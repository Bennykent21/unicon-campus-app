import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/utils/share_links.dart';
import '../models/profile_model.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 400,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    final ok = await ref.read(profileUpdateProvider.notifier).save(
          fullName: ref.read(myProfileProvider).valueOrNull?.fullName ?? '',
          username: ref.read(myProfileProvider).valueOrNull?.username ?? '',
          department: ref.read(myProfileProvider).valueOrNull?.department,
          level: ref.read(myProfileProvider).valueOrNull?.level,
          university: ref.read(myProfileProvider).valueOrNull?.university,
          bio: ref.read(myProfileProvider).valueOrNull?.bio,
          avatarFile: File(picked.path),
        );
    if (mounted) {
      setState(() => _uploadingAvatar = false);
      if (ok) {
        ref.invalidate(myProfileProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to update photo. Try again.'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(error: e, action: 'load your profile'),
        data: (profile) {
          if (profile == null) {
            return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Profile not found'),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/profile-setup'),
                child: const Text('Set up profile'),
              ),
            ]));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myProfileProvider),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    profile: profile,
                    uploadingAvatar: _uploadingAvatar,
                    onPickAvatar: _pickAndUploadAvatar,
                    onEditProfile: () => context.push('/profile-edit'),
                    onShareProfile: () => ShareLinks.copy(
                        context, ShareLinks.user(profile.id),
                        message: 'Profile link copied'),
                    themeMode: themeMode,
                    onToggleTheme: () => ref
                        .read(themeModeProvider.notifier)
                        .setMode(themeMode == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark),
                  ),
                ),
                SliverToBoxAdapter(
                    child: Divider(height: 1, color: theme.dividerTheme.color)),
                SliverToBoxAdapter(
                  child: Column(children: [
                    _ActivityRow(
                      icon: Icons.article_outlined,
                      label: 'My Posts',
                      subtitle: '${profile.postCount} posts',
                      onTap: () => context.push('/my-posts'),
                    ),
                    Divider(height: 1, color: theme.dividerTheme.color),
                    _ActivityRow(
                      icon: Icons.bookmark_border,
                      label: 'Saved Posts',
                      onTap: () => context.push('/my-posts?tab=1'),
                    ),
                    Divider(height: 1, color: theme.dividerTheme.color),
                    _ActivityRow(
                      icon: Icons.people_outline,
                      label: 'Followers',
                      subtitle: '${profile.followerCount}',
                      onTap: () => context.push('/followers/${profile.id}'),
                    ),
                    Divider(height: 1, color: theme.dividerTheme.color),
                    _ActivityRow(
                      icon: Icons.person_add_outlined,
                      label: 'Following',
                      subtitle: '${profile.followingCount}',
                      onTap: () => context.push('/following/${profile.id}'),
                    ),
                    Divider(height: 1, color: theme.dividerTheme.color),
                  ]),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text('Settings',
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.8,
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.5))),
                      ),
                      Divider(height: 1, color: theme.dividerTheme.color),
                      ListTile(
                        leading: Icon(
                            themeMode == ThemeMode.dark
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            size: 20),
                        title: const Text('Dark Mode',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Switch.adaptive(
                          value: themeMode == ThemeMode.dark,
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.primary,
                          onChanged: (_) => ref
                              .read(themeModeProvider.notifier)
                              .setMode(themeMode == ThemeMode.dark
                                  ? ThemeMode.light
                                  : ThemeMode.dark),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      Divider(height: 1, color: theme.dividerTheme.color),
                      ListTile(
                        leading: const Icon(Icons.logout,
                            size: 20, color: Colors.red),
                        title: const Text('Sign Out',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.red)),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Sign out?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Sign out',
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            // Clear cached profile-completeness so the next
                            // account signing in gets a fresh check.
                            invalidateProfileCompleteCache();
                            await SupabaseService.client.auth.signOut();
                          }
                        },
                      ),
                      Divider(height: 1, color: theme.dividerTheme.color),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final ProfileModel profile;
  final bool uploadingAvatar;
  final VoidCallback onPickAvatar;
  final VoidCallback onEditProfile;
  final VoidCallback onShareProfile;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const _ProfileHeader({
    required this.profile,
    required this.uploadingAvatar,
    required this.onPickAvatar,
    required this.onEditProfile,
    required this.onShareProfile,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Gradient
            Container(
              height: 130,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4F35CC),
                    Color(0xFF7C3AED),
                    Color(0xFF2D1B69)
                  ],
                ),
              ),
            ),

            // Three-dot — Edit + Share
            Positioned(
              top: 52,
              right: 8,
              child: PopupMenuButton<String>(
                icon:
                    const Icon(Icons.more_horiz, color: Colors.white, size: 22),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child:
                          _MenuItem(Icons.edit_outlined, 'Edit Profile', null)),
                  const PopupMenuItem(
                      value: 'share',
                      child: _MenuItem(
                          Icons.ios_share_outlined, 'Share Profile', null)),
                ],
                onSelected: (v) {
                  if (v == 'edit') onEditProfile();
                  if (v == 'share') onShareProfile();
                },
              ),
            ),

            // Avatar
            Positioned(
              bottom: -44,
              left: 20,
              child: GestureDetector(
                onTap: onPickAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Spinner overlay while uploading
                    if (uploadingAvatar)
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                            color: Colors.black45, shape: BoxShape.circle),
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        ),
                      )
                    else
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: context.palette.brandSoft,
                        backgroundImage: profile.avatarUrl != null
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null
                            ? Text(
                                profile.fullName.isNotEmpty
                                    ? profile.fullName[0]
                                    : '?',
                                style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: context.palette.brandText))
                            : null,
                      ),
                    // Camera badge
                    if (!uploadingAvatar)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 54),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.fullName,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              if (profile.username.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('@${profile.username}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
              ],
              const SizedBox(height: 8),
              if (profile.departmentLevel.isNotEmpty) ...[
                Row(children: [
                  Icon(Icons.school_outlined,
                      size: 13, color: context.palette.brandText),
                  const SizedBox(width: 5),
                  Text(profile.departmentLevel,
                      style: TextStyle(
                          fontSize: 13,
                          color: context.palette.brandText,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
              ],
              if (profile.university != null) ...[
                Row(children: [
                  Icon(Icons.location_city_outlined,
                      size: 13, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 5),
                  Text(profile.university!,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
                ]),
                const SizedBox(height: 4),
              ],
              if (profile.joinedDate.isNotEmpty) ...[
                Row(children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 5),
                  Text(profile.joinedDate,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
                ]),
                const SizedBox(height: 8),
              ],
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                Text(profile.bio!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontSize: 14, height: 1.5)),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _Stat(value: '${profile.postCount}', label: 'Posts'),
                _StatDivider(),
                _Stat(value: '${profile.followerCount}', label: 'Followers'),
                _StatDivider(),
                _Stat(value: '${profile.followingCount}', label: 'Following'),
                _StatDivider(),
                _Stat(
                  value: profile.reputation >= 1000
                      ? '${(profile.reputation / 1000).toStringAsFixed(1)}k'
                      : '${profile.reputation}',
                  label: 'Reputation',
                  valueColor: AppColors.primary,
                ),
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  const _Stat({required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 18, color: valueColor)),
        const SizedBox(height: 2),
        Text(label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
      ]);
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 30,
        color: Theme.of(context).dividerTheme.color?.withValues(alpha: 0.6),
      );
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  const _ActivityRow(
      {required this.icon, required this.label, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Icon(icon, size: 20),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 12))
            : null,
        trailing: const Icon(Icons.chevron_right, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuItem(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 14)),
      ]);
}
