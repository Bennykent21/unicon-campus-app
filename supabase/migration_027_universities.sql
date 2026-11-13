-- =========================================================
-- Migration 027 — one database, separated by university
-- Run in Supabase SQL editor. Don't re-run older migrations.
--
-- Every student belongs to a university, and every post belongs to the
-- university of the student who wrote it. Row Level Security then shows
-- each student only their own university's posts. The feed, search,
-- trending topics and comments all read through posts, so they follow
-- automatically (their views and functions are security invoker).
--
-- Not separated on purpose: profiles (so chat and follows work across
-- schools) and internships (a shared, regional resource).
-- =========================================================

-- ---------- UNIVERSITIES ----------
create table if not exists public.universities (
  id          bigint generated always as identity primary key,
  slug        text not null unique,
  name        text not null unique,
  short_name  text not null,
  city        text,
  created_at  timestamptz not null default now()
);

alter table public.universities enable row level security;

-- Signup shows the list before the student has an account, so anon reads too.
drop policy if exists "Anyone can view universities" on public.universities;
create policy "Anyone can view universities" on public.universities
  for select to anon, authenticated using (true);
grant select on public.universities to anon, authenticated;

insert into public.universities (slug, name, short_name, city) values
  ('abu',      'Ahmadu Bello University',                              'ABU',      'Zaria'),
  ('abuad',    'Afe Babalola University',                              'ABUAD',    'Ado-Ekiti'),
  ('aau',      'Ambrose Alli University',                              'AAU',      'Ekpoma'),
  ('babcock',  'Babcock University',                                   'Babcock',  'Ilishan-Remo'),
  ('buk',      'Bayero University Kano',                               'BUK',      'Kano'),
  ('biu',      'Benson Idahosa University',                            'BIU',      'Benin City'),
  ('covenant', 'Covenant University',                                  'CU',       'Ota'),
  ('delsu',    'Delta State University',                               'DELSU',    'Abraka'),
  ('eksu',     'Ekiti State University',                               'EKSU',     'Ado-Ekiti'),
  ('funaab',   'Federal University of Agriculture, Abeokuta',          'FUNAAB',   'Abeokuta'),
  ('futa',     'Federal University of Technology, Akure',              'FUTA',     'Akure'),
  ('futminna', 'Federal University of Technology, Minna',              'FUT Minna','Minna'),
  ('futo',     'Federal University of Technology, Owerri',             'FUTO',     'Owerri'),
  ('iuo',      'Igbinedion University',                                'IUO',      'Okada'),
  ('lasu',     'Lagos State University',                               'LASU',     'Lagos'),
  ('lautech',  'Ladoke Akintola University of Technology',             'LAUTECH',  'Ogbomoso'),
  ('mouau',    'Michael Okpara University of Agriculture, Umudike',    'MOUAU',    'Umudike'),
  ('unizik',   'Nnamdi Azikiwe University',                            'UNIZIK',   'Awka'),
  ('oau',      'Obafemi Awolowo University',                           'OAU',      'Ile-Ife'),
  ('oou',      'Olabisi Onabanjo University',                          'OOU',      'Ago-Iwoye'),
  ('pau',      'Pan-Atlantic University',                              'PAU',      'Lagos'),
  ('rsu',      'Rivers State University',                              'RSU',      'Port Harcourt'),
  ('uniabuja', 'University of Abuja',                                  'UniAbuja', 'Abuja'),
  ('uniben',   'University of Benin',                                  'UNIBEN',   'Benin City'),
  ('unical',   'University of Calabar',                                'UNICAL',   'Calabar'),
  ('ui',       'University of Ibadan',                                 'UI',       'Ibadan'),
  ('unilorin', 'University of Ilorin',                                 'UNILORIN', 'Ilorin'),
  ('unijos',   'University of Jos',                                    'UNIJOS',   'Jos'),
  ('unilag',   'University of Lagos',                                  'UNILAG',   'Lagos'),
  ('unimaid',  'University of Maiduguri',                              'UNIMAID',  'Maiduguri'),
  ('unn',      'University of Nigeria, Nsukka',                        'UNN',      'Nsukka'),
  ('uniport',  'University of Port Harcourt',                          'UNIPORT',  'Port Harcourt'),
  ('uniuyo',   'University of Uyo',                                    'UNIUYO',   'Uyo'),
  ('udusok',   'Usmanu Danfodiyo University',                          'UDUS',     'Sokoto')
on conflict (slug) do nothing;

-- ---------- PROFILES ----------
alter table public.profiles
  add column if not exists university_id bigint references public.universities(id);
create index if not exists idx_profiles_university_id on public.profiles (university_id);

-- Match the free-text university students typed before this migration.
update public.profiles p
set university_id = u.id
from public.universities u
where p.university_id is null
  and p.university is not null
  and (lower(trim(p.university)) = lower(u.name)
       or lower(trim(p.university)) = lower(u.short_name));

-- The app shows profiles.university as text everywhere; keep it in step
-- with university_id so those screens need no change.
create or replace function public.sync_profile_university_name()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.university_id is not null then
    select u.name into new.university from public.universities u where u.id = new.university_id;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_sync_university_name on public.profiles;
create trigger profiles_sync_university_name
  before insert or update of university_id on public.profiles
  for each row execute function public.sync_profile_university_name();

-- ---------- WHO AM I (for policies) ----------
-- Reads the caller's university without going through profiles' RLS.
-- Only ever answers for auth.uid(), so it reveals nothing about others.
create schema if not exists private;

create or replace function private.my_university_id()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select p.university_id from public.profiles p where p.id = (select auth.uid());
$$;

revoke execute on function private.my_university_id() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.my_university_id() to authenticated;

-- ---------- POSTS ----------
alter table public.posts
  add column if not exists university_id bigint references public.universities(id);

-- Everything posted so far was posted on the UNIBEN-only app.
update public.posts p
set university_id = coalesce(
  (select pr.university_id from public.profiles pr where pr.id = p.author_id),
  (select u.id from public.universities u where u.slug = 'uniben'))
where p.university_id is null;

create index if not exists idx_posts_university_created
  on public.posts (university_id, created_at desc);

-- The database, not the app, decides a post's university: always the
-- author's, and it never changes afterwards.
create or replace function public.set_post_university()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    new.university_id := old.university_id;
    return new;
  end if;

  select p.university_id into new.university_id
  from public.profiles p where p.id = new.author_id;

  if new.university_id is null then
    raise exception 'Choose your university in your profile before posting'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

revoke execute on function public.set_post_university() from public, anon, authenticated;

drop trigger if exists posts_set_university on public.posts;
create trigger posts_set_university
  before insert or update on public.posts
  for each row execute function public.set_post_university();

alter table public.posts alter column university_id set not null;

drop policy if exists "Posts are viewable by everyone" on public.posts;
drop policy if exists "Students see their university's posts" on public.posts;
create policy "Students see their university's posts" on public.posts
  for select to authenticated
  using (
    university_id = (select private.my_university_id())
    or author_id = (select auth.uid())
  );

-- ---------- COMMENTS ----------
-- A comment is visible when its post is (the posts policy applies inside).
drop policy if exists "Comments are viewable by everyone" on public.comments;
drop policy if exists "Comments follow their post" on public.comments;
create policy "Comments follow their post" on public.comments
  for select to authenticated
  using (exists (select 1 from public.posts p where p.id = comments.post_id));

create index if not exists idx_comments_post_id on public.comments (post_id);

-- ---------- WRITING TO A POST YOU CAN'T SEE ----------
-- Comments, helpful marks and saves need the post to be visible to you,
-- so nobody can reach another university's post by its id.
alter policy "Users can create own comments" on public.comments
  with check (
    (select auth.uid()) = author_id
    and exists (select 1 from public.posts p where p.id = comments.post_id)
  );

alter policy "Users can insert own helpful marks" on public.post_helpful
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.posts p where p.id = post_helpful.post_id)
  );

alter policy "Users can insert own saves" on public.post_saves
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.posts p where p.id = post_saves.post_id)
  );

-- ---------- SIGNUP ----------
-- Copy the study details from signup into the profile. When email
-- confirmation is on there is no session at signup, so the app cannot save
-- them itself. An unknown university id is ignored rather than failing signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  uni_id bigint;
begin
  if meta->>'university_id' ~ '^[0-9]+$' then
    select u.id into uni_id from public.universities u
    where u.id = (meta->>'university_id')::bigint;
  end if;

  insert into public.profiles (id, username, full_name, department, level, university_id)
  values (
    new.id,
    coalesce(meta->>'username', split_part(new.email, '@', 1)),
    coalesce(meta->>'full_name', 'New Student'),
    nullif(trim(meta->>'department'), ''),
    nullif(trim(meta->>'level'), ''),
    uni_id
  );
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
