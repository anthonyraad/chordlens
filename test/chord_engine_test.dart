import 'package:flutter_test/flutter_test.dart';
import 'package:chord_lens/chord_engine.dart';

void main() {
  group('validateTabString', () {
    test('accepts 6 char tab', () {
      expect(validateTabString('x32010'), isNull);
      expect(validateTabString('320033'), isNull);
    });
    test('rejects bad length and chars', () {
      expect(validateTabString('x3201'), isNotNull);
      expect(validateTabString('x32010a'), isNotNull);
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
