import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../home/providers/home_provider.dart';
import '../../home/widgets/post_card.dart';
import '../providers/discover_provider.dart';

class DiscoverCategoryScreen extends ConsumerWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? postType; // marketplace | job | event
  final String? tag; // for tag-based categories like Scholarships

  const DiscoverCategoryScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.postType,
    this.tag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (postType: postType, tag: tag);
    final postsAsync = ref.watch(discoverCategoryPostsProvider(params));
    final overlay = ref.watch(engagementOverlayProvider);
    final followOverlay = ref.watch(followOverlayProvider);
    final sort = ref.watch(discoverSortProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 17)),
        ]),
        actions: [
          PopupMenuButton<DiscoverSort>(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: const Icon(Icons.sort, size: 20),
            onSelected: (s) =>
                ref.read(discoverSortProvider.notifier).state = s,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: DiscoverSort.newest,
                child: Row(children: [
                  Icon(Icons.access_time,
                      size: 16,
                      color: sort == DiscoverSort.newest
                          ? AppColors.primary
                          : null),
                  const SizedBox(width: 8),
                  Text('Newest',
                      style: TextStyle(
                          fontWeight: sort == DiscoverSort.newest
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: sort == DiscoverSort.newest
                              ? AppColors.primary
                              : null)),
                ]),
              ),
              PopupMenuItem(
                value: DiscoverSort.mostHelpful,
                child: Row(children: [
                  Icon(Icons.thumb_up_outlined,
                      size: 16,
                      color: sort == DiscoverSort.mostHelpful
                          ? AppColors.primary
                          : null),
                  const SizedBox(width: 8),
                  Text('Most helpful',
                      style: TextStyle(
                          fontWeight: sort == DiscoverSort.mostHelpful
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: sort == DiscoverSort.mostHelpful
                              ? AppColors.primary
                              : null)),
                ]),
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
          error: (e, _) => Center(child: Text('Couldn\'t load: $e')),
          data: (posts) {
            if (posts.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 44, color: color.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('No $title posts yet.',
                          style: theme.textTheme.bodySmall),
                    ]),
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}
