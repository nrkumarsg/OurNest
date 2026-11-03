# OurNest — Build Prompt for Antigravity

You are a senior Flutter + Supabase engineer. Build **OurNest**, a private, family-only chat app for **Android and iOS** from a single Flutter codebase. Work in the phases listed at the end. **After each phase, stop, summarise what you built, list how to test it, and wait for my approval before continuing.**

---

## 1. Product summary

- **Name:** OurNest
- **Tagline:** "Where your family talks."
- **What it is:** A WhatsApp-style messenger that only works inside a closed family circle (Father, Mother, Son, Daughter, Grandpa, Grandma, etc.). Nobody outside the family can message, see, or join.
- **Core promises:**
  1. Only family members, approved by the family admin, can join.
  2. Every message is **end-to-end encrypted**. The server only ever stores ciphertext.
  3. Every message is sent to **Everyone** in the family or to **Selected** members only.
  4. **Shared Wake-up Alarm:** a message like "Amma, wake me up 8am" can become an alarm that rings on both phones.

---

## 2. Tech stack (use exactly this unless you ask me first)

| Area | Choice |
|---|---|
| App | Flutter (latest stable), Dart, null-safety |
| State management | Riverpod |
| Navigation | go_router |
| Backend | Supabase (Auth with phone OTP, Postgres, Realtime, Storage, Edge Functions) |
| Encryption | libsodium via `sodium_libs` |
| Local secure storage | `flutter_secure_storage` (private keys) |
| Local DB / cache | `drift` (SQLite), storing decrypted messages on-device only |
| Push notifications | Firebase Cloud Messaging (Android + iOS via APNs) |
| Alarms – Android | Exact alarms (`AlarmManager.setAlarmClock`) with full-screen intent, via a plugin or a small Kotlin platform channel |
| Alarms – iOS | **AlarmKit** (iOS 26+) via a Swift platform channel; fall back to time-sensitive local notifications on older iOS |

Secrets (Supabase URL, anon key, Firebase config) go in env/config files that are **not committed**. Never hard-code keys.

---

## 3. Branding

- **Primary (deep teal):** `#1F5C57`
- **Accent (warm coral):** `#E07A4F`
- **Background:** `#F7F4EE`, surfaces `#FFFFFF`, text `#1E2B2A`, secondary text `#4A5856`
- **Font:** Nunito (Google Fonts). Wordmark "Our" in teal and "Nest" in coral, weight 900.
- **Logo mark:** a nest (horizontal rim plus curved bowl) holding three rounded figures: two parents in teal and a smaller child in coral.
- **Elderly-friendly UI:** minimum 16sp body text, a large-text option in settings, 48dp minimum touch targets, high contrast (WCAG AA).
- Support light and dark mode.

---

## 4. Family model and permissions

- A user creates a family and becomes its **Admin**.
- The admin invites members by phone number, QR code, or a 6-character invite code.
- On joining, a member has `status = pending` until the admin approves them.
- The admin assigns each member a **relation**: father, mother, son, daughter, grandfather, grandmother, brother, sister, uncle, aunt, spouse, other (with a custom label).
- **Admin CRUD:** add, approve, edit relation, remove members, rename the family, transfer the admin role.
- **Member CRUD:** edit own profile, and edit or delete their own messages ("delete for everyone" replaces the content with "This message was deleted").
- A user belongs to one family in v1. Design the schema so multiple families can be added later.

---

## 5. Database schema (Supabase / Postgres)

Create these as SQL migrations. Enable **Row Level Security on every table**.

```sql
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text not null,
  phone text unique,
  avatar_url text,
  created_at timestamptz default now()
);

create table families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text unique not null,
  created_by uuid references profiles(id),
  created_at timestamptz default now()
);

create table family_members (
  family_id uuid references families(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  relation text not null,
  relation_label text,
  role text not null default 'member' check (role in ('admin','member')),
  status text not null default 'pending' check (status in ('pending','active')),
  created_at timestamptz default now(),
  primary key (family_id, user_id)
);

create table user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  public_key text not null,          -- base64 X25519 public key
  platform text check (platform in ('android','ios')),
  fcm_token text,
  created_at timestamptz default now(),
  revoked_at timestamptz
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id) on delete cascade,
  sender_id uuid references profiles(id),
  sender_device_id uuid references user_devices(id),
  type text not null check (type in ('text','photo','voice','alarm','alarm_event')),
  audience text not null check (audience in ('all','selected')),
  ciphertext text not null,          -- base64, encrypted payload
  nonce text not null,
  created_at timestamptz default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);

create table message_recipients (    -- who may load the message (user level)
  message_id uuid references messages(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  primary key (message_id, user_id)
);

create table message_keys (          -- per-device locked message key
  message_id uuid references messages(id) on delete cascade,
  recipient_device_id uuid references user_devices(id) on delete cascade,
  locked_key text not null,          -- crypto_box_seal output, base64
  primary key (message_id, recipient_device_id)
);
```

Create a `security definer` helper function `is_active_member(fam uuid)` that returns true when `auth.uid()` is an active member of that family.

**RLS rules (implement all of them, then write SQL tests for each):**
- `profiles`: read your own profile and profiles of active members of your family. Update only your own.
- `families`: read if you are an active member. Update only if you are its admin.
- `family_members`: read rows of your own family. Insert your own pending row via the invite code (through an RPC `join_family(code)`). Update or delete only if you are the admin. Members may delete their own row (leave the family).
- `user_devices`: insert, update and revoke your own devices. Read public keys of active members of your family.
- `messages`: select only if `sender_id = auth.uid()` or there is a `message_recipients` row for `auth.uid()`. Insert only if `sender_id = auth.uid()` and `is_active_member(family_id)`. Update (edit or delete) only your own.
- `message_recipients` / `message_keys`: insert by the message sender. Select only your own rows (`user_id = auth.uid()`, or a device you own).

Enable Realtime on `messages` (RLS still applies).

---

## 6. End-to-end encryption (mandatory, no plaintext ever leaves the device)

1. **Device keys:** on first launch, generate an X25519 key pair (`crypto_box_keypair`). Store the private key in `flutter_secure_storage` only. Upload the public key to `user_devices`.
2. **Sending a message:**
   - Build a JSON payload, e.g. `{ "text": "...", "reply_to": null }`.
   - Generate a random 32-byte message key. Encrypt the payload with XChaCha20-Poly1305 (`crypto_aead_xchacha20poly1305_ietf_encrypt`) and a random nonce.
   - Work out the recipients: **Everyone** means all active family members. **Selected** means the chosen members. **Always include the sender's own other devices.**
   - For each recipient device, lock the message key with `crypto_box_seal(messageKey, devicePublicKey)` and insert it into `message_keys`.
   - Insert one `messages` row (ciphertext and nonce) and one `message_recipients` row per recipient user.
3. **Receiving:** fetch `message_keys` for my device, open it with `crypto_box_seal_open`, decrypt the payload, and save the plaintext in the local drift DB only.
4. **Media (photo and voice):** encrypt the file on-device with its own random key, upload the ciphertext to a **private** Storage bucket `media/{family_id}/{uuid}`, and put the storage path and file key inside the encrypted message payload.
5. **Edits** re-encrypt the new payload for the same recipients. **Deletes** set `deleted_at` and replace the ciphertext with an encrypted tombstone.
6. **Never** log decrypted content, never send plaintext to the server, never put message content in push notifications.
7. Known v1 limitations (show them in the UI where relevant): new members cannot read messages sent before they joined, and a new phone cannot read old history. Leave a clean interface for a future PIN-protected encrypted backup.

---

## 7. Audience selector: Everyone vs Selected

- Above the message input there is a toggle chip: **Everyone** (default in the family chat) | **Selected**.
- Choosing **Selected** opens a member picker showing avatar, name and relation, with multi-select.
- Each message bubble shows a small label when the audience is Selected, e.g. "To: Amma, Son".
- 1-to-1 chats (tapping a member) are simply Selected messages with one recipient, shown in a separate thread.
- People who were not selected must not receive the message at all: no `message_recipients` row and no keys.

---

## 8. Shared Wake-up Alarm

**Flow:**
1. While the user types, detect a time with wake-up intent locally, e.g. "wake me up 8am", "8:30 pm", "6 o'clock tomorrow", using regex and simple date logic (no server).
2. Under the sent message, show a chip: **"Set shared alarm for 8:00 AM?"** The alarm is only created after the user taps it (no automatic alarms). The user can also create one from an alarm icon in the input bar with a time picker.
3. Creating the alarm sends a `type = 'alarm'` message to the same audience. Its encrypted payload is:
   ```json
   { "alarm_id": "uuid", "time": "2026-11-03T08:00:00+08:00", "label": "Wake-up for Son",
     "owner_id": "<son>", "participants": ["<son>", "<amma>"], "escalate_after_min": 5 }
   ```
4. Both chats show an **alarm card**: time, label, participants, [Edit] [Cancel]. Edit and cancel send `type = 'alarm_event'` messages (`update` / `cancel`) and every device re-schedules or removes its local alarm.
5. Each participant's device schedules a **real local alarm**:
   - Android: exact alarm with full-screen intent. Request the "Alarms & reminders" permission with a clear explanation screen.
   - iOS 26+: AlarmKit. Older iOS: a time-sensitive local notification with sound, plus a note telling the user to keep the volume on.
6. **Owner's alarm screen** (the son): a big **"I'm awake"** button and a Snooze option. Tapping "I'm awake" sends an `alarm_event` `ack`.
7. **Escalation (all local, no server timer):** the other participants' devices also schedule a second alarm at `time + escalate_after_min`. When an `ack` arrives, that escalation alarm is cancelled and they see "Son is awake ✓". Otherwise it rings with "Son hasn't woken up yet" and a **[Call him]** button (phone dialler).
8. If a participant's device hasn't confirmed receiving the alarm (no delivery receipt within 10 minutes), the owner sees "Amma's phone hasn't received this alarm yet."
9. Store scheduled alarms in the local DB and re-schedule them after a device reboot and after an app update.

---

## 9. Push notifications

- A Supabase Edge Function runs on `messages` insert. It looks up the recipients' active devices and sends an FCM **data message** containing only `message_id`, `family_id` and the sender's display name.
- The device fetches and decrypts the message, then shows the notification locally with a preview. If decryption isn't possible in the background, show "New message from {name}".
- Alarm messages must be delivered with high priority so alarms get scheduled promptly.

---

## 10. Screens

1. Splash / onboarding (logo plus tagline "Where your family talks.")
2. Phone login → OTP → profile setup (name, photo)
3. Create family **or** join with a code / QR
4. "Waiting for approval" screen (for pending members)
5. Home: the family group chat at the top, then 1-to-1 chats with members (avatar, name, relation, last message, unread count)
6. Chat screen: bubbles, audience toggle, Selected labels, photos, voice notes, alarm cards, reply, edit, delete, read receipts, typing indicator
7. Member picker (for Selected)
8. Alarm creation / edit sheet
9. Alarm ringing screens (owner and escalation versions)
10. Family screen: members list with relations, invite (code, QR, share link), pending approvals (admin), edit relation, remove (admin)
11. Settings: profile, large text, dark mode, notifications, alarm permission status, devices, leave family

---

## 11. Quality requirements

- Clean architecture: `lib/core`, `lib/features/<feature>/{data,domain,presentation}`.
- Unit tests for encryption (encrypt → decrypt round-trip, wrong device can't decrypt), time detection, and alarm scheduling logic.
- SQL tests for every RLS policy, including "a non-selected member cannot read a Selected message" and "a non-family user cannot read anything".
- Handle offline use: queue outgoing messages and send them when back online.
- No analytics or third-party trackers.
- Write a README with setup steps (Supabase project, migrations, Firebase, iOS signing, Android permissions).

---

## 12. Build phases (stop after each one for my review)

1. **Foundation:** Flutter project, branding/theme, Supabase setup, phone OTP login, profile.
2. **Family:** create/join family, invites (code + QR), admin approval, relations, member CRUD, all RLS for these tables, plus SQL tests.
3. **Encryption + text chat:** device keys, E2EE send/receive, Everyone/Selected, family chat + 1-to-1 threads, edit/delete, Realtime, local DB, plus encryption tests.
4. **Media + push:** encrypted photos and voice notes, the FCM Edge Function, local notifications.
5. **Shared Wake-up Alarm:** detection, alarm messages, cards, Android exact alarms, iOS AlarmKit, ack + escalation, reboot handling, plus tests.
6. **Polish:** dark mode, large text, read receipts, typing indicator, offline queue, README, store-ready app icons (from the logo above).

Before writing code for Phase 1, reply with: (a) the folder structure, (b) the packages you'll add, with versions, and (c) any questions or assumptions.
