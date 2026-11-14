-- =========================================================
-- Migration 029 — let students save their university
-- Run in Supabase SQL editor. Safe to re-run.
--
-- Migration 025 lets students write only listed profile columns.
-- university_id (migration 027) wasn't on the list, so saving a profile
-- failed with "permission denied for table profiles". The name column
-- (university) is filled in by a trigger, so it needs no new grant.
-- =========================================================

grant insert (university_id) on public.profiles to authenticated;
grant update (university_id) on public.profiles to authenticated;
