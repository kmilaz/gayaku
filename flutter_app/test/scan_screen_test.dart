import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_app/logic/garment_defaults.dart';
import 'package:flutter_app/logic/scan_pipeline.dart';
import 'package:flutter_app/screens/scan_screen.dart';
import 'package:flutter_app/state/wardrobe_store.dart';

/// A real 2x2 PNG (opaque #C81E28), so `Image.memory` has something decodable.
/// Regenerate with zlib+struct if the fixture ever needs to change.
final onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGM4IafxH4QZYAwASIgINVKfBLYAAAAASUVORK5CYII=',
);

ScanResult detectedGarment() => ScanResult(
  cutoutPng: onePixelPng,
  dominantColor: const Color(0xFFC81E28),
  colorName: 'Merah',
  label: 'Shirts',
  category: 'Tops',
  suggestedName: 'Kemeja',
  confidence: 0.87,
);

/// Pushes the scanner the way the app does, so its `pop` has somewhere to go.
Future<void> openScanner(
  WidgetTester tester, {
  required Future<ScanResult> Function(Uint8List) scanner,
  required Directory documents,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ScanScreen(
                  scanner: scanner,
                  picker: (_) async => onePixelPng,
                  documentsDirectory: () async => documents,
                ),
              ),
            ),
            child: const Text('open scanner'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open scanner'));
  await tester.pumpAndSettle();
}

/// A scan result with a box, the way the detector produces them.
ScanResult garment({
  required String label,
  required String category,
  required String name,
  double confidence = 0.87,
  String? detectedCategory,
}) => ScanResult(
  cutoutPng: onePixelPng,
  dominantColor: const Color(0xFFC81E28),
  colorName: 'Merah',
  label: label,
  category: category,
  suggestedName: name,
  confidence: confidence,
  box: const Rect.fromLTRB(0.1, 0.1, 0.6, 0.6),
  detectedCategory: detectedCategory,
);

/// Same as [openScanner] but injects the list-returning scanner the carousel needs.
Future<void> openScannerAll(
  WidgetTester tester, {
  required Future<List<ScanResult>> Function(Uint8List) scanner,
  required Directory documents,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ScanScreen(
                  scannerAll: scanner,
                  picker: (_) async => onePixelPng,
                  documentsDirectory: () async => documents,
                ),
              ),
            ),
            child: const Text('open scanner'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open scanner'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late Directory temp;

  setUp(() async {
    sqfliteFfiInit();
    temp = Directory.systemTemp.createTempSync('gayaku_scan');
    await initWardrobeStore(
      factory: databaseFactoryFfi,
      path: '${temp.path}/wardrobe.db',
    );
  });

  tearDown(() async {
    await closeWardrobeStore();
    temp.deleteSync(recursive: true);
  });

  testWidgets(
    'detects a garment, lets the user correct it, and saves the Cutout',
    (tester) async {
      await openScanner(
        tester,
        scanner: (_) async => detectedGarment(),
        documents: temp,
      );

      expect(find.text('Siap memindai'), findsOneWidget);

      await tester.tap(find.byTooltip('Pilih dari galeri'));
      await tester.pumpAndSettle();

      expect(find.text('AI DETECTED DETAILS'), findsOneWidget);
      expect(find.text('Tops'), findsOneWidget);
      expect(find.text('Merah'), findsOneWidget);
      expect(find.text('Kemeja'), findsOneWidget);
      expect(find.text('Terdeteksi: Shirts • 87% yakin'), findsOneWidget);

      // Correct the detected Category the way a user would.
      final editButton = find.widgetWithText(TextButton, 'Edit').first;
      await tester.ensureVisible(editButton);
      await tester.tap(editButton);
      await tester.pumpAndSettle();
      expect(find.text('Pilih category'), findsOneWidget);
      await tester.tap(find.text('Outerwear').last);
      await tester.pumpAndSettle();
      expect(find.text('Outerwear'), findsOneWidget);

      final saveButton = find.widgetWithText(
        FilledButton,
        'Simpan ke Wardrobe',
      );
      await tester.ensureVisible(saveButton);
      // Saving writes a PNG and a SQLite row: real I/O that the fake-async test
      // zone never resolves, so tap and wait inside runAsync.
      await tester.runAsync(() async {
        await tester.tap(saveButton);
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (wardrobeItems.value.every((item) => item.name != 'Kemeja') &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();

      final saved = wardrobeItems.value.where((item) => item.name == 'Kemeja');
      expect(saved, hasLength(1));
      final item = saved.single;
      expect(item.category, 'Outerwear');
      expect(item.subcategory, 'Shirts');
      expect(item.colorName, 'Merah');
      expect(item.color, const Color(0xFFC81E28));
      // The recommender needs both, and the scanner may only guess them from the
      // Category the user settled on.
      expect(item.formality, defaultFormality('Outerwear'));
      expect(item.occasions, defaultOccasions('Outerwear'));

      final cutout = File(item.imagePath);
      expect(cutout.existsSync(), isTrue);
      expect(cutout.path, startsWith('${temp.path}/garments/'));
      expect(cutout.readAsBytesSync(), onePixelPng);
    },
  );

  testWidgets('a failed scan explains itself and offers no save button', (
    tester,
  ) async {
    await openScanner(
      tester,
      scanner: (_) async => throw const ScanFailure(
        'Pakaian tidak terdeteksi. Coba foto ulang dengan latar yang lebih polos.',
      ),
      documents: temp,
    );

    await tester.tap(find.byTooltip('Ambil foto'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Pakaian tidak terdeteksi. Coba foto ulang dengan latar yang lebih polos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Pemindaian gagal'), findsOneWidget);
    expect(find.text('Simpan ke Wardrobe'), findsNothing);
    expect(
      wardrobeItems.value.where((item) => item.subcategory != null),
      isEmpty,
    );
  });

  testWidgets('a two-garment scan walks a carousel and saves both', (
    tester,
  ) async {
    await openScannerAll(
      tester,
      scanner: (_) async => [
        garment(label: 'Shirts', category: 'Tops', name: 'Kemeja'),
        garment(
          label: 'Jeans',
          category: 'Bottoms',
          name: 'Jeans',
          confidence: 0.5,
        ),
      ],
      documents: temp,
    );

    await tester.tap(find.byTooltip('Pilih dari galeri'));
    await tester.pumpAndSettle();

    expect(find.text('2 pakaian terdeteksi'), findsOneWidget);
    expect(find.text('1 dari 2'), findsOneWidget);
    expect(find.text('Kemeja'), findsOneWidget);

    await tester.tap(find.byTooltip('Item berikutnya'));
    await tester.pumpAndSettle();
    expect(find.text('2 dari 2'), findsOneWidget);
    expect(find.text('Terdeteksi: Jeans • 50% yakin'), findsOneWidget);
    // Below the confidence threshold, so the card says the name may be wrong without
    // blocking the save.
    expect(find.textContaining('mungkin belum tepat'), findsOneWidget);

    final saveButton = find.widgetWithText(FilledButton, 'Simpan 2 item');
    await tester.ensureVisible(saveButton);
    await tester.runAsync(() async {
      await tester.tap(saveButton);
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (wardrobeItems.value.length < 2 &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();

    final saved = wardrobeItems.value.map((item) => item.name).toList();
    expect(saved, containsAll(<String>['Kemeja', 'Jeans']));
  });

  testWidgets('an accessory is flagged even when the classifier is sure', (
    tester,
  ) async {
    await openScannerAll(
      tester,
      scanner: (_) async => [
        garment(
          label: 'Topi',
          category: 'Accessories',
          name: 'Topi',
          confidence: 0.95,
          detectedCategory: 'Accessories',
        ),
      ],
      documents: temp,
    );

    await tester.tap(find.byTooltip('Pilih dari galeri'));
    await tester.pumpAndSettle();

    expect(find.textContaining('mungkin belum tepat'), findsOneWidget);
    expect(find.text('Simpan ke Wardrobe'), findsOneWidget);
  });

  testWidgets('deleting an item removes it from the carousel', (tester) async {
    await openScannerAll(
      tester,
      scanner: (_) async => [
        garment(label: 'Shirts', category: 'Tops', name: 'Kemeja'),
        garment(label: 'Jeans', category: 'Bottoms', name: 'Jeans'),
      ],
      documents: temp,
    );

    await tester.tap(find.byTooltip('Pilih dari galeri'));
    await tester.pumpAndSettle();
    expect(find.text('1 dari 2'), findsOneWidget);

    final deleteButton = find.text('Hapus item ini');
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // One garment left, so the carousel and its indicator disappear.
    expect(find.text('Pakaian terdeteksi'), findsOneWidget);
    expect(find.textContaining('dari 2'), findsNothing);
    expect(find.text('Jeans'), findsOneWidget);
  });
}
