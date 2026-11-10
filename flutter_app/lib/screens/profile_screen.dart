import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/home_bottom_nav.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Isabella';

  // State sederhana untuk contoh pengaturan
  bool _darkMode = false;
  String _selectedLanguage = 'Indonesia';
  bool _pushNotif = true;
  bool _dailyReminder = false;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // --- MODAL EDIT PROFILE ---
  void _showEditProfileBottomSheet(AppPalette palette) {
    final TextEditingController nameController = TextEditingController(
      text: _userName,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Profile',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.surface,
                      ),
                      child: Center(
                        child: Text(
                          _userName.isNotEmpty
                              ? _userName[0].toUpperCase()
                              : 'I',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 36,
                            color: palette.accentInk,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(modalContext);
                          _showSnackBar('Pilih foto dari galeri...');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: palette.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.canvas, width: 2),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: palette.onAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Nama Pengguna',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: palette.canvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: TextStyle(color: palette.ink, fontSize: 16),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    setState(() {
                      if (nameController.text.trim().isNotEmpty) {
                        _userName = nameController.text.trim();
                      }
                    });
                    Navigator.pop(modalContext);
                    _showSnackBar('Profil berhasil diperbarui!');
                  },
                  child: const Text(
                    'Simpan Perubahan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- MODAL 1: PREFERENCES ---
  void _showPreferencesBottomSheet(AppPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preferences',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      'Mode Gelap',
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Mengubah tampilan ke warna gelap',
                      style: TextStyle(color: palette.inkMuted, fontSize: 12),
                    ),
                    value: _darkMode,
                    activeThumbColor: palette.accent,
                    onChanged: (val) {
                      setModalState(() => _darkMode = val);
                      setState(() => _darkMode = val);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: Text(
                      'Bahasa Aplikasi',
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: DropdownButton<String>(
                      value: _selectedLanguage,
                      underline: const SizedBox(),
                      items: ['Indonesia', 'English'].map((lang) {
                        return DropdownMenuItem(value: lang, child: Text(lang));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => _selectedLanguage = val);
                          setState(() => _selectedLanguage = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL 2: ACCOUNT ---
  void _showAccountBottomSheet(AppPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Info',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.email_outlined, color: palette.accentInk),
                title: Text(
                  'Email',
                  style: TextStyle(fontSize: 12, color: palette.inkMuted),
                ),
                subtitle: Text(
                  'isabella@gayaku.id',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.phone_outlined, color: palette.accentInk),
                title: Text(
                  'Nomor Telepon',
                  style: TextStyle(fontSize: 12, color: palette.inkMuted),
                ),
                subtitle: Text(
                  '+62 812 3456 7890',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.lock_reset_outlined,
                  color: palette.accentInk,
                ),
                title: Text(
                  'Ubah Kata Sandi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(modalContext);
                  _showSnackBar('Fitur Ubah Password dikirim ke Email!');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- MODAL 3: NOTIFICATIONS ---
  void _showNotificationsBottomSheet(AppPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Settings',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      'Notifikasi Push',
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Terima pengingat dan info promo',
                      style: TextStyle(color: palette.inkMuted, fontSize: 12),
                    ),
                    value: _pushNotif,
                    activeThumbColor: palette.accent,
                    onChanged: (val) {
                      setModalState(() => _pushNotif = val);
                      setState(() => _pushNotif = val);
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      'Pengingat Outfit Harian',
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Rekomendasi pakaian setiap pagi',
                      style: TextStyle(color: palette.inkMuted, fontSize: 12),
                    ),
                    value: _dailyReminder,
                    activeThumbColor: palette.accent,
                    onChanged: (val) {
                      setModalState(() => _dailyReminder = val);
                      setState(() => _dailyReminder = val);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL 4: DATA & PRIVACY ---
  void _showPrivacyBottomSheet(AppPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data & Privacy',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.cleaning_services_outlined,
                  color: palette.accentInk,
                ),
                title: Text(
                  'Hapus Cache Aplikasi',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                subtitle: Text(
                  'Membebaskan memori tanpa menghapus akun',
                  style: TextStyle(fontSize: 12, color: palette.inkMuted),
                ),
                onTap: () {
                  Navigator.pop(modalContext);
                  _showSnackBar('Cache berhasil dibersihkan!');
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.privacy_tip_outlined,
                  color: palette.accentInk,
                ),
                title: Text(
                  'Kebijakan Privasi',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(modalContext);
                  _showSnackBar('Membuka dokumen Kebijakan Privasi...');
                },
              ),
            ],
          ),
        );
      },
    );
  }

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- APP BAR / HEADER ---
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            size: 22,
                            color: palette.ink,
                          ),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Settings',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 20,
                            height: 26 / 20,
                            fontWeight: FontWeight.bold,
                            color: palette.ink,
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
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette.surface,
                              ),
                              child: Center(
                                child: Text(
                                  _userName.isNotEmpty
                                      ? _userName[0].toUpperCase()
                                      : 'I',
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontSize: 32,
                                    height: 38 / 32,
                                    color: palette.accentInk,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () =>
                                    _showEditProfileBottomSheet(palette),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: palette.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: palette.canvas,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: palette.onAccent,
                                  ),
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
                              _userName,
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 32,
                                height: 38 / 32,
                                fontWeight: FontWeight.bold,
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Premium Member',
                              style: TextStyle(
                                fontSize: 11,
                                height: 15 / 11,
                                color: palette.ink.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // --- SECTION 1: PERSONALIZATION ---
                    _sectionTitle(palette, 'PERSONALIZATION'),
                    const SizedBox(height: 12),
                    _settingsTile(
                      palette,
                      icon: Icons.tune,
                      title: 'Preferences',
                      onTap: () => _showPreferencesBottomSheet(palette),
                    ),
                    const SizedBox(height: 24),

                    // --- SECTION 2: GENERAL ---
                    _sectionTitle(palette, 'GENERAL'),
                    const SizedBox(height: 12),
                    _settingsTile(
                      palette,
                      icon: Icons.person_outline,
                      title: 'Account',
                      onTap: () => _showAccountBottomSheet(palette),
                    ),
                    const SizedBox(height: 12),
                    _settingsTile(
                      palette,
                      icon: Icons.notifications_none_outlined,
                      title: 'Notifications',
                      onTap: () => _showNotificationsBottomSheet(palette),
                    ),
                    const SizedBox(height: 12),
                    _settingsTile(
                      palette,
                      icon: Icons.lock_outline,
                      title: 'Data & Privacy',
                      onTap: () => _showPrivacyBottomSheet(palette),
                    ),
                    const SizedBox(height: 36),

                    // --- TOMBOL LOG OUT ---
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Konfirmasi Log Out'),
                              content: const Text(
                                'Apakah Anda yakin ingin keluar dari akun?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Batal'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const LoginScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  },
                                  child: Text(
                                    'Keluar',
                                    style: TextStyle(color: palette.actionInk),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text(
                          'Log Out',
                          style: TextStyle(
                            color: palette.actionInk,
                            fontSize: 13,
                            height: 18 / 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: HomeBottomNav(
                currentIndex: 4,
                onTap: (index) => openNavDestination(context, index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(AppPalette palette, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        height: 15 / 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: palette.inkMuted,
      ),
    );
  }

  Widget _settingsTile(
    AppPalette palette, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.sheet,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: palette.accentTint,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: palette.accentInk, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            height: 23 / 16,
            fontWeight: FontWeight.w600,
            color: palette.ink,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: palette.inkMuted, size: 22),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
