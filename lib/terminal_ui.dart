// Retro BIOS / DOS terminal palette and theme.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Phosphor-on-crt colors (late 80s–90s PC / Award BIOS feel).
class TerminalColors {
  TerminalColors._();

  static const bg = Color(0xFF030308);
  static const text = Color(0xFF2AD484);
  static const textBright = Color(0xFF7CFFC3);
  static const textDim = Color(0xFF0F8C52);
  static const border = Color(0xFF0E5C3A);
  static const borderFocus = Color(0xFF1AFF99);
  static const error = Color(0xFFFF4D6A);
  static const hint = Color(0xFF0A3D25);
  static const blockBg = Color(0xFF020804);
  static const panel = Color(0xFF07120C);
  static const titleGlow = Color(0xFF00FF9D);
}

class TerminalTheme {
  TerminalTheme._();

  static const _border = OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(color: TerminalColors.border, width: 1),
  );

  static ThemeData data() {
    final base = ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
      primaryColor: TerminalColors.text,
      canvasColor: TerminalColors.bg,
      scaffoldBackgroundColor: TerminalColors.bg,
      colorScheme: const ColorScheme.dark(
        surface: TerminalColors.panel,
        primary: TerminalColors.text,
        secondary: TerminalColors.textDim,
        onSurface: TerminalColors.text,
        error: TerminalColors.error,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.jetBrainsMonoTextTheme(base.textTheme).apply(
        bodyColor: TerminalColors.text,
        displayColor: TerminalColors.text,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: TerminalColors.blockBg,
        isDense: true,
        border: _border,
        enabledBorder: _border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: TerminalColors.borderFocus,
            width: 1.2,
          ),
        ),
        labelStyle: TextStyle(
          color: TerminalColors.textBright,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
        floatingLabelStyle: TextStyle(
          color: TerminalColors.textBright,
          fontSize: 12,
        ),
        hintStyle: TextStyle(
          color: TerminalColors.hint,
          fontSize: 14,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: TerminalColors.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: TerminalColors.textBright,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: TerminalColors.text),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(
          color: TerminalColors.text,
          fontSize: 13,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: TerminalColors.border),
          ),
        ),
      ),
    );
  }

  static TextStyle get sectionLabel => GoogleFonts.jetBrainsMono(
        color: TerminalColors.textBright,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );
}

/// Subtle text glow (CRT) — keep low blur for a “slick” look.
class CrtText extends StatelessWidget {
  const CrtText({
    super.key,
    required this.text,
    this.style,
    this.glowColor,
  });

  final String text;
  final TextStyle? style;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final s = style ?? const TextStyle();
    final g = glowColor ?? TerminalColors.titleGlow;
    return Text(
      text,
      style: s.copyWith(
        shadows: [
          Shadow(
            color: g.withValues(alpha: 0.28),
            blurRadius: 3,
            offset: Offset.zero,
          ),
        ],
      ),
    );
  }
}
