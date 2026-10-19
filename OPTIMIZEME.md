# OPTIMIZEME.md — 依賴優化可行性評估

> **更新日期**：2026-08-25
> **更新說明**：本文件基於對 `lib/` 全程式碼庫的**實際 import 掃描**，修正並補充原始套件優化建議。
> **原則**：在不影響用戶體驗、不改變現有 function 與介面的前提下，移除重複與非必要的套件。

---

## 📊 可行性速覽

| 層級 | 動作 | 影響 | 可行性 |
|---|---|---|---|
| 🟢 零風險 | 移除 **11 個「從未使用」的套件**（`cupertino_icons` 因 App 蘋果化重新加入，淨移除 11）| 縮減依賴、降低 APK 體積與編譯時間，**介面與功能完全不變** | **95–100%** |
| 🟡 小幅 | 合併重複的 `TileCacheService` 程式碼 | 減少維護負擔 | **60–80%** |
| 🔴 大工程 | 移除 GetX、合併地圖引擎 | 體積可再降，但改動面廣、回歸風險高 | **25–40%**，列為中長期 |

---

## 一、網路相關（Networking）— ⚠️ 原始建議有誤，已修正

**原始建議**：保留 `dio`、移除 `http` → ❌ **與實際相反**。

**實際掃描結果**：
- `http` 是專案**核心** HTTP 用戶端：整個 `lib/src/generated_api/`（openapi-generator 產生的 API 客戶端）皆以 `http` 產生；另有 **13+ 檔案**直接使用 `http`（tile 快取、通知、模擬器、報告下載、reset password、interceptor…）。
- `dio` 在執行期**完全沒有被使用**。唯一出現處是 `lib/api_generator.dart` 的 codegen 設定（`DioProperties()`），僅影響程式碼產生，不影響執行期。

**✅ 修正後建議（可行）**：
- **移除（0 使用，零風險）**：`dio`、`dio_cookie_manager`、`cookie_jar`、`dio_cache_interceptor_hive_store`、`http_cache_hive_store`、`http_auth`
- **保留**：`http`（核心）
- **補充**：`openapi_generator` / `openapi_generator_annotations` 是 codegen 工具（與 `build_runner` 同類），已確認位於 `dev_dependencies`（正確），無需調整。

---

## 二、狀態管理與架構（State Management）— ⚠️ 原始建議有誤，已修正

**原始建議**：`provider` 或 `get` 擇一移除 → ❌ **`provider` 不可移除**。

**實際掃描結果**：
- `provider` 是**核心狀態管理**：`MultiProvider`、`ChangeNotifierProvider`，**20+ 檔案**使用，無重複。
- `get`（GetX）在此專案**並非狀態管理**，而是**全域路由 + 翻譯層**：`GetMaterialApp`、`Get.to`、`Get.snackbar`、`Get.locale`，以及 **25+ 檔案、數百處 `.tr`** 翻譯呼叫、`LocalizationService extends Translations`（70 個語言檔）。

**✅ 修正後建議**：
- `provider` 保留。
- `get` 移除可行性：**低（25–40%）**。需自建 localization lookup、`GetMaterialApp`→`MaterialApp`、`Get.to`→`Navigator`、`Get.snackbar`→`ScaffoldMessenger`、`Get.locale`→自訂。改動面廣、回歸風險高，**列為中長期重構**，不建議在「介面不變」前提下現在做。

---

## 三、地圖相關（Maps & Location）— 部分有誤，已修正

**原始建議**：`flutter_map` 或 `maplibre_gl` 擇一；`flutter_map_cache` 與 `flutter_map_tile_caching` 擇一。

**實際掃描結果**：
- `flutter_map` + `latlong2`：用於圍欄繪圖/顯示（`geofences_screen.dart`）與 tile 快取。
- `maplibre_gl`：用於即時追蹤地圖（`map_screen.dart`、`livetracking_map_screen.dart`）。
- **兩者皆真的在使用**，且用在不同畫面 → 合併需重寫其中一個地圖引擎，可行性 **25–35%**，不建議現在做。
- **重要**：`flutter_map_cache` 與 `flutter_map_tile_caching` **兩者皆 0 使用**！專案自寫了 Hive 版 tile 快取（`TileCacheService`）→ **可直接移除，零風險**。
- `location`（GPS 定位套件）**0 使用**（僅有 `Icons.location_*` 與 HTTP 地址搜尋，非 GPS）→ **可直接移除**。

**✅ 修正後建議**：
- **移除（0 使用，零風險）**：`flutter_map_cache`、`flutter_map_tile_caching`、`location`
- **保留**：`flutter_map`、`latlong2`、`maplibre_gl`
- **補充**：`TileCacheService` 在 `lib/services/tile_cache_service.dart` 與 `geofences_screen.dart` 內**重複定義**，建議合併成單一 service（維護性改善，非套件問題）。

---

## 四、本地儲存（Storage）— 原始建議不採納

**原始建議**：考慮移除 `shared_preferences`。
**實際**：`shared_preferences` 用於 server URL、語言、主題、marker size 等輕量設定，是最合適的工具。以 sqflite/hive 取代反而更複雜。
**✅ 建議**：`shared_preferences`、`hive`、`sqflite` 三者用途不同且都在使用，**皆保留**。

---

## 五、檔案與文件處理（Excel / CSV）— 原始建議不採納

**原始建議**：若沒用到 CSV 可移除 `csv`。
**實際**：`csv` 與 `excel` **都在使用**（`devices_screen.dart` 的 CSV 與 XLSX 匯出/分享功能）。
**✅ 建議**：兩者**皆保留**。

---

## 💡 總結優化清單（已按實際使用修正）

### 🟢 立即執行（零風險，介面與功能不變）— 可行性 95–100%

| 套件 | 理由 |
|---|---|
| `dio` | 執行期 0 使用（僅 codegen 設定）|
| `dio_cookie_manager` | 0 使用 |
| `cookie_jar` | 0 使用 |
| `dio_cache_interceptor_hive_store` | 0 使用 |
| `http_cache_hive_store` | 0 使用 |
| `http_auth` | 0 使用 |
| `flutter_map_cache` | 0 使用（自寫 Hive 快取）|
| `flutter_map_tile_caching` | 0 使用 |
| `location` | 0 使用 |
| `sliding_up_panel` | 0 使用 |
| `flutter_phoenix` | 0 使用 |
| ~~`cupertino_icons`~~ | ❗ 已於 App 蘋果化（APPLESTYLEME）後重新加入：`CupertinoIcons.*` 字型需要此套件，**不再是冗餘** |

**依賴位置確認**：
- `openapi_generator` / `openapi_generator_annotations` 已正確位於 `dev_dependencies`（codegen 工具，不打包進 app）→ 無需調整

### 🟡 小幅改善（非套件問題）— 可行性 60–80%
- 合併重複的 `TileCacheService`（`services/tile_cache_service.dart` vs `geofences_screen.dart`）

### 🔴 中長期重構（暫不建議）— 可行性 25–40%

| 項目 | 可行性 | 說明 |
|---|---|---|
| 移除 `get`（GetX）| 25–40% | 需重寫導航 + 翻譯層（25+ 檔案、數百處 `.tr`）|
| 合併地圖引擎 | 25–35% | `flutter_map`（圍欄）與 `maplibre_gl`（即時追蹤）皆在使用，合併需重寫其一 |

---

## 附錄：原 main.dart 架構分析（保留）

以下分析仍有效，惟多屬第三層（中長期）範疇：

### 一、移除 GetX，改用原生或更輕量的導航
狀態管理已全面使用 Provider，API 注入、WebSocket 服務也都綁定在 Provider，理論上不需引入 get。
- `GetMaterialApp` → 標準 `MaterialApp`（或 `MaterialApp.router`）
- `Get.offAllNamed('/login')` → `Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false)`
- 語言切換 → 改用 Flutter 官方 `flutter_localizations` 與 `intl`
- **效益**：徹底移除 `get: ^4.7.2`，顯著減少體積
- **可行性：25–40%**（改動面廣，需完整回歸測試）

### 二、減少不必要的重構渲染（Consumer2）
`Consumer2<ThemeProvider, SettingsProvider>` 包裹整個 MaterialApp，任一 Provider 改變會重建整棵樹。
- 建議：`themeMode` 與 `getTheme()` 由 MaterialApp 自身參數監聽；`textScaler` 只包裹需要動態調整字體的區域
- **可行性：中（60–80%）**，效能改善，風險低

### 三、修正靜態實例調用的隱患（TraccarProvider.instance）
`AuthInterceptingClient` 內透過靜態 `TraccarProvider.instance` 更新 session，易破壞 Provider 生命週期管理。
- 建議：以建構子傳入 callback，或改用事件匯流排（Event Bus）
- **可行性：中（60–80%）**，屬程式品質改善

---

## 執行方式
1. 編輯 `pubspec.yaml`：移除上述 🟢 套件（codegen 依賴位置已正確，無需調整）。
2. `flutter pub get`
3. `flutter analyze` 確認無殘留引用。
4. `flutter build apk --debug` 驗證可編譯。

