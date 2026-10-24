import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../internships/providers/internship_providers.dart';
import '../discover_categories.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              readOnly: true,
              onTap: () => context.push('/feed-search'),
              decoration: const InputDecoration(
                hintText: 'Search posts, items, events',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          const _InternshipsFeature(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Semantics(
              header: true,
              child: Text('Browse', style: theme.textTheme.titleMedium),
            ),
          ),
          Divider(height: 1, color: theme.dividerTheme.color),
          for (final cat in DiscoverCategory.all) ...[
            _CategoryTile(category: cat),
            Divider(height: 1, color: theme.dividerTheme.color),
          ],
        ],
      ),
    );
  }
}

/// Lead card: how many internships fit the student right now and the
/// nearest deadline.
class _InternshipsFeature extends ConsumerWidget {
  const _InternshipsFeature();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(internshipsProvider).valueOrNull;
    final me = ref.watch(studentMatchInfoProvider);
    final today = DateTime.now();

    String line =
        'SIWES placements, internships, graduate schemes and remote programmes.';
    String? next;
    if (all != null) {
      final open = applyInternshipFilter(
          all, const InternshipFilter(matchesOnly: false, openNowOnly: true),
          today: today);
      final mine = applyInternshipFilter(
          all, const InternshipFilter(matchesOnly: true, openNowOnly: true),
          department: me.department, level: me.level, today: today);
      final who = (me.department ?? '').isNotEmpty ? me.department! : 'you';
      line = '${open.length} you can apply to now. ${mine.length} match $who.';
      final soonest = open.where((i) => i.deadline != null).toList()
        ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
      if (soonest.isNotEmpty) {
        final s = soonest.first;
        next =
            'Next deadline: ${s.companyName}, ${DateFormat('d MMM').format(s.deadline!)}';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/internships'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Internships and SIWES',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(line,
                    style: const TextStyle(
                        color: Color(0xF2FFFFFF), fontSize: 14, height: 1.35)),
                const SizedBox(height: 12),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('See internships',
                        style: TextStyle(
                            color: Color(0xFF3B2A9E),
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5)),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'My applications',
                    onPressed: () => context.push('/applications'),
                    icon: const Icon(Icons.checklist_rtl, color: Colors.white),
                  ),
                ]),
                if (next != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.schedule,
                        size: 15, color: Color(0xE6FFFFFF)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(next,
                          style: const TextStyle(
                              color: Color(0xE6FFFFFF), fontSize: 12.5)),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final DiscoverCategory category;
  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = category.colors(context);
    return Material(
      color: theme.colorScheme.surface,
      child: ListTile(
        enabled: !category.comingSoon,
        minVerticalPadding: 12,
        onTap: category.comingSoon
            ? null
            : () => context.push('/discover/${category.key}'),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: colors.bg, borderRadius: BorderRadius.circular(11)),
          child: Icon(category.icon, color: colors.fg, size: 22),
        ),
        title: Text(category.label,
            style: theme.textTheme.titleSmall?.copyWith(
                color: category.comingSoon
                    ? theme.colorScheme.onSurfaceVariant
                    : null)),
        subtitle: Text(category.subtitle, style: theme.textTheme.bodySmall),
        trailing: category.comingSoon
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: context.palette.neutral.bg,
                    borderRadius: BorderRadius.circular(6)),
                child: Text('Soon',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.palette.neutral.fg)),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
