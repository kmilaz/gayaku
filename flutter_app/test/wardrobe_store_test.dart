import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_app/models/wardrobe.dart';
import 'package:flutter_app/state/wardrobe_store.dart';

/// The wardrobe store on a real SQLite file, through the ffi factory — the
/// same schema the device runs, no device required.
void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gayaku_wardrobe');
    dbPath = '${tempDir.path}/wardrobe.db';
  });

  tearDown(() async {
    // Windows keeps the file locked until the connection is closed.
    await closeWardrobeStore();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('a fresh file starts empty: nothing is seeded', () async {
    await initWardrobeStore(factory: databaseFactoryFfi, path: dbPath);

    expect(wardrobeItems.value, isEmpty);
  });

  test('opening the same file again does not invent rows', () async {
    await initWardrobeStore(factory: databaseFactoryFfi, path: dbPath);
    await initWardrobeStore(factory: databaseFactoryFfi, path: dbPath);

    expect(wardrobeItems.value, isEmpty);
  });

  test('concurrent opens serialise onto one connection', () async {
    await Future.wait([
      initWardrobeStore(factory: databaseFactoryFfi, path: dbPath),
      initWardrobeStore(factory: databaseFactoryFfi, path: dbPath),
    ]);

    expect(wardrobeItems.value, isEmpty);
  });

  test('addWardrobeItem is still there after reopening the file', () async {
    await initWardrobeStore(factory: databaseFactoryFfi, path: dbPath);

    final scanned = WardrobeItem(
      id: newWardrobeItemId(),
      name: 'Kaos Oversize',
      category: 'Tops',
      subcategory: 'Kaos',
      imagePath: '${tempDir.path}/cutouts/kaos.png',
      colorName: 'Hitam',
      color: const Color(0xFF1A1A1A),
      formality: 2,
      occasions: const ['Kasual'],
    );
    await addWardrobeItem(scanned);
    expect(wardrobeItems.value, hasLength(1));

    // A restart: the in-memory list is gone, the file is reopened.
    wardrobeItems.value = const [];
    await initWardrobeStore(factory: databaseFactoryFfi, path: dbPath);

    final stored = wardrobeItems.value.singleWhere((i) => i.id == scanned.id);
    expect(stored.name, 'Kaos Oversize');
    expect(stored.subcategory, 'Kaos');
    expect(stored.imagePath, '${tempDir.path}/cutouts/kaos.png');
    expect(stored.colorName, 'Hitam');
    expect(stored.color, const Color(0xFF1A1A1A));
    expect(stored.formality, 2);
    expect(stored.occasions, const ['Kasual']);
    expect(wardrobeItems.value, hasLength(1), reason: 'not inserted twice');
  });

  test('deleteWardrobeItem drops the row, and reaches the file', () async {
    await initWardrobeStore(factory: databaseFactoryFfi, path: dbPath);

    final kept = WardrobeItem(
      id: newWardrobeItemId(),
      name: 'Kemeja Linen',
      category: 'Tops',
      imagePath: '${tempDir.path}/cutouts/linen.png',
    );
    await addWardrobeItem(kept);
    await deleteWardrobeItem(kept.id);
    expect(wardrobeItems.value, isEmpty);

    wardrobeItems.value = const [];
    await initWardrobeStore(factory: databaseFactoryFfi, path: dbPath);
    expect(wardrobeItems.value, isEmpty);

    // An id that is not there is a no-op, not a crash.
    await deleteWardrobeItem('does-not-exist');
    expect(wardrobeItems.value, isEmpty);
  });

  test('two garments may share a name under different ids', () async {
    await initWardrobeStore(factory: databaseFactoryFfi, path: dbPath);

    final first = WardrobeItem(
      id: newWardrobeItemId(),
      name: 'Kaos Putih',
      category: 'Tops',
      imagePath: '${tempDir.path}/cutouts/kaos-1.png',
    );
    final second = WardrobeItem(
      id: newWardrobeItemId(),
      name: 'Kaos Putih',
      category: 'Tops',
      imagePath: '${tempDir.path}/cutouts/kaos-2.png',
    );
    expect(first.id, isNot(second.id));

    await addWardrobeItem(first);
    await addWardrobeItem(second);

    expect(
      wardrobeItems.value.where((i) => i.name == 'Kaos Putih'),
      hasLength(2),
      reason: 'the name-keyed store could only ever hold one',
    );

    // Distinct rows: deleting one keeps the other.
    await deleteWardrobeItem(first.id);
    final remaining = wardrobeItems.value
        .where((i) => i.name == 'Kaos Putih')
        .single;
    expect(remaining.id, second.id);
    expect(remaining.imagePath, '${tempDir.path}/cutouts/kaos-2.png');
  });

  test('newWardrobeItemId never repeats', () {
    final ids = {for (var i = 0; i < 2000; i++) newWardrobeItemId()};
    expect(ids, hasLength(2000));
  });
}
