import 'package:flutter/material.dart';

enum BillingCycle { monthly, quarterly, yearly }

class Subscription {
  final String id; // 新增 ID
  final String name;
  final String plan;
  final double amount;
  final String currency;
  final BillingCycle cycle;
  final DateTime nextPaymentDate;
  final Color brandColor;

  Subscription({
    required this.id,
    required this.name,
    this.plan = '標準方案', // 提供預設值
    required this.amount,
    required this.currency,
    required this.cycle,
    required this.nextPaymentDate,
    required this.brandColor,
  });
}
