-- =========================================================
-- Migration 005 — update posts_with_engagement view
-- Must DROP first because column names changed from original.
-- CASCADE handles any dependent views automatically.
-- =========================================================

drop view if exists posts_with_engagement cascade;

create view posts_with_engagement as
select
  p.*,
  pr.full_name  as author_name,
  pr.username   as author_username,
  pr.avatar_url as author_avatar_url,
  case
    when pr.department is not null and pr.level is not null
      then pr.department || ' · ' || pr.level
    when pr.department is not null then pr.department
    when pr.level      is not null then pr.level
    else ''
  end as author_level,
  coalesce(h.helpful_count, 0) as helpful_count,
  coalesce(c.comment_count, 0) as comment_count,
  exists(
    select 1 from post_saves s
    where s.post_id = p.id and s.user_id = auth.uid()
  ) as is_saved_by_me,
  exists(
    select 1 from post_helpful hh
    where hh.post_id = p.id and hh.user_id = auth.uid()
  ) as is_helpful_by_me,
  exists(
    select 1 from comments cc
    where cc.post_id = p.id and cc.is_accepted_answer
  ) as has_accepted_answer,
  exists(
    select 1 from follows f
    where f.follower_id = auth.uid() and f.followee_id = p.author_id
  ) as is_following_author
from posts p
join profiles pr on pr.id = p.author_id
left join (
  select post_id, count(*) as helpful_count
  from post_helpful group by post_id
) h on h.post_id = p.id
left join (
  select post_id, count(*) as comment_count
  from comments group by post_id
) c on c.post_id = p.id;
