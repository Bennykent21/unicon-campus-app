import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_formatter.dart';
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

  ({Color color, String label}) get _badge => switch (post.type) {
        'question' => (color: AppColors.question, label: 'Q&A'),
        'marketplace' => (color: AppColors.marketplace, label: 'MARKET'),
        'job' => (color: AppColors.job, label: 'JOB'),
        'event' => (color: AppColors.event, label: 'EVENT'),
        _ => (color: AppColors.general, label: 'GENERAL'),
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = _badge;
    final helpful = isHelpfulByMe ?? post.isHelpfulByMe;
    final hCount = helpfulCount ?? post.helpfulCount;
    final saved = isSavedByMe ?? post.isSavedByMe;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: post.authorAvatarUrl != null
                        ? NetworkImage(post.authorAvatarUrl!)
                        : null,
                    child: post.authorAvatarUrl == null
                        ? Text(
                            post.authorName.isNotEmpty
                                ? post.authorName[0]
                                : '?',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14))
                        : null,
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
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (post.authorUsername.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text('@${post.authorUsername}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      color: theme.textTheme.bodySmall?.color
                                          ?.withValues(alpha: 0.55)),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                          const SizedBox(width: 4),
                          Text('·',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 11)),
                          const SizedBox(width: 4),
                          Text(compactTime(post.createdAt),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 11)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badge.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(badge.label,
                                style: TextStyle(
                                    color: badge.color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3)),
                          ),
                          const SizedBox(width: 2),
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.more_horiz,
                                  size: 16,
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.55)),
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
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: _MenuItem(Icons.delete_outline,
                                        'Delete post', Colors.red),
                                  ),
                                if (!isMyPost)
                                  const PopupMenuItem(
                                    value: 'report',
                                    child: _MenuItem(Icons.flag_outlined,
                                        'Report post', null),
                                  ),
                                const PopupMenuItem(
                                  value: 'copy',
                                  child:
                                      _MenuItem(Icons.link, 'Copy link', null),
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Link copied!'),
                                            behavior:
                                                SnackBarBehavior.floating));
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (post.authorLevel.isNotEmpty)
                        Text(post.authorLevel,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(post.title,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (post.body.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(post.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12.5,
                      height: 1.4,
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.8))),
            ],
            if (post.type == 'marketplace' && post.price != null) ...[
              const SizedBox(height: 5),
              Text('₦${post.price!.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: AppColors.marketplace,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ],
            if (post.type == 'event' && post.eventDate != null) ...[
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.calendar_today,
                    size: 11, color: AppColors.event),
                const SizedBox(width: 4),
                Text(
                    '${post.eventDate!.day}/${post.eventDate!.month}/${post.eventDate!.year}'
                    ' · ${TimeOfDay.fromDateTime(post.eventDate!).format(context)}'
                    '${post.eventLocation != null ? "  ·  ${post.eventLocation}" : ""}',
                    style: const TextStyle(
                        color: AppColors.event,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ],
            if (post.type == 'job') ...[
              if (post.isInternship == true) ...[
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('Internship',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
              if (post.salary != null && post.salary!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.payments_outlined,
                      size: 11, color: AppColors.job),
                  const SizedBox(width: 3),
                  Text(post.salary!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.job,
                          fontWeight: FontWeight.w600)),
                ]),
              ],
              if (post.jobLocation != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 11, color: AppColors.job),
                  const SizedBox(width: 3),
                  Text(post.jobLocation!,
                      style:
                          const TextStyle(fontSize: 11, color: AppColors.job)),
                ]),
              ],
            ],
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 5),
              Wrap(
                  spacing: 6,
                  children: post.tags
                      .take(4)
                      .map((t) => Text('#$t',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)))
                      .toList()),
            ],
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
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
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              height: 160,
                              color: theme.dividerTheme.color
                                  ?.withValues(alpha: 0.4)),
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
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
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.photo_library,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text('${post.imageUrls.length}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              _EngageBtn(
                icon: helpful ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                label: hCount > 0 ? '$hCount  Helpful' : 'Helpful',
                color: helpful ? AppColors.helpful : null,
                onTap: onHelpful,
              ),
              const SizedBox(width: 20),
              _EngageBtn(
                icon: Icons.mode_comment_outlined,
                label: post.commentCount > 0 ? '${post.commentCount}' : '',
                onTap: onComment,
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSave,
                child: Icon(
                  saved ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                  color: saved
                      ? AppColors.primary
                      : theme.textTheme.bodySmall?.color,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
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

class _EngageBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  const _EngageBtn(
      {required this.icon, required this.label, this.color, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          ],
        ]),
      );
}
