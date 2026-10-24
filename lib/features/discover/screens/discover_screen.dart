import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../discover_categories.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 12),
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
