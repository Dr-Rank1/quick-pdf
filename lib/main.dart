import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_pdf/constants/preference_keys.dart';
import 'package:quick_pdf/providers/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/router/app_router.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-load prefs before runApp so the correct screen shows on the
  // very first frame — no blank screen or spinner at launch.
  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding =
      prefs.getBool(kPrefHasSeenOnboarding) ?? false;
  final initialTheme = themeModeFromPrefs(prefs);

  await AdService.loadPreferences();
  // Warm Start.io before the first frame so the banner doesn't race test-mode.
  if (AdService.shouldShowAds) {
    await AdService().configureSdk();
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  final router = createAppRouter(showOnboarding: !hasSeenOnboarding);

  runApp(ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier(initialTheme)),
    ],
    child: QuickPDFApp(router: router),
  ));

  // Initialise Start.io and background maintenance after the first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    DocumentDatabase().cleanupStaleThumbnails();
    if (AdService.shouldShowAds) {
      AdService().loadInterstitial();
    }
  });
}

class QuickPDFApp extends ConsumerStatefulWidget {
  final GoRouter router;
  const QuickPDFApp({super.key, required this.router});

  @override
  ConsumerState<QuickPDFApp> createState() => _QuickPDFAppState();
}

class _QuickPDFAppState extends ConsumerState<QuickPDFApp> with WidgetsBindingObserver {
  DateTime? _lastPausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastPausedTime != null) {
        final backgroundDuration = DateTime.now().difference(_lastPausedTime!);
        if (backgroundDuration.inMinutes >= 2) {
          if (AdService.shouldShowAds) {
            AdService().showInterstitialIfReady();
          }
        }
      }
      _lastPausedTime = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'QuickPDF',
      debugShowCheckedModeBanner: false,
      theme: buildQuickPdfTheme(Brightness.light),
      darkTheme: buildQuickPdfTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: widget.router,
    );
  }
}
