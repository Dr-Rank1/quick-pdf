import 'package:flutter/material.dart';

/// QuickPDF visual tokens from `design_reference/canonical/App.tsx`.
abstract final class AppColors {
  static const amber = Color(0xFFFFB300);
  static const navy = Color(0xFF1E2E8E);

  // Dark
  static const darkBg = Color(0xFF0B0E1C);
  static const darkSurface = Color(0xFF141828);
  static const darkSurface2 = Color(0xFF1B2036);
  static const darkText = Color(0xFFEEF1FF);
  static const darkMuted = Color(0xFF8891AA);
  static const darkBorder = Color(0x12FFFFFF); // ~7% white

  // Light
  static const lightBg = Color(0xFFF2F4FF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFE6EAF8);
  static const lightText = Color(0xFF0D1130);
  static const lightMuted = Color(0xFF6271A0);
  static const lightBorder = Color(0x12000000); // ~7% black

  static Color bg(Brightness b) =>
      b == Brightness.dark ? darkBg : lightBg;
  static Color surface(Brightness b) =>
      b == Brightness.dark ? darkSurface : lightSurface;
  static Color surface2(Brightness b) =>
      b == Brightness.dark ? darkSurface2 : lightSurface2;
  static Color text(Brightness b) =>
      b == Brightness.dark ? darkText : lightText;
  static Color muted(Brightness b) =>
      b == Brightness.dark ? darkMuted : lightMuted;
  static Color border(Brightness b) =>
      b == Brightness.dark ? darkBorder : lightBorder;
}
