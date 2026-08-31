import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/utils/app_logger.dart';
import '../models/post_model.dart';

enum FeedTab { forYou, following }

final feedTabProvider = StateProvider<FeedTab>((ref) => FeedTab.forYou);
final feedFiltersProvider = StateProvider<Set<String>>((ref) => {});

const _typeFilterMap = {
  'Question': 'question',
  'Marketplace': 'marketplace',
  'Job': 'job',
  'Event': 'event',
  'General': 'general',
};

// ── Unread notification count ─────────────────────────────────────────────────
final unreadNotificationsProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return 0;
  final data = await SupabaseService.client
      .from('notifications')
      .select('id')
      .eq('recipient_id', userId)
      .eq('is_read', false);
  return (data as List).length;
});

// ── Trending topics (used in Search screen) ───────────────────────────────────
/// Counts tag occurrences client-side. Kept as a pure function so it can be
/// unit-tested and reused as the fallback when the RPC is unavailable.
List<String> computeTrendingTags(List<Map<String, dynamic>> rows,
    {int maxTopics = 12}) {
  final tagCount = <String, int>{};
  for (final row in rows) {
    final tags =
        (row['tags'] as List?)?.map((t) => t.toString()).toList() ?? <String>[];
    for (final tag in tags) {
      if (tag.isNotEmpty) tagCount[tag] = (tagCount[tag] ?? 0) + 1;
    }
  }
  final sorted = tagCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(maxTopics).map((e) => e.key).toList();
}

/// Trending topics are computed in Postgres via the `get_trending_topics`
/// function (see supabase/migration_016_trending_topics.sql). Falls back to
/// the old client-side computation if the function hasn't been deployed yet.
final trendingTopicsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final client = SupabaseService.client;
  try {
    final data = await client.rpc('get_trending_topics',
        params: {'days_back': 7, 'max_topics': 12});
    return (data as List).map((row) => row['tag'] as String).toList();
  } catch (e, st) {
    AppLogger.warning(
        'get_trending_topics RPC failed, falling back to client-side: $e',
        name: 'trending');
    AppLogger.error('trending RPC error',
        name: 'trending', error: e, stackTrace: st);
    final since =
        DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final data = await client
        .from('posts')
        .select('tags')
        .gte('created_at', since)
        .limit(200);
    return computeTrendingTags(
        (data as List).cast<Map<String, dynamic>>());
  }
});

// ── Paginated feed ────────────────────────────────────────────────────────────
class FeedState {
  final List<PostModel> posts;

  /// True only during the very first page load (show shimmer).
  final bool isInitialLoading;

  /// True while an additional page is being fetched (show bottom spinner).
  final bool isLoadingMore;

  /// False once a page returns fewer rows than [FeedNotifier.pageSize].
  final bool hasMore;
  final String? error;

  const FeedState({
    this.posts = const [],
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  FeedState copyWith({
    List<PostModel>? posts,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  static const pageSize = 20;

  final FeedTab tab;
  final Set<String> filters;

  /// Cached followee ids for the Following tab so we don't re-fetch them for
  /// every page.
  List<String>? _followeeIds;

  FeedNotifier({required this.tab, required this.filters})
      : super(const FeedState(isInitialLoading: true)) {
    _loadInitial();
  }

  List<String> get _typeFilters => filters
      .where((f) => _typeFilterMap.containsKey(f))
      .map((f) => _typeFilterMap[f]!)
      .toList();

  List<String> get _tagFilters =>
      filters.where((f) => !_typeFilterMap.containsKey(f)).toList();

  Future<List<PostModel>> _fetchPage(int offset) async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUserId;

    if (tab == FeedTab.following) {
      if (userId == null) return [];
      _followeeIds ??= ((await client
              .from('follows')
              .select('followee_id')
              .eq('follower_id', userId)) as List)
          .map((e) => e['followee_id'] as String)
          .toList();
      if (_followeeIds!.isEmpty) return [];
    }

    var query = client.from('posts_with_engagement').select();
    if (tab == FeedTab.following) {
      query = query.inFilter('author_id', _followeeIds!);
    }
    if (_tagFilters.isNotEmpty) query = query.overlaps('tags', _tagFilters);
    if (_typeFilters.isNotEmpty) query = query.inFilter('type', _typeFilters);

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + pageSize - 1);
    return (data as List).map((e) => PostModel.fromJson(e)).toList();
  }

  Future<void> _loadInitial() async {
    try {
      final page = await _fetchPage(0);
      if (!mounted) return;
      state = FeedState(
        posts: page,
        hasMore: page.length == pageSize,
      );
    } catch (e, st) {
      AppLogger.error('Failed to load feed', name: 'feed', error: e, stackTrace: st);
      if (!mounted) return;
      state = FeedState(error: e.toString(), hasMore: false);
    }
  }

  /// Pull-to-refresh: reloads page one and resets pagination.
  Future<void> refresh() async {
    _followeeIds = null;
    try {
      final page = await _fetchPage(0);
      if (!mounted) return;
      state = FeedState(
        posts: page,
        hasMore: page.length == pageSize,
      );
    } catch (e, st) {
      AppLogger.error('Failed to refresh feed',
          name: 'feed', error: e, stackTrace: st);
      if (!mounted) return;
      // Keep existing posts on refresh failure — just surface the error.
      state = state.copyWith(error: e.toString());
    }
  }

  /// Fetches the next page. Safe to call repeatedly — no-ops while a page is
  /// already loading or when there is nothing more to fetch.
  Future<void> loadMore() async {
    if (state.isInitialLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _fetchPage(state.posts.length);
      if (!mounted) return;
      state = state.copyWith(
        posts: [...state.posts, ...page],
        isLoadingMore: false,
        hasMore: page.length == pageSize,
      );
    } catch (e, st) {
      AppLogger.error('Failed to load more posts',
          name: 'feed', error: e, stackTrace: st);
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }
}

/// Autodispose + watches tab/filters, so switching tab or changing filters
/// recreates the notifier and reloads from page one.
final feedPostsProvider =
    StateNotifierProvider.autoDispose<FeedNotifier, FeedState>((ref) {
  final tab = ref.watch(feedTabProvider);
  final filters = ref.watch(feedFiltersProvider);
  return FeedNotifier(tab: tab, filters: filters);
});

// ── Optimistic engagement overlay ─────────────────────────────────────────────
typedef EngagementState = ({
  bool isHelpfulByMe,
  int helpfulCount,
  bool isSavedByMe
});
final engagementOverlayProvider =
    StateProvider<Map<String, EngagementState>>((ref) => {});
final followOverlayProvider = StateProvider<Map<String, bool>>((ref) => {});

class EngagementNotifier extends StateNotifier<void> {
  final Ref _ref;
  EngagementNotifier(this._ref) : super(null);

  Future<void> toggleHelpful(PostModel post) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final overlay = _ref.read(engagementOverlayProvider);
    final current = overlay[post.id] ??
        (
          isHelpfulByMe: post.isHelpfulByMe,
          helpfulCount: post.helpfulCount,
          isSavedByMe: post.isSavedByMe,
        );
    final nowHelpful = !current.isHelpfulByMe;
    _ref.read(engagementOverlayProvider.notifier).update((s) => {
          ...s,
          post.id: (
            isHelpfulByMe: nowHelpful,
            helpfulCount: nowHelpful
                ? current.helpfulCount + 1
                : current.helpfulCount - 1,
            isSavedByMe: current.isSavedByMe,
          ),
        });
    try {
      if (current.isHelpfulByMe) {
        await SupabaseService.client
            .from('post_helpful')
            .delete()
            .match({'post_id': post.id, 'user_id': userId});
      } else {
        await SupabaseService.client
            .from('post_helpful')
            .insert({'post_id': post.id, 'user_id': userId});
      }
    } catch (e, st) {
      AppLogger.error('toggleHelpful failed — rolling back',
          name: 'engagement', error: e, stackTrace: st);
      _ref
          .read(engagementOverlayProvider.notifier)
          .update((s) => {...s, post.id: current});
    }
  }

  Future<void> toggleSave(PostModel post) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final overlay = _ref.read(engagementOverlayProvider);
    final current = overlay[post.id] ??
        (
          isHelpfulByMe: post.isHelpfulByMe,
          helpfulCount: post.helpfulCount,
          isSavedByMe: post.isSavedByMe,
        );
    final nowSaved = !current.isSavedByMe;
    _ref.read(engagementOverlayProvider.notifier).update((s) => {
          ...s,
          post.id: (
            isHelpfulByMe: current.isHelpfulByMe,
            helpfulCount: current.helpfulCount,
            isSavedByMe: nowSaved,
          ),
        });
    try {
      if (current.isSavedByMe) {
        await SupabaseService.client
            .from('post_saves')
            .delete()
            .match({'post_id': post.id, 'user_id': userId});
      } else {
        await SupabaseService.client
            .from('post_saves')
            .insert({'post_id': post.id, 'user_id': userId});
      }
    } catch (e, st) {
      AppLogger.error('toggleSave failed — rolling back',
          name: 'engagement', error: e, stackTrace: st);
      _ref
          .read(engagementOverlayProvider.notifier)
          .update((s) => {...s, post.id: current});
    }
  }

  Future<void> toggleFollow(String authorId, bool currentlyFollowing) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null || userId == authorId) return;
    _ref
        .read(followOverlayProvider.notifier)
        .update((s) => {...s, authorId: !currentlyFollowing});
    try {
      if (currentlyFollowing) {
        await SupabaseService.client
            .from('follows')
            .delete()
            .match({'follower_id': userId, 'followee_id': authorId});
      } else {
        await SupabaseService.client
            .from('follows')
            .insert({'follower_id': userId, 'followee_id': authorId});
      }
    } catch (e, st) {
      AppLogger.error('toggleFollow failed — rolling back',
          name: 'engagement', error: e, stackTrace: st);
      _ref
          .read(followOverlayProvider.notifier)
          .update((s) => {...s, authorId: currentlyFollowing});
    }
  }
}

final engagementProvider = StateNotifierProvider<EngagementNotifier, void>(
    (ref) => EngagementNotifier(ref));
