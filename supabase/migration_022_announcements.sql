-- =========================================================
-- Migration 022 — announcement post type
-- Run in Supabase SQL editor. Don't re-run older migrations.
--
-- The app has offered "Share Announcement" since the create menu was built,
-- but posts.type only allowed five values, so the composer quietly saved
-- announcements as 'general'. This adds 'announcement' to the constraint and
-- converts nothing: older announcements stay 'general' because there is no
-- reliable way to tell them apart.
-- =========================================================

alter table public.posts drop constraint if exists posts_type_check;
alter table public.posts
  add constraint posts_type_check
  check (type in ('question','general','marketplace','job','event','announcement'));
