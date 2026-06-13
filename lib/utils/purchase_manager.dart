import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/local_app_config.dart';
import '../models/app_data.dart';
import 'ad_manager.dart';
import 'prefs_helper.dart';

class PurchaseManager {
  static final PurchaseManager instance = PurchaseManager._internal();
  PurchaseManager._internal();

  static const String _prefsKeyPremium = 'is_premium';
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  final ValueNotifier<bool> isPremium = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPurchasing = ValueNotifier<bool>(false);
  String _productId = LocalAppConfig.iosPremiumProductId;

  String get productId {
    if (_productId.trim().isNotEmpty) return _productId;
    if (kIsWeb) return LocalAppConfig.androidPremiumProductId;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return LocalAppConfig.iosPremiumProductId;
    }
    return LocalAppConfig.androidPremiumProductId;
  }

  void setProductId(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty ||
        normalized.toLowerCase() == 'nan' ||
        normalized.toLowerCase() == 'null') {
      return;
    }
    _productId = normalized;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    isPremium.value = prefs.getBool(_prefsKeyPremium) ?? false;

    if (isPremium.value) {
      AdManager.instance.disposeAll();
    }

    final Stream purchaseUpdated = _iap.purchaseStream;
    _subscription =
        purchaseUpdated.listen(
              (purchaseDetailsList) {
                _listenToPurchaseUpdated(purchaseDetailsList);
              },
              onDone: () {
                _subscription.cancel();
              },
              onError: (error) {
                debugPrint('PurchaseManager Error: $error');
              },
            )
            as StreamSubscription<List<PurchaseDetails>>;

    await _queryProducts();
  }

  Future<void> _queryProducts() async {
    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) return;
      final response = await _iap.queryProductDetails({productId});
      if (response.error == null) {
        _products = response.productDetails;
      } else {
        debugPrint(
          'PurchaseManager Error querying products: ${response.error}',
        );
      }
    } catch (e) {
      debugPrint('PurchaseManager Exception in _queryProducts: $e');
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status != PurchaseStatus.pending) {
        if (purchaseDetails.status == PurchaseStatus.error ||
            purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored ||
            purchaseDetails.status == PurchaseStatus.canceled) {
          isPurchasing.value = false;
        }

        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase Error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _unlockPremium();
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _unlockPremium() async {
    isPremium.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyPremium, true);
    AdManager.instance.disposeAll();
  }

  Future<void> buyPremium() async {
    if (isPurchasing.value) return;
    isPurchasing.value = true;

    try {
      if (!_isAvailable || _products.isEmpty) {
        await _queryProducts();
      }

      if (!_isAvailable) {
        throw Exception('In-app purchase is not available on this device.');
      }
      if (_products.isEmpty) {
        throw Exception(
          'Product details for "$productId" could not be loaded.',
        );
      }

      ProductDetails? product;
      for (final p in _products) {
        if (p.id == productId) {
          product = p;
          break;
        }
      }
      product ??= _products.first;

      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      isPurchasing.value = false;
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<bool> shouldShowSpecialOffer() async {
    if (isPremium.value) return false;
    final cachedJson = await PrefsHelper.getAppDataCache();
    if (cachedJson == null) return false;

    final appData = AppData.fromJson(json.decode(cachedJson));
    if (!appData.config.isSaleActive) return false;

    final alreadyShown = await PrefsHelper.isSpecialOfferShown();
    return !alreadyShown;
  }

  Future<void> markSpecialOfferAsShown() async {
    await PrefsHelper.markSpecialOfferShown();
  }

  void dispose() {
    _subscription.cancel();
  }
}
