import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_pdf/services/ad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdService frequency capping', () {
    late AdService ad;

    setUp(() async {
      AdService.debugOverrideIsSupportedPlatform = true;
      SharedPreferences.setMockInitialValues({
        'ads_enabled': true,
        'premium_until_timestamp': 0,
        AdService.completionPrefKey: 0,
      });
      await AdService.loadPreferences();
      ad = AdService();
      ad.interstitialShowCount = 0;
      ad.forceInterstitialReady = true;
      ad.resetCooldownForTesting();
    });

    tearDown(() {
      AdService.debugOverrideIsSupportedPlatform = null;
    });

    test('shouldShowAds is true when ads enabled and no premium', () {
      expect(AdService.shouldShowAds, isTrue);
    });

    test('shouldShowInterstitial is true on completions with capEveryN = 1', () {
      expect(AdService.shouldShowInterstitial(1), isTrue);
      expect(AdService.shouldShowInterstitial(2), isTrue);
      expect(AdService.capEveryN, equals(1));
    });

    test('recordToolCompletion shows interstitial on each completion', () async {
      SharedPreferences.setMockInitialValues({});
      await AdService.loadPreferences();

      await ad.recordToolCompletion();
      expect(ad.interstitialShowCount, 1);
      expect(await ad.completionCount(), 1);

      await ad.recordToolCompletion();
      expect(ad.interstitialShowCount, 2);
      expect(await ad.completionCount(), 2);
    });

    test('cooldown and pacing prevent rapid consecutive interstitials', () async {
      ad.forceInterstitialReady = false;
      ad.ignoreCooldownForTesting = false;
      // Immediate session allows first interstitial
      expect(ad.canShowInterstitial, isTrue);

      // Triggering an ad sets lastFullScreenAdShownTime
      ad.forceInterstitialReady = true;
      await ad.showInterstitialIfReady();

      // Right after showing, cooldown (25s) prevents immediate subsequent ad
      ad.forceInterstitialReady = false;
      expect(ad.canShowInterstitial, isFalse);

      // Overriding cooldown restores eligibility
      ad.ignoreCooldownForTesting = true;
      expect(ad.canShowInterstitial, isTrue);
    });
  });
}
