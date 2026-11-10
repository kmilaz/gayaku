import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// True while the sign-up request is in flight, so a double tap cannot send two.
  bool _busy = false;

  Future<void> _signUp() async {
    setState(() => _busy = true);
    try {
      final user = await authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
      );
      if (!mounted) return;
      if (user == null) {
        // The project wants the email confirmed first, so there is no session
        // to open Home with. Say so and go back to Sign In.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check your email to confirm the account.'),
          ),
        );
        Navigator.of(context).pop();
        return;
      }
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: Stack(
        children: [
          // 1. Header Bagian Atas
          Container(
            // A fixed 35% header overflowed on short screens; a min height
            // lets it grow instead.
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height * 0.35,
            ),
            width: double.infinity,
            // Navy ground: `palette.ink` left the cream copy on near-white.
            color: palette.canvas,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.arrow_back,
                    size: 22,
                    color: palette.onAction,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 16),
                Text(
                  "Sign Up",
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 32,
                    height: 38 / 32,
                    fontWeight: FontWeight.bold,
                    color: palette.onAction,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Sign up to discover amazing things near around you.",
                  style: TextStyle(
                    color: palette.onAction.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 18 / 13,
                  ),
                ),
              ],
            ),
          ),

          // 2. Card Form Melayang
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.28),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: palette.sheet,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [AppDecorations.cardShadow],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Full Name
                      TextField(
                        controller: _nameController,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          height: 23 / 16,
                          color: palette.ink,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Full Name',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 16,
                            height: 23 / 16,
                            color: palette.inkMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            size: 22,
                            color: palette.inkMuted,
                          ),
                          filled: true,
                          fillColor: palette.canvas.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextField(
                        controller: _emailController,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          height: 23 / 16,
                          color: palette.ink,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Email',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 16,
                            height: 23 / 16,
                            color: palette.inkMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            size: 22,
                            color: palette.inkMuted,
                          ),
                          filled: true,
                          fillColor: palette.canvas.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          height: 23 / 16,
                          color: palette.ink,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 16,
                            height: 23 / 16,
                            color: palette.inkMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            size: 22,
                            color: palette.inkMuted,
                          ),
                          filled: true,
                          fillColor: palette.canvas.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tombol Sign Up
                      ElevatedButton(
                        onPressed: _busy ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.action,
                          foregroundColor: palette.onAction,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          "Sign Up",
                          style: TextStyle(
                            color: palette.onAction,
                            fontSize: 13,
                            height: 18 / 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Link Kembali ke Sign In
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account? ",
                      style: TextStyle(fontSize: 16, height: 23 / 16),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        "Sign In",
                        style: TextStyle(
                          fontSize: 16,
                          height: 23 / 16,
                          fontWeight: FontWeight.bold,
                          color: palette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
