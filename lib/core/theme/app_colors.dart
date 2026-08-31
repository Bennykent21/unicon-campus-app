import 'package:flutter/material.dart';

/// Centralized color palette. Matches the purple "University Community App"
/// brand from the design mockups, with full light + dark variants.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF6C4FE0); // main purple (buttons, FAB, accents)
  static const Color primaryDark = Color(0xFF5A3FD0);
  static const Color primaryLight = Color(0xFFEDE7FB);

  // Tag colors (post-type badges)
  static const Color question = Color(0xFFFFC107); // QUESTION badge
  static const Color marketplace = Color(0xFF22C55E); // MARKETPLACE badge
  static const Color event = Color(0xFFEF4444); // EVENT badge
  static const Color job = Color(0xFFF59E0B); // JOB badge
  static const Color general = Color(0xFF3B82F6); // GENERAL badge

  // Interaction system
  static const Color helpful = Color(0xFF22C55E); // upvote green
  static const Color save = Color(0xFFEF4444); // bookmark/heart red
  static const Color accepted = Color(0xFF16A34A); // accepted answer check

  // Light theme neutrals
  static const Color lightBg = Color(0xFFF7F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE7E7EF);
  static const Color lightTextPrimary = Color(0xFF15131F);
  static const Color lightTextSecondary = Color(0xFF6B6B7B);

  // Dark theme neutrals
  static const Color darkBg = Color(0xFF0B0A12);
  static const Color darkSurface = Color(0xFF15131F);
  static const Color darkBorder = Color(0xFF26243A);
  static const Color darkTextPrimary = Color(0xFFF5F4FA);
  static const Color darkTextSecondary = Color(0xFF9C9AB0);
}
