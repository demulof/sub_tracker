// ============================================================================
// Firebase 網頁版設定
// 到 Firebase 主控台 → 專案設定 → 一般 → 你的應用程式 → 新增「網頁」應用程式，
// 把畫面上 firebaseConfig 的內容貼到下面。這些值會出現在網頁原始碼裡，本來就不是機密，
// 資料安全靠的是 Firestore 安全規則（firestore.rules）。
// apiKey 留空時，app 只能用訪客模式（資料只存在這台裝置的瀏覽器裡）。
// ============================================================================
export const FIREBASE_CONFIG = {
  apiKey: '',
  authDomain: 'sub-tracker-982e6.firebaseapp.com',
  projectId: 'sub-tracker-982e6',
  storageBucket: 'sub-tracker-982e6.firebasestorage.app',
  messagingSenderId: '1050375587944',
  appId: '',
};

export const APP_NAME = '訂閱管家';

/** 匯率來源：ExchangeRate-API 免費端點（以 TWD 為基準）。使用條款要求標示來源。 */
export const RATE_ENDPOINT = 'https://open.er-api.com/v6/latest/TWD';
export const RATE_ATTRIBUTION = 'Rates By Exchange Rate API (exchangerate-api.com)';
