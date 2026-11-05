-- Test Suite: security_rules_tests.sql  (audit F30, Phases A–E)
--
-- LOCAL SUPABASE ONLY. Run with:
--   supabase start
--   supabase db reset            # applies all migrations to the local DB
--   PGOPTIONS="-c ournest.allow_test_data=on" \
--     psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
--     -v ON_ERROR_STOP=1 -f supabase/tests/security_rules_tests.sql
--
-- Unlike the older test files, every check here runs as the real
-- `authenticated` role, so Row Level Security is actually applied.
-- Everything happens inside one transaction that is ROLLED BACK at the end:
-- nothing is left behind even on a local database.
-- A failing check raises 'FAIL: …' and stops the script.

begin;

-- Refuse to run unless explicitly allowed (set it only on a local,
-- disposable database). Everything is rolled back anyway.
do $$
begin
  if coalesce(current_setting('ournest.allow_test_data', true), '') <> 'on' then
    raise exception 'Refusing to run: start psql with PGOPTIONS="-c ournest.allow_test_data=on" on your LOCAL Supabase only.';
  end if;
end $$;

do $$
declare
  fam_a uuid := 'aaaaaaaa-0000-0000-0000-000000000001';
  fam_b uuid := 'bbbbbbbb-0000-0000-0000-000000000002';
  admin_a  uuid := '10000000-0000-0000-0000-00000000000a';
  member_a uuid := '10000000-0000-0000-0000-00000000000b';
  admin_b  uuid := '20000000-0000-0000-0000-00000000000a';
  stranger uuid := '90000000-0000-0000-0000-000000000009';
  applicant uuid := '80000000-0000-0000-0000-000000000008';
  msg_id uuid;
  link_id uuid;
  cnt integer;
  res json;
  failed boolean;
  i integer;
begin
  raise notice '=== OurNest security rules tests ===';

  -- ---------- setup (as superuser) ----------
  insert into auth.users (id, email) values
    (admin_a, 'admin_a@test.local'), (member_a, 'member_a@test.local'),
    (admin_b, 'admin_b@test.local'), (stranger, 'stranger@test.local'),
    (applicant, 'applicant@test.local');
  insert into public.profiles (id, display_name) values
    (admin_a, 'Admin A'), (member_a, 'Member A'), (admin_b, 'Admin B'),
    (stranger, 'Stranger'), (applicant, 'Applicant');
  insert into public.families (id, name, invite_code, created_by) values
    (fam_a, 'Family A', 'TSTAAA', admin_a),
    (fam_b, 'Family B', 'TSTBBB', admin_b);
  insert into public.family_members (family_id, user_id, relation, role, status) values
    (fam_a, admin_a, 'father', 'admin', 'active'),
    (fam_a, member_a, 'son', 'member', 'active'),
    (fam_b, admin_b, 'father', 'admin', 'active');
  insert into public.messages (family_id, sender_id, type, audience, ciphertext, nonce)
    values (fam_a, admin_a, 'text', 'all', 'x', 'y') returning id into msg_id;
  insert into public.message_recipients (message_id, user_id) values
    (msg_id, admin_a), (msg_id, member_a);

  -- ---------- 1. a stranger can't read another family's messages ----------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', stranger, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', stranger::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into cnt from public.messages where family_id = fam_a;
  if cnt <> 0 then raise exception 'FAIL 1: stranger saw % messages', cnt; end if;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', member_a, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', member_a::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into cnt from public.messages where id = msg_id;
  if cnt <> 1 then raise exception 'FAIL 1b: recipient cannot read own message'; end if;
  raise notice 'PASS 1: messages isolated per recipient';

  -- ---------- 2. recipients must be members of the message family (F18) ----------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', admin_a, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', admin_a::text, true);
  perform set_config('role', 'authenticated', true);
  failed := false;
  begin
    insert into public.message_recipients (message_id, user_id) values (msg_id, stranger);
  exception when insufficient_privilege or check_violation then failed := true;
  end;
  if not failed then raise exception 'FAIL 2: outsider added as recipient'; end if;
  raise notice 'PASS 2: outsiders cannot be added as recipients';

  -- ---------- 3. link requests can't be inserted as active (F12) ----------
  failed := false;
  begin
    insert into public.family_links (requester_family_id, target_family_id, status, created_by)
      values (fam_a, fam_b, 'active', admin_a);
  exception when insufficient_privilege or check_violation then failed := true;
  end;
  if not failed then raise exception 'FAIL 3: requester inserted an active link'; end if;
  raise notice 'PASS 3: links start as pending';

  -- ---------- 4. requester can't approve; target admin can (F12) ----------
  res := public.request_family_link(fam_a, 'TSTBBB', 'Cousins', 'all_members')::json;
  link_id := (res ->> 'link_id')::uuid;
  failed := false;
  begin
    update public.family_links set status = 'active' where id = link_id;
  exception when raise_exception then failed := true;
  end;
  if not failed then raise exception 'FAIL 4: requester approved own link'; end if;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', admin_b, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', admin_b::text, true);
  perform set_config('role', 'authenticated', true);
  update public.family_links set status = 'active' where id = link_id;
  perform set_config('role', 'postgres', true);
  select count(*) into cnt from public.family_links where id = link_id and status = 'active';
  if cnt <> 1 then raise exception 'FAIL 4b: target admin could not approve'; end if;
  raise notice 'PASS 4: only the invited family approves';

  -- ---------- 5. linked family names visible, codes not (F32) ----------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', member_a, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', member_a::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into cnt from public.get_linked_family_names(fam_a) where family_name = 'Family B';
  if cnt <> 1 then raise exception 'FAIL 5: linked family name not visible'; end if;
  select count(*) into cnt from public.families where id = fam_b;
  if cnt <> 0 then raise exception 'FAIL 5b: other family row (with invite code) visible'; end if;
  raise notice 'PASS 5: linked names visible, invite codes private';

  -- ---------- 6. one family per person (Q1) ----------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', member_a, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', member_a::text, true);
  perform set_config('role', 'authenticated', true);
  failed := false;
  begin
    perform public.join_family('TSTBBB', 'cousin', null);
  exception when raise_exception then failed := true;
  end;
  if not failed then raise exception 'FAIL 6: member joined a second family'; end if;
  raise notice 'PASS 6: one family per person';

  -- ---------- 7. pending applicant visible to the admin only (F17) ----------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', applicant, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', applicant::text, true);
  perform set_config('role', 'authenticated', true);
  res := public.join_family('TSTAAA', 'nephew', null);
  if res ->> 'status' <> 'pending' then raise exception 'FAIL 7: join did not go pending'; end if;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', admin_a, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', admin_a::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into cnt from public.profiles where id = applicant;
  if cnt <> 1 then raise exception 'FAIL 7b: admin cannot see applicant profile'; end if;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', admin_b, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', admin_b::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into cnt from public.profiles where id = applicant;
  if cnt <> 0 then raise exception 'FAIL 7c: other family admin sees applicant'; end if;
  raise notice 'PASS 7: applicants visible to their admin only';

  -- ---------- 8. wrong invite codes are limited (F20) ----------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', stranger, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', stranger::text, true);
  perform set_config('role', 'authenticated', true);
  for i in 1..10 loop
    res := public.join_family('ZZZZZZ', 'friend', null);
    if res ->> 'error' is null then raise exception 'FAIL 8: wrong code accepted'; end if;
  end loop;
  failed := false;
  begin
    perform public.join_family('TSTAAA', 'friend', null);
  exception when raise_exception then failed := true;
  end;
  if not failed then raise exception 'FAIL 8b: no limit after 10 wrong codes'; end if;
  raise notice 'PASS 8: invite code attempts limited';

  -- ---------- 9. last admin can't leave while others remain (Q4) ----------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', admin_a, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', admin_a::text, true);
  perform set_config('role', 'authenticated', true);
  failed := false;
  begin
    delete from public.family_members where family_id = fam_a and user_id = admin_a;
  exception when raise_exception then failed := true;
  end;
  if not failed then raise exception 'FAIL 9: last admin left the family'; end if;
  perform public.transfer_admin(fam_a, member_a);
  delete from public.family_members where family_id = fam_a and user_id = admin_a;
  raise notice 'PASS 9: admin must hand over before leaving';

  perform set_config('role', 'postgres', true);
  raise notice '=== ALL SECURITY RULE TESTS PASSED ===';
end $$;

rollback;
