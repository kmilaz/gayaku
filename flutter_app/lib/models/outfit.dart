import 'wardrobe.dart';

/// A user-built combination of wardrobe items.
///
/// [itemIds] holds [WardrobeItem.id]s in slot order — ids, not names — so
/// renaming a garment keeps every combination that contains it intact
/// (docs/adr/0004-sqlite-ids.md).
class SavedOutfit {
  SavedOutfit({
    required this.id,
    required this.name,
    required this.itemIds,
    required this.threshold,
    this.favorite = false,
    this.createdAt,
  });

  final String id;
  String name;

  List<String> itemIds;

  /// Minimum match percent the user wants, 0..1.
  double threshold;

  /// Favourites sort first in the wardrobe's Kombinasi tab.
  bool favorite;

  /// When the row was created; null only for an unsaved in-memory outfit.
  final DateTime? createdAt;

  /// Resolves [itemIds] against [catalog], dropping ids that no longer exist.
  List<WardrobeItem> itemsOf(List<WardrobeItem> catalog) => [
    for (final id in itemIds) ...catalog.where((i) => i.id == id),
  ];
}

/// One planned day in the weekly planner.
class PlannerEntry {
  const PlannerEntry({
    required this.day,
    required this.outfitId,
    this.occasion = '',
    this.complete = false,
  });

  /// Date only: the time part is always midnight local.
  final DateTime day;
  final String outfitId;
  final String occasion;
  final bool complete;

  PlannerEntry copyWith({String? occasion, bool? complete}) => PlannerEntry(
    day: day,
    outfitId: outfitId,
    occasion: occasion ?? this.occasion,
    complete: complete ?? this.complete,
  );
}

/// Renders a saved combination with the widgets the look cards already use.
///
/// The pictures come from the garments themselves, so a combination is never
/// a stock photo: an item scanned on this device shows its own cutout, and an
/// item that only exists in the cloud shows the placeholder.
Look lookFromOutfit(SavedOutfit outfit, List<WardrobeItem> catalog) {
  final items = outfit.itemsOf(catalog);
  final occasions = {for (final item in items) ...item.occasions};
  return Look(
    id: outfit.id,
    title: outfit.name,
    styleTag: occasions.isEmpty ? 'Custom' : occasions.first,
    subtitle: '${items.length} ${items.length == 1 ? 'item' : 'items'}',
    imagePath: items.isEmpty ? '' : items.first.imagePath,
    colorHarmony: (outfit.threshold * 100).round(),
    items: [
      for (final item in items)
        LookItem(
          type: item.category,
          name: item.name,
          imagePath: item.imagePath,
          icon: iconForCategory(item.category),
        ),
    ],
    savedAt: outfit.createdAt,
  );
}

/// The garment icon the look detail strip draws for a category.
String iconForCategory(String category) => switch (category) {
  'Tops' => 'top',
  'Bottoms' => 'bottom',
  'Shoes' => 'shoes',
  _ => 'accessory',
};
