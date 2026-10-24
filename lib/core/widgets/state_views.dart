import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../utils/app_logger.dart';

/// Turns any thrown error into one plain sentence a student can act on.
/// The raw error is logged, never shown.
String friendlyError(Object error, {String action = 'load this'}) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is AuthRetryableFetchException ||
      // package:http's ClientException (no direct dependency on http here).
      error.runtimeType.toString() == 'ClientException') {
    return "Couldn't $action. Check your internet connection and try again.";
  }
  if (error is PostgrestException && error.code == '42501') {
    return "You don't have permission to $action.";
  }
  if (error is AuthException) {
    return error.message;
  }
  return "Couldn't $action. Try again in a moment.";
}

/// Shows a SnackBar for a failed action and logs the underlying error.
void showErrorSnack(BuildContext context, Object error,
    {required String action, StackTrace? stackTrace}) {
  AppLogger.error('Failed to $action', error: error, stackTrace: stackTrace);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
        SnackBar(content: Text(friendlyError(error, action: action))));
}

/// Full-area error view with one recovery action. Logs the raw error once
/// per distinct error (not on every rebuild).
class ErrorState extends StatefulWidget {
  final Object error;
  final String action;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.error,
    this.action = 'load this',
    this.onRetry,
  });

  @override
  State<ErrorState> createState() => _ErrorStateState();
}

class _ErrorStateState extends State<ErrorState> {
  @override
  void initState() {
    super.initState();
    AppLogger.error('Failed to ${widget.action}', error: widget.error);
  }

  @override
  void didUpdateWidget(ErrorState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.error != widget.error) {
      AppLogger.error('Failed to ${widget.action}', error: widget.error);
    }
  }

  @override
  Widget build(BuildContext context) => _StateBody(
        icon: Icons.cloud_off_outlined,
        message: friendlyError(widget.error, action: widget.action),
        actionLabel: widget.onRetry != null ? 'Try again' : null,
        onAction: widget.onRetry,
      );
}

/// Empty view that points at one next step.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => _StateBody(
        icon: icon,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}

class _StateBody extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateBody({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.palette.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: context.palette.brandText, size: 26),
              ),
            ),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
