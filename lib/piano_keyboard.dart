// Minimal horizontal piano for chord visualization.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'chord_engine.dart';
import 'rainbow_ui.dart';

bool _isBlackPc(int pc) {
  return const {1, 3, 6, 8, 10}.contains(pc % 12);
}

class _PianoLayout {
  _PianoLayout._();

  static const whiteW = 32.0;
  static const blackW = 20.0;

  /// Left-edge offset to bring [targetMidi]’s key near the start of the strip.
  static double scrollOffsetToShowKey({
    required int minMidi,
    required int maxMidi,
    required int targetMidi,
  }) {
    if (targetMidi < minMidi || targetMidi > maxMidi) {
      return 0;
    }
    if (!_isBlackPc(pitchClassFromMidi(targetMidi))) {
      var idx = 0;
      for (var k = minMidi; k <= maxMidi; k++) {
        if (_isBlackPc(pitchClassFromMidi(k))) {
          continue;
        }
        if (k == targetMidi) {
          return idx * whiteW;
        }
        idx++;
      }
      return 0;
    }
    var prevW = minMidi;
    for (var k = targetMidi - 1; k >= minMidi; k--) {
      if (!_isBlackPc(pitchClassFromMidi(k))) {
        prevW = k;
        break;
      }
    }
    var wIdx = 0;
    for (var k = minMidi; k < prevW; k++) {
      if (!_isBlackPc(pitchClassFromMidi(k))) {
        wIdx++;
      }
    }
    return (wIdx + 0.68) * whiteW - blackW / 2;
  }
}

/// Renders a horizontal keyboard covering [minMidi, maxMidi] (inclusive).
class PianoKeyboard extends StatefulWidget {
  const PianoKeyboard({
    super.key,
    required this.minMidi,
    required this.maxMidi,
    required this.chordMidis,
    this.rootPitchClass,
    required this.accent,
    this.focusMidi,
  });

  final int minMidi;
  final int maxMidi;
  final Set<int> chordMidis;
  final int? rootPitchClass;
  final RainbowStyle accent;

  /// Low string = first in tab; scroll so this key is near the left (mobile).
  final int? focusMidi;

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus());
  }

  @override
  void didUpdateWidget(PianoKeyboard old) {
    super.didUpdateWidget(old);
    if (old.minMidi != widget.minMidi ||
        old.maxMidi != widget.maxMidi ||
        old.focusMidi != widget.focusMidi) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToFocus() {
    final m = widget.focusMidi;
    if (m == null) {
      return;
    }
    if (m < widget.minMidi || m > widget.maxMidi) {
      return;
    }
    if (!_scroll.hasClients) {
      return;
    }
    final offset = _PianoLayout.scrollOffsetToShowKey(
      minMidi: widget.minMidi,
      maxMidi: widget.maxMidi,
      targetMidi: m,
    );
    final pos = _scroll.position;
    final max = pos.maxScrollExtent;
    const margin = 8.0;
    _scroll.animateTo(
      (offset - margin).clamp(0.0, max),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.minMidi > widget.maxMidi) {
      return const SizedBox.shrink();
    }

    const labelH = 22.0;
    const keyH = 110.0;
    // Black key caps are shorter, like a real keyboard (overhang only).
    const blackKeyCapH = keyH * 0.57;
    const whiteW = _PianoLayout.whiteW;
    const blackW = _PianoLayout.blackW;

    final whiteMidis = <int>[];
    for (var m = widget.minMidi; m <= widget.maxMidi; m++) {
      if (!_isBlackPc(pitchClassFromMidi(m))) {
        whiteMidis.add(m);
      }
    }
    if (whiteMidis.isEmpty) {
      return const SizedBox.shrink();
    }

    final width = whiteW * whiteMidis.length;
    int whitesBefore(int midi) {
      var c = 0;
      for (var k = widget.minMidi; k < midi; k++) {
        if (!_isBlackPc(pitchClassFromMidi(k))) {
          c++;
        }
      }
      return c;
    }

    int prevWhiteFromBlack(int m) {
      for (var k = m - 1; k >= widget.minMidi; k--) {
        if (!_isBlackPc(pitchClassFromMidi(k))) {
          return k;
        }
      }
      return widget.minMidi;
    }

    final blackWidgets = <Widget>[];
    for (var m = widget.minMidi; m <= widget.maxMidi; m++) {
      if (!_isBlackPc(pitchClassFromMidi(m))) {
        continue;
      }
      final left = prevWhiteFromBlack(m);
      final wIdx = whitesBefore(left);
      final x = (wIdx + 0.68) * whiteW - blackW / 2;
      blackWidgets.add(
        Positioned(
          left: x.clamp(0, width - blackW),
          top: 0,
          child: _PianoKey(
            midi: m,
            isBlack: true,
            chordMidis: widget.chordMidis,
            rootPitchClass: widget.rootPitchClass,
            accent: widget.accent,
            name: _labelFor(m, widget.chordMidis),
            width: blackW,
            keyBodyHeight: keyH,
            keyCapHeight: blackKeyCapH,
            labelHeight: labelH,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          height: keyH + labelH,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Row(
                children: [
                  for (final m in whiteMidis)
                    _PianoKey(
                      midi: m,
                      isBlack: false,
                      chordMidis: widget.chordMidis,
                      rootPitchClass: widget.rootPitchClass,
                      accent: widget.accent,
                      name: _labelFor(m, widget.chordMidis),
                      width: whiteW,
                      keyBodyHeight: keyH,
                      keyCapHeight: keyH,
                      labelHeight: labelH,
                    ),
                ],
              ),
              ...blackWidgets,
            ],
          ),
        ),
      ),
    );
  }

  String? _labelFor(int midi, Set<int> active) {
    if (!active.contains(midi)) {
      return null;
    }
    return nameForPitchClass(pitchClassFromMidi(midi));
  }
}

class _PianoKey extends StatelessWidget {
  const _PianoKey({
    required this.midi,
    required this.isBlack,
    required this.chordMidis,
    this.rootPitchClass,
    required this.accent,
    this.name,
    required this.width,
    required this.keyBodyHeight,
    required this.keyCapHeight,
    this.labelHeight = 22,
  });

  final int midi;
  final bool isBlack;
  final Set<int> chordMidis;
  final int? rootPitchClass;
  final RainbowStyle accent;
  final String? name;
  final double width;
  /// White keys: full; black keys: full column height to align with whites.
  final double keyBodyHeight;
  /// Painted key only (shorter for black).
  final double keyCapHeight;
  final double labelHeight;

  @override
  Widget build(BuildContext context) {
    final inChord = chordMidis.contains(midi);
    final pc = pitchClassFromMidi(midi);
    final isRoot =
        inChord && rootPitchClass != null && (pc == rootPitchClass! % 12);

    // Same hue as PIANO row, darker when idle, brighter in chord
    const idleW = Color(0xFF050508);
    const idleB = Color(0xFF020202);
    final inFill = inChord
        ? (isRoot
            ? Color.lerp(accent.blockBg, accent.border, 0.35)!
            : Color.lerp(accent.blockBg, accent.border, 0.2)!)
        : (isBlack ? idleB : idleW);
    final edge = inChord
        ? (isRoot ? accent.borderFocus : accent.textDim)
        : (isBlack
            ? const Color(0xFF3D3D48)
            : const Color(0xFF1A1A1E));
    return SizedBox(
      width: width,
      height: keyBodyHeight + labelHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: width,
            height: keyCapHeight,
            decoration: BoxDecoration(
              color: inFill,
              border: Border(
                top: BorderSide(
                  color: edge,
                  width: inChord && isRoot ? 1.4 : 0.8,
                ),
                left: BorderSide(
                  color: edge,
                  width: inChord && isRoot ? 1.4 : 0.5,
                ),
                right: BorderSide(
                  color: edge,
                  width: inChord && isRoot ? 1.4 : 0.5,
                ),
                bottom: isBlack
                    ? BorderSide(
                        color: inChord
                            ? edge
                            : const Color(0xFF151518),
                        width: 0.9,
                      )
                    : BorderSide(
                        color: edge,
                        width: inChord && isRoot ? 1.4 : 0.6,
                      ),
              ),
              borderRadius: isBlack
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(2),
                    )
                  : BorderRadius.zero,
            ),
          ),
          if (keyBodyHeight > keyCapHeight)
            SizedBox(height: keyBodyHeight - keyCapHeight),
          if (inChord && name != null)
            Text(
              name!,
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                color: isRoot ? accent.textBright : accent.text,
                fontSize: 9,
                fontWeight: isRoot ? FontWeight.w600 : FontWeight.w400,
              ),
            )
          else
            SizedBox(height: labelHeight),
        ],
      ),
    );
  }
}
