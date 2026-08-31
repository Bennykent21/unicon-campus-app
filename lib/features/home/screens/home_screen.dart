import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_service.dart';
import '../providers/home_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/filter_bottom_sheet.dart';

final _userDeptLevelProvider =
    FutureProvider.autoDispose<({String? dept, String? level})>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return (dept: null, level: null);
  final data = await SupabaseService.client
      .from('profiles')
      .select('department, level')
      .eq('id', userId)
      .maybeSingle();
  return (
    dept: data?['department'] as String?,
    level: data?['level'] as String?
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(feedTabProvider);
    final activeFilters = ref.watch(feedFiltersProvider);
    final feedState = ref.watch(feedPostsProvider);
    final overlay = ref.watch(engagementOverlayProvider);
    final followOverlay = ref.watch(followOverlayProvider);
    final userInfo = ref.watch(_userDeptLevelProvider);
    final unreadAsync = ref.watch(unreadNotificationsProvider);
    final theme = Theme.of(context);

    final quickFilters = <String>['All'];
    userInfo.whenData((u) {
      if (u.dept != null) quickFilters.add(u.dept!);
      if (u.level != null) quickFilters.add(u.level!);
    });

    final hasActiveFilters = activeFilters.isNotEmpty;
    final unreadCount = unreadAsync.valueOrNull ?? 0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(unreadNotificationsProvider);
          ref.read(engagementOverlayProvider.notifier).state = {};
          ref.read(followOverlayProvider.notifier).state = {};
          await ref.read(feedPostsProvider.notifier).refresh();
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Trigger the next page when the user scrolls within ~600px of
            // the bottom. loadMore() no-ops while loading / when exhausted.
            if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 600) {
              ref.read(feedPostsProvider.notifier).loadMore();
            }
            return false;
          },
          child: CustomScrollView(
          slivers: [
            // ── App bar ─────────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              elevation: 0,
              backgroundColor: theme.scaffoldBackgroundColor,
              title: Text('Home',
                  style:
                      theme.appBarTheme.titleTextStyle?.copyWith(fontSize: 20)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, size: 22),
                  onPressed: () => context.push('/feed-search'),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none, size: 22),
                      onPressed: () => context.push('/notifications'),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: AppColors.event, shape: BoxShape.circle),
                          constraints:
                              const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            ),

            // ── Tabs + filters ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Tab row
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: theme.dividerTheme.color?.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: FeedTab.values.map((tab) {
                        final selected = tab == activeTab;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                ref.read(feedTabProvider.notifier).state = tab,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                switch (tab) {
                                  FeedTab.forYou => 'For You',
                                  FeedTab.following => 'Following',
                                },
                                style: TextStyle(
                                  color: selected ? Colors.white : null,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Smart filter chips + filter button
                  SizedBox(
                    height: 42,
                    child: Row(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                            scrollDirection: Axis.horizontal,
                            itemCount: quickFilters.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, i) {
                              final f = quickFilters[i];
                              final isActive = f == 'All'
                                  ? activeFilters.isEmpty
                                  : activeFilters.contains(f);
                              return GestureDetector(
                                onTap: () {
                                  if (f == 'All') {
                                    ref
                                        .read(feedFiltersProvider.notifier)
                                        .state = {};
                                  } else {
                                    final cur = Set<String>.from(activeFilters);
                                    isActive ? cur.remove(f) : cur.add(f);
                                    ref
                                        .read(feedFiltersProvider.notifier)
                                        .state = cur;
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppColors.primary
                                        : theme.dividerTheme.color
                                            ?.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(f,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isActive ? Colors.white : null)),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              right: 12, top: 6, bottom: 4),
                          child: GestureDetector(
                            onTap: () => showFilterSheet(context, ref),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: hasActiveFilters
                                    ? AppColors.primary
                                    : theme.dividerTheme.color
                                        ?.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.tune,
                                        size: 13,
                                        color: hasActiveFilters
                                            ? Colors.white
                                            : null),
                                    const SizedBox(width: 4),
                                    Text(
                                      hasActiveFilters
                                          ? 'Filter (${activeFilters.length})'
                                          : 'Filter',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: hasActiveFilters
                                              ? Colors.white
                                              : null),
                                    ),
                                  ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Thin divider before feed starts
                  Divider(height: 1, color: theme.dividerTheme.color),
                ],
              ),
            ),

            // ── Posts ────────────────────────────────────────────────────
            Builder(
              builder: (context) {
                if (feedState.isInitialLoading) {
                  return _buildFeedShimmer(theme);
                }
                if (feedState.error != null && feedState.posts.isEmpty) {
                  return SliverFillRemaining(
                      child: Center(
                          child:
                              Text('Couldn\'t load feed: ${feedState.error}')));
                }
                final posts = feedState.posts;
                if (posts.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 40,
                              color: theme.textTheme.bodySmall?.color),
                          const SizedBox(height: 8),
                          Text(
                            switch (activeTab) {
                              FeedTab.following =>
                                'Follow people to see their posts here.',
                              FeedTab.forYou => hasActiveFilters
                                  ? 'No posts matching your filters.'
                                  : 'No posts yet — tap + to share something!',
                            },
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                          if (hasActiveFilters) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => ref
                                  .read(feedFiltersProvider.notifier)
                                  .state = {},
                              child: const Text('Clear filters',
                                  style: TextStyle(color: AppColors.primary)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                // Divider-based feed — no cards, just content + thin dividers
                return SliverList.separated(
                  itemCount: posts.length + (feedState.isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: theme.dividerTheme.color),
                  itemBuilder: (context, i) {
                    // Bottom "loading more" spinner row.
                    if (i == posts.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
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
                      onDelete: () async {
                        await SupabaseService.client
                            .from('posts')
                            .delete()
                            .eq('id', post.id);
                        ref.invalidate(feedPostsProvider);
                      },
                      onFollow: () => ref
                          .read(engagementProvider.notifier)
                          .toggleFollow(post.authorId, isFollowing),
                      onAvatarTap: () => context.push('/user/${post.authorId}'),
                    );
                  },
                );
              },
            ),

            // Bottom padding for FAB
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedShimmer(ThemeData theme) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 8),
      sliver: SliverList.separated(
        itemCount: 6,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: theme.dividerTheme.color),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: theme.dividerTheme.color ?? Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const CircleAvatar(
                      radius: 18, backgroundColor: Colors.white),
                  const SizedBox(width: 10),
                  Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4))),
                ]),
                const SizedBox(height: 10),
                Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(
                    width: 200,
                    height: 12,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
