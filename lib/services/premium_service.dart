import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:quick_pdf/constants/preference_keys.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the non-consumable "Remove Ads" in-app purchase.
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  /// Play Console / App Store product identifier.
  static const String removeAdsProductId = 'quickpdf_remove_ads';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _storeAvailable = false;
  ProductDetails? _removeAdsProduct;
  bool _purchasePending = false;

  bool get isStoreAvailable => _storeAvailable;
  bool get isPurchasePending => _purchasePending;
  ProductDetails? get removeAdsProduct => _removeAdsProduct;

  String? get formattedPrice => _removeAdsProduct?.price;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    AdService.premiumUnlocked =
        prefs.getBool(kPrefPremiumUnlocked) ?? false;

    if (AdService.premiumUnlocked) return;

    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) return;

    _subscription ??= _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) => debugPrint('PremiumService: purchase stream — $e'),
    );

    await _queryProducts();
    await _iap.restorePurchases();
  }

  Future<void> _queryProducts() async {
    final response =
        await _iap.queryProductDetails({removeAdsProductId});
    if (response.error != null) {
      debugPrint('PremiumService: query failed — ${response.error}');
      return;
    }
    if (response.productDetails.isNotEmpty) {
      _removeAdsProduct = response.productDetails.first;
    }
  }

  Future<bool> purchaseRemoveAds() async {
    if (_removeAdsProduct == null || _purchasePending) return false;
    _purchasePending = true;
    try {
      return await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: _removeAdsProduct!),
      );
    } catch (e) {
      debugPrint('PremiumService: purchase failed — $e');
      _purchasePending = false;
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_storeAvailable) return;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != removeAdsProductId) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _grantPremium();
      }

      if (purchase.status == PurchaseStatus.error) {
        debugPrint('PremiumService: ${purchase.error}');
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }

      if (purchase.status != PurchaseStatus.pending) {
        _purchasePending = false;
      }
    }
  }

  Future<void> _grantPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefPremiumUnlocked, true);
    AdService.premiumUnlocked = true;
    AdService().dispose();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
