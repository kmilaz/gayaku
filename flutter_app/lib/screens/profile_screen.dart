import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/home_bottom_nav.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.showNav = true});

  /// False inside `NavShell`, which draws the one shared bar.
  final bool showNav;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = '';
  String? _photoUrl;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // --- AMBIL DATA PROFIL DARI SUPABASE ---
  Future<void> _loadUserProfile() async {
    final user = authService.currentUser;
    if (user == null) return;

    final initialName = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()
        : user.email.split('@').first;

    setState(() {
      _userName = initialName;
    });
    globalUserName.value = initialName; // Sinkronisasi awal state reaktif

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('display_name, photo_url')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        final dbName = data['display_name'] as String?;
        final fetchedName = (dbName != null && dbName.trim().isNotEmpty)
            ? dbName.trim()
            : _userName;

        setState(() {
          _userName = fetchedName;
          _photoUrl = data['photo_url'] as String?;
        });

        // Update juga nilai global agar Home langsung mengikuti data dari database
        globalUserName.value = fetchedName;
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  void _showNotificationsBottomSheet(AppPalette palette, bool isId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: globalNotificationsEnabled,
          builder: (context, isEnabled, _) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isId ? 'Pengaturan Notifikasi' : 'Notification Settings',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isId
                        ? 'Terima pengingat harian untuk mengecek atau merencanakan outfit.'
                        : 'Receive daily reminders to check or plan your outfits.',
                    style: TextStyle(fontSize: 13, color: palette.inkMuted),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: Text(
                      isId ? 'Pengingat Harian' : 'Daily Reminder',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    subtitle: Text(
                      isId
                          ? 'Notifikasi pukul 07:00 pagi'
                          : 'Notification at 07:00 AM',
                      style: TextStyle(fontSize: 12, color: palette.inkMuted),
                    ),
                    value: isEnabled,
                    activeThumbColor: palette.accent,
                    onChanged: (val) {
                      globalNotificationsEnabled.value = val;
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDataPrivacyBottomSheet(AppPalette palette, bool isId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isId ? 'Data & Kebijakan Privasi' : 'Data & Privacy Policy',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isId
                    ? 'Aplikasi ini menjaga kerahasiaan data lemari pakaian dan profil Anda. Seluruh data disimpan secara aman menggunakan sistem penyimpanan lokal dan *cloud*, serta hanya digunakan untuk mendukung fitur rekomendasi OOTD Anda.'
                    : 'This app protects the confidentiality of your wardrobe and profile data. All data is securely stored using local and cloud storage, and is used solely to support your OOTD recommendation features.',
                style: TextStyle(
                  fontSize: 13,
                  color: palette.inkMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    isId ? 'Mengerti' : 'Got It',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // --- FUNGSI UNGGAH FOTO DARI GALERI KE SUPABASE STORAGE ---
  Future<void> _pickAndUploadPhoto() async {
    final user = authService.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);
      _showSnackBar('Mengunggah foto profil...');

      final file = File(pickedFile.path);
      final fileExt = pickedFile.path.split('.').last;
      final filePath = '${user.id}/avatar.$fileExt';

      final supabase = Supabase.instance.client;

      // 1. Upload ke Storage Bucket 'avatars'
      await supabase.storage
          .from('avatars')
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));

      // 2. Ambil Public URL
      final imageUrl = supabase.storage.from('avatars').getPublicUrl(filePath);

      // 3. Simpan URL ke Tabel Profiles
      await supabase
          .from('profiles')
          .update({
            'photo_url': imageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      if (mounted) {
        setState(() {
          _photoUrl = imageUrl;
          _isUploadingPhoto = false;
        });
        _showSnackBar('Foto profil berhasil diperbarui!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        _showSnackBar('Gagal mengunggah foto profil.');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // Widget Tampilan Avatar (Foto Profil / Inisial Nama)
  Widget _buildAvatarWidget(
    AppPalette palette, {
    double size = 72,
    double fontSize = 32,
  }) {
    if (_isUploadingPhoto) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.surface,
        image: (_photoUrl != null && _photoUrl!.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(_photoUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: (_photoUrl == null || _photoUrl!.isEmpty)
          ? Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'I',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: fontSize,
                  color: palette.accentInk,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
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
                    _buildAvatarWidget(palette, size: 80, fontSize: 36),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(modalContext);
                          await _pickAndUploadPhoto();
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
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      Navigator.pop(modalContext);
                      return;
                    }
                    try {
                      final updated = await authService.updateDisplayName(name);
                      if (!mounted || !modalContext.mounted) return;

                      setState(() => _userName = updated.displayName);

                      // [PENTING] Update nilai global agar Home langsung ikut berubah reaktif!
                      globalUserName.value = updated.displayName;

                      Navigator.pop(modalContext);
                      _showSnackBar('Profil berhasil diperbarui!');
                    } catch (_) {
                      if (!modalContext.mounted) return;
                      _showSnackBar('Gagal menyimpan profil.');
                    }
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

  // --- MODAL 2: ACCOUNT & UBAH PASSWORD ---
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
                  authService.currentUser?.email ?? '',
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
                  Navigator.pop(modalContext); // Tutup account sheet
                  _showChangePasswordBottomSheet(
                    palette,
                  ); // Buka form password baru
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- MODAL FORM INPUT PASSWORD BARU ---
  void _showChangePasswordBottomSheet(AppPalette palette) {
    final TextEditingController passwordController = TextEditingController();

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
                'Ubah Kata Sandi Baru',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Masukkan password baru (min. 6 karakter)',
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
              const SizedBox(height: 20),
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
                  onPressed: () async {
                    final newPassword = passwordController.text.trim();
                    if (newPassword.length < 6) {
                      _showSnackBar('Password minimal 6 karakter.');
                      return;
                    }
                    try {
                      await authService.updatePassword(newPassword);
                      if (!mounted || !modalContext.mounted) return;
                      Navigator.pop(modalContext);
                      _showSnackBar(
                        'Kata sandi berhasil diperbarui di database!',
                      );
                    } catch (e) {
                      if (!modalContext.mounted) return;
                      _showSnackBar('Gagal memperbarui kata sandi: $e');
                    }
                  },
                  child: const Text(
                    'Simpan Kata Sandi',
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

  // --- MODAL PREFERENCES (TEMA & BAHASA) ---
  void _showPreferencesBottomSheet(AppPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: globalThemeMode,
          builder: (context, currentTheme, _) {
            final isDark = currentTheme == ThemeMode.dark;
            return ValueListenableBuilder<String>(
              valueListenable: globalLanguage,
              builder: (context, langCode, _) {
                final isId = langCode == 'id';
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isId ? 'Preferensi' : 'Preferences',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pengaturan Tema Gelap / Terang (Midnight vs Midnight Deep)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          Icons.dark_mode_outlined,
                          color: palette.accentInk,
                        ),
                        title: Text(
                          isId ? 'Mode Gelap Pekat' : 'Deep Dark Mode',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                        subtitle: Text(
                          isId
                              ? (isDark
                                    ? 'Aktif (Midnight Deep)'
                                    : 'Nonaktif (Midnight Default)')
                              : (isDark
                                    ? 'Enabled (Midnight Deep)'
                                    : 'Disabled (Midnight Default)'),
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.inkMuted,
                          ),
                        ),
                        value: isDark,
                        activeThumbColor: palette.accent,
                        onChanged: (val) {
                          globalThemeMode.value = val
                              ? ThemeMode.dark
                              : ThemeMode.light;
                        },
                      ),
                      const Divider(),

                      // Pengaturan Bahasa
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.language_outlined,
                          color: palette.accentInk,
                        ),
                        title: Text(
                          isId ? 'Bahasa' : 'Language',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                        subtitle: Text(
                          isId ? 'Bahasa Indonesia' : 'English',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.inkMuted,
                          ),
                        ),
                        trailing: Icon(
                          Icons.swap_horiz,
                          color: palette.inkMuted,
                        ),
                        onTap: () {
                          globalLanguage.value = isId ? 'en' : 'id';
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: globalLanguage,
      builder: (context, langCode, _) {
        final isId = langCode == 'id';

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
                              // Inside the shell there is no route to pop:
                              // the arrow is the way back to home.
                              onPressed: () => navEmbedded(context)
                                  ? openNavDestination(context, 0)
                                  : Navigator.maybePop(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isId ? 'Pengaturan' : 'Settings',
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
                                _buildAvatarWidget(
                                  palette,
                                  size: 72,
                                  fontSize: 32,
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
                                  authService.currentUser?.email ?? '',
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

                        // --- SECTION: PERSONALIZATION ---
                        _sectionTitle(
                          palette,
                          isId ? 'PERSONALISASI' : 'PERSONALIZATION',
                        ),
                        const SizedBox(height: 12),
                        _settingsTile(
                          palette,
                          icon: Icons.tune_rounded,
                          title: isId ? 'Preferensi' : 'Preferences',
                          onTap: () => _showPreferencesBottomSheet(palette),
                        ),
                        const SizedBox(height: 24),

                        // --- SECTION: GENERAL ---
                        _sectionTitle(palette, isId ? 'UMUM' : 'GENERAL'),
                        const SizedBox(height: 12),
                        _settingsTile(
                          palette,
                          icon: Icons.person_outline,
                          title: isId ? 'Akun' : 'Account',
                          onTap: () => _showAccountBottomSheet(palette),
                        ),
                        const SizedBox(height: 12),
                        _settingsTile(
                          palette,
                          icon: Icons.notifications_outlined,
                          title: isId ? 'Notifikasi' : 'Notifications',
                          onTap: () =>
                              _showNotificationsBottomSheet(palette, isId),
                        ),
                        const SizedBox(height: 12),
                        _settingsTile(
                          palette,
                          icon: Icons.lock_outline,
                          title: isId ? 'Data & Privasi' : 'Data & Privacy',
                          onTap: () => _showDataPrivacyBottomSheet(
                            palette,
                            isId,
                          ), // <--- Hubungkan ke sini
                        ),
                        const SizedBox(height: 36),

// --- TOMBOL LOG OUT ---
Center(
  child: GestureDetector(
    onTap: () {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: palette.sheet,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isId ? 'Konfirmasi Keluar' : 'Confirm Log Out',
            style: TextStyle(
              color: palette.ink,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            isId
                ? 'Apakah Anda yakin ingin keluar dari akun?'
                : 'Are you sure you want to log out?',
            style: TextStyle(
              color: palette.inkMuted,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                isId ? 'Batal' : 'Cancel',
                style: TextStyle(color: palette.inkMuted),
              ),
            ),
            TextButton(
              onPressed: () async {
                await authService.signOut();
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              child: Text(
                isId ? 'Keluar' : 'Log Out',
                style: const TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      );
    },
                            child: Text(
                              isId ? 'Keluar Akun' : 'Log Out',
                              style: TextStyle(
                                color: palette.action,
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
                if (widget.showNav)
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
      },
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
    return Material(
      color: palette.sheet,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
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
