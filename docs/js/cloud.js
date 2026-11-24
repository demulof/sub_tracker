// Firebase（登入與雲端資料）。只有在 config.js 填好設定時才會載入 Firebase 套件。
import { FIREBASE_CONFIG } from './config.js';
import { normalize, UserError } from './model.js';

export const cloudEnabled = Boolean(FIREBASE_CONFIG.apiKey && FIREBASE_CONFIG.appId);

const BATCH_LIMIT = 400; // Firestore 單一批次上限 500，保留餘裕。
let fb = null;
let auth = null;
let db = null;

export class AuthError extends UserError {}

/** 初始化 Firebase。成功回傳 true；onUser 會在登入狀態改變時被呼叫。 */
export async function initCloud(onUser) {
  if (!cloudEnabled) {
    onUser(null);
    return false;
  }
  try {
    fb = await import('../vendor/firebase.js');
    const app = fb.initializeApp(FIREBASE_CONFIG);
    auth = fb.initializeAuth(app, {
      persistence: [fb.indexedDBLocalPersistence, fb.browserLocalPersistence],
    });
    // 驗證信、重設密碼信依瀏覽器語言寄送（需維持 Firebase 主控台的預設範本內文）。
    auth.languageCode = navigator.language || 'zh-TW';
    db = fb.initializeFirestore(app, {
      localCache: fb.persistentLocalCache({ tabManager: fb.persistentMultipleTabManager() }),
    });
    fb.onAuthStateChanged(auth, onUser);
    return true;
  } catch (e) {
    console.error('Firebase 初始化失敗', e);
    onUser(null);
    return false;
  }
}

export const currentUser = () => auth?.currentUser ?? null;

// ------------------------------------------------------------------ 帳號

const AUTH_MESSAGES = {
  'auth/invalid-email': 'Email 格式不正確。',
  'auth/user-disabled': '此帳號已被停用。',
  'auth/user-not-found': 'Email 或密碼錯誤。',
  'auth/wrong-password': 'Email 或密碼錯誤。',
  'auth/invalid-credential': 'Email 或密碼錯誤。',
  'auth/invalid-login-credentials': 'Email 或密碼錯誤。',
  'auth/email-already-in-use': '此 Email 已經註冊過，請直接登入。',
  'auth/weak-password': '密碼強度不足，請使用更長且包含英數字的密碼。',
  'auth/password-does-not-meet-requirements': '密碼不符合安全規則，請使用更長且包含英數字的密碼。',
  'auth/too-many-requests': '嘗試次數過多，請稍後再試。',
  'auth/network-request-failed': '網路連線失敗，請檢查網路後再試。',
  'auth/requires-recent-login': '為了安全，請重新輸入密碼後再試一次。',
  'auth/operation-not-allowed': '目前未開放此登入方式。',
  'auth/unauthorized-domain': '這個網址尚未加入 Firebase 的授權網域。',
};

function authError(e) {
  console.warn('Firebase Auth 錯誤', e?.code);
  return new AuthError(AUTH_MESSAGES[e?.code] ?? '發生錯誤，請稍後再試。');
}

function requireCloud() {
  if (!auth) throw new AuthError('尚未設定 Firebase，目前只能使用訪客模式。');
}

export function displayNameOf(user) {
  if (!user) return '訪客';
  if (user.displayName) return user.displayName;
  return user.email?.split('@')[0] ?? '使用者';
}

export async function register(email, password, displayName) {
  requireCloud();
  let cred;
  try {
    cred = await fb.createUserWithEmailAndPassword(auth, email.trim(), password);
  } catch (e) {
    throw authError(e);
  }
  const name = displayName.trim();
  try {
    await fb.updateProfile(cred.user, { displayName: name });
  } catch (e) {
    console.warn('設定顯示名稱失敗', e);
  }
  try {
    // 只存必要欄位；Email 由 Firebase Auth 保管，不在 Firestore 重複儲存。
    await fb.setDoc(fb.doc(db, 'users', cred.user.uid), {
      displayName: name,
      createdAt: fb.serverTimestamp(),
    });
  } catch (e) {
    console.warn('建立使用者資料失敗', e);
  }
  try {
    await fb.sendEmailVerification(cred.user);
  } catch (e) {
    console.warn('寄送驗證信失敗', e);
  }
  await fb.reload(cred.user).catch(() => {});
  return cred.user;
}

export async function signIn(email, password) {
  requireCloud();
  try {
    return (await fb.signInWithEmailAndPassword(auth, email.trim(), password)).user;
  } catch (e) {
    throw authError(e);
  }
}

/** 寄送重設密碼信。為避免洩漏 Email 是否已註冊，找不到帳號時也當作成功。 */
export async function resetPassword(email) {
  requireCloud();
  try {
    await fb.sendPasswordResetEmail(auth, email.trim());
  } catch (e) {
    if (e?.code === 'auth/user-not-found') return;
    throw authError(e);
  }
}

export async function resendVerification() {
  requireCloud();
  try {
    await fb.sendEmailVerification(auth.currentUser);
  } catch (e) {
    throw authError(e);
  }
}

export async function updateDisplayName(name) {
  requireCloud();
  const user = auth.currentUser;
  if (!user) return;
  const trimmed = name.trim();
  try {
    await fb.updateProfile(user, { displayName: trimmed });
  } catch (e) {
    throw authError(e);
  }
  // 以 Firebase Auth 的顯示名稱為準，Firestore 只是備份，同步失敗不影響使用。
  fb.updateDoc(fb.doc(db, 'users', user.uid), { displayName: trimmed }).catch((e) =>
    console.warn('同步顯示名稱失敗', e));
}

export async function signOutUser() {
  if (auth) await fb.signOut(auth);
}

/** 永久刪除帳號：先重新驗證密碼，再刪除雲端資料，最後刪除帳號。 */
export async function deleteAccount(password) {
  requireCloud();
  const user = auth.currentUser;
  if (!user?.email) throw new AuthError('目前沒有登入的帳號。');
  try {
    await fb.reauthenticateWithCredential(user, fb.EmailAuthProvider.credential(user.email, password));
  } catch (e) {
    throw authError(e);
  }
  try {
    await deleteAllData(user.uid);
  } catch (e) {
    console.error('刪除雲端資料失敗', e);
    throw new AuthError('刪除資料時發生錯誤，帳號尚未刪除，請確認網路後再試一次。');
  }
  try {
    await fb.deleteUser(user);
  } catch (e) {
    throw authError(e);
  }
}

// ------------------------------------------------------------------ 訂閱資料

const subsCol = (uid) => fb.collection(db, 'users', uid, 'subscriptions');

function toFirestore(sub) {
  return {
    id: sub.id,
    name: sub.name,
    plan: sub.plan,
    amount: sub.amount,
    currency: sub.currency,
    cycle: sub.cycle,
    firstPaymentDate: fb.Timestamp.fromDate(sub.firstPaymentDate),
    endDate: sub.endDate ? fb.Timestamp.fromDate(sub.endDate) : null,
    brandColor: sub.brandColor >>> 0,
    category: sub.category,
  };
}

/** 即時監聽訂閱列表，回傳取消監聽的函式。 */
export function watchSubscriptions(uid, onData, onError) {
  return fb.onSnapshot(subsCol(uid), (snap) => {
    const list = [];
    snap.forEach((d) => {
      try {
        list.push(normalize(d.data()));
      } catch (e) {
        console.warn('略過格式錯誤的資料', d.id, e);
      }
    });
    onData(list);
  }, onError);
}

/**
 * 離線時寫入會先存進本機快取、連線後才同步，Promise 要等伺服器確認才會完成。
 * 最多等 8 秒：逾時視為已排入同步；伺服器拒絕（例如違反安全規則）的錯誤仍會在時限內拋出。
 */
async function awaitWrite(promise) {
  let timer;
  const timeout = new Promise((resolve) => { timer = setTimeout(resolve, 8000); });
  promise.catch(() => {}); // 逾時後才失敗的情況只記錄在主控台
  try {
    await Promise.race([promise, timeout]);
  } finally {
    clearTimeout(timer);
  }
}

export const saveRemote = (uid, sub) =>
  awaitWrite(fb.setDoc(fb.doc(subsCol(uid), sub.id), toFirestore(sub)));

export const deleteRemote = (uid, id) => awaitWrite(fb.deleteDoc(fb.doc(subsCol(uid), id)));

export async function saveManyRemote(uid, subs) {
  for (let i = 0; i < subs.length; i += BATCH_LIMIT) {
    const batch = fb.writeBatch(db);
    for (const sub of subs.slice(i, i + BATCH_LIMIT)) {
      batch.set(fb.doc(subsCol(uid), sub.id), toFirestore(sub));
    }
    await batch.commit();
  }
}

async function deleteAllData(uid) {
  for (;;) {
    const snap = await fb.getDocs(fb.query(subsCol(uid), fb.limit(BATCH_LIMIT)));
    if (snap.empty) break;
    const batch = fb.writeBatch(db);
    snap.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  await fb.deleteDoc(fb.doc(db, 'users', uid));
}
