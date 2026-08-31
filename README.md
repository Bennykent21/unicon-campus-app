# University Community App

Flutter + Supabase rebuild of the University Community App, structured around
a feature-based architecture (Riverpod) instead of a single main.dart.

## Project structure

```
lib/
  main.dart                 # entry point: loads .env, inits Supabase, runs app
  app.dart                  # MaterialApp.router + theme wiring
  core/
    theme/                  # colors, light/dark ThemeData, theme toggle provider
    router/                 # go_router config (auth redirect + bottom-nav shell)
    widgets/                # bottom_nav_shell.dart (shared shell w/ center FAB)
    supabase/               # SupabaseService wrapper
    constants/              # shared constants (categories, post types, points)
  features/
    home/                   # Home Feed tab
      screens/home_screen.dart
      widgets/post_card.dart
      models/post_model.dart
      providers/home_provider.dart
    chats/                  # Chats tab (DMs / Groups / Channels)
    create/                 # "+" action sheet (Post / Question / Listing / Job / Event / Announcement)
    discover/               # Marketplace / Jobs / Events / Scholarships / Clubs / Trending
    profile/                # Profile + settings + dark mode toggle
supabase/
  schema.sql                # tables, RLS policies, views, realtime config
```

## Setup

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Configure Supabase**
   - Copy `.env.example` to `.env` and fill in your project's URL + anon key
     (Supabase dashboard → Project Settings → API).
   - Run `supabase/schema.sql` in the Supabase SQL editor to create all
     tables, RLS policies, and the `posts_with_engagement` /
     `conversations_for_user` views the app queries.
   - Create two storage buckets (`post-images`, `avatars`) — see the
     commented-out lines at the bottom of `schema.sql`.

3. **Run**
   ```bash
   flutter run
   ```

## What's scaffolded vs. what's next

**Built:**
- Full 5-tab navigation (Home, Chats, Create, Discover, Profile) matching the mockups, light + dark theme
- Home Feed: For You / Following / Trending tabs, filter chips, post cards with type-specific badges (Question/General/Marketplace/Job/Event), Helpful/Comment/Save engagement wired to Supabase
- Chats: DMs/Groups/Channels filter, pinned section, realtime conversation list via Supabase streams
- Create: full action sheet (routes are stubbed — each option needs its own form screen)
- Discover: category list (Marketplace, Jobs, Events, Scholarships, Clubs, Trending)
- Profile: header, stats, settings list, dark mode toggle, sign out
- Supabase schema: profiles, posts, comments, follows, post_helpful/post_saves, conversations/messages, RLS policies, realtime, and the two views the providers query

**Not built yet (good next steps):**
- Auth screens (`/login`, `/signup`) — currently placeholders
- Individual Create forms (post composer, listing form, job form, event form)
- Post detail / comment thread screen
- Individual chat thread screen (message bubbles, sending)
- Discover category detail screens (Marketplace grid, Jobs list, etc. — same pattern as your second mockup's "detailed views" row)
- Notifications screen
- Search

Tell me which of these you want next and I'll build it the same way — full code, wired to this same Supabase schema.
