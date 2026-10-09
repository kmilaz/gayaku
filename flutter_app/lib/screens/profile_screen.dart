import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFFFFBEA); // Warna cream background
    const primaryTextColor = Color(0xFF2C221E); // Warna espresso teks
    const accentColor = Color(0xFFC9A27A); // Warna cokelat aksen
    const iconBgColor = Color(0xFFFFF8EE); // Warna background lingkaran icon

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- APP BAR / HEADER ---
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: primaryTextColor),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- PROFILE HEADER ---
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF3E7D3),
                        ),
                        child: Center(
                          child: Text(
                            'I',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 32,
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: backgroundColor, width: 2),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Isabella',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Premium Member',
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryTextColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // --- SECTION 1: PERSONALIZATION ---
              _buildSectionTitle('PERSONALIZATION'),
              const SizedBox(height: 12),
              _buildSettingsTile(
                icon: Icons.checkroom_outlined,
                title: 'Style Profile',
                iconBgColor: iconBgColor,
                accentColor: accentColor,
                primaryTextColor: primaryTextColor,
              ),
              const SizedBox(height: 12),
              _buildSettingsTile(
                icon: Icons.tune,
                title: 'Preferences',
                iconBgColor: iconBgColor,
                accentColor: accentColor,
                primaryTextColor: primaryTextColor,
              ),
              const SizedBox(height: 24),

              // --- SECTION 2: GENERAL ---
              _buildSectionTitle('GENERAL'),
              const SizedBox(height: 12),
              _buildSettingsTile(
                icon: Icons.person_outline,
                title: 'Account',
                iconBgColor: iconBgColor,
                accentColor: accentColor,
                primaryTextColor: primaryTextColor,
              ),
              const SizedBox(height: 12),
              _buildSettingsTile(
                icon: Icons.notifications_none_outlined,
                title: 'Notifications',
                iconBgColor: iconBgColor,
                accentColor: accentColor,
                primaryTextColor: primaryTextColor,
              ),
              const SizedBox(height: 12),
              _buildSettingsTile(
                icon: Icons.lock_outline,
                title: 'Data & Privacy',
                iconBgColor: iconBgColor,
                accentColor: accentColor,
                primaryTextColor: primaryTextColor,
              ),
              const SizedBox(height: 36),

              // --- TOMBOL LOG OUT ---
              Center(
                child: GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: Color(0xFFE57373),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Color(0xFF9E8B7D),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required Color iconBgColor,
    required Color accentColor,
    required Color primaryTextColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accentColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFFC4C4C4),
          size: 20,
        ),
        onTap: () {},
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}