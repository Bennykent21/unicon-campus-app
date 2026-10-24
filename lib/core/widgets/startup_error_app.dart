import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shown if the app can't start (missing configuration or Supabase failed to
/// initialise), instead of a blank screen or crash.
class StartupErrorApp extends StatelessWidget {
  final Future<void> Function() onRetry;
  const StartupErrorApp({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/unicon_mark.png',
                        width: 72, height: 72),
                    const SizedBox(height: 20),
                    Text("UNICON couldn't start",
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      'Check your internet connection and try again. If this keeps happening, update to the latest version of the app.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: onRetry, child: const Text('Try again')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
