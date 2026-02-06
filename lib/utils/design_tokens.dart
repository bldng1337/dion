import 'package:flutter/material.dart';

class DionSpacing {
  DionSpacing._();

  static const double xs = 4;

  static const double sm = 8;

  static const double md = 12;

  static const double lg = 16;

  static const double xl = 24;

  static const double xxl = 32;

  static const double xxxl = 48;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: sm,
  );

  static const EdgeInsets itemPadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  static const EdgeInsets compactPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );
}


class DionRadius {
  DionRadius._();

  static const double xs = 2;

  static const double sm = 4;

  static const double md = 6;

  static const double lg = 8;

  static const double xl = 12;

  static BorderRadius get small => BorderRadius.circular(sm);
  static BorderRadius get medium => BorderRadius.circular(md);
  static BorderRadius get large => BorderRadius.circular(lg);
}

class DionDuration {
  DionDuration._();

  static const Duration fast = Duration(milliseconds: 100);

  static const Duration normal = Duration(milliseconds: 200);

  static const Duration slow = Duration(milliseconds: 300);

  static const Duration page = Duration(milliseconds: 400);
}


class DionColors {
  DionColors._();

  static const Color primary = Color(0xFF6BA368);
  static const Color primaryLight = Color(0xFF8FBF8C);
  static const Color primaryDark = Color(0xFF4A8347);

  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF5C5C5C);
  static const Color textTertiary = Color(0xFF8C8C8C);

  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color surfaceMuted = Color(0xFFF5F5F5);
  static const Color borderLight = Color(0xFFE8E8E8);
  static const Color divider = Color(0xFFEEEEEE);

  static const Color textPrimaryDark = Color(0xFFF0F0F0);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textTertiaryDark = Color(0xFF787878);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color surfaceMutedDark = Color(0xFF242424);
  static const Color borderDark = Color(0xFF333333);
  static const Color dividerDark = Color(0xFF2A2A2A);

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2196F3);
}


class DionTypography {
  DionTypography._();

  static TextStyle displayLarge(Color color) => TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.2,
    color: color,
  );

  static TextStyle titleLarge(Color color) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
    color: color,
  );

  static TextStyle titleMedium(Color color) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    height: 1.4,
    color: color,
  );

  static TextStyle titleSmall(Color color) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    height: 1.4,
    color: color,
  );

  static TextStyle bodyLarge(Color color) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
    color: color,
  );

  static TextStyle bodyMedium(Color color) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
    color: color,
  );

  static TextStyle bodySmall(Color color) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.4,
    color: color,
  );

  static TextStyle labelLarge(Color color) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
    color: color,
  );

  static TextStyle labelMedium(Color color) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
    color: color,
  );

  static TextStyle labelSmall(Color color) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.3,
    color: color,
  );

  static TextStyle sectionHeader(Color color) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    height: 1.3,
    color: color,
  );
}

extension DionDesignContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get textPrimary =>
      isDarkMode ? DionColors.textPrimaryDark : DionColors.textPrimary;
  Color get textSecondary =>
      isDarkMode ? DionColors.textSecondaryDark : DionColors.textSecondary;
  Color get textTertiary =>
      isDarkMode ? DionColors.textTertiaryDark : DionColors.textTertiary;

  Color get surfaceMuted =>
      isDarkMode ? DionColors.surfaceMutedDark : DionColors.surfaceMuted;
  Color get dionDivider =>
      isDarkMode ? DionColors.dividerDark : DionColors.divider;
  Color get borderColor =>
      isDarkMode ? DionColors.borderDark : DionColors.borderLight;
}
