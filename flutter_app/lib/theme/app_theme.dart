import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared color constants for the Gayaku home screen.
abstract final class AppColors {
  static const cream = Color(0xFFFFFDF0);
  static const warmBackground = Color(0xFFFAF7EE);
  static const beige = Color(0xFFF7F4EB);
  static const imageSurface = Color(0xFFF3EEE2);
  static const scannerSurface = Color(0xFFE2E0DD);
  static const accentSurface = Color(0xFFFFF3E2);
  static const white = Color(0xFFFFFFFF);
  static const tan = Color(0xFFD3A277);
  static const espresso = Color(0xFF3E2F25);
  static const taupe = Color(0xFFA89C8D);
}

abstract final class AppDecorations {
  static const cardShadow = BoxShadow(
    color: Color(0x143E2F25),
    blurRadius: 18,
    offset: Offset(0, 8),
  );

  static const panelShadow = BoxShadow(
    color: Color(0x123E2F25),
    blurRadius: 16,
    offset: Offset(0, 7),
  );
}

/// App [ThemeData]: Playfair Display for display text, Inter for body.
abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final text = base.textTheme.copyWith(
      displayLarge: GoogleFonts.playfairDisplay(
        textStyle: base.textTheme.displayLarge,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        textStyle: base.textTheme.displayMedium,
      ),
      displaySmall: GoogleFonts.playfairDisplay(
        textStyle: base.textTheme.displaySmall,
      ),
      headlineLarge: GoogleFonts.playfairDisplay(
        textStyle: base.textTheme.headlineLarge,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        textStyle: base.textTheme.headlineMedium,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        textStyle: base.textTheme.headlineSmall,
      ),
      bodyLarge: GoogleFonts.inter(textStyle: base.textTheme.bodyLarge),
      bodyMedium: GoogleFonts.inter(textStyle: base.textTheme.bodyMedium),
      bodySmall: GoogleFonts.inter(textStyle: base.textTheme.bodySmall),
      labelLarge: GoogleFonts.inter(textStyle: base.textTheme.labelLarge),
      labelMedium: GoogleFonts.inter(textStyle: base.textTheme.labelMedium),
      labelSmall: GoogleFonts.inter(textStyle: base.textTheme.labelSmall),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.tan,
        surface: AppColors.cream,
      ),
      textTheme: text.apply(
        displayColor: AppColors.espresso,
        bodyColor: AppColors.espresso,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.espresso,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.beige,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(32)),
        ),
      ),
    );
  }
}
