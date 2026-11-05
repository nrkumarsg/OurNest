-- Migration: 20261105000008_linked_names_and_applicants.sql
-- Description: Phase D
--   F32  members can see the NAME of families linked to theirs (RLS on
--        `families` only allows your own family, so the app showed
--        "Connected Family" placeholders). Invite codes are NOT exposed.
--   F17  a family admin can see the profile of someone waiting for approval,
--        so they know who they're approving (was shown as "Family Member").

-- ---------------------------------------------------------------------------
-- F32: names of families linked (pending or active) to one of my families
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- F17: admins can read profiles of PENDING applicants to their own family
-- ---------------------------------------------------------------------------
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
