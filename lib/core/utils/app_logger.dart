import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Lightweight app-wide logger.
///
/// In debug builds, logs go to the console via `dart:developer` so they show
/// up in DevTools / `flutter run` output. In release builds, `error()` still
/// records via `developer.log` (which is a no-op sink unless a listener is
/// attached), keeping the app silent for end users while remaining easy to
/// wire up to a crash-reporting service (e.g. Sentry) later in one place.
class AppLogger {
  AppLogger._();

  static void info(String message, {String name = 'app'}) {
    if (kDebugMode) {
      developer.log(message, name: name, level: 800);
    }
  }

  static void warning(String message, {String name = 'app'}) {
    if (kDebugMode) {
      developer.log(message, name: name, level: 900);
    }
  }

  static void error(
    String message, {
    String name = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
