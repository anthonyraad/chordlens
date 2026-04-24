// SMF0: one block chord, standard MIDI for DAW paste/import.

import 'dart:typed_data';

import 'package:dart_midi_pro/dart_midi_pro.dart';

/// One track, all [noteNumbers] on together for [holdTicks] (default 1 quarter at 480 PPQ).
Uint8List buildChordSmf0(
  List<int> noteNumbers, {
  int ticksPerBeat = 480,
  int holdTicks = 480,
}) {
  if (noteNumbers.isEmpty) {
    throw ArgumentError('No notes to export');
  }
  final header = MidiHeader(
    format: 0,
    numTracks: 1,
    ticksPerBeat: ticksPerBeat,
  );
  final track = <MidiEvent>[];
  // 120 BPM
  final tempo = SetTempoEvent()
    ..deltaTime = 0
    ..microsecondsPerBeat = 500000;
  track.add(tempo);
  for (var i = 0; i < noteNumbers.length; i++) {
    final e = NoteOnEvent()
      ..deltaTime = 0
      ..noteNumber = noteNumbers[i].clamp(0, 127)
      ..velocity = 100
      ..channel = 0;
    track.add(e);
  }
  for (var i = 0; i < noteNumbers.length; i++) {
    final e = NoteOffEvent()
      ..deltaTime = (i == 0) ? holdTicks : 0
      ..noteNumber = noteNumbers[i].clamp(0, 127)
      ..velocity = 0
      ..channel = 0;
    track.add(e);
  }
  final eot = EndOfTrackEvent()..deltaTime = 0;
  track.add(eot);
  final file = MidiFile([track], header);
  return Uint8List.fromList(MidiWriter().writeMidiToBuffer(file));
}
