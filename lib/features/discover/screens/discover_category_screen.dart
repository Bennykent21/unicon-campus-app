import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/state_views.dart';
import '../../home/providers/home_provider.dart';
import '../../home/widgets/post_card.dart';
import '../discover_categories.dart';
import '../providers/discover_provider.dart';

class DiscoverCategoryScreen extends ConsumerWidget {
  /// [DiscoverCategory.key] from the route, e.g. `marketplace`.
  final String categoryKey;

  const DiscoverCategoryScreen({super.key, required this.categoryKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = DiscoverCategory.byKey(categoryKey);
    if (category == null || category.comingSoon) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.explore_outlined,
          message: category == null
              ? 'This category does not exist.'
              : '${category.label} is coming in a future update.',
          actionLabel: 'Back to Discover',
          onAction: () => context.go('/discover'),
        ),
      );
    }

    final params = (postType: category.postType, tag: category.tag);
    final postsAsync = ref.watch(discoverCategoryPostsProvider(params));
    final overlay = ref.watch(engagementOverlayProvider);
    final followOverlay = ref.watch(followOverlayProvider);
    final sort = ref.watch(discoverSortProvider);
    final theme = Theme.of(context);
    final colors = category.colors(context);
    final brand = context.palette.brandText;

    Widget sortItem(DiscoverSort value, IconData icon, String label) {
      final selected = sort == value;
      return Row(children: [
        Icon(icon, size: 18, color: selected ? brand : null),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                color: selected ? brand : null)),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(category.icon, color: colors.fg, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(category.label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium),
          ),
        ]),
        actions: [
          PopupMenuButton<DiscoverSort>(
            tooltip: 'Sort',
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: const Icon(Icons.sort, size: 22),
            onSelected: (s) =>
                ref.read(discoverSortProvider.notifier).state = s,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: DiscoverSort.newest,
                child:
                    sortItem(DiscoverSort.newest, Icons.access_time, 'Newest'),
              ),
              PopupMenuItem(
                value: DiscoverSort.mostHelpful,
                child: sortItem(DiscoverSort.mostHelpful,
                    Icons.thumb_up_outlined, 'Most helpful'),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(discoverCategoryPostsProvider(params)),
        child: postsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            error: e,
            action: 'load ${category.label.toLowerCase()}',
            onRetry: () =>
                ref.invalidate(discoverCategoryPostsProvider(params)),
          ),
          data: (posts) {
            if (posts.isEmpty) {
              // ListView so pull-to-refresh still works on an empty list.
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(
                    icon: category.icon,
                    message:
                        'No ${category.label.toLowerCase()} posts yet. Be the first to post one.',
                    actionLabel: 'Create a post',
                    onAction: () => context.push(category.postType != null
                        ? '/compose/${category.postType}'
                        : '/create'),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: posts.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: theme.dividerTheme.color),
              itemBuilder: (context, i) {
                final post = posts[i];
                final ov = overlay[post.id];
                final isMyPost = post.authorId == SupabaseService.currentUserId;
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
                  onHelpful: () =>
                      ref.read(engagementProvider.notifier).toggleHelpful(post),
                  onComment: () => context.push('/post/${post.id}'),
                  onSave: () =>
                      ref.read(engagementProvider.notifier).toggleSave(post),
                  onFollow: () => ref
                      .read(engagementProvider.notifier)
                      .toggleFollow(post.authorId, isFollowing),
                  onAvatarTap: () => context.push('/user/${post.authorId}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
