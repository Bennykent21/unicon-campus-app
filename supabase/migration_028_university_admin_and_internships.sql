-- =========================================================
-- Migration 028 — school-only internships, university requests, curators
--                  manage universities
-- Run in Supabase SQL editor after migration 027. Safe to re-run.
-- =========================================================

-- ---------- INTERNSHIPS FOR ONE UNIVERSITY ----------
-- university_id null = open to students of any university (most listings).
-- Set it for listings only one school's students can take.
alter table public.internships
  add column if not exists university_id bigint references public.universities(id);
create index if not exists idx_internships_university_id on public.internships (university_id);

drop policy if exists "Signed-in users can view published internships" on public.internships;
create policy "Signed-in users can view published internships"
  on public.internships for select to authenticated
  using (
    (select public.is_curator())
    or (is_published
        and (university_id is null
             or university_id = (select private.my_university_id())))
  );

-- The seeded listings were written for UNIBEN students. They are open to
-- anyone who can get there, so make the wording school-neutral.
update public.internships
set requirements = array_replace(requirements, 'Copy of your UNIBEN ID card', 'Copy of your student ID card')
where 'Copy of your UNIBEN ID card' = any(requirements);

update public.internships
set uniben_note = 'Open to graduates of any Nigerian university.'
where uniben_note = 'For UNIBEN graduates.';

update public.internships
set uniben_note = 'Has trained engineering undergraduates from Benin City universities before.'
where uniben_note = 'Has trained UNIBEN engineering undergraduates before.';

-- The app's flat view gains the school a listing is limited to.
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
  app.stage   as my_stage,
  u.short_name as university_short_name
from public.internships i
join public.companies c on c.id = i.company_id
left join public.universities u on u.id = i.university_id
left join lateral (
  select count(*)::int as alumni_count
  from public.internship_alumni a
  where a.company_id = i.company_id
) al on true
left join public.internship_applications app
  on app.internship_id = i.id and app.user_id = (select auth.uid());

grant select on public.internships_with_company to authenticated;

-- ---------- CURATORS MANAGE UNIVERSITIES ----------
drop policy if exists "Curators can add universities" on public.universities;
create policy "Curators can add universities" on public.universities
  for insert to authenticated with check ((select public.is_curator()));

drop policy if exists "Curators can edit universities" on public.universities;
create policy "Curators can edit universities" on public.universities
  for update to authenticated
  using ((select public.is_curator())) with check ((select public.is_curator()));

grant insert, update on public.universities to authenticated;

-- Lets the app show curator-only screens. Only answers for the caller.
grant execute on function public.is_curator() to authenticated;

-- ---------- "MY UNIVERSITY ISN'T LISTED" ----------
create table if not exists public.university_requests (
  id            bigint generated always as identity primary key,
  name          text not null check (char_length(trim(name)) between 3 and 120),
  city          text check (city is null or char_length(city) <= 60),
  email         text check (email is null or (char_length(email) <= 254 and email like '%_@_%')),
  requested_by  uuid references public.profiles(id) on delete set null,
  status        text not null default 'pending'
                check (status in ('pending', 'added', 'declined')),
  university_id bigint references public.universities(id) on delete set null,
  created_at    timestamptz not null default now(),
  reviewed_at   timestamptz
);

create index if not exists idx_university_requests_status
  on public.university_requests (status, created_at desc);
create index if not exists idx_university_requests_requested_by
  on public.university_requests (requested_by);
create index if not exists idx_university_requests_university_id
  on public.university_requests (university_id);

alter table public.university_requests enable row level security;

-- Students ask from the signup screen, before they have an account.
drop policy if exists "Anyone can request a university" on public.university_requests;
create policy "Anyone can request a university" on public.university_requests
  for insert to anon, authenticated
  with check (
    status = 'pending'
    and university_id is null
    and reviewed_at is null
    and (requested_by is null or requested_by = (select auth.uid()))
  );

drop policy if exists "Curators can view university requests" on public.university_requests;
create policy "Curators can view university requests" on public.university_requests
  for select to authenticated using ((select public.is_curator()));

drop policy if exists "Curators can review university requests" on public.university_requests;
create policy "Curators can review university requests" on public.university_requests
  for update to authenticated
  using ((select public.is_curator())) with check ((select public.is_curator()));

grant insert on public.university_requests to anon, authenticated;
grant select, update on public.university_requests to authenticated;
