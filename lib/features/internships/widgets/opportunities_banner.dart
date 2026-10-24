import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/internship_providers.dart';

/// One-line prompt on the home feed pointing at internships that fit the
/// student. Hidden while loading, on error, or when nothing is open.
class OpportunitiesBanner extends ConsumerWidget {
  const OpportunitiesBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(internshipsProvider).valueOrNull;
    if (all == null) return const SizedBox.shrink();
    final me = ref.watch(studentMatchInfoProvider);
    final today = DateTime.now();
    final mine = applyInternshipFilter(
        all, const InternshipFilter(openNowOnly: true),
        department: me.department, level: me.level, today: today);
    if (mine.isEmpty) return const SizedBox.shrink();

    final soonest = mine.where((i) => i.deadline != null).toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
    final who = (me.department ?? '').isNotEmpty ? me.department! : 'you';
    final title = mine.length == 1
        ? '1 internship you can apply to now'
        : '${mine.length} internships you can apply to now';
    final sub = soonest.isNotEmpty
        ? 'Matched to $who. Next deadline ${DateFormat('d MMM').format(soonest.first.deadline!)}.'
        : 'Matched to $who.';

    final theme = Theme.of(context);
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Material(
        color: p.brandSoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/internships'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(children: [
              Icon(Icons.work_outline, color: p.brandText),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: p.brandText)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: p.brandText),
            ]),
          ),
        ),
      ),
    );
  }
}
