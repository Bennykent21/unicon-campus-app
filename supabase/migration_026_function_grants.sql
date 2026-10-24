-- =========================================================
-- Migration 026 — keep internal functions out of the API
-- Run after migration_025. Safe to re-run.
--
-- Supabase exposes every function in the public schema at
-- /rest/v1/rpc/<name>, and new functions are executable by anon and
-- authenticated by default. The security advisor flagged:
--   1. reputation_on_helpful() and reputation_on_comment(): trigger
--      functions. Postgres refuses to call them outside a trigger, so
--      this was never exploitable, but nothing should be able to call
--      them. Triggers still fire: they don't need EXECUTE.
--   2. is_curator(): only RLS policies for signed-in users use it, so
--      signed-out visitors don't need it.
-- set_accepted_answer, is_conversation_participant and
-- conversation_has_any_participants stay callable by signed-in users:
-- the app and the chat policies use them, and each checks the caller.
-- =========================================================

revoke execute on function public.reputation_on_helpful() from public, anon, authenticated;
revoke execute on function public.reputation_on_comment() from public, anon, authenticated;

revoke execute on function public.is_curator() from public, anon;
grant execute on function public.is_curator() to authenticated;
