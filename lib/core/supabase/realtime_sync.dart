import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/chats/providers/chats_provider.dart';
import '../../features/home/providers/home_provider.dart';
import '../utils/app_logger.dart';
import 'supabase_service.dart';

/// Centralized realtime sync for app-wide badges and lists.
///
/// Instead of each screen polling or requiring a manual refresh, this
/// provider opens ONE Supabase Realtime channel for the whole app and
/// invalidates the relevant Riverpod providers the moment a relevant row
/// changes on the server:
///
///   - `messages` insert  -> refresh chat list (unread counts + nav badge,
///     both derive from chatsProvider, so one invalidation updates both)
///   - `notifications` insert/update -> refresh the bell badge
///
/// IMPORTANT (server-side): Supabase Realtime only emits events for tables
/// added to the `supabase_realtime` publication. Run
/// `supabase/migration_017_enable_realtime.sql` once or none of these
/// events will ever fire.
///
/// Keep the periodic polling in BottomNavShell as a fallback — realtime
/// WebSockets can drop when the app is backgrounded; polling guarantees
/// eventual consistency, realtime provides the instant updates.
final realtimeSyncProvider = Provider<void>((ref) {
  Timer? chatsDebounce;
  Timer? notifsDebounce;

  // Debounce bursts (e.g. someone sends 5 messages quickly) into a single
  // provider refresh to avoid hammering the database view.
  void refreshChats() {
    chatsDebounce?.cancel();
    chatsDebounce = Timer(const Duration(milliseconds: 350), () {
      ref.invalidate(chatsProvider);
    });
  }

  void refreshNotifications() {
    notifsDebounce?.cancel();
    notifsDebounce = Timer(const Duration(milliseconds: 350), () {
      ref.invalidate(unreadNotificationsProvider);
    });
  }

  final channel = SupabaseService.client
      .channel('app-global-sync')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          AppLogger.info('realtime: new message', name: 'realtime');
          refreshChats();
        },
      )
      .onPostgresChanges(
        // Insert = new notification, update = marked read on another device.
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        callback: (payload) {
          AppLogger.info('realtime: notifications changed', name: 'realtime');
          refreshNotifications();
        },
      )
      .subscribe((status, error) {
        AppLogger.info('realtime channel: $status', name: 'realtime');
        if (error != null) {
          AppLogger.error('realtime channel error',
              name: 'realtime', error: error);
        }
      });

  ref.onDispose(() {
    chatsDebounce?.cancel();
    notifsDebounce?.cancel();
    SupabaseService.client.removeChannel(channel);
  });
});
