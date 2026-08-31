-- =========================================================
-- Migration 018 — re-affirm message delete policy
-- Run in Supabase SQL editor. Don't re-run older migrations.
-- =========================================================

drop policy if exists "Senders can delete own messages" on messages;
create policy "Senders can delete own messages"
  on messages for delete
  to authenticated
  using ((select auth.uid()) = sender_id);
