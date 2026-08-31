-- =========================================================
-- Migration 002 — comments view, reputation function,
-- storage policies for post-images + avatars buckets
-- Run this in the Supabase SQL editor AFTER schema.sql
-- =========================================================

-- ── Comments view (joins author profile so Flutter just gets flat rows) ──────
create or replace view comments_with_author as
select
  c.id,
  c.post_id,
  c.author_id,
  c.body,
  c.is_accepted_answer,
  c.created_at,
  pr.full_name   as author_name,
  pr.avatar_url  as author_avatar_url,
  coalesce(pr.department || ' ' || pr.level, '') as author_level
from comments c
join profiles pr on pr.id = c.author_id;

-- ── award_reputation: called after helpful / comment / accepted_answer ────────
-- Finds the post author and increments their reputation score.
create or replace function award_reputation(
  target_post_id uuid,
  action         text   -- 'helpful' | 'comment' | 'accepted_answer'
)
returns void
language plpgsql
security definer
as $$
declare
  _author_id uuid;
  _points    int;
begin
  select author_id into _author_id from posts where id = target_post_id;
  if _author_id is null then return; end if;

  -- Don't award points to yourself
  if _author_id = auth.uid() then return; end if;

  _points := case action
    when 'helpful'         then 5
    when 'comment'         then 1
    when 'accepted_answer' then 15
    else 0
  end;

  update profiles
  set reputation = reputation + _points
  where id = _author_id;
end;
$$;

-- ── Storage bucket policies ───────────────────────────────────────────────────
-- Create buckets first (if not already done via dashboard):
-- insert into storage.buckets (id, name, public) values ('post-images', 'post-images', true) on conflict do nothing;
-- insert into storage.buckets (id, name, public) values ('avatars',     'avatars',     true) on conflict do nothing;

-- post-images: authenticated users can upload; everyone can read
create policy "Anyone can view post images"
  on storage.objects for select
  using (bucket_id = 'post-images');

create policy "Authenticated users can upload post images"
  on storage.objects for insert
  with check (bucket_id = 'post-images' and auth.role() = 'authenticated');

create policy "Users can delete own post images"
  on storage.objects for delete
  using (bucket_id = 'post-images' and auth.uid()::text = (storage.foldername(name))[1]);

-- avatars: same pattern
create policy "Anyone can view avatars"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "Authenticated users can upload avatars"
  on storage.objects for insert
  with check (bucket_id = 'avatars' and auth.role() = 'authenticated');

create policy "Users can update own avatar"
  on storage.objects for update
  using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);
