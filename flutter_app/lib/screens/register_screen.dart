import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: Stack(
        children: [
          // 1. Header Bagian Atas
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
            width: double.infinity,
            color: palette.action,
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
                    color: palette.onAction.withValues(alpha: 0.8),
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
