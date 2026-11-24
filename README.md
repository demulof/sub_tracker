# 訂閱管家（sub_tracker）

> **網頁版（PWA）**：`docs/` 資料夾是可以直接安裝到手機主畫面的網頁版，不需要上架。
> 設定方式見下方「網頁版（PWA）」一節。Flutter 版的程式碼保留在 `lib/`。

## 網頁版（PWA）

不需要建置工具，`docs/` 裡的檔案就是完整的網站，用 GitHub Pages 發布即可。

### 功能
- 儀表板、新增／編輯／停止／刪除訂閱、統計分析（與 Flutter 版相同的計算規則）。
- 多幣別自動換算、訂閱數量不限。
- **行事曆提醒**：匯出 .ics 檔加入手機行事曆，扣款前一天早上 9 點提醒（網頁版沒有伺服器可以發推播，用行事曆最穩定）。
- **備份**：匯出／匯入 JSON 檔。
- 沒有網路也能開啟（Service Worker 快取）。
- 登入後資料存在 Firebase，與 Flutter 版共用同一份資料；不登入時資料只存在這台裝置的瀏覽器。

### 第一次設定
1. **開啟 GitHub Pages**：GitHub repo → Settings → Pages → Source 選「Deploy from a branch」→ 分支選 `pwa`（或合併後的 `main`）、資料夾選 `/docs` → Save。
   約 1 分鐘後網址會是 `https://demulof.github.io/sub_tracker/`。
2. **註冊 Firebase 網頁應用程式**（要同步資料才需要；只用訪客模式可以跳過）：
   1. Firebase 主控台 → 專案設定 → 一般 → 你的應用程式 →「新增應用程式」→ 選「網頁」（`</>` 圖示）。
   2. 暱稱填「訂閱管家 網頁版」，**不用**勾選 Firebase Hosting → 註冊。
   3. 畫面上會出現 `firebaseConfig`，把 `apiKey` 和 `appId` 填進 `docs/js/config.js`（其他欄位已填好，若不同也一併更新）。
3. **把網址加入授權網域**：Firebase 主控台 → Authentication → 設定 → 授權網域 → 新增 `demulof.github.io`。
4. **部署安全規則**：見下方「部署 Firestore 安全規則」。
5. **限制網頁版 API 金鑰**：Google Cloud 主控台 → API 和服務 → 憑證 → 「Browser key (auto created by Firebase)」→
   應用程式限制選「網站」，加入 `https://demulof.github.io/*`。

### 安裝到 iPhone 主畫面
用 **Safari** 開啟網址 → 下方「分享」→「加入主畫面」。主畫面版本和 Safari 的資料是分開的，安裝後要重新登入一次。

### 修改與更新
- 改完 `docs/` 的檔案推上 GitHub，Pages 會自動更新。
- **有新增或改名檔案時**，要更新 `docs/sw.js` 的檔案清單，並把 `VERSION` 加 1。
- 已安裝的手機會在開啟時於背景下載新版，下一次開啟才會套用。
- 計算邏輯的測試：`cd pwa-tools && npm install && npm test`。
- Firebase 套件已打包在 `docs/vendor/firebase.js`；要升級時改 `pwa-tools/package.json` 的版本後執行 `npm run build`。


記錄各項訂閱服務、提醒即將扣款日，並統計每月與每年支出的 Flutter app。

## 功能

- **儀表板**：本月／本年總支出（外幣換算新台幣）、與上期比較、30 天內即將扣款的項目。
- **訂閱管理**：新增、編輯、刪除；可標記「已停止訂閱」並保留過去的支出紀錄。
- **快速新增**：內建常用服務與方案參考價格（影視、音樂、AI 工具、生產力）。
- **統計分析**：選擇月份查看當月扣款、每月平均成本的分類圓餅圖、各訂閱累計支出。
- **帳號**：Email 註冊登入、Email 驗證、忘記密碼、修改顯示名稱、刪除帳號（含所有雲端資料）。
- **訪客模式**：不登入也能使用，資料存在裝置上；登入時可選擇合併到帳號。

## 架構

| 項目 | 使用技術 |
|---|---|
| 前端 | Flutter（Android、iOS） |
| 登入 | Firebase Authentication（Email／密碼） |
| 雲端資料 | Cloud Firestore：`users/{uid}`、`users/{uid}/subscriptions/{id}` |
| 本機資料 | shared_preferences（訪客模式、匯率快取） |
| 匯率 | [ExchangeRate-API](https://www.exchangerate-api.com) 免費端點，12 小時更新一次 |

```
lib/
├─ config/app_config.dart        上架前要填的設定（隱私權政策網址等）
├─ features/                     各頁面（home、subscriptions、statistics、auth、account）
├─ services/                     資料存取（訂閱、匯率）
└─ shared/
   ├─ billing.dart               扣款日期與金額計算（純函式，有單元測試）
   ├─ models/subscription.dart   資料模型與輸入限制
   └─ widgets/
firestore.rules                  Firestore 安全規則
test/billing_test.dart           計算邏輯的單元測試
```

### 計算規則

- 扣款日每期都從「首次付款日」起算；該月沒有那一天時用月底（1/31 → 2/28 → 3/31）。
- 「停止續訂日」當天（含）之後不再計算扣款。
- 首頁的本月／本年支出是該期間的**實際扣款**，包含本期還沒到的預定款項。
- 統計頁的分類圓餅圖是**每月平均成本**（例如年繳 1,200 元 = 每月 100 元）。
- 外幣一律以目前匯率換算，歷史金額也用目前匯率計算。

## 開發

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### 部署 Firestore 安全規則

規則檔在 `firestore.rules`。修改後執行：

```bash
npm install -g firebase-tools   # 第一次才需要
firebase login
firebase deploy --only firestore:rules
```

> 欄位限制（名稱長度、金額上限、幣別）同時寫在 `firestore.rules` 和
> `lib/shared/models/subscription.dart` 的 `SubscriptionLimits`，修改時兩邊要一起改。

## 上架前檢查清單

### Firebase 主控台
- [ ] 部署 `firestore.rules`（見上方指令），並確認主控台上不是「測試模式」規則。
- [ ] Authentication → 設定：確認已開啟「Email 列舉保護」（Email enumeration protection）。
- [ ] Authentication → 設定 → 密碼政策：可設定最少 8 碼並要求英數字，和 app 內規則一致。
- [ ] Authentication → 範本：把驗證信、重設密碼信的語言改成繁體中文，寄件名稱改成「訂閱管家」。
- [ ] 啟用 App Check（Android 用 Play Integrity、iOS 用 App Attest），降低 API 被濫用的風險。
- [ ] 改用 Blaze 方案並設定預算警示，避免用量超過免費額度時服務中斷。

### Google Cloud 主控台（API 金鑰）
`google-services.json` 與 `firebase_options.dart` 裡的 API 金鑰本來就會打包進 app，不算機密，
但應該到 Google Cloud 主控台 →「API 和服務」→「憑證」限制金鑰：
- [ ] Android 金鑰：限制為 Android 應用程式（套件名稱 + SHA-1 指紋）。
- [ ] iOS 金鑰：限制為 iOS 應用程式（Bundle ID）。
- [ ] 兩把金鑰都限制只能呼叫 Firebase 會用到的 API（Identity Toolkit、Token Service、Cloud Firestore、Firebase Installations 等）。

### 套件名稱（applicationId / Bundle ID）
目前還是預設的 `com.example.sub_tracker`，Google Play 不接受 `com.example` 開頭。
1. 決定正式名稱，例如 `com.<你的名字>.subtracker`。
2. 修改 `android/app/build.gradle.kts` 的 `applicationId` 與 `namespace`，並把
   `android/app/src/main/kotlin/` 下的資料夾路徑和 `MainActivity.kt` 的 `package` 改成相同名稱。
3. iOS：在 Xcode 修改 Runner 的 Bundle Identifier。
4. 執行 `flutterfire configure`，重新產生 `google-services.json` 與 `lib/firebase_options.dart`。

### Android 上架簽章
1. 建立金鑰（只做一次，金鑰和密碼要妥善備份，遺失就無法更新 app）：
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. 建立 `android/key.properties`（已在 `.gitignore`，不會上傳）：
   ```properties
   storePassword=你的密碼
   keyPassword=你的密碼
   keyAlias=upload
   storeFile=/Users/你的帳號/upload-keystore.jks
   ```
3. `flutter build appbundle` 產生 `.aab` 上傳到 Google Play。

### 隱私權政策與商店資料
- [ ] 撰寫並公開隱私權政策（可放在 GitHub Pages），把網址填到 `lib/config/app_config.dart` 的 `privacyPolicyUrl`。
      填好後，登入頁和帳號設定頁會自動出現連結。
- [ ] 政策內容至少要說明：蒐集的資料（Email、顯示名稱、訂閱紀錄）、存放位置（Google Firebase）、
      第三方服務（Firebase、ExchangeRate-API、Google Fonts）、刪除帳號的方式。
- [ ] Google Play「資料安全性」表單、App Store「App 隱私權」問卷依上述內容填寫。
- [ ] Google Play 需要提供「刪除帳號」的網頁說明或連結（app 內已有刪除功能，可在說明頁寫出操作步驟）。

### 其他建議
- [ ] 字型目前由 `google_fonts` 在執行時從網路下載。建議把 Noto Sans TC 字型檔放進 `assets/` 並設定
      `GoogleFonts.config.allowRuntimeFetching = false`，離線也能正常顯示，也少一個第三方連線。
- [ ] 準備 app 圖示（目前是 Flutter 預設圖示），可用 `flutter_launcher_icons` 套件產生。
- [ ] 內建的服務價格會過時，上架前和之後要定期更新 `lib/features/subscriptions/suggestions.dart`。
