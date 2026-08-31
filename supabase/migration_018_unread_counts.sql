-- Migration 018: per-conversation unread message counts
--
-- The Flutter client (ChatModel / chats_screen) already renders an
-- `unread_count` badge per conversation, but the `conversations_for_user`
-- view may not compute it. Rather than recreating that view (whose exact
-- definition varies), this adds a standalone RPC the client merges in.
--
-- A message is "unread" for a user when:
--   * it belongs to a conversation the user participates in
--   * it was created after the participant's last_read_at
--     (or last_read_at is NULL, i.e. never opened the thread)
--   * it was NOT sent by the user themselves
--
-- Run this in the Supabase SQL editor.

create or replace function public.get_unread_counts()
returns table (conversation_id uuid, unread_count bigint)
language sql
stable
security invoker
set search_path = public
as $$
  select
    m.conversation_id,
    count(*)::bigint as unread_count
  from public.messages m
  join public.conversation_participants cp
    on cp.conversation_id = m.conversation_id
   and cp.user_id = auth.uid()
  where m.sender_id <> auth.uid()
    and (cp.last_read_at is null or m.created_at > cp.last_read_at)
  group by m.conversation_id;
$$;

grant execute on function public.get_unread_counts() to authenticated;

-- Speeds up the unread count scan (conversation + recency).
create index if not exists idx_messages_conversation_created
  on public.messages (conversation_id, created_at desc);
