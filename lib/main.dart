import 'dart:async' show unawaited;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chord_engine.dart';
import 'midi_export.dart';
import 'piano_keyboard.dart';
import 'section_card.dart';
import 'theme.dart';

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
      theme: ChordLensTheme.light(),
      darkTheme: ChordLensTheme.dark(),
      themeMode: ThemeMode.system,
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

  /// Capo-style transposition: sounding pitch +n semitones (0–11).
  int _capoSemitones = 0;

  List<PluckedNote> _transposedPluckedNotes(List<PluckedNote> base, int semis) {
    if (semis == 0) {
      return base;
    }
    return [
      for (final n in base) PluckedNote(n.midi + semis, n.stringIndex, n.fret),
    ];
  }

  void _onTuningRowHorizontalDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity;
    if (v == null) {
      return;
    }
    const threshold = 280.0;
    if (v > threshold && _capoSemitones < 11) {
      _capoSemitones++;
      _recompute();
    } else if (v < -threshold && _capoSemitones > 0) {
      _capoSemitones--;
      _recompute();
    }
  }

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
              kPitchClassNames[pitchClassFromMidi(
                kTuningPresets[0].openStringMidis[i],
              )];
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
        final baseNotes = tabToNotes(
          _tabController.text.trim().toLowerCase().replaceAll('X', 'x'),
          open,
        );
        _notes = _transposedPluckedNotes(baseNotes, _capoSemitones);
        if (_notes.isEmpty) {
          _interpretations = [];
        } else {
          _interpretations = identifyChords(_notes);
          _pianoRange = pianoOctaveRange(pianoChordHighlightMidis(_notes));
        }
      } catch (e) {
        _tuningError = e.toString();
        _notes = [];
        _interpretations = [];
      }
    });
  }

  /// Safe base name for export (no path separators or illegal filename chars).
  String _sanitizeMidiBaseName(String raw) {
    var s = raw.trim();
    if (s.isEmpty) {
      return 'chord_lens_voicing';
    }
    s = s.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
    s = s.replaceAll(RegExp(r'\s+'), '_');
    if (s.isEmpty || s == '.' || s == '..') {
      return 'chord_lens_voicing';
    }
    return s.length > 80 ? s.substring(0, 80) : s;
  }

  String _midiExportBaseName() {
    if (_interpretations.isNotEmpty) {
      return _sanitizeMidiBaseName(_interpretations.first.displayName);
    }
    final t = _tabController.text.trim().replaceAll(RegExp(r'[^0-9,xX]'), '');
    if (t.isNotEmpty) {
      return _sanitizeMidiBaseName('tab_$t');
    }
    return 'chord_lens_voicing';
  }

  Future<void> _exportChordMidi(BuildContext context) async {
    if (_notes.isEmpty) return;
    final midis = _notes.map((e) => e.midi).toList();
    final bytes = buildChordSmf0(midis);
    final base = _midiExportBaseName();
    try {
      await FileSaver.instance.saveFile(
        name: base,
        bytes: bytes,
        fileExtension: 'midi',
        mimeType: MimeType.custom,
        customMimeType: 'audio/midi',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported $base.midi — import or drag into your DAW'),
          duration: const Duration(seconds: 3),
        ),
      );
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
      final heard = _transposedPluckedNotes(notes, _capoSemitones);
      final interp = identifyChords(heard);
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
        selection: TextSelection.collapsed(offset: _slotTabTexts[i].length),
      );
    });
    _tabController.addListener(_recompute);
    _recompute();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('ChordLens')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionCard(
                          title: 'Tuning',
                          trailing: _capoSemitones > 0
                              ? Text(
                                  '+$_capoSemitones',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: scheme.primary,
                                      ),
                                )
                              : null,
                          child: _tuningBlock(context),
                        ),
                        SectionCard(title: 'Tab', child: _tabField()),
                        SectionCard(title: 'Chord', child: _chordNameBlock()),
                        SectionCard(
                          title: 'Piano',
                          trailing:
                              _notes.isNotEmpty && _interpretations.isNotEmpty
                              ? TextButton(
                                  onPressed: () => _exportChordMidi(context),
                                  child: const Text('Export'),
                                )
                              : null,
                          child: _notes.isEmpty
                              ? Text(
                                  _tabController.text.isEmpty
                                      ? 'Waiting for a tab.'
                                      : 'No sounding notes for this tab.',
                                  style: muted,
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        style: muted,
                                        children: [
                                          const TextSpan(text: 'Notes  '),
                                          TextSpan(
                                            text: _notes
                                                .map(
                                                  (e) => noteNameWithOctave(
                                                    e.midi,
                                                  ),
                                                )
                                                .join('  '),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: scheme.onSurface,
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
                                            : _interpretations
                                                  .first
                                                  .rootPitchClass;
                                        return PianoKeyboard(
                                          minMidi: minM,
                                          maxMidi: maxM,
                                          chordMidis: set,
                                          rootPitchClass: root,
                                          focusMidi: _notes.isNotEmpty
                                              ? _notes.first.midi
                                              : null,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                        ),
                        _chordSessionSlotsBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabField() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Six frets, low string to high. Example: x32010',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tabController,
          maxLength: 40,
          style: TextStyle(
            fontFamily: ChordLensTheme.fontFamily,
            fontSize: 22,
            letterSpacing: 1.5,
            color: scheme.onSurface,
          ),
          cursorColor: scheme.primary,
          cursorWidth: 2,
          decoration: const InputDecoration(
            hintText: 'x32010',
            counterText: '',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9xX,\s]')),
            LengthLimitingTextInputFormatter(40),
          ],
          onChanged: (_) => _recompute(),
        ),
        if (_tabError != null) ...[
          const SizedBox(height: 6),
          Text(
            _tabError!,
            style: TextStyle(
              fontFamily: ChordLensTheme.fontFamily,
              color: scheme.error,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Widget _tuningBlock(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Theme.of(context).cardTheme.color ?? scheme.surface;
    final items = <DropdownMenuItem<String>>[
      for (final p in kTuningPresets)
        DropdownMenuItem(value: p.id, child: Text(p.label)),
      const DropdownMenuItem(value: _customId, child: Text('Custom')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onHorizontalDragEnd: _onTuningRowHorizontalDragEnd,
          behavior: HitTestBehavior.opaque,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: card,
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _presetId,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(8),
                  dropdownColor: card,
                  style: TextStyle(
                    fontFamily: ChordLensTheme.fontFamily,
                    color: scheme.onSurface,
                    fontSize: 16,
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
          ),
        ),
        if (_presetId == _customId) ...[
          const SizedBox(height: 10),
          Text(
            'Open strings, low to high. Example: E A D G B E',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(6, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  child: TextField(
                    controller: _customTuning[i],
                    onChanged: (_) {
                      _recompute();
                      unawaited(_saveTuningPrefs());
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: ChordLensTheme.fontFamily,
                      fontSize: 16,
                      color: scheme.onSurface,
                    ),
                    decoration: InputDecoration(labelText: '${i + 1}'),
                  ),
                ),
              );
            }),
          ),
          if (_customTuningError != null) ...[
            const SizedBox(height: 6),
            Text(
              _customTuningError!,
              style: TextStyle(
                fontFamily: ChordLensTheme.fontFamily,
                color: scheme.error,
                fontSize: 13,
              ),
            ),
          ],
        ],
        if (_tuningError != null) ...[
          const SizedBox(height: 6),
          Text(
            _tuningError!,
            style: TextStyle(
              fontFamily: ChordLensTheme.fontFamily,
              color: scheme.error,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Widget _chordNameBlock() {
    final scheme = Theme.of(context).colorScheme;
    final empty = Text(
      '—',
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(color: scheme.onSurfaceVariant),
    );
    if (_tabError != null && _tabController.text.isNotEmpty) {
      return empty;
    }
    if (_notes.isEmpty || _interpretations.isEmpty) {
      return empty;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(_interpretations.length, (i) {
        final c = _interpretations[i];
        final isHead = i == 0;
        return Padding(
          padding: EdgeInsets.only(bottom: isHead ? 4 : 2),
          child: Text(
            c.displayName,
            style: isHead
                ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  )
                : Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
          ),
        );
      }),
    );
  }

  Widget _chordSessionSlotsBar() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Chord sets',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _chordSessionSlot(i, scheme)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _chordSessionSlot(int i, ColorScheme scheme) {
    final selected = i == _activeSlot;
    final label = _chordLabelForSlot(i);
    final border = selected ? scheme.onSurface : scheme.outlineVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.26),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: selected ? scheme.surface : scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border, width: selected ? 2.5 : 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _selectSlot(i),
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label ?? '${i + 1}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontFamily: ChordLensTheme.fontFamily,
                      color: label == null
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
