/// App-wide static constants shared across features.
class AppConstants {
  AppConstants._();

  // ── Storage bucket names ────────────────────────────────────────────────────
  // These must exactly match what you created in Supabase dashboard → Storage.
  // Names are case-sensitive. Change these if your bucket names differ.
  static const String postImagesBucket = 'post-images';
  static const String avatarsBucket = 'avatars';

  // ── Feed ────────────────────────────────────────────────────────────────────
  static const List<String> defaultFeedFilters = ['All'];

  // ── Post types ──────────────────────────────────────────────────────────────
  static const String postTypeQuestion = 'question';
  static const String postTypeGeneral = 'general';
  static const String postTypeMarketplace = 'marketplace';
  static const String postTypeJob = 'job';
  static const String postTypeEvent = 'event';

  // ── Discover categories ─────────────────────────────────────────────────────
  static const List<Map<String, String>> discoverCategories = [
    {
      'key': 'marketplace',
      'label': 'Marketplace',
      'subtitle': 'Buy and sell items'
    },
    {'key': 'jobs', 'label': 'Jobs', 'subtitle': 'Find internships and jobs'},
    {'key': 'events', 'label': 'Events', 'subtitle': 'See upcoming events'},
    {
      'key': 'scholarships',
      'label': 'Scholarships',
      'subtitle': 'Find scholarship opportunities'
    },
    {
      'key': 'clubs',
      'label': 'Clubs & Societies',
      'subtitle': 'Connect with campus clubs'
    },
    {
      'key': 'trending',
      'label': 'Trending Topics',
      'subtitle': 'What\'s trending on campus'
    },
  ];

  // ── Reputation points ───────────────────────────────────────────────────────
  static const int pointsHelpful = 5;
  static const int pointsAcceptedAnswer = 15;
  static const int pointsComment = 1;

  // ── University levels ───────────────────────────────────────────────────────
  static const List<String> levels = [
    '100L',
    '200L',
    '300L',
    '400L',
    '500L',
    'PG'
  ];
}
