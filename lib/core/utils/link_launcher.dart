import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_logger.dart';

/// Opens web, email and phone links outside the app, with a SnackBar when
/// nothing on the device can handle them.
class LinkLauncher {
  LinkLauncher._();

  static Future<bool> open(BuildContext context, Uri uri,
      {String failureMessage = "Couldn't open this link."}) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (e, st) {
      AppLogger.error('launchUrl failed for $uri', error: e, stackTrace: st);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failureMessage)));
    }
    return false;
  }

  static Future<bool> web(BuildContext context, String url) =>
      open(context, Uri.parse(url));

  static Future<bool> phone(BuildContext context, String number) => open(
        context,
        Uri(scheme: 'tel', path: number.replaceAll(RegExp(r'[^0-9+]'), '')),
        failureMessage: 'No app on this phone can make calls.',
      );
}
