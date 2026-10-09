import 'package:flutter/foundation.dart';

enum OutfitSortOption { newest, oldest, titleAscending, titleDescending }

@immutable
class OutfitLook {
  const OutfitLook({
    required this.id,
    required this.title,
    required this.styleTag,
    required this.subtitle,
    required this.imagePath,
    required this.colorHarmony,
    required this.items,
    required this.savedAt,
  });

  final String id;
  final String title;
  final String styleTag;
  final String subtitle;
  final String imagePath;
  final int colorHarmony;
  final List<OutfitLookItem> items;
  final DateTime savedAt;
}

@immutable
class OutfitLookItem {
  const OutfitLookItem({
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

final favoriteOutfitLooks = <OutfitLook>[
  OutfitLook(
    id: 'beige-trench-denim',
    title: 'Beige Trench & Denim',
    styleTag: 'Casual Chic',
    subtitle: 'Perfect for a sunny coffee run.',
    imagePath: 'assets/images/beige_trench_denim.jpg',
    colorHarmony: 94,
    savedAt: DateTime(2026, 10, 8, 14, 30),
    items: [
      OutfitLookItem(
        type: 'Top',
        name: 'Silk Blouse',
        imagePath: 'assets/images/silk_blouse.jpg',
        icon: 'top',
      ),
      OutfitLookItem(
        type: 'Bottom',
        name: 'Straight Leg Jeans',
        imagePath: 'assets/images/straight_leg_jeans.jpg',
        icon: 'bottom',
      ),
      OutfitLookItem(
        type: 'Shoes',
        name: 'Classic Sneakers',
        imagePath: 'assets/images/white_sneakers.jpg',
        icon: 'shoes',
      ),
      OutfitLookItem(
        type: 'Accessory',
        name: 'Gold Link Chain',
        imagePath: 'assets/images/gold_chain.jpg',
        icon: 'accessory',
      ),
    ],
  ),
  OutfitLook(
    id: 'linen-office-set',
    title: 'Linen Office Set',
    styleTag: 'Office',
    subtitle: 'Polished layers for a focused workday.',
    imagePath: 'assets/images/linen_office_set.jpg',
    colorHarmony: 91,
    savedAt: DateTime(2026, 10, 9, 9, 15),
    items: [
      OutfitLookItem(
        type: 'Top',
        name: 'Linen Shirt',
        imagePath: 'assets/images/linen_shirt.jpg',
        icon: 'top',
      ),
      OutfitLookItem(
        type: 'Bottom',
        name: 'Tailored Trousers',
        imagePath: 'assets/images/tailored_trousers.jpg',
        icon: 'bottom',
      ),
      OutfitLookItem(
        type: 'Shoes',
        name: 'Leather Loafers',
        imagePath: 'assets/images/leather_loafers.jpg',
        icon: 'shoes',
      ),
      OutfitLookItem(
        type: 'Accessory',
        name: 'Minimal Watch',
        imagePath: 'assets/images/minimal_watch.jpg',
        icon: 'accessory',
      ),
    ],
  ),
];
