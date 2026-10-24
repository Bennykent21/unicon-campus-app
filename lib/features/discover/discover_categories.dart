import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// One browsable Discover category. Looked up by [key] from the route
/// (`/discover/:category`) so the screen can be rebuilt from the URL alone —
/// after a restart, process death or a deep link.
class DiscoverCategory {
  final String key;
  final String label;
  final String subtitle;
  final IconData icon;

  /// Filters posts by `posts.type` when set...
  final String? postType;

  /// ...or by tag overlap, for categories that aren't a post type.
  final String? tag;

  /// Not built yet; shown with a "Soon" label and not tappable.
  final bool comingSoon;

  const DiscoverCategory({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.postType,
    this.tag,
    this.comingSoon = false,
  });

  TagColors colors(BuildContext context) {
    final p = context.palette;
    return switch (key) {
      'marketplace' => p.marketplace,
      'jobs' => p.job,
      'events' => p.event,
      'announcements' => p.announcement,
      'scholarships' => p.general,
      _ => TagColors(p.brandText, p.brandSoft),
    };
  }

  static const all = <DiscoverCategory>[
    DiscoverCategory(
      key: 'marketplace',
      label: 'Marketplace',
      subtitle: 'Buy and sell with other students',
      icon: Icons.storefront_outlined,
      postType: 'marketplace',
    ),
    DiscoverCategory(
      key: 'jobs',
      label: 'Jobs and gigs',
      subtitle: 'Part-time work posted by students',
      icon: Icons.work_outline,
      postType: 'job',
    ),
    DiscoverCategory(
      key: 'events',
      label: 'Events',
      subtitle: 'What is on around campus',
      icon: Icons.event_outlined,
      postType: 'event',
    ),
    DiscoverCategory(
      key: 'announcements',
      label: 'Announcements',
      subtitle: 'Notices for students',
      icon: Icons.campaign_outlined,
      postType: 'announcement',
    ),
    DiscoverCategory(
      key: 'scholarships',
      label: 'Scholarships',
      subtitle: 'Funding you can apply for',
      icon: Icons.school_outlined,
      tag: 'Scholarships',
    ),
    DiscoverCategory(
      key: 'clubs',
      label: 'Clubs and societies',
      subtitle: 'Find your people',
      icon: Icons.groups_outlined,
      comingSoon: true,
    ),
  ];

  static DiscoverCategory? byKey(String key) {
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }
}
