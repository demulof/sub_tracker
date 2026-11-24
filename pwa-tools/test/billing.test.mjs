// 執行：cd pwa-tools && npm test
import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import {
  addMonthsClamped, paymentDatesInRange, nextPaymentDate, spendingInRange,
  monthlyCostByCategory, lifetimeSpending, daysBetween,
} from '../../docs/js/billing.js';
import { normalize, toJSON, validate } from '../../docs/js/model.js';
import { rrule, buildIcs } from '../../docs/js/ics.js';

const D = (y, m, d = 1) => new Date(y, m - 1, d);
const sub = ({ first, cycle = 'monthly', end = null, amount = 100, currency = 'TWD', category = 'video' }) => ({
  id: 'x', name: 'Test', plan: '方案', amount, currency, cycle,
  firstPaymentDate: first, endDate: end, brandColor: 0xff3b82f6, category,
});
const twd = (amount, currency) => (currency === 'USD' ? amount * 30 : amount);

describe('addMonthsClamped', () => {
  test('月底日期不會往後跑', () => {
    assert.deepEqual(addMonthsClamped(D(2025, 1, 31), 1), D(2025, 2, 28));
    assert.deepEqual(addMonthsClamped(D(2024, 1, 31), 1), D(2024, 2, 29));
    assert.deepEqual(addMonthsClamped(D(2025, 1, 31), 2), D(2025, 3, 31));
    assert.deepEqual(addMonthsClamped(D(2025, 11, 30), 3), D(2026, 2, 28));
  });
});

describe('paymentDatesInRange', () => {
  test('每月 31 號扣款，每期都從首次扣款日起算', () => {
    assert.deepEqual(paymentDatesInRange(sub({ first: D(2025, 1, 31) }), D(2025, 1), D(2025, 5)),
      [D(2025, 1, 31), D(2025, 2, 28), D(2025, 3, 31), D(2025, 4, 30)]);
  });
  test('停止續訂日（含）之後不再扣款', () => {
    assert.deepEqual(
      paymentDatesInRange(sub({ first: D(2025, 1, 10), end: D(2025, 3, 10) }), D(2025, 1), D(2026, 1)),
      [D(2025, 1, 10), D(2025, 2, 10)]);
  });
  test('年繳只在扣款月份計入', () => {
    const s = sub({ first: D(2023, 6, 1), cycle: 'yearly' });
    assert.equal(paymentDatesInRange(s, D(2025, 6), D(2025, 7)).length, 1);
    assert.equal(paymentDatesInRange(s, D(2025, 7), D(2025, 8)).length, 0);
  });
  test('與逐期計算的結果一致（隨機測試）', () => {
    for (let i = 0; i < 3000; i++) {
      const y = 2015 + Math.floor(Math.random() * 10);
      const m = Math.floor(Math.random() * 12);
      const first = new Date(y, m, 1 + Math.floor(Math.random() * new Date(y, m + 1, 0).getDate()));
      const cyc = ['monthly', 'quarterly', 'yearly'][i % 3];
      const end = Math.random() < 0.5 ? null : addMonthsClamped(first, 1 + Math.floor(Math.random() * 60));
      const from = new Date(2014 + Math.floor(Math.random() * 13), Math.floor(Math.random() * 12), 1);
      const to = addMonthsClamped(from, 1 + Math.floor(Math.random() * 24));
      const s = sub({ first, cycle: cyc, end });
      const step = { monthly: 1, quarterly: 3, yearly: 12 }[cyc];
      const naive = [];
      for (let n = 0; ; n++) {
        const d = addMonthsClamped(first, n * step);
        if (!(d < to) || (end && d >= end)) break;
        if (d >= from) naive.push(d);
      }
      assert.deepEqual(paymentDatesInRange(s, from, to), naive);
    }
  });
});

describe('nextPaymentDate', () => {
  test('今天就是扣款日時回傳今天', () => {
    assert.deepEqual(nextPaymentDate(sub({ first: D(2025, 1, 15) }), D(2025, 3, 15)), D(2025, 3, 15));
  });
  test('已停止訂閱時回傳 null', () => {
    assert.equal(nextPaymentDate(sub({ first: D(2025, 1, 15), end: D(2025, 3, 1) }), D(2025, 3, 2)), null);
  });
  test('季繳', () => {
    assert.deepEqual(nextPaymentDate(sub({ first: D(2025, 1, 15), cycle: 'quarterly' }), D(2025, 2, 1)), D(2025, 4, 15));
  });
  test('daysBetween', () => {
    assert.equal(daysBetween(D(2025, 3, 1), D(2025, 3, 31)), 30);
  });
});

describe('金額計算', () => {
  test('外幣會換算成新台幣', () => {
    const subs = [sub({ first: D(2025, 1, 5), amount: 20, currency: 'USD' }), sub({ first: D(2025, 1, 5) })];
    assert.equal(spendingInRange(subs, D(2025, 2), D(2025, 3), twd), 700);
  });
  test('每月平均成本與分類', () => {
    const r = monthlyCostByCategory([
      sub({ first: D(2025, 1), amount: 1200, cycle: 'yearly' }),
      sub({ first: D(2025, 1), amount: 150, category: 'music' }),
      sub({ first: D(2025, 1), amount: 999, end: D(2025, 2), category: 'ai' }),
    ], D(2025, 3), twd);
    assert.deepEqual(r, { video: 100, music: 150 });
  });
  test('累計支出', () => {
    assert.equal(lifetimeSpending(sub({ first: D(2025, 1, 31) }), D(2025, 4), twd), 300);
  });
});

describe('資料格式', () => {
  test('JSON 可以完整還原', () => {
    const s = sub({ first: D(2025, 1, 31), end: D(2025, 6, 1) });
    assert.deepEqual(normalize(toJSON(s)), s);
  });
  test('相容 Flutter 版的本機資料（ISO 字串、沒有 endDate）', () => {
    const r = normalize({
      id: 'a', name: 'Netflix', plan: '標準', amount: 330, currency: 'TWD', cycle: 'monthly',
      firstPaymentDate: '2025-01-31T10:20:00.000', brandColor: 0xffe50914, category: 'video',
    });
    assert.deepEqual(r.firstPaymentDate, D(2025, 1, 31));
    assert.equal(r.endDate, null);
  });
  test('欄位不完整時丟出錯誤', () => {
    assert.throws(() => normalize({ id: 'a' }));
  });
  test('輸入檢查', () => {
    assert.equal(validate(sub({ first: D(2025, 1) })), null);
    assert.match(validate({ ...sub({ first: D(2025, 1) }), amount: 0 }), /大於 0/);
    assert.match(validate(sub({ first: D(2025, 3), end: D(2025, 2) })), /晚於/);
  });
});

describe('行事曆', () => {
  test('一般日期', () => {
    assert.equal(rrule(sub({ first: D(2025, 1, 15) })), 'FREQ=MONTHLY;INTERVAL=1');
  });
  test('月底扣款用 BYSETPOS 取該月最後一個候選日', () => {
    assert.equal(rrule(sub({ first: D(2025, 1, 31), cycle: 'quarterly' })),
      'FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=28,29,30,31;BYSETPOS=-1');
  });
  test('停止續訂', () => {
    assert.equal(rrule(sub({ first: D(2025, 1, 10), end: D(2025, 3, 10) })),
      'FREQ=MONTHLY;INTERVAL=1;UNTIL=20250309');
  });
  test('ics 每行不超過 75 位元組', () => {
    const ics = buildIcs([sub({ first: D(2025, 1, 31) })], (a, c) => `${c} ${a}`);
    for (const line of ics.split('\r\n')) assert.ok(new TextEncoder().encode(line).length <= 75, line);
    assert.match(ics, /BEGIN:VALARM/);
  });
});
