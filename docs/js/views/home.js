// 首頁（儀表板）
import {
  daysBetween, monthStart, nextMonthStart, nextPaymentDate, spendingInRange, isEndedOn,
} from '../billing.js';
import { cycle, dateOnly } from '../model.js';
import { toTwd } from '../rates.js';
import { displayNameOf } from '../cloud.js';
import { brandIcon, esc, fmtAmount, fmtDate, fmtTwd, icon } from '../ui.js';

let yearly = false;

function totals(subs, today) {
  if (!yearly) {
    const start = monthStart(today);
    return {
      current: spendingInRange(subs, start, nextMonthStart(today), toTwd),
      previous: spendingInRange(subs, new Date(today.getFullYear(), today.getMonth() - 1, 1), start, toTwd),
    };
  }
  const y = today.getFullYear();
  return {
    current: spendingInRange(subs, new Date(y, 0, 1), new Date(y + 1, 0, 1), toTwd),
    previous: spendingInRange(subs, new Date(y - 1, 0, 1), new Date(y, 0, 1), toTwd),
  };
}

function greeting() {
  const h = new Date().getHours();
  return h < 12 ? '早安' : h < 18 ? '午安' : '晚安';
}

function item(sub, dimmed) {
  const sub2 = sub.currency === 'TWD'
    ? cycle(sub.cycle).short
    : `≈ ${fmtTwd(toTwd(sub.amount, sub.currency))} ${cycle(sub.cycle).short}`;
  return `<button class="row-card" data-edit="${esc(sub.id)}">
    ${brandIcon(sub.name, sub.brandColor, 46, dimmed)}
    <span class="row-main">
      <span class="row-title${dimmed ? ' dim' : ''}">${esc(sub.name)}</span>
      <span class="row-sub">${dimmed && sub.endDate ? `${fmtDate(sub.endDate)} 起停止` : esc(sub.plan)}</span>
    </span>
    <span class="row-end">
      <span class="row-amount${dimmed ? ' dim' : ''}">${esc(fmtAmount(sub.amount, sub.currency))}</span>
      <span class="row-sub">${esc(sub2)}</span>
    </span>
  </button>`;
}

function upcomingCard(sub, days) {
  const tone = days <= 3 ? 'red' : days <= 14 ? 'orange' : 'green';
  return `<button class="up-card" data-edit="${esc(sub.id)}">
    <span class="up-head">${brandIcon(sub.name, sub.brandColor, 38)}
      <span class="up-text"><b>${esc(sub.name)}</b><span class="muted">${esc(fmtAmount(sub.amount, sub.currency))}</span></span>
    </span>
    <span class="pill ${tone}">${days === 0 ? '今天付款' : `${days} 天後付款`}</span>
  </button>`;
}

export function render({ user, subs, rates, error }) {
  const header = `<header class="page-head">
    <div><p class="muted">${greeting()}，${esc(displayNameOf(user))}</p><h1>你的儀表板</h1></div>
    <a class="avatar" href="#/settings" aria-label="設定">${icon(user ? 'user' : 'user-plus')}</a>
  </header>`;

  if (error) {
    return `${header}<div class="empty">${icon('cloud-off')}<p>${esc(error)}</p>
      <button class="btn outline" data-act="reload">重新載入</button></div>`;
  }
  if (!subs) return `${header}<div class="spinner"></div>`;

  const today = dateOnly(new Date());
  const { current, previous } = totals(subs, today);
  const diff = current - previous;
  const label = yearly ? '去年' : '上月';
  const diffText = Math.round(diff) === 0 ? `與${label}相同`
    : `比${label}${diff > 0 ? '多' : '少'} ${fmtTwd(Math.abs(diff))}`;

  const upcoming = subs
    .map((s) => ({ s, next: nextPaymentDate(s, today) }))
    .filter((x) => x.next && daysBetween(today, x.next) <= 30)
    .sort((a, b) => a.next - b.next);
  const active = subs.filter((s) => !isEndedOn(s, today));
  const ended = subs.filter((s) => isEndedOn(s, today));
  const foreign = subs.some((s) => s.currency !== 'TWD');

  return `${header}
    ${user && !user.emailVerified ? `<div class="banner">${icon('mail')}
      <span>請到信箱點擊驗證連結，完成 Email 驗證。</span>
      <button class="btn text small" data-act="resend">重寄</button></div>` : ''}

    <section class="total-card" data-act="stats">
      <div class="total-top">
        <span>${yearly ? '本年總支出' : '本月總支出'}</span>
        <button class="toggle" data-act="toggle" aria-label="切換月或年">
          <b class="${yearly ? '' : 'on'}">月</b> / <b class="${yearly ? 'on' : ''}">年</b></button>
      </div>
      <div class="total-amount">${fmtTwd(current)}</div>
      <div class="total-diff">${diffText}</div>
      <div class="total-note">含本期尚未扣款的預定款項</div>
    </section>
    ${foreign ? `<p class="hint">${rates.isFallback ? '外幣以預設匯率估算，連上網路後會自動更新。'
      : '外幣已依最新匯率換算為新台幣。'}</p>` : ''}

    ${upcoming.length ? `<h2>即將付款</h2>
      <div class="hscroll">${upcoming.map((x) => upcomingCard(x.s, daysBetween(today, x.next))).join('')}</div>` : ''}

    <h2>所有訂閱項目</h2>
    ${active.length ? `<div class="list">${active.map((s) => item(s, false)).join('')}</div>`
      : '<div class="empty small"><p>點右下角的 ＋ 新增第一筆訂閱</p></div>'}
    ${ended.length ? `<h2 class="dim">已停止的訂閱</h2>
      <div class="list">${ended.map((s) => item(s, true)).join('')}</div>` : ''}
    <div class="fab-space"></div>`;
}

export function bind(root, { openEditor, go, resend, subs }) {
  root.addEventListener('click', (e) => {
    const toggle = e.target.closest('[data-act="toggle"]');
    if (toggle) {
      e.stopPropagation();
      yearly = !yearly;
      go('', true);
      return;
    }
    const edit = e.target.closest('[data-edit]');
    if (edit) {
      openEditor(subs.find((s) => s.id === edit.dataset.edit));
      return;
    }
    const act = e.target.closest('[data-act]')?.dataset.act;
    if (act === 'stats') go('stats');
    else if (act === 'resend') resend();
    else if (act === 'reload') location.reload();
  });
}
