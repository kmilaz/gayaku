import 'package:flutter/foundation.dart';

import '../models/wardrobe.dart';

/// A user-built combination of items, kept in memory for the session.
///
/// ponytail: no persistence — swap the notifier for Supabase/REST when the
/// backend lands (proposal §6.1). The screen only talks to this store.
class SavedOutfit {
  SavedOutfit({
    required this.id,
    required this.name,
    required this.itemNames,
    required this.threshold,
  });

  final String id;
  String name;

  /// Item names, in slot order. Stored as names so the store stays
  /// serialisable without a mapping layer.
  List<String> itemNames;

  /// Minimum match percent the user wants, 0..1.
  double threshold;

  List<WardrobeItem> get items => [
    for (final name in itemNames)
      ...wardrobeItems.where((i) => i.name == name),
  ];
}

/// Every saved combination, newest first. Listen to it with
/// [ValueListenableBuilder] to rebuild on add/edit/delete.
final savedOutfits = ValueNotifier<List<SavedOutfit>>([]);

String newOutfitId() => DateTime.now().microsecondsSinceEpoch.toString();

void saveOutfit(SavedOutfit outfit) {
  final next = [...savedOutfits.value];
  final at = next.indexWhere((o) => o.id == outfit.id);
  if (at == -1) {
    next.insert(0, outfit);
  } else {
    next[at] = outfit;
  }
  savedOutfits.value = next;
}

void deleteOutfit(String id) {
  savedOutfits.value = savedOutfits.value
      .where((o) => o.id != id)
      .toList();
}
