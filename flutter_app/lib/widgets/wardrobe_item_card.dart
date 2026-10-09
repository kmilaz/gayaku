import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wardrobe.dart';
import '../screens/wardrobe_item_detail_screen.dart';
import '../theme/app_theme.dart';
import 'placeholder_image.dart';

/// Grid tile: photo over `Name` and `Category • Brand`.
class WardrobeItemCard extends StatelessWidget {
  const WardrobeItemCard({super.key, required this.item});

  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WardrobeItemDetailScreen(item: item),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: AppColors.espresso.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: SizedBox(
                  width: double.infinity,
                  child: PlaceholderImage(
                    imagePath: item.imagePath,
                    icon: Icons.checkroom_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.espresso,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.brand.isEmpty
                  ? item.category
                  : '${item.category} • ${item.brand}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.taupe),
            ),
          ],
        ),
      ),
    );
  }
}
