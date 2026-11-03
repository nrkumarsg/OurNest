-- Migration: 20261102000002_chat_and_encryption.sql
-- Description: user_devices, messages, message_recipients, message_keys, RLS, and Realtime

-- 1. Create user_devices table
create table if not exists public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  public_key text not null,          -- base64 X25519 public key
  platform text check (platform in ('android', 'ios')),
  fcm_token text,
  created_at timestamptz default now(),
  revoked_at timestamptz
);

-- 2. Create messages table
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete set null not null,
  sender_device_id uuid references public.user_devices(id) on delete set null,
  type text not null check (type in ('text', 'photo', 'voice', 'alarm', 'alarm_event')),
  audience text not null check (audience in ('all', 'selected')),
  ciphertext text not null,          -- base64 encrypted payload
  nonce text not null,               -- base64 random nonce
  created_at timestamptz default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);

-- 3. Create message_recipients table (user-level recipient mapping)
create table if not exists public.message_recipients (
  message_id uuid references public.messages(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  primary key (message_id, user_id)
);

-- 4. Create message_keys table (per-device sealed message key)
create table if not exists public.message_keys (
  message_id uuid references public.messages(id) on delete cascade,
  recipient_device_id uuid references public.user_devices(id) on delete cascade,
  locked_key text not null,          -- crypto_box_seal output, base64
  primary key (message_id, recipient_device_id)
);

-- 5. Enable Row Level Security (RLS) on all tables
alter table public.user_devices enable row level security;
alter table public.messages enable row level security;
alter table public.message_recipients enable row level security;
alter table public.message_keys enable row level security;

-- 6. RLS Policies for user_devices
-- Insert / Update / Revoke own devices
create policy "Users can manage own devices"
  on public.user_devices
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Read public keys of active members in the same family
create policy "Active family members can read device public keys"
  on public.user_devices
  for select
  using (
    user_id = auth.uid() or
    public.shares_family_with(user_id)
  );

-- 7. RLS Policies for messages
-- Select: only if sender, or if there is a message_recipients row for auth.uid()
create policy "Recipients and sender can view messages"
  on public.messages
  for select
  using (
    sender_id = auth.uid() or
    exists (
      select 1 from public.message_recipients mr
      where mr.message_id = id
        and mr.user_id = auth.uid()
    )
  );

-- Insert: sender must be auth.uid() and an active member of that family
create policy "Active members can send messages"
  on public.messages
  for insert
  with check (
    sender_id = auth.uid() and
    public.is_active_member(family_id)
  );

-- Update: sender can edit or soft-delete (tombstone) their own message
create policy "Senders can edit or delete own messages"
  on public.messages
  for update
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

-- 8. RLS Policies for message_recipients
-- Insert: message sender can insert recipient rows
create policy "Senders can insert message recipients"
  on public.message_recipients
  for insert
  with check (
    exists (
      select 1 from public.messages m
      where m.id = message_id
        and m.sender_id = auth.uid()
    )
  );

-- Select: users can only see their own recipient rows
create policy "Users can see own recipient rows"
  on public.message_recipients
  for select
  using (user_id = auth.uid());

-- 9. RLS Policies for message_keys
-- Insert: message sender can insert device locked keys
create policy "Senders can insert device message keys"
  on public.message_keys
  for insert
  with check (
    exists (
      select 1 from public.messages m
      where m.id = message_id
        and m.sender_id = auth.uid()
    )
  );

-- Select: users can only read keys meant for devices they own
create policy "Users can read message keys for own devices"
  on public.message_keys
  for select
  using (
    exists (
      select 1 from public.user_devices ud
      where ud.id = recipient_device_id
        and ud.user_id = auth.uid()
    )
  );

-- 10. Enable Supabase Realtime on messages
alter publication supabase_realtime add table public.messages;
