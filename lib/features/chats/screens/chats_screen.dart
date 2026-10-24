import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../models/chat_model.dart';
import '../providers/chats_provider.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(chatsTabFilterProvider);
    final chatsAsync = ref.watch(chatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          // Manual refresh kept as an escape hatch. The list now auto-updates
          // via the app-wide realtime channel (realtime_sync.dart) whenever a
          // new message arrives, plus a 30s polling fallback in the nav shell.
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(chatsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/new-message'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(chatsProvider),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search chats, people, groups...',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _FilterPill(
                    label: 'DMs',
                    selected: activeFilter == ChatsTabFilter.dms,
                    onTap: () => ref
                        .read(chatsTabFilterProvider.notifier)
                        .state = ChatsTabFilter.dms,
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'Groups',
                    selected: activeFilter == ChatsTabFilter.groups,
                    onTap: () => ref
                        .read(chatsTabFilterProvider.notifier)
                        .state = ChatsTabFilter.groups,
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'Channels',
                    selected: activeFilter == ChatsTabFilter.channels,
                    onTap: () => ref
                        .read(chatsTabFilterProvider.notifier)
                        .state = ChatsTabFilter.channels,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: chatsAsync.when(
                data: (chats) {
                  final kindFilter = switch (activeFilter) {
                    ChatsTabFilter.dms => ChatKind.dm,
                    ChatsTabFilter.groups => ChatKind.group,
                    ChatsTabFilter.channels => ChatKind.channel,
                  };
                  final filtered =
                      chats.where((c) => c.kind == kindFilter).toList();
                  final pinned = filtered.where((c) => c.isPinned).toList();
                  final rest = filtered.where((c) => !c.isPinned).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      // Wrapped in ListView so pull-to-refresh still works
                      // even when the list is empty.
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No conversations yet')),
                      ],
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (pinned.isNotEmpty) ...[
                        const _SectionLabel('Pinned'),
                        ...pinned.map((c) => _ChatTile(chat: c)),
                      ],
                      if (rest.isNotEmpty) ...[
                        const _SectionLabel('All Chats'),
                        ...rest.map((c) => _ChatTile(chat: c)),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorState(error: e, action: 'load chats'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.palette.brandText,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Theme.of(context).dividerTheme.color?.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? Colors.white : null,
              fontWeight: FontWeight.w600,
              fontSize: 13),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.push('/chat/${chat.id}'),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: context.palette.brandSoft,
        backgroundImage: chat.avatarUrl != null
            ? CachedNetworkImageProvider(chat.avatarUrl!)
            : null,
        child: chat.avatarUrl == null
            ? Text(chat.title.isNotEmpty ? chat.title[0] : '?',
                style: TextStyle(
                    color: context.palette.brandText,
                    fontWeight: FontWeight.bold))
            : null,
      ),
      title:
          Text(chat.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle:
          Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(timeago.format(chat.lastMessageAt, locale: 'en_short'),
              style: Theme.of(context).textTheme.bodySmall),
          if (chat.unreadCount > 0) ...[
            const SizedBox(height: 4),
            CircleAvatar(
              radius: 9,
              backgroundColor: AppColors.primary,
              child: Text('${chat.unreadCount}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}
