// Chord computation: tab + tuning -> notes, chord names, ranking.
// Pure Dart, no external music libraries.

import 'dart:math' as math;

// --- Note / pitch class ---

const List<String> kPitchClassNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];

int pitchClassFromMidi(int m) => m % 12;

/// C4 = 60: `12 * o + 12 + p` for octave o and pitch class p (0 = C, … 11 = B).
int midiFor(int octave, int pitchClass) => 12 * octave + 12 + pitchClass;

String nameForPitchClass(int pc) => kPitchClassNames[pc % 12];

/// Scientific octave matching [midiFor], e.g. C4 = 60, B2 = 47.
int scientificOctaveForMidi(int m) {
  final p = m % 12;
  return (m - 12 - p) ~/ 12;
}

String noteNameWithOctave(int midi) =>
    '${nameForPitchClass(pitchClassFromMidi(midi))}${scientificOctaveForMidi(midi)}';

/// Parses a note like "Eb", "B", "F#", "Bb" (one letter, optional # or b).
int? parseNoteToPitchClass(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  const letterPc = {
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
    'A': 9,
    'B': 11,
  };
  final l0 = t[0].toUpperCase();
  if (!letterPc.containsKey(l0)) return null;
  final pc0 = letterPc[l0]!;
  if (t.length == 1) return pc0;
  if (t.length != 2) return null;
  if (t[1] == '#') return (pc0 + 1) % 12;
  if (t[1] == 'b') return (pc0 + 11) % 12;
  return null;
}

/// Per-string [low→high] octaves (typical guitar, EADGBE).
const List<int> kDefaultStringOctaves = [2, 2, 3, 3, 3, 4];

List<int> openMidisForPitchClasses(List<int> pitchClasses) {
  assert(pitchClasses.length == 6);
  return List<int>.generate(
    6,
    (i) => midiFor(kDefaultStringOctaves[i], pitchClasses[i] % 12),
  );
}

// --- Presets ---

class TuningPreset {
  const TuningPreset(this.id, this.label, this.openStringMidis);
  final String id;
  final String label;
  final List<int> openStringMidis;
}

int _p(String s) {
  final r = parseNoteToPitchClass(s);
  if (r == null) throw ArgumentError('Invalid note: $s');
  return r;
}

/// Common tunings, low string → high string.
final List<TuningPreset> kTuningPresets = [
  TuningPreset('std', 'Standard (E A D G B E)', openMidisForPitchClasses(
    [_p('E'), _p('A'), _p('D'), _p('G'), _p('B'), _p('E')],
  )),
  TuningPreset('dropd', 'Drop D (D A D G B E)', openMidisForPitchClasses(
    [_p('D'), _p('A'), _p('D'), _p('G'), _p('B'), _p('E')],
  )),
  TuningPreset('openg', 'Open G (D G D G B D)', openMidisForPitchClasses(
    [_p('D'), _p('G'), _p('D'), _p('G'), _p('B'), _p('D')],
  )),
  TuningPreset('opend', 'Open D (D A D F# A D)', openMidisForPitchClasses(
    [_p('D'), _p('A'), _p('D'), _p('F#'), _p('A'), _p('D')],
  )),
  TuningPreset('opene', 'Open E (E B E G# B E)', openMidisForPitchClasses(
    [_p('E'), _p('B'), _p('E'), _p('G#'), _p('B'), _p('E')],
  )),
  TuningPreset('openc', 'Open C (F A C G C E)', openMidisForPitchClasses(
    [_p('F'), _p('A'), _p('C'), _p('G'), _p('C'), _p('E')],
  )),
  TuningPreset('dadgad', 'DADGAD (D A D G A D)', openMidisForPitchClasses(
    [_p('D'), _p('A'), _p('D'), _p('G'), _p('A'), _p('D')],
  )),
  TuningPreset('halfdown', 'Half step down (Eb Ab Db Gb Bb Eb)', openMidisForPitchClasses(
    [_p('Eb'), _p('Ab'), _p('Db'), _p('Gb'), _p('Bb'), _p('Eb')],
  )),
  TuningPreset('fulldown', 'Full step down (D G C F A D)', openMidisForPitchClasses(
    [_p('D'), _p('G'), _p('C'), _p('F'), _p('A'), _p('D')],
  )),
];

TuningPreset? presetById(String id) {
  for (final p in kTuningPresets) {
    if (p.id == id) return p;
  }
  return null;
}

// --- Tab validation ---

/// Maximum fret when using comma-separated or multi-digit values.
const int kMaxFret = 30;

String? validateTabString(String? input) {
  if (input == null) return null;
  final s = input.trim();
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    final parts = s.split(',').map((e) => e.trim()).toList();
    if (parts.length != 6) {
      return 'Use 6 comma-separated values (low → high)';
    }
    for (var i = 0; i < 6; i++) {
      final p = parts[i].toLowerCase();
      if (p.isEmpty) {
        return 'String ${i + 1}: empty (use x or a fret number).';
      }
      if (p == 'x') continue;
      if (!RegExp(r'^\d+$').hasMatch(p)) {
        return 'String ${i + 1}: use a number or x (muted).';
      }
      final v = int.parse(p);
      if (v < 0 || v > kMaxFret) {
        return 'String ${i + 1}: fret 0–$kMaxFret.';
      }
    }
    return null;
  }
  if (s.length != 6) {
    return 'Without commas, use exactly 6 characters (0–9 or x). '
        'Use commas for 10+';
  }
  final t = s.toLowerCase();
  for (var i = 0; i < 6; i++) {
    final c = t[i];
    if (c == 'x') continue;
    if (c.codeUnitAt(0) < 0x30 || c.codeUnitAt(0) > 0x39) {
      return 'String ${i + 1}: use a digit 0–9 or x (muted).';
    }
  }
  return null;
}

List<int?> _fretsFromNormalizedTab(String t) {
  if (t.contains(',')) {
    final parts = t.split(',').map((e) => e.trim()).toList();
    return List<int?>.generate(6, (i) {
      final p = parts[i].toLowerCase();
      if (p == 'x') return null;
      return int.parse(p);
    });
  }
  if (t.length != 6) {
    throw ArgumentError('Legacy tab must be 6 characters, got ${t.length}.');
  }
  final lo = t.toLowerCase();
  return List<int?>.generate(6, (i) {
    final c = lo[i];
    if (c == 'x') return null;
    return c.codeUnitAt(0) - 0x30;
  });
}

// --- Notes from tab ---

class PluckedNote {
  const PluckedNote(this.midi, this.stringIndex, this.fret);
  final int midi;
  final int stringIndex; // 0 = low, 5 = high
  final int? fret; // null = muted
  int get pitchClass => pitchClassFromMidi(midi);
}

List<PluckedNote> tabToNotes(String tab, List<int> openStringMidis) {
  if (openStringMidis.length != 6) {
    throw ArgumentError('Tuning must have 6 open-string MIDI values.');
  }
  final raw = tab.trim().replaceAll('X', 'x');
  final t = raw.contains(',') ? raw : raw.toLowerCase();
  final frets = _fretsFromNormalizedTab(t);
  final out = <PluckedNote>[];
  for (var s = 0; s < 6; s++) {
    final f = frets[s];
    if (f == null) continue;
    out.add(PluckedNote(openStringMidis[s] + f, s, f));
  }
  return out;
}

// --- Chord ID ---

class ChordInterpretation {
  const ChordInterpretation({
    required this.displayName,
    required this.rootPitchClass,
    required this.likelihood,
    required this.bassPitchClass,
    this.fullChordPcs,
  });
  final String displayName;
  final int rootPitchClass;
  final int bassPitchClass;
  final int likelihood;

  /// All pitch classes (0–11) in the named chord, or `null` when the piano
  /// should only reflect the plucked frets.
  final Set<int>? fullChordPcs;
}

String _r(int pc) => nameForPitchClass(pc);

int? _bassPitchClass(Iterable<PluckedNote> notes) {
  if (notes.isEmpty) return null;
  var m = 127;
  for (final n in notes) {
    if (n.midi < m) m = n.midi;
  }
  return pitchClassFromMidi(m);
}

class _Def {
  const _Def(this.suffix, this.sets, this.likelihood);
  final String suffix; // e.g. "m7" or "maj7"
  final List<Set<int>> sets; // match if equal to any
  final int likelihood;

  /// Largest template for this type (e.g. full 7th, not a shell), for piano.
  Set<int> get canonicalTones => sets
      .reduce((a, b) => a.length >= b.length ? a : b);
}

String _withSlash(String symbol, int root, int? bass) {
  if (bass == null || bass % 12 == root % 12) return symbol;
  return '$symbol/${_r(bass)}';
}

String _formatSymbol(int root, String suffix) {
  if (suffix == '(5)') {
    return '${_r(root)}(5)';
  }
  if (suffix.isEmpty) return _r(root);
  if (suffix.startsWith('(')) return '${_r(root)}$suffix';
  return '${_r(root)}$suffix';
}

List<_Def> _defs() {
  return [
    // Triads
    _Def('', [{0, 4, 7}], 960),
    _Def('m', [{0, 3, 7}], 940),
    _Def('dim', [{0, 3, 6}], 800),
    _Def('aug', [{0, 4, 8}], 820),
    _Def('sus2', [{0, 2, 7}], 900),
    _Def('sus4', [{0, 5, 7}], 900),
    _Def('(5)', [{0, 7}], 700),
    // 6
    _Def('6', [{0, 4, 7, 9}], 900),
    _Def('m6', [{0, 3, 7, 9}], 860),
    _Def('6/9', [{0, 2, 4, 7, 9}], 890),
    // 7
    _Def('7', [
      {0, 4, 7, 10},
      {0, 4, 10},
      {0, 7, 10},
    ], 920),
    _Def('maj7', [
      {0, 4, 7, 11},
      {0, 4, 11},
      {0, 7, 11},
    ], 920),
    _Def('m7', [
      {0, 3, 7, 10},
      {0, 3, 10},
    ], 900),
    _Def('m7b5', [
      {0, 3, 6, 10},
    ], 840),
    _Def('dim7', [
      {0, 3, 6, 9},
    ], 820),
    _Def('7b5', [{0, 4, 6, 10}], 780),
    _Def('7#5', [{0, 4, 8, 10}], 780),
    _Def('7sus4', [
      {0, 5, 7, 10},
    ], 860),
    // add / 9
    _Def('add9', [
      {0, 2, 4, 7},
    ], 900),
    _Def('madd9', [
      {0, 2, 3, 7},
    ], 850),
    _Def('9', [
      {0, 2, 4, 7, 10},
    ], 900),
    _Def('maj9', [
      {0, 2, 4, 7, 11},
    ], 900),
    _Def('m9', [
      {0, 2, 3, 7, 10},
    ], 900),
    _Def('7#9', [
      {0, 3, 4, 7, 10},
    ], 850),
    _Def('7b9', [
      {0, 1, 4, 7, 10},
    ], 850),
    _Def('7#11', [
      {0, 4, 6, 7, 10},
    ], 850),
    _Def('9#11', [
      {0, 2, 4, 6, 7, 10},
    ], 820),
    _Def('maj7#11', [
      {0, 2, 4, 6, 7, 11},
    ], 820),
    // 11 / 13
    _Def('11', [
      {0, 2, 4, 5, 7, 10},
    ], 800),
    _Def('13', [
      {0, 4, 7, 9, 10},
    ], 880),
    _Def('m13', [
      {0, 3, 7, 9, 10},
    ], 860),
  ];
}

List<ChordInterpretation> _twoNoteChord(Set<int> pcs, int? bass) {
  final pair = (pcs.toList()..sort());
  final a = pair[0];
  final b = pair[1];
  final d = (b - a + 12) % 12;
  final res = <ChordInterpretation>[];
  void one(int root, int intervalUp, int like, String suffix) {
    final other = (root + intervalUp) % 12;
    if (!pcs.contains(root) || !pcs.contains(other)) return;
    final sym = _formatSymbol(root, suffix);
    res.add(ChordInterpretation(
      displayName: _withSlash(sym, root, bass),
      rootPitchClass: root,
      likelihood: like,
      bassPitchClass: bass ?? root,
      fullChordPcs: {root, other},
    ));
  }
  if (d == 7) {
    one(a, 7, 650, '(5)');
  }
  if (d == 3) {
    res.add(ChordInterpretation(
      displayName: _withSlash('${_r(a)}–${_r(b)} (m3 interval)', a, bass),
      rootPitchClass: a,
      likelihood: 600,
      bassPitchClass: bass ?? a,
      fullChordPcs: {...pcs},
    ));
  }
  if (d == 4) {
    res.add(ChordInterpretation(
      displayName: _withSlash('${_r(a)}–${_r(b)} (M3 interval)', a, bass),
      rootPitchClass: a,
      likelihood: 620,
      bassPitchClass: bass ?? a,
      fullChordPcs: {...pcs},
    ));
  }
  if (d == 2) {
    res.add(ChordInterpretation(
      displayName: _withSlash('${_r(a)}–${_r(b)} (sus2-style)', a, bass),
      rootPitchClass: a,
      likelihood: 550,
      bassPitchClass: bass ?? a,
      fullChordPcs: {...pcs},
    ));
  }
  if (d == 5) {
    res.add(ChordInterpretation(
      displayName: _withSlash('${_r(a)}–${_r(b)} (4th / sus4 shell)', a, bass),
      rootPitchClass: a,
      likelihood: 550,
      bassPitchClass: bass ?? a,
      fullChordPcs: {...pcs},
    ));
  }
  if (res.isEmpty) {
    return [
      ChordInterpretation(
        displayName: _withSlash('${_r(a)}–${_r(b)}', a, bass),
        rootPitchClass: a,
        likelihood: 200,
        bassPitchClass: bass ?? a,
        fullChordPcs: {...pcs},
      ),
    ];
  }
  res.sort((x, y) => y.likelihood.compareTo(x.likelihood));
  return res;
}

List<ChordInterpretation> identifyChords(List<PluckedNote> notes) {
  if (notes.isEmpty) {
    return [];
  }
  final bass = _bassPitchClass(notes);
  final bassPc = bass ?? 0;
  if (notes.length == 1) {
    final p = notes.first.pitchClass;
    return [
      ChordInterpretation(
        displayName: _r(p),
        rootPitchClass: p,
        likelihood: 1000,
        bassPitchClass: p,
        fullChordPcs: {p},
      ),
    ];
  }
  final pcs = notes.map((e) => e.pitchClass).toSet();
  if (pcs.length == 2) {
    return _twoNoteChord(pcs, bass);
  }
  final defs = _defs();
  final out = <ChordInterpretation>[];
  for (var root = 0; root < 12; root++) {
    final fromRoot = {for (final pc in pcs) (pc - root + 12) % 12};
    for (final def in defs) {
      for (final t in def.sets) {
        if (fromRoot.length != t.length) continue;
        if (fromRoot.difference(t).isNotEmpty) continue;
        if (t.difference(fromRoot).isNotEmpty) continue;
        // Require root in voicing (pitch class 0 in chord)
        if (!fromRoot.contains(0)) continue;
        var like = def.likelihood;
        if (t.length == 3 &&
            (def.suffix == '7' || def.suffix == 'maj7' || def.suffix == 'm7')) {
          like -= 12; // shell voicing, rank below full
        }
        final sym = _formatSymbol(root, def.suffix);
        final fullPcs = {
          for (final iv in def.canonicalTones) (root + iv) % 12,
        };
        out.add(ChordInterpretation(
          displayName: _withSlash(sym, root, bass),
          rootPitchClass: root,
          likelihood: like,
          bassPitchClass: bassPc,
          fullChordPcs: fullPcs,
        ));
        break; // one shape per def per root
      }
    }
  }
  if (out.isEmpty) {
    final names = (pcs.toList()..sort((a, b) => a.compareTo(b)))
        .map((e) => _r(e))
        .join(' ');
    return [
      ChordInterpretation(
        displayName: '($names)',
        rootPitchClass: bassPc,
        likelihood: 100,
        bassPitchClass: bassPc,
        fullChordPcs: null,
      ),
    ];
  }
  final best = <String, ChordInterpretation>{};
  for (final c in out) {
    final old = best[c.displayName];
    if (old == null || c.likelihood > old.likelihood) {
      best[c.displayName] = c;
    }
  }
  final list = best.values.toList();
  list.sort((a, b) {
    final k = b.likelihood.compareTo(a.likelihood);
    if (k != 0) return k;
    return a.displayName.compareTo(b.displayName);
  });
  return list;
}

/// One highlighted key per sounded string: exact [PluckedNote.midi] for each
/// fretted note (repeated pitch classes in different octaves = multiple keys).
Set<int> pianoChordHighlightMidis(List<PluckedNote> notes) {
  if (notes.isEmpty) return {};
  return {for (final n in notes) n.midi};
}

(int minOctave, int maxOctave) pianoOctaveRange(Iterable<int> midis) {
  if (midis.isEmpty) return (2, 4);
  var lo = 127;
  var hi = 0;
  for (final m in midis) {
    if (m < lo) lo = m;
    if (m > hi) hi = m;
  }
  if (lo > hi) return (2, 4);
  int o(int midi) {
    if (midi < 12) return 0;
    return (midi - 12) ~/ 12;
  }
  var a = o(lo);
  var b = o(hi);
  if (b - a < 1) b = a + 1;
  // Start at the octave that contains the lowest note — do not add a full
  // octave below (avoids a long empty run on the left, esp. on mobile).
  a = math.max(0, a);
  b = math.min(8, b + 1);
  return (a, b);
}
