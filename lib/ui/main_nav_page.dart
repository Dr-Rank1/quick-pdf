import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:startapp_sdk/startapp.dart';

class QuickPDFHomePage extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const QuickPDFHomePage({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BannerAdArea(),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: navigationShell.goBranch,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.build_outlined),
                selectedIcon: Icon(Icons.build),
                label: 'Tools',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
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

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (!AdService.shouldShowAds) return;
    try {
      await AdService().configureSdk();
      final ad = await AdService().sdk.loadBannerAd(StartAppBannerType.BANNER);
      if (!mounted) {
        ad.dispose();
        return;
      }
      setState(() => _ad = ad);
    } catch (e) {
      debugPrint('Banner: failed to load — $e');
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService.shouldShowAds || _ad == null) {
      return const SizedBox.shrink();
    }
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      child: StartAppBanner(_ad!),
    );
  }
}
