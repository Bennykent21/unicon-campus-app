import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_community_app/core/theme/app_colors.dart';

/// WCAG relative luminance contrast ratio.
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final l1 = lum(a), l2 = lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  for (final (name, palette, surface, bg) in [
    ('light', AppPalette.light, AppColors.lightSurface, AppColors.lightBg),
    ('dark', AppPalette.dark, AppColors.darkSurface, AppColors.darkBg),
  ]) {
    group('$name palette meets 4.5:1 for text', () {
      final tags = {
        'question': palette.question,
        'marketplace': palette.marketplace,
        'job': palette.job,
        'event': palette.event,
        'general': palette.general,
        'announcement': palette.announcement,
        'positive': palette.positive,
        'warning': palette.warning,
        'neutral': palette.neutral,
      };
      tags.forEach((tag, c) {
        test('$tag on its tint',
            () => expect(contrast(c.fg, c.bg), greaterThanOrEqualTo(4.5)));
        test('$tag on surface',
            () => expect(contrast(c.fg, surface), greaterThanOrEqualTo(4.5)));
      });
      test('brand text on background', () {
        expect(contrast(palette.brandText, bg), greaterThanOrEqualTo(4.5));
        expect(contrast(palette.brandText, palette.brandSoft),
            greaterThanOrEqualTo(4.5));
      });
    });
  }

  test('white on the unread badge passes', () {
    expect(contrast(Colors.white, AppColors.badge), greaterThanOrEqualTo(4.5));
  });

  test('white on the primary button passes', () {
    expect(
        contrast(Colors.white, AppColors.primary), greaterThanOrEqualTo(4.5));
  });
}
