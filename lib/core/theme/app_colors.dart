import 'package:flutter/material.dart';

/// Centralized color palette for the UNICON brand, with full light + dark
/// variants.
///
/// The raw brand/tag colors below are for fills, icons and badges on a
/// tinted background. For anything that is *text*, read the theme-aware
/// shades from [AppPalette] (`context.palette`) instead — several of the raw
/// tag colors fall below the 4.5:1 contrast minimum when used as text.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary =
      Color(0xFF6C4FE0); // main purple (buttons, FAB, accents)
  static const Color primaryDark = Color(0xFF5A3FD0);
  static const Color primaryLight = Color(0xFFEDE7FB);

  // Tag colors (post-type badges)
  static const Color question = Color(0xFFFFC107); // QUESTION badge
  static const Color marketplace = Color(0xFF22C55E); // MARKETPLACE badge
  static const Color event = Color(0xFFEF4444); // EVENT badge
  static const Color job = Color(0xFFF59E0B); // JOB badge
  static const Color general = Color(0xFF3B82F6); // GENERAL badge
  static const Color announcement = Color(0xFFA855F7); // ANNOUNCEMENT badge

  // Interaction system
  static const Color helpful = Color(0xFF22C55E); // upvote green
  static const Color save = Color(0xFFEF4444); // bookmark/heart red
  static const Color accepted = Color(0xFF16A34A); // accepted answer check
  static const Color badge =
      Color(0xFFD92D20); // unread count dot (white text passes 4.5:1)

  // Light theme neutrals
  static const Color lightBg = Color(0xFFF7F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE7E7EF);
  static const Color lightTextPrimary = Color(0xFF15131F);
  static const Color lightTextSecondary = Color(0xFF5F5D6E);

  // Dark theme neutrals
  static const Color darkBg = Color(0xFF0B0A12);
  static const Color darkSurface = Color(0xFF15131F);
  static const Color darkBorder = Color(0xFF26243A);
  static const Color darkTextPrimary = Color(0xFFF5F4FA);
  static const Color darkTextSecondary = Color(0xFF9C9AB0);
}

/// A foreground/background pair for a semantic tag (post type, status pill).
/// [fg] meets 4.5:1 on [bg] and on the surface color in its theme.
@immutable
class TagColors {
  final Color fg;
  final Color bg;
  const TagColors(this.fg, this.bg);

  static TagColors lerp(TagColors a, TagColors b, double t) =>
      TagColors(Color.lerp(a.fg, b.fg, t)!, Color.lerp(a.bg, b.bg, t)!);
}

/// Theme-aware semantic colors. Registered on both themes in [AppTheme];
/// read with `context.palette` (or `Theme.of(context).extension<AppPalette>()`).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// Brand purple when used as text or a small icon. Lighter in dark mode,
  /// where [AppColors.primary] only reaches 3.6:1 on the background.
  final Color brandText;
  final Color brandSoft;
  final TagColors question;
  final TagColors marketplace;
  final TagColors job;
  final TagColors event;
  final TagColors general;
  final TagColors announcement;

  /// Open / accepting / success (e.g. "Closes 15 Nov", "You match").
  final TagColors positive;

  /// Needs attention soon (e.g. "Closes in 3 days", "Follow up today").
  final TagColors warning;

  /// Neutral pill / chip fill and its text.
  final TagColors neutral;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppPalette({
    required this.brandText,
    required this.brandSoft,
    required this.question,
    required this.marketplace,
    required this.job,
    required this.event,
    required this.general,
    required this.announcement,
    required this.positive,
    required this.warning,
    required this.neutral,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  static const light = AppPalette(
    brandText: Color(0xFF5B3FD6),
    brandSoft: AppColors.primaryLight,
    question: TagColors(Color(0xFF8A5A00), Color(0xFFFFF4D6)),
    marketplace: TagColors(Color(0xFF0F7B4F), Color(0xFFE3F4EC)),
    job: TagColors(Color(0xFFA15C07), Color(0xFFFDF0E1)),
    event: TagColors(Color(0xFFB42318), Color(0xFFFDECEA)),
    general: TagColors(Color(0xFF1D4ED8), Color(0xFFE6EEFD)),
    announcement: TagColors(Color(0xFF7E22CE), Color(0xFFF3E8FF)),
    positive: TagColors(Color(0xFF0F7B4F), Color(0xFFE3F4EC)),
    warning: TagColors(Color(0xFFA15C07), Color(0xFFFDF0E1)),
    neutral: TagColors(Color(0xFF5F5D6E), Color(0xFFF1F0F8)),
    shimmerBase: Color(0xFFE7E7EF),
    shimmerHighlight: Color(0xFFF7F7FB),
  );

  static const dark = AppPalette(
    brandText: Color(0xFFA99BFF),
    brandSoft: Color(0xFF2A2350),
    question: TagColors(Color(0xFFFFD666), Color(0xFF3A2E0A)),
    marketplace: TagColors(Color(0xFF4ADE80), Color(0xFF12301F)),
    job: TagColors(Color(0xFFFBBF24), Color(0xFF3A2A0D)),
    event: TagColors(Color(0xFFF97066), Color(0xFF3A1715)),
    general: TagColors(Color(0xFF8EB4FF), Color(0xFF16233F)),
    announcement: TagColors(Color(0xFFD8B4FE), Color(0xFF2E1A45)),
    positive: TagColors(Color(0xFF4ADE80), Color(0xFF12301F)),
    warning: TagColors(Color(0xFFFBBF24), Color(0xFF3A2A0D)),
    neutral: TagColors(Color(0xFF9C9AB0), Color(0xFF1E1B2B)),
    shimmerBase: Color(0xFF1E1B2B),
    shimmerHighlight: Color(0xFF2A2638),
  );

  /// Colors for a post type badge (`question`, `job`, ...).
  TagColors forPostType(String type) => switch (type) {
        'question' => question,
        'marketplace' => marketplace,
        'job' => job,
        'event' => event,
        'announcement' => announcement,
        _ => general,
      };

  @override
  AppPalette copyWith({Color? brandText}) => AppPalette(
        brandText: brandText ?? this.brandText,
        brandSoft: brandSoft,
        question: question,
        marketplace: marketplace,
        job: job,
        event: event,
        general: general,
        announcement: announcement,
        positive: positive,
        warning: warning,
        neutral: neutral,
        shimmerBase: shimmerBase,
        shimmerHighlight: shimmerHighlight,
      );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      brandText: Color.lerp(brandText, other.brandText, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      question: TagColors.lerp(question, other.question, t),
      marketplace: TagColors.lerp(marketplace, other.marketplace, t),
      job: TagColors.lerp(job, other.job, t),
      event: TagColors.lerp(event, other.event, t),
      general: TagColors.lerp(general, other.general, t),
      announcement: TagColors.lerp(announcement, other.announcement, t),
      positive: TagColors.lerp(positive, other.positive, t),
      warning: TagColors.lerp(warning, other.warning, t),
      neutral: TagColors.lerp(neutral, other.neutral, t),
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight:
          Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
