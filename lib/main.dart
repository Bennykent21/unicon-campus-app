import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/supabase/supabase_service.dart';
import 'core/utils/app_logger.dart';
import 'core/widgets/startup_error_app.dart';

void main() {
  runZonedGuarded(_start, (error, stack) {
    AppLogger.error('Uncaught error',
        name: 'zone', error: error, stackTrace: stack);
  });
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Log framework and platform errors instead of losing them, and replace
  // the red/grey error box with a calm message in release builds.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error('Flutter error',
        name: 'flutter', error: details.exception, stackTrace: details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Platform error',
        name: 'platform', error: error, stackTrace: stack);
    return true;
  };
  ErrorWidget.builder = (details) => const _BrokenWidget();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    // Loads SUPABASE_URL / SUPABASE_ANON_KEY from .env (see .env.example).
    // .env is gitignored — never commit real keys.
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (url.isEmpty || key.isEmpty) {
      throw StateError(
          'SUPABASE_URL or SUPABASE_ANON_KEY is missing from .env');
    }
    await SupabaseService.init(url: url, anonKey: key);
  } catch (e, st) {
    AppLogger.error('Startup failed',
        name: 'startup', error: e, stackTrace: st);
    runApp(const StartupErrorApp(onRetry: _start));
    return;
  }

  runApp(const ProviderScope(child: UniversityCommunityApp()));
}

/// Shown in place of a widget that failed to build.
class _BrokenWidget extends StatelessWidget {
  const _BrokenWidget();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Something on this screen failed to load.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B6B7B))),
      );
}
