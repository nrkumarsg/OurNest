-- Migration: 20261105000007_push_webhook.sql
-- Description: Phase C (audit F04) – call the push-dispatcher Edge Function
-- after every new message. The old migrations never created this trigger, so
-- push notifications were never sent.
--
-- The function URL and shared secret are read from Supabase Vault, so no
-- secret is stored in this file. Until both Vault secrets exist the trigger
-- does nothing (messages still save normally).
--
-- One-time setup (SQL Editor), replacing the placeholders:
--   select vault.create_secret('https://<project-ref>.supabase.co/functions/v1/push-dispatcher', 'push_dispatcher_url');
--   select vault.create_secret('<same random string as PUSH_WEBHOOK_SECRET>', 'push_dispatcher_secret');
--
-- pg_net sends the request only AFTER the transaction commits, so the
-- recipients written by send_message() in the same transaction are visible
-- to the function.

create extension if not exists pg_net with schema extensions;

create or replace function public.notify_push_dispatcher()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets where name = 'push_dispatcher_url' limit 1;
  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'push_dispatcher_secret' limit 1;

  if v_url is null or v_secret is null then
    return new; -- push not configured yet
  end if;

  -- Never include ciphertext/nonce: only routing metadata.
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'messages',
      'record', jsonb_build_object(
        'id', new.id,
        'family_id', new.family_id,
        'sender_id', new.sender_id,
        'type', new.type,
        'audience', new.audience,
        'created_at', new.created_at
      )
    ),
    timeout_milliseconds := 5000
  );
  return new;
exception when others then
  -- A push problem must never block sending a message.
  raise warning 'notify_push_dispatcher failed: %', sqlerrm;
  return new;
end;
$$;

revoke all on function public.notify_push_dispatcher() from public, anon, authenticated;

drop trigger if exists on_message_insert_push on public.messages;

create trigger on_message_insert_push
  after insert on public.messages
  for each row
  execute function public.notify_push_dispatcher();
