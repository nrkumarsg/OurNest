# OurNest — Private Family Chat App

> "Where your family talks."

A private, family-only messenger for **Android and iOS** built from a single Flutter codebase with **Supabase**, featuring zero-knowledge end-to-end encryption (libsodium), audience controls (Everyone vs. Selected), shared wake-up alarms with automatic local escalation, shared family calendar reminders, and one-touch social media sharing.

Developed by **ARKIS PTE LTD**.

---

## 🎨 Branding & Accessibility
- **Primary Color:** Deep Teal (`#1F5C57`)
- **Accent Color:** Warm Coral (`#E07A4F`)
- **Background:** `#F7F4EE`, surfaces `#FFFFFF`, text `#1E2B2A`, secondary text `#4A5856`
- **Font:** Nunito (Google Fonts), wordmark "Our" in teal and "Nest" in coral (weight 900)
- **Elderly-friendly:** Minimum 16sp body text, toggleable Large Text mode, 48dp+ touch targets, high contrast (WCAG AA)
- **Dark Mode:** Full dark theme support with tailored dark surfaces (`#0F1817` and `#1B2827`)

---

## 🌟 Core Features

1. **Closed Family Circle & Admin Controls:**
   - Only approved family members can join via unique 6-character invite code or QR code.
   - Admin approves members and assigns relations: *Father, Mother, Son, Daughter, Grandfather, Grandmother, Brother, Sister, Uncle, Aunt, Spouse, Other (custom label)*.
   - Admin can rename family, edit relations, transfer admin, or remove members.

2. **Military-Grade End-to-End Encryption (E2EE):**
   - Libsodium X25519 device keypair generated on first launch; private keys stored exclusively in `flutter_secure_storage`.
   - Messages encrypted with random 32-byte message keys using XChaCha20-Poly1305 and sealed with `crypto_box_seal` for authorized recipient devices only.
   - Server only ever stores ciphertext. Plaintext never leaves the device.

3. **Audience Selector (Everyone vs Selected):**
   - Seamlessly switch between sending to **Everyone** in the family or **Selected** members only.
   - 1-to-1 chats are naturally handled as Selected threads with full E2EE.

4. **Shared Wake-Up Alarms & Local Escalation:**
   - 100% local NLP regex detection: type *"Amma wake me up 8am"* -> suggestion chip pops up immediately.
   - Interactive alarm cards in chat with time, label, participants, and status.
   - **Owner screen:** Giant button **"I'M AWAKE ✓"** and Snooze.
   - **Escalation alarm:** Rings on participants' phones (e.g. Amma/Dad) at `time + escalate_after_min` with a big **[📞 Call Him]** phone dialer button if the owner does not wake up!

5. **Shared Family Reminders & Calendar Events:**
   - Dad or any member can schedule reminders (e.g. *"Grandma Doctor Appointment at 4:00 PM on Friday"*).
   - Set audience for **All** or **Individual** family members with one-tap device calendar addition.

6. **Encrypted Photos & Voice Notes:**
   - Voice note recorder with live timer, cancellation, and audio wave player.
   - Photos encrypted on-device before uploading to private Supabase Storage (`media/{family_id}/{uuid}`).

7. **One-Touch Social & YouTube Sharing:**
   - System `ACTION_SEND` intent filters allow sharing videos directly from YouTube, Instagram, or web browsers into OurNest.

8. **Non-Intrusive Family Sponsor Ad Space:**
   - Premium native sponsor card on the Home screen between the Family Group Chat and Direct Messages.
   - Zero disturbance to the chat and typing experience.

9. **Web Landing Page:**
   - Located in [`landing/`](landing/index.html) with responsive mockups, QR scan code, and download links for Android (APK) and iOS (App Store).
   - Copyright: `© 2026 OurNest. All rights reserved. Developed by ARKIS PTE LTD.`

---

## 🚀 Setup & Installation

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.19.0 or higher)
- [Supabase Account & CLI](https://supabase.com/docs/guides/cli)

### 2. Configure Environment Variables
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
Update `.env` with your Supabase credentials:
```ini
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
APP_ENV=development
```

### 3. Apply Supabase Database Migrations
Run the SQL migrations located in `supabase/migrations/`:
```bash
# Using Supabase CLI:
supabase db push

# Or run the migrations directly in the Supabase SQL Editor:
# 1. supabase/migrations/20261102000000_init_profiles.sql
# 2. supabase/migrations/20261102000001_family_schema_and_rls.sql
# 3. supabase/migrations/20261102000002_chat_and_encryption.sql
# 4. supabase/migrations/20261102000003_storage_media_and_push_webhook.sql
```

### 4. Deploy FCM Push Dispatcher (Edge Function)
```bash
supabase functions deploy push-dispatcher
```

### 5. Run Automated Tests
```bash
# Unit tests
flutter test

# Run SQL RLS security tests in Supabase SQL Editor:
# - supabase/tests/family_rls_tests.sql
# - supabase/tests/chat_rls_tests.sql
```

---

## 🏛️ Architecture Overview
```text
lib/
├── core/
│   ├── constants/       # AppColors (#1F5C57, #E07A4F), Nunito AppTypography (>=16sp), Env
│   ├── crypto/          # libsodium X25519, XChaCha20-Poly1305, MediaCryptoService
│   ├── database/        # Drift (SQLite) local decrypted message cache
│   ├── network/         # Supabase client wrapper & providers
│   ├── notifications/   # FCM & FlutterLocalNotifications exact channel
│   ├── platform/        # AlarmSchedulerService (Android AlarmManager.setAlarmClock)
│   ├── router/          # go_router declarative routes & auth guards
│   ├── theme/           # AppTheme (Light & Dark WCAG AA), ThemeProvider
│   └── widgets/         # NestLogoMark & NestWordmark custom painters
├── features/
│   ├── auth/            # Phone OTP sign in, verification, auth controller
│   ├── profile/         # Display name setup, avatar, profile sync
│   ├── family/          # Create family, QR/code invites, admin approvals, relations
│   ├── chat/            # E2EE messaging, Realtime sync, Everyone/Selected, photo & voice
│   ├── alarm/           # NLP intent parser, AlarmCard, AlarmRingingScreen, escalation
│   ├── reminder/        # Shared family calendar events & reminders
│   └── settings/        # Large text toggle, dark mode, device keys, privacy status
landing/                 # Responsive web landing page with Android/iOS downloads
supabase/                # SQL migrations, RLS tests, and push-dispatcher Edge Function
```
