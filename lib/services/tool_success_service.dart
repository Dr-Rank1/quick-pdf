import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/services/review_service.dart';

/// Central hook for successful major document operations (ads + review).
class ToolSuccessService {
  ToolSuccessService._();

  static Future<void> onMajorOperationComplete() async {
    await ReviewService.instance.recordMajorOperation();
    await AdService().recordToolCompletion();
  }
}
