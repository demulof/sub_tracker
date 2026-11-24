/// 上架前需要確認或填寫的設定都集中在這裡。
class AppConfig {
  static const String appName = '訂閱管家';

  /// 隱私權政策網址（Google Play 與 App Store 上架都必須提供）。
  /// TODO(上架前): 填入已公開的隱私權政策網址，例如 GitHub Pages 頁面。
  static const String privacyPolicyUrl = '';

  /// 匯率來源：ExchangeRate-API 免費開放端點，以 TWD 為基準。
  /// 使用條款要求在 app 內標示資料來源（統計頁與帳號頁已標示）。
  static const String exchangeRateEndpoint =
      'https://open.er-api.com/v6/latest/TWD';
  static const String exchangeRateAttribution =
      'Rates By Exchange Rate API (exchangerate-api.com)';
}
