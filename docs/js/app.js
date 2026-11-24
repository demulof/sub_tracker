// 進入點：路由、畫面更新、Service Worker 註冊
import * as cloud from './cloud.js';
import * as store from './store.js';
import { getRates, initRates, onRatesChange } from './rates.js';
import { toast } from './ui.js';
import { openEditor } from './views/editor.js';
import * as home from './views/home.js';
import * as stats from './views/stats.js';
import * as settings from './views/settings.js';
import * as login from './views/login.js';

const VIEWS = { '': home, stats, settings, login };
const main = document.getElementById('main');
const fab = document.getElementById('fab');

const route = () => location.hash.replace(/^#\/?/, '').split('?')[0];

/** 換頁；replace 為 true 時只重畫目前頁面、不新增瀏覽紀錄。 */
function go(path, replace = false) {
  const target = `#/${path}`;
  if (replace || location.hash === target) render();
  else location.hash = target;
}

async function resend() {
  try {
    await cloud.resendVerification();
    toast('驗證信已寄出');
  } catch (e) {
    toast(e.message);
  }
}

function render() {
  const name = VIEWS[route()] ? route() : '';
  const view = VIEWS[name];
  const { user, subs, error } = store.getState();
  // 已登入時不需要停在登入頁
  if (name === 'login' && user) {
    location.replace('#/');
    return;
  }
  const ctx = { user: user ?? null, subs, error, rates: getRates(), go, openEditor, resend };
  const scrollY = window.scrollY;
  const container = document.createElement('div');
  container.className = `view view-${name || 'home'}`;
  container.innerHTML = view.render(ctx);
  view.bind?.(container, ctx);
  main.replaceChildren(container);
  window.scrollTo(0, main.dataset.route === name ? scrollY : 0);
  main.dataset.route = name;

  document.querySelectorAll('.tabbar a').forEach((a) =>
    a.classList.toggle('on', a.getAttribute('href') === `#/${name}`));
  fab.hidden = name !== '' && name !== 'stats';
}

fab.addEventListener('click', () => openEditor());
window.addEventListener('hashchange', render);
// 資料或匯率更新時重畫畫面；登入頁有輸入框，重畫會清掉使用者正在輸入的內容，所以略過。
const refresh = () => {
  if (route() === 'login' && main.dataset.route === 'login' && !store.getState().user) return;
  render();
};
store.subscribe(refresh);
onRatesChange(refresh);

initRates();
cloud.initCloud((user) => store.setUser(user));
// 從背景回到前景時更新匯率（例如隔天才打開）
document.addEventListener('visibilitychange', () => { if (!document.hidden) initRates(); });

render();

if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost')) {
  navigator.serviceWorker.register('./sw.js').then((reg) => {
    reg.addEventListener('updatefound', () => {
      const worker = reg.installing;
      worker?.addEventListener('statechange', () => {
        if (worker.state === 'installed' && navigator.serviceWorker.controller) {
          toast('已有新版本，重新開啟後就會更新');
        }
      });
    });
  }).catch((e) => console.warn('Service Worker 註冊失敗', e));
}
