-- =========================================================
-- Migration 007 — fix conversation creation (RLS was blocking it)
-- Run in Supabase SQL editor. Don't re-run older migrations.
--
-- Root cause: schema.sql only added SELECT policies for
-- conversations and conversation_participants. There was no
-- INSERT policy, so creating a new DM silently failed at the
-- database level even though the Flutter code was correct.
-- =========================================================

-- Any authenticated user can create a new conversation
-- (they immediately add themselves as a participant right after,
-- so this is safe — an orphan conversation with no participants
-- is harmless and invisible to everyone via the SELECT policy).
create policy "Authenticated users can create conversations"
  on conversations for insert
  with check (auth.role() = 'authenticated');

-- A user can add themselves as a participant to any conversation.
-- This covers: creating a new DM (add both yourself and the other user),
-- and joining a group/channel later.
create policy "Users can add themselves as participants"
  on conversation_participants for insert
  with check (auth.uid() = user_id);

-- Allow adding OTHER users as participants too, but only if the
-- person doing the inserting is themselves already a participant
-- of that conversation (or the conversation was just created by them —
-- covered by the fact conversations has no owner_id check here).
-- This is needed because starting a DM inserts BOTH participants
-- in one request, and the second row's user_id != auth.uid().
create policy "Participants can add other participants"
  on conversation_participants for insert
  with check (
    exists (
      select 1 from conversation_participants cp
      where cp.conversation_id = conversation_id
        and cp.user_id = auth.uid()
    )
    or
    -- Allow if this is a brand new conversation with no participants yet
    -- (the very first insert in the pair has nothing to check against)
    not exists (
      select 1 from conversation_participants cp2
      where cp2.conversation_id = conversation_id
    )
  );
