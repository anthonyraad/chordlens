import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chord_lens/main.dart';
import 'package:chord_lens/theme.dart';

void main() {
  testWidgets('ChordLens loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ChordLensApp());
    expect(find.text('ChordLens'), findsOneWidget);
    expect(find.text('Tuning'), findsOneWidget);
    expect(find.text('Chord sets'), findsOneWidget);
  });

  testWidgets('dark theme matches Irodoku canvas and Balatro', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: ChordLensTheme.dark(), home: const ChordLensHome()),
    );
    await tester.pump();

    final context = tester.element(find.text('ChordLens'));
    final theme = Theme.of(context);
    expect(theme.scaffoldBackgroundColor, ChordLensTheme.darkBackground);
    expect(theme.textTheme.bodyMedium?.fontFamily, ChordLensTheme.fontFamily);
  });
}
