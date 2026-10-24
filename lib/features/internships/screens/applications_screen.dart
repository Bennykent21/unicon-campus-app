import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/link_launcher.dart';
import '../../../core/widgets/state_views.dart';
import '../models/internship.dart';
import '../providers/internship_providers.dart';
import '../widgets/internship_card.dart';

/// The student's private tracker: Saved -> Applied -> Interview -> Offer.
class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen> {
  ApplicationStage _stage = ApplicationStage.applied;
  bool _pickedStage = false;

  static const _pipeline = [
    ApplicationStage.saved,
    ApplicationStage.applied,
    ApplicationStage.interview,
    ApplicationStage.offer,
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myApplicationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My applications')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myApplicationsProvider);
          await ref.read(myApplicationsProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            error: e,
            action: 'load your applications',
            onRetry: () => ref.invalidate(myApplicationsProvider),
          ),
          data: (apps) {
            if (apps.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.checklist_rtl,
                  message:
                      'Save listings you like and track each one from saved to offer.',
                  actionLabel: 'Browse internships',
                  onAction: () => context.push('/internships'),
                ),
              ]);
            }

            final counts = {
              for (final s in ApplicationStage.values)
                s: apps.where((a) => a.stage == s).length,
            };
            // Until the student picks a stage, open on the first one that
            // has something in it.
            final stage = !_pickedStage && (counts[_stage] ?? 0) == 0
                ? _pipeline.firstWhere((s) => (counts[s] ?? 0) > 0,
                    orElse: () => ApplicationStage.declined)
                : _stage;
            final visible = apps.where((a) => a.stage == stage).toList();
            final today = DateTime.now();
            final followUps = apps.where((a) => a.needsFollowUp(today)).length;

            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(children: [
                    for (final s in _pipeline)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _StageTile(
                            stage: s,
                            count: counts[s] ?? 0,
                            selected: stage == s,
                            onTap: () => setState(() {
                              _stage = s;
                              _pickedStage = true;
                            }),
                          ),
                        ),
                      ),
                  ]),
                ),
                if (followUps > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      followUps == 1
                          ? '1 application is due a follow-up.'
                          : '$followUps applications are due a follow-up.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.palette.warning.fg,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                if ((counts[ApplicationStage.declined] ?? 0) > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: TextButton(
                        onPressed: () => setState(() {
                          _stage = ApplicationStage.declined;
                          _pickedStage = true;
                        }),
                        child: Text(
                            'Not this time (${counts[ApplicationStage.declined]})'),
                      ),
                    ),
                  ),
                Divider(height: 1, color: theme.dividerTheme.color),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      message: 'Nothing in ${stage.label} yet.',
                    ),
                  )
                else
                  for (final a in visible) ...[
                    _ApplicationTile(app: a),
                    Divider(height: 1, color: theme.dividerTheme.color),
                  ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(children: [
                    Icon(Icons.lock_outline,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text('Only you can see this list.',
                        style: theme.textTheme.bodySmall),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  final ApplicationStage stage;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _StageTile(
      {required this.stage,
      required this.count,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? p.brandText : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: '${stage.label}, $count',
      excludeSemantics: true,
      child: Material(
        color: selected ? p.brandSoft : p.neutral.bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$count',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
                Text(stage.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplicationTile extends ConsumerWidget {
  final TrackedApplication app;
  const _ApplicationTile({required this.app});

  Future<void> _move(BuildContext context, WidgetRef ref, ApplicationStage? s,
      {DateTime? interviewAt}) async {
    try {
      await ref
          .read(internshipActionsProvider)
          .setStage(app.internship, s, interviewAt: interviewAt);
    } catch (e, st) {
      if (context.mounted) {
        showErrorSnack(context, e,
            action: 'update your tracker', stackTrace: st);
      }
    }
  }

  Future<void> _addInterview(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 3)),
      helpText: 'Interview date',
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
        helpText: 'Interview time');
    if (!context.mounted) return;
    final at = DateTime(
        date.year, date.month, date.day, time?.hour ?? 10, time?.minute ?? 0);
    await _move(context, ref, ApplicationStage.interview, interviewAt: at);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = app.internship;
    final theme = Theme.of(context);
    final p = context.palette;
    final today = DateTime.now();
    final df = DateFormat('d MMM');

    final Widget? nudge = switch (app.stage) {
      ApplicationStage.applied when app.needsFollowUp(today) => _Nudge(
          colors: p.warning,
          text: app.appliedOn != null
              ? 'Follow up today. You applied on ${df.format(app.appliedOn!)}.'
              : 'Follow up today.',
          action: i.applyPhone != null
              ? ('Call', () => LinkLauncher.phone(context, i.applyPhone!))
              : (
                  'Done',
                  () => ref.read(internshipActionsProvider).snoozeFollowUp(i)
                ),
        ),
      ApplicationStage.applied => _Nudge(
          colors: p.neutral,
          text: app.followUpOn != null
              ? 'Waiting for a reply. Follow up on ${df.format(app.followUpOn!)}.'
              : 'Waiting for a reply.',
        ),
      ApplicationStage.interview => _Nudge(
          colors: p.positive,
          text: app.interviewAt != null
              ? 'Interview ${DateFormat('EEE d MMM, h:mm a').format(app.interviewAt!)}.'
              : 'Interview stage. Add the date so you have it to hand.',
          action: app.interviewAt == null
              ? ('Add date', () => _addInterview(context, ref))
              : null,
        ),
      ApplicationStage.saved => i.isActionableOn(today)
          ? _Nudge(
              colors: p.neutral,
              text: i.deadlineLabel(today).text,
            )
          : _Nudge(
              colors: p.neutral,
              text: i.opensNote ?? 'Not open right now.',
            ),
      _ => null,
    };

    final next = switch (app.stage) {
      ApplicationStage.saved => ApplicationStage.applied,
      ApplicationStage.applied => ApplicationStage.interview,
      ApplicationStage.interview => ApplicationStage.offer,
      _ => null,
    };

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () => context.push('/internships/${i.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CompanyLogo(internship: i, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.title, style: theme.textTheme.titleSmall),
                      Text(i.companyName, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Move to another stage',
                  onSelected: (v) {
                    // 'remove' is a sentinel: a null item value would count
                    // as "menu dismissed" and never reach onSelected.
                    final s = v == 'remove' ? null : ApplicationStage.parse(v);
                    if (s == ApplicationStage.interview) {
                      _addInterview(context, ref);
                    } else {
                      _move(context, ref, s);
                    }
                  },
                  itemBuilder: (_) => [
                    for (final s in ApplicationStage.values)
                      if (s != app.stage)
                        PopupMenuItem(
                            value: s.value, child: Text('Move to ${s.label}')),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('Stop tracking',
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ],
                ),
              ]),
              if (nudge != null) ...[
                const SizedBox(height: 10),
                Padding(
                    padding: const EdgeInsets.only(right: 12), child: nudge),
              ],
              if (next != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton(
                    onPressed: () => next == ApplicationStage.interview
                        ? _addInterview(context, ref)
                        : _move(context, ref, next),
                    child: Text('Move to ${next.label}'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Nudge extends StatelessWidget {
  final TagColors colors;
  final String text;
  final (String, VoidCallback)? action;
  const _Nudge({required this.colors, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
            color: colors.bg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13)),
          ),
          if (action != null)
            TextButton(onPressed: action!.$2, child: Text(action!.$1)),
        ]),
      );
}
