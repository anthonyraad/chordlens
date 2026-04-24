import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_clipboard/super_clipboard.dart';

import 'chord_engine.dart';
import 'midi_export.dart';
import 'piano_keyboard.dart';
import 'rainbow_ui.dart';
import 'terminal_ui.dart';

/// `public.midi` / common MIMEs for DAWs that read MIDI from the clipboard.
const SimpleFileFormat _kClipboardSmf = SimpleFileFormat(
  uniformTypeIdentifiers: ['public.midi'],
  mimeTypes: ['audio/midi', 'application/x-midi', 'audio/x-midi'],
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChordLensApp());
}

class ChordLensApp extends StatelessWidget {
  const ChordLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChordLens',
      debugShowCheckedModeBanner: false,
      theme: TerminalTheme.data(),
      home: const ChordLensHome(),
    );
  }
}

class ChordLensHome extends StatefulWidget {
  const ChordLensHome({super.key});

  @override
  State<ChordLensHome> createState() => _ChordLensHomeState();
}

class _ChordLensHomeState extends State<ChordLensHome> {
  static const _customId = 'custom';
  static const _kPrefTuningPreset = 'chordlens_tuning_preset_id';
  static const _kPrefTuningCustomPrefix = 'chordlens_tuning_custom_';

  final TextEditingController _tabController = TextEditingController();
  final List<TextEditingController> _customTuning = List.generate(
    6,
    (_) => TextEditingController(),
  );

  String _presetId = 'std';
  String? _tabError;
  String? _tuningError;
  String? _customTuningError;

  /// One tab + derived UI per session slot (in-memory for app lifetime).
  final List<String> _slotTabTexts = List<String>.generate(4, (_) => '');
  int _activeSlot = 0;

  List<PluckedNote> _notes = [];
  List<ChordInterpretation> _interpretations = [];
  (int, int) _pianoRange = (2, 4);

  @override
  void initState() {
    super.initState();
    _applyPresetStrings(kTuningPresets[0].openStringMidis);
    _tabController.addListener(_recompute);
    unawaited(_loadTuningFromPrefs());
  }

  Future<void> _loadTuningFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    final id = prefs.getString(_kPrefTuningPreset);
    if (id == null) {
      _recompute();
      return;
    }
    if (id == _customId) {
      setState(() {
        _presetId = _customId;
        for (var i = 0; i < 6; i++) {
          _customTuning[i].text =
              prefs.getString('$_kPrefTuningCustomPrefix$i') ??
                  kPitchClassNames[
                      pitchClassFromMidi(kTuningPresets[0].openStringMidis[i])];
        }
      });
      _recompute();
      return;
    }
    final preset = presetById(id);
    if (preset == null) {
      setState(() {
        _presetId = 'std';
        _applyPresetStrings(presetById('std')!.openStringMidis);
      });
      _recompute();
      return;
    }
    setState(() {
      _presetId = id;
      _applyPresetStrings(preset.openStringMidis);
    });
    _recompute();
  }

  Future<void> _saveTuningPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefTuningPreset, _presetId);
    if (_presetId == _customId) {
      for (var i = 0; i < 6; i++) {
        await prefs.setString(
          '$_kPrefTuningCustomPrefix$i',
          _customTuning[i].text.trim(),
        );
      }
    }
  }

  void _applyPresetStrings(List<int> openMidis) {
    for (var i = 0; i < 6; i++) {
      final p = pitchClassFromMidi(openMidis[i]);
      _customTuning[i].text = kPitchClassNames[p];
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_recompute);
    _tabController.dispose();
    for (final c in _customTuning) {
      c.dispose();
    }
    super.dispose();
  }

  List<int> _openMidis() {
    if (_presetId == _customId) {
      final out = <int>[];
      for (var i = 0; i < 6; i++) {
        final p = parseNoteToPitchClass(_customTuning[i].text);
        if (p == null) return [];
        out.add(midiFor(kDefaultStringOctaves[i], p));
      }
      return out;
    }
    return presetById(_presetId)!.openStringMidis;
  }

  void _recompute() {
    setState(() {
      _slotTabTexts[_activeSlot] = _tabController.text;
      _tuningError = null;
      _customTuningError = null;
      _tabError = validateTabString(_tabController.text);
      if (_presetId == _customId) {
        for (var i = 0; i < 6; i++) {
          if (parseNoteToPitchClass(_customTuning[i].text) == null) {
            _customTuningError =
                'String ${i + 1} (low → high): use C, C#, Bb, etc.';
            _notes = [];
            _interpretations = [];
            return;
          }
        }
        _customTuningError = null;
      }
      if (_tabError != null) {
        _notes = [];
        _interpretations = [];
        return;
      }
      if (_tabController.text.trim().isEmpty) {
        _notes = [];
        _interpretations = [];
        return;
      }
      if (_openMidis().isEmpty) {
        _tuningError = 'Invalid tuning.';
        _notes = [];
        _interpretations = [];
        return;
      }
      try {
        final open = _openMidis();
        if (open.length != 6) {
          _tuningError = 'Need 6 string pitches.';
          return;
        }
        _notes = tabToNotes(
          _tabController.text.trim().toLowerCase().replaceAll('X', 'x'),
          open,
        );
        if (_notes.isEmpty) {
          _interpretations = [];
        } else {
          _interpretations = identifyChords(_notes);
          _pianoRange = pianoOctaveRange(
            pianoChordHighlightMidis(_notes),
          );
        }
      } catch (e) {
        _tuningError = e.toString();
        _notes = [];
        _interpretations = [];
      }
    });
  }

  Future<void> _copyPianoMapMidi(BuildContext context) async {
    if (_notes.isEmpty) return;
    final midis = _notes.map((e) => e.midi).toList();
    final preview = midis.join(' ');
    var wroteSmf = false;
    final bytes = buildChordSmf0(midis);

    final system = SystemClipboard.instance;
    if (system != null) {
      try {
        final item = DataWriterItem(
          suggestedName: 'chordlens_voicing.mid',
        );
        // Android: include plain text alongside file bytes (super_clipboard).
        item.add(Formats.plainText(preview));
        item.add(_kClipboardSmf(bytes));
        await system.write([item]);
        wroteSmf = true;
      } on Object {
        // Fall back to text below.
      }
    }
    if (!wroteSmf) {
      await Clipboard.setData(ClipboardData(text: preview));
    }
    if (!context.mounted) return;
    final msg = wroteSmf
        ? 'Copied voicing as a .mid on the clipboard — paste in your DAW (also: $preview)'
        : (kIsWeb
            ? 'Copied MIDI numbers only ($preview). Browsers often cannot put a .mid on the clipboard — use the desktop app for full DAW paste.'
            : 'Copied MIDI numbers only ($preview). DAWs may still accept text; a .mid file on the clipboard was unavailable.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.jetBrainsMono(fontSize: 12),
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: TerminalColors.panel,
      ),
    );
  }

  /// Chord name for a slot from its stored tab and current tuning (no side effects).
  String? _chordLabelForSlot(int slotIndex) {
    final t = _slotTabTexts[slotIndex].trim();
    if (t.isEmpty) {
      return null;
    }
    if (validateTabString(t) != null) {
      return null;
    }
    if (_presetId == _customId) {
      for (var j = 0; j < 6; j++) {
        if (parseNoteToPitchClass(_customTuning[j].text) == null) {
          return null;
        }
      }
    }
    final open = _openMidis();
    if (open.isEmpty || open.length != 6) {
      return null;
    }
    try {
      final norm = t.toLowerCase().replaceAll('X', 'x');
      final notes = tabToNotes(norm, open);
      if (notes.isEmpty) {
        return null;
      }
      final interp = identifyChords(notes);
      if (interp.isEmpty) {
        return null;
      }
      return interp.first.displayName;
    } catch (_) {
      return null;
    }
  }

  void _selectSlot(int i) {
    if (i == _activeSlot) {
      return;
    }
    _tabController.removeListener(_recompute);
    setState(() {
      _slotTabTexts[_activeSlot] = _tabController.text;
      _activeSlot = i;
      _tabController.value = TextEditingValue(
        text: _slotTabTexts[i],
        selection: TextSelection.collapsed(
          offset: _slotTabTexts[i].length,
        ),
      );
    });
    _tabController.addListener(_recompute);
    _recompute();
  }

  @override
  Widget build(BuildContext context) {
    final rBar = RainbowStyle.band(0);
    final r1 = RainbowStyle.band(1);
    final r2 = RainbowStyle.band(2);
    final r3 = RainbowStyle.band(3);
    final r4 = RainbowStyle.band(4);
    final rSlots = RainbowStyle.band(5);
    return Scaffold(
      backgroundColor: TerminalColors.bg,
      appBar: AppBar(
        backgroundColor: rBar.blockBg,
        title: CrtText(
          text: r'> CHORDLENS.EXE',
          glowColor: rBar.titleGlow,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: rBar.textBright,
          ),
        ),
        iconTheme: IconThemeData(color: rBar.text),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RainbowPanel(
                        band: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('> TUNING', style: r1.sectionLabel()),
                            const SizedBox(height: 8),
                            _tuningBlock(context, r1),
                          ],
                        ),
                      ),
                      RainbowPanel(
                        band: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              r'> TAB  (6 char, L→H)',
                              style: r2.sectionLabel(),
                            ),
                            const SizedBox(height: 8),
                            _tabField(r2),
                          ],
                        ),
                      ),
                      RainbowPanel(
                        band: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('> CHORD_ID', style: r3.sectionLabel()),
                            const SizedBox(height: 8),
                            _chordNameBlock(r3),
                          ],
                        ),
                      ),
                      RainbowPanel(
                        band: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    '> PIANO_MAP',
                                    style: r4.sectionLabel(),
                                  ),
                                ),
                                if (_notes.isNotEmpty && _interpretations.isNotEmpty)
                                  TextButton(
                                    onPressed: () => _copyPianoMapMidi(context),
                                    style: TextButton.styleFrom(
                                      foregroundColor: r4.textDim,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 0,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      '(copy)',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        color: r4.textBright,
                                        decoration: TextDecoration.underline,
                                        decorationColor: r4.textDim,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_notes.isEmpty)
                              Text(
                                _tabController.text.isEmpty
                                    ? r'[ ] Awaiting input...  _'
                                    : r'[ ] No open strings, or run diagnostics above.',
                                style: GoogleFonts.jetBrainsMono(
                                  color: r4.textDim,
                                  fontSize: 13,
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        color: r4.text,
                                      ),
                                      children: [
                                        const TextSpan(text: 'Notes: '),
                                        TextSpan(
                                          text: _notes
                                              .map(
                                                (e) => noteNameWithOctave(e.midi),
                                              )
                                              .join('  '),
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 12,
                                            color: r4.textBright,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  LayoutBuilder(
                                    builder: (context, c) {
                                      final o = _pianoRange;
                                      final minM = midiFor(o.$1, 0);
                                      final maxM = midiFor(o.$2, 11);
                                      final set = pianoChordHighlightMidis(
                                        _notes,
                                      );
                                      final root = _interpretations.isEmpty
                                          ? null
                                          : _interpretations.first
                                              .rootPitchClass;
                                      return PianoKeyboard(
                                        minMidi: minM,
                                        maxMidi: maxM,
                                        chordMidis: set,
                                        rootPitchClass: root,
                                        accent: r4,
                                        focusMidi: _notes.isNotEmpty
                                            ? _notes.first.midi
                                            : null,
                                      );
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _chordSessionSlotsBar(rSlots),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabField(RainbowStyle r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _tabController,
          maxLength: 40,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 20,
            letterSpacing: 2,
            color: r.textBright,
          ),
          cursorColor: r.borderFocus,
          cursorWidth: 2,
          decoration: r.inputFieldDecoration(
            hint: 'x32010',
            hintStyle: GoogleFonts.jetBrainsMono(
              color: r.hint,
              fontSize: 20,
              letterSpacing: 2,
            ),
          ).copyWith(
            isDense: true,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'[0-9xX,\s]'),
            ),
            LengthLimitingTextInputFormatter(40),
          ],
          onChanged: (_) => _recompute(),
        ),
        if (_tabError != null) ...[
          const SizedBox(height: 6),
          Text(
            '[ERR] $_tabError',
            style: GoogleFonts.jetBrainsMono(
              color: TerminalColors.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _tuningBlock(BuildContext context, RainbowStyle r) {
    final items = <DropdownMenuItem<String>>[
      for (final p in kTuningPresets)
        DropdownMenuItem(
          value: p.id,
          child: Text(
            p.label,
            style: GoogleFonts.jetBrainsMono(
              color: r.text,
              fontSize: 12,
            ),
          ),
        ),
      DropdownMenuItem(
        value: _customId,
        child: Text(
          r'[ Custom — per string ]',
          style: GoogleFonts.jetBrainsMono(
            color: r.text,
            fontSize: 12,
          ),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          decoration: BoxDecoration(
            color: r.blockBg,
            border: Border.all(
              color: r.border,
            ),
            borderRadius: BorderRadius.zero,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _presetId,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: r.textBright,
              ),
              itemHeight: 48,
              dropdownColor: r.blockBg,
              style: GoogleFonts.jetBrainsMono(
                color: r.text,
                fontSize: 12,
              ),
              items: items,
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _presetId = v;
                  if (v != _customId) {
                    _applyPresetStrings(presetById(v)!.openStringMidis);
                    _customTuningError = null;
                  }
                  _recompute();
                });
                unawaited(_saveTuningPrefs());
              },
            ),
          ),
        ),
        if (_presetId == _customId) ...[
          const SizedBox(height: 10),
          Text(
            r'// Open strings, low to high. E.g. E A D G B E',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: r.hint,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(6, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 3,
                    right: i == 5 ? 0 : 0,
                  ),
                  child: TextField(
                    controller: _customTuning[i],
                    onChanged: (_) {
                      _recompute();
                      unawaited(_saveTuningPrefs());
                    },
                    textAlign: TextAlign.center,
                    cursorColor: r.borderFocus,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: r.textBright,
                    ),
                    decoration: r.inputFieldDecoration().copyWith(
                      labelText: 'S${i + 1}',
                      labelStyle: GoogleFonts.jetBrainsMono(
                        color: r.textBright,
                        fontSize: 10,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_customTuningError != null) ...[
            const SizedBox(height: 6),
            Text(
              '[ERR] $_customTuningError',
              style: GoogleFonts.jetBrainsMono(
                color: TerminalColors.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
        if (_tuningError != null) ...[
          const SizedBox(height: 6),
          Text(
            '[ERR] $_tuningError',
            style: GoogleFonts.jetBrainsMono(
              color: TerminalColors.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _chordNameBlock(RainbowStyle r) {
    if (_tabError != null && _tabController.text.isNotEmpty) {
      return Text(
        '[ -- ]',
        style: GoogleFonts.jetBrainsMono(
          color: r.hint,
          fontSize: 14,
        ),
      );
    }
    if (_notes.isEmpty) {
      return Text(
        '[ -- ]',
        style: GoogleFonts.jetBrainsMono(
          color: r.hint,
          fontSize: 14,
        ),
      );
    }
    if (_interpretations.isEmpty) {
      return Text(
        '[ -- ]',
        style: GoogleFonts.jetBrainsMono(
          color: r.hint,
          fontSize: 14,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(_interpretations.length, (i) {
        final c = _interpretations[i];
        final isHead = i == 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: r.blockBg,
              border: Border.all(
                color: isHead ? r.borderFocus : r.border,
                width: isHead ? 1.2 : 0.8,
              ),
              borderRadius: BorderRadius.zero,
            ),
            child: Text(
              isHead ? '>> ${c.displayName}' : '   ${c.displayName}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: isHead ? 18 : 13,
                fontWeight: isHead ? FontWeight.w600 : FontWeight.w400,
                color: isHead ? r.textBright : r.text,
                letterSpacing: 0.2,
                height: 1.25,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _chordSessionSlotsBar(RainbowStyle r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('> CHORD_SETS', style: r.sectionLabel()),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _chordSessionSlot(i, r),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _chordSessionSlot(int i, RainbowStyle r) {
    final selected = i == _activeSlot;
    final label = _chordLabelForSlot(i);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectSlot(i),
        borderRadius: BorderRadius.zero,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: const EdgeInsets.all(6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: r.blockBg,
              border: Border.all(
                color: selected ? r.borderFocus : r.border,
                width: selected ? 1.6 : 0.9,
              ),
              borderRadius: BorderRadius.zero,
            ),
            child: label == null
                ? const SizedBox.shrink()
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      style: GoogleFonts.jetBrainsMono(
                        color: r.textBright,
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
