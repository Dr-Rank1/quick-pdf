import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quick_pdf/constants/preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton that owns the interstitial ad lifecycle.
/// The banner is managed separately in _BannerAdArea (main_nav_page.dart).
///
/// Frequency capping: shows an interstitial at most once every
/// [_capEveryN] tool completions to reduce ad fatigue.
class AdService {
  AdService._();
  static final AdService _instance = AdService._();
  factory AdService() => _instance;

  static const String bannerAdUnitId =
      'ca-app-pub-9418386170210711/8362178112';
  static const String interstitialAdUnitId =
      'ca-app-pub-9418386170210711/3537611287';
  /// Dedicated rewarded ad unit — replace with your AdMob rewarded placement ID.
  static const String rewardedAdUnitId =
      'ca-app-pub-9418386170210711/0000000000';
  static const String _prefCompletions = 'ad_completion_count';
  static const int _capEveryN = 3;

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

  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

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

  // ── Interstitial ──────────────────────────────────────────────────────────

  void loadInterstitial() {
    if (!shouldShowAds) return;
    _isInterstitialReady = false;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialReady = false;
              loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (_, error) {
              debugPrint('AdService: interstitial show failed — $error');
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialReady = false;
              loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: interstitial load failed — $error');
          _interstitialAd = null;
          _isInterstitialReady = false;
        },
      ),
    );
  }

  /// Call after each tool completion. Shows an interstitial once every
  /// [_capEveryN] completions. Silently skips if ads are disabled or not ready.
  Future<void> recordToolCompletion() async {
    if (!shouldShowAds) return;
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_prefCompletions) ?? 0) + 1;
    await prefs.setInt(_prefCompletions, count);
    if (count % _capEveryN == 0) {
      showInterstitialIfReady();
    }
  }

  @visibleForTesting
  Future<int> completionCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefCompletions) ?? 0;
  }

  void showInterstitialIfReady() {
    if (!shouldShowAds) return;
    if (forceInterstitialReady ||
        (_isInterstitialReady && _interstitialAd != null)) {
      interstitialShowCount++;
      if (!forceInterstitialReady) {
        _interstitialAd!.show();
      }
    }
  }

  // ── Rewarded ads ──────────────────────────────────────────────────────────

  /// Loads and shows a rewarded ad, calling [onRewarded] if the user earns
  /// the reward. Falls back to calling [onRewarded] immediately if the ad
  /// fails, so the feature is never blocked.
  Future<void> showRewardedOrFallback({
    required VoidCallback onRewarded,
    VoidCallback? onDismissed,
  }) async {
    if (!shouldShowAds) {
      onRewarded();
      return;
    }

    RewardedAd? ad;
    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (loaded) => ad = loaded,
        onAdFailedToLoad: (error) {
          debugPrint('AdService: rewarded load failed — $error. Falling back.');
          onRewarded(); // never block the user
        },
      ),
    );

    if (ad == null) return; // already handled by onAdFailedToLoad

    ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        ad!.dispose();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('AdService: rewarded show failed — $error. Falling back.');
        ad!.dispose();
        onRewarded(); // fall back
      },
    );

    await ad!.show(
      onUserEarnedReward: (_, __) => onRewarded(),
    );
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialReady = false;
  }
}
