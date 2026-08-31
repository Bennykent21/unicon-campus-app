-- =========================================================
-- Migration 003 — profiles_with_counts view
-- Run in Supabase SQL editor. Don't re-run migration_002.
-- =========================================================

-- Flat view used by myProfileProvider and profileByIdProvider.
-- Includes post count, follower count, following count so Flutter
-- doesn't need three separate queries just to render the profile header.
create or replace view profiles_with_counts as
select
  p.id,
  p.username,
  p.full_name,
  p.avatar_url,
  p.department,
  p.level,
  p.university,
  p.bio,
  p.reputation,
  p.created_at,
  coalesce(pc.post_count,      0) as post_count,
  coalesce(fc.follower_count,  0) as follower_count,
  coalesce(fg.following_count, 0) as following_count
from profiles p
left join (
  select author_id, count(*) as post_count
  from posts
  group by author_id
) pc on pc.author_id = p.id
left join (
  select followee_id, count(*) as follower_count
  from follows
  group by followee_id
) fc on fc.followee_id = p.id
left join (
  select follower_id, count(*) as following_count
  from follows
  group by follower_id
) fg on fg.follower_id = p.id;
