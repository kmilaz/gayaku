import 'dart:math';

/// RFC 4122 v4 id. Local cache and Postgres share it: `wardrobe_items.id` is a
/// uuid, so an item scanned offline already carries the id the cloud accepts.
String newWardrobeItemId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final _random = Random.secure();
