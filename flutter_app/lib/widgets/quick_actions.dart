import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Two shortcut cards; each one opens a real tab.
class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.onFavoriteTap,
    required this.onPlannerTap,
  });

  final VoidCallback onFavoriteTap;
  final VoidCallback onPlannerTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 24,
            height: 30 / 24,
            fontWeight: FontWeight.bold,
            color: palette.ink,
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
                onTap: onPlannerTap,
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
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.all(Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: palette.accentInk, size: 28),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 18 / 13,
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
