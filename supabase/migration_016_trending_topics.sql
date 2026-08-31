-- migration_016_trending_topics.sql
-- Moves trending-topic computation from the Flutter client into Postgres.
--
-- Before: the app downloaded the `tags` column of up to 200 recent posts and
-- counted tag frequencies in Dart. That caps accuracy at 200 rows, wastes
-- bandwidth, and pushes work onto every client device.
--
-- After: a single set-based query runs where the data lives. It unnests the
-- tags array, counts occurrences over the requested window, and returns only
-- the top N tags.
--
-- Run this in the Supabase SQL editor (or via `supabase db push`).

create or replace function public.get_trending_topics(
  days_back  int default 7,
  max_topics int default 12
)
returns table (tag text, tag_count bigint)
language sql
stable
security invoker            -- respects the posts table's RLS policies
set search_path = public
as $$
  select t.tag, count(*)::bigint as tag_count
  from posts p
  cross join lateral unnest(p.tags) as t(tag)
  where p.created_at >= now() - make_interval(days => days_back)
    and t.tag <> ''
  group by t.tag
  order by tag_count desc, t.tag asc
  limit max_topics;
$$;

-- Allow signed-in users (and anon, if your feed is public) to call it.
grant execute on function public.get_trending_topics(int, int) to authenticated;
grant execute on function public.get_trending_topics(int, int) to anon;

-- Optional but recommended: index to keep the 7-day window scan fast as the
-- posts table grows.
create index if not exists idx_posts_created_at on posts (created_at desc);
