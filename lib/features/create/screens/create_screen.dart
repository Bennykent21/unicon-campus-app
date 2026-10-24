import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final options = <_Option>[
      _Option(Icons.help_outline, p.question, 'Ask a question',
          'Get help from other students', 'question'),
      _Option(Icons.edit_note, TagColors(p.brandText, p.brandSoft),
          'Write a post', 'Share an update or start a discussion', 'general'),
      _Option(Icons.sell_outlined, p.marketplace, 'Sell an item',
          'List something for other students', 'marketplace'),
      _Option(Icons.work_outline, p.job, 'Post a job or gig',
          'Part-time work or a small project', 'job'),
      _Option(Icons.event_outlined, p.event, 'Create an event',
          'A meetup, talk or party', 'event'),
      _Option(Icons.campaign_outlined, p.announcement, 'Share an announcement',
          'Notices everyone should see', 'announcement'),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => context.pop()),
        title: const Text('Create'),
      ),
      body: LayoutBuilder(builder: (context, c) {
        final columns = c.maxWidth > 560 ? 3 : 2;
        return GridView.count(
          crossAxisCount: columns,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // Taller tiles when the student uses larger text, so nothing clips.
          childAspectRatio:
              0.98 / MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8),
          children: [
            for (final o in options)
              _OptionTile(
                  option: o, onTap: () => context.push('/compose/${o.type}')),
          ],
        );
      }),
    );
  }
}

class _Option {
  final IconData icon;
  final TagColors colors;
  final String title;
  final String subtitle;
  final String type;
  const _Option(this.icon, this.colors, this.title, this.subtitle, this.type);
}

class _OptionTile extends StatelessWidget {
  final _Option option;
  final VoidCallback onTap;
  const _OptionTile({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerTheme.color!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: option.colors.bg,
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(option.icon, color: option.colors.fg, size: 26),
              ),
              const Spacer(),
              Text(option.title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(option.subtitle,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
