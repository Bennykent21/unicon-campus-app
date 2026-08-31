-- =========================================================
-- Migration 010 — isolated fix for conversation creation
-- Run in Supabase SQL editor. Don't re-run older migrations.
--
-- This migration ONLY touches conversations/conversation_participants/
-- messages INSERT policies — nothing else. Kept deliberately small and
-- self-contained so a typo elsewhere can't roll back this critical fix
-- (which is likely what happened with migration_009 — one failed
-- statement rolled back the whole script, including the working part).
-- =========================================================

-- Consolidate conversation_participants INSERT into ONE policy
-- (previously had two overlapping ones, which is also flagged by the
-- performance linter as wasteful).
drop policy if exists "Users can add themselves as participants" on conversation_participants;
drop policy if exists "Users can add participants" on conversation_participants;

create policy "Users can add participants"
  on conversation_participants for insert
  to authenticated
  with check (
    auth.uid() = user_id
    or is_conversation_participant(conversation_id, auth.uid())
    or not conversation_has_any_participants(conversation_id)
  );

-- conversations INSERT policy
drop policy if exists "Authenticated users can create conversations" on conversations;
create policy "Authenticated users can create conversations"
  on conversations for insert
  to authenticated
  with check (true);

-- messages INSERT policy
drop policy if exists "Participants can send messages" on messages;
create policy "Participants can send messages"
  on messages for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and is_conversation_participant(conversation_id, auth.uid())
  );
