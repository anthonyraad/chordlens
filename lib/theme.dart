// Visual system aligned with Irodoku: Balatro, Material 3, flat cards.
import 'package:flutter/material.dart';

abstract final class ChordLensTheme {
  static const fontFamily = 'Balatro';
  static const _seed = Color(0xFF42A5F5);
  static const lightBackground = Color(0xFFF5F6F8);
  static const darkBackground = Color(0xFF121418);
  static const darkCard = Color(0xFF1C1F26);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final scaffold = isDark ? darkBackground : lightBackground;
    final card = isDark ? darkCard : Colors.white;
    final base = ThemeData(brightness: brightness);
    final radius = const BorderRadius.all(Radius.circular(8));
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colorScheme.outline),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: base.textTheme.apply(fontFamily: fontFamily),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: fontFamily),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: isDark ? Colors.white.withValues(alpha: 0.12) : null,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        isDense: true,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: colorScheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
        backgroundColor: isDark ? darkCard : colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? colorScheme.onSurface : colorScheme.onInverseSurface,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(
          fontFamily: fontFamily,
          color: colorScheme.onSurface,
          fontSize: 16,
        ),
      ),
    );
  }
}
