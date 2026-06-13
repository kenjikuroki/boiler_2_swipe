class LocalAppConfig {
  static const String appId = 'boiler_2';
  static const String storagePrefix = 'boiler2';
  static const String appTitle = '2級ボイラー技士対策';

  static const Map<String, String> categoryTitles = {
    'part1': '1. ボイラーの構造',
    'part2': '2. ボイラーの取扱い',
    'part3': '3. 燃料および燃焼',
    'part4': '4. 関係法令',
  };

  static const String androidBannerAdUnitId = 'ca-app-pub-3331079517737737/8853800306';
  static const String iosBannerAdUnitId = androidBannerAdUnitId;
  static const String androidInterstitialAdUnitId = 'ca-app-pub-3331079517737737/3779413507';
  static const String iosInterstitialAdUnitId = androidInterstitialAdUnitId;

  static const String androidPremiumProductId = 'unlock_b';
  static const String iosPremiumProductId = 'unlock_b';

  static const int regularPrice = 390;
  static const int salePrice = 190;
  static const bool nextAppEnabled = false;
  static const String nextAppText = '';
  static const String nextAppUrl = '';
}
