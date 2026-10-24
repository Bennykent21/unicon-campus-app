import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/share_links.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/widgets/post_type_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../providers/post_detail_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/comment_tile.dart';
import '../widgets/image_viewer.dart';
import '../widgets/report_dialog.dart';

enum CommentSort { mostRecent, mostHelpful }

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _focusNode = FocusNode();
  CommentSort _sort = CommentSort.mostRecent;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _prefillReply(String username) {
    final text = '@$username ';
    _commentController.text = text;
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    _focusNode.requestFocus();
  }

  Future<void> _submitComment(PostModel post) async {
    if (_commentController.text.trim().isEmpty) return;
    await ref
        .read(commentNotifierProvider.notifier)
        .submit(postId: post.id, body: _commentController.text);
    _commentController.clear();
    _focusNode.unfocus();
  }

  Future<void> _deletePost(BuildContext context, String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await SupabaseService.client.from('posts').delete().eq('id', postId);
      } catch (e, st) {
        if (context.mounted) {
          showErrorSnack(context, e,
              action: 'delete this post', stackTrace: st);
        }
        return;
      }
      ref.invalidate(feedPostsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Post deleted')));
      context.pop();
    }
  }

  void _sharePost(PostModel post) =>
      ShareLinks.copy(context, ShareLinks.post(post.id));

  List<CommentModel> _sorted(List<CommentModel> comments) {
    final list = List<CommentModel>.from(comments);
    list.sort((a, b) {
      if (a.isAcceptedAnswer && !b.isAcceptedAnswer) return -1;
      if (!a.isAcceptedAnswer && b.isAcceptedAnswer) return 1;
      return _sort == CommentSort.mostHelpful
          ? b.helpfulCount.compareTo(a.helpfulCount)
          : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    final commentState = ref.watch(commentNotifierProvider);
    final followOverlay = ref.watch(followOverlayProvider);
    final currentUserId = SupabaseService.currentUserId;
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Post', style: TextStyle(fontSize: 17)),
        actions: [
          postAsync.whenOrNull(data: (post) {
                if (post == null) return null;
                final isMyPost = post.authorId == currentUserId;
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Copy link',
                    icon: const Icon(Icons.ios_share_outlined, size: 20),
                    onPressed: () => _sharePost(post),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More options',
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      if (isMyPost)
                        PopupMenuItem(
                            value: 'delete',
                            child: _MenuItem(Icons.delete_outline,
                                'Delete post', theme.colorScheme.error)),
                      if (!isMyPost)
                        const PopupMenuItem(
                            value: 'report',
                            child: _MenuItem(
                                Icons.flag_outlined, 'Report post', null)),
                      const PopupMenuItem(
                          value: 'copy',
                          child: _MenuItem(Icons.link, 'Copy link', null)),
                    ],
                    onSelected: (v) {
                      switch (v) {
                        case 'delete':
                          _deletePost(context, post.id);
                        case 'report':
                          showReportDialog(context, post.id);
                        case 'copy':
                          _sharePost(post);
                      }
                    },
                  ),
                ]);
              }) ??
              const SizedBox.shrink(),
          const SizedBox(width: 4),
        ],
      ),
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: e,
          action: 'load this post',
          onRetry: () => ref.invalidate(postDetailProvider(widget.postId)),
        ),
        data: (post) {
          if (post == null) {
            return EmptyState(
              icon: Icons.article_outlined,
              message: 'This post was deleted or is no longer available.',
              actionLabel: 'Back to feed',
              onAction: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            );
          }
          final isMyPost = post.authorId == currentUserId;
          final isFollowing = followOverlay.containsKey(post.authorId)
              ? followOverlay[post.authorId]!
              : post.isFollowingAuthor;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            button: !isMyPost,
                            label: "${post.authorName}'s profile",
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: !isMyPost
                                  ? () => context.push('/user/${post.authorId}')
                                  : null,
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: palette.brandSoft,
                                backgroundImage: post.authorAvatarUrl != null
                                    ? CachedNetworkImageProvider(
                                        post.authorAvatarUrl!)
                                    : null,
                                child: post.authorAvatarUrl == null
                                    ? Text(
                                        post.authorName.isNotEmpty
                                            ? post.authorName[0]
                                            : '?',
                                        style: TextStyle(
                                            color: palette.brandText,
                                            fontWeight: FontWeight.bold))
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(
                                    child: Text(post.authorName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  if (post.authorUsername.isNotEmpty) ...[
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text('@${post.authorUsername}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(fontSize: 12),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ]),
                                Row(children: [
                                  if (post.authorLevel.isNotEmpty) ...[
                                    Flexible(
                                      child: Text(post.authorLevel,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  color: palette.brandText,
                                                  fontWeight: FontWeight.w600)),
                                    ),
                                    Text('  ·  ',
                                        style: theme.textTheme.bodySmall),
                                  ],
                                  Text(compactTime(post.createdAt),
                                      style: theme.textTheme.bodySmall),
                                ]),
                              ],
                            ),
                          ),
                          if (!isMyPost) ...[
                            const SizedBox(width: 10),
                            _FollowButton(
                              isFollowing: isFollowing,
                              onTap: () => ref
                                  .read(engagementProvider.notifier)
                                  .toggleFollow(post.authorId, isFollowing),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PostTypeBadge(type: post.type, short: false),
                          const SizedBox(height: 10),
                          Text(post.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800, fontSize: 18)),
                          if (post.body.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(post.body,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(height: 1.6, fontSize: 14)),
                          ],
                          if (post.type == 'marketplace' &&
                              post.price != null) ...[
                            const SizedBox(height: 12),
                            Text(formatNaira(post.price!),
                                style: TextStyle(
                                    color: palette.marketplace.fg,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 24)),
                          ],
                          if (post.type == 'event' &&
                              post.eventDate != null) ...[
                            const SizedBox(height: 10),
                            _InfoRow(
                                icon: Icons.calendar_today,
                                label:
                                    '${post.eventDate!.day}/${post.eventDate!.month}/${post.eventDate!.year}'
                                    ' at ${TimeOfDay.fromDateTime(post.eventDate!).format(context)}'),
                            if (post.eventLocation != null)
                              _InfoRow(
                                  icon: Icons.location_on_outlined,
                                  label: post.eventLocation!),
                          ],
                          if (post.type == 'job') ...[
                            const SizedBox(height: 10),
                            if (post.salary != null && post.salary!.isNotEmpty)
                              _InfoRow(
                                  icon: Icons.payments_outlined,
                                  label: post.salary!),
                            if (post.jobLocation != null)
                              _InfoRow(
                                  icon: Icons.location_on_outlined,
                                  label: post.jobLocation!),
                            if (post.isInternship == true)
                              const _InfoRow(
                                  icon: Icons.work_outline,
                                  label: 'Internship'),
                          ],
                          if (post.tags.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                                spacing: 8,
                                children: post.tags
                                    .map((t) => Text('#$t',
                                        style: TextStyle(
                                            color: palette.brandText,
                                            fontWeight: FontWeight.w600)))
                                    .toList()),
                          ],
                          if (post.imageUrls.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            post.imageUrls.length == 1
                                ? _SingleImage(
                                    postId: post.id,
                                    url: post.imageUrls.first,
                                    allUrls: post.imageUrls)
                                : _ImageGrid(
                                    postId: post.id, imageUrls: post.imageUrls),
                          ],
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Row(children: [
                        if (post.helpfulCount > 0) ...[
                          Icon(Icons.thumb_up,
                              size: 14,
                              color: post.isHelpfulByMe
                                  ? palette.marketplace.fg
                                  : theme.textTheme.bodySmall?.color),
                          const SizedBox(width: 4),
                          Text('${post.helpfulCount} Helpful',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 14),
                        ],
                        if (post.commentCount > 0) ...[
                          Icon(Icons.mode_comment_outlined,
                              size: 14,
                              color: theme.textTheme.bodySmall?.color),
                          const SizedBox(width: 4),
                          Text('${post.commentCount} Comments',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 14),
                        ],
                        if (post.isSavedByMe) ...[
                          Icon(Icons.bookmark,
                              size: 14, color: palette.brandText),
                          const SizedBox(width: 4),
                          Text('Saved',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: palette.brandText)),
                        ],
                      ]),
                    ),
                    Divider(height: 1, color: theme.dividerTheme.color),
                    Row(children: [
                      Expanded(
                          child: _EngageBtn(
                        icon: post.isHelpfulByMe
                            ? Icons.thumb_up
                            : Icons.thumb_up_alt_outlined,
                        label: 'Helpful',
                        color:
                            post.isHelpfulByMe ? palette.marketplace.fg : null,
                        onTap: () => ref
                            .read(helpfulToggleProvider.notifier)
                            .toggle(post.id, post.isHelpfulByMe)
                            .then((_) =>
                                ref.refresh(postDetailProvider(post.id))),
                      )),
                      _vDivider(context),
                      Expanded(
                          child: _EngageBtn(
                        icon: Icons.mode_comment_outlined,
                        label: 'Comment',
                        onTap: () => _focusNode.requestFocus(),
                      )),
                      _vDivider(context),
                      Expanded(
                          child: _EngageBtn(
                        icon: post.isSavedByMe
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        label: 'Save',
                        color: post.isSavedByMe ? palette.brandText : null,
                        onTap: () => ref
                            .read(saveToggleProvider.notifier)
                            .toggle(post.id, post.isSavedByMe)
                            .then((_) =>
                                ref.refresh(postDetailProvider(post.id))),
                      )),
                      _vDivider(context),
                      Expanded(
                          child: _EngageBtn(
                        icon: Icons.ios_share_outlined,
                        label: 'Copy link',
                        onTap: () => _sharePost(post),
                      )),
                    ]),
                    Divider(height: 1, color: theme.dividerTheme.color),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(children: [
                        Text('Comments (${post.commentCount})',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        PopupMenuButton<CommentSort>(
                          tooltip: 'Sort comments',
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: (s) => setState(() => _sort = s),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: CommentSort.mostRecent,
                              child: Text('Most recent',
                                  style: TextStyle(
                                      fontWeight:
                                          _sort == CommentSort.mostRecent
                                              ? FontWeight.w700
                                              : FontWeight.normal,
                                      color: _sort == CommentSort.mostRecent
                                          ? palette.brandText
                                          : null)),
                            ),
                            PopupMenuItem(
                              value: CommentSort.mostHelpful,
                              child: Text('Most helpful',
                                  style: TextStyle(
                                      fontWeight:
                                          _sort == CommentSort.mostHelpful
                                              ? FontWeight.w700
                                              : FontWeight.normal,
                                      color: _sort == CommentSort.mostHelpful
                                          ? palette.brandText
                                          : null)),
                            ),
                          ],
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(
                                _sort == CommentSort.mostRecent
                                    ? 'Most recent'
                                    : 'Most helpful',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: palette.brandText,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                              Icon(Icons.keyboard_arrow_down,
                                  size: 18, color: palette.brandText),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                    commentsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => ErrorState(
                        error: e,
                        action: 'load comments',
                        onRetry: () =>
                            ref.invalidate(commentsProvider(widget.postId)),
                      ),
                      data: (comments) {
                        if (comments.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                  'No comments yet. Start the discussion below.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant)),
                            ),
                          );
                        }
                        final sorted = _sorted(comments);
                        return Column(
                          children: List.generate(sorted.length, (i) {
                            final c = sorted[i];
                            return Column(
                              children: [
                                CommentTile(
                                  comment: c,
                                  isPostAuthor: isMyPost,
                                  onToggleAccepted: isMyPost
                                      ? () => ref
                                          .read(
                                              commentNotifierProvider.notifier)
                                          .toggleAccepted(
                                              commentId: c.id,
                                              postId: post.id,
                                              currentlyAccepted:
                                                  c.isAcceptedAnswer)
                                      : null,
                                  onReply: () => _prefillReply(c.authorName),
                                ),
                                if (i < sorted.length - 1)
                                  Divider(
                                      height: 1,
                                      color: theme.dividerTheme.color),
                              ],
                            );
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  MediaQuery.of(context).viewInsets.bottom +
                      MediaQuery.of(context).padding.bottom +
                      10,
                ),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(
                      top: BorderSide(
                          color:
                              theme.dividerTheme.color ?? Colors.transparent)),
                ),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      maxLines: null,
                      decoration:
                          const InputDecoration(hintText: 'Add a comment...'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  commentState is AsyncLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          tooltip: 'Send comment',
                          icon: Icon(Icons.send_rounded,
                              color: palette.brandText),
                          onPressed: () => _submitComment(post),
                        ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _vDivider(BuildContext context) => Container(
      width: 1,
      height: 28,
      color: Theme.of(context).dividerTheme.color?.withValues(alpha: 0.5),
    );

class _EngageBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  const _EngageBtn(
      {required this.icon, required this.label, this.color, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onTap;
  const _FollowButton({required this.isFollowing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brand = context.palette.brandText;
    return Semantics(
      button: true,
      label: isFollowing ? 'Following. Tap to unfollow' : 'Follow',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isFollowing ? Colors.transparent : AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: isFollowing ? brand : Colors.transparent),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isFollowing) ...[
                  Icon(Icons.check, size: 14, color: brand),
                  const SizedBox(width: 4),
                ],
                Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isFollowing ? brand : Colors.white,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon, size: 16, color: context.palette.brandText),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ]),
      );
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

class _SingleImage extends StatelessWidget {
  final String postId;
  final String url;
  final List<String> allUrls;
  const _SingleImage(
      {required this.postId, required this.url, required this.allUrls});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.push(
            context,
            ImageViewerPage.route(
                imageUrls: allUrls,
                initialIndex: 0,
                heroTag: 'detail_img_${postId}_0')),
        child: Hero(
          tag: 'detail_img_${postId}_0',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: url,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(height: 200, color: context.palette.shimmerBase),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
}

class _ImageGrid extends StatelessWidget {
  final String postId;
  final List<String> imageUrls;
  const _ImageGrid({required this.postId, required this.imageUrls});

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: imageUrls.length > 4 ? 4 : imageUrls.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1),
        itemBuilder: (context, i) {
          final isLast = i == 3 && imageUrls.length > 4;
          return GestureDetector(
            onTap: () => Navigator.push(
                context,
                ImageViewerPage.route(
                    imageUrls: imageUrls,
                    initialIndex: i,
                    heroTag: 'detail_img_${postId}_$i')),
            child: Hero(
              tag: 'detail_img_${postId}_$i',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(fit: StackFit.expand, children: [
                  CachedNetworkImage(
                      imageUrl: imageUrls[i],
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink()),
                  if (isLast)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: Text('+${imageUrls.length - 4}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                    ),
                ]),
              ),
            ),
          );
        },
      );
}
