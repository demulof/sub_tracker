// 共用的畫面工具：跳脫字元、格式化、底部彈出視窗、對話框、提示訊息。
import { cssColor } from './model.js';

/** HTML 跳脫。所有使用者輸入的文字都要經過它再放進畫面。 */
export const esc = (value) => String(value ?? '')
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

const intFmt = new Intl.NumberFormat('zh-TW', { maximumFractionDigits: 0 });
const decFmt = new Intl.NumberFormat('zh-TW', { maximumFractionDigits: 2 });

export const fmtTwd = (n) => `NT$ ${intFmt.format(Math.round(n))}`;
export const fmtAmount = (n, currency) =>
  `${currency} ${currency === 'USD' ? decFmt.format(n) : intFmt.format(Math.round(n))}`;
export const fmtDate = (d) =>
  `${d.getFullYear()}/${String(d.getMonth() + 1).padStart(2, '0')}/${String(d.getDate()).padStart(2, '0')}`;
export const fmtMonth = (d) => `${d.getFullYear()} 年 ${d.getMonth() + 1} 月`;
export const fmtDateTime = (ms) => {
  const d = new Date(ms);
  return `${fmtDate(d)} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
};

/** 以服務名稱第一個字做成的圖示（不使用各品牌的商標圖檔）。 */
export function brandIcon(name, color, size = 44, dimmed = false) {
  const letter = [...(name.trim() || '?')][0].toUpperCase();
  return `<span class="brand" style="width:${size}px;height:${size}px;font-size:${size * 0.48}px;` +
    `background:${dimmed ? '#bdbdbd' : cssColor(color)}">${esc(letter)}</span>`;
}

export const icon = (name) => `<svg class="ic" aria-hidden="true"><use href="#i-${name}"/></svg>`;

// ------------------------------------------------------------------ 提示訊息

let toastTimer;
export function toast(message) {
  const el = document.getElementById('toast');
  el.textContent = message;
  el.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove('show'), 2800);
}

// ------------------------------------------------------------------ 底部彈出視窗

/**
 * 開啟底部彈出視窗。bind(root, close) 用來綁定事件。回傳 close()。
 * 返回鍵（瀏覽器上一頁）也會關閉視窗。
 */
export function openSheet(html, bind, { tall = false, onClose = null } = {}) {
  const layer = document.createElement('div');
  layer.className = 'overlay';
  layer.innerHTML = `<div class="sheet${tall ? ' tall' : ''}" role="dialog" aria-modal="true">
    <div class="grab"></div>${html}</div>`;
  document.body.appendChild(layer);
  document.body.classList.add('locked');
  requestAnimationFrame(() => layer.classList.add('open'));

  let closed = false;
  const close = () => {
    if (closed) return;
    closed = true;
    layer.classList.remove('open');
    onClose?.();
    setTimeout(() => {
      layer.remove();
      if (!document.querySelector('.overlay')) document.body.classList.remove('locked');
    }, 220);
  };
  layer.addEventListener('click', (e) => { if (e.target === layer) close(); });
  layer.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });
  bind?.(layer.querySelector('.sheet'), close);
  return close;
}

/** 讓使用者從清單選一項。回傳選到的 value，取消時回傳 null。 */
export function chooseSheet(title, options, footnote = '') {
  return new Promise((resolve) => {
    let picked = null;
    openSheet(`
      <h3 class="sheet-title">${esc(title)}</h3>
      <div class="choices">
        ${options.map((o, i) => `<button class="choice" data-i="${i}">
          <span>${esc(o.label)}</span><span class="muted">${esc(o.detail ?? '')}</span></button>`).join('')}
      </div>
      ${footnote ? `<p class="hint">${esc(footnote)}</p>` : ''}`,
    (root, close) => {
      root.querySelectorAll('.choice').forEach((b) => b.addEventListener('click', () => {
        picked = options[Number(b.dataset.i)].value;
        close();
      }));
    }, { onClose: () => resolve(picked) });
  });
}

// ------------------------------------------------------------------ 對話框

function dialog(inner, bind) {
  return new Promise((resolve) => {
    const layer = document.createElement('div');
    layer.className = 'overlay dialog-layer';
    layer.innerHTML = `<div class="dialog" role="alertdialog" aria-modal="true">${inner}</div>`;
    document.body.appendChild(layer);
    requestAnimationFrame(() => layer.classList.add('open'));
    const done = (value) => {
      layer.classList.remove('open');
      setTimeout(() => layer.remove(), 180);
      resolve(value);
    };
    bind(layer.querySelector('.dialog'), done);
  });
}

export function confirmDialog({ title, message, confirm = '確定', cancel = '取消', danger = false }) {
  return dialog(`
    ${title ? `<h3>${esc(title)}</h3>` : ''}
    <p class="dialog-msg">${esc(message)}</p>
    <div class="dialog-actions">
      ${cancel ? `<button class="btn text" data-act="no">${esc(cancel)}</button>` : ''}
      <button class="btn text ${danger ? 'danger' : ''}" data-act="yes">${esc(confirm)}</button>
    </div>`,
  (root, done) => {
    root.querySelector('[data-act="yes"]').addEventListener('click', () => done(true));
    root.querySelector('[data-act="no"]')?.addEventListener('click', () => done(false));
  });
}

export const alertDialog = (message, title = '') =>
  confirmDialog({ title, message, cancel: '', confirm: '確定' });

export function promptDialog({ title, message = '', label = '', type = 'text', value = '',
  maxLength = 100, confirm = '確定', danger = false }) {
  return dialog(`
    <h3>${esc(title)}</h3>
    ${message ? `<p class="dialog-msg">${esc(message)}</p>` : ''}
    <label class="field"><span>${esc(label)}</span>
      <input type="${type}" maxlength="${maxLength}" value="${esc(value)}"
        ${type === 'password' ? 'autocomplete="current-password"' : ''}></label>
    <div class="dialog-actions">
      <button class="btn text" data-act="no">取消</button>
      <button class="btn text ${danger ? 'danger' : ''}" data-act="yes">${esc(confirm)}</button>
    </div>`,
  (root, done) => {
    const input = root.querySelector('input');
    setTimeout(() => input.focus(), 50);
    const ok = () => done(type === 'password' ? input.value : input.value.trim());
    root.querySelector('[data-act="yes"]').addEventListener('click', ok);
    root.querySelector('[data-act="no"]').addEventListener('click', () => done(null));
    input.addEventListener('keydown', (e) => { if (e.key === 'Enter') ok(); });
  });
}

// ------------------------------------------------------------------ 檔案

/** 下載或分享檔案。iPhone 上優先用分享選單（可以存到「檔案」或用其他 app 開啟）。 */
export async function saveFile(filename, content, type) {
  const blob = new Blob([content], { type });
  const file = typeof File === 'function' ? new File([blob], filename, { type }) : null;
  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  if (isIOS && file && navigator.canShare?.({ files: [file] }) && type !== 'text/calendar') {
    try {
      await navigator.share({ files: [file] });
      return;
    } catch (e) {
      if (e?.name === 'AbortError') return;
    }
  }
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

/** 讓使用者選一個檔案並讀成文字。 */
export function pickTextFile(accept) {
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = accept;
    input.addEventListener('change', async () => {
      const f = input.files?.[0];
      resolve(f ? await f.text() : null);
    });
    input.click();
  });
}
