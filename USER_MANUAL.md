# OurNest — Comprehensive User Manual & Working Flow Guide
> **"Where your family talks."**  
> Private, family-only messenger with End-to-End Encryption, Shared Wake-Up Alarms, Family Reminders, and Elderly-Friendly Accessibility.  
> **Developed by ARKIS PTE LTD**  
> *© 2026 OurNest. All rights reserved.*

---

## Table of Contents
1. [App Overview & Core Philosophy](#1-app-overview--core-philosophy)
2. [Step-by-Step User Workflows](#2-step-by-step-user-workflows)
   - [Workflow 1: Getting Started & Passwordless Sign-In](#workflow-1-getting-started--passwordless-sign-in)
   - [Workflow 2: Creating a Family Circle & Inviting Members](#workflow-2-creating-a-family-circle--inviting-members)
   - [Workflow 3: Joining a Family & Admin Approval Safety Gate](#workflow-3-joining-a-family--admin-approval-safety-gate)
   - [Workflow 4: Everyone vs. Selected (Audience Isolation)](#workflow-4-everyone-vs-selected-audience-isolation)
   - [Workflow 5: 1-to-1 Private Direct Messaging](#workflow-5-1-to-1-private-direct-messaging)
   - [Workflow 6: Encrypted Voice Notes & Photos](#workflow-6-encrypted-voice-notes--photos)
   - [Workflow 7: One-Touch Sharing from YouTube & Social Media](#workflow-7-one-touch-sharing-from-youtube--social-media)
   - [Workflow 8: Shared Wake-Up Alarms & Local Escalation](#workflow-8-shared-wake-up-alarms--local-escalation)
   - [Workflow 9: Shared Family Reminders & Calendar Events](#workflow-9-shared-family-reminders--calendar-events)
   - [Workflow 10: Accessibility (Large Text Mode & Dark Theme)](#workflow-10-accessibility-large-text-mode--dark-theme)
3. [End-to-End Encryption Architecture](#3-end-to-end-encryption-architecture)
4. [Device Permissions & System Requirements](#4-device-permissions--system-requirements)
5. [Frequently Asked Questions & Troubleshooting](#5-frequently-asked-questions--troubleshooting)
6. [Company Attribution & Support](#6-company-attribution--support)

---

## 1. App Overview & Core Philosophy
OurNest is designed specifically for families. Unlike commercial messengers cluttered with public channels, spam calls, strangers, and invasive targeted ads:
- **Zero Outsiders:** Only verified, admin-approved family members can enter.
- **Zero Server Eavesdropping:** Military-grade E2EE (`libsodium` X25519 + XChaCha20-Poly1305). Plaintext messages never touch any server.
- **Elderly-Friendly by Design:** Minimum 16sp font, 48dp touch targets, warm readable colors (`#1F5C57` Deep Forest Teal, `#E07A4F` Warm Terracotta, `#F7F4EE` Soft Cream).
- **Proactive Family Care:** Interactive Shared Wake-Up Alarms that escalate if someone overslept, and Family Reminders that sync into personal phone calendars.

---

## 2. Step-by-Step User Workflows

```
┌────────────────────────────────────────────────────────────────────────┐
│                        OURNEST MASTER WORKFLOW                         │
└────────────────────────────────────────────────────────────────────────┘

  [Phone Number] ──> [SMS OTP 6-Digit] ──> [Profile Setup (Name & Photo)]
                                                  │
                ┌─────────────────────────────────┴───────────────────────────────┐
                ▼                                                                 ▼
      [Create New Family]                                                 [Join Existing Family]
      - Choose Family Name                                                - Enter 6-char Code (e.g. SHRM92)
      - Select Admin Relation (Father, etc.)                              - Or Scan Admin's QR Code
      - Generates Code & QR                                               - Select Relation (Son, Mother, etc.)
                │                                                                 │
                │                                                                 ▼
                │                                                       [Pending Approval Gate]
                │                                                       - Admin gets push alert
                │                                                       - Admin taps Approve (✓)
                ▼                                                                 │
         ┌────────────────────────────────────────────────────────────────────────┘
         ▼
  [Home Screen]
   ├── [Family Group Chat] ───> Audience: [Everyone | Selected Members]
   │    ├── Text Messaging (End-to-End Encrypted)
   │    ├── Voice Notes (Hold to record, live timer, trash cancel)
   │    ├── Encrypted Photos (Camera or Gallery)
   │    ├── Shared Wake-Up Alarms ("Wake me up 8am" -> Alarm Card -> Escalation)
   │    └── Family Reminders ("Grandma Doctor" -> 1-tap Add to Calendar)
   │
   ├── [Native Sponsor Space] ── Non-intrusive family sponsors (Zero pop-ups)
   │
   ├── [Direct 1-on-1 Chats] ── Fully isolated private encrypted chats
   │
   └── [Settings & Help] ───── Large Text Mode (+20%), Dark Mode, Full Guide
```

---

### Workflow 1: Getting Started & Passwordless Sign-In
1. Launch the **OurNest** app.
2. Enter your mobile phone number with your country code.
3. You will immediately receive a 6-digit SMS verification code. Enter this code. There are no passwords to remember or forget.
4. On the **Profile Setup** screen, enter your Display Name (e.g. *"Dad"*, *"Amma"*, *"Pooja"*, *"Grandpa"*).
5. Optionally select an avatar photo.
6. Tap **Continue**. Your device automatically generates a unique cryptographic keypair in your phone's hardware security module (`flutter_secure_storage`).

---

### Workflow 2: Creating a Family Circle & Inviting Members
1. If you are starting your family circle, tap **Create a Family**.
2. Type your family name (e.g. *"The Sharma Family"*, *"Smith Nest"*).
3. Select your relationship to the family (e.g. `Father`, `Mother`, `Grandparent`).
4. You are now the **Family Admin**.
5. To invite your spouse, children, or parents:
   - Tap the **QR Code icon** in the top bar.
   - Show the QR code on your screen for family members to scan with their camera, or tap **Copy Invite Code** to share the unique 6-character code (e.g. `SHRM92`) via SMS or WhatsApp.

---

### Workflow 3: Joining a Family & Admin Approval Safety Gate
1. Download OurNest on the family member's phone and sign in with their phone number.
2. On the family setup screen, tap **Join a Family**.
3. Either:
   - Scan the Admin's QR code using the built-in scanner, or
   - Manually type the 6-character invite code (e.g. `SHRM92`).
4. Choose your relation (e.g. `Son`, `Daughter`, `Mother`, `Aunt`).
5. Tap **Request to Join**.
6. **Safety Gate:** The app will display a *"Pending Approval"* screen.
7. The Admin will see a pending card in their Family Circle screen and tap **Approve (✓)**.
8. Once approved, the member instantly enters the circle with full access to send and receive messages.

---

### Workflow 4: Everyone vs. Selected (Audience Isolation)
Above the chat typing bar, you will see an Audience Toggle:
```
[ 👥 Everyone ]  or  [ 🎯 Selected (2) ]
```
- **Everyone (Default):** Every active family member receives and can read the message.
- **Selected:** Opens a quick member picker:
  - Check the members you want to include (e.g. *Mom* and *Dad*).
  - The message is encrypted **only** with the public keys of those selected members.
  - Members who were not selected **cannot decrypt or see the message in their chat feed**.
  - No accidental leaks when planning surprise birthday parties or discussing private matters.

---

### Workflow 5: 1-to-1 Private Direct Messaging
1. On the **Home Screen**, scroll below the Family Group Chat to the **Direct Messages** section.
2. Tap any family member's avatar or name.
3. A 1-to-1 encrypted conversation opens.
4. Only the two participants hold the keys to this conversation.

---

### Workflow 6: Encrypted Voice Notes & Photos
- **Voice Notes:**
  1. Press and hold the **Microphone** icon next to the chat text bar.
  2. Speak your message. A live recording timer and waveform appear.
  3. If you want to cancel, slide your finger to the left towards the red **Trash Can** icon.
  4. Release the button to encrypt and send.
  5. Recipients can tap **Play/Pause** to listen with playback scrubber.
- **Photos:**
  1. Tap the **+** (Plus) button on the left of the chat bar.
  2. Select **Take a Photo** (Camera) or **Choose from Gallery**.
  3. The image is encrypted symmetrically on your device before upload.
  4. Tap the thumbnail in chat to open a high-resolution, zoomable fullscreen viewer.

---

### Workflow 7: One-Touch Sharing from YouTube & Social Media
Share interesting videos, news articles, or recipes with your family in two taps:
1. While watching a video in the **YouTube** app, or reading an article in **Chrome / Safari**:
2. Tap your phone's native **Share** button.
3. In the system share sheet, select **OurNest**.
4. OurNest opens directly into your Family Chat with the link or photo pre-filled, ready to send!

---

### Workflow 8: Shared Wake-Up Alarms & Local Escalation
OurNest features a revolutionary shared wake-up alarm system designed to keep families on track:

#### A. Smart Natural Language Typing Detection
- Type any phrase like `"Amma wake me up 8am"` or `"wake Rahul up at 7:00 am"` into the chat box.
- OurNest's offline regex NLP engine instantly recognizes the time and displays a highlighted suggestion chip:
  `[ ⏰ Set shared alarm for 8:00 AM? ]`
- Tap the chip to confirm and create the alarm instantly!

#### B. Manual Alarm Creation
- Tap the **+** button in chat -> **Set Shared Alarm**.
- Select target time, grace period (e.g. 5 minutes), and optional note (e.g. *"Math Exam today!"*).

#### C. The Ringing & Escalation Working Flow:
```
  [Alarm Time Arrives: 7:00 AM]
               │
               ▼
   Owner's Phone Rings Loudly
   (Full-Screen Ringing Screen)
               │
     ┌─────────┴────────────────────────┐
     ▼                                  ▼
[Taps "I'M AWAKE ✓"]          [Oversleeps / No Response]
  - Alarm stops                  - Grace period expires (e.g. 5 min: 7:05 AM)
  - Sends "I'm Awake" status     - Escalation triggers!
  - Escalation cancelled                │
                                        ▼
                               Family Member's Phone Rings!
                               - Red Alert Screen
                               - Loud siren/ringtone
                               - Giant [📞 Call Him] dialer button
```

---

### Workflow 9: Shared Family Reminders & Calendar Events
Designed so Dad, Mom, or any member can notify the family about important dates:
1. Tap the **+** icon in chat -> select **Family Reminder / Event**.
2. Enter:
   - **Event Title:** e.g. *"Grandma Eye Checkup"*, *"Rahul School Fees Due"*, *"Family Dinner Sunday"*.
   - **Date & Time:** Pick the exact date and reminder time.
   - **Target Audience:** Remind **All Family Members** or **Individual Members**.
   - **Notes:** e.g. *"Bring prescription and previous test reports"*.
3. Tap **Schedule Reminder**.
4. An interactive **Calendar Card** appears in the family chat feed.
5. Family members can tap **[📅 Add to Calendar]** to sync it directly into their personal Google Calendar or Apple Calendar with one touch.
6. When completed, tap the checkbox on the card to mark it as done.

---

### Workflow 10: Accessibility (Large Text Mode & Dark Theme)
Built specifically for elderly parents and grandparents:
1. Tap the **Settings (⚙️)** icon in the top right.
2. **Large Text Mode:** Switch on to increase all body text by 20% across every screen.
3. **Dark Mode:** Switch on for an eye-friendly, high-contrast dark palette with reduced blue light.
4. **48dp Touch Targets:** All buttons, icons, and interactive cards have a minimum touch boundary of 48x48dp to eliminate frustrating mis-taps.

---

### Workflow 11: Rich Personal Profiles & Family Birthday Reminders
Every family member has a complete profile card visible inside the family circle:
1. Open **Settings → Edit Personal Profile** (or tap the badge icon in the top bar of the **Family** screen).
2. Add or update:
   - **Profile Photo** (Camera or Gallery)
   - **Full Name** & **Status Line** (with 1-tap quick chips like *"🏠 At Home"*, *"💼 At Work"*, *"✈️ Travelling"*)
   - **Sex / Gender**, **Blood Group**, and **Date of Birth** (automatically calculates age & birthday countdown)
   - **Mobile Phone Number** & **WhatsApp Number** (with `[✓] Same as Mobile Phone Number` checkbox, enabling 1-tap `[📞 Call Mobile]` and `[💬 WhatsApp]` buttons)
   - **Living Place / Residence City** (area, city, country)
   - **Home / Residential Address** (Door No, Street, Area, Postal Code — with a 1-tap `[🗺️ Map Address]` button to open Google Maps navigation!)
   - **Education / Qualification**
   - **Occupation / Profession**, **Working Place (Company / School)**, and **Working Details**
   - **Bio / About Me**
3. Tap any person in **`🏠 My Family`** to view their complete profile card, or switch to the **`🎂 Birthdays`** tab to see all upcoming family birthdays sorted by days remaining and send a **1-Tap Birthday Wish 🎂**!

---

### Workflow 12: Connected Family Tree, Church/Temple Volunteers & Multi-Group Broadcasts
Connect **🌳 Relative Families**, **🤝 Friend & Neighbour Families**, and **🛕⛪ Church / Temple / Volunteer Groups** (including single/solo members) into your **Family Tree** while keeping daily nuclear family chat private by default:
1. **Single Member & Volunteer Support:**
   - A Church Coordinator, Pastor, or Temple Trustee can create a group (e.g., *"St. Mary's Parish Fellowship"* or *"Sri Mariamman Temple Volunteers"*).
   - Single members or volunteers scan the QR code or enter the 6-character code and tap a 1-tap role chip (**`🛕 Temple Volunteer`**, **`⛪ Church Member`**, **`👑 Group Coordinator`**, **`🤲 Community Volunteer`**, or **`👤 Single / Solo Member`**).
2. **3-Ring Linking in `🌳 Family Tree`:**
   - Open **Family → `🌳 Family Tree`** tab and tap **"Link Family / Friend / Temple / Church"**.
   - Choose between **🌳 Relative**, **🤝 Friend**, or **🛕⛪ Church / Temple / Volunteer** rings.
3. **📢 Multi-Group Broadcast & Custom Circles:**
   - Tap **`📢 Broadcast & Custom Groups`** at the top of the Family Tree tab.
   - Broadcast announcements to **🌐 All Connected Nests**, **🌳 Relatives Only**, **🤝 Friends Only**, **🛕⛪ Church / Temple / Volunteers**, or **⭕ Saved Custom Circles** (*Sunday Church Fellowship*, *Temple Seva Volunteers*, *Close Relatives*, *Weekend Dinner Friends*) with 1-tap templates!

---

### Workflow 13: Silent Curtain (Peace & Hide Mode — Better Than Block)
If two connected families have a disagreement or fight, a WhatsApp-style "Block" or "Delete" only creates more embarrassment and family drama. OurNest's **Silent Curtain** gives you complete peace on your side with **zero notification** to the other family:
1. In **`🌳 Family Tree`**, tap **`Hide / Peace`** (or the curtain icon `🪟`) on any connected family card.
2. Choose your Peace Level:
   - **`🪟 Curtain Mode (Hide Family Completely)`:** Completely hides that family from your Family Tree, Chat, and Birthdays—tucking them into a discreet **`🪟 Tucked Away / Hidden Branches`** drawer at the bottom.
   - **`🕊️ Peace Pause (7 Days / 30 Days / Until Unpaused)`:** Keeps them in the tree, but silently mutes their cross-family invitations and alerts while everyone cools down.
   - **`🛡️ Privacy Shield (Hide Our Updates From Them)`:** Prevents your family's invitations, status, working/living details, and birthday alerts from being shared with that family.
3. Choose Scope: **`🏠 My Entire Family`** (Admin) or **`👤 Only On My Phone`** (Individual Member).
4. **1-Tap Reconciliation:** Whenever the families make peace, open **`🪟 Tucked Away / Hidden Branches`** at the bottom of the Family Tree and tap **`🤝 Lift Curtain`** to restore them immediately as if nothing happened!

---

## 3. End-to-End Encryption Architecture
- **Cryptographic Engine:** `sodium_libs` (standard `libsodium` implementation).
- **Key Pairs:** X25519 asymmetric keypairs generated locally on-device.
- **Hardware Storage:** Private keys are stored strictly in `flutter_secure_storage` (Android KeyStore / iOS Keychain).
- **Message Encryption:** Symmetrically encrypted with XChaCha20-Poly1305. The symmetric key is encrypted using `crypto_box_seal` for each recipient's public key.
- **Media Encryption:** Full-resolution photos and voice audio are symmetrically encrypted with a random 256-bit key. Only the encrypted blob is stored on Supabase Storage. The decryption key travels inside the E2E encrypted message payload.
- **Zero Push Leakage:** Push notifications sent via FCM contain data-only alerts (`"You have a new family message"`) without plaintext snippets.

---

## 4. Device Permissions & System Requirements

| Permission | Android | iOS | Why It Is Needed |
|---|---|---|---|
| **Alarms & Reminders** | `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM` | Background Audio / AlarmKit | Rings alarms at the exact minute even when phone is locked. |
| **Microphone** | `RECORD_AUDIO` | `NSMicrophoneUsageDescription` | Recording encrypted voice notes. |
| **Camera & Gallery** | `CAMERA`, `READ_MEDIA_IMAGES` | `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` | Taking or choosing family photos. |
| **Notifications** | `POST_NOTIFICATIONS` | User Notifications API | Notifying you of incoming family messages and alarms. |
| **Battery Optimization** | Whitelist / Unrestricted | Background App Refresh | Prevents Android Doze or iOS sleep from delaying wake-up alarms. |

---

## 5. Frequently Asked Questions & Troubleshooting

#### Q: Why didn't my wake-up alarm ring on Android?
**A:** Ensure OurNest has permission to set exact alarms:
1. Open your phone's **Settings** > **Apps** > **OurNest** > **Alarms & Reminders** > set to **Allowed**.
2. Under **Battery**, select **Unrestricted** so the operating system does not kill the alarm service during deep sleep.

#### Q: Can I read messages on a new phone?
**A:** For your family's security, OurNest does not store your private keys on any central server. New devices only receive messages sent after they join the family circle.

#### Q: Can strangers find or message my children or grandparents?
**A:** No. OurNest has no public directory, no stranger search, and no friend suggestions. Only people who possess your 6-character code and are explicitly approved by the Family Admin can enter.

#### Q: What if someone loses their phone?
**A:** The Family Admin can open the **Family Screen**, tap the member's card, and select **Remove Member**. This immediately revokes their access to the circle.

---

## 6. Company Attribution & Support
**OurNest** is proudly engineered and maintained by:  
**ARKIS PTE LTD**  
*Singapore*  

For technical support, feedback, or enterprise family deployment:  
- **Email:** `support@arkis.sg`  
- **Copyright:** `© 2026 OurNest. All rights reserved. Developed by ARKIS PTE LTD.`
