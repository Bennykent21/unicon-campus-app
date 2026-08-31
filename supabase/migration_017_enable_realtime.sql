-- migration_017_enable_realtime.sql
--
-- Enables Supabase Realtime on the tables the app listens to.
--
-- WHY THIS IS NEEDED:
-- Supabase Realtime only broadcasts postgres_changes events for tables
-- explicitly added to the `supabase_realtime` publication. If a table is
-- not in the publication, `.stream()` in supabase_flutter does its initial
-- fetch and then NEVER receives another event — no error, it just silently
-- stays stale. This is the classic "everything needs a manual refresh" bug.
--
-- Run this once in the Supabase SQL editor.

-- Chat messages: powers the live chat thread AND the new app-wide channel
-- that refreshes the chat list + bottom-nav unread badge instantly.
alter publication supabase_realtime add table public.messages;

-- Comments: powers live comment updates on post detail screens.
alter publication supabase_realtime add table public.comments;

-- Notifications: powers the instant bell badge on the home screen.
alter publication supabase_realtime add table public.notifications;

-- Ensure UPDATE/DELETE events include the full old row (needed so clients
-- can reconcile deletions/edits in streams, e.g. deleted chat messages).
alter table public.messages      replica identity full;
alter table public.comments      replica identity full;
alter table public.notifications replica identity full;

-- NOTE: if any of these tables were already added to the publication you
-- will get: 'relation "x" is already member of publication'. That is
-- harmless — just remove that line and re-run the rest.
