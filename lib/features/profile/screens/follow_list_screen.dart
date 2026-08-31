import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../home/providers/home_provider.dart';
import '../models/profile_model.dart';
import '../providers/follow_list_provider.dart';

enum FollowListType { followers, following }

class FollowListScreen extends ConsumerWidget {
  final String userId;
  final FollowListType type;

  const FollowListScreen({super.key, required this.userId, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(
      type == FollowListType.followers
          ? followersListProvider(userId)
          : followingListProvider(userId),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          type == FollowListType.followers ? 'Followers' : 'Following',
          style: const TextStyle(fontSize: 17),
        ),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Text(
                type == FollowListType.followers
                    ? 'No followers yet.'
                    : 'Not following anyone yet.',
                style: theme.textTheme.bodySmall,
              ),
            );
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: theme.dividerTheme.color),
            itemBuilder: (context, i) => _UserRow(user: users[i]),
          );
        },
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  final ProfileModel user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMe = user.id == SupabaseService.currentUserId;
    final followOverlay = ref.watch(followOverlayProvider);
    final isFollowingAsync = ref.watch(isFollowingUserProvider(user.id));

    return ListTile(
      onTap: () => context.push('/user/${user.id}'),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primaryLight,
        backgroundImage:
            user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
        child: user.avatarUrl == null
            ? Text(user.fullName.isNotEmpty ? user.fullName[0] : '?',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold))
            : null,
      ),
      title: Text(user.fullName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(
        user.username.isNotEmpty
            ? '@${user.username}${user.departmentLevel.isNotEmpty ? " · ${user.departmentLevel}" : ""}'
            : user.departmentLevel,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: isMe
          ? null
          : isFollowingAsync.when(
              loading: () => const SizedBox(width: 70),
              error: (_, __) => const SizedBox.shrink(),
              data: (isFollowing) {
                final overlayValue = followOverlay[user.id] ?? isFollowing;
                return _FollowChip(
                  isFollowing: overlayValue,
                  onTap: () => ref
                      .read(engagementProvider.notifier)
                      .toggleFollow(user.id, overlayValue),
                );
              },
            ),
    );
  }
}

class _FollowChip extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onTap;
  const _FollowChip({required this.isFollowing, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isFollowing ? Colors.transparent : AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isFollowing ? AppColors.primary : Colors.transparent),
          ),
          child: Text(
            isFollowing ? 'Following' : 'Follow',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isFollowing ? AppColors.primary : Colors.white,
            ),
          ),
        ),
      );
}
