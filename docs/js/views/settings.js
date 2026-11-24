// 設定：帳號、資料（行事曆、備份）、匯率、安裝說明
import * as cloud from '../cloud.js';
import * as store from '../store.js';
import { isEndedOn } from '../billing.js';
import { dateOnly, UserError } from '../model.js';
import { buildIcs } from '../ics.js';
import { getRates, refreshRates } from '../rates.js';
import { RATE_ATTRIBUTION } from '../config.js';
import {
  alertDialog, confirmDialog, esc, fmtAmount, fmtDateTime, icon, pickTextFile, promptDialog, saveFile, toast,
} from '../ui.js';

const isStandalone = () =>
  window.matchMedia?.('(display-mode: standalone)').matches || navigator.standalone === true;

const row = (act, ic, title, sub = '', extra = '') =>
  `<button class="set-row ${extra}" data-act="${act}">${icon(ic)}<span><b>${title}</b>${sub ? `<small>${sub}</small>` : ''}</span></button>`;

export function render({ user, subs }) {
  const rates = getRates();
  const account = user
    ? `<section class="card list-card">
        ${row('name', 'user', '顯示名稱', esc(cloud.displayNameOf(user)))}
        <div class="set-row static">${icon('mail')}<span><b>Email</b>
          <small>${esc(user.email)}${user.emailVerified ? '' : '（尚未驗證）'}</small></span></div>
        ${row('reset', 'key', '重設密碼', '寄送重設密碼信到你的信箱')}
        ${row('logout', 'logout', '登出')}
        ${row('delete', 'trash', '刪除帳號', '永久刪除帳號與所有雲端資料', 'danger')}
      </section>`
    : cloud.cloudEnabled
      ? `<section class="card list-card">
          ${row('login', 'user-plus', '登入或註冊', '登入後資料會同步到雲端，手機和電腦都能使用')}
        </section>
        <p class="hint">目前是訪客模式，資料只存在這台裝置的瀏覽器裡。清除瀏覽器資料會讓資料消失，建議定期匯出備份。</p>`
      : `<p class="hint">尚未設定 Firebase，目前只能使用訪客模式：資料只存在這台裝置的瀏覽器裡，建議定期匯出備份。</p>`;

  return `<header class="page-head"><div><h1>設定</h1></div></header>
    <h2>帳號</h2>${account}

    <h2>資料</h2>
    <section class="card list-card">
      ${row('calendar', 'calendar', '匯出到行事曆', '所有訂閱中的扣款日，前一天早上 9 點提醒')}
      ${row('export', 'download', '匯出備份', `目前共 ${subs?.length ?? 0} 筆，存成 JSON 檔`)}
      ${row('import', 'upload', '匯入備份', '相同的項目會被備份檔覆蓋')}
    </section>

    <h2>匯率</h2>
    <section class="card list-card">
      ${row('rates', 'refresh', rates.isFallback ? '使用預設匯率' : '線上匯率',
        rates.isFallback ? '尚未取得線上匯率，點此更新'
          : `USD ${rates.twdPerUnit.USD.toFixed(2)}、JPY ${rates.twdPerUnit.JPY.toFixed(4)}，更新於 ${fmtDateTime(rates.updatedAt)}`)}
    </section>
    <p class="hint"><small>${esc(RATE_ATTRIBUTION)}</small></p>

    ${isStandalone() ? '' : `<h2>安裝到主畫面</h2>
    <section class="card install">
      <p><b>iPhone：</b>用 Safari 開啟這個網址 → 點下方的「分享」${icon('share')} →「加入主畫面」。</p>
      <p><b>Android：</b>用 Chrome 開啟 → 右上角選單 →「安裝應用程式」或「加到主畫面」。</p>
      <p class="muted">安裝後要重新登入一次，因為主畫面版本和瀏覽器的資料是分開的。</p>
    </section>`}
    <p class="version muted">訂閱管家 網頁版</p>`;
}

export function bind(root, { go, subs }) {
  root.addEventListener('click', async (e) => {
    const act = e.target.closest('[data-act]')?.dataset.act;
    if (!act) return;
    const user = store.getState().user;
    try {
      switch (act) {
        case 'login':
          go('login');
          break;
        case 'name': {
          const name = await promptDialog({
            title: '修改顯示名稱', label: '顯示名稱', value: cloud.displayNameOf(user), maxLength: 30, confirm: '儲存',
          });
          if (name && name !== user.displayName) {
            await cloud.updateDisplayName(name);
            store.refreshUser();
            toast('已更新顯示名稱');
          }
          break;
        }
        case 'reset':
          await cloud.resetPassword(user.email);
          toast(`重設密碼信已寄到 ${user.email}`);
          break;
        case 'logout':
          await cloud.signOutUser();
          go('');
          break;
        case 'delete': {
          const password = await promptDialog({
            title: '永久刪除帳號',
            message: '刪除後，你的帳號與雲端上所有訂閱資料都會永久刪除，無法復原。請輸入密碼確認：',
            label: '密碼', type: 'password', confirm: '永久刪除', danger: true,
          });
          if (!password) break;
          toast('刪除中…');
          await cloud.deleteAccount(password);
          toast('帳號已刪除');
          go('');
          break;
        }
        case 'calendar': {
          const today = dateOnly(new Date());
          const active = (subs ?? []).filter((s) => !isEndedOn(s, today));
          if (!active.length) {
            toast('目前沒有訂閱中的項目');
            break;
          }
          const ok = await confirmDialog({
            title: '匯出到行事曆',
            message: `會產生一個包含 ${active.length} 筆訂閱的行事曆檔。開啟後選擇要加入的行事曆即可。\n\n` +
              '之後修改或新增訂閱，行事曆不會自動更新：可以在該訂閱的編輯畫面單獨加入，' +
              '或先刪除行事曆裡的舊事件再重新匯出，避免重複。',
            confirm: '匯出',
          });
          if (ok) await saveFile('訂閱扣款日.ics', buildIcs(active, fmtAmount), 'text/calendar');
          break;
        }
        case 'export': {
          const stamp = new Date().toISOString().slice(0, 10);
          await saveFile(`訂閱管家備份-${stamp}.json`, store.exportBackup(), 'application/json');
          break;
        }
        case 'import': {
          const text = await pickTextFile('application/json,.json');
          if (!text) break;
          const count = await store.importBackup(text);
          toast(`已匯入 ${count} 筆`);
          break;
        }
        case 'rates': {
          const ok = await refreshRates();
          toast(ok ? '匯率已更新' : '目前無法更新匯率，請稍後再試');
          go('settings', true);
          break;
        }
        default:
      }
    } catch (err) {
      console.error(err);
      alertDialog(err instanceof UserError ? err.message : '發生錯誤，請稍後再試。');
    }
  });
}
