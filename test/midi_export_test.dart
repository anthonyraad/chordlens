import 'package:chord_lens/midi_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildChordSmf0 writes standard header', () {
    final b = buildChordSmf0([40, 45, 52]);
    expect(b.length, greaterThan(20));
    // "MThd" magic
    expect(String.fromCharCodes(b.sublist(0, 4)), 'MThd');
  });
}
