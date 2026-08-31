-- =========================================================
-- Migration 004 — notifications table + auto-triggers
-- Run in Supabase SQL editor. Don't re-run older migrations.
-- =========================================================

create table if not exists notifications (
  id           uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references profiles(id) on delete cascade,
  actor_id     uuid references profiles(id) on delete set null,
  actor_name   text not null default '',
  actor_avatar text,
  type         text not null, -- comment | helpful | follow | accepted_answer
  message      text not null,
  post_id      uuid references posts(id) on delete cascade,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now()
);

create index if not exists idx_notifications_recipient
  on notifications (recipient_id, created_at desc);

alter table notifications enable row level security;

create policy "Users can view own notifications"
  on notifications for select using (auth.uid() = recipient_id);

create policy "Users can update own notifications"
  on notifications for update using (auth.uid() = recipient_id);

-- ── Trigger: notify post author when someone comments ─────────────────────────
create or replace function notify_on_comment()
returns trigger as $$
declare
  _author_id   uuid;
  _author_name text;
  _actor_name  text;
  _actor_avatar text;
begin
  -- Get the post author
  select author_id into _author_id from posts where id = new.post_id;
  -- Don't notify yourself
  if _author_id = new.author_id then return new; end if;

  select full_name, avatar_url
    into _actor_name, _actor_avatar
    from profiles where id = new.author_id;

  insert into notifications
    (recipient_id, actor_id, actor_name, actor_avatar, type, message, post_id)
  values
    (_author_id, new.author_id, _actor_name, _actor_avatar,
     'comment', 'commented on your post', new.post_id);

  return new;
end;
$$ language plpgsql security definer;

create trigger on_comment_created
  after insert on comments
  for each row execute procedure notify_on_comment();

-- ── Trigger: notify post author when someone marks Helpful ───────────────────
create or replace function notify_on_helpful()
returns trigger as $$
declare
  _author_id    uuid;
  _actor_name   text;
  _actor_avatar text;
begin
  select author_id into _author_id from posts where id = new.post_id;
  if _author_id = new.user_id then return new; end if;

  select full_name, avatar_url
    into _actor_name, _actor_avatar
    from profiles where id = new.user_id;

  insert into notifications
    (recipient_id, actor_id, actor_name, actor_avatar, type, message, post_id)
  values
    (_author_id, new.user_id, _actor_name, _actor_avatar,
     'helpful', 'found your post helpful', new.post_id);

  return new;
end;
$$ language plpgsql security definer;

create trigger on_helpful_created
  after insert on post_helpful
  for each row execute procedure notify_on_helpful();

-- ── Trigger: notify when someone follows you ─────────────────────────────────
create or replace function notify_on_follow()
returns trigger as $$
declare
  _actor_name   text;
  _actor_avatar text;
begin
  select full_name, avatar_url
    into _actor_name, _actor_avatar
    from profiles where id = new.follower_id;

  insert into notifications
    (recipient_id, actor_id, actor_name, actor_avatar, type, message)
  values
    (new.followee_id, new.follower_id, _actor_name, _actor_avatar,
     'follow', 'started following you');

  return new;
end;
$$ language plpgsql security definer;

create trigger on_follow_created
  after insert on follows
  for each row execute procedure notify_on_follow();

-- ── Trigger: notify comment author when answer is accepted ───────────────────
create or replace function notify_on_accepted_answer()
returns trigger as $$
declare
  _actor_name   text;
  _actor_avatar text;
  _post_author  uuid;
begin
  -- Only fire when is_accepted_answer flips to true
  if new.is_accepted_answer = false or old.is_accepted_answer = true then
    return new;
  end if;

  select author_id into _post_author from posts where id = new.post_id;
  select full_name, avatar_url
    into _actor_name, _actor_avatar
    from profiles where id = _post_author;

  insert into notifications
    (recipient_id, actor_id, actor_name, actor_avatar, type, message, post_id)
  values
    (new.author_id, _post_author, _actor_name, _actor_avatar,
     'accepted_answer', 'accepted your answer', new.post_id);

  return new;
end;
$$ language plpgsql security definer;

create trigger on_answer_accepted
  after update on comments
  for each row execute procedure notify_on_accepted_answer();
