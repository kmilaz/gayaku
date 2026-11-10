import 'package:flutter/foundation.dart';

import '../models/outfit.dart';
import '../services/outfit_service.dart';

/// The weekly plan, one entry per day, backed by `planner_entries` in
/// Supabase. Keys are date-only so a planned day never depends on the hour it
/// was created.
final plannerEntries = ValueNotifier<Map<DateTime, PlannerEntry>>({});

DateTime dayKey(DateTime value) => DateTime(value.year, value.month, value.day);

/// Loads every planned day. A failed fetch keeps the current plan on screen.
Future<void> loadPlannerFromBackend() async {
  try {
    final entries = await plannerService.entries();
    plannerEntries.value = {
      for (final entry in entries) dayKey(entry.day): entry,
    };
  } catch (_) {
    // Offline, signed out, or the migration has not run yet.
  }
}

/// Backend first, then the notifier.
Future<void> savePlannerEntry(PlannerEntry entry) async {
  final stored = await plannerService.save(entry);
  plannerEntries.value = {...plannerEntries.value, dayKey(entry.day): stored};
}

Future<void> deletePlannerEntry(DateTime day) async {
  await plannerService.remove(day);
  final next = {...plannerEntries.value}..remove(dayKey(day));
  plannerEntries.value = next;
}
