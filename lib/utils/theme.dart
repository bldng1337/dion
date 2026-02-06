import 'package:dionysos/utils/design_tokens.dart';
import 'package:flutter/material.dart';

enum DionThemeMode { material, cupertino }

class DionTheme {
  final DionThemeMode mode;
  final Brightness brightness;

  const DionTheme({required this.mode, required this.brightness});

  @override
  bool operator ==(Object other) {
    return other is DionTheme &&
        other.mode == mode &&
        other.brightness == brightness;
  }

  @override
  int get hashCode => Object.hash(mode, brightness);

  static const DionTheme material = DionTheme(
    mode: DionThemeMode.material,
    brightness: Brightness.light,
  );
  static const DionTheme cupertino = DionTheme(
    mode: DionThemeMode.cupertino,
    brightness: Brightness.light,
  );

  static DionTheme of(BuildContext context) {
    final DionTheme? theme = context
        .dependOnInheritedWidgetOfExactType<InheritedDionTheme>()
        ?.theme;
    return theme ?? DionTheme.material;
  }
}

ThemeData getTheme(Brightness b) {
  final bool isDark = b == Brightness.dark;

  // Use design tokens for colors
  const Color primary = DionColors.primary;
  final Color textColor = isDark
      ? DionColors.textPrimaryDark
      : DionColors.textPrimary;
  final Color textSecondary = isDark
      ? DionColors.textSecondaryDark
      : DionColors.textSecondary;
  final Color surfaceColor = isDark
      ? DionColors.surfaceDark
      : DionColors.surfaceLight;
  final Color surfaceMuted = isDark
      ? DionColors.surfaceMutedDark
      : DionColors.surfaceMuted;
  final Color borderColor = isDark
      ? DionColors.borderDark
      : DionColors.borderLight;
  final Color dividerColor = isDark
      ? DionColors.dividerDark
      : DionColors.divider;

  final ColorScheme colorScheme =
      ColorScheme.fromSeed(brightness: b, seedColor: primary).copyWith(
        primary: primary,
        onSurface: textColor,
        onSurfaceVariant: textSecondary,
        surface: surfaceColor,
        surfaceContainerHighest: surfaceMuted,
      );

  final RoundedRectangleBorder smallRadiusShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(DionRadius.sm),
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surfaceColor,

    appBarTheme: AppBarTheme(
      backgroundColor: surfaceColor,
      foregroundColor: textColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: textColor),
      actionsIconTheme: IconThemeData(color: textColor),
      titleTextStyle: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DionRadius.sm),
      ),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surfaceColor,
      elevation: 0,
      indicatorColor: primary.withValues(alpha: 0.15),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DionRadius.sm),
      ),
      selectedIconTheme: IconThemeData(color: primary, size: 22),
      unselectedIconTheme: IconThemeData(
        color: textSecondary.withValues(alpha: 0.7),
        size: 22,
      ),
      selectedLabelTextStyle: TextStyle(
        color: primary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: textSecondary.withValues(alpha: 0.7),
        fontSize: 11,
      ),
      useIndicator: true,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: primary.withValues(alpha: 0.15),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DionRadius.sm),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: primary, size: 22);
        }
        return IconThemeData(
          color: textSecondary.withValues(alpha: 0.7),
          size: 22,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            color: primary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          );
        }
        return TextStyle(
          color: textSecondary.withValues(alpha: 0.7),
          fontSize: 11,
        );
      }),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DionRadius.md),
        side: BorderSide(color: borderColor.withValues(alpha: 0.5), width: 0.5),
      ),
      color: surfaceColor,
    ),

    dialogTheme: DialogThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DionRadius.md),
        side: BorderSide(color: borderColor.withValues(alpha: 0.5), width: 0.5),
      ),
      backgroundColor: surfaceColor,
    ),

    popupMenuTheme: PopupMenuThemeData(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DionRadius.md),
        side: BorderSide(color: borderColor.withValues(alpha: 0.5), width: 0.5),
      ),
      color: surfaceColor,
    ),

    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DionRadius.sm),
          borderSide: BorderSide(
            color: borderColor.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DionRadius.sm),
          borderSide: BorderSide(
            color: borderColor.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DionRadius.sm),
          borderSide: BorderSide(color: primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      menuStyle: MenuStyle(
        elevation: WidgetStateProperty.all(8),
        shadowColor: WidgetStateProperty.all(
          Colors.black.withValues(alpha: 0.15),
        ),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DionRadius.md),
            side: BorderSide(
              color: borderColor.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        backgroundColor: WidgetStateProperty.all(surfaceColor),
      ),
    ),

    menuTheme: MenuThemeData(
      style: MenuStyle(
        elevation: WidgetStateProperty.all(8),
        shadowColor: WidgetStateProperty.all(
          Colors.black.withValues(alpha: 0.15),
        ),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DionRadius.md),
            side: BorderSide(
              color: borderColor.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        backgroundColor: WidgetStateProperty.all(surfaceColor),
      ),
    ),

    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(smallRadiusShape),
        overlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.1)),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(smallRadiusShape),
        overlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.1)),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        elevation: WidgetStateProperty.all(0),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DionRadius.sm),
            side: BorderSide(
              color: borderColor.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        overlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.1)),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DionRadius.sm),
            side: BorderSide(color: primary.withValues(alpha: 0.5), width: 0.5),
          ),
        ),
        overlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.1)),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(smallRadiusShape),
        overlayColor: WidgetStateProperty.all(
          colorScheme.onPrimary.withValues(alpha: 0.1),
        ),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(smallRadiusShape),
        overlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.1)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DionRadius.sm),
        borderSide: BorderSide(
          color: borderColor.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DionRadius.sm),
        borderSide: BorderSide(
          color: borderColor.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DionRadius.sm),
        borderSide: BorderSide(color: primary, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DionRadius.sm),
        borderSide: BorderSide(color: DionColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DionRadius.sm),
        borderSide: BorderSide(color: DionColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
    ),

    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DionRadius.sm),
        side: BorderSide(color: borderColor.withValues(alpha: 0.5), width: 0.5),
      ),
      backgroundColor: surfaceColor,
      selectedColor: primary.withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pressElevation: 0,
    ),

    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DionRadius.sm),
      ),
      selectedTileColor: primary.withValues(alpha: 0.1),
      selectedColor: primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    dividerTheme: DividerThemeData(color: dividerColor, thickness: 0.5),

    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(DionRadius.lg),
          topRight: Radius.circular(DionRadius.lg),
        ),
      ),
      backgroundColor: surfaceColor,
    ),

    snackBarTheme: SnackBarThemeData(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DionRadius.sm),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark
          ? DionColors.surfaceMuted
          : DionColors.textPrimary,
      contentTextStyle: TextStyle(
        color: isDark ? DionColors.textPrimaryDark : Colors.white,
      ),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? DionColors.surfaceMuted : DionColors.textPrimary,
        borderRadius: BorderRadius.circular(DionRadius.sm),
      ),
      textStyle: TextStyle(
        color: isDark ? DionColors.textPrimaryDark : Colors.white,
        fontSize: 12,
      ),
    ),

    sliderTheme: SliderThemeData(
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      activeTrackColor: primary,
      inactiveTrackColor: borderColor,
      thumbColor: primary,
      overlayColor: primary.withValues(alpha: 0.15),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary;
        }
        return textSecondary.withValues(alpha: 0.6);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary.withValues(alpha: 0.35);
        }
        return borderColor;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      side: BorderSide(color: textSecondary.withValues(alpha: 0.5), width: 1.5),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary;
        }
        return textSecondary.withValues(alpha: 0.5);
      }),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: borderColor,
      circularTrackColor: borderColor,
    ),

    tabBarTheme: TabBarThemeData(
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: primary, width: 2),
      ),
      labelColor: primary,
      unselectedLabelColor: textSecondary.withValues(alpha: 0.7),
      overlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.1)),
    ),

    drawerTheme: DrawerThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(DionRadius.md),
          bottomRight: Radius.circular(DionRadius.md),
        ),
      ),
      backgroundColor: surfaceColor,
    ),

    expansionTileTheme: ExpansionTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DionRadius.sm),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DionRadius.sm),
      ),
      iconColor: primary,
      collapsedIconColor: textSecondary.withValues(alpha: 0.5),
    ),

    searchBarTheme: SearchBarThemeData(
      elevation: WidgetStateProperty.all(0),
      surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DionRadius.sm),
          side: BorderSide(
            color: borderColor.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      backgroundColor: WidgetStateProperty.all(surfaceColor),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DionRadius.sm),
          ),
        ),
        side: WidgetStateProperty.all(
          BorderSide(color: borderColor.withValues(alpha: 0.5), width: 0.5),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.15);
          }
          return surfaceColor;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return textColor;
        }),
      ),
    ),

    badgeTheme: BadgeThemeData(
      backgroundColor: primary,
      textColor: colorScheme.onPrimary,
    ),
  );
}

class InheritedDionTheme extends InheritedWidget {
  final DionTheme theme;
  const InheritedDionTheme({required this.theme, required super.child});

  @override
  bool updateShouldNotify(InheritedDionTheme oldWidget) {
    return theme != oldWidget.theme;
  }
}

extension DionThemeExt on BuildContext {
  DionTheme get diontheme => DionTheme.of(this);
}
