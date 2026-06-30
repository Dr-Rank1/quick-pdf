import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_pdf/constants/preference_keys.dart';
import 'package:quick_pdf/providers/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/services/premium_service.dart';
import 'package:quick_pdf/router/app_router.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:go_router/go_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-load prefs before runApp so the correct screen shows on the
  // very first frame — no blank screen or spinner at launch.
  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding =
      prefs.getBool(kPrefHasSeenOnboarding) ?? false;

  await AdService.loadPreferences();
  await PremiumService.instance.initialize();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  final router = createAppRouter(showOnboarding: !hasSeenOnboarding);

  runApp(ProviderScope(
    child: QuickPDFApp(router: router),
  ));

  // Initialise AdMob and background maintenance after the first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    DocumentDatabase().cleanupStaleThumbnails();
    if (AdService.shouldShowAds) {
      MobileAds.instance
          .initialize()
          .then((_) => AdService().loadInterstitial());
    }
  });
}

class QuickPDFApp extends ConsumerWidget {
  final GoRouter router;
  const QuickPDFApp({super.key, required this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    const seed = Color(0xFF1A237E); // deep navy primary

    return MaterialApp.router(
      title: 'QuickPDF',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(seed, Brightness.light),
      darkTheme: _buildTheme(seed, Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
    );
  }

  ThemeData _buildTheme(Color seed, Brightness brightness) {
    final cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      secondary: const Color(0xFFFFB300), // amber accent
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: cs.primaryContainer,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }
}
