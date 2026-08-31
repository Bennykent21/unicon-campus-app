-- =========================================================
-- Migration 012 — fix broken image/avatar uploads
--
-- Root cause: the storage policies used auth.role() = 'authenticated'
-- string-matching, the same unreliable pattern that broke conversation
-- creation earlier. Switching to "to authenticated" role targeting
-- fixed that bug, so we apply the same fix here.
-- =========================================================

drop policy if exists "Authenticated users can upload post images" on storage.objects;
create policy "Authenticated users can upload post images"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'post-images');

drop policy if exists "Users can delete own post images" on storage.objects;
create policy "Users can delete own post images"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'post-images' and (select auth.uid())::text = (storage.foldername(name))[1]);

drop policy if exists "Authenticated users can upload avatars" on storage.objects;
create policy "Authenticated users can upload avatars"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'avatars');

drop policy if exists "Users can update own avatar" on storage.objects;
create policy "Users can update own avatar"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'avatars' and (select auth.uid())::text = (storage.foldername(name))[1]);
