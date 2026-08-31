-- =========================================================
-- Migration 011 — performance fixes from Supabase linter
-- Run AFTER confirming migration_010 fixed chat creation.
-- Run in Supabase SQL editor. Don't re-run older migrations.
-- =========================================================

-- ── A. Consolidate overlapping policies on follows/post_helpful/post_saves ─────
-- Each had a "manage own" FOR ALL policy stacked on top of a "viewable by
-- everyone" SELECT policy — Postgres had to check both on every read.
-- Splitting into precise INSERT/DELETE-only policies removes the overlap
-- and wraps auth.uid() in (select ...) so it's evaluated once per query
-- instead of once per row.

drop policy if exists "Users manage own follows" on follows;
create policy "Users can insert own follows"
  on follows for insert to authenticated
  with check ((select auth.uid()) = follower_id);
create policy "Users can delete own follows"
  on follows for delete to authenticated
  using ((select auth.uid()) = follower_id);

drop policy if exists "Users manage own helpful marks" on post_helpful;
create policy "Users can insert own helpful marks"
  on post_helpful for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can delete own helpful marks"
  on post_helpful for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users manage own saves" on post_saves;
create policy "Users can insert own saves"
  on post_saves for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can delete own saves"
  on post_saves for delete to authenticated
  using ((select auth.uid()) = user_id);

-- ── B. Wrap auth.uid() in (select ...) on the remaining policies ───────────────
-- (ALTER POLICY updates the expression without needing to drop/recreate.)

alter policy "Users can create own comments" on comments
  with check ((select auth.uid()) = author_id);
alter policy "Users can update own comments" on comments
  using ((select auth.uid()) = author_id);
alter policy "Users can delete own comments" on comments
  using ((select auth.uid()) = author_id);

alter policy "Users can update own profile" on profiles
  using ((select auth.uid()) = id);
alter policy "Users can insert own profile" on profiles
  with check ((select auth.uid()) = id);

alter policy "Users can create own posts" on posts
  with check ((select auth.uid()) = author_id);
alter policy "Users can update own posts" on posts
  using ((select auth.uid()) = author_id);
alter policy "Users can delete own posts" on posts
  using ((select auth.uid()) = author_id);

alter policy "Users manage own participant row" on conversation_participants
  using ((select auth.uid()) = user_id);

alter policy "Users can add participants" on conversation_participants
  with check (
    (select auth.uid()) = user_id
    or is_conversation_participant(conversation_id, (select auth.uid()))
    or not conversation_has_any_participants(conversation_id)
  );

alter policy "Participants can view participant rows" on conversation_participants
  using (is_conversation_participant(conversation_id, (select auth.uid())));

alter policy "Participants can view their conversations" on conversations
  using (is_conversation_participant(id, (select auth.uid())));

alter policy "Participants can view messages" on messages
  using (is_conversation_participant(conversation_id, (select auth.uid())));

alter policy "Participants can send messages" on messages
  with check (
    (select auth.uid()) = sender_id
    and is_conversation_participant(conversation_id, (select auth.uid()))
  );

alter policy "Users can view own notifications" on notifications
  using ((select auth.uid()) = recipient_id);
alter policy "Users can update own notifications" on notifications
  using ((select auth.uid()) = recipient_id);

-- ── C. Add missing indexes on foreign key columns ───────────────────────────────
-- Speeds up joins and cascade deletes on these relationships.

create index if not exists idx_comments_author_id               on comments (author_id);
create index if not exists idx_comments_post_id                 on comments (post_id);
create index if not exists idx_conversation_participants_user_id on conversation_participants (user_id);
create index if not exists idx_follows_followee_id               on follows (followee_id);
create index if not exists idx_messages_sender_id                on messages (sender_id);
create index if not exists idx_notifications_actor_id            on notifications (actor_id);
create index if not exists idx_notifications_post_id             on notifications (post_id);
create index if not exists idx_post_helpful_user_id              on post_helpful (user_id);
create index if not exists idx_post_saves_user_id                on post_saves (user_id);
create index if not exists idx_posts_author_id                   on posts (author_id);

-- Note: the linter also flagged idx_messages_conversation as "unused" —
-- that's expected for a low-traffic dev project and not a problem. It's
-- the right index for ordering messages by conversation, and will show
-- as used once there's more real usage data.
