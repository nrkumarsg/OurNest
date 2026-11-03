-- Test Suite: family_rls_tests.sql
-- Description: Tests RLS policies for families, family_members, and cross-family data isolation

do $$
declare
  admin_uid uuid := '11111111-1111-1111-1111-111111111111';
  member_uid uuid := '22222222-2222-2222-2222-222222222222';
  stranger_uid uuid := '33333333-3333-3333-3333-333333333333';
  test_fam_id uuid;
  cnt integer;
begin
  raise notice '=== Running OurNest Family RLS Tests ===';

  -- Setup Test Profiles
  delete from public.profiles where id in (admin_uid, member_uid, stranger_uid);
  insert into public.profiles (id, display_name, phone) values
    (admin_uid, 'Admin User', '+10000000001'),
    (member_uid, 'Son User', '+10000000002'),
    (stranger_uid, 'Stranger User', '+10000000003');

  -- 1. Test Family Creation
  insert into public.families (name, invite_code, created_by)
  values ('Test Sharma Family', 'SHRM99', admin_uid)
  returning id into test_fam_id;

  insert into public.family_members (family_id, user_id, relation, role, status)
  values (test_fam_id, admin_uid, 'father', 'admin', 'active');

  insert into public.family_members (family_id, user_id, relation, role, status)
  values (test_fam_id, member_uid, 'son', 'member', 'active');

  -- 2. Verify Helper Functions
  -- Admin is active member
  perform set_config('request.jwt.claim.sub', admin_uid::text, true);
  if not public.is_active_member(test_fam_id) then
    raise exception 'Test Failed: Admin should be active member';
  end if;
  if not public.is_family_admin(test_fam_id) then
    raise exception 'Test Failed: Admin should be recognized as family admin';
  end if;

  -- Member is active member, but NOT admin
  perform set_config('request.jwt.claim.sub', member_uid::text, true);
  if not public.is_active_member(test_fam_id) then
    raise exception 'Test Failed: Son should be active member';
  end if;
  if public.is_family_admin(test_fam_id) then
    raise exception 'Test Failed: Son should NOT be admin';
  end if;

  -- Stranger is NOT active member and NOT admin
  perform set_config('request.jwt.claim.sub', stranger_uid::text, true);
  if public.is_active_member(test_fam_id) then
    raise exception 'Test Failed: Stranger must NOT be active member';
  end if;

  -- 3. Verify Profiles Isolation (Stranger cannot see family profiles)
  select count(*) into cnt
  from public.profiles
  where id in (admin_uid, member_uid);
  if cnt > 0 then
    raise exception 'Test Failed: Stranger must not read family profiles (found %)', cnt;
  end if;

  -- 4. Verify Family Visibility (Stranger cannot see family record)
  select count(*) into cnt
  from public.families
  where id = test_fam_id;
  if cnt > 0 then
    raise exception 'Test Failed: Stranger must not read other families (found %)', cnt;
  end if;

  -- Clean up
  delete from public.families where id = test_fam_id;
  delete from public.profiles where id in (admin_uid, member_uid, stranger_uid);

  raise notice '✓ ALL FAMILY RLS TESTS PASSED SUCCESSFULLY';
end $$;
