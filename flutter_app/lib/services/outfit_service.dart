import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/outfit.dart';

/// A combination or planner call that failed with a message the UI can show.
class OutfitException implements Exception {
  const OutfitException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The only seam between the Kombinasi tab and the backend.
abstract class OutfitService {
  /// Owner's combinations, newest first.
  Future<List<SavedOutfit>> outfits();

  /// Inserts or replaces [outfit]; the same id updates the same row.
  Future<SavedOutfit> save(SavedOutfit outfit);

  Future<void> remove(String id);
}

/// The only seam between the weekly planner and the backend.
abstract class PlannerService {
  /// Every planned day for the owner.
  Future<List<PlannerEntry>> entries();

  /// One outfit per day: planning the same date again replaces that row.
  Future<PlannerEntry> save(PlannerEntry entry);

  Future<void> remove(DateTime day);
}

/// Keeps combinations and plans in memory, for tests and for runs built
/// without credentials.
class DemoOutfitService implements OutfitService {
  final _outfits = <SavedOutfit>[];

  @override
  Future<List<SavedOutfit>> outfits() async => List.unmodifiable(_outfits);

  @override
  Future<SavedOutfit> save(SavedOutfit outfit) async {
    _outfits
      ..removeWhere((o) => o.id == outfit.id)
      ..add(outfit);
    return outfit;
  }

  @override
  Future<void> remove(String id) async =>
      _outfits.removeWhere((o) => o.id == id);
}

class DemoPlannerService implements PlannerService {
  final _entries = <DateTime, PlannerEntry>{};

  @override
  Future<List<PlannerEntry>> entries() async => List.unmodifiable(
    _entries.values.toList()..sort((a, b) => a.day.compareTo(b.day)),
  );

  @override
  Future<PlannerEntry> save(PlannerEntry entry) async =>
      _entries[_day(entry.day)] = entry;

  @override
  Future<void> remove(DateTime day) async => _entries.remove(_day(day));
}

class SupabaseOutfitService implements OutfitService {
  SupabaseOutfitService(this._client);

  final sb.SupabaseClient _client;

  static const _table = 'outfit_looks';

  @override
  Future<List<SavedOutfit>> outfits() async {
    final rows = await _guard(
      () => _client.from(_table).select().order('created_at', ascending: false),
    );
    return rows.map(_toOutfit).toList();
  }

  @override
  Future<SavedOutfit> save(SavedOutfit outfit) async {
    final row = await _guard(
      () => _client
          .from(_table)
          .upsert({
            if (outfit.id.isNotEmpty) 'id': outfit.id,
            'name': outfit.name,
            'item_ids': outfit.itemIds,
            'threshold': outfit.threshold,
            'favorite': outfit.favorite,
          })
          .select()
          .single(),
    );
    return _toOutfit(row);
  }

  @override
  Future<void> remove(String id) =>
      _guard(() => _client.from(_table).delete().eq('id', id));
}

class SupabasePlannerService implements PlannerService {
  SupabasePlannerService(this._client);

  final sb.SupabaseClient _client;

  static const _table = 'planner_entries';

  @override
  Future<List<PlannerEntry>> entries() async {
    final rows = await _guard(
      () => _client.from(_table).select().order('day', ascending: true),
    );
    return rows.map(_toEntry).toList();
  }

  @override
  Future<PlannerEntry> save(PlannerEntry entry) async {
    final row = await _guard(
      () => _client
          .from(_table)
          .upsert({
            'day': _isoDay(entry.day),
            'outfit_id': entry.outfitId,
            'occasion': entry.occasion,
            'complete': entry.complete,
          }, onConflict: 'owner_id,day')
          .select()
          .single(),
    );
    return _toEntry(row);
  }

  @override
  Future<void> remove(DateTime day) =>
      _guard(() => _client.from(_table).delete().eq('day', _isoDay(day)));
}

SavedOutfit _toOutfit(Map<String, dynamic> row) => SavedOutfit(
  id: row['id'] as String,
  name: row['name'] as String? ?? '',
  itemIds: [
    for (final id in (row['item_ids'] as List? ?? const [])) id as String,
  ],
  threshold: (row['threshold'] as num?)?.toDouble() ?? 0.6,
  favorite: row['favorite'] as bool? ?? false,
  createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal(),
);

PlannerEntry _toEntry(Map<String, dynamic> row) => PlannerEntry(
  day: DateTime.parse(row['day'] as String),
  outfitId: row['outfit_id'] as String,
  occasion: row['occasion'] as String? ?? '',
  complete: row['complete'] as bool? ?? false,
);

/// `yyyy-MM-dd` for a `date` column, in local time.
String _isoDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

Future<T> _guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on sb.PostgrestException catch (e) {
    throw OutfitException(_friendly(e.message));
  }
}

String _friendly(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('row-level security') || lower.contains('violates')) {
    return 'Tidak diizinkan menyimpan kombinasi ini.';
  }
  if (lower.contains('jwt') || lower.contains('expired')) {
    return 'Sesi habis, masuk ulang.';
  }
  // A project that has not run 20261108160000 yet answers 404/PGRST205.
  if (lower.contains('does not exist') || lower.contains('schema cache')) {
    return 'Tabel kombinasi belum ada di Supabase.';
  }
  return message;
}

OutfitService _outfits = DemoOutfitService();
PlannerService _planner = DemoPlannerService();

/// The combination backend the Kombinasi tab talks to.
OutfitService get outfitService => _outfits;

/// The planner backend the weekly planner talks to.
PlannerService get plannerService => _planner;

/// Swaps the backends; called once from [main] before the first frame.
void useOutfitService(OutfitService service) => _outfits = service;

void usePlannerService(PlannerService service) => _planner = service;
