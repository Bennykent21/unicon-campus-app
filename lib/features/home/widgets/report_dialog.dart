// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/post_detail_provider.dart';

const _reportReasons = [
  'Spam',
  'Inappropriate content',
  'Harassment or bullying',
  'False information',
  'Other',
];

/// Shows a reason picker, then submits the report to Supabase.
/// Call this instead of just showing a "Report submitted" snackbar —
/// it actually records the report now.
void showReportDialog(BuildContext context, String postId) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Report this post',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          ..._reportReasons.map((reason) => ListTile(
                title: Text(reason),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await reportPost(postId: postId, reason: reason);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Report submitted. Thanks for helping keep the community safe.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not submit report: $e')),
                      );
                    }
                  }
                },
              )),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
