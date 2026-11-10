/// Test catalog for the screens that need partner items.
///
/// The app itself ships no demo garments: an empty wardrobe is an empty
/// screen. These fixtures used to live in lib/models/wardrobe.dart as the
/// rows seeded into `wardrobe.db`.
library;

import 'package:flutter/material.dart';

import 'package:flutter_app/models/wardrobe.dart';

const wardrobeFixture = <WardrobeItem>[
  WardrobeItem(
    id: 'seed-silk-blouse',
    name: 'Silk Blouse',
    category: 'Tops',
    brand: 'Zara',
    colorName: 'Krem',
    color: Color(0xFFEFE3D0),
    formality: 4,
    occasions: ['Formal', 'Smart-Casual'],
    imagePath: 'assets/images/silk_blouse.png',
  ),
  WardrobeItem(
    id: 'seed-beige-trench',
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
    id: 'seed-classic-sneakers',
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
    id: 'seed-gold-link-chain',
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
    id: 'seed-straight-leg-jeans',
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
    id: 'seed-linen-shirt',
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
    id: 'seed-pleated-midi-skirt',
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
    id: 'seed-leather-loafers',
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
    id: 'seed-tote-bag-canvas',
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
