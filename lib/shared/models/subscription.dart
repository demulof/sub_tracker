// =================================================================
// 檔案: lib/shared/models/subscription.dart
// (此檔案已更新，加入了 toJson/fromJson 方法以便儲存)
// =================================================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- [修改] 將 SubscriptionCategory 移至此檔案，方便共用 ---
enum SubscriptionCategory {
  video('影視'),
  music('音樂'),
  ai('AI 工具'),
  productivity('生產力'),
  other('其他'); // 新增一個預設分類

  const SubscriptionCategory(this.displayName);
  final String displayName;
}

enum BillingCycle { monthly, quarterly, yearly }

class Subscription {
  final String id;
  final String name;
  final String plan;
  final double amount;
  final String currency;
  final BillingCycle cycle;
  final DateTime firstPaymentDate;
  final Color brandColor;
  final SubscriptionCategory category;

  Subscription({
    required this.id,
    required this.name,
    this.plan = '標準方案',
    required this.amount,
    required this.currency,
    required this.cycle,
    required this.firstPaymentDate,
    required this.brandColor,
    required this.category,
  });

  // --- [新增] toJson: 將物件轉換為 Map 以便存入 Firestore ---
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'plan': plan,
      'amount': amount,
      'currency': currency,
      'cycle': cycle.name, // 將 enum 轉為字串
      'firstPaymentDate': Timestamp.fromDate(firstPaymentDate),
      'brandColor': brandColor.value, // 將 Color 轉為 int
      'category': category.name, // 將 enum 轉為字串
    };
  }

  // --- [新增] fromJson: 從 Map 建立物件 ---
  factory Subscription.fromJson(Map<String, dynamic> json) {
    // 為了兼容舊的 shared_preferences 格式 (string) 和新的 firestore 格式 (Timestamp)
    DateTime parsedDate;
    if (json['firstPaymentDate'] is Timestamp) {
      parsedDate = (json['firstPaymentDate'] as Timestamp).toDate();
    } else {
      parsedDate = DateTime.parse(json['firstPaymentDate'] as String);
    }

    return Subscription(
      id: json['id'],
      name: json['name'],
      plan: json['plan'],
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'],
      cycle: BillingCycle.values.firstWhere((e) => e.name == json['cycle']),
      firstPaymentDate: parsedDate,
      brandColor: Color(json['brandColor']),
      category: SubscriptionCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => SubscriptionCategory.other,
      ),
    );
  }
}
