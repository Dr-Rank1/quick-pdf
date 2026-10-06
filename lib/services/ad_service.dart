import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

/// Singleton that manages Unity Ads lifecycles (Banner, Interstitial, and Rewarded).
///
/// Frequency capping: shows an interstitial at most once every
/// [_capEveryN] tool completions to reduce ad fatigue.
class AdService {
  AdService._();
  static final AdService _instance = AdService._();
  factory AdService() => _instance;

  /// Unity Ads Game IDs from the Unity Monetization portal.
  static const String gameIdAndroid = '6200387';
  static const String gameIdIos = '6200386';

  static String get gameId => Platform.isIOS ? gameIdIos : gameIdAndroid;

  /// Standard Unity Ads placement IDs created for this project.
  static String get bannerPlacementId =>
      Platform.isIOS ? 'Banner_iOS' : 'Banner_Android';
  static String get interstitialPlacementId =>
      Platform.isIOS ? 'Interstitial_iOS' : 'Interstitial_Android';
  static String get rewardedPlacementId =>
      Platform.isIOS ? 'Rewarded_iOS' : 'Rewarded_Android';

  static const String _prefCompletions = 'ad_completion_count';
  static const String _prefPremiumUntil = 'premium_until_timestamp';
  static const int _capEveryN = 1;

  /// Minimum cooldown between any two full-screen ads (25 seconds).
  static const Duration minAdCooldown = Duration(seconds: 25);

  /// Minimum time after app launch before any interstitial is eligible (immediate).
  static const Duration minSessionDurationBeforeAd = Duration.zero;

  final DateTime _sessionStartTime = DateTime.now();
  DateTime? _lastFullScreenAdShownTime;

  @visibleForTesting
  bool ignoreCooldownForTesting = false;

  @visibleForTesting
  void resetCooldownForTesting() {
    _lastFullScreenAdShownTime = null;
  }

  @visibleForTesting
  static int get capEveryN => _capEveryN;

  @visibleForTesting
  static String get completionPrefKey => _prefCompletions;

  /// Whether an interstitial should be shown for this completion count.
  @visibleForTesting
  static bool shouldShowInterstitial(int completionCount) =>
      completionCount % _capEveryN == 0;

  /// Whether an interstitial is eligible based on session age and cooldown.
  bool get canShowInterstitial {
    if (!shouldShowAds) return false;
    if (forceInterstitialReady) return true;
    if (ignoreCooldownForTesting) return true;

    final now = DateTime.now();
    if (now.difference(_sessionStartTime) < minSessionDurationBeforeAd) {
      return false;
    }
    if (_lastFullScreenAdShownTime != null &&
        now.difference(_lastFullScreenAdShownTime!) < minAdCooldown) {
      return false;
    }
    return true;
  }

  @visibleForTesting
  int interstitialShowCount = 0;

  @visibleForTesting
  bool forceInterstitialReady = false;

  bool _initialized = false;
  bool _isInterstitialReady = false;
  bool _isRewardedReady = false;
  Future<void>? _configureFuture;

  bool get isInterstitialReady => _isInterstitialReady;
  bool get isRewardedReady => _isRewardedReady;

  @visibleForTesting
  static bool? debugOverrideIsSupportedPlatform;

  static bool _adsEnabledBySettings = true;
  static int _premiumUntil = 0;

  /// Whether any ad format should be requested or shown.
  static bool get shouldShowAds {
    if (debugOverrideIsSupportedPlatform != null) {
      if (!debugOverrideIsSupportedPlatform!) return false;
    } else {
      if (kIsWeb) return false;
      if (!Platform.isAndroid && !Platform.isIOS) return false;
    }
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

  /// Initializes Unity Ads SDK once.
  Future<void> configureSdk() async {
    if (!shouldShowAds) return;
    if (_initialized) return;
    _configureFuture ??= _doConfigure();
    await _configureFuture;
  }

  Future<void> _doConfigure() async {
    final completer = Completer<void>();

    try {
      await UnityAds.init(
        gameId: gameId,
        testMode: kDebugMode,
        onComplete: () {
          _initialized = true;
          debugPrint(
              'AdService: Unity Ads initialized (gameId=$gameId, testMode=$kDebugMode)');
          loadInterstitial();
          loadRewarded();
          if (!completer.isCompleted) completer.complete();
        },
        onFailed: (error, message) {
          debugPrint(
              'AdService: Unity Ads initialization failed: $error — $message');
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (e) {
      debugPrint('AdService: Unity Ads init exception: $e');
      if (!completer.isCompleted) completer.complete();
    }

    await completer.future;
  }

  // ── Interstitial ──────────────────────────────────────────────────────────

  Future<void> loadInterstitial() async {
    if (!shouldShowAds) return;
    await configureSdk();

    try {
      await UnityAds.load(
        placementId: interstitialPlacementId,
        onComplete: (placementId) {
          debugPrint('AdService: Unity interstitial loaded ($placementId)');
          _isInterstitialReady = true;
        },
        onFailed: (placementId, error, message) {
          debugPrint(
              'AdService: Unity interstitial load failed ($placementId): $error — $message');
          _isInterstitialReady = false;
        },
      );
    } catch (e) {
      debugPrint('AdService: Unity interstitial load error: $e');
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
      _lastFullScreenAdShownTime = DateTime.now();
      return;
    }
    if (!canShowInterstitial) {
      debugPrint('AdService: Interstitial skipped due to pacing/cooldown');
      return;
    }
    if (!_isInterstitialReady) {
      loadInterstitial();
      return;
    }

    try {
      _lastFullScreenAdShownTime = DateTime.now();
      await UnityAds.showVideoAd(
        placementId: interstitialPlacementId,
        onStart: (placementId) =>
            debugPrint('AdService: Unity interstitial started: $placementId'),
        onClick: (placementId) =>
            debugPrint('AdService: Unity interstitial clicked: $placementId'),
        onSkipped: (placementId) {
          debugPrint('AdService: Unity interstitial skipped: $placementId');
          _isInterstitialReady = false;
          interstitialShowCount++;
          loadInterstitial();
        },
        onComplete: (placementId) {
          debugPrint('AdService: Unity interstitial completed: $placementId');
          _isInterstitialReady = false;
          interstitialShowCount++;
          loadInterstitial();
        },
        onFailed: (placementId, error, message) {
          debugPrint(
              'AdService: Unity interstitial show failed ($placementId): $error — $message');
          _isInterstitialReady = false;
          loadInterstitial();
        },
      );
    } catch (e) {
      debugPrint('AdService: Unity interstitial show error: $e');
      _isInterstitialReady = false;
      loadInterstitial();
    }
  }

  // ── Rewarded video ────────────────────────────────────────────────────────

  Future<void> loadRewarded() async {
    if (!shouldShowAds) return;
    await configureSdk();

    try {
      await UnityAds.load(
        placementId: rewardedPlacementId,
        onComplete: (placementId) {
          debugPrint('AdService: Unity rewarded loaded ($placementId)');
          _isRewardedReady = true;
        },
        onFailed: (placementId, error, message) {
          debugPrint(
              'AdService: Unity rewarded load failed ($placementId): $error — $message');
          _isRewardedReady = false;
        },
      );
    } catch (e) {
      debugPrint('AdService: Unity rewarded load error: $e');
      _isRewardedReady = false;
    }
  }

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
    Future<void> grantOnce() async {
      if (grantStarted) return;
      grantStarted = true;
      try {
        await onRewarded();
      } catch (e) {
        debugPrint('AdService: error executing onRewarded: $e');
      }
    }

    try {
      _lastFullScreenAdShownTime = DateTime.now();
      await UnityAds.showVideoAd(
        placementId: rewardedPlacementId,
        onStart: (placementId) =>
            debugPrint('AdService: Unity rewarded started: $placementId'),
        onClick: (placementId) =>
            debugPrint('AdService: Unity rewarded clicked: $placementId'),
        onSkipped: (placementId) {
          debugPrint('AdService: Unity rewarded skipped: $placementId');
          onDismissed?.call();
          loadRewarded();
        },
        onComplete: (placementId) async {
          debugPrint('AdService: Unity rewarded completed: $placementId');
          await grantOnce();
          onDismissed?.call();
          loadRewarded();
        },
        onFailed: (placementId, error, message) async {
          debugPrint(
              'AdService: Unity rewarded show failed ($placementId): $error — $message. Falling back.');
          await grantOnce();
          onDismissed?.call();
          loadRewarded();
        },
      );
    } catch (e) {
      debugPrint('AdService: Unity rewarded exception: $e. Falling back.');
      await grantOnce();
      onDismissed?.call();
      loadRewarded();
    }
  }

  void dispose() {
    _isInterstitialReady = false;
    _isRewardedReady = false;
  }
}
