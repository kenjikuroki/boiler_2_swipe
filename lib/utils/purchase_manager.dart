import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ad_manager.dart';

class PurchaseManager {
  static final PurchaseManager instance = PurchaseManager._internal();
  PurchaseManager._internal();

  static const String productIdUnlockB = 'unlock_b';
  static const String _keyIsPremium = 'is_premium';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  final ValueNotifier<bool> isPremium = ValueNotifier<bool>(false);

  Future<void> initialize() async {
    // Load persisted status
    final prefs = await SharedPreferences.getInstance();
    isPremium.value = prefs.getBool(_keyIsPremium) ?? false;

    // Listen for purchase updates
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('Purchase error: $error');
    });
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if needed
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          if (purchaseDetails.productID == productIdUnlockB) {
            await _setPremiumStatus(true);
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> buyUnlockB() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      debugPrint('Store not available');
      return;
    }

    const Set<String> _kIds = {productIdUnlockB};
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kIds);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Product not found: ${response.notFoundIDs}');
      return;
    }

    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    // Use buyNonConsumable for ad removal
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  Future<void> _setPremiumStatus(bool value) async {
    isPremium.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsPremium, value);
    
    if (value) {
      // Immediately notify AdManager to stop ads
      AdManager.instance.onPremiumPurchased();
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}
