// 常用服務的快速新增資料。價格只是參考值，各服務會調價，畫面上會提醒以實際帳單為準。
export const SUGGESTIONS = [
  { name: 'Netflix', native: 'TWD', color: 0xffe50914, category: 'video', plans: [
    { name: '基本', prices: { TWD: 270, USD: 6.99 } },
    { name: '標準', prices: { TWD: 330, USD: 10.99 } },
    { name: '高級', prices: { TWD: 390, USD: 15.99 } },
  ] },
  { name: 'Disney+', native: 'TWD', color: 0xff113ccf, category: 'video', plans: [
    { name: '標準方案', prices: { TWD: 270 } },
    { name: '高級方案', prices: { TWD: 320 } },
  ] },
  { name: 'YouTube', native: 'TWD', color: 0xffff0000, category: 'video', plans: [
    { name: 'Premium 個人', prices: { TWD: 199, USD: 7.99 } },
    { name: 'Premium 家庭', prices: { TWD: 399, USD: 14.99 } },
  ] },
  { name: '動畫瘋', native: 'TWD', color: 0xff00a2e8, category: 'video', plans: [
    { name: '月費方案', prices: { TWD: 99 } },
    { name: '年費方案', prices: { TWD: 990 } },
  ] },
  { name: 'Spotify', native: 'TWD', color: 0xff1db954, category: 'music', plans: [
    { name: 'Individual', prices: { TWD: 149, USD: 5.99 } },
    { name: 'Duo', prices: { TWD: 198, USD: 7.99 } },
    { name: 'Family', prices: { TWD: 268, USD: 9.99 } },
  ] },
  { name: 'KKBOX', native: 'TWD', color: 0xff00acc1, category: 'music', plans: [
    { name: '標準音質', prices: { TWD: 149 } },
    { name: '無損音質', prices: { TWD: 299 } },
  ] },
  { name: 'Apple Music', native: 'TWD', color: 0xfffc3c44, category: 'music', plans: [
    { name: '個人方案', prices: { TWD: 165, USD: 10.99 } },
    { name: '家庭方案', prices: { TWD: 265, USD: 16.99 } },
  ] },
  { name: 'ChatGPT', native: 'USD', color: 0xff74aa9c, category: 'ai', plans: [
    { name: 'Plus', prices: { USD: 20 } },
  ] },
  { name: 'Gemini', native: 'USD', color: 0xff8e44ad, category: 'ai', plans: [
    { name: 'Advanced', prices: { USD: 19.99 } },
  ] },
  { name: 'Claude', native: 'USD', color: 0xffd97757, category: 'ai', plans: [
    { name: 'Pro', prices: { USD: 20 } },
  ] },
  { name: 'Microsoft 365', native: 'TWD', color: 0xff0078d4, category: 'productivity', plans: [
    { name: '個人版', prices: { TWD: 219, USD: 6.99 } },
    { name: '家用版', prices: { TWD: 320, USD: 9.99 } },
  ] },
  { name: 'Google One', native: 'TWD', color: 0xff1976d2, category: 'productivity', plans: [
    { name: '100 GB', prices: { TWD: 65 } },
    { name: '200 GB', prices: { TWD: 90 } },
    { name: '2 TB', prices: { TWD: 330 } },
  ] },
  { name: 'iCloud+', native: 'TWD', color: 0xff7986cb, category: 'productivity', plans: [
    { name: '50 GB', prices: { TWD: 30 } },
    { name: '200 GB', prices: { TWD: 90 } },
    { name: '2 TB', prices: { TWD: 300 } },
  ] },
];

export const findSuggestion = (name) =>
  SUGGESTIONS.find((s) => s.name.toLowerCase() === name.trim().toLowerCase()) ?? null;
