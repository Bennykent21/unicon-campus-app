-- =========================================================
-- Migration 021 — real Report Post backend
-- Run in Supabase SQL editor. Don't re-run older migrations.
-- =========================================================

create table if not exists post_reports (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references posts(id) on delete cascade,
  reporter_id uuid not null references profiles(id) on delete cascade,
  reason      text,
  created_at  timestamptz not null default now()
);

create index if not exists idx_post_reports_post_id on post_reports (post_id);

alter table post_reports enable row level security;

create policy "Users can report posts"
  on post_reports for insert
  to authenticated
  with check ((select auth.uid()) = reporter_id);
