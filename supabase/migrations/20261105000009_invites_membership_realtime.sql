-- Migration: 20261105000009_invites_membership_realtime.sql
-- Description: Phase E + owner decisions (2026-11-05)
--   F20  invite codes: attempt limit, admin can issue a new code
--   Q1   one family per person (decision: yes, for now). Joining a second
--        family is refused; an older PENDING request elsewhere is replaced.
--   Q4   the last admin can't leave while other active members remain
--        (decision: must transfer admin first)
--   F21  private Realtime channels: only active family members may join
--        `family_chat_<family_id>` (enforced once "Allow public access" is
--        turned OFF in Supabase → Realtime → Settings)

-- ---------------------------------------------------------------------------
-- F20: remember join attempts so invite codes can't be brute-forced
-- ---------------------------------------------------------------------------
create table if not exists public.join_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  attempted_at timestamptz not null default now(),
  succeeded boolean not null default false
);

create index if not exists join_attempts_user_time_idx
  on public.join_attempts (user_id, attempted_at desc);

alter table public.join_attempts enable row level security;
-- No policies: only the SECURITY DEFINER function below reads/writes it.

-- ---------------------------------------------------------------------------
-- join_family: attempt limit (F20) + one family per person (Q1)
-- ---------------------------------------------------------------------------
create or replace function public.join_family(
  invite_code_input text,
  applicant_relation text,
  applicant_relation_label text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  fam record;
  caller_id uuid := auth.uid();
  recent_failures integer;
begin
  if caller_id is null then
    raise exception 'Unauthorized';
  end if;

  -- F20: at most 10 wrong codes per hour per account
  select count(*) into recent_failures
  from join_attempts
  where user_id = caller_id
    and succeeded = false
    and attempted_at > now() - interval '1 hour';

  if recent_failures >= 10 then
    raise exception 'Too many wrong invite codes. Please wait an hour and try again, or ask the family admin to share the code again.';
  end if;

  select * into fam
  from families
  where upper(invite_code) = upper(trim(invite_code_input));

  if fam.id is null then
    -- Return (not raise) so the failed attempt is actually saved; raising
    -- would roll the insert back and the limit would never trigger.
    insert into join_attempts (user_id, succeeded) values (caller_id, false);
    return json_build_object('error', 'Invalid invite code. Please check and try again.');
  end if;

  -- Q1: one family per person
  if exists (
    select 1 from family_members
    where user_id = caller_id
      and status = 'active'
      and family_id <> fam.id
  ) then
    raise exception 'You are already a member of another family. Leave it first to join a new one. (To stay in touch with relatives, ask your admin to connect the two families instead.)';
  end if;

  -- Already an active member of this family: nothing to do (don't demote to pending)
  if exists (
    select 1 from family_members
    where user_id = caller_id and family_id = fam.id and status = 'active'
  ) then
    return json_build_object('family_id', fam.id, 'family_name', fam.name, 'status', 'active');
  end if;

  -- Replace any older pending request to a different family
  delete from family_members
  where user_id = caller_id
    and status = 'pending'
    and family_id <> fam.id;

  insert into family_members (family_id, user_id, relation, relation_label, role, status)
  values (fam.id, caller_id, applicant_relation, applicant_relation_label, 'member', 'pending')
  on conflict (family_id, user_id)
  do update set
    relation = excluded.relation,
    relation_label = excluded.relation_label;

  insert into join_attempts (user_id, succeeded) values (caller_id, true);

  return json_build_object(
    'family_id', fam.id,
    'family_name', fam.name,
    'status', 'pending'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- F20: admin can replace a leaked invite code. Old QR codes stop working.
-- ---------------------------------------------------------------------------
create or replace function public.regenerate_invite_code(target_family_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
  tries integer := 0;
begin
  if not is_family_admin(target_family_id) then
    raise exception 'Only the family admin can create a new invite code.';
  end if;

  loop
    new_code := generate_invite_code();
    begin
      update families set invite_code = new_code where id = target_family_id;
      exit;
    exception when unique_violation then
      tries := tries + 1;
      if tries > 10 then
        raise exception 'Could not generate a unique invite code. Please try again.';
      end if;
    end;
  end loop;

  return new_code;
end;
$$;

revoke all on function public.regenerate_invite_code(uuid) from public, anon;
grant execute on function public.regenerate_invite_code(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Q4: the last admin must hand over the admin role before leaving
-- ---------------------------------------------------------------------------
create or replace function public.guard_last_admin_leaving()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Deleting the whole family or the user's account cascades here; those
  -- rows are already gone, so don't block them.
  if not exists (select 1 from families where id = old.family_id)
     or not exists (select 1 from profiles where id = old.user_id) then
    return old;
  end if;

  if old.role = 'admin' and old.status = 'active'
     and not exists (
       select 1 from family_members
       where family_id = old.family_id
         and role = 'admin' and status = 'active'
         and user_id <> old.user_id
     )
     and exists (
       select 1 from family_members
       where family_id = old.family_id
         and status = 'active'
         and user_id <> old.user_id
     )
  then
    raise exception 'You are the only admin. Make another member admin before leaving the family.';
  end if;
  return old;
end;
$$;

drop trigger if exists on_family_member_delete_guard on public.family_members;

create trigger on_family_member_delete_guard
  before delete on public.family_members
  for each row
  execute function public.guard_last_admin_leaving();

-- ---------------------------------------------------------------------------
-- F21: private Realtime channels for family chat presence / receipts
-- ---------------------------------------------------------------------------
create or replace function public.family_id_from_topic(topic text)
returns uuid
language plpgsql
immutable
set search_path = public
as $$
begin
  if topic is null or topic not like 'family_chat_%' then
    return null;
  end if;
  return substring(topic from 13)::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;

drop policy if exists "Family members can receive family channel" on realtime.messages;
create policy "Family members can receive family channel"
  on realtime.messages
  for select
  to authenticated
  using (
    public.is_active_member(public.family_id_from_topic(realtime.topic()))
  );

drop policy if exists "Family members can send on family channel" on realtime.messages;
create policy "Family members can send on family channel"
  on realtime.messages
  for insert
  to authenticated
  with check (
    public.is_active_member(public.family_id_from_topic(realtime.topic()))
  );
