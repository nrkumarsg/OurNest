-- Test Suite: chat_rls_tests.sql
-- Description: Tests RLS rules for E2EE messages, recipients, and locked keys

do $$
declare
  fam_id uuid := 'ffffffff-ffff-ffff-ffff-ffffffffffff';
  user_a uuid := '11111111-1111-1111-1111-111111111111'; -- Father (Sender)
  user_b uuid := '22222222-2222-2222-2222-222222222222'; -- Mother (Selected Recipient)
  user_c uuid := '33333333-3333-3333-3333-333333333333'; -- Son (Family member, NOT selected)
  user_x uuid := '44444444-4444-4444-4444-444444444444'; -- Stranger (different family)
  dev_b uuid;
  dev_c uuid;
  msg_id uuid;
  cnt integer;
begin
  raise notice '=== Running OurNest E2EE Chat RLS Tests ===';

  -- Clean setup
  delete from public.messages where family_id = fam_id;
  delete from public.user_devices where user_id in (user_a, user_b, user_c, user_x);
  delete from public.family_members where family_id = fam_id;
  delete from public.families where id = fam_id;
  delete from public.profiles where id in (user_a, user_b, user_c, user_x);

  -- Setup profiles & family
  insert into public.profiles (id, display_name, phone) values
    (user_a, 'Father', '+1111111111'),
    (user_b, 'Mother', '+2222222222'),
    (user_c, 'Son', '+3333333333'),
    (user_x, 'Stranger', '+4444444444');

  insert into public.families (id, name, invite_code, created_by)
  values (fam_id, 'Chat Test Family', 'TEST99', user_a);

  insert into public.family_members (family_id, user_id, relation, role, status) values
    (fam_id, user_a, 'father', 'admin', 'active'),
    (fam_id, user_b, 'mother', 'member', 'active'),
    (fam_id, user_c, 'son', 'member', 'active');

  -- Setup user devices
  insert into public.user_devices (user_id, public_key, platform)
  values (user_b, 'fake_pubkey_mother_b64', 'android')
  returning id into dev_b;

  insert into public.user_devices (user_id, public_key, platform)
  values (user_c, 'fake_pubkey_son_b64', 'ios')
  returning id into dev_c;

  -- 1. Father sends a SELECTED message to Mother ONLY
  perform set_config('request.jwt.claim.sub', user_a::text, true);
  insert into public.messages (family_id, sender_id, type, audience, ciphertext, nonce)
  values (fam_id, user_a, 'text', 'selected', 'ciphertext_b64', 'nonce_b64')
  returning id into msg_id;

  insert into public.message_recipients (message_id, user_id)
  values (msg_id, user_b);

  insert into public.message_keys (message_id, recipient_device_id, locked_key)
  values (msg_id, dev_b, 'locked_key_for_mother_b64');

  -- 2. Test Father (Sender) can read message
  select count(*) into cnt from public.messages where id = msg_id;
  if cnt <> 1 then
    raise exception 'Test Failed: Sender should be able to select their own message';
  end if;

  -- 3. Test Mother (Selected recipient) can read message and her device key
  perform set_config('request.jwt.claim.sub', user_b::text, true);
  select count(*) into cnt from public.messages where id = msg_id;
  if cnt <> 1 then
    raise exception 'Test Failed: Selected recipient (Mother) should be able to read message';
  end if;

  select count(*) into cnt from public.message_keys where message_id = msg_id;
  if cnt <> 1 then
    raise exception 'Test Failed: Mother should be able to read message key for her device';
  end if;

  -- 4. Test Son (Family member, but NOT selected) CANNOT read the message
  perform set_config('request.jwt.claim.sub', user_c::text, true);
  select count(*) into cnt from public.messages where id = msg_id;
  if cnt <> 0 then
    raise exception 'Test Failed: Non-selected member (Son) must NOT be able to read Selected message (found %)', cnt;
  end if;

  select count(*) into cnt from public.message_keys where message_id = msg_id;
  if cnt <> 0 then
    raise exception 'Test Failed: Son must NOT be able to read message key';
  end if;

  -- 5. Test Stranger (Non-family user) CANNOT read message or keys
  perform set_config('request.jwt.claim.sub', user_x::text, true);
  select count(*) into cnt from public.messages where id = msg_id;
  if cnt <> 0 then
    raise exception 'Test Failed: Stranger must not read message';
  end if;

  -- Clean up
  delete from public.messages where id = msg_id;
  delete from public.user_devices where user_id in (user_a, user_b, user_c, user_x);
  delete from public.family_members where family_id = fam_id;
  delete from public.families where id = fam_id;
  delete from public.profiles where id in (user_a, user_b, user_c, user_x);

  raise notice '✓ ALL E2EE CHAT RLS TESTS PASSED SUCCESSFULLY';
end $$;
