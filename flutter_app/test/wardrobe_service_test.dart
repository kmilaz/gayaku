import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/models/scan_result.dart';
import 'package:flutter_app/services/wardrobe_service.dart';

/// A scan as the scanner would emit it: one label, its category, K-Means colour.
ScanResult _scan({String suggestedName = 'Kaos Putih'}) => ScanResult(
  label: 't_shirt',
  category: GarmentCategory.tops,
  suggestedName: suggestedName,
  confidence: 0.87,
  colorName: 'Putih',
  dominantColor: const Color(0xFFF5F5F0),
  formality: 3,
  cutoutPng: Uint8List(0),
);

void main() {
  // The seam is a global; reset so one test cannot leak its backend onward.
  tearDown(() => useWardrobeService(DemoWardrobeService()));

  test('dominantHex is the #RRGGBB the column check accepts', () {
    expect(_scan().dominantHex, '#F5F5F0');
  });

  test('add stores every scan field and list() is newest first', () async {
    final service = DemoWardrobeService();

    final first = await service.add(_scan());
    await service.add(_scan(), name: '  Kemeja Linen  ');

    expect(first.label, 't_shirt');
    expect(first.category, 'Tops');
    expect(first.confidence, 0.87);
    expect(first.colorName, 'Putih');
    expect(first.color, const Color(0xFFF5F5F0));
    expect(first.formality, 3);

    final names = (await service.items()).map((i) => i.name);
    expect(names, ['Kemeja Linen', 'Kaos Putih']);
  });

  test(
    'corrected name falls back to the label, never to an empty row',
    () async {
      final service = DemoWardrobeService();
      final item = await service.add(_scan(suggestedName: '   '), name: '  ');
      expect(item.name, 't_shirt');
    },
  );

  test('remove deletes by id and leaves the rest', () async {
    final service = DemoWardrobeService();
    final keep = await service.add(_scan());
    final drop = await service.add(_scan(), name: 'Jaket');

    await service.remove(drop.id);

    expect((await service.items()).map((i) => i.id), [keep.id]);
  });

  test('the global seam can be swapped, like main() does', () async {
    useWardrobeService(DemoWardrobeService());
    await wardrobeService.add(_scan());
    expect(await wardrobeService.items(), hasLength(1));
  });
}
