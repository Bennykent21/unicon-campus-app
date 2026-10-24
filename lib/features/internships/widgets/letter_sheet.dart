import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/link_launcher.dart';
import '../../../core/widgets/state_views.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/internship.dart';
import '../providers/internship_providers.dart';
import '../utils/application_email.dart';

/// Opens the application draft for [internship]. With an email address the
/// draft opens in the phone's email app; without one it is a letter to copy,
/// print or hand in (the usual route for SIWES).
Future<void> showLetterSheet(BuildContext context, Internship internship) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _LetterSheet(internship: internship),
  );
}

class _LetterSheet extends ConsumerStatefulWidget {
  final Internship internship;
  const _LetterSheet({required this.internship});

  @override
  ConsumerState<_LetterSheet> createState() => _LetterSheetState();
}

class _LetterSheetState extends ConsumerState<_LetterSheet> {
  late final TextEditingController _subject;
  late final TextEditingController _body;
  bool _markApplied = true;
  bool _initialised = false;

  bool get _hasEmail =>
      widget.internship.applyEmail != null &&
      widget.internship.applyEmail!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _subject = TextEditingController();
    _body = TextEditingController();
    // Fill the draft once the profile is available (it may still be loading
    // the first time the sheet opens).
    ref.listenManual(myProfileProvider, (_, next) {
      if (next.hasValue && !_initialised) setState(_fillFromProfile);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _fillFromProfile() {
    if (_initialised) return;
    final profile = ref.read(myProfileProvider).valueOrNull;
    final draft = ApplicationEmail.forListing(
      widget.internship,
      studentName: profile?.fullName,
      department: profile?.department,
      level: profile?.level,
    );
    _subject.text = draft.subject;
    _body.text = draft.body;
    _initialised = true;
  }

  Future<void> _maybeMarkApplied() async {
    if (!_markApplied) return;
    try {
      await ref
          .read(internshipActionsProvider)
          .setStage(widget.internship, ApplicationStage.applied);
    } catch (e, st) {
      if (mounted) {
        showErrorSnack(context, e,
            action: 'update your tracker', stackTrace: st);
      }
    }
  }

  Future<void> _copy() async {
    final text = _hasEmail
        ? 'To: ${widget.internship.applyEmail}\nSubject: ${_subject.text}\n\n${_body.text}'
        : '${_subject.text}\n\n${_body.text}';
    await Clipboard.setData(ClipboardData(text: text));
    await _maybeMarkApplied();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_markApplied
            ? 'Copied. Marked as applied in My applications.'
            : 'Copied')));
    Navigator.pop(context);
  }

  Future<void> _openEmail() async {
    final email = ApplicationEmail(
        to: widget.internship.applyEmail!,
        subject: _subject.text,
        body: _body.text);
    final opened = await LinkLauncher.open(context, email.toMailtoUri(),
        failureMessage:
            'No email app found. Copy the text and send it from any email app.');
    if (!opened) return;
    await _maybeMarkApplied();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.internship;
    final theme = Theme.of(context);
    final p = context.palette;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scroll) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  Text(
                      _hasEmail
                          ? 'Email ${i.companyName}'
                          : 'Your application letter',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    _hasEmail
                        ? 'Edit anything you like. Your email app opens next, where you attach your documents and send.'
                        : 'Edit anything you like, then copy it into a document to print and sign, or into an email.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  if (_hasEmail) ...[
                    _Labelled(
                      label: 'To',
                      child: SelectableText(i.applyEmail!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _subject,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    maxLines: null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _body,
                    decoration: const InputDecoration(
                        labelText: 'Letter', alignLabelWithHint: true),
                    minLines: 10,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                  if (i.requirements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: p.warning.bg,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.attach_file,
                              size: 18, color: p.warning.fg),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Remember to include: ${i.requirements.join('; ')}.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _markApplied,
                    onChanged: (v) => setState(() => _markApplied = v),
                    title: const Text('Mark as applied in My applications'),
                    subtitle:
                        const Text("We'll remind you to follow up in a week."),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border:
                      Border(top: BorderSide(color: theme.dividerTheme.color!)),
                ),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy text'),
                    ),
                  ),
                  if (_hasEmail) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _openEmail,
                        icon: const Icon(Icons.mail_outline, size: 18),
                        label: const Text('Open in email app'),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  final String label;
  final Widget child;
  const _Labelled({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 64,
              child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: child),
        ],
      );
}
