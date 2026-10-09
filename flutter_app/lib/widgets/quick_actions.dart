import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'placeholder_image.dart';

/// Two shortcut cards for destinations not yet built.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key, this.onFavoriteTap});

  final VoidCallback? onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.espresso,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                label: 'Your Favorite',
                icon: Icons.favorite_outline,
                onTap: onFavoriteTap,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                label: 'Plan Week',
                icon: Icons.calendar_month_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => showComingSoon(context, label),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: AppColors.beige,
          borderRadius: BorderRadius.all(Radius.circular(32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.tan, size: 28),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.espresso,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
