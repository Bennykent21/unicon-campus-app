import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../home/models/post_model.dart';
import '../models/profile_model.dart';

// ── Current user's profile ────────────────────────────────────────────────────

final myProfileProvider =
    FutureProvider.autoDispose<ProfileModel?>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return null;
  final data = await SupabaseService.client
      .from('profiles_with_counts')
      .select()
      .eq('id', userId)
      .maybeSingle();
  if (data == null) return null;
  return ProfileModel.fromJson(data);
});

// ── Any user's profile (for viewing others) ───────────────────────────────────

final profileByIdProvider = FutureProvider.autoDispose
    .family<ProfileModel?, String>((ref, userId) async {
  final data = await SupabaseService.client
      .from('profiles_with_counts')
      .select()
      .eq('id', userId)
      .maybeSingle();
  if (data == null) return null;
  return ProfileModel.fromJson(data);
});

// ── My posts (for the "Posts" tab on My Posts screen) ─────────────────────────

final myPostsProvider =
    FutureProvider.autoDispose<List<PostModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];
  final data = await SupabaseService.client
      .from('posts_with_engagement')
      .select()
      .eq('author_id', userId)
      .order('created_at', ascending: false);
  return (data as List).map((e) => PostModel.fromJson(e)).toList();
});

// ── My saved posts (for the "Saved" tab) ───────────────────────────────────────

final mySavedPostsProvider =
    FutureProvider.autoDispose<List<PostModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];
  final savedRows = await SupabaseService.client
      .from('post_saves')
      .select('post_id')
      .eq('user_id', userId)
      .order('created_at', ascending: false);
  final ids = (savedRows as List).map((e) => e['post_id'] as String).toList();
  if (ids.isEmpty) return [];
  final data = await SupabaseService.client
      .from('posts_with_engagement')
      .select()
      .inFilter('id', ids);
  final posts = (data as List).map((e) => PostModel.fromJson(e)).toList();
  // Preserve the save order (most recently saved first)
  posts.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
  return posts;
});

// ── Profile update notifier ───────────────────────────────────────────────────

enum ProfileUpdateStatus { idle, loading, success, error }

class ProfileUpdateState {
  final ProfileUpdateStatus status;
  final String? errorMessage;
  const ProfileUpdateState(
      {this.status = ProfileUpdateStatus.idle, this.errorMessage});
}

class ProfileUpdateNotifier extends StateNotifier<ProfileUpdateState> {
  ProfileUpdateNotifier() : super(const ProfileUpdateState());

  Future<bool> save({
    required String fullName,
    required String username,
    String? department,
    String? level,
    String? university,
    String? bio,
    File? avatarFile,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    state = const ProfileUpdateState(status: ProfileUpdateStatus.loading);
    try {
      String? avatarUrl;
      if (avatarFile != null) {
        final ext = avatarFile.path.split('.').last.toLowerCase();
        final path = '$userId/avatar.$ext';
        await SupabaseService.client.storage
            .from(AppConstants.avatarsBucket)
            .upload(path, avatarFile,
                fileOptions: const FileOptions(upsert: true));
        avatarUrl = SupabaseService.client.storage
            .from(AppConstants.avatarsBucket)
            .getPublicUrl(path);
      }

      await SupabaseService.client.from('profiles').upsert({
        'id': userId,
        'full_name': fullName.trim(),
        'username': username.trim(),
        if (department != null) 'department': department.trim(),
        if (level != null) 'level': level.trim(),
        if (university != null) 'university': university.trim(),
        if (bio != null) 'bio': bio.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      });

      // Profile data changed — let the router re-check completeness once.
      invalidateProfileCompleteCache();

      state = const ProfileUpdateState(status: ProfileUpdateStatus.success);
      return true;
    } catch (e) {
      state = ProfileUpdateState(
          status: ProfileUpdateStatus.error, errorMessage: e.toString());
      return false;
    }
  }

  void reset() => state = const ProfileUpdateState();
}

final profileUpdateProvider = StateNotifierProvider.autoDispose<
    ProfileUpdateNotifier,
    ProfileUpdateState>((ref) => ProfileUpdateNotifier());
