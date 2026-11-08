-- =============================================================================
-- OurNest — One-Click Consolidated Supabase Database Upgrade Script
-- Project: https://lbpboiyyhqyheajgrjlw.supabase.co
-- Safe to run multiple times (100% idempotent).
--
-- Instructions:
-- 1. Open: https://supabase.com/dashboard/project/lbpboiyyhqyheajgrjlw/sql/new
-- 2. Paste this entire file and click "Run".
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PART 1: Rich Personal Profiles & Family Tree (20261103000004)
-- -----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists whatsapp_number text,
  add column if not exists sex text check (sex in ('Male', 'Female', 'Other')),
  add column if not exists date_of_birth date,
  add column if not exists blood_group text,
  add column if not exists education text,
  add column if not exists occupation text,
  add column if not exists working_place text,
  add column if not exists working_details text,
  add column if not exists living_place text,
  add column if not exists home_address text,
  add column if not exists city text,
  add column if not exists status_text text default 'Available for family ❤️',
  add column if not exists bio_description text;

-- Allow multiple test/family accounts to share a household/mobile phone number without 23505 errors
alter table public.profiles
  drop constraint if exists profiles_phone_key;

create table if not exists public.family_links (
  id uuid primary key default gen_random_uuid(),
  requester_family_id uuid not null references public.families(id) on delete cascade,
  target_family_id uuid not null references public.families(id) on delete cascade,
  branch_label text not null default 'Extended Family',
  messaging_policy text not null default 'all_members'
    check (messaging_policy in ('all_members', 'admins_only')),
  status text not null default 'pending'
    check (status in ('pending', 'active')),
  visibility_mode text not null default 'visible'
    check (visibility_mode in ('visible', 'peace_pause', 'curtain_hidden')),
  hidden_scope text not null default 'none'
    check (hidden_scope in ('none', 'entire_family', 'personal_only')),
  hide_our_updates boolean not null default false,
  paused_until timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz default now(),
  constraint no_self_family_link check (requester_family_id <> target_family_id),
  unique (requester_family_id, target_family_id)
);

alter table public.family_links enable row level security;

create or replace function public.are_families_linked(fam_a uuid, fam_b uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.family_links fl
    where fl.status = 'active'
      and (
        (fl.requester_family_id = fam_a and fl.target_family_id = fam_b)
        or (fl.requester_family_id = fam_b and fl.target_family_id = fam_a)
      )
  );
$$;

drop policy if exists "Members can view family links for their family" on public.family_links;
create policy "Members can view family links for their family"
  on public.family_links
  for select
  using (
    public.is_active_member(requester_family_id)
    or public.is_active_member(target_family_id)
  );

drop policy if exists "Family admins can delete family link" on public.family_links;
create policy "Family admins can delete family link"
  on public.family_links
  for delete
  using (
    public.is_family_admin(requester_family_id)
    or public.is_family_admin(target_family_id)
  );

create or replace function public.request_family_link(
  my_family_id uuid,
  target_invite_code text,
  branch_relation_label text default 'Relative''s Family',
  policy_input text default 'all_members'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target_family record;
  v_link_id uuid;
begin
  if not public.is_family_admin(my_family_id) then
    raise exception 'Only the Family Admin can link with another family.';
  end if;

  select * into v_target_family
  from public.families
  where upper(invite_code) = upper(trim(target_invite_code))
  limit 1;

  if v_target_family.id is null then
    raise exception 'No family found with invite code %', target_invite_code;
  end if;

  if v_target_family.id = my_family_id then
    raise exception 'Cannot link a family with itself.';
  end if;

  insert into public.family_links (
    requester_family_id,
    target_family_id,
    branch_label,
    messaging_policy,
    status,
    created_by
  )
  values (
    my_family_id,
    v_target_family.id,
    branch_relation_label,
    coalesce(policy_input, 'all_members'),
    'pending',
    auth.uid()
  )
  on conflict (requester_family_id, target_family_id)
  do update set
    branch_label = excluded.branch_label,
    messaging_policy = excluded.messaging_policy
  returning id into v_link_id;

  return jsonb_build_object(
    'link_id', v_link_id,
    'target_family_id', v_target_family.id,
    'target_family_name', v_target_family.name,
    'status', 'pending'
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- PART 2: Security Hardening (20261105000005)
-- -----------------------------------------------------------------------------
alter function public.is_active_member(uuid)          set search_path = public;
alter function public.is_family_admin(uuid)           set search_path = public;
alter function public.shares_family_with(uuid)        set search_path = public;
alter function public.are_families_linked(uuid, uuid) set search_path = public;
alter function public.generate_invite_code()          set search_path = public;
alter function public.handle_updated_at()             set search_path = public;
alter function public.request_family_link(uuid, text, text, text) set search_path = public;

create or replace function public.user_is_active_member(fam uuid, uid uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.family_members
    where family_id = fam
      and user_id = uid
      and status = 'active'
  );
$$;

create or replace function public.device_is_message_recipient(msg uuid, dev uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.user_devices ud
    join public.message_recipients mr on mr.user_id = ud.user_id
    where ud.id = dev
      and mr.message_id = msg
  );
$$;

drop policy if exists "Senders can insert message recipients" on public.message_recipients;
create policy "Senders can insert message recipients"
  on public.message_recipients
  for insert
  with check (
    exists (
      select 1 from public.messages m
      where m.id = message_id
        and m.sender_id = auth.uid()
        and public.user_is_active_member(m.family_id, message_recipients.user_id)
    )
  );

drop policy if exists "Senders can insert device message keys" on public.message_keys;
create policy "Senders can insert device message keys"
  on public.message_keys
  for insert
  with check (
    exists (
      select 1 from public.messages m
      where m.id = message_id
        and m.sender_id = auth.uid()
    )
    and public.device_is_message_recipient(message_id, recipient_device_id)
  );

drop policy if exists "Senders can edit or delete own messages" on public.messages;
create policy "Senders can edit or delete own messages"
  on public.messages
  for update
  using (sender_id = auth.uid())
  with check (
    sender_id = auth.uid()
    and public.is_active_member(family_id)
  );

drop policy if exists "Family admins can request family link" on public.family_links;
create policy "Family admins can request family link"
  on public.family_links
  for insert
  with check (
    public.is_family_admin(requester_family_id)
    and status = 'pending'
    and (created_by is null or created_by = auth.uid())
  );

drop policy if exists "Family admins can update family link" on public.family_links;
create policy "Family admins can update family link"
  on public.family_links
  for update
  using (
    public.is_family_admin(requester_family_id)
    or public.is_family_admin(target_family_id)
  )
  with check (
    public.is_family_admin(requester_family_id)
    or public.is_family_admin(target_family_id)
  );

create or replace function public.guard_family_link_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.requester_family_id is distinct from old.requester_family_id
     or new.target_family_id is distinct from old.target_family_id then
    raise exception 'Linked families cannot be changed. Remove the link and create a new request.';
  end if;

  if new.status is distinct from old.status then
    if not public.is_family_admin(old.target_family_id) then
      raise exception 'Only the invited family''s admin can approve this link.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists on_family_link_update_guard on public.family_links;
create trigger on_family_link_update_guard
  before update on public.family_links
  for each row
  execute function public.guard_family_link_update();

-- -----------------------------------------------------------------------------
-- PART 3: Atomic Send Message & Sync Indexes (20261105000006)
-- -----------------------------------------------------------------------------
create or replace function public.send_message(
  p_family_id uuid,
  p_sender_device_id uuid,
  p_type text,
  p_audience text,
  p_ciphertext text,
  p_nonce text,
  p_recipient_ids uuid[],
  p_keys jsonb default '[]'::jsonb
)
returns json
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid;
  v_created timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Unauthorized';
  end if;

  if p_recipient_ids is null or coalesce(array_length(p_recipient_ids, 1), 0) = 0 then
    raise exception 'A message needs at least one recipient';
  end if;

  if p_sender_device_id is not null and not exists (
    select 1 from public.user_devices
    where id = p_sender_device_id
      and user_id = auth.uid()
      and revoked_at is null
  ) then
    raise exception 'Sender device is not registered to this user';
  end if;

  insert into public.messages
    (family_id, sender_id, sender_device_id, type, audience, ciphertext, nonce)
  values
    (p_family_id, auth.uid(), p_sender_device_id, p_type, p_audience, p_ciphertext, p_nonce)
  returning id, created_at into v_id, v_created;

  insert into public.message_recipients (message_id, user_id)
  select distinct v_id, r
  from unnest(p_recipient_ids) as r;

  insert into public.message_keys (message_id, recipient_device_id, locked_key)
  select distinct on ((k ->> 'device_id')::uuid)
         v_id,
         (k ->> 'device_id')::uuid,
         k ->> 'locked_key'
  from jsonb_array_elements(coalesce(p_keys, '[]'::jsonb)) as k
  where k ->> 'device_id' is not null
    and k ->> 'locked_key' is not null;

  return json_build_object('id', v_id, 'created_at', v_created);
end;
$$;

grant execute on function public.send_message(uuid, uuid, text, text, text, text, uuid[], jsonb)
  to authenticated;

create index if not exists messages_family_created_idx
  on public.messages (family_id, created_at);
create index if not exists message_keys_device_idx
  on public.message_keys (recipient_device_id, message_id);
create index if not exists message_recipients_user_idx
  on public.message_recipients (user_id, message_id);

-- -----------------------------------------------------------------------------
-- PART 4: Linked Family Names & Pending Applicant Visibility (20261105000008)
-- -----------------------------------------------------------------------------
create or replace function public.get_linked_family_names(my_family_id uuid)
returns table (link_id uuid, family_id uuid, family_name text)
language sql
security definer
stable
set search_path = public
as $$
  select fl.id,
         f.id,
         f.name
  from public.family_links fl
  join public.families f
    on f.id = case when fl.requester_family_id = my_family_id
                   then fl.target_family_id
                   else fl.requester_family_id end
  where public.is_active_member(my_family_id)
    and (fl.requester_family_id = my_family_id or fl.target_family_id = my_family_id);
$$;

revoke all on function public.get_linked_family_names(uuid) from public, anon;
grant execute on function public.get_linked_family_names(uuid) to authenticated;

create or replace function public.is_pending_applicant_to_my_family(applicant uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.family_members app
    join public.family_members adm
      on adm.family_id = app.family_id
    where app.user_id = applicant
      and app.status = 'pending'
      and adm.user_id = auth.uid()
      and adm.role = 'admin'
      and adm.status = 'active'
  );
$$;

drop policy if exists "Admins can view pending applicants profiles" on public.profiles;
create policy "Admins can view pending applicants profiles"
  on public.profiles
  for select
  using (public.is_pending_applicant_to_my_family(id));

-- -----------------------------------------------------------------------------
-- PART 5: Invite Rate Limit, Code Rotation & Private Realtime (20261105000009)
-- -----------------------------------------------------------------------------
create table if not exists public.join_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  attempted_at timestamptz not null default now(),
  succeeded boolean not null default false
);

create index if not exists join_attempts_user_time_idx
  on public.join_attempts (user_id, attempted_at desc);

alter table public.join_attempts enable row level security;

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
    insert into join_attempts (user_id, succeeded) values (caller_id, false);
    return json_build_object('error', 'Invalid invite code. Please check and try again.');
  end if;

  if exists (
    select 1 from family_members
    where user_id = caller_id
      and status = 'active'
      and family_id <> fam.id
  ) then
    raise exception 'You are already a member of another family. Leave it first to join a new one. (To stay in touch with relatives, ask your admin to connect the two families instead.)';
  end if;

  if exists (
    select 1 from family_members
    where user_id = caller_id and family_id = fam.id and status = 'active'
  ) then
    return json_build_object('family_id', fam.id, 'family_name', fam.name, 'status', 'active');
  end if;

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

create or replace function public.guard_last_admin_leaving()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
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

-- -----------------------------------------------------------------------------
-- PART 6: All Device Platforms (20261105000010)
-- -----------------------------------------------------------------------------
alter table public.user_devices
  drop constraint if exists user_devices_platform_check;

alter table public.user_devices
  add constraint user_devices_platform_check
  check (platform in ('android', 'ios', 'web', 'windows', 'macos', 'linux'));

-- -----------------------------------------------------------------------------
-- PART 7: Shared Family Notepad & Grocery/Task Records (20261108000011)
-- -----------------------------------------------------------------------------
create table if not exists public.family_notes (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id) on delete cascade,
  created_by uuid references public.profiles(id) on delete set null,
  category text not null default 'grocery'
    check (category in ('grocery', 'tasks', 'volunteer', 'note')),
  title text not null default 'Grocery & Shopping List',
  assigned_to text not null default 'All Family',
  content text not null default '',
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.family_notes enable row level security;

drop policy if exists "Family members can view family notes" on public.family_notes;
create policy "Family members can view family notes"
  on public.family_notes
  for select
  using (
    created_by = auth.uid()
    or (family_id is not null and public.is_active_member(family_id))
  );

drop policy if exists "Family members can insert family notes" on public.family_notes;
create policy "Family members can insert family notes"
  on public.family_notes
  for insert
  with check (
    auth.uid() is not null
    and (created_by is null or created_by = auth.uid())
    and (family_id is null or public.is_active_member(family_id))
  );

drop policy if exists "Family members can update family notes" on public.family_notes;
create policy "Family members can update family notes"
  on public.family_notes
  for update
  using (
    created_by = auth.uid()
    or (family_id is not null and public.is_active_member(family_id))
  );

drop policy if exists "Family members can delete family notes" on public.family_notes;
create policy "Family members can delete family notes"
  on public.family_notes
  for delete
  using (
    created_by = auth.uid()
    or (family_id is not null and public.is_active_member(family_id))
  );


