# UNICON — Campus Community App

A full-stack, cross-platform mobile app that centralizes academic discussion, Q&A, a campus marketplace, job/internship listings, events, and real-time messaging for university students — built solo from schema to UI.

**Stack:** Flutter · Dart · Riverpod · go_router · Supabase (PostgreSQL, Auth, Realtime, Storage)

---

## Why this project is worth a look

Most student projects are CRUD demos. This one required solving real production-grade problems:

- **Row Level Security done properly** — every table is protected by RLS, including policies that needed `SECURITY DEFINER` helper functions to avoid infinite recursion (a genuinely tricky Postgres gotcha most tutorials never cover).
- **Realtime vs. views** — discovered and fixed a subtle bug class where Supabase Realtime silently never fires for database views (only physical tables), which broke live chat/comment updates until traced to the root cause.
- **Optimistic UI** — engagement actions (likes, saves, follows) update instantly client-side and reconcile with the server in the background, with rollback on failure.
- **Feature-first architecture** — ~50 modular Dart files organized by feature (`home`, `chats`, `profile`, `discover`, `create`, `auth`, `notifications`), not by layer, for maintainability at scale.

## Features

- **Auth** — email/password signup with guided profile setup, session-aware routing (auto-redirects based on auth + profile completeness)
- **Home Feed** — infinite-scroll feed supporting 6 post types (general, question, marketplace, job, event, announcement), tag/type filtering, full-text search, trending topics
- **Engagement** — helpful votes, saves, comments with accepted-answer marking (Q&A style), reputation scoring via Postgres functions
- **Profile** — editable profile with avatar upload, followers/following, activity history, dark mode (persisted)
- **Discover** — category browsing for Marketplace, Jobs, Events, Announcements, Scholarships
- **Internship board** — SIWES placements, internships, graduate trainee schemes and remote programmes open to UNIBEN students, matched to each student's department and level. Each listing shows eligibility, documents to send, step-by-step application instructions, contacts and its source. Students draft their application email or SIWES letter from their profile in one tap, see which UNIBEN students trained at a company, and track each application from saved to offer (private to them through RLS)
- **Chat** — real-time 1:1 messaging with image attachments, message deletion, read-state tracking
- **Notifications** — event-driven via Postgres triggers (comment, helpful, follow, accepted-answer)

## Architecture

```
lib/
  core/            # theme, router, shared widgets, Supabase client wrapper
  features/
    auth/
    home/
    chats/
    profile/
    discover/
    create/
    notifications/
supabase/
  migrations/      # numbered, sequential SQL migrations (schema, RLS, triggers, views)
```

- **State management:** Riverpod (`StateNotifier` + `FutureProvider`/`StreamProvider`)
- **Routing:** `go_router` with auth-aware redirects and deep-linkable routes
- **Backend:** Supabase — Postgres with RLS on every table, Realtime for chat, Storage for images/avatars (public buckets with upload-scoped policies)

## Security highlights

```sql
-- Example: SECURITY DEFINER used to break RLS recursion on conversation
-- membership checks (a self-referential policy would otherwise infinite-loop)
create or replace function is_conversation_participant(_conversation_id uuid, _user_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from conversation_participants
    where conversation_id = _conversation_id and user_id = _user_id
  );
$$;
```

Every insert/select/update/delete policy across posts, comments, messages, follows, and storage objects is scoped to `auth.uid()` — no table is left open by default.

## Screenshots
<img width="1080" height="2340" alt="108745" src="https://github.com/user-attachments/assets/42dbad74-de1c-4d97-90ce-ece10afa82e3" />
<img width="1080" height="2717" alt="108744" src="https://github.com/user-attachments/assets/916a7a16-818d-4676-9a61-7b4430d4f9c3" />
<img width="1080" height="2340" alt="108743" src="https://github.com/user-attachments/assets/a306fa13-bc4d-44df-aded-cab46b859957" />
<img width="1080" height="2340" alt="108742" src="https://github.com/user-attachments/assets/1e3df5fb-cb4c-47a9-aa25-3d6e8cf88ab7" />
<img width="1080" height="2340" alt="108741" src="https://github.com/user-attachments/assets/531f4f7b-a87a-48d0-bc7c-414af55f8e4f" />
<img width="1080" height="2340" alt="108740" src="https://github.com/user-attachments/assets/47802263-4c53-490b-bab8-3b6b2f12371c" />

<!-- Add screenshots here: Home feed, Post detail, Chat, Profile, Discover -->

## Download the app

Every push builds a release APK on GitHub Actions (`.github/workflows/android.yml`), after `flutter analyze` and the tests pass. Open [Releases](https://github.com/Bennykent21/unicon-campus-app/releases) on an Android phone, pick the newest `UNICON build N`, download the `.apk` and open it. Builds are signed with the same key each time, so a new one installs over the old one.

The build reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from repository secrets when they are set (Settings → Secrets and variables → Actions); otherwise it uses this project's public client key.

## Setup

1. `flutter pub get`
2. Copy `.env.example` → `.env`, add your Supabase URL + anon key
3. Run migrations in `supabase/` sequentially in the Supabase SQL editor, ending with `migration_022_announcements.sql`, `migration_023_internships.sql`, `migration_024_internship_seed.sql` (the starting internship listings) and `migration_025_hardening.sql` (server-side reputation, accepted answers, tighter RLS and indexes)
4. Create `avatars`, `post-images`, and `chat-images` storage buckets (public)
5. `flutter run`
6. `flutter test` runs the unit and widget tests

To let someone add or edit internship listings, insert their user id into the `curators` table from the Supabase dashboard. The app never writes to that table.

## Known limitations / roadmap

- Group chats and channels (DMs are fully implemented; groups are schema-ready but UI not yet built)
- Message reactions and reply-threading
- An in-app screen for curators to add listings (today they are added in the Supabase dashboard)
- Older migrations need consolidating: `migration_009` references a function that only exists in the original project, and `migration_017_enable_realtime` re-adds a table that `schema.sql` already published, so both fail on a brand-new project
- Block/mute users

## About

Final year Computer Engineering project, University of Benin. Built end-to-end solo — schema design, backend security, and full Flutter UI.

**Author:** Oghosa Benedict — [LinkedIn](https://linkedin.com/in/oghosabenedict-721119287) · [GitHub](https://github.com/Bennykent21)
