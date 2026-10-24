import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Deep links into the app. Android routes `unicon://open/<path>` to the
/// matching go_router location (see the intent filter in AndroidManifest.xml).
class ShareLinks {
  ShareLinks._();

  static const _base = 'unicon://open';

  static String post(String postId) => '$_base/post/$postId';
  static String user(String userId) => '$_base/user/$userId';
  static String internship(String internshipId) =>
      '$_base/internships/$internshipId';

  /// Copies [text] and confirms with a SnackBar.
  static Future<void> copy(BuildContext context, String text,
      {String message = 'Link copied'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
