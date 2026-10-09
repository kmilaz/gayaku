import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/greeting_header.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/occasion_search_bar.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recently_added.dart';
import '../widgets/todays_look_card.dart';
import 'add_item_stub.dart';
import 'profile_screen.dart';

/// Static home/dashboard: greeting, Today's Look, search, quick actions,
/// recently added, and a floating pill bottom nav.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  void _onNavTap(int index) {
    if (index == 2) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AddItemStub()));
      return;
    }
    setState(() => _navIndex = index);
  }

// TAMBAHKAN 1: Wadah tampilan dashboard
  Widget _buildHomeDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GreetingHeader(),
          const SizedBox(height: 16),
          Text(
            "Today's Look",
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.espresso,
            ),
          ),
          const SizedBox(height: 12),
          const TodaysLookCard(),
          const SizedBox(height: 16),
          const OccasionSearchBar(),
          const SizedBox(height: 20),
          const QuickActions(),
          const SizedBox(height: 20),
          const RecentlyAdded(),
        ],
      ),
    );
  }

  // TAMBAHKAN 2: Penyeleksi layar profil
  Widget _buildBody() {
    if (_navIndex == 4) {
      return const ProfileScreen();
    }
    return _buildHomeDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildBody(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: HomeBottomNav(
                currentIndex: _navIndex,
                onTap: _onNavTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}