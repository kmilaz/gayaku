import 'package:flutter/foundation.dart';

import '../logic/ids.dart';
import '../models/outfit.dart';
import '../services/outfit_service.dart';

export '../models/outfit.dart' show SavedOutfit, PlannerEntry, lookFromOutfit;
export '../services/outfit_service.dart'
    show
        OutfitException,
        outfitService,
        plannerService,
        useOutfitService,
        usePlannerService;

/// Every saved combination, newest first. The rows live in Supabase
/// (`outfit_looks`); this notifier is the in-memory copy the screens read.
final savedOutfits = ValueNotifier<List<SavedOutfit>>([]);

/// Ids are uuid v4 so the same value works as a Postgres primary key and as a
/// local key — no second identity scheme.
String newOutfitId() => newWardrobeItemId();

/// Replaces the list with the owner's rows. A failed fetch keeps whatever the
/// screen already shows instead of blanking it.
Future<void> loadOutfitsFromBackend() async {
  try {
    savedOutfits.value = await outfitService.outfits();
  } catch (_) {
    // Offline, signed out, or the migration has not run yet.
  }
}

/// Backend first, then the notifier: a combination the backend rejected must
/// not look saved.
Future<void> saveOutfit(SavedOutfit outfit) async {
  final stored = await outfitService.save(outfit);
  final next = [...savedOutfits.value];
  final at = next.indexWhere((o) => o.id == stored.id);
  if (at == -1) {
    next.insert(0, stored);
  } else {
    next[at] = stored;
  }
  savedOutfits.value = next;
}

Future<void> deleteOutfit(String id) async {
  await outfitService.remove(id);
  savedOutfits.value = savedOutfits.value
      .where((outfit) => outfit.id != id)
      .toList();
}

/// Flips the favourite flag and re-notifies listeners.
Future<void> toggleOutfitFavorite(String id) async {
  final match = savedOutfits.value.where((outfit) => outfit.id == id);
  if (match.isEmpty) return;
  final outfit = match.single;
  await saveOutfit(
    SavedOutfit(
      id: outfit.id,
      name: outfit.name,
      itemIds: outfit.itemIds,
      threshold: outfit.threshold,
      favorite: !outfit.favorite,
      createdAt: outfit.createdAt,
    ),
  );
}
