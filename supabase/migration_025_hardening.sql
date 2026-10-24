-- =========================================================
-- Migration 025 — security and performance hardening
-- Run in Supabase SQL editor. Safe whether or not migration_011 was
-- applied (the live project never got it), and safe to re-run.
--
-- Fixes found by the Supabase security/performance advisors:
--   1. Reputation could be faked. Any signed-in user could call
--      award_reputation() over and over, and could also set their own
--      profiles.reputation directly. Reputation now changes only through
--      triggers on helpful marks, comments and accepted answers, and
--      students can update only their own profile fields.
--   2. RLS policies called auth.uid() once per row; they now use
--      (select auth.uid()) so it is evaluated once per query.
--   3. "Manage own" FOR ALL policies overlapped the public SELECT
--      policies. They are split into insert/delete policies, keeping a
--      select policy for a student's own saved posts (migration_011
--      accidentally dropped it).
--   4. Foreign keys without indexes.
--   5. rls_auto_enable() was callable through the API.
--   6. Post authors couldn't mark someone else's comment as the accepted
--      answer (RLS blocked it silently) but commenters could accept
--      their own. See set_accepted_answer().
-- =========================================================

-- ── 1. Reputation through triggers ───────────────────────────────────────────
-- Points: +5 to the post author per helpful mark, +1 per comment from
-- someone else, +15 to the comment author when their answer is accepted.
-- Removing the mark, comment or acceptance takes the points back.

create or replace function public.reputation_on_helpful()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _author uuid;
  _actor  uuid := coalesce(new.user_id, old.user_id);
begin
  select author_id into _author
  from public.posts where id = coalesce(new.post_id, old.post_id);
  if _author is null or _author = _actor then
    return null;
  end if;
  update public.profiles
     set reputation = greatest(reputation + case when tg_op = 'INSERT' then 5 else -5 end, 0)
   where id = _author;
  return null;
end;
$$;

drop trigger if exists post_helpful_reputation on public.post_helpful;
create trigger post_helpful_reputation
  after insert or delete on public.post_helpful
  for each row execute function public.reputation_on_helpful();

create or replace function public.reputation_on_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _post_author uuid;
  _row         public.comments := coalesce(new, old);
begin
  select author_id into _post_author from public.posts where id = _row.post_id;

  if tg_op in ('INSERT', 'DELETE') and _post_author is not null
     and _post_author <> _row.author_id then
    update public.profiles
       set reputation = greatest(reputation + case when tg_op = 'INSERT' then 1 else -1 end, 0)
     where id = _post_author;
  end if;

  -- Accepted answer: reward the person who answered, not the asker, and
  -- never for accepting your own comment.
  if _row.author_id is distinct from _post_author then
    if (tg_op = 'UPDATE' and new.is_accepted_answer and not old.is_accepted_answer) then
      update public.profiles set reputation = reputation + 15 where id = new.author_id;
    elsif (tg_op = 'UPDATE' and old.is_accepted_answer and not new.is_accepted_answer)
       or (tg_op = 'DELETE' and old.is_accepted_answer) then
      update public.profiles
         set reputation = greatest(reputation - 15, 0)
       where id = old.author_id;
    end if;
  end if;
  return null;
end;
$$;

drop trigger if exists comments_reputation on public.comments;
create trigger comments_reputation
  after insert or delete or update of is_accepted_answer on public.comments
  for each row execute function public.reputation_on_comment();

-- Older app builds still call award_reputation() after each action. Keep it
-- callable so they don't error, but make it do nothing: the triggers above
-- now award the points.
create or replace function public.award_reputation(target_post_id uuid, action text)
returns void
language sql
security invoker
set search_path = ''
as $$ select $$;

-- Accepting an answer. The comments UPDATE policy only lets a comment's
-- author edit it, so a post author's "Mark accepted" was silently blocked,
-- while a commenter could accept their own comment. Acceptance now goes
-- through this function, which only the post's author can use, and
-- students can edit only the body of their own comments.
create or replace function public.set_accepted_answer(_comment_id uuid, _accepted boolean)
returns void
language plpgsql
security definer
-- public, not '': the existing notify_on_accepted_answer trigger that this
-- update fires refers to tables without a schema.
set search_path = public
as $$
declare
  _post        uuid;
  _post_author uuid;
begin
  select c.post_id, p.author_id into _post, _post_author
  from public.comments c
  join public.posts p on p.id = c.post_id
  where c.id = _comment_id;

  if _post is null then
    raise exception 'Comment not found' using errcode = 'P0002';
  end if;
  if _post_author is distinct from (select auth.uid()) then
    raise exception 'Only the author of the post can accept an answer'
      using errcode = '42501';
  end if;

  if _accepted then
    update public.comments set is_accepted_answer = false
     where post_id = _post and id <> _comment_id and is_accepted_answer;
  end if;
  update public.comments set is_accepted_answer = _accepted
   where id = _comment_id and is_accepted_answer is distinct from _accepted;
end;
$$;
revoke execute on function public.set_accepted_answer(uuid, boolean) from public, anon;
grant execute on function public.set_accepted_answer(uuid, boolean) to authenticated;

revoke update on public.comments from authenticated, anon;
grant update (body) on public.comments to authenticated;

-- Students may change only their own profile fields, never reputation.
revoke insert, update on public.profiles from authenticated, anon;
grant insert (id, username, full_name, avatar_url, department, level, university, bio)
  on public.profiles to authenticated;
grant update (id, username, full_name, avatar_url, department, level, university, bio)
  on public.profiles to authenticated;

-- ── 2 and 3. Policies ────────────────────────────────────────────────────────

-- follows
drop policy if exists "Users manage own follows" on public.follows;
drop policy if exists "Users can insert own follows" on public.follows;
drop policy if exists "Users can delete own follows" on public.follows;
create policy "Users can insert own follows" on public.follows
  for insert to authenticated with check ((select auth.uid()) = follower_id);
create policy "Users can delete own follows" on public.follows
  for delete to authenticated using ((select auth.uid()) = follower_id);

-- post_helpful
drop policy if exists "Users manage own helpful marks" on public.post_helpful;
drop policy if exists "Users can insert own helpful marks" on public.post_helpful;
drop policy if exists "Users can delete own helpful marks" on public.post_helpful;
create policy "Users can insert own helpful marks" on public.post_helpful
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can delete own helpful marks" on public.post_helpful
  for delete to authenticated using ((select auth.uid()) = user_id);

-- post_saves (private: students see only their own)
drop policy if exists "Users manage own saves" on public.post_saves;
drop policy if exists "Users can insert own saves" on public.post_saves;
drop policy if exists "Users can delete own saves" on public.post_saves;
drop policy if exists "Users can view own saves" on public.post_saves;
create policy "Users can view own saves" on public.post_saves
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can insert own saves" on public.post_saves
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can delete own saves" on public.post_saves
  for delete to authenticated using ((select auth.uid()) = user_id);

alter policy "Users can create own comments" on public.comments
  with check ((select auth.uid()) = author_id);
alter policy "Users can update own comments" on public.comments
  using ((select auth.uid()) = author_id);
alter policy "Users can delete own comments" on public.comments
  using ((select auth.uid()) = author_id);

alter policy "Users can update own profile" on public.profiles
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
alter policy "Users can insert own profile" on public.profiles
  with check ((select auth.uid()) = id);

alter policy "Users can create own posts" on public.posts
  with check ((select auth.uid()) = author_id);
alter policy "Users can update own posts" on public.posts
  using ((select auth.uid()) = author_id);
alter policy "Users can delete own posts" on public.posts
  using ((select auth.uid()) = author_id);

alter policy "Users manage own participant row" on public.conversation_participants
  using ((select auth.uid()) = user_id);
alter policy "Users can add participants" on public.conversation_participants
  with check (
    (select auth.uid()) = user_id
    or public.is_conversation_participant(conversation_id, (select auth.uid()))
    or not public.conversation_has_any_participants(conversation_id)
  );
alter policy "Participants can view participant rows" on public.conversation_participants
  using (public.is_conversation_participant(conversation_id, (select auth.uid())));
alter policy "Participants can view their conversations" on public.conversations
  using (public.is_conversation_participant(id, (select auth.uid())));
alter policy "Participants can view messages" on public.messages
  using (public.is_conversation_participant(conversation_id, (select auth.uid())));
alter policy "Participants can send messages" on public.messages
  with check (
    (select auth.uid()) = sender_id
    and public.is_conversation_participant(conversation_id, (select auth.uid()))
  );

alter policy "Users can view own notifications" on public.notifications
  using ((select auth.uid()) = recipient_id);
alter policy "Users can update own notifications" on public.notifications
  using ((select auth.uid()) = recipient_id);

-- ── 4. Foreign key indexes ───────────────────────────────────────────────────
create index if not exists idx_comments_author_id                on public.comments (author_id);
create index if not exists idx_comments_post_id                  on public.comments (post_id);
create index if not exists idx_conversation_participants_user_id on public.conversation_participants (user_id);
create index if not exists idx_follows_followee_id               on public.follows (followee_id);
create index if not exists idx_messages_sender_id                on public.messages (sender_id);
create index if not exists idx_notifications_actor_id            on public.notifications (actor_id);
create index if not exists idx_notifications_post_id             on public.notifications (post_id);
create index if not exists idx_post_helpful_user_id              on public.post_helpful (user_id);
create index if not exists idx_post_reports_reporter_id          on public.post_reports (reporter_id);
create index if not exists idx_post_saves_user_id                on public.post_saves (user_id);
create index if not exists idx_posts_author_id                   on public.posts (author_id);

-- ── 5. Not an API function ───────────────────────────────────────────────────
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end $$;
