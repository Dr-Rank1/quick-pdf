import 'package:flutter/foundation.dart';
import 'package:quick_pdf/constants/preference_keys.dart';
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
  static const String startIoAppId = '206613327';

  static const String _prefCompletions = 'ad_completion_count';
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
  bool _sdkConfigured = false;

  bool get isInterstitialReady => _isInterstitialReady;

  // ── Ads enabled flag (for testing / user preference) ──────────────────────

  static bool adsEnabled = true;

  /// Set when the user purchases or restores the Remove Ads IAP.
  static bool premiumUnlocked = false;

  /// Whether any ad format should be requested or shown.
  static bool get shouldShowAds => adsEnabled && !premiumUnlocked;

  static Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    premiumUnlocked = prefs.getBool(kPrefPremiumUnlocked) ?? false;
    adsEnabled = prefs.getBool(kPrefAdsEnabled) ?? true;
  }

  /// Configures Start.io once (test mode in debug builds).
  Future<void> configureSdk() async {
    if (_sdkConfigured || !shouldShowAds) return;
    _sdkConfigured = true;
    // Test ads only while developing — disabled in release builds.
    await _sdk.setTestAdsEnabled(kDebugMode);
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

  /// Loads and shows a rewarded video, calling [onRewarded] when the video
  /// completes. Falls back to [onRewarded] immediately if the ad fails so
  /// the feature is never blocked.
  Future<void> showRewardedOrFallback({
    required VoidCallback onRewarded,
    VoidCallback? onDismissed,
  }) async {
    if (!shouldShowAds) {
      onRewarded();
      return;
    }

    await configureSdk();
    var rewarded = false;

    try {
      final ad = await _sdk.loadRewardedVideoAd(
        onVideoCompleted: () {
          rewarded = true;
          onRewarded();
        },
        onAdHidden: () {
          if (!rewarded) {
            // User closed early — still fall back so tools are not blocked.
            onRewarded();
          }
          onDismissed?.call();
        },
        onAdNotDisplayed: () {
          debugPrint('AdService: rewarded not displayed. Falling back.');
          onRewarded();
        },
      );

      final shown = await ad.show();
      if (!shown && !rewarded) {
        debugPrint('AdService: rewarded show returned false. Falling back.');
        onRewarded();
      }
      ad.dispose();
    } catch (e) {
      debugPrint('AdService: rewarded load/show failed — $e. Falling back.');
      onRewarded();
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialReady = false;
  }
}
