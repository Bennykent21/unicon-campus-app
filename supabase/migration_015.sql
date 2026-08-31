-- =========================================================
-- Migration 015 — allow senders to delete their own messages
-- Run in Supabase SQL editor. Don't re-run older migrations.
--
-- No DELETE policy existed on messages before this, so the new
-- "long-press → Delete" feature would have silently failed via RLS.
-- =========================================================

drop policy if exists "Senders can delete own messages" on messages;
create policy "Senders can delete own messages"
  on messages for delete
  to authenticated
  using ((select auth.uid()) = sender_id);
