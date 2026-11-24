// 新增／編輯訂閱（底部彈出視窗）
import { CATEGORIES, CYCLES, LIMITS, category, dateOnly, parseDate, toDateInput, validate } from '../model.js';
import { SUGGESTIONS, findSuggestion } from '../suggestions.js';
import { buildIcs } from '../ics.js';
import * as store from '../store.js';
import {
  alertDialog, brandIcon, chooseSheet, confirmDialog, esc, fmtAmount, icon, openSheet, saveFile, toast,
} from '../ui.js';

const amountText = (n) => String(Math.round(n * 100) / 100);

export function openEditor(existing = null) {
  const today = dateOnly(new Date());
  const form = {
    category: existing?.category ?? 'video',
    name: existing?.name ?? '',
    plan: existing?.plan ?? '',
    amount: existing ? amountText(existing.amount) : '',
    currency: existing?.currency ?? 'TWD',
    cycle: existing?.cycle ?? 'monthly',
    first: existing?.firstPaymentDate ?? today,
    ended: Boolean(existing?.endDate),
    end: existing?.endDate ?? today,
  };
  let selectedPlan = null; // 從快速新增選到的方案，用來在換幣別時自動帶入價格
  let saving = false;

  const suggestionsHtml = () => {
    const items = SUGGESTIONS.filter((s) => s.category === form.category);
    if (!items.length) return '<p class="hint">此分類沒有常用服務，請直接在下方輸入。</p>';
    return `<p class="hint">從常用服務快速新增（價格僅供參考）</p>
      <div class="sugg-grid">${items.map((s) => `<button type="button" class="sugg" data-sugg="${esc(s.name)}">
        ${brandIcon(s.name, s.color, 36)}<span>${esc(s.name)}</span></button>`).join('')}</div>`;
  };

  const html = `
    <form class="editor" novalidate>
      <h3 class="sheet-title">${existing ? '編輯訂閱項目' : '新增訂閱項目'}</h3>
      <div class="label">分類</div>
      <div class="chips" role="radiogroup">${CATEGORIES.map((c) =>
        `<button type="button" class="chip" data-cat="${c.id}" role="radio">${esc(c.name)}</button>`).join('')}</div>
      ${existing ? '' : '<div class="suggestions"></div>'}

      <label class="field"><span>服務名稱</span>
        <input name="svcname" maxlength="${LIMITS.maxNameLength}" placeholder="例如：YouTube" autocomplete="off" required></label>
      <label class="field"><span>方案名稱（選填）</span>
        <input name="plan" maxlength="${LIMITS.maxPlanLength}" placeholder="例如：Premium 個人" autocomplete="off"></label>
      <div class="field"><span>金額</span>
        <div class="amount-row">
          <input name="amount" inputmode="decimal" placeholder="390" autocomplete="off">
          <select name="currency" aria-label="幣別">${LIMITS.currencies.map((c) =>
            `<option value="${c}">${c}</option>`).join('')}</select>
        </div></div>
      <div class="label">付款週期</div>
      <div class="segmented">${CYCLES.map((c) =>
        `<button type="button" data-cycle="${c.id}">${esc(c.name)}</button>`).join('')}</div>
      <label class="field"><span>首次付款日</span><input type="date" name="first" required></label>
      <label class="switch-row"><span><b>已停止訂閱</b><small>保留過去的支出紀錄，之後不再計算扣款</small></span>
        <input type="checkbox" name="ended" role="switch"></label>
      <label class="field end-field"><span>停止續訂日（此日起不再扣款）</span><input type="date" name="end"></label>
      <p class="form-error" role="alert"></p>
      <button class="btn primary block" type="submit">${existing ? '儲存變更' : '儲存訂閱'}</button>
      ${existing ? `<div class="editor-extra">
        <button type="button" class="btn text" data-act="calendar">${icon('calendar')} 加入行事曆提醒</button>
        <button type="button" class="btn text danger" data-act="delete">${icon('trash')} 刪除此訂閱</button>
      </div>` : ''}
    </form>`;

  openSheet(html, (root, close) => {
    const $ = (sel) => root.querySelector(sel);
    const f = $('form');
    const el = f.elements;
    const errorEl = $('.form-error');

    const sync = () => {
      root.querySelectorAll('[data-cat]').forEach((b) => {
        b.classList.toggle('on', b.dataset.cat === form.category);
        b.setAttribute('aria-checked', String(b.dataset.cat === form.category));
      });
      root.querySelectorAll('[data-cycle]').forEach((b) => b.classList.toggle('on', b.dataset.cycle === form.cycle));
      $('.end-field').hidden = !form.ended;
      const box = $('.suggestions');
      if (box) box.innerHTML = suggestionsHtml();
    };

    el.svcname.value = form.name;
    el.plan.value = form.plan;
    el.amount.value = form.amount;
    el.currency.value = form.currency;
    el.first.value = toDateInput(form.first);
    el.ended.checked = form.ended;
    el.end.value = toDateInput(form.end);
    sync();

    el.amount.addEventListener('input', () => {
      // 只允許數字與最多兩位小數
      const clean = el.amount.value.replace(/[^\d.]/g, '').replace(/^(\d*\.?\d{0,2}).*$/, '$1');
      if (clean !== el.amount.value) el.amount.value = clean;
    });
    el.currency.addEventListener('change', () => {
      const price = selectedPlan?.prices[el.currency.value];
      if (price != null) el.amount.value = amountText(price);
    });
    el.ended.addEventListener('change', () => { form.ended = el.ended.checked; sync(); });

    root.addEventListener('click', async (e) => {
      const cat = e.target.closest('[data-cat]');
      if (cat) { form.category = cat.dataset.cat; sync(); return; }
      const cyc = e.target.closest('[data-cycle]');
      if (cyc) { form.cycle = cyc.dataset.cycle; sync(); return; }
      const sugg = e.target.closest('[data-sugg]');
      if (sugg) {
        const s = SUGGESTIONS.find((x) => x.name === sugg.dataset.sugg);
        const options = s.plans.map((p) => {
          const cur = p.prices[el.currency.value] != null ? el.currency.value : s.native;
          return { label: p.name, detail: fmtAmount(p.prices[cur], cur), value: { p, cur } };
        });
        const picked = await chooseSheet(`選擇 ${s.name} 的方案`, options, '價格僅供參考，請以實際帳單金額為準。');
        if (!picked) return;
        selectedPlan = picked.p;
        el.svcname.value = s.name;
        el.plan.value = picked.p.name;
        el.currency.value = picked.cur;
        el.amount.value = amountText(picked.p.prices[picked.cur]);
        form.category = s.category;
        sync();
        return;
      }
      const act = e.target.closest('[data-act]')?.dataset.act;
      if (act === 'delete') {
        const ok = await confirmDialog({
          title: '刪除訂閱',
          message: `確定要刪除「${existing.name}」嗎？刪除後無法復原，相關的統計紀錄也會一併消失。\n\n` +
            '如果只是不再續訂，建議改用「已停止訂閱」，保留過去的支出紀錄。',
          confirm: '刪除', danger: true,
        });
        if (!ok) return;
        try {
          await store.deleteSubscription(existing.id);
          close();
          toast('已刪除');
        } catch (err) {
          console.error(err);
          alertDialog('刪除失敗，請稍後再試。');
        }
      } else if (act === 'calendar') {
        await saveFile(`${existing.name}.ics`, buildIcs([existing], fmtAmount), 'text/calendar');
      }
    });

    f.addEventListener('submit', async (e) => {
      e.preventDefault();
      if (saving) return;
      const name = el.svcname.value.trim();
      const suggestion = findSuggestion(name);
      let brandColor;
      if (suggestion) brandColor = suggestion.color;
      else if (existing && existing.name === name) brandColor = existing.brandColor;
      else brandColor = category(form.category).color;

      const sub = {
        id: existing?.id ?? '',
        name,
        plan: el.plan.value.trim() || '自訂方案',
        amount: Number(el.amount.value),
        currency: el.currency.value,
        cycle: form.cycle,
        firstPaymentDate: parseDate(el.first.value),
        endDate: el.ended.checked ? parseDate(el.end.value) : null,
        brandColor,
        category: form.category,
      };
      if (el.ended.checked && !sub.endDate) {
        errorEl.textContent = '請選擇停止續訂日';
        return;
      }
      const problem = el.amount.value.trim() === '' ? '請輸入金額' : validate(sub);
      if (problem) {
        errorEl.textContent = problem;
        return;
      }
      errorEl.textContent = '';
      saving = true;
      const btn = f.querySelector('[type="submit"]');
      btn.disabled = true;
      btn.textContent = '儲存中…';
      try {
        await store.saveSubscription(sub);
        close();
        toast(existing ? '已儲存變更' : '已新增訂閱');
      } catch (err) {
        console.error(err);
        errorEl.textContent = '儲存失敗，請稍後再試。';
        btn.disabled = false;
        btn.textContent = existing ? '儲存變更' : '儲存訂閱';
        saving = false;
      }
    });
  }, { tall: true });
}
