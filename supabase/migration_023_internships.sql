-- =========================================================
-- Migration 023 — internship board
-- Run in Supabase SQL editor AFTER migration_022. Then run
-- migration_024_internship_seed.sql to load the starting listings.
--
-- Listings live in their own tables instead of `posts` because they need
-- structure (deadline, eligibility, documents, contacts) and someone
-- accountable for keeping them correct. Students keep posting gigs as
-- ordinary job posts.
--
--   companies               who is hiring
--   internships             one opening (SIWES, internship, graduate trainee,
--                           remote programme or free training)
--   internship_applications a student's private tracker row per listing
--   internship_alumni       "I trained here" — students who did IT at a company
--   curators                who may add or edit listings (managed in the
--                           dashboard; the app never writes to it)
-- =========================================================

-- ── Curators ──────────────────────────────────────────────────────────────────
-- A separate table rather than a profiles.role column: profiles has a
-- "users can update own profile" policy, so a role column there would let any
-- student make themselves a curator.
create table if not exists public.curators (
  user_id    uuid primary key references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.curators enable row level security;
-- No policies: only the service role / dashboard can read or write it.

create or replace function public.is_curator()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.curators where user_id = (select auth.uid())
  );
$$;
grant execute on function public.is_curator() to authenticated;

-- ── Companies ─────────────────────────────────────────────────────────────────
create table if not exists public.companies (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  industry   text,
  city       text,
  address    text,
  website    text,
  logo_url   text,
  created_at timestamptz not null default now()
);
alter table public.companies enable row level security;

create policy "Signed-in users can view companies"
  on public.companies for select to authenticated using (true);
create policy "Curators can add companies"
  on public.companies for insert to authenticated with check ((select public.is_curator()));
create policy "Curators can edit companies"
  on public.companies for update to authenticated using ((select public.is_curator()));
create policy "Curators can delete companies"
  on public.companies for delete to authenticated using ((select public.is_curator()));

-- ── Internships ───────────────────────────────────────────────────────────────
create table if not exists public.internships (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete cascade,
  title         text not null,
  kind          text not null
                check (kind in ('siwes','internship','graduate_trainee','remote_program','training')),
  work_mode     text not null default 'onsite'
                check (work_mode in ('onsite','hybrid','remote')),
  location      text,
  summary       text not null default '',
  duration      text,                         -- free text: "6 months", "3, 6 or 12 months"
  stipend       text,                         -- free text: "Monthly stipend", "₦50,000 / month"
  is_paid       boolean,                      -- null = not stated
  -- Broad fields of study (see lib/features/internships/utils/field_matcher.dart).
  -- Empty array = open to every field.
  fields        text[] not null default '{}',
  -- e.g. {'300L','400L'}. Empty array = any level.
  levels        text[] not null default '{}',
  requirements  text[] not null default '{}', -- documents / conditions
  how_to_apply  text[] not null default '{}', -- ordered steps
  apply_url     text,
  apply_email   text,
  apply_phone   text,
  contact_name  text,
  -- open: taking applications; rolling: any time; contact: write to the
  -- company directly; expected: a new window is expected (see opens_note);
  -- closed: this cycle is over.
  status        text not null default 'open'
                check (status in ('open','rolling','contact','expected','closed')),
  opens_note    text,
  deadline      date,
  uniben_note   text,                         -- why this is relevant to UNIBEN students
  source_url    text,                         -- where the information came from
  last_checked  date,
  is_published  boolean not null default true,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists idx_internships_company on public.internships (company_id);
create index if not exists idx_internships_status_deadline on public.internships (status, deadline);
create index if not exists idx_internships_fields on public.internships using gin (fields);
create index if not exists idx_internships_created_by on public.internships (created_by);

alter table public.internships enable row level security;

create policy "Signed-in users can view published internships"
  on public.internships for select to authenticated
  using (is_published or (select public.is_curator()));
create policy "Curators can add internships"
  on public.internships for insert to authenticated with check ((select public.is_curator()));
create policy "Curators can edit internships"
  on public.internships for update to authenticated using ((select public.is_curator()));
create policy "Curators can delete internships"
  on public.internships for delete to authenticated using ((select public.is_curator()));

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists internships_touch_updated_at on public.internships;
create trigger internships_touch_updated_at
  before update on public.internships
  for each row execute function public.touch_updated_at();

-- ── Application tracker (private to each student) ─────────────────────────────
create table if not exists public.internship_applications (
  user_id        uuid not null references public.profiles(id) on delete cascade,
  internship_id  uuid not null references public.internships(id) on delete cascade,
  stage          text not null default 'saved'
                 check (stage in ('saved','applied','interview','offer','declined')),
  applied_on     date,
  follow_up_on   date,
  interview_at   timestamptz,
  notes          text,
  updated_at     timestamptz not null default now(),
  primary key (user_id, internship_id)
);
-- The PK covers lookups by user; this covers the FK to internships.
create index if not exists idx_internship_applications_internship
  on public.internship_applications (internship_id);

alter table public.internship_applications enable row level security;

create policy "Students see their own applications"
  on public.internship_applications for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Students add their own applications"
  on public.internship_applications for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Students update their own applications"
  on public.internship_applications for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Students delete their own applications"
  on public.internship_applications for delete to authenticated
  using ((select auth.uid()) = user_id);

drop trigger if exists internship_applications_touch_updated_at on public.internship_applications;
create trigger internship_applications_touch_updated_at
  before update on public.internship_applications
  for each row execute function public.touch_updated_at();

-- ── "I trained here" ──────────────────────────────────────────────────────────
create table if not exists public.internship_alumni (
  company_id  uuid not null references public.companies(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  year        int  not null check (year between 1990 and 2100),
  created_at  timestamptz not null default now(),
  primary key (company_id, user_id)
);
create index if not exists idx_internship_alumni_user on public.internship_alumni (user_id);

alter table public.internship_alumni enable row level security;

create policy "Signed-in users can see who trained where"
  on public.internship_alumni for select to authenticated using (true);
create policy "Students add themselves as alumni"
  on public.internship_alumni for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Students remove themselves as alumni"
  on public.internship_alumni for delete to authenticated
  using ((select auth.uid()) = user_id or (select public.is_curator()));

-- ── Flat view for the app ─────────────────────────────────────────────────────
-- security_invoker so it respects the RLS above (see migration_009).
drop view if exists public.internships_with_company;
create view public.internships_with_company
with (security_invoker = true)
as
select
  i.*,
  c.name      as company_name,
  c.industry  as company_industry,
  c.city      as company_city,
  c.address   as company_address,
  c.website   as company_website,
  c.logo_url  as company_logo_url,
  coalesce(al.alumni_count, 0) as alumni_count,
  app.stage   as my_stage
from public.internships i
join public.companies c on c.id = i.company_id
left join lateral (
  select count(*)::int as alumni_count
  from public.internship_alumni a
  where a.company_id = i.company_id
) al on true
left join public.internship_applications app
  on app.internship_id = i.id and app.user_id = (select auth.uid());

-- ── Data API access ───────────────────────────────────────────────────────────
-- New tables may not be exposed automatically, depending on project settings.
grant select on public.companies, public.internships, public.internship_alumni,
  public.internships_with_company to authenticated;
grant insert, update, delete on public.companies, public.internships to authenticated;
grant select, insert, update, delete on public.internship_applications to authenticated;
grant insert, delete on public.internship_alumni to authenticated;
