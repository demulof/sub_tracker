// 扣款日期與金額計算（與 Flutter 版 lib/shared/billing.dart 相同的規則）。
// 全部是純函式，測試在 pwa-tools/test/billing.test.mjs。
import { cycle, dateOnly } from './model.js';

/** 加上 months 個月；目標月份沒有那一天時用月底（1/31 + 1 個月 = 2/28）。 */
export function addMonthsClamped(date, months) {
  const total = date.getFullYear() * 12 + date.getMonth() + months;
  const year = Math.floor(total / 12);
  const month = total - year * 12;
  const lastDay = new Date(year, month + 1, 0).getDate();
  return new Date(year, month, Math.min(date.getDate(), lastDay));
}

const months = (sub) => cycle(sub.cycle).months;

/** 第 n 次扣款日（n 從 0 開始），每期都從首次扣款日起算，不會越算越偏。 */
export const paymentDateAt = (sub, n) => addMonthsClamped(sub.firstPaymentDate, n * months(sub));

/** 停止續訂日（含）之後不再扣款。 */
export const isEndedOn = (sub, day) => sub.endDate != null && dateOnly(day) >= sub.endDate;

function startIndex(sub, from) {
  const between = (from.getFullYear() - sub.firstPaymentDate.getFullYear()) * 12 +
    (from.getMonth() - sub.firstPaymentDate.getMonth());
  return Math.max(0, Math.trunc(between / months(sub)) - 1);
}

/** start（含）到 end（不含）之間的實際扣款日。 */
export function paymentDatesInRange(sub, start, end) {
  const from = dateOnly(start);
  const to = dateOnly(end);
  const result = [];
  if (!(sub.firstPaymentDate < to)) return result;
  for (let n = startIndex(sub, from); ; n++) {
    const date = paymentDateAt(sub, n);
    if (!(date < to) || isEndedOn(sub, date)) break;
    if (date >= from) result.push(date);
  }
  return result;
}

/** 今天（含）之後的下一次扣款日；已停止訂閱時回傳 null。 */
export function nextPaymentDate(sub, today) {
  const from = dateOnly(today);
  for (let n = startIndex(sub, from); ; n++) {
    const date = paymentDateAt(sub, n);
    if (isEndedOn(sub, date)) return null;
    if (date >= from) return date;
  }
}

export const monthStart = (d) => new Date(d.getFullYear(), d.getMonth(), 1);
export const nextMonthStart = (d) => new Date(d.getFullYear(), d.getMonth() + 1, 1);

/** 兩個日期相差幾天（只看日期）。 */
export const daysBetween = (from, to) =>
  Math.round((Date.UTC(to.getFullYear(), to.getMonth(), to.getDate()) -
    Date.UTC(from.getFullYear(), from.getMonth(), from.getDate())) / 86400000);

/** 期間內所有訂閱的實際扣款總額（新台幣）。toTwd(amount, currency) 負責換算。 */
export function spendingInRange(subs, start, end, toTwd) {
  let total = 0;
  for (const sub of subs) {
    const count = paymentDatesInRange(sub, start, end).length;
    if (count > 0) total += toTwd(sub.amount, sub.currency) * count;
  }
  return total;
}

/** 該月份是否在訂閱期間內。 */
export function isActiveInMonth(sub, month) {
  const start = monthStart(month);
  const end = nextMonthStart(month);
  if (!(sub.firstPaymentDate < end)) return false;
  return sub.endDate == null || sub.endDate > start;
}

/** 每月平均成本（新台幣），例如年繳 1,200 元 = 每月 100 元。 */
export const monthlyCost = (sub, toTwd) => toTwd(sub.amount, sub.currency) / months(sub);

/** 該月份訂閱中的項目，依分類加總每月平均成本。 */
export function monthlyCostByCategory(subs, month, toTwd) {
  const result = {};
  for (const sub of subs) {
    if (!isActiveInMonth(sub, month)) continue;
    result[sub.category] = (result[sub.category] ?? 0) + monthlyCost(sub, toTwd);
  }
  return result;
}

/** 從首次扣款到 end（不含）為止的累計扣款（新台幣）。 */
export const lifetimeSpending = (sub, end, toTwd) =>
  toTwd(sub.amount, sub.currency) * paymentDatesInRange(sub, sub.firstPaymentDate, end).length;
