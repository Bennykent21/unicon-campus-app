import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../home/widgets/image_viewer.dart';
import '../models/message_model.dart';
import '../providers/chat_thread_provider.dart';
import '../providers/chats_provider.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatThreadScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _messageController = TextEditingController();
  File? _pendingImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      markConversationRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    ref.invalidate(chatsProvider);
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _pendingImage = File(picked.path));
  }

  Future<void> _send() async {
    final text = _messageController.text;
    if (text.trim().isEmpty && _pendingImage == null) return;
    final image = _pendingImage;
    _messageController.clear();
    setState(() => _pendingImage = null);
    try {
      await ref.read(sendMessageProvider.notifier).send(
            conversationId: widget.conversationId,
            body: text,
            imageFile: image,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
      }
    }
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('$feature is coming in a future update'),
          behavior: SnackBarBehavior.floating),
    );
  }

  void _showMessageOptions(MessageModel msg, bool isMine) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.body.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: msg.body));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Copied!'),
                        behavior: SnackBarBehavior.floating),
                  );
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await deleteMessage(msg.id);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not delete: $e')),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync =
        ref.watch(conversationInfoProvider(widget.conversationId));
    final messagesAsync =
        ref.watch(messagesStreamProvider(widget.conversationId));
    final isSending = ref.watch(sendMessageProvider);
    final theme = Theme.of(context);
    final myId = SupabaseService.currentUserId;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        titleSpacing: 0,
        title: infoAsync.when(
          loading: () => const Text('Chat'),
          error: (_, __) => const Text('Chat'),
          data: (info) {
            if (info == null) return const Text('Chat');
            return Row(children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: info['avatar_url'] != null
                    ? NetworkImage(info['avatar_url'] as String)
                    : null,
                child: info['avatar_url'] == null
                    ? Text(
                        (info['title'] as String?)?.isNotEmpty == true
                            ? (info['title'] as String)[0]
                            : '?',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info['title'] as String? ?? 'Chat',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined, size: 20),
            onPressed: () => _comingSoon('Voice calls'),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: () => _comingSoon('Chat settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                      child: Text('Say hello 👋',
                          style: theme.textTheme.bodySmall));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMine = msg.senderId == myId;
                    final showAvatar = !isMine &&
                        (i == messages.length - 1 ||
                            messages[i + 1].senderId != msg.senderId);
                    return GestureDetector(
                      onLongPress: () => _showMessageOptions(msg, isMine),
                      child: _MessageBubble(
                          message: msg, isMine: isMine, showAvatar: showAvatar),
                    );
                  },
                );
              },
            ),
          ),
          if (_pendingImage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_pendingImage!,
                        width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _pendingImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(
              10,
              8,
              10,
              MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  8,
            ),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                  top: BorderSide(
                      color: theme.dividerTheme.color ?? Colors.transparent)),
            ),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: AppColors.primary),
                onPressed: _pickImage,
              ),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.dividerTheme.color?.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: 4,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Message...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: AppColors.primary),
                      onPressed: _send,
                    ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final bool showAvatar;

  const _MessageBubble(
      {required this.message, required this.isMine, required this.showAvatar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            SizedBox(
              width: 28,
              child: showAvatar
                  ? CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: message.senderAvatarUrl != null
                          ? NetworkImage(message.senderAvatarUrl!)
                          : null,
                      child: message.senderAvatarUrl == null
                          ? Text(
                              message.senderName.isNotEmpty
                                  ? message.senderName[0]
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold))
                          : null,
                    )
                  : null,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              margin: EdgeInsets.only(
                  left: isMine ? 40 : 0, right: isMine ? 0 : 40),
              padding: message.imageUrl != null
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: isMine
                    ? AppColors.primary
                    : theme.dividerTheme.color?.withValues(alpha: 0.4),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.imageUrl != null)
                    GestureDetector(
                      // Tap to view full screen — reuses the same viewer
                      // widget as the home feed's image viewing.
                      onTap: () => Navigator.push(
                        context,
                        ImageViewerPage.route(
                          imageUrls: [message.imageUrl!],
                          initialIndex: 0,
                          heroTag: 'chat_img_${message.id}',
                        ),
                      ),
                      child: Hero(
                        tag: 'chat_img_${message.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            message.imageUrl!,
                            width: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox(
                                width: 200,
                                height: 140,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              );
                            },
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 200,
                              height: 140,
                              child: Icon(Icons.broken_image,
                                  color: Colors.white38),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (message.body.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        top: message.imageUrl != null ? 6 : 0,
                        left: message.imageUrl != null ? 8 : 0,
                        right: message.imageUrl != null ? 8 : 0,
                      ),
                      child: Text(
                        message.body,
                        style: TextStyle(
                            color: isMine ? Colors.white : null,
                            fontSize: 14,
                            height: 1.35),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: 3,
                      left: message.imageUrl != null ? 8 : 0,
                      right: message.imageUrl != null ? 8 : 0,
                      bottom: message.imageUrl != null ? 4 : 0,
                    ),
                    child: Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMine
                            ? Colors.white70
                            : theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
