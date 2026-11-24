import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../shared/models/subscription.dart';

/// 匯率表：1 單位外幣等於多少新台幣。
class ExchangeRates {
  const ExchangeRates({
    required this.twdPerUnit,
    required this.updatedAt,
    required this.isFallback,
  });

  final Map<String, double> twdPerUnit;
  final DateTime? updatedAt;

  /// true 表示目前用的是內建預設匯率（尚未成功取得線上匯率）。
  final bool isFallback;

  /// 網路取不到匯率時的預設值，只求數量級正確。
  static const fallback = ExchangeRates(
    twdPerUnit: {'TWD': 1, 'USD': 31.0, 'JPY': 0.21},
    updatedAt: null,
    isFallback: true,
  );

  double toTwd(double amount, String currency) {
    final rate =
        twdPerUnit[currency] ?? ExchangeRates.fallback.twdPerUnit[currency];
    return amount * (rate ?? 1);
  }

  Map<String, dynamic> toJson() => {
    'twdPerUnit': twdPerUnit,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  static ExchangeRates? fromJson(Map<String, dynamic> json) {
    final raw = json['twdPerUnit'];
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    if (raw is! Map || updatedAt == null) return null;
    final rates = <String, double>{};
    raw.forEach((k, v) {
      if (k is String && v is num && v > 0 && v.isFinite) {
        rates[k] = v.toDouble();
      }
    });
    if (!SubscriptionLimits.currencies.every(rates.containsKey)) return null;
    return ExchangeRates(
      twdPerUnit: rates,
      updatedAt: updatedAt,
      isFallback: false,
    );
  }
}

/// 取得並快取匯率。匯率每 12 小時最多更新一次；離線時沿用上次的快取。
class ExchangeRateService {
  ExchangeRateService._();
  static final ExchangeRateService instance = ExchangeRateService._();

  static const _cacheKey = 'exchange_rates_v1';
  static const _maxAge = Duration(hours: 12);

  final ValueNotifier<ExchangeRates> rates = ValueNotifier(
    ExchangeRates.fallback,
  );
  bool _refreshing = false;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final parsed = ExchangeRates.fromJson(
          json.decode(cached) as Map<String, dynamic>,
        );
        if (parsed != null) rates.value = parsed;
      }
    } catch (e) {
      debugPrint('讀取匯率快取失敗：$e');
    }
    final updatedAt = rates.value.updatedAt;
    if (updatedAt == null || DateTime.now().difference(updatedAt) > _maxAge) {
      unawaited(refresh());
    }
  }

  /// 從網路更新匯率。成功回傳 true。
  Future<bool> refresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final response = await http
          .get(Uri.parse(AppConfig.exchangeRateEndpoint))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;
      final body = json.decode(response.body) as Map<String, dynamic>;
      if (body['result'] != 'success') return false;
      final apiRates = body['rates'];
      if (apiRates is! Map) return false;

      // API 回傳的是「1 TWD = 多少外幣」，這裡轉成「1 外幣 = 多少 TWD」。
      final twdPerUnit = <String, double>{'TWD': 1};
      for (final code in SubscriptionLimits.currencies) {
        if (code == 'TWD') continue;
        final r = apiRates[code];
        if (r is! num || r <= 0 || !r.isFinite) return false;
        twdPerUnit[code] = 1 / r;
      }
      final fresh = ExchangeRates(
        twdPerUnit: twdPerUnit,
        updatedAt: DateTime.now(),
        isFallback: false,
      );
      rates.value = fresh;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(fresh.toJson()));
      return true;
    } catch (e) {
      debugPrint('更新匯率失敗：$e');
      return false;
    } finally {
      _refreshing = false;
    }
  }
}
