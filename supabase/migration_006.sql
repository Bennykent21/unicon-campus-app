-- =========================================================
-- Migration 006 — messages_with_sender view
-- Run in Supabase SQL editor. Don't re-run older migrations.
-- =========================================================

create or replace view messages_with_sender as
select
  m.id,
  m.conversation_id,
  m.sender_id,
  m.body,
  m.created_at,
  pr.full_name  as sender_name,
  pr.avatar_url as sender_avatar
from messages m
join profiles pr on pr.id = m.sender_id;
