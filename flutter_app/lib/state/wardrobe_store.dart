import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/wardrobe.dart';

export '../logic/ids.dart' show newWardrobeItemId;

/// Every garment the user owns, mirroring `wardrobe.db` in insertion order.
///
/// Listen to it with [ValueListenableBuilder] to rebuild on add/delete. The
/// table is the source of truth: a scanned garment survives a restart, which
/// the old in-memory catalog could not do (docs/adr/0004-sqlite-ids.md).
final wardrobeItems = ValueNotifier<List<WardrobeItem>>([]);

const String _dbFileName = 'wardrobe.db';
const String _table = 'wardrobe_items';

Database? _db;

/// Chains every [initWardrobeStore] call so two callers can never interleave
/// two half-open connections.
Future<void> _queue = Future<void>.value();

/// Opens `wardrobe.db` in the app documents directory, creates the schema and
/// mirrors the rows into [wardrobeItems]. Nothing is seeded: an account with
/// no garments shows an empty wardrobe, and Supabase is what fills it.
///
/// Pass [path] (and [factory]) to point the store somewhere else — the tests
/// run it on `sqflite_common_ffi` against a temp file. Calling it again is
/// safe: the open connection is closed first and the rows are left alone.
Future<void> initWardrobeStore({DatabaseFactory? factory, String? path}) {
  final next = _queue.then((_) => _open(factory: factory, path: path));
  // Keep the chain usable even when one open fails.
  _queue = next.then((_) {}, onError: (Object _) {});
  return next;
}

/// Closes the connection and empties [wardrobeItems]; the next
/// [initWardrobeStore] reopens the file. Tests that delete their temporary
/// directory need this — Windows keeps the file locked while it is open.
Future<void> closeWardrobeStore() async {
  final db = _db;
  _db = null;
  await db?.close();
  wardrobeItems.value = const [];
}

/// Inserts [item] and re-notifies listeners. Same [WardrobeItem.id] replaces.
Future<void> addWardrobeItem(WardrobeItem item) async {
  final db = _requireDb();
  await db.insert(
    _table,
    _toRow(item),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  wardrobeItems.value = await _readAll(db);
}

/// Removes the row with [id]; a missing id is a no-op.
Future<void> deleteWardrobeItem(String id) async {
  final db = _requireDb();
  await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  wardrobeItems.value = await _readAll(db);
}

Future<void> _open({DatabaseFactory? factory, String? path}) async {
  final resolved = path ?? await _documentsPath();
  await _ensureParent(resolved);

  final previous = _db;
  _db = null;
  if (previous != null) await previous.close();

  final db = await (factory ?? databaseFactory).openDatabase(
    resolved,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) => _createTable(db),
    ),
  );
  _db = db;
  wardrobeItems.value = await _readAll(db);
}

Future<String> _documentsPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}${Platform.pathSeparator}$_dbFileName';
}

/// sqflite will not create the folder, and a fresh install has none.
Future<void> _ensureParent(String dbPath) async {
  if (dbPath.contains(':memory:')) return;
  final cut = dbPath.lastIndexOf(RegExp(r'[/\\]'));
  if (cut <= 0) return;
  final parent = Directory(dbPath.substring(0, cut));
  if (!await parent.exists()) await parent.create(recursive: true);
}

Future<void> _createTable(Database db) {
  return db.execute('''
CREATE TABLE $_table (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT,
  image_path TEXT NOT NULL,
  brand TEXT NOT NULL DEFAULT '',
  color_name TEXT NOT NULL DEFAULT '',
  color INTEGER NOT NULL DEFAULT ${0xFFD3A277},
  formality INTEGER NOT NULL DEFAULT 3,
  occasions TEXT NOT NULL DEFAULT '[]'
)
''');
}

Future<List<WardrobeItem>> _readAll(Database db) async {
  final rows = await db.query(_table, orderBy: 'rowid');
  return [for (final row in rows) _fromRow(row)];
}

Database _requireDb() {
  final db = _db;
  if (db == null) {
    throw StateError(
      'initWardrobeStore() must complete before the wardrobe is read or written.',
    );
  }
  return db;
}

Map<String, Object?> _toRow(WardrobeItem item) => {
  'id': item.id,
  'name': item.name,
  'category': item.category,
  'subcategory': item.subcategory,
  'image_path': item.imagePath,
  'brand': item.brand,
  'color_name': item.colorName,
  'color': item.color.toARGB32(),
  'formality': item.formality,
  'occasions': jsonEncode(item.occasions),
};

WardrobeItem _fromRow(Map<String, Object?> row) => WardrobeItem(
  id: row['id']! as String,
  name: row['name']! as String,
  category: row['category']! as String,
  subcategory: row['subcategory'] as String?,
  imagePath: row['image_path']! as String,
  brand: row['brand'] as String? ?? '',
  colorName: row['color_name'] as String? ?? '',
  color: Color(row['color'] as int? ?? 0xFFD3A277),
  formality: row['formality'] as int? ?? 3,
  occasions: _occasionsOf(row['occasions']),
);

List<String> _occasionsOf(Object? raw) {
  if (raw is! String || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.whereType<String>().toList() : const [];
  } on FormatException {
    return const [];
  }
}
