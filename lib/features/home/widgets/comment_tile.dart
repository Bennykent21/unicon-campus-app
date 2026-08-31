import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_formatter.dart';
import '../models/comment_model.dart';

class CommentTile extends StatelessWidget {
  final CommentModel comment;
  final bool isPostAuthor;

  /// Called whenever the post author taps "Mark accepted" OR taps the
  /// "Accepted" badge itself to unmark it — same callback handles both,
  /// the parent decides which via the comment's current state.
  final VoidCallback? onToggleAccepted;
  final VoidCallback? onReply;

  const CommentTile({
    super.key,
    required this.comment,
    this.isPostAuthor = false,
    this.onToggleAccepted,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: comment.authorAvatarUrl != null
                    ? NetworkImage(comment.authorAvatarUrl!)
                    : null,
                child: comment.authorAvatarUrl == null
                    ? Text(
                        comment.authorName.isNotEmpty
                            ? comment.authorName[0]
                            : '?',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12))
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(comment.authorName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Text('·',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 11)),
                      const SizedBox(width: 6),
                      Text(compactTime(comment.createdAt),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 11)),
                      const Spacer(),
                      // Accepted badge — tappable by the post author to UNMARK it.
                      // Non-authors just see it as a static badge.
                      if (comment.isAcceptedAnswer)
                        GestureDetector(
                          onTap: isPostAuthor ? onToggleAccepted : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.helpful.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      AppColors.helpful.withValues(alpha: 0.3)),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.check_circle,
                                  color: AppColors.helpful, size: 12),
                              const SizedBox(width: 4),
                              Text(isPostAuthor ? 'Accepted ✕' : 'Accepted',
                                  style: const TextStyle(
                                      color: AppColors.helpful,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        )
                      else if (isPostAuthor)
                        GestureDetector(
                          onTap: onToggleAccepted,
                          child: Text('Mark accepted',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: AppColors.helpful,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ]),
                    if (comment.authorLevel.isNotEmpty)
                      Text(comment.authorLevel,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 38, top: 6),
            child: Text(comment.body,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontSize: 13.5, height: 1.5)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 6),
            child: Row(children: [
              GestureDetector(
                onTap: onReply,
                child: Text('Reply',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.6))),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
