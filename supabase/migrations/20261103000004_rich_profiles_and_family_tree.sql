-- Migration: 20261103000004_rich_profiles_and_family_tree.sql
-- Description: Adds rich personal profile fields (sex, DOB, education, occupation, status, bio, blood_group)
--              and the family_links table for Family-to-Family Tree chains ("Connected Nests").

-- 1. Extend public.profiles with rich family member bio & birthday fields
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

-- 2. Create family_links table for connecting relative families in a Family Tree chain
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

-- Helper function: returns true if two families have an active link
create or replace function public.are_families_linked(fam_a uuid, fam_b uuid)
returns boolean
language sql
security definer
stable
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

-- RLS for family_links: members of either family can view links involving their family
create policy "Members can view family links for their family"
  on public.family_links
  for select
  using (
    public.is_active_member(requester_family_id)
    or public.is_active_member(target_family_id)
  );

-- Admins of requester_family_id can insert a link request
create policy "Family admins can request family link"
  on public.family_links
  for insert
  with check (
    public.is_family_admin(requester_family_id)
  );

-- Admins of either family can update (approve/change policy) or delete the link
create policy "Family admins can update family link"
  on public.family_links
  for update
  using (
    public.is_family_admin(requester_family_id)
    or public.is_family_admin(target_family_id)
  );

create policy "Family admins can delete family link"
  on public.family_links
  for delete
  using (
    public.is_family_admin(requester_family_id)
    or public.is_family_admin(target_family_id)
  );

-- 3. RPC to request linking with another family using its 6-character invite code
create or replace function public.request_family_link(
  my_family_id uuid,
  target_invite_code text,
  branch_relation_label text default 'Relative''s Family',
  policy_input text default 'all_members'
)
returns jsonb
language plpgsql
security definer
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
