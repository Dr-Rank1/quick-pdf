import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:startapp_sdk/startapp.dart';

/// Singleton that owns Start.io interstitial / rewarded ad lifecycles.
/// The banner is managed separately in `_BannerAdArea` (main_nav_page.dart).
///
/// Frequency capping: shows an interstitial at most once every
/// [_capEveryN] tool completions to reduce ad fatigue.
class AdService {
  AdService._();
  static final AdService _instance = AdService._();
  factory AdService() => _instance;

  /// Start.io App ID from the portal (ads.txt account remains `177461104`).
  static const String startIoAppId = '206385656';

  static const String _prefCompletions = 'ad_completion_count';
  static const String _prefPremiumUntil = 'premium_until_timestamp';
  static const int _capEveryN = 3;

  final StartAppSdk _sdk = StartAppSdk();

  @visibleForTesting
  static int get capEveryN => _capEveryN;

  @visibleForTesting
  static String get completionPrefKey => _prefCompletions;

  /// Whether an interstitial should be shown for this completion count.
  @visibleForTesting
  static bool shouldShowInterstitial(int completionCount) =>
      completionCount % _capEveryN == 0;

  @visibleForTesting
  int interstitialShowCount = 0;

  @visibleForTesting
  bool forceInterstitialReady = false;

  StartAppInterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;
  Future<void>? _configureFuture;

  bool get isInterstitialReady => _isInterstitialReady;

  static bool _adsEnabledBySettings = true;
  static int _premiumUntil = 0;

  /// Whether any ad format should be requested or shown.
  static bool get shouldShowAds {
    if (!_adsEnabledBySettings) return false;
    if (DateTime.now().millisecondsSinceEpoch < _premiumUntil) return false;
    return true;
  }

  static Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _adsEnabledBySettings = prefs.getBool('ads_enabled') ?? true;
    _premiumUntil = prefs.getInt(_prefPremiumUntil) ?? 0;
  }

  static Future<void> setAdsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ads_enabled', enabled);
    _adsEnabledBySettings = enabled;
  }

  static Future<void> activate24hPremium() async {
    final prefs = await SharedPreferences.getInstance();
    final until =
        DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
    await prefs.setInt(_prefPremiumUntil, until);
    _premiumUntil = until;
  }

  /// Configures Start.io once (test mode in debug builds).
  /// Concurrent callers await the same future so banners never load before
  /// `setTestAdsEnabled` finishes.
  Future<void> configureSdk() async {
    if (!shouldShowAds) return;
    _configureFuture ??= _doConfigure();
    await _configureFuture;
  }

  Future<void> _doConfigure() async {
    // Test ads only while developing — disabled in release builds.
    await _sdk.setTestAdsEnabled(kDebugMode);
    debugPrint(
        'AdService: Start.io configured (testAds=$kDebugMode, appId=$startIoAppId)');
  }

  StartAppSdk get sdk => _sdk;

  // ── Interstitial ──────────────────────────────────────────────────────────

  Future<void> loadInterstitial() async {
    if (!shouldShowAds) return;
    await configureSdk();
    _isInterstitialReady = false;

    try {
      final ad = await _sdk.loadInterstitialAd(
        onAdHidden: () {
          _interstitialAd?.dispose();
          _interstitialAd = null;
          _isInterstitialReady = false;
          loadInterstitial();
        },
        onAdNotDisplayed: () {
          _interstitialAd?.dispose();
          _interstitialAd = null;
          _isInterstitialReady = false;
          loadInterstitial();
        },
      );
      _interstitialAd = ad;
      _isInterstitialReady = true;
    } catch (e) {
      debugPrint('AdService: interstitial load failed — $e');
      _interstitialAd = null;
      _isInterstitialReady = false;
    }
  }

  /// Call after each tool completion. Shows an interstitial once every
  /// [_capEveryN] completions. Silently skips if ads are disabled or not ready.
  Future<void> recordToolCompletion() async {
    if (!shouldShowAds) return;
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_prefCompletions) ?? 0) + 1;
    await prefs.setInt(_prefCompletions, count);
    if (count % _capEveryN == 0) {
      await showInterstitialIfReady();
    }
  }

  @visibleForTesting
  Future<int> completionCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefCompletions) ?? 0;
  }

  Future<void> showInterstitialIfReady() async {
    if (!shouldShowAds) return;
    if (forceInterstitialReady) {
      interstitialShowCount++;
      return;
    }
    if (!_isInterstitialReady || _interstitialAd == null) return;

    try {
      final shown = await _interstitialAd!.show();
      if (shown) {
        interstitialShowCount++;
        // Interstitial can only be shown once.
        _interstitialAd = null;
        _isInterstitialReady = false;
        loadInterstitial();
      }
    } catch (e) {
      debugPrint('AdService: interstitial show failed — $e');
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isInterstitialReady = false;
      loadInterstitial();
    }
  }

  // ── Rewarded ads ──────────────────────────────────────────────────────────

  /// Loads and shows a rewarded video, then awaits [onRewarded] exactly once.
  /// Falls back to [onRewarded] if the ad fails so the feature is never blocked.
  Future<void> showRewardedOrFallback({
    required Future<void> Function() onRewarded,
    VoidCallback? onDismissed,
  }) async {
    if (!shouldShowAds) {
      await onRewarded();
      return;
    }

    await configureSdk();

    var grantStarted = false;
    final grantDone = Completer<void>();

    Future<void> grantOnce() async {
      if (grantStarted) return;
      grantStarted = true;
      try {
        await onRewarded();
        if (!grantDone.isCompleted) grantDone.complete();
      } catch (e, st) {
        if (!grantDone.isCompleted) grantDone.completeError(e, st);
      }
    }

    try {
      final ad = await _sdk.loadRewardedVideoAd(
        onVideoCompleted: () {
          // Kick off grant; callers await [grantDone] below.
          unawaited(grantOnce());
        },
        onAdHidden: () {
          // Closed early or after completion — grant at most once.
          unawaited(grantOnce());
          onDismissed?.call();
        },
        onAdNotDisplayed: () {
          debugPrint('AdService: rewarded not displayed. Falling back.');
          unawaited(grantOnce());
        },
      );

      final shown = await ad.show();
      if (!shown) {
        await grantOnce();
      } else {
        try {
          await grantDone.future.timeout(const Duration(minutes: 3));
        } on TimeoutException {
          // SDK never delivered completion/hidden callbacks — still unlock.
          await grantOnce();
        }
      }
      ad.dispose();
    } catch (e) {
      debugPrint('AdService: rewarded load/show failed — $e. Falling back.');
      if (!grantStarted) {
        await grantOnce();
      } else {
        await grantDone.future;
      }
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialReady = false;
  }
}
