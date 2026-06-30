import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prompts satisfied users for a store rating after major tool successes.
class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  static const String _prefMajorOps = 'major_operation_count';
  static const String _prefReviewPrompted = 'review_prompt_shown';
  static const int operationsBeforePrompt = 5;

  /// Call after a successful merge, compress, OCR, split, or similar workflow.
  Future<void> recordMajorOperation() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefReviewPrompted) ?? false) return;

    final count = (prefs.getInt(_prefMajorOps) ?? 0) + 1;
    await prefs.setInt(_prefMajorOps, count);

    if (count < operationsBeforePrompt) return;

    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
        await prefs.setBool(_prefReviewPrompted, true);
      }
    } catch (_) {
      // Never block the user on review errors.
    }
  }

  @visibleForTesting
  static Future<int> majorOperationCountForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefMajorOps) ?? 0;
  }
}
