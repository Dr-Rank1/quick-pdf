import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

ThemeMode themeModeFromPrefs(SharedPreferences prefs) {
  final modeString = prefs.getString('theme_mode');
  switch (modeString) {
    case 'light':
      return ThemeMode.light;
    case 'system':
      return ThemeMode.system;
    case 'dark':
    default:
      return ThemeMode.dark; // design reference is dark-first
  }
}

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier([ThemeMode? initial]) : super(initial ?? ThemeMode.dark) {
    if (initial == null) {
      _loadTheme();
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    state = themeModeFromPrefs(prefs);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    state = mode;
    final String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      case ThemeMode.system:
        modeString = 'system';
        break;
    }
    await prefs.setString('theme_mode', modeString);
  }
}
