// 統計分析
import {
  lifetimeSpending, monthStart, monthlyCostByCategory, nextMonthStart, spendingInRange,
} from '../billing.js';
import { CATEGORIES, cssColor } from '../model.js';
import { toTwd } from '../rates.js';
import { RATE_ATTRIBUTION } from '../config.js';
import { brandIcon, esc, fmtDateTime, fmtMonth, fmtTwd, icon } from '../ui.js';

let selected = monthStart(new Date());
let touched = null;

const monthValue = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;

function donut(entries, total) {
  // 用 SVG 圓弧畫環狀圖；每段的 pathLength 以 100 為總長。
  const r = 70;
  let offset = 0;
  const segments = entries.map(([cat, value]) => {
    const pct = (value / total) * 100;
    const gap = entries.length > 1 ? 1.2 : 0;
    const seg = `<circle class="seg${touched === cat.id ? ' on' : ''}" data-cat="${cat.id}" r="${r}" cx="90" cy="90"
      pathLength="100" stroke="${cssColor(cat.color)}"
      stroke-dasharray="${Math.max(pct - gap, 0.1)} ${100 - Math.max(pct - gap, 0.1)}"
      stroke-dashoffset="${-offset}"/>`;
    offset += pct;
    return seg;
  }).join('');
  const hit = entries.find(([cat]) => cat.id === touched);
  const center = hit
    ? `<b>${esc(hit[0].name)}</b><span>${fmtTwd(hit[1])}</span><b>${((hit[1] / total) * 100).toFixed(1)}%</b>`
    : `<span class="muted">每月平均</span><b>${fmtTwd(total)}</b>`;
  return `<div class="donut">
    <svg viewBox="0 0 180 180" role="img" aria-label="支出分類圓餅圖">
      <g transform="rotate(-90 90 90)">${segments}</g></svg>
    <div class="donut-center">${center}</div></div>`;
}

export function render({ subs, rates }) {
  const head = `<header class="page-head"><div><h1>統計分析</h1></div></header>`;
  if (!subs) return `${head}<div class="spinner"></div>`;
  if (!subs.length) return `${head}<div class="empty">${icon('chart')}<p>還沒有訂閱資料可以分析</p></div>`;

  const start = selected;
  const end = nextMonthStart(start);
  const prevStart = new Date(start.getFullYear(), start.getMonth() - 1, 1);
  const charged = spendingInRange(subs, start, end, toTwd);
  const diff = charged - spendingInRange(subs, prevStart, start, toTwd);
  const byCat = monthlyCostByCategory(subs, start, toTwd);
  const entries = CATEGORIES.filter((c) => (byCat[c.id] ?? 0) > 0).map((c) => [c, byCat[c.id]]);
  const monthlyTotal = entries.reduce((a, [, v]) => a + v, 0);
  const lifetime = subs.map((s) => [s, lifetimeSpending(s, end, toTwd)])
    .filter(([, v]) => v > 0).sort((a, b) => b[1] - a[1]);

  const earliest = subs.reduce((m, s) => (s.firstPaymentDate < m ? s.firstPaymentDate : m), new Date());
  const now = new Date();
  const max = new Date(now.getFullYear(), now.getMonth() + 12, 1);
  const diffClass = Math.round(diff) === 0 ? '' : diff > 0 ? 'up' : 'down';

  return `${head}
    <div class="section-head"><h2>總覽</h2>
      <div class="month-nav">
      <button class="icon-btn" data-month="-1" aria-label="上個月"${start <= monthStart(earliest) ? ' disabled' : ''}>‹</button>
      <label class="month-pick">${icon('calendar')}<span>${fmtMonth(start)}</span>
        <input type="month" value="${monthValue(start)}" min="${monthValue(earliest)}" max="${monthValue(max)}"
          aria-label="選擇月份"></label>
      <button class="icon-btn" data-month="1" aria-label="下個月"${start >= monthStart(max) ? ' disabled' : ''}>›</button>
      </div>
    </div>
    <section class="card summary">
      <div><span class="muted">當月扣款</span><b>${fmtTwd(charged)}</b></div>
      <div><span class="muted">與上月比較</span><b class="${diffClass}">${diff >= 0 ? '+' : '−'} ${fmtTwd(Math.abs(diff))}</b></div>
      <div><span class="muted">每月平均成本</span><b>${fmtTwd(monthlyTotal)}</b></div>
    </section>

    <h2>支出分類</h2>
    <p class="hint">以當月訂閱中的項目，換算每月平均成本。點圓環可以看各分類的比例。</p>
    <section class="card">
      ${entries.length ? `${donut(entries, monthlyTotal)}
        <div class="legend">${entries.map(([c, v]) => `<button class="legend-item" data-cat="${c.id}">
          <i style="background:${cssColor(c.color)}"></i>${esc(c.name)} ${fmtTwd(v)}</button>`).join('')}</div>`
        : '<p class="empty small">這個月份沒有訂閱中的項目</p>'}
    </section>

    <h2>累計支出 <small class="muted">（至 ${fmtMonth(start)} 底）</small></h2>
    ${lifetime.length ? `<div class="list">${lifetime.map(([s, v]) => `<div class="row-card static">
      ${brandIcon(s.name, s.brandColor, 40)}<span class="row-main"><span class="row-title">${esc(s.name)}</span></span>
      <span class="row-amount">${fmtTwd(v)}</span></div>`).join('')}</div>`
      : '<p class="hint">這個月份之前還沒有扣款紀錄。</p>'}

    <p class="hint">${rates.isFallback ? '外幣以預設匯率估算（尚未取得線上匯率）。'
      : `外幣依 ${fmtDateTime(rates.updatedAt)} 的匯率換算，歷史金額同樣以目前匯率計算。`}<br>
      <small>${esc(RATE_ATTRIBUTION)}</small></p>`;
}

export function bind(root, { go }) {
  root.querySelector('input[type="month"]')?.addEventListener('change', (e) => {
    const m = e.target.value.match(/^(\d{4})-(\d{2})$/);
    if (!m) return;
    selected = new Date(Number(m[1]), Number(m[2]) - 1, 1);
    touched = null;
    go('stats', true);
  });
  root.addEventListener('click', (e) => {
    const nav = e.target.closest('[data-month]');
    if (nav) {
      selected = new Date(selected.getFullYear(), selected.getMonth() + Number(nav.dataset.month), 1);
      touched = null;
      go('stats', true);
      return;
    }
    const seg = e.target.closest('[data-cat]');
    if (!seg) return;
    touched = touched === seg.dataset.cat ? null : seg.dataset.cat;
    go('stats', true);
  });
}
