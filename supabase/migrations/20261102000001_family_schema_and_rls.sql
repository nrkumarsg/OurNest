-- Migration: 20261102000001_family_schema_and_rls.sql
-- Description: Families and Family Members tables, RLS policies, helper functions, and RPCs

-- 1. Create families table
create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text unique not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz default now()
);

-- 2. Create family_members table
create table if not exists public.family_members (
  family_id uuid references public.families(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  relation text not null,
  relation_label text,
  role text not null default 'member' check (role in ('admin', 'member')),
  status text not null default 'pending' check (status in ('pending', 'active')),
  created_at timestamptz default now(),
  primary key (family_id, user_id)
);

-- 3. Security definer helper functions to prevent recursive RLS
create or replace function public.is_active_member(fam uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1
    from public.family_members
    where family_id = fam
      and user_id = auth.uid()
      and status = 'active'
  );
$$;

create or replace function public.is_family_admin(fam uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1
    from public.family_members
    where family_id = fam
      and user_id = auth.uid()
      and role = 'admin'
      and status = 'active'
  );
$$;

create or replace function public.shares_family_with(other_user uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1
    from public.family_members m1
    join public.family_members m2 on m1.family_id = m2.family_id
    where m1.user_id = auth.uid()
      and m1.status = 'active'
      and m2.user_id = other_user
      and m2.status = 'active'
  );
$$;

-- 4. Enable Row Level Security (RLS)
alter table public.families enable row level security;
alter table public.family_members enable row level security;

-- 5. RLS Policies for families
-- Read: active members can view their family
create policy "Active members can view family"
  on public.families
  for select
  using (public.is_active_member(id));

-- Update: only the admin can update family details (e.g. rename)
create policy "Admins can update family"
  on public.families
  for update
  using (public.is_family_admin(id))
  with check (public.is_family_admin(id));

-- Insert: allowed through security definer RPC create_family or direct insert by creator
create policy "Users can create family"
  on public.families
  for insert
  with check (auth.uid() = created_by);

-- 6. RLS Policies for family_members
-- Read: members can view rows of families they belong to (even pending to check own status)
create policy "Members can view family members"
  on public.family_members
  for select
  using (
    user_id = auth.uid() or
    public.is_active_member(family_id)
  );

-- Update: admin can update members (e.g. approve, edit relation)
create policy "Admins can update family members"
  on public.family_members
  for update
  using (public.is_family_admin(family_id))
  with check (public.is_family_admin(family_id));

-- Delete: admin can remove members, OR a member can remove themselves (leave family)
create policy "Admins can remove or members can leave"
  on public.family_members
  for delete
  using (
    public.is_family_admin(family_id) or
    user_id = auth.uid()
  );

-- 7. Update profiles RLS: active family members can see each other's profiles
drop policy if exists "Users can view own profile" on public.profiles;

create policy "Users can view own and family members profiles"
  on public.profiles
  for select
  using (
    auth.uid() = id or
    public.shares_family_with(id)
  );

-- 8. Stored Procedures / RPCs for secure atomic family operations

-- Generates a clean, unambiguous 6-character uppercase invite code (excluding 0, O, 1, I)
create or replace function public.generate_invite_code()
returns text
language plpgsql
as $$
declare
  chars text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  result text := '';
  i integer := 0;
begin
  for i in 1..6 loop
    result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
  end loop;
  return result;
end;
$$;

-- RPC: create_family
create or replace function public.create_family(
  family_name text,
  admin_relation text,
  admin_relation_label text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  new_family_id uuid;
  new_code text;
  caller_id uuid := auth.uid();
  tries integer := 0;
begin
  if caller_id is null then
    raise exception 'Unauthorized';
  end if;

  if coalesce(trim(family_name), '') = '' then
    raise exception 'Family name cannot be empty';
  end if;

  -- Ensure unique invite code
  loop
    new_code := generate_invite_code();
    begin
      insert into families (name, invite_code, created_by)
      values (trim(family_name), new_code, caller_id)
      returning id into new_family_id;
      exit; -- succeeded
    exception when unique_violation then
      tries := tries + 1;
      if tries > 10 then
        raise exception 'Could not generate unique invite code';
      end if;
    end;
  end loop;

  -- Insert admin member with 'active' status
  insert into family_members (family_id, user_id, relation, relation_label, role, status)
  values (new_family_id, caller_id, admin_relation, admin_relation_label, 'admin', 'active');

  return json_build_object(
    'family_id', new_family_id,
    'name', trim(family_name),
    'invite_code', new_code
  );
end;
$$;

-- RPC: join_family
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
begin
  if caller_id is null then
    raise exception 'Unauthorized';
  end if;

  -- Look up family by invite code (case-insensitive)
  select * into fam
  from families
  where upper(invite_code) = upper(trim(invite_code_input));

  if fam.id is null then
    raise exception 'Invalid invite code. Please check and try again.';
  end if;

  -- Insert or update pending record
  insert into family_members (family_id, user_id, relation, relation_label, role, status)
  values (fam.id, caller_id, applicant_relation, applicant_relation_label, 'member', 'pending')
  on conflict (family_id, user_id)
  do update set
    relation = excluded.relation,
    relation_label = excluded.relation_label,
    status = 'pending';

  return json_build_object(
    'family_id', fam.id,
    'family_name', fam.name,
    'status', 'pending'
  );
end;
$$;

-- RPC: approve_member
create or replace function public.approve_member(
  target_family_id uuid,
  target_user_id uuid,
  assigned_relation text default null,
  assigned_label text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_family_admin(target_family_id) then
    raise exception 'Only the family admin can approve members';
  end if;

  update family_members
  set status = 'active',
      relation = coalesce(assigned_relation, relation),
      relation_label = coalesce(assigned_label, relation_label)
  where family_id = target_family_id
    and user_id = target_user_id;
end;
$$;

-- RPC: transfer_admin
create or replace function public.transfer_admin(
  target_family_id uuid,
  new_admin_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_family_admin(target_family_id) then
    raise exception 'Only the current admin can transfer the admin role';
  end if;

  -- Demote current admin
  update family_members
  set role = 'member'
  where family_id = target_family_id
    and user_id = auth.uid();

  -- Promote new admin
  update family_members
  set role = 'admin'
  where family_id = target_family_id
    and user_id = new_admin_id
    and status = 'active';
end;
$$;
