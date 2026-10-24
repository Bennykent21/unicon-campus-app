import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/state_views.dart';
import '../providers/home_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../../internships/providers/internship_providers.dart';
import '../../internships/widgets/opportunities_banner.dart';

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
    final palette = context.palette;
    final chipFill = palette.neutral.bg;

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
          ref.invalidate(internshipsProvider);
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
                titleSpacing: 16,
                title: Semantics(
                  header: true,
                  label: 'UNICON home',
                  excludeSemantics: true,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/images/unicon_mark.png',
                        width: 30, height: 30),
                    const SizedBox(width: 10),
                    Text('UNICON',
                        style: theme.appBarTheme.titleTextStyle?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8)),
                  ]),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.search, size: 22),
                    onPressed: () => context.push('/feed-search'),
                  ),
                  IconButton(
                    tooltip: unreadCount > 0
                        ? 'Notifications, $unreadCount unread'
                        : 'Notifications',
                    onPressed: () => context.push('/notifications'),
                    icon: Badge(
                      isLabelVisible: unreadCount > 0,
                      backgroundColor: AppColors.badge,
                      label: Text(unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.w800)),
                      child: const Icon(Icons.notifications_none, size: 22),
                    ),
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
                        color:
                            theme.dividerTheme.color?.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: FeedTab.values.map((tab) {
                          final selected = tab == activeTab;
                          return Expanded(
                            child: Semantics(
                              button: true,
                              selected: selected,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => ref
                                    .read(feedTabProvider.notifier)
                                    .state = tab,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  constraints:
                                      const BoxConstraints(minHeight: 38),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 9),
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
                                      fontSize: 13.5,
                                    ),
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
                      height: 52,
                      child: Row(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
                              scrollDirection: Axis.horizontal,
                              itemCount: quickFilters.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (context, i) {
                                final f = quickFilters[i];
                                final isActive = f == 'All'
                                    ? activeFilters.isEmpty
                                    : activeFilters.contains(f);
                                return Semantics(
                                  button: true,
                                  selected: isActive,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (f == 'All') {
                                        ref
                                            .read(feedFiltersProvider.notifier)
                                            .state = {};
                                      } else {
                                        final cur =
                                            Set<String>.from(activeFilters);
                                        isActive ? cur.remove(f) : cur.add(f);
                                        ref
                                            .read(feedFiltersProvider.notifier)
                                            .state = cur;
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? AppColors.primary
                                            : chipFill,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(f,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isActive
                                                  ? Colors.white
                                                  : null)),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                right: 12, top: 8, bottom: 6),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => showFilterSheet(context, ref),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: hasActiveFilters
                                      ? AppColors.primary
                                      : chipFill,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.tune,
                                          size: 15,
                                          color: hasActiveFilters
                                              ? Colors.white
                                              : null),
                                      const SizedBox(width: 4),
                                      Text(
                                        hasActiveFilters
                                            ? 'Filter (${activeFilters.length})'
                                            : 'Filter',
                                        style: TextStyle(
                                            fontSize: 13,
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

                    if (activeTab == FeedTab.forYou && !hasActiveFilters)
                      const OpportunitiesBanner(),

                    // Thin divider before feed starts
                    Divider(height: 1, color: theme.dividerTheme.color),
                  ],
                ),
              ),

              // ── Posts ────────────────────────────────────────────────────
              Builder(
                builder: (context) {
                  if (feedState.isInitialLoading) {
                    return _buildFeedShimmer(theme, palette);
                  }
                  if (feedState.error != null && feedState.posts.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorState(
                        error: feedState.error!,
                        action: 'load the feed',
                        onRetry: () =>
                            ref.read(feedPostsProvider.notifier).refresh(),
                      ),
                    );
                  }
                  final posts = feedState.posts;
                  if (posts.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: switch (activeTab) {
                        FeedTab.following => EmptyState(
                            icon: Icons.people_outline,
                            message:
                                'Posts from people you follow show up here.',
                            actionLabel: 'Find people in For You',
                            onAction: () => ref
                                .read(feedTabProvider.notifier)
                                .state = FeedTab.forYou,
                          ),
                        FeedTab.forYou => hasActiveFilters
                            ? EmptyState(
                                icon: Icons.filter_alt_off_outlined,
                                message: 'No posts match these filters.',
                                actionLabel: 'Clear filters',
                                onAction: () => ref
                                    .read(feedFiltersProvider.notifier)
                                    .state = {},
                              )
                            : EmptyState(
                                icon: Icons.forum_outlined,
                                message:
                                    'Nothing here yet. Share a question, an item or an event.',
                                actionLabel: 'Create a post',
                                onAction: () => context.push('/create'),
                              ),
                      },
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
                      final isFollowing =
                          followOverlay.containsKey(post.authorId)
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
                          try {
                            await SupabaseService.client
                                .from('posts')
                                .delete()
                                .eq('id', post.id);
                          } catch (e, st) {
                            if (context.mounted) {
                              showErrorSnack(context, e,
                                  action: 'delete this post', stackTrace: st);
                            }
                            return;
                          }
                          ref.invalidate(feedPostsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Post deleted')));
                          }
                        },
                        onFollow: () => ref
                            .read(engagementProvider.notifier)
                            .toggleFollow(post.authorId, isFollowing),
                        onAvatarTap: () =>
                            context.push('/user/${post.authorId}'),
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

  Widget _buildFeedShimmer(ThemeData theme, AppPalette palette) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 8),
      sliver: SliverList.separated(
        itemCount: 6,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: theme.dividerTheme.color),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: palette.shimmerBase,
          highlightColor: palette.shimmerHighlight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const CircleAvatar(radius: 18, backgroundColor: Colors.white),
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
