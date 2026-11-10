import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wardrobe.dart';
import '../navigation.dart';
import '../state/outfit_store.dart';
import '../state/planner_store.dart';
import '../state/wardrobe_store.dart';
import '../theme/app_theme.dart';
import 'placeholder_image.dart';

/// Featured outfit card with a style-tag pill over the photo and a
/// decorative check button.
class TodaysLookCard extends StatelessWidget {
  const TodaysLookCard({super.key, required this.look});

  final Look look;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return GestureDetector(
      onTap: () => openNavDestination(context, 3),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PlaceholderImage(
                      imagePath: look.imagePath,
                      icon: Icons.checkroom_outlined,
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: palette.canvas,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(999),
                          ),
                        ),
                        child: Text(
                          look.styleTag,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            height: 15 / 11,
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    look.title,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 20,
                      height: 26 / 20,
                      fontWeight: FontWeight.bold,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    look.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 18 / 13,
                      color: palette.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home section: the combination planned for today, or a card that says the
/// day is still unplanned. No stock photo stands in for a missing plan.
class TodaysLookSection extends StatelessWidget {
  const TodaysLookSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<DateTime, PlannerEntry>>(
      valueListenable: plannerEntries,
      builder: (context, entries, _) {
        return ValueListenableBuilder<List<SavedOutfit>>(
          valueListenable: savedOutfits,
          builder: (context, outfits, _) {
            final entry = entries[dayKey(DateTime.now())];
            final match = outfits.where((o) => o.id == entry?.outfitId);
            if (match.isEmpty) return const _NoPlanCard();
            return ValueListenableBuilder<List<WardrobeItem>>(
              valueListenable: wardrobeItems,
              builder: (context, catalog, _) =>
                  TodaysLookCard(look: lookFromOutfit(match.single, catalog)),
            );
          },
        );
      },
    );
  }
}

class _NoPlanCard extends StatelessWidget {
  const _NoPlanCard();

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.sheet,
        borderRadius: BorderRadius.circular(20),
      ),
      // The section header above already says "Today's Look"; the card only
      // carries the empty state.
      child: Text(
        'Belum ada rencana untuk hari ini.',
        style: GoogleFonts.inter(fontSize: 13, color: palette.inkMuted),
      ),
    );
  }
}
