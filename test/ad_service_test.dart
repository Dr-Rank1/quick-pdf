import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_pdf/services/ad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdService frequency capping', () {
    late AdService ad;

    setUp(() {
      ad = AdService();
      ad.interstitialShowCount = 0;
      ad.forceInterstitialReady = true;
    });

    test('shouldShowAds is always true', () {
      expect(AdService.shouldShowAds, isTrue);
    });

    test('shouldShowInterstitial is true every 3rd completion', () {
      expect(AdService.shouldShowInterstitial(1), isFalse);
      expect(AdService.shouldShowInterstitial(2), isFalse);
      expect(AdService.shouldShowInterstitial(3), isTrue);
      expect(AdService.shouldShowInterstitial(6), isTrue);
      expect(AdService.capEveryN, equals(3));
    });

    test('recordToolCompletion shows interstitial on 3rd completion', () async {
      SharedPreferences.setMockInitialValues({});

      await ad.recordToolCompletion();
      expect(ad.interstitialShowCount, 0);
      expect(await ad.completionCount(), 1);

      await ad.recordToolCompletion();
      expect(ad.interstitialShowCount, 0);
      expect(await ad.completionCount(), 2);

      await ad.recordToolCompletion();
      expect(ad.interstitialShowCount, 1);
      expect(await ad.completionCount(), 3);
    });
  });
}
