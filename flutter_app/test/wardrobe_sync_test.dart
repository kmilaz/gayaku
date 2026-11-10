import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/logic/garment_defaults.dart';
import 'package:flutter_app/logic/ids.dart';
import 'package:flutter_app/models/scan_result.dart';
import 'package:flutter_app/models/wardrobe.dart';
import 'package:flutter_app/services/wardrobe_service.dart';
import 'package:flutter_app/state/wardrobe_sync.dart';

void main() {
  tearDown(() => useWardrobeService(DemoWardrobeService()));

  test('newWardrobeItemId is a v4 uuid, so SQLite and Postgres agree', () {
    expect(
      newWardrobeItemId(),
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect({for (var i = 0; i < 200; i++) newWardrobeItemId()}.length, 200);
  });

  test(
    'save keeps every model field the scanner review screen edited',
    () async {
      final service = DemoWardrobeService();
      final item = WardrobeItem(
        id: newWardrobeItemId(),
        name: 'Kemeja Linen',
        label: 'Kemeja',
        category: 'Tops',
        subcategory: 'Kemeja',
        brand: 'Uniqlo',
        imagePath: '/tmp/cutouts/a.png',
        colorName: 'Putih',
        color: const Color(0xFFF5F5F0),
        formality: 4,
        occasions: const ['Formal', 'Smart-Casual'],
        confidence: 0.91,
      );

      final stored = await service.save(item);

      expect(stored.id, item.id);
      expect(stored.subcategory, 'Kemeja');
      expect(stored.brand, 'Uniqlo');
      expect(stored.occasions, ['Formal', 'Smart-Casual']);
      expect((await service.items()).single.id, item.id);
    },
  );

  test(
    'add derives subcategory and occasions the way the SQL backfill does',
    () async {
      final service = DemoWardrobeService();
      final stored = await service.add(
        ScanResult(
          label: 'Kemeja',
          category: GarmentCategory.tops,
          suggestedName: 'Kemeja Putih',
          confidence: 0.8,
          colorName: 'Putih',
          dominantColor: const Color(0xFFFFFFFF),
          formality: 4,
          cutoutPng: Uint8List(0),
        ),
      );

      expect(stored.subcategory, 'Kemeja');
      expect(stored.occasions, defaultOccasions('Tops'));
    },
  );

  test('a failed backend fetch never escapes the startup path', () async {
    // Regression: when the host could not be resolved the gotrue
    // AuthRetryableFetchException escaped main() and froze the splash screen.
    useWardrobeService(_OfflineWardrobeService());
    await expectLater(loadWardrobeFromBackend(), completes);
  });
}

class _OfflineWardrobeService implements WardrobeService {
  @override
  Future<List<WardrobeItem>> items() async =>
      throw const SocketException('Failed host lookup');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}
