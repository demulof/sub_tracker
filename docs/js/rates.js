// 匯率：1 單位外幣 = 多少新台幣。每 12 小時最多更新一次，離線時沿用快取或預設值。
import { RATE_ENDPOINT } from './config.js';
import { LIMITS } from './model.js';

const CACHE_KEY = 'sub_tracker_rates_v1';
const MAX_AGE = 12 * 60 * 60 * 1000;

export const FALLBACK = Object.freeze({
  twdPerUnit: { TWD: 1, USD: 31.0, JPY: 0.21 },
  updatedAt: null,
  isFallback: true,
});

let current = loadCache() ?? FALLBACK;
const listeners = new Set();

function loadCache() {
  try {
    const raw = JSON.parse(localStorage.getItem(CACHE_KEY) ?? 'null');
    if (!raw || !raw.updatedAt || !raw.twdPerUnit) return null;
    const ok = LIMITS.currencies.every((c) => typeof raw.twdPerUnit[c] === 'number' && raw.twdPerUnit[c] > 0);
    return ok ? { twdPerUnit: raw.twdPerUnit, updatedAt: raw.updatedAt, isFallback: false } : null;
  } catch {
    return null;
  }
}

export const getRates = () => current;
export const onRatesChange = (fn) => { listeners.add(fn); return () => listeners.delete(fn); };

/** 換算成新台幣。 */
export const toTwd = (amount, currency) =>
  amount * (current.twdPerUnit[currency] ?? FALLBACK.twdPerUnit[currency] ?? 1);

let refreshing = null;

/** 從網路更新匯率，成功回傳 true。 */
export function refreshRates() {
  if (refreshing) return refreshing;
  refreshing = (async () => {
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 10000);
      const res = await fetch(RATE_ENDPOINT, { signal: controller.signal, cache: 'no-store' });
      clearTimeout(timer);
      if (!res.ok) return false;
      const body = await res.json();
      if (body.result !== 'success' || typeof body.rates !== 'object') return false;
      // API 給的是「1 TWD = 多少外幣」，轉成「1 外幣 = 多少 TWD」。
      const twdPerUnit = { TWD: 1 };
      for (const code of LIMITS.currencies) {
        if (code === 'TWD') continue;
        const r = body.rates[code];
        if (typeof r !== 'number' || !(r > 0) || !Number.isFinite(r)) return false;
        twdPerUnit[code] = 1 / r;
      }
      current = { twdPerUnit, updatedAt: Date.now(), isFallback: false };
      try { localStorage.setItem(CACHE_KEY, JSON.stringify(current)); } catch { /* 空間不足時忽略 */ }
      listeners.forEach((fn) => fn(current));
      return true;
    } catch (e) {
      console.warn('更新匯率失敗', e);
      return false;
    } finally {
      refreshing = null;
    }
  })();
  return refreshing;
}

export function initRates() {
  if (!current.updatedAt || Date.now() - current.updatedAt > MAX_AGE) refreshRates();
}
