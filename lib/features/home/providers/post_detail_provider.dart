import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_service.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';

// ─── Single post ───────────────────────────────────────────────────────────────

final postDetailProvider =
    FutureProvider.autoDispose.family<PostModel?, String>((ref, postId) async {
  final data = await SupabaseService.client
      .from('posts_with_engagement')
      .select()
      .eq('id', postId)
      .maybeSingle();
  if (data == null) return null;
  return PostModel.fromJson(data);
});

// ─── Comments (TRUE realtime — streams the real table, not the view) ───────────
//
// This used to stream `comments_with_author`, which is a VIEW. Supabase
// Realtime only fires postgres_changes events for physical tables — it
// silently never fired for the view, so a new comment from someone else
// never appeared without a manual screen revisit. Same root cause as the
// earlier chat message bug. Fixed the same way: stream the real `comments`
// table, then hydrate author info for just the changed rows via the view.

final commentsProvider = StreamProvider.autoDispose
    .family<List<CommentModel>, String>((ref, postId) {
  return SupabaseService.client
      .from('comments')
      .stream(primaryKey: ['id'])
      .eq('post_id', postId)
      .order('created_at')
      .asyncMap((rows) async {
        if (rows.isEmpty) return <CommentModel>[];
        final ids = rows.map((r) => r['id'] as String).toList();
        final hydrated = await SupabaseService.client
            .from('comments_with_author')
            .select()
            .inFilter('id', ids)
            .order('created_at');
        return (hydrated as List).map((e) => CommentModel.fromJson(e)).toList();
      });
});

// ─── Submit comment ────────────────────────────────────────────────────────────

class CommentNotifier extends StateNotifier<AsyncValue<void>> {
  CommentNotifier() : super(const AsyncData(null));

  Future<void> submit({required String postId, required String body}) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null || body.trim().isEmpty) return;
    state = const AsyncLoading();
    try {
      await SupabaseService.client.from('comments').insert({
        'post_id': postId,
        'author_id': userId,
        'body': body.trim(),
      });
      await SupabaseService.client.rpc('award_reputation', params: {
        'target_post_id': postId,
        'action': 'comment',
      });
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Toggles the accepted state of a comment.
  /// - If it's already accepted, tapping again UNMARKS it (sets false).
  /// - If it's not accepted, marks it accepted and unmarks any other
  ///   previously accepted comment on the same post (only one at a time).
  Future<void> toggleAccepted({
    required String commentId,
    required String postId,
    required bool currentlyAccepted,
  }) async {
    if (currentlyAccepted) {
      await SupabaseService.client
          .from('comments')
          .update({'is_accepted_answer': false}).eq('id', commentId);
      return;
    }

    // Unmark any previously accepted answer first, then mark this one.
    await SupabaseService.client
        .from('comments')
        .update({'is_accepted_answer': false}).eq('post_id', postId);
    await SupabaseService.client
        .from('comments')
        .update({'is_accepted_answer': true}).eq('id', commentId);

    await SupabaseService.client.rpc('award_reputation', params: {
      'target_post_id': postId,
      'action': 'accepted_answer',
    });
  }
}

final commentNotifierProvider =
    StateNotifierProvider.autoDispose<CommentNotifier, AsyncValue<void>>(
        (ref) => CommentNotifier());

// ─── Helpful toggle ────────────────────────────────────────────────────────────

class HelpfulToggleNotifier extends StateNotifier<void> {
  HelpfulToggleNotifier() : super(null);

  Future<void> toggle(String postId, bool currentlyHelpful) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final client = SupabaseService.client;
    if (currentlyHelpful) {
      await client
          .from('post_helpful')
          .delete()
          .match({'post_id': postId, 'user_id': userId});
    } else {
      await client
          .from('post_helpful')
          .insert({'post_id': postId, 'user_id': userId});
      await client.rpc('award_reputation', params: {
        'target_post_id': postId,
        'action': 'helpful',
      });
    }
  }
}

final helpfulToggleProvider =
    StateNotifierProvider<HelpfulToggleNotifier, void>(
        (ref) => HelpfulToggleNotifier());

// ─── Save toggle ───────────────────────────────────────────────────────────────

class SaveToggleNotifier extends StateNotifier<void> {
  SaveToggleNotifier() : super(null);

  Future<void> toggle(String postId, bool currentlySaved) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final client = SupabaseService.client;
    if (currentlySaved) {
      await client
          .from('post_saves')
          .delete()
          .match({'post_id': postId, 'user_id': userId});
    } else {
      await client
          .from('post_saves')
          .insert({'post_id': postId, 'user_id': userId});
    }
  }
}

final saveToggleProvider = StateNotifierProvider<SaveToggleNotifier, void>(
    (ref) => SaveToggleNotifier());

// ─── Report post ───────────────────────────────────────────────────────────────

Future<void> reportPost(
    {required String postId, required String reason}) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return;
  await SupabaseService.client.from('post_reports').insert({
    'post_id': postId,
    'reporter_id': userId,
    'reason': reason,
  });
}

// ─── Lightweight polling for post detail (catches other users' likes/comments
// counts without needing a manual refresh) ──────────────────────────────────
//
// Same reliable pattern used for the chat list and notifications badge —
// Realtime channels proved flaky to keep alive across the app's lifecycle,
// so periodic polling is used instead. Comments themselves are now true
// realtime (see commentsProvider above); this just covers the helpful/save
// counts shown on the post itself.
