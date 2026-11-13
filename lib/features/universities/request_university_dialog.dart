import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/state_views.dart';
import 'university.dart';

/// Asks to add a university that isn't in the list. Shows a thank-you
/// snackbar and returns true once the request is sent.
Future<bool> showRequestUniversityDialog(BuildContext context,
    {String initialName = ''}) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _RequestUniversityDialog(initialName: initialName),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Thanks. We will add your university and email you when it is ready.')));
  }
  return sent == true;
}

class _RequestUniversityDialog extends ConsumerStatefulWidget {
  final String initialName;
  const _RequestUniversityDialog({required this.initialName});

  @override
  ConsumerState<_RequestUniversityDialog> createState() =>
      _RequestUniversityDialogState();
}

class _RequestUniversityDialogState
    extends ConsumerState<_RequestUniversityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  final _city = TextEditingController();
  final _email = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(universityActionsProvider)
          .request(name: _name.text, city: _city.text, email: _email.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e, st) {
      if (mounted) {
        setState(() => _sending = false);
        showErrorSnack(context, e, action: 'send your request', stackTrace: st);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add my university'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: widget.initialName.isEmpty,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'University name'),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Enter the full name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'City (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  helperText: 'So we can tell you when it is added'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                    ? null
                    : 'Check the email address';
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Sending…' : 'Send request'),
        ),
      ],
    );
  }
}
