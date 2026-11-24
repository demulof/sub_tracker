// 扣款日期與金額計算。全部是純函式，方便單元測試（見 test/billing_test.dart）。
import 'dart:math' as math;

import 'models/subscription.dart';

/// 把金額換算成新台幣的函式，由 ExchangeRates.toTwd 提供。
typedef ToTwd = double Function(double amount, String currency);

/// 加上 [months] 個月。目標月份沒有那一天時，改用該月最後一天，
/// 例如 1/31 加一個月是 2/28（或 2/29），不會跑到 3/3。
DateTime addMonthsClamped(DateTime date, int months) {
  final totalMonths = date.year * 12 + (date.month - 1) + months;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(date.day, lastDay));
}

/// 第 [n] 次扣款日（n 從 0 開始）。每次都從首次扣款日起算，日期不會越來越偏。
DateTime paymentDateAt(Subscription sub, int n) =>
    addMonthsClamped(sub.firstPaymentDate, n * sub.cycle.months);

/// [start]（含）到 [end]（不含）之間的實際扣款日。停止續訂日（含）之後的扣款不計。
List<DateTime> paymentDatesInRange(
  Subscription sub,
  DateTime start,
  DateTime end,
) {
  final from = dateOnly(start);
  final to = dateOnly(end);
  final result = <DateTime>[];
  if (!sub.firstPaymentDate.isBefore(to)) return result;

  // 從接近 start 的那一期開始找，避免長年訂閱每次都從第 0 期跑起。
  final monthsBetween =
      (from.year - sub.firstPaymentDate.year) * 12 +
      (from.month - sub.firstPaymentDate.month);
  var n = math.max(0, monthsBetween ~/ sub.cycle.months - 1);

  while (true) {
    final date = paymentDateAt(sub, n);
    if (!date.isBefore(to) || sub.isEndedOn(date)) break;
    if (!date.isBefore(from)) result.add(date);
    n++;
  }
  return result;
}

/// 今天（含）之後的下一次扣款日；已停止訂閱且沒有下一期時回傳 null。
DateTime? nextPaymentDate(Subscription sub, DateTime today) {
  final from = dateOnly(today);
  final monthsBetween =
      (from.year - sub.firstPaymentDate.year) * 12 +
      (from.month - sub.firstPaymentDate.month);
  var n = math.max(0, monthsBetween ~/ sub.cycle.months - 1);
  while (true) {
    final date = paymentDateAt(sub, n);
    if (sub.isEndedOn(date)) return null;
    if (!date.isBefore(from)) return date;
    n++;
  }
}

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);
DateTime nextMonthStart(DateTime d) => DateTime(d.year, d.month + 1);

/// 這段期間內所有訂閱的實際扣款總額（新台幣）。
double spendingInRange(
  Iterable<Subscription> subs,
  DateTime start,
  DateTime end,
  ToTwd toTwd,
) {
  var total = 0.0;
  for (final sub in subs) {
    final count = paymentDatesInRange(sub, start, end).length;
    if (count > 0) total += toTwd(sub.amount, sub.currency) * count;
  }
  return total;
}

/// 該月份是否在訂閱期間內（已開始且尚未停止）。
bool isActiveInMonth(Subscription sub, DateTime month) {
  final start = monthStart(month);
  final end = nextMonthStart(month);
  if (!sub.firstPaymentDate.isBefore(end)) return false;
  return sub.endDate == null || sub.endDate!.isAfter(start);
}

/// 換算成每月平均成本（新台幣），例如年繳 1200 元 = 每月 100 元。
double monthlyCost(Subscription sub, ToTwd toTwd) =>
    toTwd(sub.amount, sub.currency) / sub.cycle.months;

/// 該月份在訂閱期間內的項目，依分類加總每月平均成本。
Map<SubscriptionCategory, double> monthlyCostByCategory(
  Iterable<Subscription> subs,
  DateTime month,
  ToTwd toTwd,
) {
  final result = <SubscriptionCategory, double>{};
  for (final sub in subs.where((s) => isActiveInMonth(s, month))) {
    result.update(
      sub.category,
      (v) => v + monthlyCost(sub, toTwd),
      ifAbsent: () => monthlyCost(sub, toTwd),
    );
  }
  return result;
}

/// 從首次扣款到 [end]（不含）為止的累計扣款（新台幣）。
double lifetimeSpending(Subscription sub, DateTime end, ToTwd toTwd) {
  final count = paymentDatesInRange(sub, sub.firstPaymentDate, end).length;
  return toTwd(sub.amount, sub.currency) * count;
}
