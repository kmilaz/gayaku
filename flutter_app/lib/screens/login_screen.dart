import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: Stack(
        children: [
          // 1. Header Bagian Atas (Espresso Theme)
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
            width: double.infinity,
            color: palette.action,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.onAction.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.checkroom,
                        color: palette.onAction,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "GayaKu",
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 24,
                        height: 30 / 24,
                        fontWeight: FontWeight.bold,
                        color: palette.onAction,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  "Sign In",
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 32,
                    height: 38 / 32,
                    fontWeight: FontWeight.bold,
                    color: palette.onAction,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Sign in to discover amazing outfits around you.",
                  style: TextStyle(
                    color: palette.onAction.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 18 / 13,
                  ),
                ),
              ],
            ),
          ),

          // 2. Card Form Melayang (Overlapping Card)
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
                      // Input Email
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

                      // Input Password
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

                      // Tombol Sign In
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.action,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          "Sign In",
                          style: TextStyle(
                            color: palette.onAction,
                            fontSize: 13,
                            height: 18 / 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Forgot Password Link
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: palette.inkMuted,
                              fontSize: 13,
                              height: 18 / 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Pembatas "Or connect using"
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              "Or connect using",
                              style: TextStyle(
                                color: palette.inkMuted,
                                fontSize: 11,
                                height: 15 / 11,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tombol Sosial Media / Google
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialButton(
                            icon: Icons.g_mobiledata,
                            color: palette.ink,
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const HomeScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Link ke Registrasi
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(fontSize: 16, height: 23 / 16),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "Sign Up",
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

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
