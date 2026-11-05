-- ONE-TIME MANUAL SCRIPT – run by the project owner, NOT an automatic migration.
-- Fixes audit finding F01 on the server side.
--
-- WHY: older app versions set every account's password to
--   'OurNest#Family2026!' || email
-- That formula is public (it is inside the shipped web/Android app), so anyone
-- who knows a member's email can still log in with it until the passwords are
-- replaced. Updating the app alone does NOT close this hole.
--
-- WHAT IT DOES: replaces every user's password with a long random value that
-- nobody knows. Email OTP / magic-link sign-in keeps working, so users simply
-- sign in with an email code next time. No messages, families or profiles are
-- touched.
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste → Run.
-- Do this AFTER the fixed app version is released (old app versions would
-- otherwise just set the derived password again after an OTP login).
--
-- ALSO IN THE DASHBOARD (Authentication → Providers → Email):
--   * turn ON "Confirm email" so nobody can sign up with someone else's address
--   * consider lowering the OTP expiry and keeping the default rate limits

-- 1. Preview how many accounts will be affected
select count(*) as accounts_to_reset from auth.users;

-- 2. Replace passwords with random, unknown values
update auth.users
set encrypted_password = extensions.crypt(
      encode(extensions.gen_random_bytes(32), 'base64'),
      extensions.gen_salt('bf')
    ),
    updated_at = now();

-- 3. Sign everyone out so any session an attacker may already hold is ended
delete from auth.refresh_tokens;
delete from auth.sessions;
