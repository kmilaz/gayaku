import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/screens/wardrobe_screen.dart';

void main() {
  testWidgets('WardrobeScreen shows catalog and filters by chip', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: WardrobeScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wardrobe'), findsWidgets);
    expect(find.text('Total 9 items'), findsOneWidget);
    expect(find.text('Silk Blouse'), findsOneWidget);
    expect(find.text('Tops • Zara'), findsOneWidget);

    await tester.tap(find.text('Bottoms'));
    await tester.pumpAndSettle();

    expect(find.text('Straight Leg Jeans'), findsOneWidget);
    expect(find.text('Silk Blouse'), findsNothing);
  });
}
