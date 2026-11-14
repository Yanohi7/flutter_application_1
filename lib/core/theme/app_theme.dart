// Apply one coordinated palette to backgrounds, surfaces and controls.

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';

abstract final class AppTheme {
  static final light = build(Brightness.light);
  static final dark = build(Brightness.dark);

  static ThemeData build(
    Brightness brightness, {
    AppPalette palette = AppPalette.graphite,
    double surfaceOpacity = 1,
  }) {
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFE9ECF0) : const Color(0xFF252B33);
    final accent = isDark ? palette.darkPrimary : palette.primary;
    final secondary = isDark ? palette.darkSecondary : palette.secondary;
    final surface = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.08 : 0.10),
      isDark ? const Color(0xFF23262C) : Colors.white,
    );
    final canvas = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.06 : 0.065),
      isDark ? AppColors.darkCanvas : AppColors.canvas,
    );
    final chrome = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.22 : 0.24),
      isDark ? const Color(0xFF23262C) : Colors.white,
    );
    final raised = Color.alphaBlend(
      secondary.withValues(alpha: isDark ? 0.18 : 0.12),
      surface,
    );
    // Keep enough tint over even the brightest or darkest pixel of a photo.
    // The saved slider range still controls the amount of glass on each panel.
    final minimumOpacity = isDark ? 0.87 : 0.80;
    final amount = (surfaceOpacity.clamp(0.25, 1.0) - 0.25) / 0.75;
    final opacity = minimumOpacity + (1 - minimumOpacity) * amount;
    final worstBackdrop = isDark ? Colors.white : Colors.black;
    final worstSurface = Color.alphaBlend(
      chrome.withValues(alpha: minimumOpacity),
      worstBackdrop,
    );
    final primary = _readable(accent, ink, worstSurface);
    final muted = _readable(
      isDark ? const Color(0xFFBBC5D2) : const Color(0xFF485567),
      ink,
      worstSurface,
    );
    final border = Color.alphaBlend(accent.withValues(alpha: 0.24), surface);
    final controlBorder = _readable(border, ink, worstSurface, ratio: 3);
    final onPrimary = primary.computeLuminance() > 0.179
        ? Colors.black
        : Colors.white;
    final colors =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          primaryContainer: Color.alphaBlend(
            primary.withValues(alpha: 0.12),
            surface,
          ),
          onPrimaryContainer: ink,
          secondary: secondary,
          onSecondary:
              ThemeData.estimateBrightnessForColor(secondary) == Brightness.dark
              ? Colors.white
              : AppColors.darkCanvas,
          onSecondaryContainer: ink,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: controlBorder,
          outlineVariant: border,
          surfaceContainerLowest: surface,
          surfaceContainerLow: canvas,
          surfaceContainer: chrome,
          surfaceContainerHigh: raised,
          surfaceContainerHighest: Color.alphaBlend(
            primary.withValues(alpha: 0.09),
            surface,
          ),
          secondaryContainer: Color.alphaBlend(
            secondary.withValues(alpha: 0.12),
            surface,
          ),
        );
    final base = ThemeData(useMaterial3: true, colorScheme: colors);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      iconTheme: IconThemeData(size: 20, color: colors.onSurfaceVariant),
      // Define a shared text hierarchy so pages do not need to repeat every font size
      textTheme: base.textTheme.copyWith(
        bodyLarge: TextStyle(fontSize: 14, height: 1.5, color: ink),
        bodyMedium: TextStyle(fontSize: 13, height: 1.4, color: ink),
        bodySmall: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: chrome.withValues(alpha: opacity),
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 50,
        titleSpacing: 8,
        centerTitle: false,
        iconTheme: IconThemeData(size: 20, color: ink),
        actionsIconTheme: IconThemeData(size: 20, color: ink),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        shape: Border(bottom: BorderSide(color: border)),
      ),
      cardTheme: CardThemeData(
        color: surface.withValues(alpha: opacity),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(side: BorderSide(color: border)),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface.withValues(alpha: opacity),
        isDense: true,
        hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        helperMaxLines: 4,
        errorMaxLines: 4,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: controlBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: controlBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      // Give selected category and filter chips the same accent as other controls
      chipTheme: ChipThemeData(
        backgroundColor: surface.withValues(alpha: opacity),
        selectedColor: primary,
        secondarySelectedColor: primary,
        disabledColor: raised,
        side: BorderSide(color: border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        labelStyle: TextStyle(fontSize: 12, color: ink),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: chrome,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: raised,
        surfaceTintColor: Colors.transparent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.28),
        selectionHandleColor: primary,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: 20,
          foregroundColor: primary,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.all(8),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: surface.withValues(alpha: opacity),
          foregroundColor: primary,
          disabledForegroundColor: muted,
          disabledBackgroundColor: raised,
          side: BorderSide(color: controlBorder),
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 40),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: colors.onPrimary,
          disabledForegroundColor: muted,
          disabledBackgroundColor: raised,
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 44),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          disabledForegroundColor: muted,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      // Style the creation button consistently across the application
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: colors.onPrimary,
        elevation: 3,
        focusElevation: 5,
        hoverElevation: 5,
        highlightElevation: 2,
        shape: const CircleBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface.withValues(alpha: opacity),
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 20,
        horizontalTitleGap: 12,
        minTileHeight: 52,
      ),
    );
  }

  static Color _readable(
    Color color,
    Color ink,
    Color surface, {
    double ratio = 4.5,
  }) {
    final background = surface.computeLuminance();
    for (var step = 0; step <= 10; step++) {
      final candidate = Color.lerp(color, ink, step / 10)!;
      final foreground = candidate.computeLuminance();
      final contrast = foreground > background
          ? (foreground + 0.05) / (background + 0.05)
          : (background + 0.05) / (foreground + 0.05);
      if (contrast >= ratio) return candidate;
    }
    return ink;
  }
}
