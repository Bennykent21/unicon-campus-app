import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand violet from the app icon, also used by the Android splash screen.
const kAuthBand = Color(0xFF2B0A93);

/// Shared layout for login and signup: a violet brand band with the UNICON
/// mark, and the form on a raised sheet that overlaps it.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons over the violet band.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kAuthBand,
        body: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, topInset + 12, 24, 44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 48,
                      child: showBack
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                tooltip: 'Back',
                                color: Colors.white,
                                style: IconButton.styleFrom(
                                    padding: EdgeInsets.zero),
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.arrow_back),
                              ),
                            )
                          : null,
                    ),
                    Row(children: [
                      Image.asset('assets/images/unicon_mark.png',
                          width: 56, height: 56, semanticLabel: 'UNICON logo'),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('UNICON',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    height: 1.1)),
                            SizedBox(height: 4),
                            Text('University of Benin, in one app',
                                style: TextStyle(
                                    color: Color(0xD9FFFFFF),
                                    fontSize: 14,
                                    height: 1.3)),
                          ],
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            // The sheet fills the rest of the screen and scrolls with the form.
            SliverFillRemaining(
              hasScrollBody: false,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: EdgeInsets.fromLTRB(
                    24, 28, 24, 24 + MediaQuery.of(context).padding.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    ...children,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline error shown under a form after a failed sign in or sign up.
class AuthErrorBanner extends StatelessWidget {
  final String message;
  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final err = theme.colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: err.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: err, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: err))),
        ]),
      ),
    );
  }
}

/// Primary button that swaps its label for a spinner while busy.
class BusyButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  const BusyButton(
      {super.key,
      required this.label,
      required this.busy,
      required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: busy ? null : onPressed,
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: Theme.of(context).colorScheme.primary,
            disabledForegroundColor: Colors.white,
          ),
          child: busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white),
                )
              : Text(label, style: const TextStyle(fontSize: 15.5)),
        ),
      );
}
