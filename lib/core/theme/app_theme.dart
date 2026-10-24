import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  /// Type scale. Screens should take sizes from `Theme.of(context).textTheme`
  /// rather than hard-coding them. Nothing a student must read goes below
  /// 12; 11 is reserved for badge labels.
  static TextTheme _textTheme(Color primary, Color secondary) {
    final base = GoogleFonts.interTextTheme();
    TextStyle? s(TextStyle? t, double size, FontWeight w, Color c,
            {double? height}) =>
        t?.copyWith(fontSize: size, fontWeight: w, color: c, height: height);
    return base.copyWith(
      headlineSmall: s(base.headlineSmall, 24, FontWeight.w800, primary),
      titleLarge: s(base.titleLarge, 20, FontWeight.w800, primary),
      titleMedium: s(base.titleMedium, 16, FontWeight.w700, primary),
      titleSmall: s(base.titleSmall, 14.5, FontWeight.w700, primary),
      bodyLarge:
          s(base.bodyLarge, 15.5, FontWeight.w400, primary, height: 1.45),
      bodyMedium: s(base.bodyMedium, 14, FontWeight.w400, primary, height: 1.4),
      bodySmall:
          s(base.bodySmall, 12.5, FontWeight.w400, secondary, height: 1.35),
      labelLarge: s(base.labelLarge, 14, FontWeight.w600, primary),
      labelMedium: s(base.labelMedium, 12.5, FontWeight.w600, primary),
      labelSmall: s(base.labelSmall, 11, FontWeight.w700, secondary),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final fill = palette.neutral.bg;
    final textTheme = _textTheme(textPrimary, textSecondary);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: palette.brandSoft,
        onSecondary: palette.brandText,
        error: palette.event.fg,
        onError: isDark ? AppColors.darkBg : Colors.white,
        surface: surface,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        outline: border,
        outlineVariant: border,
      ),
      textTheme: textTheme,
      extensions: [palette],
      // Material's 48dp minimum hit area for every tappable control.
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(64, 48),
          side: BorderSide(color: border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.brandText,
          minimumSize: const Size(48, 44),
          textStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: textSecondary,
          selectedBackgroundColor: AppColors.primary,
          selectedForegroundColor: Colors.white,
          side: BorderSide(color: border),
          textStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        labelStyle: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
        secondaryLabelStyle: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        shape: StadiumBorder(side: BorderSide(color: border)),
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      ),
    );
  }
}
