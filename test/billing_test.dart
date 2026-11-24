import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/shared/billing.dart';
import 'package:sub_tracker/shared/models/subscription.dart';

Subscription sub({
  required DateTime first,
  BillingCycle cycle = BillingCycle.monthly,
  DateTime? end,
  double amount = 100,
  String currency = 'TWD',
  SubscriptionCategory category = SubscriptionCategory.video,
}) => Subscription(
  id: 'x',
  name: 'Test',
  amount: amount,
  currency: currency,
  cycle: cycle,
  firstPaymentDate: first,
  endDate: end,
  brandColor: Colors.blue,
  category: category,
);

double twd(double amount, String currency) =>
    currency == 'USD' ? amount * 30 : amount;

void main() {
  group('addMonthsClamped', () {
    test('月底日期不會往後跑', () {
      expect(addMonthsClamped(DateTime(2025, 1, 31), 1), DateTime(2025, 2, 28));
      expect(addMonthsClamped(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
      expect(addMonthsClamped(DateTime(2025, 1, 31), 2), DateTime(2025, 3, 31));
      expect(addMonthsClamped(DateTime(2025, 11, 30), 3), DateTime(2026, 2, 28));
    });
  });

  group('paymentDatesInRange', () {
    test('每月 31 號扣款，每期都從首次扣款日起算', () {
      final s = sub(first: DateTime(2025, 1, 31));
      final dates = paymentDatesInRange(s, DateTime(2025, 1), DateTime(2025, 5));
      expect(dates, [
        DateTime(2025, 1, 31),
        DateTime(2025, 2, 28),
        DateTime(2025, 3, 31),
        DateTime(2025, 4, 30),
      ]);
    });

    test('停止續訂日（含）之後不再扣款', () {
      final s = sub(first: DateTime(2025, 1, 10), end: DateTime(2025, 3, 10));
      final dates = paymentDatesInRange(s, DateTime(2025), DateTime(2026));
      expect(dates, [DateTime(2025, 1, 10), DateTime(2025, 2, 10)]);
    });

    test('年繳只在扣款月份計入', () {
      final s = sub(first: DateTime(2023, 6, 1), cycle: BillingCycle.yearly);
      expect(
        paymentDatesInRange(s, DateTime(2025, 6), DateTime(2025, 7)).length,
        1,
      );
      expect(paymentDatesInRange(s, DateTime(2025, 7), DateTime(2025, 8)), isEmpty);
    });

    test('首次扣款日在區間之後時沒有扣款', () {
      final s = sub(first: DateTime(2026, 1, 1));
      expect(paymentDatesInRange(s, DateTime(2025), DateTime(2026)), isEmpty);
    });
  });

  group('nextPaymentDate', () {
    test('今天就是扣款日時回傳今天', () {
      final s = sub(first: DateTime(2025, 1, 15));
      expect(nextPaymentDate(s, DateTime(2025, 3, 15)), DateTime(2025, 3, 15));
    });

    test('已停止訂閱時回傳 null', () {
      final s = sub(first: DateTime(2025, 1, 15), end: DateTime(2025, 3, 1));
      expect(nextPaymentDate(s, DateTime(2025, 3, 2)), isNull);
    });

    test('季繳', () {
      final s = sub(first: DateTime(2025, 1, 15), cycle: BillingCycle.quarterly);
      expect(nextPaymentDate(s, DateTime(2025, 2, 1)), DateTime(2025, 4, 15));
    });
  });

  group('金額計算', () {
    test('外幣會換算成新台幣', () {
      final subs = [
        sub(first: DateTime(2025, 1, 5), amount: 20, currency: 'USD'),
        sub(first: DateTime(2025, 1, 5), amount: 100),
      ];
      expect(
        spendingInRange(subs, DateTime(2025, 2), DateTime(2025, 3), twd),
        700,
      );
    });

    test('每月平均成本與分類', () {
      final subs = [
        sub(first: DateTime(2025, 1, 1), amount: 1200, cycle: BillingCycle.yearly),
        sub(
          first: DateTime(2025, 1, 1),
          amount: 150,
          category: SubscriptionCategory.music,
        ),
        sub(
          first: DateTime(2025, 1, 1),
          amount: 999,
          end: DateTime(2025, 2, 1),
          category: SubscriptionCategory.ai,
        ),
      ];
      final result = monthlyCostByCategory(subs, DateTime(2025, 3), twd);
      expect(result[SubscriptionCategory.video], 100);
      expect(result[SubscriptionCategory.music], 150);
      expect(result.containsKey(SubscriptionCategory.ai), isFalse);
    });

    test('累計支出', () {
      final s = sub(first: DateTime(2025, 1, 31));
      expect(lifetimeSpending(s, DateTime(2025, 4), twd), 300);
    });
  });

  group('Subscription 資料格式', () {
    test('本機 JSON 可以完整還原', () {
      final s = sub(first: DateTime(2025, 1, 31), end: DateTime(2025, 6, 1));
      final restored = Subscription.fromMap(s.toLocalJson());
      expect(restored.firstPaymentDate, s.firstPaymentDate);
      expect(restored.endDate, s.endDate);
      expect(restored.brandColor.toARGB32(), s.brandColor.toARGB32());
    });

    test('相容舊版本機資料（沒有 endDate 欄位）', () {
      final restored = Subscription.fromMap({
        'id': 'a',
        'name': 'Netflix',
        'plan': '標準',
        'amount': 330,
        'currency': 'TWD',
        'cycle': 'monthly',
        'firstPaymentDate': '2025-01-31T10:20:00.000',
        'brandColor': 0xFFE50914,
        'category': 'video',
      });
      expect(restored.endDate, isNull);
      expect(restored.firstPaymentDate, DateTime(2025, 1, 31));
    });

    test('欄位不完整時丟出 FormatException', () {
      expect(() => Subscription.fromMap({'id': 'a'}), throwsFormatException);
    });
  });
}
