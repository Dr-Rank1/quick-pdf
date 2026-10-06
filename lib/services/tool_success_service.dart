import 'dart:async';

import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/services/review_service.dart';

/// Central hook for successful major document operations (ads + review).
class ToolSuccessService {
  ToolSuccessService._();

  static Future<void> onMajorOperationComplete() async {
    await ReviewService.instance.recordMajorOperation();
    // Allow the tool's success screen or navigation transition to settle
    // smoothly before evaluating and presenting any interstitial ad.
    unawaited(Future.microtask(() async {
      await Future.delayed(const Duration(milliseconds: 700));
      await AdService().recordToolCompletion();
    }));
  }
}
