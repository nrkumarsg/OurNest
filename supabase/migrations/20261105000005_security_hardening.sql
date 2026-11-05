-- Migration: 20261105000005_security_hardening.sql
-- Description: Phase A security fixes from CODE_AUDIT_REPORT.md
--   F19  pin search_path on every SECURITY DEFINER / helper function
--   F12  family links: requester can no longer self-approve or insert 'active' links
--   F18  message recipients / keys must belong to active members of the message's family;
--        message edits can't move a message into a family the sender isn't in
-- Safe to run more than once (idempotent drops / create or replace).

-- ---------------------------------------------------------------------------
-- F19: pin search_path so a malicious object in another schema can't hijack
-- these privileged functions.
-- ---------------------------------------------------------------------------
alter function public.is_active_member(uuid)        set search_path = public;
alter function public.is_family_admin(uuid)         set search_path = public;
alter function public.shares_family_with(uuid)      set search_path = public;
alter function public.are_families_linked(uuid, uuid) set search_path = public;
alter function public.generate_invite_code()        set search_path = public;
alter function public.handle_updated_at()           set search_path = public;
alter function public.request_family_link(uuid, text, text, text) set search_path = public;

-- ---------------------------------------------------------------------------
-- Helpers (SECURITY DEFINER so they can look across RLS-protected rows)
-- ---------------------------------------------------------------------------

-- True if [uid] is an active member of family [fam]
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

-- True if device [dev] belongs to a user listed in message_recipients for [msg]
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

-- ---------------------------------------------------------------------------
-- F18: message_recipients – only active members of the message's family
-- ---------------------------------------------------------------------------
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

-- F18: message_keys – only for devices of users who are recipients of that message
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

-- F18: messages – an edit/tombstone must stay inside a family the sender is active in
drop policy if exists "Senders can edit or delete own messages" on public.messages;

create policy "Senders can edit or delete own messages"
  on public.messages
  for update
  using (sender_id = auth.uid())
  with check (
    sender_id = auth.uid()
    and public.is_active_member(family_id)
  );

-- ---------------------------------------------------------------------------
-- F12: family_links approval can't be skipped
-- ---------------------------------------------------------------------------

-- Insert: requester admin may only create a PENDING request, as themselves
drop policy if exists "Family admins can request family link" on public.family_links;

create policy "Family admins can request family link"
  on public.family_links
  for insert
  with check (
    public.is_family_admin(requester_family_id)
    and status = 'pending'
    and (created_by is null or created_by = auth.uid())
  );

-- Update: admins of either side may update (policy, peace mode, ...),
-- and the row must still involve a family they administer afterwards.
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

-- Trigger: only the TARGET family's admin may change status, and the two
-- family ids can never be re-pointed after creation.
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
