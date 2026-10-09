import 'package:flutter/material.dart';

import '../models/wardrobe.dart';

/// Color harmony between two garments on the HSV color wheel.
///
/// [score] is the raw harmony weight (0..1); the label is what the UI shows.
enum ColorHarmony {
  netral('Netral', 0.90),
  analog('Analog', 1.00),
  komplementer('Komplementer', 1.00),
  triadic('Triadic', 0.85),
  kontras('Kontras', 0.30);

  const ColorHarmony(this.label, this.score);

  final String label;
  final double score;
}

/// Shortest hue distance on the 360° wheel, 0..180.
double hueDistance(Color a, Color b) {
  final d = (HSVColor.fromColor(a).hue - HSVColor.fromColor(b).hue).abs();
  return d > 180 ? 360 - d : d;
}

/// Near-greyscale colors carry no hue, so they pair with anything.
bool isNeutral(Color c) {
  final hsv = HSVColor.fromColor(c);
  return hsv.saturation < 0.18 || hsv.value < 0.20 || hsv.value > 0.94;
}

ColorHarmony harmonyOf(Color a, Color b) {
  if (isNeutral(a) || isNeutral(b)) return ColorHarmony.netral;
  final d = hueDistance(a, b);
  if (d <= 30) return ColorHarmony.analog;
  if (d >= 150 && d <= 210) return ColorHarmony.komplementer;
  if ((d >= 105 && d < 150) || (d > 210 && d <= 255)) {
    return ColorHarmony.triadic;
  }
  return ColorHarmony.kontras;
}

/// Slots that stack on top of any outfit instead of competing with it.
const layeringCategories = {'Outerwear', 'Accessories'};

/// Two pieces of the same slot never pair — except layers, which stack.
bool canPair(WardrobeItem a, WardrobeItem b) =>
    a.category != b.category || layeringCategories.contains(a.category);

class MatchSuggestion {
  const MatchSuggestion({
    required this.item,
    required this.score,
    required this.reasons,
  });

  final WardrobeItem item;

  /// 0..1, higher is a better partner.
  final double score;

  /// Human-readable justifications, e.g. `['Komplementer', 'Cocok Formal']`.
  final List<String> reasons;

  int get percent => (score * 100).round();
}

/// Weighted compatibility: color harmony 50%, formality closeness 30%,
/// shared occasion 20% — the content-based scoring from the proposal (§6.2).
/// Returns 0 for a pair that must not be worn together.
double pairScore(WardrobeItem a, WardrobeItem b) {
  if (identical(a, b) || a.name == b.name) return 0;
  if (!canPair(a, b)) return 0;

  final harmony = harmonyOf(a.color, b.color);
  final gap = (a.formality - b.formality).abs();
  final shared = a.occasions.where(b.occasions.contains).length;

  return harmony.score * 0.5 +
      (1 - gap / 4).clamp(0.0, 1.0) * 0.3 +
      (shared == 0 ? 0.0 : 0.2);
}

MatchSuggestion? _score(WardrobeItem base, WardrobeItem other) {
  final score = pairScore(base, other);
  if (score == 0) return null;

  final harmony = harmonyOf(base.color, other.color);
  final gap = (base.formality - other.formality).abs();
  final shared = base.occasions.where(other.occasions.contains).toList();

  final reasons = <String>[harmony.label];
  if (gap <= 1) reasons.add('Formalitas seimbang');
  if (shared.isNotEmpty) reasons.add('Cocok ${shared.first}');
  return MatchSuggestion(item: other, score: score, reasons: reasons);
}

/// Every compatible item, best first.
List<MatchSuggestion> recommendMatches(
  WardrobeItem base,
  List<WardrobeItem> all, {
  int limit = 20,
}) {
  final out = all.map((o) => _score(base, o)).nonNulls.toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  return out.take(limit).toList();
}

/// One best partner per complementary slot, so the detail page reads as a
/// complete outfit instead of four near-identical bottoms.
List<MatchSuggestion> outfitFor(
  WardrobeItem base,
  List<WardrobeItem> all, {
  int limit = 4,
}) {
  final seen = <String>{};
  final out = <MatchSuggestion>[];
  for (final m in recommendMatches(base, all)) {
    if (seen.add(m.item.category)) out.add(m);
    if (out.length == limit) break;
  }
  return out;
}

/// Overall compatibility of a hand-built set: mean of every pair's score.
///
/// A conflicting pair (two tops, or the same item twice) scores 0, so the
/// number drops instead of silently ignoring the clash.
double outfitScore(List<WardrobeItem> items) {
  if (items.length < 2) return 0;
  var sum = 0.0;
  var pairs = 0;
  for (var i = 0; i < items.length; i++) {
    for (var j = i + 1; j < items.length; j++) {
      sum += pairScore(items[i], items[j]);
      pairs++;
    }
  }
  return pairs == 0 ? 0 : sum / pairs;
}

/// The pair dragging the set down, or null for fewer than two items.
({WardrobeItem a, WardrobeItem b, double score})? weakestPair(
  List<WardrobeItem> items,
) {
  ({WardrobeItem a, WardrobeItem b, double score})? worst;
  for (var i = 0; i < items.length; i++) {
    for (var j = i + 1; j < items.length; j++) {
      final s = pairScore(items[i], items[j]);
      if (worst == null || s < worst.score) {
        worst = (a: items[i], b: items[j], score: s);
      }
    }
  }
  return worst;
}

/// A one-item swap that lifts [outfitScore] towards [threshold].
class SwapSuggestion {
  const SwapSuggestion({
    required this.index,
    required this.from,
    required this.to,
    required this.newScore,
  });

  /// Position in the outfit's item list that gets replaced.
  final int index;
  final WardrobeItem from;
  final WardrobeItem to;

  /// [outfitScore] of the set after the swap.
  final double newScore;

  int get gainPercent => (newScore * 100).round();
}

/// Up to [limit] swaps that raise the score, best first.
///
/// Empty when the set already meets [threshold] — nothing to recommend.
List<SwapSuggestion> improveOutfit(
  List<WardrobeItem> items,
  List<WardrobeItem> catalog, {
  required double threshold,
  int limit = 3,
}) {
  final current = outfitScore(items);
  if (current >= threshold || items.length < 2) return const [];

  final used = items.map((i) => i.name).toSet();
  final out = <SwapSuggestion>[];
  for (var i = 0; i < items.length; i++) {
    for (final candidate in catalog) {
      if (used.contains(candidate.name)) continue;
      final trial = [...items]..[i] = candidate;
      final score = outfitScore(trial);
      if (score > current) {
        out.add(
          SwapSuggestion(
            index: i,
            from: items[i],
            to: candidate,
            newScore: score,
          ),
        );
      }
    }
  }
  out.sort((a, b) => b.newScore.compareTo(a.newScore));
  return out.take(limit).toList();
}
