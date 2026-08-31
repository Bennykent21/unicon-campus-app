import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  static const _categories = [
    (
      key: 'marketplace',
      label: 'Marketplace',
      subtitle: 'Buy and sell items',
      icon: Icons.storefront_outlined,
      color: AppColors.marketplace,
      postType: 'marketplace',
      tag: null
    ),
    (
      key: 'jobs',
      label: 'Jobs',
      subtitle: 'Find internships and jobs',
      icon: Icons.work_outline,
      color: AppColors.job,
      postType: 'job',
      tag: null
    ),
    (
      key: 'events',
      label: 'Events',
      subtitle: 'See upcoming events',
      icon: Icons.event_outlined,
      color: AppColors.event,
      postType: 'event',
      tag: null
    ),
    (
      key: 'scholarships',
      label: 'Scholarships',
      subtitle: 'Find scholarship opportunities',
      icon: Icons.school_outlined,
      color: Color(0xFF3B82F6),
      postType: null,
      tag: 'Scholarships'
    ),
    (
      key: 'clubs',
      label: 'Clubs & Societies',
      subtitle: 'Connect with campus clubs',
      icon: Icons.groups_outlined,
      color: Color(0xFFEC4899),
      postType: null,
      tag: null
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            readOnly: true,
            onTap: () => context.push('/feed-search'),
            decoration: const InputDecoration(
              hintText: 'Search marketplace, jobs, events...',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Find what you need',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Explore opportunities, items and more',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                      color: Colors.white24, shape: BoxShape.circle),
                  child: const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Browse Categories',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          ..._categories.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    // Clubs has no dedicated post type/tag yet — be honest
                    // about it rather than showing an empty or wrong list.
                    if (cat.key == 'clubs') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Clubs & Societies is coming in a future update'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    context.push(
                      '/discover-category',
                      extra: {
                        'title': cat.label,
                        'icon': cat.icon,
                        'color': cat.color,
                        'postType': cat.postType,
                        'tag': cat.tag,
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Theme.of(context).dividerTheme.color ??
                              Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: cat.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(cat.icon, color: cat.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cat.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(cat.subtitle,
                                  style: TextStyle(
                                      fontSize: 12,
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
              ),
            );
          }),
        ],
      ),
    );
  }
}
