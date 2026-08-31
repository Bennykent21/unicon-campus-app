-- =========================================================
-- Migration 019 — fix delete not reflecting live in chat
--
-- Root cause: by default, Postgres only includes the PRIMARY KEY in a
-- DELETE event's replicated data — not the other columns. Our chat
-- stream filters by conversation_id, but a delete event without that
-- column means the Supabase Realtime client can't tell which filtered
-- list the deleted row belonged to, so it never removes it locally.
-- Only a fresh query (app restart) would show the correct state.
--
-- REPLICA IDENTITY FULL tells Postgres to include ALL columns in the
-- delete event, not just the primary key, so the client-side filter can
-- correctly match and remove it in real time.
-- =========================================================

alter table messages replica identity full;
