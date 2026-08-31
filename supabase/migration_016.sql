-- =========================================================
-- Migration 016 — isolated re-check of chat-images bucket
-- Run in Supabase SQL editor. Don't re-run older migrations.
-- =========================================================

insert into storage.buckets (id, name, public)
values ('chat-images', 'chat-images', true)
on conflict (id) do update set public = true;

drop policy if exists "Authenticated users can upload chat images" on storage.objects;
create policy "Authenticated users can upload chat images"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'chat-images');
