import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quick_pdf/theme/app_colors.dart';

ThemeData buildQuickPdfTheme(Brightness brightness) {
  final bg = AppColors.bg(brightness);
  final surface = AppColors.surface(brightness);
  final surface2 = AppColors.surface2(brightness);
  final text = AppColors.text(brightness);
  final muted = AppColors.muted(brightness);
  final border = AppColors.border(brightness);

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: bg,
  );

  final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
    bodyColor: text,
    displayColor: text,
  );

  final cs = ColorScheme(
    brightness: brightness,
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.amber,
    onSecondary: const Color(0xFF070915),
    error: const Color(0xFFE53935),
    onError: Colors.white,
    surface: surface,
    onSurface: text,
    onSurfaceVariant: muted,
    outline: border,
    outlineVariant: border,
    surfaceContainerHighest: surface2,
    surfaceContainerHigh: surface2,
    surfaceContainer: surface,
    primaryContainer: AppColors.navy,
    onPrimaryContainer: Colors.white,
    secondaryContainer: AppColors.amber.withValues(alpha: 0.18),
    onSecondaryContainer: text,
  );

  return base.copyWith(
    colorScheme: cs,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: bg,
      foregroundColor: text,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: text,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      elevation: 0,
      height: 64,
      indicatorColor: AppColors.amber.withValues(alpha: 0.20),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 10,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? AppColors.amber : muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 20,
          color: active ? AppColors.amber : muted,
        );
      }),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.amber,
      foregroundColor: Colors.black,
      elevation: 4,
      shape: CircleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      hintStyle: TextStyle(color: muted, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.amber),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: AppColors.amber.withValues(alpha: 0.18),
      side: BorderSide(color: border),
      labelStyle: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(
        color: AppColors.amber,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: muted,
      textColor: text,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.amber;
        return surface2;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.amber,
      thumbColor: AppColors.amber,
      inactiveTrackColor: surface2,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: surface2,
      contentTextStyle: TextStyle(color: text),
    ),
  );
}

/// Brand wordmark: Quick + amber PDF.
class QuickPdfWordmark extends StatelessWidget {
  final double fontSize;
  const QuickPdfWordmark({super.key, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).colorScheme.onSurface;
    return Text.rich(
      TextSpan(
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        children: [
          TextSpan(text: 'Quick', style: TextStyle(color: text)),
          const TextSpan(
            text: 'PDF',
            style: TextStyle(color: AppColors.amber),
          ),
        ],
      ),
    );
  }
}
