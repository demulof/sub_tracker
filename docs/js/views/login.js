// 登入／註冊
import * as cloud from '../cloud.js';
import * as store from '../store.js';
import { UserError } from '../model.js';
import { alertDialog, confirmDialog, toast } from '../ui.js';

let registering = false;

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

/** 密碼規則：至少 8 碼，且同時包含英文字母與數字。 */
export function passwordProblem(pw) {
  if (pw.length < 8) return '密碼至少需 8 個字元';
  if (!/[A-Za-z]/.test(pw) || !/\d/.test(pw)) return '密碼需同時包含英文字母與數字';
  return null;
}

export function render() {
  if (!cloud.cloudEnabled) {
    return `<header class="page-head"><div><h1>登入</h1></div></header>
      <p class="hint">尚未設定 Firebase，目前只能使用訪客模式。設定方式請看 README。</p>`;
  }
  return `<header class="page-head"><div>
      <h1>${registering ? '建立新帳號' : '歡迎回來'}</h1>
      <p class="muted">${registering ? '註冊後手機和電腦可以使用同一份資料' : '登入後資料會同步到雲端'}</p>
    </div></header>
    <form class="card auth-form" novalidate>
      ${registering ? `<label class="field"><span>顯示名稱</span>
        <input name="displayName" maxlength="30" autocomplete="nickname" required></label>` : ''}
      <label class="field"><span>電子郵件</span>
        <input name="email" type="email" autocomplete="email" autocapitalize="off" spellcheck="false" required></label>
      <label class="field"><span>密碼</span>
        <input name="password" type="password" autocomplete="${registering ? 'new-password' : 'current-password'}" required>
        ${registering ? '<small class="muted">至少 8 碼，需包含英文字母與數字</small>' : ''}</label>
      ${registering ? '' : '<button type="button" class="btn text small right" data-act="forgot">忘記密碼？</button>'}
      <p class="form-error" role="alert"></p>
      <button class="btn primary block" type="submit">${registering ? '註冊' : '登入'}</button>
      <button type="button" class="btn text block" data-act="switch">
        ${registering ? '已經有帳號了？點此登入' : '還沒有帳號？點此註冊'}</button>
    </form>`;
}

export function bind(root, { go }) {
  const f = root.querySelector('form');
  if (!f) return;
  const el = f.elements;
  const errorEl = root.querySelector('.form-error');
  const fail = (msg) => { errorEl.textContent = msg; };

  root.addEventListener('click', async (e) => {
    const act = e.target.closest('[data-act]')?.dataset.act;
    if (act === 'switch') {
      registering = !registering;
      go('login', true);
    } else if (act === 'forgot') {
      const email = el.email.value.trim();
      if (!EMAIL_RE.test(email)) return fail('請先在上方輸入註冊時使用的 Email。');
      try {
        await cloud.resetPassword(email);
        alertDialog('如果這個 Email 已經註冊，你會收到一封重設密碼的信，請依信中連結設定新密碼。', '重設密碼');
      } catch (err) {
        fail(err instanceof UserError ? err.message : '發生錯誤，請稍後再試。');
      }
    }
  });

  f.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = el.email.value.trim();
    const password = el.password.value;
    if (registering && !el.displayName.value.trim()) return fail('請輸入顯示名稱');
    if (!EMAIL_RE.test(email)) return fail('請輸入有效的 Email');
    if (!password) return fail('請輸入密碼');
    if (registering) {
      const problem = passwordProblem(password);
      if (problem) return fail(problem);
    }
    fail('');
    const btn = f.querySelector('[type="submit"]');
    btn.disabled = true;
    btn.textContent = '處理中…';

    const localCount = store.localCount();
    try {
      if (registering) await cloud.register(email, password, el.displayName.value);
      else await cloud.signIn(email, password);
    } catch (err) {
      fail(err instanceof UserError ? err.message : '發生錯誤，請稍後再試。');
      btn.disabled = false;
      btn.textContent = registering ? '註冊' : '登入';
      return;
    }

    if (localCount > 0) {
      const merge = await confirmDialog({
        title: '合併訪客資料',
        message: `這台裝置上有 ${localCount} 筆以訪客身分建立的訂閱。要把它們加入目前登入的帳號嗎？\n\n` +
          '選擇「先不要」時，資料會保留在這台裝置上，登出後仍可看到。',
        confirm: '合併', cancel: '先不要',
      });
      if (merge) {
        try {
          await store.mergeLocalToCloud();
          toast(`已合併 ${localCount} 筆訂閱`);
        } catch (err) {
          console.error(err);
          alertDialog('合併失敗，資料仍保留在本機，下次登入時可以再試一次。');
        }
      }
    }
    registering = false;
    go('');
  });
}

