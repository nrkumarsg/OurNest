-- Migration: 20261105000010_device_platforms.sql
-- Description: Phase F (audit F40) – record the real device platform.
-- The old check only allowed 'android' / 'ios', so web and desktop devices
-- were stored as 'android' (which would also break platform-specific push).

alter table public.user_devices
  drop constraint if exists user_devices_platform_check;

alter table public.user_devices
  add constraint user_devices_platform_check
  check (platform in ('android', 'ios', 'web', 'windows', 'macos', 'linux'));
