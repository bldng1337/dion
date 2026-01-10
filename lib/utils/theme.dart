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
  const Color primary = Color(0xFF6BA368);
  // Very dark gray for text, bordering on black
  final Color textColor = b == Brightness.light
      ? const Color(0xFF1A1A1A)
      : const Color(0xFFF0F0F0);

  final ColorScheme colorScheme =
      ColorScheme.fromSeed(brightness: b, seedColor: primary).copyWith(
        onSurface: textColor,
        onSurfaceVariant: textColor.withValues(alpha: 0.8),
      );

  final RoundedRectangleBorder smallRadiusShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(3),
  );

  return ThemeData(
    colorScheme: colorScheme,

    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: textColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: colorScheme.onPrimary),
      actionsIconTheme: IconThemeData(color: colorScheme.onPrimary),
      titleTextStyle: TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: colorScheme.primary, width: 0.3),
      ),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
      ),
      selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 24),
      unselectedIconTheme: IconThemeData(
        color: colorScheme.onSurface.withValues(alpha: 0.5),
        size: 24,
      ),
      selectedLabelTextStyle: TextStyle(
        color: colorScheme.primary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.5),
        fontSize: 12,
      ),
      useIndicator: true,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: colorScheme.primary, size: 24);
        }
        return IconThemeData(
          color: colorScheme.onSurface.withValues(alpha: 0.5),
          size: 24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            color: colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }
        return TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 12,
        );
      }),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      color: colorScheme.surface,
    ),

    dialogTheme: DialogThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      backgroundColor: colorScheme.surface,
    ),

    popupMenuTheme: PopupMenuThemeData(
      elevation: 4,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      color: colorScheme.surface,
    ),

    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      menuStyle: MenuStyle(
        elevation: WidgetStateProperty.all(4),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: BorderSide(
              color: colorScheme.onSurface.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        backgroundColor: WidgetStateProperty.all(colorScheme.surface),
      ),
    ),

    menuTheme: MenuThemeData(
      style: MenuStyle(
        elevation: WidgetStateProperty.all(4),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: BorderSide(
              color: colorScheme.onSurface.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        backgroundColor: WidgetStateProperty.all(colorScheme.surface),
      ),
    ),

    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(smallRadiusShape),
        overlayColor: WidgetStateProperty.all(
          colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(smallRadiusShape),
        overlayColor: WidgetStateProperty.all(
          colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        elevation: WidgetStateProperty.all(0),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
        ),
        overlayColor: WidgetStateProperty.all(
          colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: BorderSide(color: colorScheme.primary, width: 0.5),
          ),
        ),
        overlayColor: WidgetStateProperty.all(
          colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(smallRadiusShape),
        overlayColor: WidgetStateProperty.all(
          colorScheme.onPrimary.withValues(alpha: 0.15),
        ),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(smallRadiusShape),
        overlayColor: WidgetStateProperty.all(
          colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: BorderSide(color: colorScheme.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),

    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primary.withValues(alpha: 0.2),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pressElevation: 0,
    ),

    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      selectedTileColor: colorScheme.primary.withValues(alpha: 0.15),
      selectedColor: colorScheme.primary,
    ),

    dividerTheme: DividerThemeData(
      color: colorScheme.onSurface.withValues(alpha: 0.1),
      thickness: 0.5,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(3),
          topRight: Radius.circular(3),
        ),
      ),
      backgroundColor: colorScheme.surface,
    ),

    snackBarTheme: SnackBarThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(3),
      ),
      textStyle: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
    ),

    sliderTheme: SliderThemeData(
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.2),
      thumbColor: colorScheme.primary,
      overlayColor: colorScheme.primary.withValues(alpha: 0.15),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return colorScheme.onSurface.withValues(alpha: 0.6);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary.withValues(alpha: 0.4);
        }
        return colorScheme.onSurface.withValues(alpha: 0.2);
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      side: BorderSide(
        color: colorScheme.onSurface.withValues(alpha: 0.5),
        width: 1.5,
      ),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return colorScheme.onSurface.withValues(alpha: 0.5);
      }),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: colorScheme.onSurface.withValues(alpha: 0.1),
      circularTrackColor: colorScheme.onSurface.withValues(alpha: 0.1),
    ),

    tabBarTheme: TabBarThemeData(
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: colorScheme.primary, width: 2.5),
      ),
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.5),
      overlayColor: WidgetStateProperty.all(
        colorScheme.primary.withValues(alpha: 0.15),
      ),
    ),

    drawerTheme: DrawerThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(3),
          bottomRight: Radius.circular(3),
        ),
      ),
      backgroundColor: colorScheme.surface,
    ),

    expansionTileTheme: ExpansionTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
      ),
      iconColor: colorScheme.primary,
      collapsedIconColor: colorScheme.onSurface.withValues(alpha: 0.5),
    ),

    searchBarTheme: SearchBarThemeData(
      elevation: WidgetStateProperty.all(0),
      surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      backgroundColor: WidgetStateProperty.all(colorScheme.surface),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
        side: WidgetStateProperty.all(
          BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.2);
          }
          return colorScheme.surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurface;
        }),
      ),
    ),

    badgeTheme: BadgeThemeData(
      backgroundColor: colorScheme.primary,
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
