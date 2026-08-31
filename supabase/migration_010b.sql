-- =========================================================
-- Migration 010b — single isolated statement, run ALONE
-- Paste ONLY this into the SQL editor and run it by itself.
-- =========================================================

drop policy if exists "Authenticated users can create conversations" on conversations;

create policy "Authenticated users can create conversations"
  on conversations
  for insert
  to authenticated
  with check (true);
