import 'dart:typed_data';

import 'package:flutter/material.dart';

/// The five slots a scanned garment can land in.
///
/// `id` is both the value `labels.json` maps each of the 18 YOLO labels to and
/// the string stored in `wardrobe_items.category`, so no translation layer sits
/// between the model output and the database.
enum GarmentCategory {
  tops('Tops'),
  bottoms('Bottoms'),
  outerwear('Outerwear'),
  shoes('Shoes'),
  accessories('Accessories');

  const GarmentCategory(this.id);

  final String id;
}

/// Everything one scan produces, before the user corrects it.
///
/// [category] and [formality] are already derived by the scanner (label lookup,
/// then category default) so the correction screen only edits [suggestedName].
class ScanResult {
  const ScanResult({
    required this.label,
    required this.category,
    required this.suggestedName,
    required this.confidence,
    required this.colorName,
    required this.dominantColor,
    required this.formality,
    required this.cutoutPng,
  });

  /// Winning class, one of the 18 in `labels.json`, e.g. `t_shirt`.
  final String label;

  final GarmentCategory category;

  /// Indonesian name ready for the `name` column, e.g. `Kaos Putih`.
  final String suggestedName;

  /// Softmax score of the winning class, 0..1.
  final double confidence;

  /// Indonesian colour label from K-Means over the cutout pixels.
  final String colorName;

  final Color dominantColor;

  /// 1 = santai, 5 = formal; seeded from [category].
  final int formality;

  /// Transparent-background PNG; uploaded as the item image.
  final Uint8List cutoutPng;

  /// `#RRGGBB` — the shape the `dominant_color` check accepts.
  String get dominantHex =>
      '#${(dominantColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
