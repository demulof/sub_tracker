// 資料模型。欄位與 Flutter 版（lib/shared/models/subscription.dart）、Firestore 安全規則完全相同，
// 兩個版本可以共用同一個 Firebase 專案的資料。

/** 訊息可以直接顯示給使用者看的錯誤。 */
export class UserError extends Error {}

export const CATEGORIES = [
  { id: 'video', name: '影視', color: 0xff3b82f6 },
  { id: 'music', name: '音樂', color: 0xfff59e0b },
  { id: 'ai', name: 'AI 工具', color: 0xff6366f1 },
  { id: 'productivity', name: '生產力', color: 0xff10b981 },
  { id: 'other', name: '其他', color: 0xff9ca3af },
];

export const CYCLES = [
  { id: 'monthly', name: '每月', short: '/ 月', months: 1 },
  { id: 'quarterly', name: '每季', short: '/ 季', months: 3 },
  { id: 'yearly', name: '每年', short: '/ 年', months: 12 },
];

/** 輸入限制，與 firestore.rules 相同，修改時兩邊要一起改。 */
export const LIMITS = {
  maxNameLength: 50,
  maxPlanLength: 50,
  maxAmount: 10000000,
  currencies: ['TWD', 'USD', 'JPY'],
};

export const category = (id) => CATEGORIES.find((c) => c.id === id) ?? CATEGORIES[4];
export const cycle = (id) => CYCLES.find((c) => c.id === id) ?? CYCLES[0];

/** ARGB 整數 → CSS 顏色。 */
export const cssColor = (argb) => '#' + ((argb >>> 0) & 0xffffff).toString(16).padStart(6, '0');

export const dateOnly = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());

/** 本機日期轉成 YYYY-MM-DD（input[type=date] 用）。 */
export function toDateInput(d) {
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** YYYY-MM-DD 或 ISO 字串 → 本機日期（不含時間）。 */
export function parseDate(value) {
  if (value == null) return null;
  if (value instanceof Date) return dateOnly(value);
  if (typeof value.toDate === 'function') return dateOnly(value.toDate()); // Firestore Timestamp
  if (typeof value === 'string') {
    const m = value.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (m) return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  }
  return null;
}

/**
 * 把任何來源的資料（Firestore、本機、備份檔）整理成標準格式。
 * 必要欄位不完整時丟出錯誤。
 */
export function normalize(raw) {
  const first = parseDate(raw?.firstPaymentDate);
  if (!raw || typeof raw.id !== 'string' || !raw.id || typeof raw.name !== 'string' ||
      typeof raw.amount !== 'number' || !Number.isFinite(raw.amount) || !first) {
    throw new Error('訂閱資料欄位不完整');
  }
  return {
    id: raw.id,
    name: raw.name,
    plan: typeof raw.plan === 'string' ? raw.plan : '自訂方案',
    amount: raw.amount,
    currency: LIMITS.currencies.includes(raw.currency) ? raw.currency : 'TWD',
    cycle: cycle(raw.cycle).id,
    firstPaymentDate: first,
    endDate: parseDate(raw.endDate),
    brandColor: Number.isInteger(raw.brandColor) ? raw.brandColor >>> 0 : 0xff9e9e9e,
    category: category(raw.category).id,
  };
}

/** 本機儲存與備份檔用的格式（日期轉字串）。 */
export function toJSON(sub) {
  return {
    ...sub,
    firstPaymentDate: toDateInput(sub.firstPaymentDate),
    endDate: sub.endDate ? toDateInput(sub.endDate) : null,
  };
}

/** 檢查使用者輸入，回傳錯誤訊息，沒問題時回傳 null。 */
export function validate(sub) {
  const name = sub.name.trim();
  if (!name) return '請輸入服務名稱';
  if (name.length > LIMITS.maxNameLength) return `服務名稱最多 ${LIMITS.maxNameLength} 個字`;
  if (sub.plan.length > LIMITS.maxPlanLength) return `方案名稱最多 ${LIMITS.maxPlanLength} 個字`;
  if (!Number.isFinite(sub.amount) || sub.amount <= 0) return '金額必須大於 0';
  if (sub.amount > LIMITS.maxAmount) return '金額過大';
  if (!sub.firstPaymentDate) return '請選擇首次付款日';
  if (sub.endDate && sub.endDate <= sub.firstPaymentDate) return '停止續訂日必須晚於首次付款日';
  return null;
}

export function newId() {
  return crypto.randomUUID ? crypto.randomUUID()
    : 'id-' + Date.now().toString(36) + Math.random().toString(36).slice(2);
}
