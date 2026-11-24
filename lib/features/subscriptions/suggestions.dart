// 常用服務的快速新增資料。
// 價格只是方便填寫的參考值，各服務會調價，畫面上已提醒使用者以實際帳單為準。
import 'package:flutter/material.dart';

import '../../shared/models/subscription.dart';

// --- Data models for suggestions ---
class Plan {
  final String name;
  final Map<String, double> prices;
  Plan({required this.name, required this.prices});
}

class SubscriptionSuggestion {
  final String name;
  final String nativeCurrency;
  final Color brandColor;
  final List<Plan> plans;
  final SubscriptionCategory category;
  SubscriptionSuggestion({
    required this.name,
    required this.nativeCurrency,
    required this.brandColor,
    required this.plans,
    required this.category,
  });
}

// --- Data list for suggestions ---
final List<SubscriptionSuggestion> popularSuggestions = [
  SubscriptionSuggestion(
    name: 'Netflix',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFFE50914),
    category: SubscriptionCategory.video,
    plans: [
      Plan(name: '基本', prices: {'TWD': 270, 'USD': 6.99}),
      Plan(name: '標準', prices: {'TWD': 330, 'USD': 10.99}),
      Plan(name: '高級', prices: {'TWD': 390, 'USD': 15.99}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Disney+',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFF113CCF),
    category: SubscriptionCategory.video,
    plans: [
      Plan(name: '標準方案', prices: {'TWD': 270}),
      Plan(name: '高級方案', prices: {'TWD': 320}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'YouTube',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFFFF0000),
    category: SubscriptionCategory.video,
    plans: [
      Plan(name: 'Premium 個人', prices: {'TWD': 199, 'USD': 7.99}),
      Plan(name: 'Premium 家庭', prices: {'TWD': 399, 'USD': 14.99}),
    ],
  ),
  SubscriptionSuggestion(
    name: '動畫瘋',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFF00A2E8),
    category: SubscriptionCategory.video,
    plans: [
      Plan(name: '月費方案', prices: {'TWD': 99}),
      Plan(name: '年費方案', prices: {'TWD': 990}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Spotify',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFF1DB954),
    category: SubscriptionCategory.music,
    plans: [
      Plan(name: 'Individual', prices: {'TWD': 149, 'USD': 5.99}),
      Plan(name: 'Duo', prices: {'TWD': 198, 'USD': 7.99}),
      Plan(name: 'Family', prices: {'TWD': 268, 'USD': 9.99}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'KKBOX',
    nativeCurrency: 'TWD',
    brandColor: Colors.cyan[600]!,
    category: SubscriptionCategory.music,
    plans: [
      Plan(name: '標準音質', prices: {'TWD': 149}),
      Plan(name: '無損音質', prices: {'TWD': 299}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Apple Music',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFFFC3C44),
    category: SubscriptionCategory.music,
    plans: [
      Plan(name: '個人方案', prices: {'TWD': 165, 'USD': 10.99}),
      Plan(name: '家庭方案', prices: {'TWD': 265, 'USD': 16.99}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'ChatGPT',
    nativeCurrency: 'USD',
    brandColor: const Color(0xFF74AA9C),
    category: SubscriptionCategory.ai,
    plans: [
      Plan(name: 'Plus', prices: {'USD': 20}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Gemini',
    nativeCurrency: 'USD',
    brandColor: const Color(0xFF8E44AD),
    category: SubscriptionCategory.ai,
    plans: [
      Plan(name: 'Advanced', prices: {'USD': 19.99}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Claude',
    nativeCurrency: 'USD',
    brandColor: const Color(0xFFD97757),
    category: SubscriptionCategory.ai,
    plans: [
      Plan(name: 'Pro', prices: {'USD': 20}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Microsoft 365',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFF0078D4),
    category: SubscriptionCategory.productivity,
    plans: [
      Plan(name: '個人版', prices: {'TWD': 219, 'USD': 6.99}),
      Plan(name: '家用版', prices: {'TWD': 320, 'USD': 9.99}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Google One',
    nativeCurrency: 'TWD',
    brandColor: Colors.blue[700]!,
    category: SubscriptionCategory.productivity,
    plans: [
      Plan(name: '100 GB', prices: {'TWD': 65}),
      Plan(name: '200 GB', prices: {'TWD': 90}),
      Plan(name: '2 TB', prices: {'TWD': 330}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'iCloud+',
    nativeCurrency: 'TWD',
    brandColor: Colors.indigo[300]!,
    category: SubscriptionCategory.productivity,
    plans: [
      Plan(name: '50 GB', prices: {'TWD': 30}),
      Plan(name: '200 GB', prices: {'TWD': 90}),
      Plan(name: '2 TB', prices: {'TWD': 300}),
    ],
  ),
];
