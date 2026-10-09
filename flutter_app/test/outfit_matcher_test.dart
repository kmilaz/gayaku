import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_app/logic/outfit_matcher.dart';
import 'package:flutter_app/models/wardrobe.dart';
import 'package:flutter_app/screens/outfit_builder_screen.dart';
import 'package:flutter_app/screens/wardrobe_item_detail_screen.dart';
import 'package:flutter_app/state/outfit_store.dart';

const _top = WardrobeItem(
  name: 'Kaos',
  category: 'Tops',
  color: Color(0xFF3B5A80),
  colorName: 'Biru',
  formality: 3,
  occasions: ['Kasual'],
  imagePath: 'assets/images/kaos.jpg',
);

const _otherTop = WardrobeItem(
  name: 'Kemeja',
  category: 'Tops',
  color: Color(0xFFF2EDE3),
  formality: 3,
  imagePath: 'assets/images/kemeja.jpg',
);

const _bottoms = WardrobeItem(
  name: 'Celana',
  category: 'Bottoms',
  color: Color(0xFF8B5E3C),
  formality: 3,
  occasions: ['Kasual'],
  imagePath: 'assets/images/celana.jpg',
);

const _accessory = WardrobeItem(
  name: 'Jam',
  category: 'Accessories',
  color: Color(0xFFC9A227),
  formality: 3,
  imagePath: 'assets/images/jam.jpg',
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('harmonyOf', () {
    test('reads the wheel: analog, triadic, complementary, clash', () {
      Color hue(double h) => HSVColor.fromAHSV(1, h, 0.7, 0.7).toColor();
      expect(harmonyOf(hue(0), hue(20)), ColorHarmony.analog);
      expect(harmonyOf(hue(0), hue(120)), ColorHarmony.triadic);
      expect(harmonyOf(hue(0), hue(180)), ColorHarmony.komplementer);
      expect(harmonyOf(hue(0), hue(60)), ColorHarmony.kontras);
    });

    test('greyscale is neutral against any hue', () {
      expect(isNeutral(Colors.white), isTrue);
      expect(harmonyOf(Colors.white, Colors.red), ColorHarmony.netral);
    });
  });

  group('canPair', () {
    test('same slot never pairs, layers stack', () {
      expect(canPair(_top, _otherTop), isFalse);
      expect(canPair(_top, _bottoms), isTrue);
      expect(canPair(_accessory, _accessory), isTrue);
    });
  });

  group('recommendMatches', () {
    test('drops same-category items and sorts by score', () {
      final out = recommendMatches(_top, [_top, _otherTop, _bottoms, _accessory]);
      expect(out.map((m) => m.item.name), isNot(contains('Kaos')));
      expect(out.map((m) => m.item.name), isNot(contains('Kemeja')));
      expect(
        out.first.score,
        greaterThanOrEqualTo(out.last.score),
        reason: 'sorted descending',
      );
      expect(out.first.reasons, isNotEmpty);
    });

    test('a shared occasion and close formality raise the score', () {
      final onOccasion = recommendMatches(_top, [_bottoms]).single;
      final offOccasion = recommendMatches(_top, [
        const WardrobeItem(
          name: 'Sepatu Formal',
          category: 'Shoes',
          color: Color(0xFF8B5E3C),
          formality: 5,
          occasions: ['Formal'],
          imagePath: 'assets/images/sepatu.jpg',
        ),
      ]).single;
      expect(onOccasion.score, greaterThan(offOccasion.score));
    });
  });

  test('outfitFor keeps one best partner per slot', () {
    final out = outfitFor(_top, [_top, _otherTop, _bottoms, _accessory]);
    expect(out.map((m) => m.item.category).toSet(), {'Bottoms', 'Accessories'});
  });

  group('outfitScore', () {
    test('averages pairs and drops to 0 on a slot clash', () {
      final clash = outfitScore([_top, _otherTop]);
      expect(clash, 0, reason: 'two tops never pair');

      final good = outfitScore([_top, _bottoms, _accessory]);
      expect(good, greaterThan(clash));
      expect(good, lessThanOrEqualTo(1));
    });

    test('a single item scores 0', () {
      expect(outfitScore([_top]), 0);
    });

    test('weakestPair names the clashing pair', () {
      final weak = weakestPair([_top, _otherTop, _bottoms])!;
      expect({weak.a.name, weak.b.name}, {'Kaos', 'Kemeja'});
      expect(weak.score, 0);
    });
  });

  group('improveOutfit', () {
    test('stays silent when the set already meets the threshold', () {
      final set = [_top, _bottoms, _accessory];
      expect(outfitScore(set), greaterThan(0));
      expect(improveOutfit(set, [_top, _bottoms, _accessory], threshold: 0.1),
          isEmpty);
    });

    test('proposes a swap that lifts the score past the threshold', () {
      final set = [_top, _otherTop, _bottoms];
      final swaps = improveOutfit(set, wardrobeItems, threshold: 0.9);
      expect(swaps, isNotEmpty);

      final best = swaps.first;
      expect(best.newScore, greaterThan(outfitScore(set)));

      final applied = [...set]..[best.index] = best.to;
      expect(outfitScore(applied), best.newScore);
      expect(
        applied.map((i) => i.name).toSet(),
        hasLength(applied.length),
        reason: 'never duplicates an item already in the set',
      );
    });
  });

  group('savedOutfits store', () {
    setUp(() => savedOutfits.value = []);

    test('adds, edits in place, and deletes', () {
      // Names must exist in the catalog: SavedOutfit.items resolves against it.
      final names = ['Silk Blouse', 'Straight Leg Jeans'];
      saveOutfit(
        SavedOutfit(
          id: 'a',
          name: 'Kantor',
          itemNames: names,
          threshold: 0.8,
        ),
      );
      expect(savedOutfits.value, hasLength(1));

      saveOutfit(
        SavedOutfit(
          id: 'a',
          name: 'Kantor Senin',
          itemNames: names,
          threshold: 0.9,
        ),
      );
      expect(savedOutfits.value, hasLength(1), reason: 'same id edits in place');
      expect(savedOutfits.value.single.name, 'Kantor Senin');
      expect(savedOutfits.value.single.items, hasLength(2));

      deleteOutfit('a');
      expect(savedOutfits.value, isEmpty);
    });
  });

  testWidgets('builder shows the score and its improvement suggestions',
      (tester) async {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Two tops in one set: guaranteed clash, so the score sits under 95%.
    const names = ['Silk Blouse', 'Linen Shirt', 'Straight Leg Jeans'];
    final set = [for (final n in names) ...wardrobeItems.where((i) => i.name == n)];
    final swap = improveOutfit(set, wardrobeItems, threshold: 0.95).first;

    await tester.pumpWidget(
      MaterialApp(
        home: OutfitBuilderScreen(
          existing: SavedOutfit(
            id: 'x',
            name: 'Uji',
            itemNames: names,
            threshold: 0.95,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Kombinasi'), findsOneWidget);
    expect(find.text('Batas minimum'), findsOneWidget);
    expect(find.text('Rekomendasi Peningkatan'), findsOneWidget);
    expect(find.text('${(outfitScore(set) * 100).round()}%'), findsWidgets);

    await tester.tap(find.textContaining('Ganti ').first);
    await tester.pumpAndSettle();

    // Applying the best swap moves the meter to its new score.
    expect(find.text('${swap.gainPercent}%'), findsWidgets);
  });

  testWidgets('detail page lists the matched pieces', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WardrobeItemDetailScreen(
          item: wardrobeItems.first,
          catalog: wardrobeItems,
        ),
      ),
    );

    expect(find.text('Cocok Dipadukan Dengan'), findsOneWidget);
    expect(find.text(wardrobeItems.first.name), findsWidgets);

    final expected = outfitFor(wardrobeItems.first, wardrobeItems);
    expect(expected, isNotEmpty);
    for (final match in expected) {
      expect(find.text(match.item.name), findsOneWidget);
    }
    expect(find.textContaining('%'), findsNWidgets(expected.length));
  });
}
