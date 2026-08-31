import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_service.dart';
import '../models/chat_model.dart';

enum ChatsTabFilter { dms, groups, channels }

final chatsTabFilterProvider = StateProvider<ChatsTabFilter>((ref) => ChatsTabFilter.dms);

final chatsProvider = FutureProvider.autoDispose<List<ChatModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final rows = await SupabaseService.client
      .from('conversations_for_user')
      .select()
      .order('last_message_at', ascending: false);

  return (rows as List).map((r) => ChatModel.fromJson(r)).toList();
});

/// Total unread messages, for the Chats tab badge.
///
/// IMPORTANT: this derives directly from chatsProvider's live state instead
/// of being its own independent FutureProvider. The earlier version required
/// every single refresh point across the app (pull-to-refresh, the refresh
/// button, leaving a chat thread, polling, etc.) to remember to invalidate
/// BOTH providers — miss one and the badge silently goes stale even though
/// the list itself is fresh. Deriving it directly makes that class of bug
/// structurally impossible: whenever chatsProvider updates, this updates
/// automatically, with nothing extra to remember.
final unreadChatsCountProvider = Provider.autoDispose<int>((ref) {
  final chatsAsync = ref.watch(chatsProvider);
  return chatsAsync.valueOrNull?.fold<int>(0, (sum, c) => sum + c.unreadCount) ?? 0;
});