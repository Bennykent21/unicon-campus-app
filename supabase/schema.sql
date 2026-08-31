-- =========================================================
-- University Community App — Supabase schema
-- Run this in the Supabase SQL editor (or via `supabase db push`)
-- =========================================================

-- ---------- PROFILES ----------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  full_name text not null,
  avatar_url text,
  department text,        -- e.g. "CPE"
  level text,              -- e.g. "400L"
  university text,
  bio text,
  reputation int not null default 0,
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;
create policy "Profiles are viewable by everyone" on profiles for select using (true);
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on profiles for insert with check (auth.uid() = id);

-- Auto-create a profile row on signup
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'full_name', 'New Student')
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- ---------- FOLLOWS ----------
create table if not exists follows (
  follower_id uuid references profiles(id) on delete cascade,
  followee_id uuid references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id)
);
alter table follows enable row level security;
create policy "Follows are viewable by everyone" on follows for select using (true);
create policy "Users manage own follows" on follows for all using (auth.uid() = follower_id);

-- ---------- POSTS ----------
create table if not exists posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles(id) on delete cascade,
  type text not null check (type in ('question','general','marketplace','job','event')),
  title text not null,
  body text not null default '',
  tags text[] not null default '{}',
  image_urls text[] not null default '{}',
  -- marketplace
  price numeric,
  -- job
  job_location text,
  is_internship boolean,
  -- event
  event_date timestamptz,
  event_location text,
  created_at timestamptz not null default now()
);

create index if not exists idx_posts_created_at on posts (created_at desc);
create index if not exists idx_posts_type on posts (type);
create index if not exists idx_posts_tags on posts using gin (tags);

alter table posts enable row level security;
create policy "Posts are viewable by everyone" on posts for select using (true);
create policy "Users can create own posts" on posts for insert with check (auth.uid() = author_id);
create policy "Users can update own posts" on posts for update using (auth.uid() = author_id);
create policy "Users can delete own posts" on posts for delete using (auth.uid() = author_id);

-- ---------- POST ENGAGEMENT ----------
create table if not exists post_helpful (
  post_id uuid references posts(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table post_helpful enable row level security;
create policy "Helpful marks viewable by everyone" on post_helpful for select using (true);
create policy "Users manage own helpful marks" on post_helpful for all using (auth.uid() = user_id);

create table if not exists post_saves (
  post_id uuid references posts(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table post_saves enable row level security;
create policy "Users manage own saves" on post_saves for all using (auth.uid() = user_id);

create table if not exists comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  body text not null,
  is_accepted_answer boolean not null default false,
  created_at timestamptz not null default now()
);
alter table comments enable row level security;
create policy "Comments are viewable by everyone" on comments for select using (true);
create policy "Users can create own comments" on comments for insert with check (auth.uid() = author_id);
create policy "Users can update own comments" on comments for update using (auth.uid() = author_id);
create policy "Users can delete own comments" on comments for delete using (auth.uid() = author_id);

-- View combining posts with engagement counts + current-user flags.
-- (auth.uid() resolves per-request, so is_*_by_me is correct per caller.)
create or replace view posts_with_engagement as
select
  p.*,
  pr.full_name as author_name,
  pr.avatar_url as author_avatar_url,
  coalesce(pr.department || ' ' || pr.level, '') as author_level,
  coalesce(h.helpful_count, 0) as helpful_count,
  coalesce(c.comment_count, 0) as comment_count,
  exists(select 1 from post_saves s where s.post_id = p.id and s.user_id = auth.uid()) as is_saved_by_me,
  exists(select 1 from post_helpful hh where hh.post_id = p.id and hh.user_id = auth.uid()) as is_helpful_by_me,
  exists(select 1 from comments cc where cc.post_id = p.id and cc.is_accepted_answer) as has_accepted_answer
from posts p
join profiles pr on pr.id = p.author_id
left join (select post_id, count(*) helpful_count from post_helpful group by post_id) h on h.post_id = p.id
left join (select post_id, count(*) comment_count from comments group by post_id) c on c.post_id = p.id;

-- ---------- CHATS ----------
create table if not exists conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('dm','group','channel')),
  title text,            -- null for DMs (derived from the other participant)
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists conversation_participants (
  conversation_id uuid references conversations(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  is_pinned boolean not null default false,
  last_read_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_messages_conversation on messages (conversation_id, created_at desc);

alter table conversations enable row level security;
alter table conversation_participants enable row level security;
alter table messages enable row level security;

create policy "Participants can view their conversations" on conversations for select using (
  exists (select 1 from conversation_participants cp where cp.conversation_id = id and cp.user_id = auth.uid())
);
create policy "Participants can view participant rows" on conversation_participants for select using (
  exists (select 1 from conversation_participants cp2 where cp2.conversation_id = conversation_id and cp2.user_id = auth.uid())
);
create policy "Users manage own participant row" on conversation_participants for update using (auth.uid() = user_id);
create policy "Participants can view messages" on messages for select using (
  exists (select 1 from conversation_participants cp where cp.conversation_id = conversation_id and cp.user_id = auth.uid())
);
create policy "Participants can send messages" on messages for insert with check (
  auth.uid() = sender_id and
  exists (select 1 from conversation_participants cp where cp.conversation_id = conversation_id and cp.user_id = auth.uid())
);

-- View used by chatsStreamProvider: one row per conversation the caller is in,
-- with last message + unread count precomputed.
create or replace view conversations_for_user as
select
  c.id,
  c.kind,
  case when c.kind = 'dm' then op.full_name else c.title end as title,
  case when c.kind = 'dm' then op.avatar_url else c.avatar_url end as avatar_url,
  coalesce(lm.body, '') as last_message,
  coalesce(lm.created_at, c.created_at) as last_message_at,
  coalesce(unread.cnt, 0) as unread_count,
  cp.is_pinned,
  cp.user_id as viewer_id
from conversations c
join conversation_participants cp on cp.conversation_id = c.id and cp.user_id = auth.uid()
left join lateral (
  select m.body, m.created_at from messages m
  where m.conversation_id = c.id order by m.created_at desc limit 1
) lm on true
left join lateral (
  -- For DMs, show the *other* participant's name/avatar
  select pr.full_name, pr.avatar_url from conversation_participants cp2
  join profiles pr on pr.id = cp2.user_id
  where cp2.conversation_id = c.id and cp2.user_id != auth.uid() and c.kind = 'dm'
  limit 1
) op on true
left join lateral (
  select count(*) cnt from messages m2
  where m2.conversation_id = c.id and m2.created_at > cp.last_read_at and m2.sender_id != auth.uid()
) unread on true;

-- ---------- REALTIME ----------
-- Enable realtime on tables the app streams from.
alter publication supabase_realtime add table messages;
alter publication supabase_realtime add table conversations;
alter publication supabase_realtime add table conversation_participants;

-- ---------- STORAGE ----------
-- Run once: create a public bucket for post images & avatars.
-- insert into storage.buckets (id, name, public) values ('post-images', 'post-images', true);
-- insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true);
