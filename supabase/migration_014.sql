-- =========================================================
-- Migration 014 — force avatars & chat-images buckets to be public
-- Run in Supabase SQL editor. Don't re-run older migrations.
--
-- If a bucket was created earlier without public=true (e.g. via an
-- earlier manual dashboard step), direct image URLs return 400/403
-- even if the policies are correct — the "public" flag on the bucket
-- itself is what allows unauthenticated URL access at all.
-- =========================================================

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

insert into storage.buckets (id, name, public)
values ('chat-images', 'chat-images', true)
on conflict (id) do update set public = true;

insert into storage.buckets (id, name, public)
values ('post-images', 'post-images', true)
on conflict (id) do update set public = true;

-- Re-affirm the upload policies once more, in case they were affected
-- by the same rollback issue we hit with the conversations fix earlier.
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

drop policy if exists "Authenticated users can upload chat images" on storage.objects;
create policy "Authenticated users can upload chat images"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'chat-images');
