import 'package:flutter_test/flutter_test.dart';
import 'package:chord_lens/chord_engine.dart';

void main() {
  group('validateTabString', () {
    test('accepts 6 char tab', () {
      expect(validateTabString('x32010'), isNull);
      expect(validateTabString('320033'), isNull);
    });
    test('accepts comma-separated frets', () {
      expect(validateTabString('11,0,0,0,0,0'), isNull);
      expect(validateTabString('11,00000'), isNull);
      expect(validateTabString('10,00000'), isNull);
      expect(validateTabString('x,00000'), isNull);
      expect(validateTabString('x,3,2,0,1,0'), isNull);
      expect(validateTabString('11, 0, 0, 0, 0, 0'), isNull);
    });
    test('rejects bad comma or legacy length', () {
      expect(validateTabString('11,0,0,0,0'), isNotNull);
      expect(validateTabString('11,0,00000'), isNotNull);
      expect(validateTabString('x3201'), isNotNull);
      expect(validateTabString('x32010a'), isNotNull);
      expect(validateTabString('110000000000'), isNotNull);
    });
    test('empty or whitespace is no error (prompt only)', () {
      expect(validateTabString(''), isNull);
      expect(validateTabString('   '), isNull);
    });
  });

  group('tab C major', () {
    test('x32010 standard tuning gives C E G', () {
      final open = kTuningPresets.first.openStringMidis;
      final notes = tabToNotes('x32010', open);
      final pcs = notes.map((e) => e.pitchClass).toSet()..addAll({});
      // C(0) E(4) G(7) — C major triad
      expect(pcs, {0, 4, 7});
      final names = identifyChords(notes);
      expect(names.first.displayName, 'C');
    });
    test('comma form matches 6-char C voicing', () {
      final open = kTuningPresets.first.openStringMidis;
      final a = tabToNotes('x32010', open);
      final b = tabToNotes('x,3,2,0,1,0', open);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].midi, b[i].midi);
        expect(a[i].stringIndex, b[i].stringIndex);
        expect(a[i].fret, b[i].fret);
      }
    });
  });

  group('double-digit frets', () {
    test('fret 11 on low E, other strings open (comma form)', () {
      final open = kTuningPresets.first.openStringMidis;
      final notes = tabToNotes('11,0,0,0,0,0', open);
      expect(notes[0].fret, 11);
      for (var i = 1; i < 6; i++) {
        expect(notes[i].fret, 0);
        expect(notes[i].stringIndex, i);
      }
    });
    test('fret 11 with packed zeros after one comma', () {
      final open = kTuningPresets.first.openStringMidis;
      final a = tabToNotes('11,0,0,0,0,0', open);
      final b = tabToNotes('11,00000', open);
      expect(b.length, a.length);
      for (var i = 0; i < a.length; i++) {
        expect(b[i].midi, a[i].midi);
        expect(b[i].stringIndex, a[i].stringIndex);
        expect(b[i].fret, a[i].fret);
      }
    });
  });

  group('piano full chord', () {
    test('G triad tab shows every plucked string, not one key per class', () {
      final open = kTuningPresets.first.openStringMidis;
      final notes = tabToNotes('32003x', open);
      final ids = identifyChords(notes);
      expect(ids.first.displayName, 'G');
      final midis = pianoChordHighlightMidis(notes);
      expect(
        midis,
        {43, 47, 50, 55, 62},
        reason: 'G and B each appear in two octaves; all five are lit',
      );
    });
    test('shell maj7 voicing: piano is only plucked string midis', () {
      // C, E, B — matches maj7 without the 5th; piano should add G.
      const notes = [
        PluckedNote(48, 1, 3),
        PluckedNote(52, 2, 2),
        PluckedNote(59, 4, 0),
      ];
      final ids = identifyChords(notes);
      expect(ids.first.displayName, 'Cmaj7');
      final midis = pianoChordHighlightMidis(notes);
      expect(midis.length, 3);
    });
  });

  group('noteNameWithOctave', () {
    test('matches midiFor convention', () {
      expect(noteNameWithOctave(midiFor(4, 0)), 'C4');
      expect(noteNameWithOctave(midiFor(2, 11)), 'B2');
    });
  });

  group('parseNoteToPitchClass', () {
    test('parses', () {
      expect(parseNoteToPitchClass('E'), 4);
      expect(parseNoteToPitchClass('F#'), 6);
      expect(parseNoteToPitchClass('Eb'), 3);
      expect(parseNoteToPitchClass('Bb'), 10);
    });
  });
}
