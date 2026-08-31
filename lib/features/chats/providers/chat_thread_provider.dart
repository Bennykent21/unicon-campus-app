import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/supabase/supabase_service.dart';
import '../models/message_model.dart';

final messagesStreamProvider = StreamProvider.autoDispose
    .family<List<MessageModel>, String>((ref, conversationId) {
  // Sender profiles cached per conversation. The realtime stream already
  // delivers every message column — only the sender's name/avatar are
  // missing. Previously we re-queried the `messages_with_sender` view for
  // ALL message ids on EVERY stream event (an N+1 pattern). Now we fetch
  // each sender's profile once and join client-side, so steady-state chat
  // traffic needs zero extra queries.
  final senderCache = <String, ({String name, String? avatar})>{};

  return SupabaseService.client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: false)
      .asyncMap((rows) async {
        if (rows.isEmpty) return <MessageModel>[];

        // Only look up senders we haven't seen yet (usually 0 after the
        // first event — a 1:1 chat has at most 2 senders).
        final unknownSenders = rows
            .map((r) => r['sender_id'] as String)
            .toSet()
            .where((id) => !senderCache.containsKey(id))
            .toList();
        if (unknownSenders.isNotEmpty) {
          final profiles = await SupabaseService.client
              .from('profiles')
              .select('id, full_name, avatar_url')
              .inFilter('id', unknownSenders);
          for (final p in profiles as List) {
            senderCache[p['id'] as String] = (
              name: p['full_name'] as String? ?? 'Unknown',
              avatar: p['avatar_url'] as String?,
            );
          }
        }

        return rows.map((r) {
          final sender = senderCache[r['sender_id'] as String];
          return MessageModel.fromJson({
            ...r,
            'sender_name': sender?.name,
            'sender_avatar': sender?.avatar,
          });
        }).toList();
      });
});

final conversationInfoProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, conversationId) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return null;
  final data = await SupabaseService.client
      .from('conversations_for_user')
      .select()
      .eq('id', conversationId)
      .maybeSingle();
  return data;
});

class SendMessageNotifier extends StateNotifier<bool> {
  SendMessageNotifier() : super(false);

  Future<void> send({
    required String conversationId,
    String body = '',
    File? imageFile,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    if (body.trim().isEmpty && imageFile == null) return;

    state = true;
    try {
      String? imageUrl;
      if (imageFile != null) {
        final ext = imageFile.path.split('.').last.toLowerCase();
        final path = '$userId/${const Uuid().v4()}.$ext';
        await SupabaseService.client.storage
            .from('chat-images')
            .upload(path, imageFile);
        imageUrl = SupabaseService.client.storage
            .from('chat-images')
            .getPublicUrl(path);
      }

      await SupabaseService.client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': userId,
        'body': body.trim(),
        if (imageUrl != null) 'image_url': imageUrl,
      });

      await SupabaseService.client
          .from('conversation_participants')
          .update({'last_read_at': DateTime.now().toIso8601String()}).match(
              {'conversation_id': conversationId, 'user_id': userId});
    } finally {
      state = false;
    }
  }
}

final sendMessageProvider =
    StateNotifierProvider.autoDispose<SendMessageNotifier, bool>(
        (ref) => SendMessageNotifier());

Future<void> markConversationRead(String conversationId) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return;
  await SupabaseService.client
      .from('conversation_participants')
      .update({'last_read_at': DateTime.now().toIso8601String()}).match(
          {'conversation_id': conversationId, 'user_id': userId});
}

/// Deletes a message. RLS only allows the sender to delete their own —
/// requires migration_015.sql to have been run.
Future<void> deleteMessage(String messageId) async {
  await SupabaseService.client.from('messages').delete().eq('id', messageId);
}
