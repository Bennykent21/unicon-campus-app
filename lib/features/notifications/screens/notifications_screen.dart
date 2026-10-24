import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/widgets/state_views.dart';

class NotificationModel {
  final String id;
  final String type; // comment | helpful | follow | accepted_answer
  final String actorName;
  final String? actorAvatarUrl;
  final String message;
  final String? postId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.actorName,
    this.actorAvatarUrl,
    required this.message,
    this.postId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'general',
      actorName: json['actor_name'] as String? ?? 'Someone',
      actorAvatarUrl: json['actor_avatar'] as String?,
      message: json['message'] as String? ?? '',
      postId: json['post_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final data = await SupabaseService.client
      .from('notifications')
      .select()
      .eq('recipient_id', userId)
      .order('created_at', ascending: false)
      .limit(50);

  return (data as List).map((e) => NotificationModel.fromJson(e)).toList();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconForType(String type) => switch (type) {
        'comment' => Icons.mode_comment_outlined,
        'helpful' => Icons.thumb_up_outlined,
        'follow' => Icons.person_add_outlined,
        'accepted_answer' => Icons.check_circle_outline,
        _ => Icons.notifications_none,
      };

  Color _colorForType(String type) => switch (type) {
        'comment' => AppColors.primary,
        'helpful' => AppColors.helpful,
        'follow' => const Color(0xFF3B82F6),
        'accepted_answer' => AppColors.helpful,
        _ => AppColors.general,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              final userId = SupabaseService.currentUserId;
              if (userId == null) return;
              await SupabaseService.client
                  .from('notifications')
                  .update({'is_read': true}).eq('recipient_id', userId);
              ref.invalidate(notificationsProvider);
            },
            child: Text('Mark all read',
                style:
                    TextStyle(color: context.palette.brandText, fontSize: 13)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: notifs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(error: e, action: 'load notifications'),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none,
                        size: 48,
                        color: AppColors.primary.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text('No notifications yet',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                        'When people interact with your posts,\nyou\'ll see it here.',
                        textAlign: TextAlign.center,
                        style:
                            theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                  ],
                ),
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: theme.dividerTheme.color,
              ),
              itemBuilder: (context, i) {
                final n = items[i];
                final color = _colorForType(n.type);
                return InkWell(
                  onTap: n.postId != null
                      ? () => context.push('/post/${n.postId}')
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    color: n.isRead
                        ? Colors.transparent
                        : AppColors.primary.withValues(alpha: 0.05),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon circle
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_iconForType(n.type),
                              color: color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontSize: 13),
                                  children: [
                                    TextSpan(
                                      text: n.actorName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    TextSpan(text: ' ${n.message}'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                compactTime(n.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
