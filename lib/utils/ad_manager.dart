import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/local_app_config.dart';
import 'purchase_manager.dart';

class PreloadedAd {
  final BannerAd ad;
  final ValueNotifier<bool> isLoaded = ValueNotifier(false);

  PreloadedAd(this.ad);

  void dispose() {
    ad.dispose();
    isLoaded.dispose();
  }
}

class AdManager {
  static final AdManager instance = AdManager._internal();
  AdManager._internal();

  final Map<String, PreloadedAd> _ads = {};

  final String _testBannerAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';
  final String _testInterstitialAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';

  String get adUnitId => kDebugMode
      ? _testBannerAdUnitId
      : (Platform.isIOS
            ? LocalAppConfig.iosBannerAdUnitId
            : LocalAppConfig.androidBannerAdUnitId);

  String get interstitialAdUnitId => kDebugMode
      ? _testInterstitialAdUnitId
      : (Platform.isIOS
            ? LocalAppConfig.iosInterstitialAdUnitId
            : LocalAppConfig.androidInterstitialAdUnitId);

  void preloadAd(String key) {
    if (PurchaseManager.instance.isPremium.value) return;
    if (_ads.containsKey(key)) return;

    final ad = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('AdManager: Ad $key loaded.');
          _ads[key]?.isLoaded.value = true;
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('AdManager: Ad $key failed to load: $err');
          ad.dispose();
          _ads.remove(key);
        },
      ),
    );

    final preloadedAd = PreloadedAd(ad);
    _ads[key] = preloadedAd;
    ad.load();
  }

  PreloadedAd? getAd(String key) => _ads[key];

  PreloadedAd? consumeAd(String key, {bool keep = false}) {
    if (keep) return _ads[key];
    return _ads.remove(key);
  }

  InterstitialAd? _interstitialAd;

  void preloadInterstitial() {
    if (PurchaseManager.instance.isPremium.value) return;
    if (_interstitialAd != null) return;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdManager: Interstitial loaded.');
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (err) {
          debugPrint('AdManager: Interstitial failed to load: $err');
          _interstitialAd = null;
        },
      ),
    );
  }

  void showInterstitial({required VoidCallback onComplete}) {
    if (PurchaseManager.instance.isPremium.value || _interstitialAd == null) {
      onComplete();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        onComplete();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('AdManager: Interstitial failed to show: $err');
        ad.dispose();
        _interstitialAd = null;
        onComplete();
      },
    );

    _interstitialAd!.show();
  }

  void setAdUnitIds({
    required String bannerId,
    required String interstitialId,
  }) {}

  void disposeAll() {
    for (final ad in _ads.values) {
      ad.dispose();
    }
    _ads.clear();
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
