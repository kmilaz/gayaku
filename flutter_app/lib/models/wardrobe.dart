/// Domain models for the wardrobe home screen.
///
/// A [Look] is a styled outfit suggestion rendered as "Today's Look".
/// A [WardrobeItem] is a single owned garment rendered in "Recently Added".
/// A Look may reference multiple WardrobeItems but is not itself one.
library;

import 'package:flutter/material.dart';

class Look {
  const Look({
    required this.id,
    required this.title,
    required this.styleTag,
    required this.subtitle,
    required this.imagePath,
    this.colorHarmony = 0,
    this.items = const [],
    this.savedAt,
  });

  final String id;
  final String title;

  /// Short occasion label shown as a pill on the look card.
  final String styleTag;
  final String subtitle;
  final String imagePath;

  /// Percentage match from the outfit matcher; 0 when not scored yet.
  final int colorHarmony;

  /// Garments that make up this look, for the detail view.
  final List<LookItem> items;

  /// When the user saved this look; null for a suggestion not saved yet.
  final DateTime? savedAt;
}

/// A single garment inside a [Look].
class LookItem {
  const LookItem({
    required this.type,
    required this.name,
    required this.imagePath,
    required this.icon,
  });

  final String type;
  final String name;
  final String imagePath;
  final String icon;
}

/// Ordering applied to the saved looks list.
enum LookSortOption { newest, oldest, titleAscending, titleDescending }

class WardrobeItem {
  const WardrobeItem({
    required this.id,
    required this.name,
    required this.category,
    this.subcategory,
    required this.imagePath,
    this.label = '',
    this.brand = '',
    this.colorName = '',
    this.color = const Color(0xFFD3A277),
    this.formality = 3,
    this.occasions = const [],
    this.confidence,
  });

  /// Stable identity: the `wardrobe.db` primary key for a scanned garment,
  /// `seed-*` for the demo catalog. Saved combinations store these, so a
  /// rename never splits a combination (see docs/adr/0004-sqlite-ids.md).
  final String id;

  final String name;
  final String category;

  /// Finer garment type from the scanner, e.g. `Kaos` under `Tops`.
  final String? subcategory;

  final String imagePath;

  /// Winning scanner class, e.g. `t_shirt`; empty for hand-added items.
  final String label;

  /// Optional maker label, rendered as `Category • Brand` under the name.
  final String brand;

  /// Indonesian color label shown on the detail page, e.g. `Krem`.
  final String colorName;

  /// Dominant garment color, used for HSV color-harmony scoring.
  final Color color;

  /// 1 = santai, 5 = formal. Compared against a partner item's level.
  final int formality;

  /// Occasions this item suits: `Formal`, `Kasual`, `Smart-Casual`, `Sport`.
  final List<String> occasions;

  /// Softmax score the scanner reported, 0..1; null when not scanned.
  final double? confidence;

  /// Short-lived signed URL of the cutout in the private `cutouts` bucket.
}

/// Category slots a combination is built from.
const wardrobeSlots = <String>[
  'Tops',
  'Bottoms',
  'Outerwear',
  'Shoes',
  'Accessories',
];

/// Chip labels: the leading chip clears the category filter.
const wardrobeCategories = <String>[
  'All Items',
  'Tops',
  'Bottoms',
  'Outerwear',
  'Shoes',
  'Accessories',
];
