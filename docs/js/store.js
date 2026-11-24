// 資料層：已登入時讀寫 Firestore，訪客時存在這台裝置的 localStorage。
// 畫面只需要 subscribe()，登入、登出時資料來源會自動切換。
import * as cloud from './cloud.js';
import { newId, normalize, toJSON, UserError, validate } from './model.js';

const LOCAL_KEY = 'sub_tracker_local_v1';

const state = {
  /** undefined = 還在確認登入狀態；null = 訪客 */
  user: undefined,
  subs: null,
  error: null,
};
const listeners = new Set();
let stopRemote = null;

export const getState = () => state;
export function subscribe(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}
const emit = () => listeners.forEach((fn) => fn(state));

const byName = (a, b) => a.name.localeCompare(b.name, 'zh-Hant');

// ------------------------------------------------------------------ 本機資料

function loadLocal() {
  try {
    const raw = JSON.parse(localStorage.getItem(LOCAL_KEY) ?? '[]');
    if (!Array.isArray(raw)) return [];
    const list = [];
    for (const item of raw) {
      try {
        list.push(normalize(item));
      } catch (e) {
        console.warn('略過格式錯誤的本機資料', e);
      }
    }
    return list;
  } catch {
    return [];
  }
}

function saveLocal(list) {
  localStorage.setItem(LOCAL_KEY, JSON.stringify(list.map(toJSON)));
  if (!state.user) {
    state.subs = [...list].sort(byName);
    emit();
  }
}

export const localCount = () => loadLocal().length;

// ------------------------------------------------------------------ 登入狀態

/** 由 cloud.initCloud 在登入狀態改變時呼叫。 */
export function setUser(user) {
  const prevUid = state.user?.uid;
  state.user = user;
  if (user && user.uid === prevUid && stopRemote) {
    emit(); // 只是使用者資料（例如顯示名稱）更新
    return;
  }
  stopRemote?.();
  stopRemote = null;
  state.error = null;
  if (user) {
    state.subs = null;
    emit();
    stopRemote = cloud.watchSubscriptions(user.uid, (list) => {
      state.subs = list.sort(byName);
      state.error = null;
      emit();
    }, (e) => {
      // 登出瞬間舊的監聽可能先收到權限錯誤，這時資料來源即將切換，不顯示錯誤。
      if (e?.code === 'permission-denied' && cloud.currentUser()?.uid !== user.uid) return;
      console.error('讀取雲端資料失敗', e);
      state.error = '無法載入雲端資料，請檢查網路連線。';
      emit();
    });
  } else {
    state.subs = loadLocal().sort(byName);
    emit();
  }
}

/** 使用者資料（例如顯示名稱、驗證狀態）在外部更新後，通知畫面重畫。 */
export const refreshUser = () => emit();

// ------------------------------------------------------------------ 寫入

/** 新增或更新。id 為空時視為新增。 */
export async function saveSubscription(sub) {
  const item = sub.id ? sub : { ...sub, id: newId() };
  if (state.user) {
    await cloud.saveRemote(state.user.uid, item);
  } else {
    const list = loadLocal();
    const i = list.findIndex((s) => s.id === item.id);
    if (i >= 0) list[i] = item;
    else list.push(item);
    saveLocal(list);
  }
  return item;
}

export async function deleteSubscription(id) {
  if (state.user) {
    await cloud.deleteRemote(state.user.uid, id);
  } else {
    saveLocal(loadLocal().filter((s) => s.id !== id));
  }
}

/** 把訪客資料上傳到目前登入的帳號，成功後清除本機資料。以相同 id 寫入，重複執行不會產生重複資料。 */
export async function mergeLocalToCloud() {
  if (!state.user) return;
  const local = loadLocal();
  if (local.length === 0) return;
  await cloud.saveManyRemote(state.user.uid, local);
  localStorage.removeItem(LOCAL_KEY);
}

// ------------------------------------------------------------------ 備份

export function exportBackup() {
  return JSON.stringify({
    app: 'sub_tracker',
    version: 1,
    exportedAt: new Date().toISOString(),
    subscriptions: (state.subs ?? []).map(toJSON),
  }, null, 2);
}

/** 匯入備份檔，同一個 id 會覆蓋。回傳匯入筆數。 */
export async function importBackup(text) {
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    throw new UserError('檔案不是有效的備份檔。');
  }
  const raw = Array.isArray(data) ? data : data?.subscriptions;
  if (!Array.isArray(raw)) throw new UserError('檔案裡找不到訂閱資料。');
  const items = [];
  for (const r of raw) {
    try {
      const sub = normalize(r);
      if (!validate(sub)) items.push(sub); // 略過不符合輸入限制的項目
    } catch {
      /* 略過格式錯誤的項目 */
    }
  }
  if (items.length === 0) throw new UserError('檔案裡沒有可以匯入的訂閱資料。');
  if (state.user) {
    await cloud.saveManyRemote(state.user.uid, items);
  } else {
    const map = new Map(loadLocal().map((s) => [s.id, s]));
    items.forEach((s) => map.set(s.id, s));
    saveLocal([...map.values()]);
  }
  return items.length;
}
