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
  static const String postTypeAnnouncement = 'announcement';

  // Discover categories live in lib/features/discover/discover_categories.dart.

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
