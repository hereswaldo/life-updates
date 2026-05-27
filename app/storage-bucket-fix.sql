-- Fix for storage bucket creation.
-- Use this if the bucket "photos" doesn't appear in Storage in the Supabase dashboard.
-- Run this in the SQL editor (or just create the bucket manually via UI).

-- Option A: SQL approach
-- Some Supabase projects block direct inserts into storage.buckets.
-- If this works, the bucket will appear in your Storage dashboard.
insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

-- Re-apply storage policies (safe to re-run)
drop policy if exists "photos_select" on storage.objects;
drop policy if exists "photos_insert" on storage.objects;
drop policy if exists "photos_update" on storage.objects;
drop policy if exists "photos_delete" on storage.objects;

create policy "photos_select" on storage.objects for select using (bucket_id = 'photos');
create policy "photos_insert" on storage.objects for insert with check (
  bucket_id = 'photos' and auth.role() = 'authenticated'
);
create policy "photos_update" on storage.objects for update using (
  bucket_id = 'photos' and auth.uid()::text = (storage.foldername(name))[1]
);
create policy "photos_delete" on storage.objects for delete using (
  bucket_id = 'photos' and auth.uid()::text = (storage.foldername(name))[1]
);

-- Option B (recommended if A still doesn't work): Create via dashboard
-- 1. Click "Storage" in the left sidebar of Supabase
-- 2. Click "New bucket"
-- 3. Name: photos
-- 4. Check "Public bucket"
-- 5. Save
-- Then re-run the policies block above.
