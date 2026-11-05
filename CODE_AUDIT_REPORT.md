# OurNest – Code Audit Report

**Date:** 2026-11-05 · **Commit audited:** `775cb9c` (pubspec version `1.2.3+6`) · **Auditor:** Claude (review only, no source files changed)

> **What I did and didn't do.** I read every data-layer file, every database migration, the edge function, the router, the auth, chat, crypto, alarm and family code, the Android and iOS config, and the parts of the large UI screens that matter. I ran `pub get`, `flutter analyze`, `flutter test --coverage`, `pub outdated` and `flutter build web`.
> **I did not click through the app live.** The app has no local or test Supabase project. `.env` and the hardcoded fallback in `lib/core/constants/env.dart` both point to your **real production project** (`lbpboiyyhqyheajgrjlw`). Signing in there would create real accounts and real data, so I traced the user flows (Phase 7) through the code instead. Anything that needs a real device is marked **needs verification**.

---

## 1. Executive summary

**Overall health score: 3 / 10**

The app looks polished and the encryption building blocks (libsodium sealed boxes plus XChaCha20-Poly1305) are chosen well. Underneath, several headline features are **not actually working end to end**, and there is one **critical security hole in login**. A lot of the code "fakes success": it shows a green "done" message even when nothing was saved or sent. That pattern is typical of AI-generated code.

### Top 5 risks

1. **Anyone can log in as anyone (Critical).** Every account's password is `OurNest#Family2026!` + the email address, and that formula is in the public web app. If you know a member's email, you can sign in as them and read their family's profile data, including home addresses, phones and dates of birth.
2. **Chat has no message history (Critical).** The app only receives messages that arrive *while the chat screen is open*. Anything sent while your phone was off or the app was closed never shows up. On the web/PWA, refreshing the page wipes the whole chat.
3. **Push notifications and shared alarms don't work across devices (High).** Firebase Messaging isn't installed, the notification service is never started, the server function uses a Google API that was shut down in 2024, and other family members' phones never schedule the "escalation" alarm.
4. **Fake success messages (High).** "Broadcast delivered to 5 Nests", "Family linked", "Reminder scheduled", "Profile saved" and the privacy "Silent Curtain" all report success even when nothing was saved or sent. Users will trust things that didn't happen.
5. **Phone-sharing privacy leak (High).** Logging out doesn't wipe the local message database or the device encryption keys. The next person who signs in on that phone can see the previous user's decrypted messages and is tied to the previous user's device key.

---

## 2. Findings table

Severity: **C** = Critical, **H** = High, **M** = Medium, **L** = Low.

| ID | Sev | Category | File:line | Problem | Why it matters | Recommended fix |
|---|---|---|---|---|---|---|
| F01 | C | Security / Auth | `lib/features/auth/data/auth_repository.dart:20-22, 39-85, 186-195` | Password is derived as `'OurNest#Family2026!' + email`. Login tries `signInWithPassword` with it first. After an OTP login, `_bindInstantKeyAfterVerify` **sets the account password to that value**. The string is in the shipped `landing/app/main.dart.js` (3 matches). | Anyone with the public anon key and a victim's email can take over their account and see everything RLS allows that user to see. | Remove "instant" password login completely and use email OTP / magic link only. Reset or rotate every existing user's password (Supabase admin). Turn on "Confirm email" in Supabase Auth. |
| F02 | C | Logic / Data | `lib/features/chat/data/chat_repository.dart` (whole file), `lib/core/database/app_database.dart:36-40,113-160` | No code ever reads old messages from the `messages` table; only live Realtime events are processed. On web, messages live in an in-memory `Map`. | Messages sent while the app is closed are lost forever on that device. A new phone, reinstall or browser refresh means an empty chat. | Add a "catch-up sync" that, on open, fetches messages newer than the last stored `created_at` (plus their `message_keys`) and decrypts them. Use persistent storage on web (drift wasm/IndexedDB). |
| F03 | H | Logic / Realtime | `chat_repository.dart:99-121` + `supabase/migrations/…0002…sql:84-94` | The message row is inserted **before** its `message_recipients` rows. Realtime checks RLS on the insert event, and at that moment the recipient isn't listed yet, so the event is probably filtered out for recipients. **Needs verification on two real devices.** | If confirmed, recipients never receive messages live either, and together with F02 chat would not work at all. | Insert message, recipients and keys in one transaction via an RPC (`send_message`), or have clients listen to `message_recipients` / `message_keys` inserts instead. |
| F04 | H | Feature not wired | `pubspec.yaml` (no `firebase_messaging`), `lib/core/notifications/notification_service.dart` (never called), `supabase/functions/push-dispatcher/index.ts:98-105` | No FCM token is ever obtained or stored. `NotificationService.init()` and `showLocalMessageNotification()` are never called. The edge function uses the legacy `fcm/send` API, which Google shut down in 2024. No database webhook or trigger is created in the migrations. | Users get **no notifications** for messages or alarms when the app isn't open. | Add `firebase_messaging`, save the token to `user_devices.fcm_token`, migrate the function to the FCM HTTP v1 API with a service account, and create the webhook in a migration. |
| F05 | H | Feature not wired | `lib/features/alarm/presentation/alarm_controller.dart:56-60, 69-92`, `alarm_scheduler_service.dart` | An alarm is scheduled only on the creator's own phone. Nothing schedules the escalation alarm on Amma/Dad's phones when the alarm message arrives, and "I'm awake" cancels nothing on other phones. `cancelAlarm` "for everyone" only cancels locally. | The main "shared wake-up with escalation" promise doesn't work. | On receiving an `alarm` message, call `scheduleAlarm` for participants. On receiving an `alarm_event` ack, call `cancelAlarm`. |
| F06 | H | Config | `android/app/src/main/AndroidManifest.xml` (no `ScheduledNotificationReceiver` / `ScheduledNotificationBootReceiver`) | `flutter_local_notifications` needs these receivers declared for `zonedSchedule` to fire and to survive reboot. Also, the plugin's `initialize()` is never called before scheduling (`alarm_scheduler_service.dart:22-46`). **Needs verification on a device.** | Alarms may never ring, even on the owner's phone. | Add the receivers per the plugin README and call `initialize()` once at startup. |
| F07 | H | Fake success | `lib/features/family/data/family_repository.dart:283-296` | If `request_family_link` throws for *any* reason (wrong code, offline, permission), the code invents a link with `status: 'active'` and shows it. | The user sees "connected" to a family that doesn't exist or never agreed. | Remove `_localFallbackLinks` and `_peaceOverrides`, and show the real error. |
| F08 | H | Fake success | `lib/features/family/presentation/family_screen.dart:1026-1048` and `~1287` (Family-to-Family send) | "Multi-Group Broadcast" and "Send Across Family Tree" only post a labelled message into **your own** family chat, then say "Broadcast delivered to …". | Misleading. Linked families never receive anything. | Either build real cross-family delivery (needs schema plus RLS using `are_families_linked`) or hide the feature and label it "coming soon". |
| F09 | H | Fake success | `lib/features/reminder/presentation/widgets/reminder_card.dart:127-134` | "Add to My Device Calendar" only shows a "Reminder scheduled" snackbar. | Users think they'll be reminded, but they won't be. | Schedule a local notification or use a calendar plugin, or remove the button. |
| F10 | H | Fake success / data loss | `lib/features/profile/data/profile_repository.dart:30-60` | If all three upsert attempts fail, it returns the unsaved profile as if it were saved. | The profile looks saved but is lost. Splash then sends the user back to profile setup. | Rethrow and show an error. Remove the "schema not migrated" fallbacks once migrations are confirmed. |
| F11 | H | Security / Privacy | `lib/core/crypto/device_key_manager.dart:19-53`, `auth_repository.dart:198-200`, `app_database.dart:66-79` | Device keys and device ID are stored under fixed names, not per user. Sign-out doesn't clear secure storage or the local SQLite messages. | On a shared phone the next user inherits the previous user's decrypted messages (same family) and device row. Their own messages are encrypted to the old user's device. | Key the storage by user ID and wipe local DB + keys on sign-out (and revoke the device row). |
| F12 | H | Security / RLS | `supabase/migrations/20261103000004…sql:67-88`, `family_repository.dart:299-305` | A requesting admin can insert a link with `status='active'` directly, or "approve" their own request, because the insert/update policies have no `with check` on status. | The target family's approval step can be skipped. | Allow `status='pending'` only on insert. Allow the switch to `active` only by the target family's admin (via an RPC). |
| F13 | H | Logic | `family_repository.dart:57-68` + `join_family` RPC | `getCurrentUserMembership()` uses `.maybeSingle()`. If a user belongs to 2 families (the join RPC allows it), it throws. Splash catches the error and sends the user to `/profile-setup` in a loop. | A user who joins a second family is locked out of the app. | Decide the business rule (see Q1). Either block a second family in `join_family`, or support choosing a family. |
| F14 | H | Release | `android/app/build.gradle:34` | Release build is signed with the **debug** key. | Can't publish to Play Store. Anyone can sign an "update" with the public debug key, and users can't upgrade once you switch keys. | Create a release keystore (kept out of git) and a `signingConfigs.release`. |
| F15 | M | Privacy / Android | `AndroidManifest.xml:37-38` | `showWhenLocked="true"` and `turnScreenOn="true"` are set on the **main** activity. | The family chat can show over the lock screen without unlocking. | Remove them from the main activity and use a separate full-screen-intent activity only for ringing alarms. |
| F16 | M | RLS / Business rule | `…0001…sql:120-126`, `family_screen.dart:242-260` | The admin can "leave" (delete own row) without transferring the admin role, leaving a family with no admin. | Nobody can approve new members or rename the family. | Block the last admin from leaving unless they transfer admin first (in RLS or the RPC). |
| F17 | M | RLS / Flow | `…0001…sql:59-74, 128-137` | `shares_family_with` requires **both** users to be active, so the admin can't read a pending applicant's profile. The pending list shows "Family Member" (`family_member_model.dart:33`). | The admin approves strangers blind. | Let admins read the profiles of pending applicants to their own family. |
| F18 | M | RLS | `…0002…sql:99-121` | `message_recipients` and `message_keys` inserts allow any `user_id` / device, even outside the family. The `messages` update policy doesn't re-check family membership. | Outsiders can be made "recipients" (they see metadata only, not content). Data integrity is weak. | Add `is_active_member` checks for the recipient, and check `family_id` in the update `with check`. |
| F19 | M | Security / DB | `…0001…sql:29-74`, `…0004…sql:52-66, 91-145` | `security definer` functions (`is_active_member`, `is_family_admin`, `shares_family_with`, `are_families_linked`, `request_family_link`) don't `set search_path`. | This is a known Postgres privilege-escalation pattern and the Supabase linter flags it. | Add `set search_path = public` to each. |
| F20 | M | Security | `join_family` RPC (`…0001…sql:205-247`) | No rate limit. Invite codes never expire or rotate. The RPC returns the family **name** for any valid code. | Codes can be brute-forced (32^6 ≈ 1 billion, but unlimited tries) and family names enumerated. Leaked QR codes work forever. | Add an attempt limit, an option to regenerate the code, and only return the name after approval. |
| F21 | M | Security | `chat_repository.dart:174-238` | Presence and read/delivery receipts use a public Realtime broadcast channel named `family_chat_<familyId>`. It isn't marked private, so anyone authenticated who knows the UUID can join. | Fake read ticks, plus online/offline status visible to outsiders. | Use Realtime private channels with RLS on `realtime.messages`. |
| F22 | M | Logic | `app_database.dart:44-56, 104-108` | The DM thread shows **every** "selected" message I sent to anyone, plus all of theirs. Messages sent to "selected members" from the family chat vanish from the family thread. | Wrong messages appear in the wrong chats, which is confusing and a minor privacy issue. | Filter DMs by exact recipient set `{me, other}` and show "selected" group messages in the family thread with a badge. |
| F23 | M | UX / Error handling | `lib/features/chat/presentation/chat_screen.dart:74-87` | Text is cleared before sending, and the result (`false`) is ignored. | If sending fails (offline), the message just disappears with no error. | Keep the text until success, show an error, and offer retry. |
| F24 | M | Performance | `chat_screen.dart:399-410` | On **every rebuild**, it broadcasts a separate `read_ack` for **every** incoming message ever loaded. | Floods the Realtime channel and drains battery and quota. | Send acks only for new, unacknowledged messages, batched in one payload. |
| F25 | M | Security / Web | `device_key_manager.dart:30-34` (web), `app_database.dart:36` | On web/PWA the private key is stored by `flutter_secure_storage` web (browser localStorage + WebCrypto) and messages are memory-only. | Any XSS or shared computer exposes the key. The web experience loses data. | Document the web risk and consider not storing keys on web, or encrypting them with a passcode. |
| F26 | M | Routing | `lib/core/router/app_router.dart:17-87` | No `redirect` guard and no `errorBuilder`. `ournest://invite/...` deep links (manifest line 68) don't match any route (`/join-family` expects `?code=`). **Needs verification.** | Screens like `/home` open without login and may show errors. Scanned QR deep links may show a GoRouter error page. | Add an auth/membership redirect, map `/invite/:code`, and add a friendly error page. |
| F27 | M | iOS config | `ios/Runner/Info.plist` | `NSLocationWhenInUseUsageDescription` is missing, but location sharing uses `geolocator`. | iOS native builds will crash or be rejected when sharing location. | Add the key with a clear message. |
| F28 | M | Deployment | `landing/Start-OurNest-Desktop.bat:11`, `pubspec.yaml` assets | The "Windows Desktop app" is the web build served by `python -m http.server`. Without Python it opens a **hardcoded LAN IP** over plain http (`192.168.18.19:8080`). `.env` is bundled as an asset and shipped in `landing/app/assets/.env` and the zip. | Breaks on most PCs and could point users to an untrusted machine. Shipping `.env` is risky if a secret is ever added to it. | Ship a real `flutter build windows` or just a PWA link. Use `--dart-define` instead of bundling `.env`. |
| F29 | M | Dependencies | `pubspec.yaml`, `checks` output | `sodium_libs` is **discontinued** (replaced by `sodium`). Flutter 3.24.5 is 2 years old. 143 packages are behind and 21 are held back by constraints. | No future security fixes for the crypto library. | Plan an upgrade: Flutter stable, `sodium_libs` → maintained version, re-test crypto. |
| F30 | M | Tests | `supabase/tests/*.sql` | The SQL tests `delete from` real tables and insert profiles without matching `auth.users` (FK). They also run as superuser, so RLS isn't really exercised. **Needs verification.** | Running them against production could delete data, and they don't prove RLS works. | Run them only on a local Supabase (`supabase start`) with pgTAP and `set role authenticated` + JWT claims. |
| F31 | M | Error handling | `lib/main.dart:15-23`, `env.dart:7-12`, `supabase_client.dart:14-23`, many `catch (_) {}` | Errors are swallowed silently throughout. If Supabase init fails, the app continues and crashes later at `Supabase.instance`. | Failures are invisible and impossible to debug. | Log errors (e.g. Sentry or Crashlytics) and show a "can't connect, retry" screen. |
| F32 | M | Data quality | `family_repository.dart:191-240` | Linked family names come from `getFamily()`, but RLS on `families` only allows *your own* family. The result is always "Connected Family" / "------". The code also queries once per link (N+1). | The family tree UI shows placeholders. | Return linked family names from an RPC that checks `are_families_linked`. |
| F33 | L | Security | `lib/core/constants/env.dart:14-19` | The production URL and anon key are hardcoded as a fallback. | The anon key is public by design, but every build (including tests) silently talks to production. | Use `--dart-define` per environment and fail loudly if missing. |
| F34 | L | Placeholder | `lib/features/chat/presentation/widgets/native_sponsor_card.dart`, `home_chat_screen.dart:147` | A hardcoded "SPONSORED – Family Photobooks" ad with no link appears in a "private family" app. | It looks like an ad network is present, which hurts trust. | Remove it or make it a real, opt-in feature. |
| F35 | L | Placeholder | `lib/features/settings/presentation/settings_screen.dart:206-211, 240` | The "Alarm & Reminders Permission" tile always says "ready" and does nothing. "About" says `v1.2.1 (Build 4)`, but the pubspec says `1.2.3+6`. `netlify.toml` also hardcodes v1.2.1. | Misleading status and wrong version shown. | Check the real permission status and read the version from `package_info_plus`. |
| F36 | L | Lint | `flutter analyze` | 28 issues: 14 warnings (unused imports/field, pointless `?.`/`!`), 14 infos. | Minor, but the analyzer exits with code 1 and would fail CI. | Fix the warnings. |
| F37 | L | Code smell | `chat_screen.dart:66-86` | `replyToId` stores the reply **text snippet**, not the message ID. | You can't jump to the original message, and the name is misleading. | Store the ID and render the snippet from it. |
| F38 | L | Performance | `lib/core/crypto/media_crypto_service.dart:43, 81, 116` | The decrypted-media cache never evicts entries. | Memory grows with every photo or voice note viewed. | Use an LRU cache with a size limit. |
| F39 | L | Maintainability | `family_screen.dart` (3,020 lines), `smart_family_composer.dart` (1,047), `help_guide_screen.dart` (1,027) | These files are huge and mix UI, business logic and copy text. | Hard to change safely. | Split them into widgets and controllers. |
| F40 | L | Correctness | `device_key_manager.dart:70-71` | Windows, web, Linux and macOS are all recorded as platform `'android'` (the DB check only allows android/ios). | Wrong device data, and push targeting will break later. | Extend the check constraint (`web`, `windows`, …). |
| F41 | L | Config | `pubspec.yaml` assets `assets/images/` | The folder is empty and untracked, so builds from a fresh clone can fail ("unable to find directory"). **Needs verification.** | CI or a fresh clone may not build. | Add a `.gitkeep` or remove the entry. |
| F42 | L | Repo hygiene | `landing/app/**`, `landing/*.zip` committed; `landing/ournest.apk` git-ignored | Build outputs are committed, but the APK isn't. If Netlify deploys from git, `/ournest.apk` returns 404. **Needs verification.** | The download link may be broken, and the repo is bloated. | Build in CI/Netlify, or upload artifacts manually and stop committing builds. |

---

## 3. Automated check output (actual results)

Environment: `Flutter 3.24.5 • channel stable • 2024-11-13 • Dart 3.5.4`

### 3.1 `flutter pub get`
```
Got dependencies!
1 package is discontinued.
143 packages have newer versions incompatible with dependency constraints.
```

### 3.2 `flutter analyze` – **exit 1, 28 issues**
```
warning - Unused import: 'dart:convert' - lib\features\alarm\domain\shared_alarm_model.dart:1:8
warning - Unused import: '../../../family/domain/family_member_model.dart' - lib\features\chat\presentation\widgets\member_picker_sheet.dart:5:8
warning - The value of the field '_isRecording' isn't used - lib\features\chat\presentation\widgets\voice_recorder_sheet.dart:24:8
warning - invalid_null_aware_operator - lib\features\family\presentation\family_screen.dart:2108:40, 2118:40
warning - unnecessary_non_null_assertion - lib\features\family\presentation\family_screen.dart:2109:40, 2119:40
warning - invalid_null_aware_operator - lib\features\profile\presentation\widgets\member_profile_sheet.dart:364:34, 374:34
warning - unnecessary_non_null_assertion - member_profile_sheet.dart:364:61, 375:40, 376:40
warning - Unused import: '../../family/presentation/family_controller.dart' - lib\features\settings\presentation\settings_screen.dart:10:8
info    - 'anonKey' is deprecated … Use publishableKey instead - lib\core\network\supabase_client.dart:16:9
info    - unnecessary_import dart:typed_data - device_key_manager.dart:2:8, voice_recorder_sheet.dart:2:8
info    - prefer_const_constructors ×9, prefer_interpolation_to_compose_strings ×2, prefer_const_literals ×1, prefer_const_declarations ×1 (test/unit/family_test.dart:83)
28 issues found. (ran in 111.5s)
```
No type errors. There is no TypeScript lint or type check set up for the edge function.

### 3.3 `flutter test --coverage` – **29 / 29 passed**
```
00:19 +29: All tests passed!
coverage (lines in files loaded by tests): 304 / 733 = 41.5%
```
Important context: the tests only cover **pure models and parsers** (payload JSON, alarm time parser, reminder model, help search). `crypto_test.dart` doesn't actually encrypt or decrypt anything. The 41.5% only counts the ~730 lines the tests touch; the whole `lib/` is ~18,200 lines, so **real coverage is about 2%**. No widget, repository, RLS or integration tests run. (Running the tests created a `coverage/` folder in the project. It's safe to delete.)

### 3.4 `flutter pub outdated` (summary)
```
21 dependencies are constrained to versions that are older than a resolvable version.
Discontinued: sodium_libs (replaced by sodium), flutter_secure_storage_macos, js,
              build_resolvers, build_runner_core, macros
```

### 3.5 `flutter build web --release` – **built OK (exit 0)**
```
Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons).
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 27116 bytes (98.4% reduction).
Compiling lib\main.dart for the Web...   120.0s
√ Built build\web
```
The warning means some code uses `CupertinoIcons`, but the `cupertino_icons` package isn't in `pubspec.yaml`, so those icons will show as empty boxes (finding F43). I didn't build the Android APK, iOS or Windows targets: the Android SDK, Xcode and Windows toolchain weren't verified in this session, and iOS can't be built on Windows.

**F43 (L, Build):** add `cupertino_icons` to `pubspec.yaml`, or replace the `CupertinoIcons` usages.

### 3.6 Vulnerability audit
Dart/pub has no `npm audit` equivalent; the discontinued-package list above is the closest signal. The edge function imports `deno.land/std@0.168.0` (2022) and an **unpinned** `esm.sh/@supabase/supabase-js@2`, so pin exact versions.

### 3.7 Secret scan (`git grep` across history)
- No service-role key, private key or third-party API key is committed. `.env` is git-ignored ✅.
- The production anon key and URL are hardcoded in `env.dart`. They're public by design, so this is low risk.
- `.env` is bundled into `landing/app/assets/.env` and `OurNest-Windows-Desktop.zip`. It currently holds only URL, anon key and APP_ENV.
- ⚠️ The derived-password prefix `OurNest#Family2026!` appears in the public `landing/app/main.dart.js` (see F01).

---

## 4. User flow maps (per role)

**Roles:** Guest (not logged in) · New user · Pending applicant · Family member · Family admin · Linked-family admin.

```
GUEST / NEW USER – Sign-in
 Splash (1.2s) → /phone-login (actually email) → enter email → [instant password login ⚠F01]
   ├─ success → Splash checks profile → /profile-setup → save profile (⚠F10 may silently fail)
   └─ fallback → email OTP → /otp-verify → enter code or paste magic link → password silently set ⚠F01
 Data saved: auth.users, profiles     User sees: profile setup, then family entry

NEW USER – Create family (becomes ADMIN)
 /family-entry → Create → name + my relation → RPC create_family
 Data saved: families, family_members(admin, active)     User sees: /home with invite code / QR

NEW USER – Join family (becomes PENDING)
 /family-entry → Join → code or scan QR → my relation → RPC join_family
 Data saved: family_members(pending)     User sees: /pending-approval (can cancel = leave)
 ⚠ No auto-refresh when approved: user must reopen or tap a refresh button (needs verification)

ADMIN – Approve member
 /family → pending list (names show as "Family Member" ⚠F17) → approve, optionally set relation → RPC approve_member
 Data saved: status=active     Admin sees: member moves to the active list

MEMBER – Family chat
 /home → Family Group → /chat/family → type → encrypt → insert messages + recipients + keys
 Others see: only if their chat screen is open at that moment (⚠F02/F03); no push (⚠F04)

MEMBER – Private / selected message
 /home → tap a member → /chat/<userId> → send (audience=selected)
 ⚠ DM thread mixes in unrelated "selected" messages (F22)

MEMBER – Photo / voice note
 chat → camera/gallery or mic → encrypt file → upload to private bucket media/<familyId>/… → send message with key
 Others see: decrypt on view ✅ (if they got the message at all)

MEMBER – Shared alarm
 chat → type "wake me up 8am" (auto-detected) or alarm sheet → send alarm message + schedule on MY phone
 ⚠ Participants' phones never schedule escalation (F05); may not fire at all (F06)

MEMBER – Reminder / checklist / location
 chat → sheet → sent as an encrypted text message ✅; "Add to calendar" is fake (F09)

ADMIN – Link another family ("Connected Nests")
 /family → Link → other family's code → RPC request_family_link (pending)
   ⚠ Any error → fake "active" link (F07); requester can self-approve (F12); names show placeholders (F32)
 Target ADMIN → incoming request → approve → status=active

ADMIN – Multi-group broadcast / Family-to-Family message
 /family → Broadcast → pick circles → Send → ⚠ goes only to your own family chat (F08)

ADMIN – Rename / remove member / transfer admin / leave
 /family → dialogs with confirmation ✅ → direct table update/delete or RPC
 ⚠ Admin can leave with no successor (F16)

ANY – Settings
 /settings → edit profile, large text, dark mode, help, sign out
 ⚠ Sign-out leaves local messages and keys on the device (F11)
```

---

## 5. Flow issues table

| ID | Flow / Screen | Steps to reproduce | What happens now | What should happen | Sev | Proposed fix |
|---|---|---|---|---|---|---|
| U01 | Login | Use only Supabase API + a victim's email: `signInWithPassword(email, 'OurNest#Family2026!'+email)` | Logged in as the victim | Login impossible without inbox access | C | F01 |
| U02 | Chat | User A closes the app; B sends 3 messages; A opens chat | A sees none of them, ever | A sees all 3 | C | F02 catch-up sync |
| U03 | Chat (web/PWA) | Open chat in browser → refresh | Chat is empty | History reloads | C | F02 + persistent web DB |
| U04 | Chat send | Turn on airplane mode → type → send | Text vanishes, no error | Error + retry, text kept | M | F23 |
| U05 | Notifications | Close app → family member sends message/alarm | No notification | Push notification | H | F04 |
| U06 | Shared alarm | A sets "wake me 7am, escalate Amma after 5 min"; A ignores it | Amma's phone never rings | Amma's phone rings at 7:05 | H | F05/F06 |
| U07 | Link families | Enter a wrong / random 6-char code | "Linked" family appears as active | Error "No family found" | H | F07 |
| U08 | Broadcast | Family → Broadcast → choose 3 nests → send | "Delivered to 3 Nests", but only your own family receives it | Real delivery, or the feature is hidden | H | F08 |
| U09 | Reminder card | Tap "Add to My Device Calendar" | Snackbar "Reminder scheduled", nothing scheduled | Calendar event or local reminder created | H | F09 |
| U10 | Profile setup | Save profile while the DB rejects it (e.g. phone already used by someone else + other error) | Moves on as if saved; next launch asks again | Clear error message | H | F10 |
| U11 | Shared phone | A logs out → B logs in (same family) | B can see A's private messages; B's device key = A's device | Clean slate per user | H | F11 |
| U12 | Second family | Active member joins a second family with another code | Splash crashes into a profile-setup loop | Rule enforced (block, or let them pick a family) | H | F13 |
| U13 | Approve applicant | Applicant joins → admin opens pending list | Name shows "Family Member" | Applicant's name/photo shown | M | F17 |
| U14 | Admin leaves | Only admin taps Leave Family | Family left with no admin | Must transfer admin first | M | F16 |
| U15 | Pending screen | Admin approves while applicant waits on the pending screen | Applicant stays on pending until manual refresh or restart (**needs verification**) | Auto-move to home | M | Listen on `family_members` row via Realtime |
| U16 | Deep link | Scan QR with phone camera → `ournest://invite/CODE` | Likely GoRouter error page (**needs verification**) | Opens Join screen prefilled | M | F26 |
| U17 | Lock screen | Lock phone → app comes to front (e.g. alarm/notification) | Chat visible without unlocking | Only alarm screen over the lock screen | M | F15 |
| U18 | DM thread | Send "selected" message to Dad, then open DM with Mom | Message to Dad appears in Mom's thread | Only Mom ↔ me messages | M | F22 |
| U19 | Silent Curtain | Set peace mode → restart app | Setting may be lost (in-memory override); DB update errors are hidden | Persisted or clear error | M | Remove `_peaceOverrides`, show errors |
| U20 | Desktop app | Run `Start-OurNest-Desktop.bat` on a PC without Python | Opens `http://192.168.18.19:8080` (developer's LAN) | Opens the app | M | F28 |
| U21 | First use, no data | New family, chat empty | Empty-state message shown ✅ | – | – | OK |
| U22 | Destructive actions | Remove member / leave family | Confirmation dialogs present ✅ | – | – | OK. Message delete: confirmation **needs verification** |
| U23 | Settings | Tap "Alarm & Reminders Permission" | Nothing happens; always says "ready" | Opens permission settings, shows real state | L | F35 |

---

## 6. Missing tests (most important first)

1. **RLS tests on a local Supabase** (pgTAP, `set role authenticated` with JWT claims): a stranger can't read messages, families or profiles; a pending user can't read chat; a non-admin can't approve or remove; the requester can't self-approve a family link.
2. **Auth test**: guessing a password must not log a user in (regression test for F01).
3. **Crypto round-trip**: encrypt → seal key → unseal → decrypt with real libsodium, plus "wrong device key fails".
4. **Chat sync**: messages sent while offline are fetched on reconnect, with no duplicates (F02).
5. **Repository error tests**: `linkWithFamily`, `upsertProfile` and broadcast must surface errors, not fake success (F07–F10).
6. **Sign-out wipe**: after sign-out, the local DB and secure storage are empty (F11).
7. **Multi-membership**: `getCurrentUserMembership` with 2 rows (F13).
8. **DM filter**: query returns only messages between exactly the two users (F22).
9. **Alarm**: receiving an alarm schedules escalation for participants, and an ack cancels it (F05).
10. **Router guard widget tests**: unauthenticated `/home` redirects to login; `/invite/CODE` opens Join (F26).

---

## 7. Questions for the owner (business decisions)

- **Q1.** Can one person belong to **more than one family** at a time? (The code half-supports it and crashes; see F13.)
- **Q2.** Should "Connected Nests" (linked families) actually exchange messages, or is it only a family-tree display for now? This decides whether to build F08 properly or hide it.
- **Q3.** What should happen to old messages when a member is removed or leaves? Keep their access to history, or revoke it?
- **Q4.** Can the admin leave without naming a successor? If the admin deletes their account, who takes over?
- **Q5.** Is the "SPONSORED" card a planned revenue feature? If yes, how does that fit the "private, no tracking" promise?
- **Q6.** Should invite codes expire or be regenerable? Should the admin be able to turn invites off?
- **Q7.** Is the web/PWA meant to be a full client (then it needs persistent storage and a key-backup story) or a light companion?
- **Q8.** Is the Windows "desktop app" required? If so, do you want a real Windows build or just "install the PWA from Edge"?
- **Q9.** Are you OK with forcing all existing users to log in again by email OTP after the F01 fix (their passwords will be reset)?
- **Q10.** Do you have, or want, a separate **staging Supabase project** so testing never touches real family data?

**Decisions (2026-11-05, owner asked for Claude's recommendation on Q1/Q2/Q4):**
- **Q1 → one family per person, for now.** The server refuses joining a second family with a clear message; an older pending request elsewhere is replaced. Relatives stay connected through "Connected Nests". A family switcher can come later. *(implemented in migration `…000009`)*
- **Q2 → not now.** Real cross-family delivery means sharing keys and data between families, a large privacy and security change. The honest "posts to your own chat" wording from Phase D stays. Revisit after chat, push and alarms are proven on real phones.
- **Q4 → no.** While other active members remain, the last admin must make someone else admin before leaving. A lone admin may leave. Deleting the whole family or an account isn't blocked. *(implemented in migration `…000009`)*
- **Q5 → keep the sponsored card** (owner's decision). It's static: no tracking, no network calls.
- Still open: Q3, Q6 (partly done: admins can now issue a new code), Q7, Q8, Q9, Q10.

---

## 8. Prioritised fix plan

**Phase A – Critical security (do first, ideally today)**
1. F01: remove derived-password login; OTP only; reset all existing passwords in Supabase; enable email confirmation.
2. F19, F12, F18: harden SQL (`search_path`, link approval rules, recipient checks) in a new migration.
3. F11: per-user key storage plus a full local wipe on sign-out.
4. F15: remove `showWhenLocked` / `turnScreenOn` from the main activity.

**Phase B – Make core chat actually work**
5. F03: atomic `send_message` RPC (or listen on recipient rows), then verify on 2 devices.
6. F02: catch-up sync from the server plus persistent web storage.
7. F23, F24, F22: send errors and retry, batched read receipts, correct DM filtering.

**Phase C – Notifications & alarms**
8. F04: Firebase Messaging plus FCM HTTP v1 edge function and webhook migration.
9. F05, F06: Android receivers, plugin init, participant escalation and ack-cancel.

**Phase D – Remove fake success / half-built features**
10. F07, F08, F09, F10, F32, U19: show real errors; hide or finish broadcast, linked-family messaging and the calendar button (depends on Q2).
11. F13, F16, F17: membership rules (depends on Q1, Q4).
12. F34, F35: remove the sponsor card (Q5) and fix the settings tile and version label.

**Phase E – Release readiness**
13. F14: release signing key. F27: iOS location string. F26: router guard plus deep links.
14. F28, F33, F42: environment config via `--dart-define`, stop bundling `.env`, real desktop and download pipeline.
15. F20, F21: invite-code limits, private Realtime channels.

**Phase F – Quality**
16. F29: upgrade Flutter and dependencies; replace discontinued `sodium_libs`.
17. F36–F41: analyzer warnings, split giant files, media cache, platform values.
18. Add the tests in section 6 and a local Supabase for F30.

---

---

## 9. Fix log

### Phase A – Critical security (done 2026-11-05)

| Finding | Status | What changed (simple words) | Files |
|---|---|---|---|
| F01 | ✅ Fixed in app · ⚠️ **owner action needed on server** | Removed the "instant" password login completely. Sign-in now always sends an email code, and the app never sets a password any more. Added a basic email format check. Button text changed from "Sign In (Instant)" to "Send Sign-In Code". | `lib/features/auth/data/auth_repository.dart`, `lib/features/auth/presentation/auth_controller.dart`, `lib/features/auth/presentation/phone_input_screen.dart` |
| F01 (server) | ⏳ Waiting for you | Existing accounts **still have the guessable password** until you run the reset script. The app change alone does not close the hole. | `supabase/manual/2026-11-05_reset_derived_passwords.sql` |
| F11 | ✅ Fixed | Device encryption keys are now stored **per user**. Old shared keys are moved over only if the server confirms that device belongs to the signed-in user; otherwise they're deleted. On sign-out (or if a different account signs in, or the session expires) the app wipes local decrypted messages, cached photos/voice notes, in-memory keys and live chat state. | `lib/core/crypto/device_key_manager.dart`, `lib/core/database/app_database.dart`, `lib/core/crypto/media_crypto_service.dart`, `lib/features/chat/data/chat_repository.dart`, `auth_controller.dart` |
| F15 | ✅ Fixed (needs a device check) | The chat no longer shows over the lock screen. Only a ringing alarm (notification payload `alarm_ring:` / `alarm_escalate:`) may appear over the lock screen and turn the screen on. | `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/ournest/app/MainActivity.kt` |
| F12 | ✅ Fixed (migration written, **not applied**) | A family can only *request* a link (status `pending`). Only the invited family's admin can approve it, and the two family IDs can't be changed later. | `supabase/migrations/20261105000005_security_hardening.sql` |
| F18 | ✅ Fixed (migration, not applied) | Message recipients must be active members of that message's family. Encrypted keys can only go to devices of those recipients. Edits can't move a message into another family. | same migration |
| F19 | ✅ Fixed (migration, not applied) | All privileged database functions now use a fixed `search_path`. | same migration |

**Trade-off to know about (F11):** sign-out now deletes the decrypted messages stored on that phone. Because the app can't yet download old messages from the server (F02, Phase B), signing out and back in currently means an **empty chat** until Phase B is done. The per-user keys are kept, so Phase B's catch-up sync will be able to restore that history.

**Checks after Phase A (actual results):**
```
flutter analyze   → 27 issues (was 28), 0 new; all pre-existing lint warnings/infos (Phase F)
flutter test      → 00:05 +43: All tests passed!   (29 old + 14 new)
flutter build apk --debug → √ Built build\app\outputs\flutter-apk\app-debug.apk  (Kotlin change compiles)
```

**New regression tests:** `test/unit/security_phase_a_test.dart`. They check:
- no password sign-in or derived-password string anywhere in `lib/`
- `sendOtp` never reports "authenticated"
- email validation works
- key storage names differ per user
- sign-out runs the cleanup first, and still signs out if cleanup fails
- the manifest has no lock-screen flags, and the alarm payload prefixes match the scheduler
- the migration contains the pending-only, target-admin, recipient and `search_path` rules

**Not verified yet (needs you or a real device):**
- The migration hasn't been run against any database. Please apply it to a **staging** project first (`supabase db push` against staging), then production.
- The alarm-over-lock-screen behaviour needs testing on an Android phone.
- The reset script must be run by you **after** the fixed app version is released. Old app versions re-set the guessable password after an OTP login.

### Owner action checklist for Phase A
1. Release the new app build (APK + web), so users stop running the old login code.
2. Supabase Dashboard → Authentication → Providers → Email → turn **ON "Confirm email"**.
3. Run `supabase/manual/2026-11-05_reset_derived_passwords.sql` in the SQL Editor. It resets passwords to random values and signs everyone out, but doesn't touch messages or families.
4. Apply `supabase/migrations/20261105000005_security_hardening.sql` (staging first).

Phase A was committed on branch `fix/audit-phase-a` (commit `0bf8265`). Not pushed.

### Phase B – Make core chat actually work (done 2026-11-05)

| Finding | Status | What changed (simple words) | Files |
|---|---|---|---|
| F03 | ✅ Fixed (migration written, **not applied**) | New database function `send_message` saves the message, its recipients and its keys **together in one step**, so Realtime can see the recipients when it decides who gets the live update. It runs with the user's own permissions, so all security rules still apply. Also added indexes for the sync queries. If the function isn't on the server yet, the app falls back to the old way, but **only** for "function not found"; any other error is shown to the user. | `supabase/migrations/20261105000006_atomic_send_message.sql`, `lib/features/chat/data/chat_repository.dart` |
| F02 | ✅ Fixed | New **catch-up sync**. Every time the chat connects or reconnects, the app downloads messages it doesn't have yet (in pages of 200) and decrypts them with one key lookup per batch. If the phone or browser has nothing stored (new phone, reinstall, web refresh, after sign-out), it restores the latest 300 messages. "Delete for everyone" from the last 7 days is applied too. Messages you sent from *another* of your devices now show up (before, they were skipped). | `chat_repository.dart`, `lib/core/database/app_database.dart` |
| F02 (web) | ✅ Solved by sync | Instead of adding a browser database, the web app now **re-downloads history from the server** after a refresh, and the device key is kept in the browser. This avoids storing decrypted messages in the browser. | same |
| F22 | ✅ Fixed | The recipient list now travels **inside the encrypted message**, so the server doesn't learn more. A private chat with Dad shows only messages between you and Dad. A "selected members" message to 3+ people shows in the family chat with its "selected" badge. Old messages without the list use the old rule, so nothing disappears. | `lib/features/chat/domain/message_payload.dart`, `lib/features/chat/domain/thread_filter.dart` (new), `app_database.dart` |
| F23 | ✅ Fixed | If sending fails, the typed text and the reply you were writing come back, and an error message explains why. Photo, voice, location and checklist sends also show an error now. Double-tapping Send no longer sends twice. | `lib/features/chat/presentation/chat_screen.dart` |
| F24 | ✅ Fixed | Read receipts are sent **once per message**, batched into one broadcast, instead of once per message on every screen refresh. Older app versions still understand the receipt (for the newest message in the batch). | `chat_repository.dart` |

**Limits to know about:**
- Messages sent **before** a device was registered can't be decrypted on that device; there's no key for it, and that's how end-to-end encryption works. A new phone sees history from the moment it was set up. Fixing this would need encrypted key backup (a business decision, see Q7).
- Sync runs when the chat connects or reconnects. It doesn't run in the background while the app is closed; that needs push notifications (Phase C).

**Checks after Phase B (actual results):**
```
flutter analyze  → 27 issues, 0 new (same pre-existing lint list)
flutter test     → 00:04 +57: All tests passed!  (43 + 14 new in test/unit/chat_phase_b_test.dart)
flutter build web --release → √ Built build\web
```

**Not verified yet:** both migrations (Phase A and B) still need to be applied, staging first. The live-delivery fix (F03) and the sync need a test with **two real devices or browsers** after the migrations are applied:
1. A sends while B is closed, then B opens: B should see the message.
2. Both are open: B should see A's message within a second.
3. Refresh the web app: history should come back.

### Updated owner checklist
1. Apply `20261105000005_security_hardening.sql`, **then** `20261105000006_atomic_send_message.sql` (staging first).
2. Do the two-device test above.
3. Release the new app, then do the Phase A steps (Confirm email ON, run the password reset script).

Phase B was committed on `fix/audit-phase-a` (commit `d396b2a`). Not pushed.

### Phase C – Notifications & alarms (done 2026-11-05)

| Finding | Status | What changed (simple words) | Files |
|---|---|---|---|
| F06 | ✅ Fixed (needs a phone test) | Added the three Android "receivers" the alarm plugin needs; without them scheduled alarms never fire and are lost after a reboot. The notification system is now set up once at app start. Notification IDs no longer depend on Dart's `hashCode`, which can differ between runs. The exact-alarm permission screen now only opens if the permission is actually missing. | `AndroidManifest.xml`, `lib/core/notifications/notification_service.dart`, `lib/core/platform/alarm_scheduler_service.dart`, `lib/main.dart` |
| F05 | ✅ Fixed (needs a two-phone test) | New **alarm coordinator**. When an alarm message arrives on Amma's phone (live, by catch-up sync or by push in the background), her phone schedules the escalation alarm. When the owner taps **I'm awake**, the ack cancels it on every phone, and the owner's cancel also cancels it everywhere. | `lib/features/alarm/data/alarm_coordinator.dart` (new), `chat_repository.dart`, `alarm_controller.dart` |
| F05 (new finding) | ✅ Fixed | The "I'm awake" screen **was never opened anywhere**, so owners couldn't confirm. Now tapping the alarm notification opens it, even when the app was closed, and the alarm card in chat has an **I'm awake** button. **Snooze** used to just close the screen; it now re-rings in 5 minutes. **Call** always called nobody; it now dials the owner's saved number. **Dismiss** now actually stops the alert. Cancel asks for confirmation; for non-owners it only silences their own phone. | `alarm_ringing_screen.dart`, `alarm_card.dart`, `lib/app.dart`, `app_router.dart` (`/alarm` route), `splash_screen.dart` |
| F04 | ✅ Fixed in code · ⚠️ **owner setup needed** | Added Firebase Messaging. After login the app saves this phone's push token, refreshes it when it changes, and removes it on sign-out. A push in the background wakes the app briefly to catch up the chat (and schedule alarm escalations), then shows a notification with **only the sender's name**, never the message text. Firebase settings come from build options, so **without them push is simply off** and nothing crashes. | `lib/core/notifications/push_service.dart` (new), `home_chat_screen.dart`, `auth_controller.dart`, `pubspec.yaml` (`firebase_core 4.7.0`, `firebase_messaging 16.2.0`) |
| F04 (server) | ✅ Rewritten (**not deployed, not type-checked**) | Push function moved from Google's shut-down legacy API to **FCM HTTP v1** with a service account. It only accepts calls carrying the shared secret, clears dead tokens, never reads message content and no longer returns internal error details. A new migration adds the missing database trigger, which reads the function URL and secret from Supabase Vault and never blocks sending if push fails. | `supabase/functions/push-dispatcher/index.ts`, `supabase/migrations/20261105000007_push_webhook.sql`, `supabase/manual/PUSH_SETUP.md` |

**Small behaviour choices made (tell me if you want them different):**
- While the app is open, only **alarms** show a pop-up notification. Normal messages just appear in the chat, to avoid a notification for every message you're already reading.
- iOS escalation uses "time-sensitive" instead of "critical" alerts. Critical alerts need a special entitlement from Apple.
- The alarm card's status label (active / acknowledged) still comes from the original alarm message. The "✓ I am awake!" message appears in the chat, but the card itself doesn't change colour yet (Phase D).

**Checks after Phase C (actual results):**
```
flutter analyze  → 21 issues (was 27), 0 errors, 0 new warnings
flutter test     → 00:05 +72: All tests passed!  (57 + 15 new in test/unit/alarm_push_phase_c_test.dart)
flutter build apk --debug   → √ Built build\app\outputs\flutter-apk\app-debug.apk
flutter build web --release → √ Built build\web
```

**Not verified yet:**
- The Edge Function. There's no Deno on this PC, so it hasn't been type-checked or run; test it after deploy (see logs tip in `PUSH_SETUP.md`).
- Real push delivery, background wake-up and alarm ringing on a locked phone all need real devices with Firebase configured.
- Background sync opens the local database from a second process. If the app is open in the background at the same time, new messages appear after reopening the chat rather than instantly.
- Web / PWA / Windows launcher: no push yet (needs web push, Phase E).

### Updated owner checklist
1. Apply migrations in order: `…000005` → `…000006` → `…000007` (staging first).
2. Follow `supabase/manual/PUSH_SETUP.md` (Firebase project, build options, function secrets, Vault secrets).
3. Two-phone tests: chat delivery (Phase B) plus push and shared alarm with escalation (Phase C).
4. Release the new app, then do the Phase A steps (Confirm email ON, run the password reset script).

Phase C was committed on `fix/audit-phase-a` (commit `a0cbd67`). Not pushed.

### Phase D – Remove fake success (done 2026-11-05)

| Finding | Status | What changed (simple words) | Files |
|---|---|---|---|
| F07 | ✅ Fixed | No more invented "active" links. A wrong code or no internet now shows the real reason (e.g. "No family found with invite code …"). After sending, the message says it's a **request** that the other admin must approve. | `lib/features/family/data/family_repository.dart`, `family_screen.dart` |
| U19 | ✅ Fixed | Silent Curtain / Peace Pause no longer keeps a hidden "pretend" copy on the phone. It's saved on the server or you see an error. Approve, policy toggle, unlink and lift curtain also report the real result. When the database quietly blocks a change (0 rows), that now counts as an error instead of "success". | same |
| F32 | ✅ Fixed (migration, not applied) | Linked families now show their **real name** (new secure function `get_linked_family_names`, with one query instead of one per link). The other family's invite code is **no longer shown**, because it would let people join that family. | `supabase/migrations/20261105000008_linked_names_and_applicants.sql`, `family_repository.dart` |
| F08 | ✅ Made honest (real delivery needs Q2) | "Multi-Group Broadcast" and "Send Across Family Tree" still post into **your own** family chat (that's all the system can do today), but now say so: "Posted in your family chat. Connected families don't receive broadcasts yet." The button is renamed "Post to Our Family Chat". Building real cross-family delivery waits for your answer to **Q2**. | `family_screen.dart` |
| (new) | ✅ Fixed | "Unlink Permanently" deleted the connection **without asking**. It now asks for confirmation first. | `family_screen.dart` |
| F09 | ✅ Fixed | "Add to My Device Calendar" only showed a message. It's now **"Remind Me on This Phone"** and really schedules a notification at the event time. It also says so if the time has passed, or if you're in the browser where this isn't available. | `reminder_card.dart`, `alarm_scheduler_service.dart` |
| F10 | ✅ Fixed | Profile save no longer pretends to succeed, and no longer silently drops your phone number when another account uses it. You now see a clear reason, e.g. "This phone number is already used by another OurNest account." | `lib/features/profile/data/profile_repository.dart`, `profile_setup_screen.dart` |
| F13 | ✅ Crash fixed (rule still needs Q1) | A user with two family memberships is no longer locked out. The app picks the **active** one (else the oldest). Whether two families should be allowed at all is still your decision (**Q1**). | `family_repository.dart` |
| F17 | ✅ Fixed (migration, not applied) | Admins can now see the name and profile of someone **waiting for approval**, instead of "Family Member". Only the admins of that family can see it. | migration `…000008` |
| (Phase C follow-up) | ✅ Fixed | The alarm card now changes to "✓ … is awake!" or "Cancelled" when that event arrives in the chat. | `lib/features/alarm/presentation/alarm_status_provider.dart` (new), `alarm_card.dart` |
| F35 | ✅ Fixed | The "Alarm & Reminders Permission" row shows the **real** state (allowed or not allowed) and asks for permission when tapped. The version label now reads `1.2.3 (Build 6)` from one constant, and a test fails if it ever differs from `pubspec.yaml`. | `settings_screen.dart`, `lib/core/constants/app_version.dart` (new) |
| F36 (part) | ✅ | Removed one unused import from Settings. | `settings_screen.dart` |

**Left alone on purpose (business decisions, see Questions):**
- **F16 (Q4):** an admin can still leave without naming a successor.
- **F34 (Q5):** the "SPONSORED" card is still there.
- **F08 / Q2:** real cross-family messaging isn't built.
- **F13 / Q1:** joining a second family is still allowed by the server.

**Note:** I tried `package_info_plus` for the version, but its current release needs Kotlin 2 and this Android project is on Kotlin 1.8.22. The build failed, so I removed it and used a checked constant. Upgrading Kotlin/AGP is part of Phase F.

**Checks after Phase D (actual results):**
```
flutter analyze  → 16 issues (was 21), 0 errors, 0 new
flutter test     → 00:06 +87: All tests passed!  (72 + 15 new in test/unit/honest_ui_phase_d_test.dart)
flutter build apk --debug   → √ Built build\app\outputs\flutter-apk\app-debug.apk
flutter build web --release → √ Built build\web
```

**Not verified yet:** migration `…000008` (apply after 5, 6 and 7, staging first). The family-link screens need a click-through with two real families after the migrations are applied.

### Updated owner checklist
1. Apply migrations in order: `…000005` → `…000006` → `…000007` → `…000008` (staging first).
2. `supabase/manual/PUSH_SETUP.md` for push.
3. Two-phone / two-family tests: chat, push, shared alarm, link request plus approval, pending applicant name visible to admin.
4. Release the new app, then do the Phase A steps (Confirm email ON, run the password reset script).
5. Answer **Q1, Q2, Q4, Q5** so the remaining Phase D items can be finished.

Phase D was committed on `fix/audit-phase-a` (commit `e728676`). Not pushed.

### Phase E – Release readiness (done 2026-11-05)

| Finding | Status | What changed (simple words) | Files |
|---|---|---|---|
| F14 | ✅ Fixed | Release builds no longer use the public debug key without telling you. They now use **your own key** from `android/key.properties` (git-ignored). Without it, a release build **stops with a clear message**. For a local test only: `flutter build apk --release --android-project-arg=ournest.allowDebugSigning=true` (prints a warning; never publish that APK). | `android/app/build.gradle` |
| F27 | ✅ Fixed | iPhone now explains why location is needed, so the native iOS app won't crash or be rejected when sharing location. | `ios/Runner/Info.plist` |
| F26 | ✅ Fixed | **Sign-in guard:** signed-out users can only see the splash and login screens, and after sign-out the app returns to login automatically. **Invite links** (`ournest://invite/CODE`, `…/join?code=CODE`) open the Join screen with the code filled in; if you weren't signed in, it continues there after sign-in. The email sign-in link no longer lands on an unknown page. Unknown links show a friendly "page not found" with a Home button instead of a red error. | `lib/core/router/route_guard.dart` (new), `app_router.dart`, `AndroidManifest.xml` (`flutter_deeplinking_enabled`) |
| F28 / F33 | ✅ Fixed | `.env` is **no longer bundled** into the web app, the Windows zip or the APK (confirmed: `build/web/assets` has no `.env`). Settings now come from build options (`--dart-define` / `--dart-define-from-file=env/staging.json`; template in `env/staging.example.json`, real files git-ignored). With no options, the same public production values as before are used, so nothing changes for current builds. Removed the `flutter_dotenv` package. | `lib/core/constants/env.dart`, `pubspec.yaml`, `env/`, `.gitignore`, `main.dart` |
| F28 (desktop) | ✅ Fixed | The Windows launcher no longer opens `http://192.168.18.19:8080` (a private machine on the developer's network). Without Python it now explains how to install the web app from Edge or Chrome. | `landing/Start-OurNest-Desktop.bat` |
| F41 | ✅ Fixed | Removed the empty `assets/images/` entry that could break fresh builds. | `pubspec.yaml` |
| F20 | ✅ Fixed (migration, not applied) | At most **10 wrong invite codes per hour** per account. The failed attempt is saved before replying, so the limit really counts. The admin gets **"Create a new invite code"** (with confirmation) to stop a leaked code or QR from working. | `supabase/migrations/20261105000009_invites_membership_realtime.sql`, `family_repository.dart`, `family_controller.dart`, `family_qr_scanner_modal.dart` |
| F21 | ✅ Fixed (needs a server setting) | The family chat's live channel (online status, ticks) is now **private**: only active members of that family may join. If the server isn't ready yet, the app falls back to the old public channel once, so chat keeps working during the rollout. | same migration, `chat_repository.dart` |
| Q1 / Q4 | ✅ Implemented as decided | One family per person; the last admin must hand over before leaving. The app shows the reason, e.g. "You are the only admin. Make another member admin before leaving the family." Before, leaving failed silently and still jumped to the "join a family" screen. | same migration, `family_screen.dart` |
| (new) | ✅ Fixed | Errors were shown as raw text such as "Bad state: …" or "PostgrestException(…)". There's now one helper that turns them into plain sentences. Removing a member and leaving also report the real result. | `lib/core/errors/friendly_error.dart` (new), `join_family_screen.dart`, `family_screen.dart` |

**Also fixed while testing:** a test caught that `/family` (6 letters) could be mistaken for an invite code. Bare-code links now only match the real invite alphabet (uppercase, no 0/O/1/I).

**Checks after Phase E (actual results):**
```
flutter analyze  → 16 issues, 0 errors, 0 new
flutter test     → 00:10 +110: All tests passed!  (87 + 23 new in test/unit/release_phase_e_test.dart)
flutter build apk --debug   → √ Built build\app\outputs\flutter-apk\app-debug.apk
flutter build apk --release (no key) → FAILURE: "Release signing key missing: create android/key.properties …"  ← intended
flutter build apk --release --android-project-arg=ournest.allowDebugSigning=true → √ Built app-release.apk (86.6MB)
flutter build web --release → √ Built build\web   (no .env in build/web/assets)
```

**Not verified yet / needs you:**
- **Signing key change.** Phones that installed the old debug-signed APK **can't update** to an APK signed with your new key; Android requires uninstall and reinstall. Do this once, now, while there are few users. Create the key with:
  ```bash
  keytool -genkey -v -keystore C:/keys/ournest-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ournest
  ```
  Then create `android/key.properties` (format in `build.gradle`). **Back up the .jks file and passwords.** If you lose them, you can never update the app again.
- **Old `.env` copies:** `landing/app/assets/.env` and `landing/OurNest-Windows-Desktop.zip` still contain the old bundled `.env` (public values only). They disappear when you rebuild the landing app and zip. I didn't delete them.
- **F21:** after applying migration `…000009`, go to Supabase → Realtime → Settings and turn **off "Allow public access"**; only then are private channels enforced.
- **Deep links:** test on an Android phone by scanning a family QR with the camera app. iOS can't open `ournest://` links yet, because the URL scheme isn't registered in `Info.plist`; that's only needed if you ship native iOS.
- **Join limit:** test on staging: 10 wrong codes, then the 11th should show "Too many wrong invite codes…".

### Updated owner checklist
1. Apply migrations in order: `…000005` → `…000006` → `…000007` → `…000008` → `…000009` (staging first).
2. Supabase → Realtime → Settings → turn off "Allow public access" (after step 1).
3. Create the release key and `android/key.properties`; back them up.
4. `supabase/manual/PUSH_SETUP.md` for push.
5. Rebuild `landing/app` (web) and the Windows zip, so the old bundled `.env` disappears.
6. Two-phone tests: chat, push, shared alarm, invite link and QR, link request and approval, admin-leave rule.
7. Release the new app (users with the old APK must reinstall once because of the new key), then do the Phase A steps (Confirm email ON, run the password reset script).

Phase E was committed on `fix/audit-phase-a` (commit `0631517`). Not pushed.

### Phase F – Quality (done 2026-11-05)

| Finding | Status | What changed (simple words) | Files |
|---|---|---|---|
| F36 | ✅ Fixed | `flutter analyze` now reports **No issues found** (it started at 28). Removed unused imports and an unused field, fixed pointless `?.` / `!`, and switched the deprecated Supabase `anonKey` parameter to `publishableKey` (same value, same behaviour). | several files |
| F38 | ✅ Fixed | Decrypted photos and voice notes are kept in a **40 MB least-recently-used cache** instead of growing forever. | `media_crypto_service.dart` |
| F40 | ✅ Fixed (migration, not applied) | Devices record their real platform (`web`, `windows`, `macos`, `linux`, `ios`, `android`). Until migration `…000010` is applied, the app falls back to the old value, so device registration never breaks. | `device_key_manager.dart`, `supabase/migrations/20261105000010_device_platforms.sql` |
| F30 | ✅ Rewritten (**not run, no local Supabase here**) | New `supabase/tests/security_rules_tests.sql` checks 9 rules as the **real signed-in role**, so Row Level Security actually applies: message isolation, outsider recipients, link approval, linked names vs private codes, one family per person, applicant visibility, invite-code limit, last-admin rule. It runs in one transaction that is **always rolled back**, and refuses to start without an explicit opt-in flag. The two old test files (which deleted data and ran as superuser) now refuse to run without that flag. | `supabase/tests/*.sql` |
| F29 | ⏸ Blocked: needs a Flutter SDK upgrade (your machine) | `flutter pub upgrade` changes **nothing**: every package is already at the newest version that supports Flutter 3.24.5 / Dart 3.5.4. Newer packages, including a maintained replacement for the discontinued `sodium_libs` crypto library and a Kotlin 2 Android toolchain, need a newer Flutter. That changes the toolchain installed on your PC, so I didn't do it unasked. Plan below. | – |
| F39 | ⏸ Deferred | `family_screen.dart` (~3,100 lines) is still large. Splitting it safely needs widget tests first; otherwise it's easy to break the UI without noticing. | – |
| F37 | ⏸ Deferred | `replyToId` still stores the reply snippet. Changing it alters the encrypted message format, which older app versions read, so it's best done together with a version bump. | – |
| (login text) | ✅ Fixed | The login screen still said "sign in immediately — no waiting for email codes" from the removed instant login. It now says a 6-digit code will be emailed. | `phone_input_screen.dart` |
| **F44 (new)** | ❌ Open | **Sharing into OurNest isn't wired up.** Android lists OurNest as a share target (text and images) and the Help guide says the chat "opens with the link pre-filled", but the app has no code to receive shared content, so it just opens. Fix: add a share-receiving package and handler, **or** remove the share intent filters and that Help card. *(Medium, UI promise not kept.)* | `AndroidManifest.xml`, `help_guide_screen.dart` |

**Flutter / dependency upgrade plan (when you're ready):**
1. Run `flutter upgrade` on this PC (to the current stable).
2. Run `flutter pub upgrade --major-versions`, then fix the breaking changes (expected in go_router, flutter_riverpod, drift, flutter_local_notifications, record, mobile_scanner).
3. Replace `sodium_libs` with the maintained package and **add a real encrypt → decrypt round-trip test** before releasing; this is the encryption layer.
4. Upgrade the Android Gradle plugin and Kotlin to what the new Flutter recommends (Kotlin 2.x). This also unblocks `package_info_plus` for the version label.
5. Re-run all tests and all builds, then test on real phones.

**Checks after Phase F (actual results):**
```
flutter analyze  → No issues found!
flutter test --coverage → 00:16 +119: All tests passed!   (110 + 9 new in test/unit/quality_phase_f_test.dart)
                          lines covered in loaded files: 536 / 2544 (21.1%)
flutter build apk --debug   → √ Built build\app\outputs\flutter-apk\app-debug.apk
flutter build web --release → √ Built build\web
```

---

## 10. Final user-flow walkthrough

How each flow was checked:
- **PASS (browser):** clicked through the real web build (signed out only; I didn't create accounts on your production database).
- **PASS (code + tests):** the code path was re-read end to end and is covered by automated tests, but it still needs a run on real phones after the migrations are applied.
- **BLOCKED:** needs a setup step from you first.
- **FAIL:** known not to work.

| # | Role | Flow | Result | Notes |
|---|---|---|---|---|
| 1 | Guest | Open app → login screen; protected pages redirect to login; invalid email rejected | **PASS (browser)** | `/settings` and unknown pages went to `/phone-login`; "not-an-email" showed "Please enter a valid email address". |
| 2 | Guest | Email code sign-in (send code → enter code / magic link) | PASS (code + tests) | No password path any more (F01). Not sent for real, because it would email a real account. |
| 3 | New user | Profile setup and edit | PASS (code + tests) | Real errors, e.g. duplicate phone (F10). |
| 4 | New user | Create family → becomes admin | PASS (code + tests) | Unchanged RPC. |
| 5 | New user | Join by code, QR or invite link (also when signed out first) | PASS (code + tests) | Needs migration 9; deep link needs an Android phone test. A second family is refused (Q1). |
| 6 | Admin | See applicant's name → approve | PASS (code + tests) | Needs migration 8 (F17). |
| 7 | Member | Family chat: live delivery, catch-up after offline, web reload restores history | PASS (code + tests) | Needs migrations 5 and 6 plus a **two-device test** (F02/F03). |
| 8 | Member | Private message to one member; "selected" group message | PASS (code + tests) | F22 thread rules tested. |
| 9 | Member | Photo / voice note send and view | PASS (code + tests) | Errors now shown (F23); cache limited (F38). |
| 10 | Member | Send fails (offline) | PASS (code + tests) | Text restored and error shown (F23). |
| 11 | Member | Shared alarm → escalation on other phones → "I'm awake" cancels | PASS (code + tests) | Needs real phones (locked-screen ringing). |
| 12 | Member | Push notification while app closed | **BLOCKED** | Needs Firebase setup (`supabase/manual/PUSH_SETUP.md`) plus migration 7. |
| 13 | Member | Reminder → "Remind Me on This Phone" | PASS (code + tests) | Real scheduled notification (F09). |
| 14 | Admin | Link another family → other admin approves; Peace Pause / Silent Curtain; unlink | PASS (code + tests) | Real results, confirmation on unlink (F07/U19/F12/F32). |
| 15 | Admin | Broadcast / Family-to-Family post | PASS (honest) | Posts to own family chat and says so. Real cross-family delivery isn't built (decision Q2). |
| 16 | Admin | Rename, remove member, transfer admin, new invite code | PASS (code + tests) | New code invalidates old QR (F20). |
| 17 | Admin | Leave family as the only admin | PASS (code + tests) | Blocked with a clear message until admin is transferred (Q4). |
| 18 | Any | Settings: permission status, version, sign-out wipes this phone | PASS (code + tests) | F35, F11. |
| 19 | Any | Windows desktop launcher | PASS (code + tests) | No LAN IP; explains PWA install without Python. |
| 20 | Any | Share a link or photo from another app into OurNest | **FAIL** | Not wired (F44). |

---

## 11. Summary of all changes

Branch `fix/audit-phase-a`, **not pushed**:

| Commit | Phase | In one line |
|---|---|---|
| `0bf8265` | A – Security | Email-code-only login, per-user keys + wipe on sign-out, lock-screen fix, RLS hardening |
| `d396b2a` | B – Chat | Atomic send, catch-up sync, correct private/group threads, visible send errors, batched receipts |
| `a0cbd67` | C – Alarms & push | Alarm receivers, cross-device escalation and "I'm awake", Firebase push, FCM v1 function and trigger |
| `e728676` | D – Honest UI | Real results instead of fake success, real reminders, profile errors, applicant names |
| `0631517` | E – Release | Signing guard, sign-in guard + invite links, no bundled .env, invite limits, private realtime, Q1/Q4 rules |
| *(this phase)* | F – Quality | Zero analyzer issues, media cache limit, real platforms, safe RLS tests |

**Numbers, before → after:**
- Analyzer: 28 issues → **0**.
- Tests: 29 (models only) → **119**.
- Database migrations added: **6** (`…000005` to `…000010`), none applied yet.
- Findings: 44 total (43 from the audit + F44).
  - **Fixed in code:** 34.
  - **Made honest; real feature is a decision:** F08.
  - **Blocked on your setup:** F04 (push needs Firebase) and F29 (needs a Flutter SDK upgrade).
  - **Deferred:** F37, F39, F42.
  - **Open:** F44.
  - **Covered by other fixes:** F03 needs the two-device check; F31 is partly addressed through `friendlyError` and logging, but there's no crash-reporting service (that would be a third-party choice for you).

**Updated health score: about 6.5 / 10 in code.** It rises to roughly 7.5 once the migrations are applied and the two-phone tests pass. The biggest remaining risks are: (1) the password reset script and "Confirm email" not done yet, so the old login hole stays open on the live server; (2) nothing verified on real devices yet; (3) the old Flutter SDK and the discontinued crypto library.

### Final owner checklist (in order)
1. Apply migrations `…000005` → `…000010` (staging first, then production).
2. Supabase → Realtime → Settings → turn off "Allow public access".
3. Create the release signing key plus `android/key.properties` and back them up.
4. Optional: push setup (`supabase/manual/PUSH_SETUP.md`).
5. Rebuild `landing/app` and the Windows zip; publish the new APK (old installs must reinstall once).
6. **Then** Supabase → Auth → Email → turn ON "Confirm email", and run `supabase/manual/2026-11-05_reset_derived_passwords.sql`.
7. Two-phone test of flows 5–17 above.
8. Later: the Flutter upgrade plan, and a decision on F44 (build share-into-OurNest or remove the promise).

*The `coverage/` folder (from the test runs) and `.claude/launch.json` (local web preview) are safe to delete.*
