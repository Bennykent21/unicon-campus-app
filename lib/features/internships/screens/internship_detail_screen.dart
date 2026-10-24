import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/link_launcher.dart';
import '../../../core/utils/share_links.dart';
import '../../../core/widgets/state_views.dart';
import '../data/internship_repository.dart';
import '../models/internship.dart';
import '../providers/internship_providers.dart';
import '../utils/field_matcher.dart';
import '../widgets/internship_card.dart';
import '../widgets/letter_sheet.dart';

class InternshipDetailScreen extends ConsumerWidget {
  final String internshipId;
  const InternshipDetailScreen({super.key, required this.internshipId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(internshipByIdProvider(internshipId));
    return async.when(
      loading: () => Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          error: e,
          action: 'load this listing',
          onRetry: () => ref.invalidate(internshipByIdProvider(internshipId)),
        ),
      ),
      data: (i) => i == null
          ? Scaffold(
              appBar: AppBar(),
              body: EmptyState(
                icon: Icons.work_off_outlined,
                message: 'This listing was removed or is no longer available.',
                actionLabel: 'Back to internships',
                onAction: () => context.go('/internships'),
              ),
            )
          : _DetailView(internship: i),
    );
  }
}

class _DetailView extends ConsumerWidget {
  final Internship internship;
  const _DetailView({required this.internship});

  Future<void> _setStage(
      BuildContext context, WidgetRef ref, ApplicationStage? stage) async {
    try {
      await ref.read(internshipActionsProvider).setStage(internship, stage);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(stage == null
                  ? 'Removed from My applications'
                  : 'Moved to ${stage.label}')));
      }
    } catch (e, st) {
      if (context.mounted) {
        showErrorSnack(context, e,
            action: 'update your tracker', stackTrace: st);
      }
    }
  }

  Future<void> _openWebsite(BuildContext context, WidgetRef ref) async {
    final opened = await LinkLauncher.web(context, internship.applyUrl!);
    if (!opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      content: const Text('Applied on the website?'),
      action: SnackBarAction(
        label: 'Mark as applied',
        onPressed: () => _setStage(context, ref, ApplicationStage.applied),
      ),
    ));
  }

  void _pickStage(
      BuildContext context, WidgetRef ref, ApplicationStage? current) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Track this listing',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final s in ApplicationStage.values)
              ListTile(
                leading: Icon(current == s
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                title: Text(s.label),
                onTap: () {
                  Navigator.pop(ctx);
                  _setStage(context, ref, s);
                },
              ),
            if (current != null)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(ctx).colorScheme.error),
                title: Text('Stop tracking',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _setStage(context, ref, null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = internship;
    final theme = Theme.of(context);
    final p = context.palette;
    final overlay = ref.watch(stageOverlayProvider);
    final stage = overlay.containsKey(i.id) ? overlay[i.id] : i.myStage;
    final me = ref.watch(studentMatchInfoProvider);
    final today = DateTime.now();
    final actionable = i.isActionableOn(today);
    final hasEmail = i.applyEmail != null && i.applyEmail!.isNotEmpty;
    final hasUrl = i.applyUrl != null && i.applyUrl!.isNotEmpty;
    final matchesField =
        FieldMatcher.matchesDepartment(i.fields, me.department) &&
            FieldMatcher.matchesLevel(i.levels, me.level);
    final knowsStudent = (me.department ?? '').isNotEmpty;

    // One primary action, chosen by how this listing is applied to.
    final ({String label, IconData icon, VoidCallback onTap}) primary;
    if (!actionable) {
      primary = stage == null
          ? (
              label: 'Save for later',
              icon: Icons.bookmark_border,
              onTap: () => _setStage(context, ref, ApplicationStage.saved)
            )
          : (
              label: 'Saved: ${stage.label}',
              icon: Icons.bookmark,
              onTap: () => _pickStage(context, ref, stage)
            );
    } else if (hasEmail) {
      primary = (
        label: 'Email the company',
        icon: Icons.mail_outline,
        onTap: () => showLetterSheet(context, i)
      );
    } else if (hasUrl && i.status != ListingStatus.contact) {
      primary = (
        label: 'Apply on website',
        icon: Icons.open_in_new,
        onTap: () => _openWebsite(context, ref)
      );
    } else {
      primary = (
        label: 'Write my letter',
        icon: Icons.edit_note,
        onTap: () => showLetterSheet(context, i)
      );
    }

    final facts = <(String, String)>[
      ('Type', i.kind.label),
      if (i.duration != null && i.duration!.isNotEmpty) ('Length', i.duration!),
      ('Mode', i.workModeLabel),
      if (i.stipend != null && i.stipend!.isNotEmpty) ('Pay', i.stipend!),
      if (i.deadline != null)
        ('Closes', DateFormat('d MMM yyyy').format(i.deadline!)),
    ];

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Copy link',
            icon: const Icon(Icons.link),
            onPressed: () =>
                ShareLinks.copy(context, ShareLinks.internship(i.id)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompanyLogo(internship: i, size: 56),
                const SizedBox(height: 12),
                Text(i.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  [i.companyName, i.companyIndustry]
                      .whereType<String>()
                      .join('. '),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if ((i.location ?? i.companyCity) != null) ...[
                  const SizedBox(height: 2),
                  Text(i.location ?? i.companyCity!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  DeadlinePill(internship: i),
                  if (stage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: p.brandSoft,
                          borderRadius: BorderRadius.circular(7)),
                      child: Text('In My applications: ${stage.label}',
                          style: TextStyle(
                              color: p.brandText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                ]),
                if (i.opensNote != null && i.opensNote!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _Note(
                    icon: actionable ? Icons.info_outline : Icons.event_repeat,
                    colors: actionable ? p.neutral : p.warning,
                    text: i.opensNote!,
                  ),
                ],
                if (i.unibenNote != null && i.unibenNote!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _Note(
                      icon: Icons.school_outlined,
                      colors: p.positive,
                      text: i.unibenNote!),
                ],
              ],
            ),
          ),
          _FactsGrid(facts: facts),
          if (i.summary.isNotEmpty)
            _Section(
              title: 'About',
              child: Text(i.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
            ),
          _Section(
            title: 'Who can apply',
            trailing: knowsStudent
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: matchesField ? p.positive.bg : p.neutral.bg,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                        matchesField ? 'You match' : 'Check eligibility',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                matchesField ? p.positive.fg : p.neutral.fg)),
                  )
                : null,
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              if (i.fields.isEmpty)
                const FactChip('Any field of study')
              else
                for (final f in i.fields) FactChip(FieldMatcher.labels[f] ?? f),
              if (i.levels.isEmpty)
                const FactChip('Any level')
              else
                FactChip(i.levels.length == 1
                    ? i.levels.first
                    : '${i.levels.first} to ${i.levels.last}'),
            ]),
          ),
          if (i.requirements.isNotEmpty)
            _Section(
              title: 'What you need',
              child: Column(children: [
                for (final r in i.requirements)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 18, color: p.brandText),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(r, style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                  ),
              ]),
            ),
          if (i.howToApply.isNotEmpty)
            _Section(
              title: 'How to apply',
              child: Column(children: [
                for (var n = 0; n < i.howToApply.length; n++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: p.brandSoft, shape: BoxShape.circle),
                          child: Text('${n + 1}',
                              style: TextStyle(
                                  color: p.brandText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(i.howToApply[n],
                                style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                  ),
              ]),
            ),
          _ContactSection(internship: i),
          _AlumniSection(internship: i),
          if (i.sourceUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: i.lastChecked != null
                          ? 'Information checked ${DateFormat('d MMM yyyy').format(i.lastChecked!)} from '
                          : 'Information from '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: InkWell(
                      onTap: () => LinkLauncher.web(context, i.sourceUrl!),
                      child: Text(Uri.parse(i.sourceUrl!).host,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: p.brandText,
                              decoration: TextDecoration.underline)),
                    ),
                  ),
                  const TextSpan(
                      text:
                          '. Confirm with the company before you apply. A real employer never asks you to pay.'),
                ]),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.dividerTheme.color!)),
          ),
          child: Row(children: [
            if (actionable)
              OutlinedButton.icon(
                onPressed: () => _pickStage(context, ref, stage),
                icon: Icon(
                    stage == null ? Icons.bookmark_border : Icons.bookmark,
                    size: 18,
                    color: stage == null ? null : p.brandText),
                label: Text(stage == null ? 'Track' : stage.label),
              ),
            if (actionable) const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: primary.onTap,
                icon: Icon(primary.icon, size: 18),
                label: Text(primary.label, overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final TagColors colors;
  final String text;
  const _Note({required this.icon, required this.colors, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: colors.bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: colors.fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface)),
            ),
          ],
        ),
      );
}

class _FactsGrid extends StatelessWidget {
  final List<(String, String)> facts;
  const _FactsGrid({required this.facts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = theme.dividerTheme.color!;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.symmetric(horizontal: BorderSide(color: line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          for (final (label, value) in facts)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 90, maxWidth: 220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(value,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerTheme.color!)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 10),
          child,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final Internship internship;
  const _ContactSection({required this.internship});

  @override
  Widget build(BuildContext context) {
    final i = internship;
    final rows = <Widget>[
      if (i.contactName != null && i.contactName!.isNotEmpty)
        _ContactRow(icon: Icons.person_outline, text: i.contactName!),
      if (i.applyEmail != null && i.applyEmail!.isNotEmpty)
        _ContactRow(
            icon: Icons.mail_outline,
            text: i.applyEmail!,
            selectable: true,
            onTap: () => showLetterSheet(context, i),
            tooltip: 'Write an email'),
      if (i.applyPhone != null && i.applyPhone!.isNotEmpty)
        _ContactRow(
            icon: Icons.call_outlined,
            text: i.applyPhone!,
            selectable: true,
            onTap: () => LinkLauncher.phone(context, i.applyPhone!),
            tooltip: 'Call'),
      if (i.companyAddress != null && i.companyAddress!.isNotEmpty)
        _ContactRow(
            icon: Icons.location_on_outlined,
            text: i.companyAddress!,
            selectable: true),
      if (i.applyUrl != null && i.applyUrl!.isNotEmpty)
        _ContactRow(
            icon: Icons.open_in_new,
            text: 'Application page',
            onTap: () => LinkLauncher.web(context, i.applyUrl!),
            tooltip: 'Open application page'),
      if (i.companyWebsite != null &&
          i.companyWebsite!.isNotEmpty &&
          i.companyWebsite != i.applyUrl)
        _ContactRow(
            icon: Icons.language,
            text: 'Company website',
            onTap: () => LinkLauncher.web(context, i.companyWebsite!),
            tooltip: 'Open company website'),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Section(title: 'Contact and links', child: Column(children: rows));
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool selectable;
  final VoidCallback? onTap;
  final String? tooltip;
  const _ContactRow(
      {required this.icon,
      required this.text,
      this.selectable = false,
      this.onTap,
      this.tooltip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;
    final style = theme.textTheme.bodyMedium?.copyWith(
        color: onTap != null ? p.brandText : null,
        fontWeight: onTap != null ? FontWeight.w600 : null);
    final label = selectable
        ? SelectableText(text, style: style, onTap: onTap)
        : Text(text, style: style);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(child: label),
      ]),
    );
    if (onTap == null || selectable) return row;
    return Semantics(
      button: true,
      label: tooltip ?? text,
      excludeSemantics: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _AlumniSection extends ConsumerWidget {
  final Internship internship;
  const _AlumniSection({required this.internship});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companyAlumniProvider(internship.companyId));
    final theme = Theme.of(context);
    final myId = SupabaseService.currentUserId;

    Future<void> toggle(bool trained) async {
      try {
        await ref
            .read(internshipActionsProvider)
            .setTrainedHere(internship, trained);
      } catch (e, st) {
        if (context.mounted) {
          showErrorSnack(context, e, action: 'update this', stackTrace: st);
        }
      }
    }

    return _Section(
      title: 'UNIBEN students who trained here',
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Text(friendlyError(e, action: 'load this list'),
            style: theme.textTheme.bodySmall),
        data: (alumni) {
          final iTrained = alumni.any((a) => a.userId == myId);
          final others = alumni.where((a) => a.userId != myId).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (others.isEmpty)
                Text(
                  iTrained
                      ? 'You are the first UNIBEN student listed here.'
                      : 'No one has added themselves yet. Trained here? Add yourself so others can ask you about it.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else
                for (final a in others) _AlumnusTile(alumnus: a),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => toggle(!iTrained),
                icon: Icon(iTrained ? Icons.check : Icons.add, size: 18),
                label: Text(
                    iTrained ? 'You trained here. Remove' : 'I trained here'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AlumnusTile extends StatelessWidget {
  final CompanyAlumnus alumnus;
  const _AlumnusTile({required this.alumnus});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final a = alumnus;
    final sub = [a.department, a.level, '${a.year}']
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(', ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: p.brandSoft,
        backgroundImage:
            a.avatarUrl != null ? NetworkImage(a.avatarUrl!) : null,
        child: a.avatarUrl == null
            ? Text(a.name.isNotEmpty ? a.name[0] : '?',
                style:
                    TextStyle(color: p.brandText, fontWeight: FontWeight.bold))
            : null,
      ),
      title: Text(a.name),
      subtitle: Text(sub),
      trailing: OutlinedButton(
        onPressed: () => context.push('/user/${a.userId}'),
        child: const Text('Ask them'),
      ),
    );
  }
}
