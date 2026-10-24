import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/internship.dart';

/// Square company tile: logo when there is one, otherwise initials on a
/// color picked from the company name (stable across rebuilds).
class CompanyLogo extends StatelessWidget {
  final Internship internship;
  final double size;
  const CompanyLogo({super.key, required this.internship, this.size = 44});

  static const _tiles = [
    Color(0xFF1F4B99),
    Color(0xFF0F7B4F),
    Color(0xFF8A3B12),
    Color(0xFF5B3FD6),
    Color(0xFF9F1239),
    Color(0xFF115E59),
  ];

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.26);
    final url = internship.companyLogoUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
            imageUrl: url, width: size, height: size, fit: BoxFit.cover),
      );
    }
    final color = _tiles[
        internship.companyName.codeUnits.fold<int>(0, (a, b) => a + b) %
            _tiles.length];
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: radius),
        child: Text(internship.initials,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.32)),
      ),
    );
  }
}

/// "Closes 15 Nov" / "Closes in 3 days" / "Write to apply" pill.
class DeadlinePill extends StatelessWidget {
  final Internship internship;
  const DeadlinePill({super.key, required this.internship});

  @override
  Widget build(BuildContext context) {
    final label = internship.deadlineLabel(DateTime.now());
    final p = context.palette;
    final colors = switch (label.tone) {
      DeadlineTone.positive => p.positive,
      DeadlineTone.warning => p.warning,
      DeadlineTone.neutral => p.neutral,
    };
    final icon = switch (label.tone) {
      DeadlineTone.warning => Icons.schedule,
      DeadlineTone.positive => Icons.event_available_outlined,
      DeadlineTone.neutral => Icons.event_busy_outlined,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: colors.bg, borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: colors.fg),
        const SizedBox(width: 4),
        Text(label.text,
            style: TextStyle(
                color: colors.fg, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Small neutral fact chip ("6 months", "Remote").
class FactChip extends StatelessWidget {
  final String text;
  const FactChip(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: p.neutral.bg, borderRadius: BorderRadius.circular(7)),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface)),
    );
  }
}

class InternshipCard extends StatelessWidget {
  final Internship internship;
  final ApplicationStage? stage;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  const InternshipCard({
    super.key,
    required this.internship,
    required this.stage,
    required this.onTap,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final i = internship;
    final theme = Theme.of(context);
    final p = context.palette;
    final muted = theme.colorScheme.onSurfaceVariant;
    // Remote listings already say 'Remote' in their facts.
    final where = i.workMode == 'remote' ? null : (i.location ?? i.companyCity);
    final facts = <String>[
      i.kind.label,
      if (i.duration != null && i.duration!.isNotEmpty) i.duration!,
      if (i.workMode != 'onsite') i.workModeLabel,
      if (i.stipend != null && i.stipend!.isNotEmpty) i.stipend!,
    ];
    final tracked = stage != null;

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompanyLogo(internship: i),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontSize: 15, height: 1.3)),
                        const SizedBox(height: 2),
                        Text(
                          where != null && where.isNotEmpty
                              ? '${i.companyName}, $where'
                              : i.companyName,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleSave,
                    tooltip: tracked
                        ? (stage == ApplicationStage.saved
                            ? 'Remove from saved'
                            : 'Tracked as ${stage!.label}')
                        : 'Save',
                    icon: Icon(tracked ? Icons.bookmark : Icons.bookmark_border,
                        color: tracked ? p.brandText : muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final f in facts) FactChip(f)],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DeadlinePill(internship: i),
                    if (tracked && stage != ApplicationStage.saved)
                      Text(stage!.label,
                          style: TextStyle(
                              color: p.brandText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    if (i.alumniCount > 0)
                      _ProofLine(
                          icon: Icons.school_outlined,
                          text: i.alumniCount == 1
                              ? '1 UNIBEN student trained here'
                              : '${i.alumniCount} UNIBEN students trained here')
                    else if (i.unibenNote != null && i.unibenNote!.isNotEmpty)
                      _ProofLine(icon: Icons.info_outline, text: i.unibenNote!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProofLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProofLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: muted),
      const SizedBox(width: 4),
      Flexible(
        child: Text(text,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}
