// Vintage CRT / BBS: vertical rainbow (distinct hue per horizontal band).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RainbowStyle {
  const RainbowStyle({
    required this.text,
    required this.textBright,
    required this.textDim,
    required this.border,
    required this.borderFocus,
    required this.hint,
    required this.blockBg,
    required this.titleGlow,
  });

  final Color text;
  final Color textBright;
  final Color textDim;
  final Color border;
  final Color borderFocus;
  final Color hint;
  final Color blockBg;
  final Color titleGlow;

  static Color _h(double h, double s, double l) {
    return HSLColor.fromAHSL(1, h, s, l).toColor();
  }

  /// Top → bottom: red → orange → gold → green → blue → violet (0–4 main UI).
  static RainbowStyle band(int i) {
    const hues = <double>[2, 32, 58, 145, 210, 285];
    final h = hues[i.clamp(0, hues.length - 1)];
    return RainbowStyle(
      text: _h(h, 0.62, 0.55),
      textBright: _h(h, 0.88, 0.78),
      textDim: _h(h, 0.4, 0.42),
      border: _h(h, 0.5, 0.38),
      borderFocus: _h(h, 0.95, 0.6),
      hint: _h(h, 0.32, 0.32),
      blockBg: _h(h, 0.5, 0.06).withValues(alpha: 0.9),
      titleGlow: _h(h, 0.85, 0.5),
    );
  }

  TextStyle sectionLabel() => GoogleFonts.jetBrainsMono(
        color: textBright,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        shadows: [
          Shadow(
            color: titleGlow.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: Offset.zero,
          ),
        ],
      );

  /// Square terminal field matching this row’s spectrum.
  InputDecoration inputFieldDecoration({
    String? hint,
    TextStyle? hintStyle,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: hintStyle,
      filled: true,
      fillColor: blockBg,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: borderFocus, width: 1.4),
      ),
    );
  }
}

class RainbowPanel extends StatelessWidget {
  const RainbowPanel({
    super.key,
    required this.band,
    required this.child,
  });

  final int band;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = RainbowStyle.band(band);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            r.blockBg,
            r.blockBg.withValues(alpha: 0.45),
            r.blockBg.withValues(alpha: 0.2),
          ],
          stops: const [0, 0.45, 1],
        ),
        border: Border(
          left: BorderSide(color: r.borderFocus, width: 3),
          top: BorderSide(color: r.border, width: 0.5),
          bottom: BorderSide(color: r.border, width: 0.5),
        ),
      ),
      child: child,
    );
  }
}

