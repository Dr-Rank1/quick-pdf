import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/theme/app_colors.dart';
import 'package:startapp_sdk/startapp.dart';

class QuickPDFHomePage extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const QuickPDFHomePage({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      body: navigationShell,
      // Custom bottom chrome: nav → banner → system inset.
      // NavigationBar's built-in SafeArea is removed so the banner is not
      // pushed under the gesture bar (which made ads look "missing").
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              backgroundColor: AppColors.surface(brightness),
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined,
                      color: AppColors.muted(brightness)),
                  selectedIcon:
                      const Icon(Icons.home, color: AppColors.amber),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.build_outlined,
                      color: AppColors.muted(brightness)),
                  selectedIcon:
                      const Icon(Icons.build, color: AppColors.amber),
                  label: 'Tools',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined,
                      color: AppColors.muted(brightness)),
                  selectedIcon:
                      const Icon(Icons.settings, color: AppColors.amber),
                  label: 'Settings',
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border(brightness)),
          const _BannerAdArea(),
          if (bottomInset > 0)
            ColoredBox(
              color: AppColors.surface2(brightness),
              child: SizedBox(height: bottomInset, width: double.infinity),
            ),
        ],
      ),
    );
  }
}

// ── Persistent banner ad (Start.io) ───────────────────────────────────────────

class _BannerAdArea extends StatefulWidget {
  const _BannerAdArea();

  @override
  State<_BannerAdArea> createState() => _BannerAdAreaState();
}

class _BannerAdAreaState extends State<_BannerAdArea> {
  StartAppBannerAd? _ad;
  bool _loading = false;
  int _attempts = 0;

  /// Start.io standard banner is 320×50; smaller slots clip / hide the ad.
  static const double _bannerHeight = 50;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (!AdService.shouldShowAds || _loading) return;
    _loading = true;
    _attempts++;
    try {
      await AdService().configureSdk();
      final ad = await AdService().sdk.loadBannerAd(StartAppBannerType.BANNER);
      if (!mounted) {
        ad.dispose();
        return;
      }
      setState(() => _ad = ad);
    } catch (e) {
      debugPrint('Banner: failed to load (attempt $_attempts) — $e');
      if (mounted && _attempts < 4) {
        await Future<void>.delayed(Duration(seconds: 2 * _attempts));
        if (mounted) {
          _loading = false;
          await _loadAd();
          return;
        }
      }
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (!AdService.shouldShowAds) return const SizedBox.shrink();

    final height = _ad?.height ?? _bannerHeight;

    return Container(
      height: height,
      alignment: Alignment.center,
      width: double.infinity,
      color: AppColors.surface2(brightness),
      child: _ad != null
          ? StartAppBanner(_ad!)
          : Text(
              'Ad',
              style: TextStyle(
                fontSize: 9,
                color: AppColors.muted(brightness).withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
    );
  }
}
