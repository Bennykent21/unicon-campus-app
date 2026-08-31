-- =========================================================
-- Migration 008 — fix infinite RLS recursion on conversation_participants
-- Run in Supabase SQL editor. Don't re-run older migrations.
--
-- Root cause: policies on conversation_participants and conversations
-- checked membership by querying conversation_participants FROM WITHIN
-- a policy ON conversation_participants. Postgres has to evaluate that
-- table's RLS policy to run the subquery, which re-triggers the same
-- policy — infinite recursion (error 42P17).
--
-- Fix: SECURITY DEFINER functions run with elevated privileges and
-- bypass RLS internally, so using them inside policies breaks the loop.
-- This is the standard Supabase-recommended pattern for this problem.
-- =========================================================

-- ── Helper functions (bypass RLS — safe because they only return booleans) ────

create or replace function is_conversation_participant(_conversation_id uuid, _user_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from conversation_participants
    where conversation_id = _conversation_id and user_id = _user_id
  );
$$;

create or replace function conversation_has_any_participants(_conversation_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from conversation_participants
    where conversation_id = _conversation_id
  );
$$;

-- ── Drop old recursive policies ────────────────────────────────────────────────

drop policy if exists "Participants can view their conversations" on conversations;
drop policy if exists "Participants can view participant rows" on conversation_participants;
drop policy if exists "Participants can view messages" on messages;
drop policy if exists "Participants can send messages" on messages;
drop policy if exists "Participants can add other participants" on conversation_participants;

-- ── Recreate using the helper functions (no recursion) ─────────────────────────

create policy "Participants can view their conversations"
  on conversations for select
  using (is_conversation_participant(id, auth.uid()));

create policy "Participants can view participant rows"
  on conversation_participants for select
  using (is_conversation_participant(conversation_id, auth.uid()));

create policy "Participants can view messages"
  on messages for select
  using (is_conversation_participant(conversation_id, auth.uid()));

create policy "Participants can send messages"
  on messages for insert
  with check (
    auth.uid() = sender_id
    and is_conversation_participant(conversation_id, auth.uid())
  );

-- Combined INSERT policy for conversation_participants:
-- - You can always add yourself
-- - You can add someone else if you're already a participant
-- - You can add someone else if the conversation has no participants yet
--   (covers creating a brand-new DM, where the 2nd insert happens
--   right after the 1st is committed)
create policy "Users can add participants"
  on conversation_participants for insert
  with check (
    auth.uid() = user_id
    or is_conversation_participant(conversation_id, auth.uid())
    or not conversation_has_any_participants(conversation_id)
  );
