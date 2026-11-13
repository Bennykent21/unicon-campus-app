import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/state_views.dart';
import 'request_university_dialog.dart';
import 'university.dart';

/// Form field for choosing a university from the list. Required: a student's
/// university decides which posts they see.
class UniversityPickerField extends ConsumerWidget {
  final int? value;
  final ValueChanged<University> onChanged;

  const UniversityPickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(universitiesProvider).valueOrNull ?? const [];
    final selected = list.where((u) => u.id == value).firstOrNull;
    return FormField<int>(
      // Rebuild the field when the chosen value changes from outside.
      key: ValueKey(value),
      initialValue: value,
      validator: (v) => v == null ? 'Choose your university' : null,
      builder: (field) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await showModalBottomSheet<University>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => const _UniversitySheet(),
          );
          if (picked != null) {
            field.didChange(picked.id);
            onChanged(picked);
          }
        },
        child: InputDecorator(
          isEmpty: selected == null,
          decoration: InputDecoration(
            labelText: 'University',
            prefixIcon: const Icon(Icons.school_outlined, size: 20),
            suffixIcon: const Icon(Icons.expand_more),
            errorText: field.errorText,
          ),
          child: selected == null
              ? null
              : Text(selected.name, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _UniversitySheet extends ConsumerStatefulWidget {
  const _UniversitySheet();

  @override
  ConsumerState<_UniversitySheet> createState() => _UniversitySheetState();
}

class _UniversitySheetState extends ConsumerState<_UniversitySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(universitiesProvider);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search by name, short name or city',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorState(
                  error: e,
                  action: 'load universities',
                  onRetry: () => ref.invalidate(universitiesProvider),
                ),
                data: (list) {
                  final shown = list.where((u) => u.matches(_query)).toList();
                  if (shown.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            'No university matches "$_query" yet.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () => showRequestUniversityDialog(
                                context,
                                initialName: _query.trim()),
                            child: const Text('Ask us to add it'),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: shown.length + 1,
                    itemBuilder: (_, i) {
                      if (i == shown.length) {
                        return ListTile(
                          leading: const Icon(Icons.add_circle_outline),
                          title: const Text("Can't find your university?"),
                          subtitle: const Text('Ask us to add it'),
                          onTap: () => showRequestUniversityDialog(context,
                              initialName: _query.trim()),
                        );
                      }
                      final u = shown[i];
                      return ListTile(
                        title: Text(u.name),
                        subtitle: Text([
                          u.shortName,
                          if (u.city != null) u.city!
                        ].join(' · ')),
                        onTap: () => Navigator.pop(context, u),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
