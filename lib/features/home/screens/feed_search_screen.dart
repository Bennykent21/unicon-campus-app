import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/home_provider.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';

final _searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final _searchResultsProvider =
    FutureProvider.autoDispose<List<PostModel>>((ref) async {
  final query = ref.watch(_searchQueryProvider).trim();
  if (query.isEmpty) return [];
  final data = await SupabaseService.client
      .from('posts_with_engagement')
      .select()
      .or('title.ilike.%$query%,body.ilike.%$query%')
      .order('created_at', ascending: false)
      .limit(30);
  return (data as List).map((e) => PostModel.fromJson(e)).toList();
});

class FeedSearchScreen extends ConsumerStatefulWidget {
  const FeedSearchScreen({super.key});

  @override
  ConsumerState<FeedSearchScreen> createState() => _FeedSearchScreenState();
}

class _FeedSearchScreenState extends ConsumerState<FeedSearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setQuery(String q) {
    _ctrl.text = q;
    _ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: q.length));
    ref.read(_searchQueryProvider.notifier).state = q;
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_searchQueryProvider);
    final results = ref.watch(_searchResultsProvider);
    final overlay = ref.watch(engagementOverlayProvider);
    final followOverlay = ref.watch(followOverlayProvider);
    final trending = ref.watch(trendingTopicsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          decoration: InputDecoration(
            hintText: 'Search posts, questions, topics...',
            border: InputBorder.none,
            filled: false,
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.textTheme.bodySmall?.color),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _ctrl.clear();
                      ref.read(_searchQueryProvider.notifier).state = '';
                    },
                  )
                : null,
          ),
          onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
          textInputAction: TextInputAction.search,
        ),
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerTheme.color),
        ),
      ),
      body: query.isEmpty
          // ── Empty state: Twitter Explore-style trending ───────────────
          ? trending.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _buildEmptyPrompt(theme),
              data: (tags) => tags.isEmpty
                  ? _buildEmptyPrompt(theme)
                  : _TrendingExplore(
                      tags: tags,
                      onTagTap: (tag) => _setQuery(tag),
                    ),
            )
          // ── Search results ────────────────────────────────────────────
          : results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (posts) {
                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 44,
                            color: AppColors.primary.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text('No results for "$query"',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: posts.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: theme.dividerTheme.color),
                  itemBuilder: (context, i) {
                    final post = posts[i];
                    final ov = overlay[post.id];
                    final isMyPost =
                        post.authorId == SupabaseService.currentUserId;
                    final isFollowing = followOverlay.containsKey(post.authorId)
                        ? followOverlay[post.authorId]!
                        : post.isFollowingAuthor;
                    return PostCard(
                      post: post,
                      isMyPost: isMyPost,
                      isFollowingAuthor: isFollowing,
                      isHelpfulByMe: ov?.isHelpfulByMe,
                      helpfulCount: ov?.helpfulCount,
                      isSavedByMe: ov?.isSavedByMe,
                      onTap: () => context.push('/post/${post.id}'),
                      onHelpful: () => ref
                          .read(engagementProvider.notifier)
                          .toggleHelpful(post),
                      onComment: () => context.push('/post/${post.id}'),
                      onSave: () => ref
                          .read(engagementProvider.notifier)
                          .toggleSave(post),
                      onFollow: () => ref
                          .read(engagementProvider.notifier)
                          .toggleFollow(post.authorId, isFollowing),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyPrompt(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search,
              size: 44, color: AppColors.primary.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Text('Search for posts, questions,\nmarketplace listings and more',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ── Trending explore panel (shown when search is empty) ───────────────────────

class _TrendingExplore extends StatelessWidget {
  final List<String> tags;
  final void Function(String tag) onTagTap;

  const _TrendingExplore({required this.tags, required this.onTagTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Split tags: top 3 get featured rows, rest get a chip grid
    final featured = tags.take(3).toList();
    final rest = tags.skip(3).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text('Trending on campus',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800, fontSize: 15)),
        ),

        // Featured trending rows (large, with rank)
        ...featured.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final tag = entry.value;
          return InkWell(
            onTap: () => onTagTap(tag),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Text('$rank',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.25))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#$tag',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.primary)),
                      const SizedBox(height: 2),
                      Text('Trending in your university',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 12,
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.4)),
              ]),
            ),
          );
        }),

        if (rest.isNotEmpty) ...[
          Divider(height: 1, color: theme.dividerTheme.color),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text('More trending topics',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rest
                  .map((tag) => GestureDetector(
                        onTap: () => onTagTap(tag),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('#$tag',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}
