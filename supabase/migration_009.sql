-- =========================================================
-- Migration 009 — security & RLS fixes from Supabase linter
-- Run in Supabase SQL editor. Don't re-run older migrations.
-- =========================================================

-- ── A. Fix conversation creation (the new "forbidden" 42501 error) ─────────────
-- auth.role() = 'authenticated' string-matching is less reliable than
-- Postgres's native "to authenticated" role targeting on the policy itself.

drop policy if exists "Authenticated users can create conversations" on conversations;
create policy "Authenticated users can create conversations"
  on conversations for insert
  to authenticated
  with check (true);

drop policy if exists "Users can add participants" on conversation_participants;
create policy "Users can add participants"
  on conversation_participants for insert
  to authenticated
  with check (
    auth.uid() = user_id
    or is_conversation_participant(conversation_id, auth.uid())
    or not conversation_has_any_participants(conversation_id)
  );

drop policy if exists "Participants can send messages" on messages;
create policy "Participants can send messages"
  on messages for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and is_conversation_participant(conversation_id, auth.uid())
  );

-- ── B. Fix SECURITY DEFINER views (ERROR-level — real security holes) ──────────
-- Views default to running as their creator, bypassing the querying user's RLS.
-- security_invoker=true makes each view respect the RLS of whoever is querying
-- it instead. This matters most for messages_with_sender — without this fix,
-- ANY authenticated user could read messages from conversations they're not
-- part of, because the view ignored the "participants only" policy entirely.

alter view public.profiles_with_counts    set (security_invoker = true);
alter view public.posts_with_engagement   set (security_invoker = true);
alter view public.comments_with_author    set (security_invoker = true);
alter view public.conversations_for_user  set (security_invoker = true);
alter view public.messages_with_sender    set (security_invoker = true);

-- ── C. Fix mutable search_path on functions (WARN-level) ────────────────────────
-- Without a fixed search_path, a function's unqualified table references could
-- theoretically be hijacked by a malicious schema earlier in the search path.
-- Pinning it to 'public' closes that.

alter function public.update_post_comment_count()     set search_path = public;
alter function public.update_post_votes()              set search_path = public;
alter function public.update_conversation_last_message() set search_path = public;
alter function public.handle_new_user()                 set search_path = public;
alter function public.award_reputation(uuid, text)      set search_path = public;
alter function public.notify_on_comment()                set search_path = public;
alter function public.notify_on_helpful()                 set search_path = public;
alter function public.notify_on_follow()                   set search_path = public;
alter function public.notify_on_accepted_answer()            set search_path = public;
alter function public.is_conversation_participant(uuid, uuid) set search_path = public;
alter function public.conversation_has_any_participants(uuid)  set search_path = public;
-- Note: rls_auto_enable() is a Supabase-managed internal function — not ours to alter, skip it.

-- ── D. Tighten EXECUTE grants on SECURITY DEFINER functions (WARN-level) ───────
-- These functions currently accept RPC calls from anyone, including logged-out
-- users. Restrict trigger-only functions entirely, and app-called functions to
-- signed-in users only.

-- Trigger-only functions — never called directly by the app, only by DB triggers.
-- Triggers don't need the invoking role to have EXECUTE, so this is safe.
revoke execute on function public.handle_new_user()                 from public, anon, authenticated;
revoke execute on function public.notify_on_comment()                 from public, anon, authenticated;
revoke execute on function public.notify_on_helpful()                  from public, anon, authenticated;
revoke execute on function public.notify_on_follow()                    from public, anon, authenticated;
revoke execute on function public.notify_on_accepted_answer()             from public, anon, authenticated;

-- award_reputation is called by the app via .rpc() — must stay callable,
-- but only by logged-in users, not anonymous visitors.
revoke execute on function public.award_reputation(uuid, text) from public, anon;
grant  execute on function public.award_reputation(uuid, text) to authenticated;

-- Helper functions used only inside RLS policies — authenticated users need
-- EXECUTE for their own queries' policies to evaluate, but anonymous callers
-- should not be able to invoke them directly via RPC.
revoke execute on function public.is_conversation_participant(uuid, uuid)     from public, anon;
grant  execute on function public.is_conversation_participant(uuid, uuid)     to authenticated;
revoke execute on function public.conversation_has_any_participants(uuid)     from public, anon;
grant  execute on function public.conversation_has_any_participants(uuid)     to authenticated;

-- ── E. Remove redundant public-bucket listing policies (WARN-level) ────────────
-- Both buckets are PUBLIC, so individual file URLs (what CachedNetworkImage
-- actually uses) are served directly without needing a SELECT RLS policy at
-- all. These policies only added the ability to LIST every file in the bucket,
-- which isn't needed and unnecessarily exposes the full file listing.

drop policy if exists "Anyone can view avatars"     on storage.objects;
drop policy if exists "Anyone can view post images" on storage.objects;
