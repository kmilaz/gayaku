/// Domain models for the wardrobe home screen.
///
/// A [Look] is a styled outfit suggestion rendered as "Today's Look".
/// A [WardrobeItem] is a single owned garment rendered in "Recently Added".
/// A Look may reference multiple WardrobeItems but is not itself one.
library;

import 'package:flutter/material.dart';

class Look {
  const Look({
    required this.title,
    required this.subtitle,
    required this.styleTag,
    required this.imagePath,
  });

  final String title;
  final String subtitle;

  /// Short occasion label shown as a pill on the look card.
  final String styleTag;
  final String imagePath;
}

class WardrobeItem {
  const WardrobeItem({
    required this.name,
    required this.category,
    required this.imagePath,
    this.brand = '',
    this.colorName = '',
    this.color = const Color(0xFFD3A277),
    this.formality = 3,
    this.occasions = const [],
  });

  final String name;
  final String category;
  final String imagePath;

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
}

/// Catalog shown on the Wardrobe screen, grouped by the chips below.
const wardrobeItems = <WardrobeItem>[
  WardrobeItem(
    name: 'Silk Blouse',
    category: 'Tops',
    brand: 'Zara',
    colorName: 'Krem',
    color: Color(0xFFEFE3D0),
    formality: 4,
    occasions: ['Formal', 'Smart-Casual'],
    imagePath: 'assets/images/silk_blouse.jpg',
  ),
  WardrobeItem(
    name: 'Beige Trench',
    category: 'Outerwear',
    brand: 'Burberry',
    colorName: 'Beige',
    color: Color(0xFFD8C3A5),
    formality: 4,
    occasions: ['Formal', 'Smart-Casual'],
    imagePath: 'assets/images/beige_trench.jpg',
  ),
  WardrobeItem(
    name: 'Classic Sneakers',
    category: 'Shoes',
    brand: 'Nike',
    colorName: 'Putih',
    color: Color(0xFFF5F5F0),
    formality: 2,
    occasions: ['Kasual', 'Sport'],
    imagePath: 'assets/images/classic_sneakers.jpg',
  ),
  WardrobeItem(
    name: 'Gold Link Chain',
    category: 'Accessories',
    brand: 'Mejuri',
    colorName: 'Emas',
    color: Color(0xFFC9A227),
    formality: 4,
    occasions: ['Formal', 'Smart-Casual'],
    imagePath: 'assets/images/gold_link_chain.jpg',
  ),
  WardrobeItem(
    name: 'Straight Leg Jeans',
    category: 'Bottoms',
    brand: "Levi's",
    colorName: 'Biru Denim',
    color: Color(0xFF3B5A80),
    formality: 2,
    occasions: ['Kasual', 'Smart-Casual'],
    imagePath: 'assets/images/straight_leg_jeans.jpg',
  ),
  WardrobeItem(
    name: 'Linen Shirt',
    category: 'Tops',
    brand: 'Uniqlo',
    colorName: 'Putih Gading',
    color: Color(0xFFF2EDE3),
    formality: 3,
    occasions: ['Kasual', 'Smart-Casual'],
    imagePath: 'assets/images/linen_shirt.jpg',
  ),
  WardrobeItem(
    name: 'Pleated Midi Skirt',
    category: 'Bottoms',
    brand: 'COS',
    colorName: 'Cokelat Tanah',
    color: Color(0xFF8B5E3C),
    formality: 4,
    occasions: ['Formal', 'Smart-Casual'],
    imagePath: 'assets/images/pleated_midi_skirt.jpg',
  ),
  WardrobeItem(
    name: 'Leather Loafers',
    category: 'Shoes',
    brand: 'Dr. Martens',
    colorName: 'Cokelat Tua',
    color: Color(0xFF5A3A22),
    formality: 4,
    occasions: ['Formal', 'Smart-Casual'],
    imagePath: 'assets/images/leather_loafers.jpg',
  ),
  WardrobeItem(
    name: 'Tote Bag Canvas',
    category: 'Accessories',
    brand: 'Muji',
    colorName: 'Abu Muda',
    color: Color(0xFFBFBCB4),
    formality: 2,
    occasions: ['Kasual'],
    imagePath: 'assets/images/tote_bag_canvas.jpg',
  ),
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

/// Sample content for the static home screen.
const todaysLook = Look(
  title: 'Effortless Linen Dress',
  subtitle: 'Breezy layers for a warm afternoon out',
  styleTag: 'Casual Chic',
  imagePath: 'assets/images/todays_look.jpg',
);

const recentItems = <WardrobeItem>[
  WardrobeItem(
    name: 'White Sneakers',
    category: 'Shoes',
    imagePath: 'assets/images/white_sneakers.jpg',
  ),
  WardrobeItem(
    name: 'Gold Chain',
    category: 'Accessories',
    imagePath: 'assets/images/gold_chain.jpg',
  ),
  WardrobeItem(
    name: 'Silk Blouse',
    category: 'Tops',
    imagePath: 'assets/images/silk_blouse.jpg',
  ),
];
