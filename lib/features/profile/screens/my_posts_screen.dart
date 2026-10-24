import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/state_views.dart';
import '../../home/models/post_model.dart';
import '../../home/widgets/post_card.dart';
import '../../home/providers/home_provider.dart';
import '../providers/profile_provider.dart';

// Filter chips for the Posts tab
enum _PostFilter { all, questions, marketplace, jobs, events }

extension on _PostFilter {
  String get label => switch (this) {
        _PostFilter.all => 'All',
        _PostFilter.questions => 'Questions',
        _PostFilter.marketplace => 'Market',
        _PostFilter.jobs => 'Jobs',
        _PostFilter.events => 'Events',
      };

  String? get typeValue => switch (this) {
        _PostFilter.all => null,
        _PostFilter.questions => 'question',
        _PostFilter.marketplace => 'marketplace',
        _PostFilter.jobs => 'job',
        _PostFilter.events => 'event',
      };
}

class MyPostsScreen extends ConsumerStatefulWidget {
  /// 0 = Posts tab, 1 = Saved tab
  final int initialTab;
  const MyPostsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends ConsumerState<MyPostsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _PostFilter _activeFilter = _PostFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Activity', style: TextStyle(fontSize: 17)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelColor: AppColors.primary,
          unselectedLabelColor: theme.textTheme.bodySmall?.color,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: 'Posts'), Tab(text: 'Saved')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Posts tab with filter chips ──────────────────────────────
          Column(
            children: [
              // Filter chips
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: _PostFilter.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = _PostFilter.values[i];
                    final selected = f == _activeFilter;
                    return GestureDetector(
                      onTap: () => setState(() => _activeFilter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : theme.dividerTheme.color
                                  ?.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(f.label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : null)),
                      ),
                    );
                  },
                ),
              ),
              Divider(height: 1, color: theme.dividerTheme.color),
              Expanded(
                child: _FilteredPostsList(
                  typeFilter: _activeFilter.typeValue,
                ),
              ),
            ],
          ),

          // ── Saved tab ────────────────────────────────────────────────
          _SavedPostsList(),
        ],
      ),
    );
  }
}

// ── My posts, optionally filtered by type ─────────────────────────────────────

class _FilteredPostsList extends ConsumerWidget {
  final String? typeFilter;
  const _FilteredPostsList({this.typeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myPostsAsync = ref.watch(myPostsProvider);
    ref.watch(engagementOverlayProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myPostsProvider),
      child: myPostsAsync.when(
        loading: () => _shimmer(theme),
        error: (e, _) => ErrorState(error: e, action: 'load your posts'),
        data: (allPosts) {
          final posts = typeFilter == null
              ? allPosts
              : allPosts.where((p) => p.type == typeFilter).toList();

          if (posts.isEmpty) {
            return Center(
              child: Text(
                typeFilter == null
                    ? 'No posts yet.\nTap + to share something!'
                    : 'No ${typeFilter!} posts yet.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            );
          }
          return _postList(context, ref, posts, onDelete: (post) async {
            await SupabaseService.client
                .from('posts')
                .delete()
                .eq('id', post.id);
            ref.invalidate(myPostsProvider);
          });
        },
      ),
    );
  }
}

// ── Saved posts list ──────────────────────────────────────────────────────────

class _SavedPostsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(mySavedPostsProvider);
    ref.watch(engagementOverlayProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(mySavedPostsProvider),
      child: savedAsync.when(
        loading: () => _shimmer(theme),
        error: (e, _) => ErrorState(error: e, action: 'load your posts'),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Text(
                'No saved posts yet.\nBookmark posts to find them here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            );
          }
          return _postList(context, ref, posts, onSave: (post) async {
            await ref.read(engagementProvider.notifier).toggleSave(post);
            ref.invalidate(mySavedPostsProvider);
          });
        },
      ),
    );
  }
}

// ── Shared post list builder ──────────────────────────────────────────────────

Widget _postList(
  BuildContext context,
  WidgetRef ref,
  List<PostModel> posts, {
  Future<void> Function(PostModel)? onDelete,
  Future<void> Function(PostModel)? onSave,
}) {
  final overlay = ref.watch(engagementOverlayProvider);
  final followOverlay = ref.watch(followOverlayProvider);
  final theme = Theme.of(context);

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
        onSave: onSave != null
            ? () => onSave(post)
            : () => ref.read(engagementProvider.notifier).toggleSave(post),
        onDelete: onDelete != null ? () => onDelete(post) : null,
        onFollow: !isMyPost
            ? () => ref
                .read(engagementProvider.notifier)
                .toggleFollow(post.authorId, isFollowing)
            : null,
      );
    },
  );
}

// ── Shimmer loading ───────────────────────────────────────────────────────────

Widget _shimmer(ThemeData theme) {
  return ListView.separated(
    itemCount: 5,
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
  );
}
