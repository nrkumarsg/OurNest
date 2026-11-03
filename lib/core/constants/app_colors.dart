import 'package:flutter/material.dart';

/// App color palette matching the OurNest branding specification.
/// - Primary (Deep Teal): #1F5C57
/// - Accent (Warm Coral): #E07A4F
/// - Background: #F7F4EE
/// - Surfaces: #FFFFFF
/// - Text: #1E2B2A
/// - Secondary Text: #4A5856
class AppColors {
  // Brand Colors
  static const Color primaryTeal = Color(0xFF1F5C57);
  static const Color primaryTealLight = Color(0xFF2E8079);
  static const Color primaryTealDark = Color(0xFF143D39);

  static const Color accentCoral = Color(0xFFE07A4F);
  static const Color accentCoralLight = Color(0xFFEA9673);
  static const Color accentCoralDark = Color(0xFFBA5A32);

  // Light Theme Colors
  static const Color backgroundLight = Color(0xFFF7F4EE);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1E2B2A);
  static const Color textSecondaryLight = Color(0xFF4A5856);
  static const Color dividerLight = Color(0xFFE5E0D5);
  static const Color inputBorderLight = Color(0xFFD4CFC4);

  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF0F1817);
  static const Color surfaceDark = Color(0xFF1B2827);
  static const Color textPrimaryDark = Color(0xFFF7F4EE);
  static const Color textSecondaryDark = Color(0xFF98A6A4);
  static const Color dividerDark = Color(0xFF273836);
  static const Color inputBorderDark = Color(0xFF334A47);

  // Status & Feedback Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFED6C02);
  static const Color info = Color(0xFF0288D1);

  // Alarm Colors
  static const Color alarmActive = Color(0xFFE07A4F);
  static const Color alarmEscalated = Color(0xFFD32F2F);
  static const Color alarmDismissed = Color(0xFF2E7D32);
}
