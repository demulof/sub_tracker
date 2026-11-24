import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 訂閱分類。`color` 固定對應每個分類，統計圖表不會因資料順序而換色。
enum SubscriptionCategory {
  video('影視', Color(0xFF3B82F6)),
  music('音樂', Color(0xFFF59E0B)),
  ai('AI 工具', Color(0xFF6366F1)),
  productivity('生產力', Color(0xFF10B981)),
  other('其他', Color(0xFF9CA3AF));

  const SubscriptionCategory(this.displayName, this.color);
  final String displayName;
  final Color color;

  static SubscriptionCategory fromName(String? name) =>
      SubscriptionCategory.values.firstWhere(
        (e) => e.name == name,
        orElse: () => SubscriptionCategory.other,
      );
}

enum BillingCycle {
  monthly('每月', '/ 月', 1),
  quarterly('每季', '/ 季', 3),
  yearly('每年', '/ 年', 12);

  const BillingCycle(this.displayName, this.shortLabel, this.months);
  final String displayName;
  final String shortLabel;

  /// 每個週期相隔幾個月。
  final int months;

  static BillingCycle fromName(String? name) => BillingCycle.values.firstWhere(
    (e) => e.name == name,
    orElse: () => BillingCycle.monthly,
  );
}

/// 輸入限制。Firestore 安全規則（firestore.rules）使用相同的數值，修改時兩邊要一起改。
class SubscriptionLimits {
  static const int maxNameLength = 50;
  static const int maxPlanLength = 50;
  static const double maxAmount = 10000000;
  static const List<String> currencies = ['TWD', 'USD', 'JPY'];
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class Subscription {
  final String id;
  final String name;
  final String plan;
  final double amount;
  final String currency;
  final BillingCycle cycle;

  /// 第一次扣款日（只取日期，不含時間）。
  final DateTime firstPaymentDate;

  /// 停止續訂日。此日（含）之後不再扣款；null 表示仍在訂閱中。
  final DateTime? endDate;
  final Color brandColor;
  final SubscriptionCategory category;

  Subscription({
    required this.id,
    required this.name,
    this.plan = '自訂方案',
    required this.amount,
    required this.currency,
    required this.cycle,
    required DateTime firstPaymentDate,
    DateTime? endDate,
    required this.brandColor,
    required this.category,
  }) : firstPaymentDate = dateOnly(firstPaymentDate),
       endDate = endDate == null ? null : dateOnly(endDate);

  bool isEndedOn(DateTime day) =>
      endDate != null && !dateOnly(day).isBefore(endDate!);

  Subscription copyWith({
    String? id,
    String? name,
    String? plan,
    double? amount,
    String? currency,
    BillingCycle? cycle,
    DateTime? firstPaymentDate,
    DateTime? endDate,
    bool clearEndDate = false,
    Color? brandColor,
    SubscriptionCategory? category,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      plan: plan ?? this.plan,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      cycle: cycle ?? this.cycle,
      firstPaymentDate: firstPaymentDate ?? this.firstPaymentDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      brandColor: brandColor ?? this.brandColor,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> _baseMap() => {
    'id': id,
    'name': name,
    'plan': plan,
    'amount': amount,
    'currency': currency,
    'cycle': cycle.name,
    'brandColor': brandColor.toARGB32(),
    'category': category.name,
  };

  /// 存入 Firestore 用（日期轉 Timestamp）。
  Map<String, dynamic> toFirestore() => {
    ..._baseMap(),
    'firstPaymentDate': Timestamp.fromDate(firstPaymentDate),
    'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
  };

  /// 存在本機（shared_preferences）用，日期轉 ISO 8601 字串。
  Map<String, dynamic> toLocalJson() => {
    ..._baseMap(),
    'firstPaymentDate': firstPaymentDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
  };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// 同時支援 Firestore 與本機兩種格式。資料不完整時丟出 [FormatException]。
  factory Subscription.fromMap(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final amount = json['amount'];
    final firstPaymentDate = _parseDate(json['firstPaymentDate']);
    if (id is! String ||
        name is! String ||
        amount is! num ||
        firstPaymentDate == null) {
      throw const FormatException('訂閱資料欄位不完整');
    }
    final currency = json['currency'];
    final brandColor = json['brandColor'];
    return Subscription(
      id: id,
      name: name,
      plan: json['plan'] is String ? json['plan'] as String : '自訂方案',
      amount: amount.toDouble(),
      currency:
          currency is String && SubscriptionLimits.currencies.contains(currency)
          ? currency
          : 'TWD',
      cycle: BillingCycle.fromName(json['cycle']?.toString()),
      firstPaymentDate: firstPaymentDate,
      endDate: _parseDate(json['endDate']),
      brandColor: brandColor is int ? Color(brandColor) : Colors.grey,
      category: SubscriptionCategory.fromName(json['category']?.toString()),
    );
  }
}
