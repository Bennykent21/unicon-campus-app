import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: () => context.pop()),
        title: const Text('What would you like to do?',
            style: TextStyle(fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CreateOption(
            icon: Icons.edit_note,
            color: AppColors.primary,
            title: 'Create Post',
            subtitle: 'Share an update or start a discussion',
            onTap: () => context.push('/compose/general'),
          ),
          const SizedBox(height: 12),
          _CreateOption(
            icon: Icons.help_outline,
            color: const Color(0xFF3B82F6),
            title: 'Ask Question',
            subtitle: 'Get help from the community',
            onTap: () => context.push('/compose/question'),
          ),
          const SizedBox(height: 12),
          _CreateOption(
            icon: Icons.sell_outlined,
            color: AppColors.marketplace,
            title: 'List Item',
            subtitle: 'Sell something to other students',
            onTap: () => context.push('/compose/marketplace'),
          ),
          const SizedBox(height: 12),
          _CreateOption(
            icon: Icons.work_outline,
            color: AppColors.job,
            title: 'Post Job',
            subtitle: 'Post a job or internship opportunity',
            onTap: () => context.push('/compose/job'),
          ),
          const SizedBox(height: 12),
          _CreateOption(
            icon: Icons.event_outlined,
            color: AppColors.event,
            title: 'Create Event',
            subtitle: 'Organize an event or meetup',
            onTap: () => context.push('/compose/event'),
          ),
          const SizedBox(height: 12),
          _CreateOption(
            icon: Icons.campaign_outlined,
            color: const Color(0xFFA855F7),
            title: 'Share Announcement',
            subtitle: 'Important info for students',
            onTap: () => context.push('/compose/announcement'),
          ),
        ],
      ),
    );
  }
}

class _CreateOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color:
                    Theme.of(context).dividerTheme.color ?? Colors.transparent),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
