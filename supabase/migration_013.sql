-- =========================================================
-- Migration 013 — chat image attachments + unread count support
-- Run in Supabase SQL editor. Don't re-run older migrations.
-- =========================================================

-- ── Add image support to messages ───────────────────────────────────────────────
alter table messages add column if not exists image_url text;

-- ── Create chat-images bucket (safe if it already exists) ──────────────────────
insert into storage.buckets (id, name, public)
values ('chat-images', 'chat-images', true)
on conflict (id) do nothing;

drop policy if exists "Authenticated users can upload chat images" on storage.objects;
create policy "Authenticated users can upload chat images"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'chat-images');
