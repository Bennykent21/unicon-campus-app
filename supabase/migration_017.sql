-- =========================================================
-- Migration 017 — fix chat images not displaying
--
-- Root cause: migration_013 added an image_url column to the `messages`
-- table, but never updated the `messages_with_sender` VIEW to select it.
-- The app reads from the view, not the table directly, so it always
-- received image_url = null regardless of whether the upload succeeded —
-- explaining "uploads fine, never displays."
-- =========================================================

drop view if exists messages_with_sender;

create view messages_with_sender
with (security_invoker = true)
as
select
  m.id,
  m.conversation_id,
  m.sender_id,
  m.body,
  m.image_url,
  m.created_at,
  pr.full_name  as sender_name,
  pr.avatar_url as sender_avatar
from messages m
join profiles pr on pr.id = m.sender_id;
