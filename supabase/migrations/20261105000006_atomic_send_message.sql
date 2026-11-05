-- Migration: 20261105000006_atomic_send_message.sql
-- Description: Phase B (audit F03) – send a message, its recipients and its
-- sealed keys in ONE transaction.
--
-- Why: the app used to insert the message first and the recipient rows in a
-- second request. Supabase Realtime checks RLS for each subscriber when the
-- message INSERT is broadcast; at that moment the recipient rows didn't exist
-- yet, so recipients were filtered out and never got the live event. Inside a
-- single function call everything commits together, so the recipient rows are
-- visible by the time Realtime evaluates RLS.
--
-- SECURITY INVOKER: all existing RLS policies (including the Phase A
-- recipient/key checks) still apply to every insert below.

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

-- Speeds up the catch-up sync query (family + time order) and key lookups.
create index if not exists messages_family_created_idx
  on public.messages (family_id, created_at);
create index if not exists message_keys_device_idx
  on public.message_keys (recipient_device_id, message_id);
create index if not exists message_recipients_user_idx
  on public.message_recipients (user_id, message_id);
