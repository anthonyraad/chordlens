import 'package:flutter_test/flutter_test.dart';
import 'package:chord_lens/main.dart';

void main() {
  testWidgets('ChordLens loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ChordLensApp());
    expect(find.textContaining('CHORDLENS'), findsOneWidget);
  });
}
