import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Label for each post type, shared by the feed card, post detail and filters.
String postTypeLabel(String type, {bool short = false}) => switch (type) {
      'question' => 'Q&A',
      'marketplace' => short ? 'Market' : 'Marketplace',
      'job' => 'Job',
      'event' => 'Event',
      'announcement' => 'Announcement',
      _ => 'General',
    };

/// Small tinted pill naming a post's type. Colors come from [AppPalette] so
/// the label passes contrast in both themes.
class PostTypeBadge extends StatelessWidget {
  final String type;
  final bool short;

  const PostTypeBadge({super.key, required this.type, this.short = true});

  @override
  Widget build(BuildContext context) {
    final colors = context.palette.forPostType(type);
    final label = postTypeLabel(type, short: short);
    return Semantics(
      label: '$label post',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: colors.fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2)),
      ),
    );
  }
}
