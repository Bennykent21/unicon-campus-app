import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/state_views.dart';
import '../../home/providers/home_provider.dart';
import '../../home/models/post_model.dart';
import '../../home/widgets/post_card.dart';
import '../providers/profile_provider.dart';
import '../providers/follow_list_provider.dart';

/// Posts by a specific user — used on their profile page.
final _userPostsProvider =
    FutureProvider.autoDispose.family<List<PostModel>, String>((ref, userId) async {
  final data = await SupabaseService.client
      .from('posts_with_engagement')
      .select()
      .eq('author_id', userId)
      .order('created_at', ascending: false);
  return (data as List).map((e) => PostModel.fromJson(e)).toList();
});

class UserProfileScreen extends ConsumerWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId == SupabaseService.currentUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/profile');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileAsync     = ref.watch(profileByIdProvider(userId));
    final postsAsync       = ref.watch(_userPostsProvider(userId));
    final isFollowingAsync = ref.watch(isFollowingUserProvider(userId));
    final followOverlay    = ref.watch(followOverlayProvider);
    final overlay          = ref.watch(engagementOverlayProvider);
    final theme            = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile', style: TextStyle(fontSize: 17))),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => ErrorState(error: e, action: 'load this profile'),
        data:    (profile) {
          if (profile == null) return const Center(child: Text('User not found'));

          final isFollowing = followOverlay.containsKey(userId)
              ? followOverlay[userId]!
              : (isFollowingAsync.valueOrNull ?? false);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(profileByIdProvider(userId));
              ref.invalidate(_userPostsProvider(userId));
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 110,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF4F35CC), Color(0xFF7C3AED), Color(0xFF2D1B69)],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -40, left: 20,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: context.palette.brandSoft,
                              backgroundImage: profile.avatarUrl != null
                                  ? NetworkImage(profile.avatarUrl!) : null,
                              child: profile.avatarUrl == null
                                  ? Text(profile.fullName.isNotEmpty ? profile.fullName[0] : '?',
                                      style: TextStyle(fontSize: 28,
                                          fontWeight: FontWeight.bold, color: context.palette.brandText))
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 50),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.fullName,
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                            if (profile.username.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text('@${profile.username}',
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
                            ],
                            const SizedBox(height: 8),
                            if (profile.departmentLevel.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(children: [
                                  Icon(Icons.school_outlined, size: 13, color: context.palette.brandText),
                                  const SizedBox(width: 5),
                                  Text(profile.departmentLevel,
                                      style: TextStyle(fontSize: 13, color: context.palette.brandText,
                                          fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            if (profile.university != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(children: [
                                  Icon(Icons.location_city_outlined, size: 13,
                                      color: theme.textTheme.bodySmall?.color),
                                  const SizedBox(width: 5),
                                  Text(profile.university!,
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
                                ]),
                              ),
                            if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(profile.bio!,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.5)),
                            ],
                            const SizedBox(height: 14),

                            Row(children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => ref.read(engagementProvider.notifier)
                                      .toggleFollow(userId, isFollowing),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isFollowing ? Colors.transparent : AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: isFollowing ? AppColors.primary : Colors.transparent),
                                    ),
                                    child: Text(
                                      isFollowing ? 'Following' : 'Follow',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: isFollowing ? context.palette.brandText : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _startChat(context, ref, userId),
                                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                  label: const Text('Message',
                                      style: TextStyle(fontWeight: FontWeight.w700)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    side: const BorderSide(color: AppColors.primary),
                                    foregroundColor: AppColors.primary,
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 16),

                            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                              _Stat(value: '${profile.postCount}', label: 'Posts'),
                              _Stat(
                                value: '${profile.followerCount}',
                                label: 'Followers',
                                onTap: () => context.push('/followers/$userId'),
                              ),
                              _Stat(
                                value: '${profile.followingCount}',
                                label: 'Following',
                                onTap: () => context.push('/following/$userId'),
                              ),
                              _Stat(
                                value: profile.reputation >= 1000
                                    ? '${(profile.reputation / 1000).toStringAsFixed(1)}k'
                                    : '${profile.reputation}',
                                label: 'Reputation',
                                valueColor: AppColors.primary,
                              ),
                            ]),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: theme.dividerTheme.color),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Text('Posts',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),

                postsAsync.when(
                  loading: () => const SliverToBoxAdapter(
                      child: Padding(padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()))),
                  error: (e, _) => SliverToBoxAdapter(
                      child: ErrorState(error: e, action: 'load posts')),
                  data: (posts) {
                    if (posts.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                              child: Text('No posts yet.', style: theme.textTheme.bodySmall)),
                        ),
                      );
                    }
                    return SliverList.separated(
                      itemCount: posts.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: theme.dividerTheme.color),
                      itemBuilder: (context, i) {
                        final post = posts[i];
                        final ov   = overlay[post.id];
                        return PostCard(
                          post: post,
                          isMyPost: false,
                          isFollowingAuthor: isFollowing,
                          isHelpfulByMe: ov?.isHelpfulByMe,
                          helpfulCount:  ov?.helpfulCount,
                          isSavedByMe:   ov?.isSavedByMe,
                          onTap:     () => context.push('/post/${post.id}'),
                          onHelpful: () => ref.read(engagementProvider.notifier).toggleHelpful(post),
                          onComment: () => context.push('/post/${post.id}'),
                          onSave:    () => ref.read(engagementProvider.notifier).toggleSave(post),
                          onFollow:  () => ref.read(engagementProvider.notifier)
                              .toggleFollow(userId, isFollowing),
                        );
                      },
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _startChat(BuildContext context, WidgetRef ref, String otherUserId) async {
    final myId = SupabaseService.currentUserId;
    if (myId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final myConvos = await SupabaseService.client
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', myId);
      final myConvoIds =
          (myConvos as List).map((e) => e['conversation_id'] as String).toList();

      String? existingId;
      if (myConvoIds.isNotEmpty) {
        final theirConvos = await SupabaseService.client
            .from('conversation_participants')
            .select('conversation_id')
            .eq('user_id', otherUserId)
            .inFilter('conversation_id', myConvoIds);
        if ((theirConvos as List).isNotEmpty) {
          for (final row in theirConvos) {
            final convoId = row['conversation_id'] as String;
            final convo = await SupabaseService.client
                .from('conversations')
                .select('kind')
                .eq('id', convoId)
                .maybeSingle();
            if (convo != null && convo['kind'] == 'dm') {
              existingId = convoId;
              break;
            }
          }
        }
      }

      String conversationId;
      if (existingId != null) {
        conversationId = existingId;
      } else {
        // Generate the ID client-side — avoids chaining .select() after
        // insert, which would require Postgres to pass the SELECT policy
        // on a row that has no participants yet, causing a false RLS error.
        conversationId = const Uuid().v4();
        await SupabaseService.client.from('conversations').insert({
          'id': conversationId,
          'kind': 'dm',
        });
        await SupabaseService.client.from('conversation_participants')
            .insert({'conversation_id': conversationId, 'user_id': myId});
        await SupabaseService.client.from('conversation_participants')
            .insert({'conversation_id': conversationId, 'user_id': otherUserId});
      }

      if (context.mounted) {
        Navigator.pop(context); // close loading dialog
        context.push('/chat/$conversationId');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start chat: $e')),
        );
      }
    }
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final VoidCallback? onTap;
  const _Stat({required this.value, required this.label, this.valueColor, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: valueColor)),
      const SizedBox(height: 2),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
    ]),
  );
}