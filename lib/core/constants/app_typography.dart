import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// App typography using Google Fonts Nunito.
/// Follows elderly-friendly requirements: minimum 16sp body text, high contrast.
class AppTypography {
  static const double minTouchTargetSize = 48.0;
  static const double minBodyFontSize = 16.0;
  static const double largeTextScale = 1.2;

  static TextTheme textTheme(bool isDark, {bool largeTextMode = false}) {
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final scale = largeTextMode ? largeTextScale : 1.0;

    return TextTheme(
      // Wordmark and massive headers
      displayLarge: GoogleFonts.nunito(
        fontSize: 34 * scale,
        fontWeight: FontWeight.w900,
        color: textColor,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.nunito(
        fontSize: 28 * scale,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
      displaySmall: GoogleFonts.nunito(
        fontSize: 24 * scale,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
      // Section headers / Screen Titles
      headlineMedium: GoogleFonts.nunito(
        fontSize: 22 * scale,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.nunito(
        fontSize: 20 * scale,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      titleLarge: GoogleFonts.nunito(
        fontSize: 18 * scale,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      titleMedium: GoogleFonts.nunito(
        fontSize: 16 * scale,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      // Body text - minimum 16sp as required by OurNest elderly-friendly guidelines
      bodyLarge: GoogleFonts.nunito(
        fontSize: 18 * scale,
        fontWeight: FontWeight.w500,
        color: textColor,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.nunito(
        fontSize: 16 * scale, // Minimum 16sp!
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.4,
      ),
      bodySmall: GoogleFonts.nunito(
        fontSize: 14 * scale,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),
      // Labels (used by inputs, chips, buttons) - must use high-contrast textColor
      labelLarge: GoogleFonts.nunito(
        fontSize: 17 * scale,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      labelMedium: GoogleFonts.nunito(
        fontSize: 15 * scale,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
      ),
    );
  }
}
