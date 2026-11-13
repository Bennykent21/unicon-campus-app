import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/state_views.dart';
import 'university.dart';

/// Curators only: review "add my university" requests and add universities.
class ManageUniversitiesScreen extends ConsumerWidget {
  const ManageUniversitiesScreen({super.key});

  Future<void> _addUniversity(BuildContext context, WidgetRef ref,
      {UniversityRequest? from}) async {
    final added = await showDialog<int>(
      context: context,
      builder: (_) => _AddUniversityDialog(from: from),
    );
    if (added == null) return;
    ref.invalidate(universitiesProvider);
    ref.invalidate(pendingUniversityRequestsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(from?.email == null
              ? 'University added'
              : 'University added. Let ${from!.email} know.')));
    }
  }

  Future<void> _decline(
      BuildContext context, WidgetRef ref, UniversityRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decline this request?'),
        content: Text('"${r.name}" will be removed from the list of requests.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Decline')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(universityActionsProvider).review(r.id);
      ref.invalidate(pendingUniversityRequestsProvider);
    } catch (e, st) {
      if (context.mounted) {
        showErrorSnack(context, e,
            action: 'decline the request', stackTrace: st);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final requests = ref.watch(pendingUniversityRequestsProvider);
    final universities = ref.watch(universitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Universities')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addUniversity(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add a university'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pendingUniversityRequestsProvider);
          ref.invalidate(universitiesProvider);
          await ref.read(pendingUniversityRequestsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Requests', style: theme.textTheme.titleMedium),
            ),
            ...requests.when(
              loading: () => [
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator())),
              ],
              error: (e, _) => [
                ErrorState(
                    error: e,
                    action: 'load requests',
                    onRetry: () =>
                        ref.invalidate(pendingUniversityRequestsProvider)),
              ],
              data: (list) => list.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Text('No requests waiting.',
                            style: theme.textTheme.bodyMedium),
                      ),
                    ]
                  : [
                      for (final r in list)
                        ListTile(
                          title: Text(r.name),
                          subtitle: Text([
                            if (r.city != null) r.city!,
                            if (r.email != null) r.email!,
                          ].join(' · ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Decline',
                                icon: const Icon(Icons.close),
                                onPressed: () => _decline(context, ref, r),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    _addUniversity(context, ref, from: r),
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        ),
                    ],
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text('Listed (${universities.valueOrNull?.length ?? '…'})',
                  style: theme.textTheme.titleMedium),
            ),
            for (final u in universities.valueOrNull ?? const <University>[])
              ListTile(
                dense: true,
                title: Text(u.name),
                subtitle: Text(
                    [u.shortName, if (u.city != null) u.city!].join(' · ')),
              ),
          ],
        ),
      ),
    );
  }
}

/// Adds a university, optionally from a request. Pops with the new id.
class _AddUniversityDialog extends ConsumerStatefulWidget {
  final UniversityRequest? from;
  const _AddUniversityDialog({this.from});

  @override
  ConsumerState<_AddUniversityDialog> createState() =>
      _AddUniversityDialogState();
}

class _AddUniversityDialogState extends ConsumerState<_AddUniversityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.from?.name ?? '');
  final _short = TextEditingController();
  late final _city = TextEditingController(text: widget.from?.city ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final actions = ref.read(universityActionsProvider);
    try {
      final id = await actions.add(
          name: _name.text, shortName: _short.text, city: _city.text);
      if (widget.from != null) {
        await actions.review(widget.from!.id, universityId: id);
      }
      if (mounted) Navigator.pop(context, id);
    } catch (e, st) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnack(context, e,
            action: 'add the university (is it already listed?)',
            stackTrace: st);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a university'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Full name', hintText: 'e.g. University of Lagos'),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Enter the full name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _short,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Short name', hintText: 'e.g. UNILAG'),
              validator: (v) => (v == null || slugFor(v).isEmpty)
                  ? 'Enter a short name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'City'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Adding…' : 'Add'),
        ),
      ],
    );
  }
}
