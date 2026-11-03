import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State notifier for ThemeMode (Light / Dark / System)
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  void toggleTheme(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  void setSystem() {
    state = ThemeMode.system;
  }
}

/// State notifier for elderly-friendly Large Text Mode
final largeTextModeProvider = StateNotifierProvider<LargeTextNotifier, bool>((ref) {
  return LargeTextNotifier();
});

class LargeTextNotifier extends StateNotifier<bool> {
  LargeTextNotifier() : super(false);

  void toggle() {
    state = !state;
  }

  void set(bool value) {
    state = value;
  }
}
