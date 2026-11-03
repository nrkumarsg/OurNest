-- Migration: 20261102000003_storage_media_and_push_webhook.sql
-- Description: Private media storage bucket, RLS policies for encrypted files, and push notification webhook hook

-- 1. Create the private 'media' bucket in storage.buckets if not exists
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'media',
  'media',
  false, -- STRICTLY PRIVATE: no public access
  52428800, -- 50MB max file size
  null -- ciphertext binary payloads
)
on conflict (id) do update set public = false;

-- 2. Storage RLS Policies for 'media' bucket
-- Storage objects path structure: media/{family_id}/{file_uuid}
-- Only active members of the family can upload or download media files

-- Allow active family members to upload media into their family's folder
create policy "Active family members can upload media"
  on storage.objects
  for insert
  with check (
    bucket_id = 'media' and
    public.is_active_member((storage.foldername(name))[1]::uuid)
  );

-- Allow active family members to read encrypted media files from their family's folder
create policy "Active family members can read family media"
  on storage.objects
  for select
  using (
    bucket_id = 'media' and
    public.is_active_member((storage.foldername(name))[1]::uuid)
  );

-- Allow the uploader (or admin) to delete media
create policy "Senders or admins can delete media"
  on storage.objects
  for delete
  using (
    bucket_id = 'media' and
    (owner = auth.uid() or public.is_family_admin((storage.foldername(name))[1]::uuid))
  );
