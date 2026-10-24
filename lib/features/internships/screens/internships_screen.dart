import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../models/internship.dart';
import '../providers/internship_providers.dart';
import '../widgets/internship_card.dart';

class InternshipsScreen extends ConsumerStatefulWidget {
  const InternshipsScreen({super.key});

  @override
  ConsumerState<InternshipsScreen> createState() => _InternshipsScreenState();
}

class _InternshipsScreenState extends ConsumerState<InternshipsScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search =
        TextEditingController(text: ref.read(internshipFilterProvider).query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _update(InternshipFilter Function(InternshipFilter) change) {
    final n = ref.read(internshipFilterProvider.notifier);
    n.state = change(n.state);
  }

  Future<void> _toggleSave(Internship i) async {
    try {
      await ref.read(internshipActionsProvider).toggleSaved(i);
    } catch (e, st) {
      if (mounted) {
        showErrorSnack(context, e, action: 'save this listing', stackTrace: st);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(internshipFilterProvider);
    final listAsync = ref.watch(filteredInternshipsProvider);
    final me = ref.watch(studentMatchInfoProvider);
    final overlay = ref.watch(stageOverlayProvider);
    final theme = Theme.of(context);

    final matchLabel = [me.department, me.level]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Internships'),
        actions: [
          IconButton(
            tooltip: 'My applications',
            icon: const Icon(Icons.checklist_rtl),
            onPressed: () => context.push('/applications'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(stageOverlayProvider.notifier).state = {};
          ref.invalidate(internshipsProvider);
          await ref.read(internshipsProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onChanged: (v) => _update((f) => f.copyWith(query: v)),
                      decoration: InputDecoration(
                        hintText: 'Role, company or city',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: filter.query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  _update((f) => f.copyWith(query: ''));
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: true, label: Text('Matches you')),
                        ButtonSegment(
                            value: false, label: Text('All listings')),
                      ],
                      selected: {filter.matchesOnly},
                      onSelectionChanged: (s) =>
                          _update((f) => f.copyWith(matchesOnly: s.first)),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  children: [
                    _chip('Open now', filter.openNowOnly,
                        (v) => _update((f) => f.copyWith(openNowOnly: v))),
                    for (final k in InternshipKind.values)
                      _chip(k.label, filter.kinds.contains(k), (v) {
                        final next = Set<InternshipKind>.from(filter.kinds);
                        v ? next.add(k) : next.remove(k);
                        _update((f) => f.copyWith(kinds: next));
                      }),
                    _chip('Benin City and Edo', filter.edoOnly,
                        (v) => _update((f) => f.copyWith(edoOnly: v))),
                    _chip('Remote', filter.remoteOnly,
                        (v) => _update((f) => f.copyWith(remoteOnly: v))),
                    _chip('Paid', filter.paidOnly,
                        (v) => _update((f) => f.copyWith(paidOnly: v))),
                  ],
                ),
              ),
            ),
            ...listAsync.when(
              loading: () => [
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    error: e,
                    action: 'load internships',
                    onRetry: () => ref.invalidate(internshipsProvider),
                  ),
                ),
              ],
              data: (list) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Text(
                      _countLine(list.length, filter, matchLabel),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
                if (list.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: filter.hasExtraFilters
                        ? EmptyState(
                            icon: Icons.filter_alt_off_outlined,
                            message: 'No listings match these filters.',
                            actionLabel: 'Clear filters',
                            onAction: () {
                              _search.clear();
                              _update((f) => f.cleared());
                            },
                          )
                        : EmptyState(
                            icon: Icons.work_outline,
                            message: filter.matchesOnly
                                ? 'No listings match your department yet.'
                                : 'No internships have been listed yet.',
                            actionLabel:
                                filter.matchesOnly ? 'See all listings' : null,
                            onAction: filter.matchesOnly
                                ? () => _update(
                                    (f) => f.copyWith(matchesOnly: false))
                                : null,
                          ),
                  )
                else
                  SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: theme.dividerTheme.color),
                    itemBuilder: (context, idx) {
                      final i = list[idx];
                      final stage =
                          overlay.containsKey(i.id) ? overlay[i.id] : i.myStage;
                      return InternshipCard(
                        internship: i,
                        stage: stage,
                        onTap: () => context.push('/internships/${i.id}'),
                        onToggleSave: () => _toggleSave(i),
                      );
                    },
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Text(
                      'Listings are gathered from company career pages and public opportunity sites. Always confirm details with the company and your department\'s SIWES coordinator. A company will never ask you to pay to apply.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _FilterPill(
            label: label,
            selected: selected,
            onTap: () => onChanged(!selected)),
      );

  String _countLine(int n, InternshipFilter f, String matchLabel) {
    final noun = n == 1 ? '1 listing' : '$n listings';
    if (f.matchesOnly && matchLabel.isNotEmpty) return '$noun for $matchLabel';
    if (f.matchesOnly) {
      return '$noun. Add your department and level to your profile for better matches.';
    }
    return noun;
  }
}

/// Toggle pill for the filter row. A plain widget rather than FilterChip,
/// whose label was clipped with this theme's fonts on web.
class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : theme.dividerTheme.color!),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (selected) ...[
                  const Icon(Icons.check, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : theme.colorScheme.onSurface)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
