import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/theme/app_colors.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class QuickPDFHomePage extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const QuickPDFHomePage({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BannerAdArea(),
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.border(brightness),
          ),
          NavigationBar(
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
        ],
      ),
    );
  }
}

// ── Persistent banner ad (Unity Ads) ─────────────────────────────────────────

class _BannerAdArea extends StatefulWidget {
  const _BannerAdArea();

  @override
  State<_BannerAdArea> createState() => _BannerAdAreaState();
}

class _BannerAdAreaState extends State<_BannerAdArea> {
  bool _adLoaded = false;

  @override
  void initState() {
    super.initState();
    if (AdService.shouldShowAds) {
      AdService().configureSdk();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService.shouldShowAds) return const SizedBox.shrink();

    final brightness = Theme.of(context).brightness;

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 250),
      crossFadeState: _adLoaded
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: Container(
        alignment: Alignment.center,
        width: double.infinity,
        color: AppColors.surface(brightness),
        child: UnityBannerAd(
          placementId: AdService.bannerPlacementId,
          onLoad: (placementId) {
            debugPrint('Unity banner loaded: $placementId');
            if (mounted && !_adLoaded) {
              setState(() => _adLoaded = true);
            }
          },
          onFailed: (placementId, error, message) {
            debugPrint('Unity banner failed: $placementId — $error $message');
            if (mounted && _adLoaded) {
              setState(() => _adLoaded = false);
            }
          },
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }
}
