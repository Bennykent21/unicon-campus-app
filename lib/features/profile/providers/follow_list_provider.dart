import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_service.dart';
import '../models/profile_model.dart';

/// Fetches the list of users who follow [userId].
final followersListProvider = FutureProvider.autoDispose
    .family<List<ProfileModel>, String>((ref, userId) async {
  final rows = await SupabaseService.client
      .from('follows')
      .select('follower_id')
      .eq('followee_id', userId);

  final ids = (rows as List).map((r) => r['follower_id'] as String).toList();
  if (ids.isEmpty) return [];

  final data = await SupabaseService.client
      .from('profiles_with_counts')
      .select()
      .inFilter('id', ids);

  return (data as List).map((e) => ProfileModel.fromJson(e)).toList();
});

/// Fetches the list of users that [userId] follows.
final followingListProvider = FutureProvider.autoDispose
    .family<List<ProfileModel>, String>((ref, userId) async {
  final rows = await SupabaseService.client
      .from('follows')
      .select('followee_id')
      .eq('follower_id', userId);

  final ids = (rows as List).map((r) => r['followee_id'] as String).toList();
  if (ids.isEmpty) return [];

  final data = await SupabaseService.client
      .from('profiles_with_counts')
      .select()
      .inFilter('id', ids);

  return (data as List).map((e) => ProfileModel.fromJson(e)).toList();
});

/// Whether the current user follows [userId] — used to show Follow/Following
/// buttons in the list rows.
final isFollowingUserProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, userId) async {
  final myId = SupabaseService.currentUserId;
  if (myId == null || myId == userId) return false;
  final row = await SupabaseService.client
      .from('follows')
      .select()
      .match({'follower_id': myId, 'followee_id': userId}).maybeSingle();
  return row != null;
});
