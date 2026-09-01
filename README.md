# University Community App

## Setup

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Run**
   ```bash
   flutter run
   ```

**Built:**
- Full 5-tab navigation (Home, Chats, Create, Discover, Profile) matching the mockups, light + dark theme
- Home Feed: For You / Following / Trending tabs, filter chips, post cards with type-specific badges (Question/General/Marketplace/Job/Event), Helpful/Comment/Save engagement wired to Supabase
- Chats: DMs/Groups/Channels filter, pinned section, realtime conversation list via Supabase streams
- Create: full action sheet (routes are stubbed — each option needs its own form screen)
- Discover: category list (Marketplace, Jobs, Events, Scholarships, Clubs, Trending)
- Profile: header, stats, settings list, dark mode toggle, sign out
- Supabase schema: profiles, posts, comments, follows, post_helpful/post_saves, conversations/messages, RLS policies, realtime, and the two views the providers query
- Auth screens (`/login`, `/signup`) — currently placeholders
- Individual Create forms (post composer, listing form, job form, event form)
- Post detail / comment thread screen
- Individual chat thread screen (message bubbles, sending)
- Discover category detail screens (Marketplace grid, Jobs list, etc. — same pattern as your second mockup's "detailed views" row)
- Notifications screen
- Search
