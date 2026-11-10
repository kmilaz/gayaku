import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/greeting_header.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recently_added.dart';
import '../widgets/todays_look_card.dart';

/// Home dashboard: greeting, Today's Look, search, quick actions, recently
/// added, and a floating pill bottom nav.
///
/// Every nav destination opens its own route with a back button, so the whole
/// bar behaves one way rather than mixing pushed routes with in-place swaps.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GreetingHeader(),
                    const SizedBox(height: 16),
                    Text(
                      "Today's Look",
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 24,
                        height: 30 / 24,
                        fontWeight: FontWeight.bold,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const TodaysLookSection(),
                    const SizedBox(height: 20),
                    QuickActions(
                      onFavoriteTap: () => openNavDestination(
                        context,
                        1,
                        initialTab: 1,
                        initialFavoritesOnly: true,
                      ),
                      onPlannerTap: () => openNavDestination(context, 3),
                    ),
                    const SizedBox(height: 20),
                    const RecentlyAdded(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: HomeBottomNav(
                currentIndex: 0,
                onTap: (index) => openNavDestination(context, index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
