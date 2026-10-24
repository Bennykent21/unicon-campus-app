import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/share_links.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/widgets/post_type_badge.dart';
import '../models/post_model.dart';
import 'image_viewer.dart';
import 'report_dialog.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final bool isMyPost;
  final bool isFollowingAuthor;
  final bool? isHelpfulByMe;
  final int? helpfulCount;
  final bool? isSavedByMe;
  final VoidCallback? onTap;
  final VoidCallback? onHelpful;
  final VoidCallback? onComment;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onFollow;
  final VoidCallback? onAvatarTap;

  const PostCard({
    super.key,
    required this.post,
    this.isMyPost = false,
    this.isFollowingAuthor = false,
    this.isHelpfulByMe,
    this.helpfulCount,
    this.isSavedByMe,
    this.onTap,
    this.onHelpful,
    this.onComment,
    this.onSave,
    this.onDelete,
    this.onFollow,
    this.onAvatarTap,
  });

  /// Light tap feedback for the quick actions.
  static VoidCallback? _withHaptic(VoidCallback? action) => action == null
      ? null
      : () {
          HapticFeedback.lightImpact();
          action();
        };

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            child: Text('Delete',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final muted = theme.colorScheme.onSurfaceVariant;
    final helpful = isHelpfulByMe ?? post.isHelpfulByMe;
    final hCount = helpfulCount ?? post.helpfulCount;
    final saved = isSavedByMe ?? post.isSavedByMe;
    final metaStyle = theme.textTheme.bodySmall;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: onAvatarTap != null,
                  label: "${post.authorName}'s profile",
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onAvatarTap,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: palette.brandSoft,
                      backgroundImage: post.authorAvatarUrl != null
                          ? CachedNetworkImageProvider(post.authorAvatarUrl!)
                          : null,
                      child: post.authorAvatarUrl == null
                          ? Text(
                              post.authorName.isNotEmpty
                                  ? post.authorName[0]
                                  : '?',
                              style: TextStyle(
                                  color: palette.brandText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15))
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(post.authorName,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontSize: 14),
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (post.authorUsername.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text('@${post.authorUsername}',
                                  style: metaStyle,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                          Text('  ·  ${compactTime(post.createdAt)}',
                              style: metaStyle),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Type badge sits on the second line so long names
                      // keep the full width of the first.
                      Row(children: [
                        if (post.authorLevel.isNotEmpty) ...[
                          Flexible(
                            child: Text(post.authorLevel,
                                overflow: TextOverflow.ellipsis,
                                style: metaStyle?.copyWith(
                                    color: palette.brandText,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        PostTypeBadge(type: post.type),
                      ]),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More options',
                  icon: Icon(Icons.more_horiz, size: 20, color: muted),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => [
                    if (!isMyPost)
                      PopupMenuItem(
                        value: 'follow',
                        child: _MenuItem(
                          isFollowingAuthor
                              ? Icons.person_remove_outlined
                              : Icons.person_add_outlined,
                          isFollowingAuthor
                              ? 'Unfollow @${post.authorUsername}'
                              : 'Follow @${post.authorUsername}',
                          null,
                        ),
                      ),
                    if (isMyPost)
                      PopupMenuItem(
                        value: 'delete',
                        child: _MenuItem(Icons.delete_outline, 'Delete post',
                            theme.colorScheme.error),
                      ),
                    if (!isMyPost)
                      const PopupMenuItem(
                        value: 'report',
                        child:
                            _MenuItem(Icons.flag_outlined, 'Report post', null),
                      ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: _MenuItem(Icons.link, 'Copy link', null),
                    ),
                  ],
                  onSelected: (v) {
                    switch (v) {
                      case 'follow':
                        onFollow?.call();
                      case 'delete':
                        _confirmDelete(context);
                      case 'report':
                        showReportDialog(context, post.id);
                      case 'copy':
                        ShareLinks.copy(context, ShareLinks.post(post.id));
                    }
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(post.title,
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (post.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(post.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13.5, color: muted, height: 1.4)),
                  ],
                  if (post.type == 'marketplace' && post.price != null) ...[
                    const SizedBox(height: 6),
                    Text(formatNaira(post.price!),
                        style: TextStyle(
                            color: palette.marketplace.fg,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ],
                  if (post.type == 'event' && post.eventDate != null) ...[
                    const SizedBox(height: 6),
                    _MetaLine(
                      icon: Icons.calendar_today,
                      color: palette.event.fg,
                      text:
                          '${post.eventDate!.day}/${post.eventDate!.month}/${post.eventDate!.year}'
                          ' · ${TimeOfDay.fromDateTime(post.eventDate!).format(context)}'
                          '${post.eventLocation != null && post.eventLocation!.isNotEmpty ? "  ·  ${post.eventLocation}" : ""}',
                    ),
                  ],
                  if (post.type == 'job') ...[
                    if (post.isInternship == true) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: palette.brandSoft,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('Internship',
                            style: TextStyle(
                                color: palette.brandText,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                    if (post.salary != null && post.salary!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _MetaLine(
                          icon: Icons.payments_outlined,
                          color: palette.job.fg,
                          text: post.salary!),
                    ],
                    if (post.jobLocation != null &&
                        post.jobLocation!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _MetaLine(
                          icon: Icons.location_on_outlined,
                          color: palette.job.fg,
                          text: post.jobLocation!),
                    ],
                  ],
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                        spacing: 8,
                        children: post.tags
                            .take(4)
                            .map((t) => Text('#$t',
                                style: TextStyle(
                                    color: palette.brandText,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)))
                            .toList()),
                  ],
                  if (post.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      image: true,
                      button: true,
                      label: post.imageUrls.length > 1
                          ? 'Open ${post.imageUrls.length} photos'
                          : 'Open photo',
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            ImageViewerPage.route(
                                imageUrls: post.imageUrls,
                                initialIndex: 0,
                                heroTag: 'post_img_${post.id}_0')),
                        child: Hero(
                          tag: 'post_img_${post.id}_0',
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: post.imageUrls.first,
                                  height: 170,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                      height: 170, color: palette.shimmerBase),
                                  errorWidget: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              // Multi-image indicator — like Instagram's stacked-photos badge
                              if (post.imageUrls.length > 1)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.photo_library,
                                              color: Colors.white, size: 13),
                                          const SizedBox(width: 4),
                                          Text('${post.imageUrls.length}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700)),
                                        ]),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 2),
            // Shift left so the first icon lines up with the text above while
            // keeping its full 48dp hit area.
            Transform.translate(
              offset: const Offset(-10, 0),
              child: Row(children: [
                _EngageBtn(
                  icon: helpful ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                  label: hCount > 0 ? '$hCount Helpful' : 'Helpful',
                  semanticLabel: helpful
                      ? 'Marked helpful, $hCount total. Tap to undo'
                      : 'Mark helpful, $hCount so far',
                  color: helpful ? palette.marketplace.fg : null,
                  onTap: _withHaptic(onHelpful),
                ),
                _EngageBtn(
                  icon: Icons.mode_comment_outlined,
                  label: post.commentCount > 0 ? '${post.commentCount}' : '',
                  semanticLabel: '${post.commentCount} comments',
                  onTap: onComment,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _withHaptic(onSave),
                  tooltip: saved ? 'Remove from saved' : 'Save post',
                  icon: Icon(
                    saved ? Icons.bookmark : Icons.bookmark_border,
                    size: 21,
                    color: saved ? palette.brandText : muted,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _MetaLine(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, color: color, fontWeight: FontWeight.w600)),
        ),
      ]);
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

/// Icon + optional count, with a 48dp-tall hit area and a spoken label.
class _EngageBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticLabel;
  final Color? color;
  final VoidCallback? onTap;
  const _EngageBtn(
      {required this.icon,
      required this.label,
      required this.semanticLabel,
      this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: c),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: 13, color: c, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
