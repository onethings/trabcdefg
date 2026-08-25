# APPLESTYLEME.md — 整個 APP「蘋果化」（iOS 風格）可行性評估

> **更新日期**：2026-08-25
> **目標**：將整個 App 的介面樣式、風格與 icon 完全「蘋果化」（iOS / Apple 視覺風格）。
> **前提**：不影響既有功能、資料與使用者操作流程，僅改變視覺呈現。

---

## 一、現況盤點（實際統計）

| 項目 | 數量 | 說明 |
|---|---|---|
| `lib/` 下 Dart 檔案 | **201** | 含 screen / widget / provider / service / model |
| `Icons.*`（Material icon）引用 | **265 次 / 149 種** | 分散在各 screen 與 widget |
| `CupertinoIcons.*` 引用 | **0** | 目前完全沒有 iOS 風格元件 |
| `CupertinoApp / CupertinoPageScaffold / CupertinoNavigationBar / CupertinoTabBar` | **0** | 純 Material 3 架構 |

**主要 Material 元件使用量**：

| 元件 | 次數 | | 元件 | 次數 |
|---|---|---|---|---|
| `Scaffold` | 69 | | `SnackBar` | 79 |
| `AppBar` | 57 | | `ElevatedButton` | 35 |
| `ListTile` | 68 | | `TextButton` | 17 |
| `Card` | 56 | | `FloatingActionButton` | 17 |
| `TextField` | 13 | | `showDialog` | 16 |
| `DropdownButton` | 6 | | `showModalBottomSheet` | 6 |
| `Slider` | 4 | | `Checkbox` / `Radio` | 4 / 2 |
| `Switch` | 2 | | `showDatePicker` / `showTimePicker` | 3 / 2 |
| `BottomNavigationBar` | 1 | | `Drawer` | 1 |

---

## 二、三種可行方案與可行性評分

### 方案 A：完全原生 Cupertino 重寫（最徹底的「蘋果化」）
把每一支 screen 的 Material widget 全部替換成 Cupertino 原生元件：
`Scaffold→CupertinoPageScaffold`、`AppBar→CupertinoNavigationBar`、`BottomNavigationBar→CupertinoTabBar`、`ListTile→CupertinoListTile`、`Card→CupertinoListSection`、`TextField→CupertinoTextField`、`Dialog→CupertinoAlertDialog`、`Switch→CupertinoSwitch`、`Button→CupertinoButton`、`Icons.*→CupertinoIcons.*`（265 處）等。

- **優點**：最接近原生 iOS 視覺與互動（含滑動返回、系統感）。
- **缺點**：
  - 幾乎所有 screen（數十至上百個檔）都要重寫，工作量極大。
  - 部分元件**沒有 1:1 對應**：`SnackBar`（Cupertino 無內建）、`DropdownButton`（需改用 `CupertinoPicker`）、表單型 `DatePicker/TimePicker`（需包在 bottom sheet）、自訂 Card 排版、地圖覆蓋層/控制列等，皆需自行兜出近似外觀，**回歸風險高**。
- **可行性**：**20–35%**（以「不影響功能、不改變流程」的前提下）。

### 方案 A 補充：「改用 Cupertino」的實際影響（逐項盤點）

> **重要澄清**：Cupertino **不是第三方 package**，而是 Flutter SDK 內建的 `flutter/cupertino.dart`，**不需安裝任何套件**。所謂「改用 Cupertino」＝把現有 Material widget 逐一改寫成 Cupertino 元件。

**逐項影響（實際統計）**：

| 項目 | 現況 | Cupertino 對應 | 工作量 |
|---|---|---|---|
| `Theme.of(context)` | **197 處 / 26 檔** | `CupertinoTheme.of`（API 完全不同，`colorScheme` 需改寫）| 高 |
| `ScaffoldMessenger` / `SnackBar` | **76 處** | Cupertino 無對應，需自製 overlay | 高 |
| `Scaffold` | 69 | `CupertinoPageScaffold`（無 FAB/Drawer 整合，需另處理）| 中 |
| `AppBar` | 57 | `CupertinoNavigationBar`（大標題需 `CupertinoSliverNavigationBar`）| 中 |
| `ListTile` | 68 | `CupertinoListTile` | 中 |
| `Card` | 56 | `CupertinoListSection` / 自訂 | 中 |
| `TextField` / `TextFormField` | 13 / 27 | `CupertinoTextField`（表單驗證機制需改寫）| 高 |
| `DropdownButtonFormField` | 9 | 需 `CupertinoPicker` + bottom sheet | 高 |
| `IconButton` | 43 | `CupertinoButton` | 中 |
| `showDialog` | 16 | `CupertinoAlertDialog` / 自訂 | 中 |
| `showDatePicker` / `showTimePicker` | 3 / 2 | `CupertinoDatePicker`（需包進 bottom sheet）| 中 |
| `Icons.*` | **265 處 / 149 種** | `CupertinoIcons.*`（約 7–8 成有對應，其餘需自訂）| 中高 |
| 底部導航 | 1（`BottomNavigationBar`）| `CupertinoTabBar` + `CupertinoTabScaffold`（需重整 `MainScreen`）| 中 |
| 主題 | `ThemeData`（Material）| `CupertinoThemeData`（`main.dart`、`ThemeProvider`、26 個檔案需調整）| 高 |

**可行性結論**：
- **全量純 Cupertino 重寫：25–35%** —— 197 處 `Theme.of` + 76 處 `SnackBar` + 大量表單/下拉/日期選擇器是最大障礙，回歸風險高。
- **Cupertino-first 混合（推薦）：55–65%** —— 保留 `GetMaterialApp` + `Scaffold` 殼（維持 `SnackBar`、表單、`Theme.of` 相容），但把視覺主力逐步換成 `CupertinoNavigationBar`、`CupertinoListTile`、`CupertinoButton`、`CupertinoSwitch`、`CupertinoIcons`、iOS 頁面轉場，以低風險替換逼近原生 iOS 外觀。

### 方案 B：保留 Material 引擎，套用「iOS 風格主題」（最推薦的務實做法）
維持 `GetMaterialApp` / `MaterialApp` 與現有 Material widget（架構零變動、零回歸風險），透過 **ThemeData 層**把視覺全面 iOS 化：

1. **iOS 頁面轉場**：`pageTransitionsTheme` 全面改用 `CupertinoPageTransitionsBuilder`（Android/iOS 都變成由右滑入 + 可滑動返回），這是「蘋果感」最有感的單一改動。
2. **iOS 色彩**：套用系統色（藍 `#007AFF`、灰、綠 `#34C759`、橙 `#FF9500`、紅 `#FF3B30`…），分區群組背景（grouped list）風格。
3. **iOS 字型**：iOS 裝置預設即為 SF Pro（Flutter 自動使用系統字型）；Android 上無法合法打包 SF Pro，可選用近似字型（如 Inter）或維持系統預設。
4. **iOS 細節**：扁平化（無 elevation 陰影）、圓角大卡片、置中標題 AppBar（已是 `centerTitle`）、`CupertinoSwitch` 樣式、SegmentedControl 取代部分篩選、`CupertinoIcons` 局部替換最顯眼的 icon（底部導航、AppBar 返回鍵等）。
5. **選用**：常用互動（SnackBar、Dialog、Button）可逐步換成 Cupertino 樣式。

- **優點**：成本低、風險低，約 1–3 天可完成視覺 80% 的「蘋果感」；結構與功能完全不動。
- **缺點**：底層仍是 Material 渲染，並非「100% 原生」，但外觀上一般使用者無法分辨。
- **可行性**：**80–90%**。

### 方案 C：漸進式混合（分階段落地）
- **Phase 1**（1–2 天）：iOS 頁面轉場 + iOS 色彩主題 + 字型 + 扁平化 → 立即有感。
- **Phase 2**（3–5 天）：底部導航 `CupertinoTabBar`、主要 AppBar 換 `CupertinoNavigationBar`、常用 `Icons.*→CupertinoIcons.*` 對應、iOS 風格 Dialog/Button/Switch。
- **Phase 3**（可選，1–2 週）：最常使用的畫面（裝置列表、地圖、設定）改寫為 Cupertino 原生；其餘維持。
- **可行性**：整體 **60–70%**；每個 Phase 獨立驗證、可隨時停止，風險可控。

---

## 三、方案比較

| 面向 | A 完全原生 | B iOS 風格主題 | C 漸進式 |
|---|---|---|---|
| 蘋果視覺完成度 | 100% | ~80% | ~85–100% |
| 工作量 | 數週以上 | 1–3 天 | 分階段數天~兩週 |
| 回歸風險 | 高 | 極低 | 中（可控）|
| 維護成本 | 高 | 低 | 中 |
| **可行性** | **20–35%** | **80–90%** ⭐ | **60–70%** |

---

## 四、關鍵限制與提醒

1. **SF Pro 授權**：SF Pro 不可在 App 內隨意打包分發；iOS 上系統自動使用，Android 上僅能選近似字型。
2. **icon 更換**：265 處 `Icons.*` 並非全部有對應的 `CupertinoIcons`（部分需自訂），建議只換「有乾淨對應」的部分。
3. **無 1:1 對應的元件**：`SnackBar`、`DropdownButton`、表單 Date/Time Picker 等需自行設計近似 UI。
4. **地圖**：`maplibre_gl` / `flutter_map` 為跨平台引擎，其控制列、圖例需人工做 iOS 樣式。
5. **目前以 Android 為主要目標平台**（workspace 僅含 `android/`），「蘋果化」是指**在 Android 上呈現 iOS 風格**的視覺主題，與平台無關。

---

## 五、建議結論

**以「方案 B（iOS 風格主題）」為首選**：花費最低、風險最低，即可獲得 80% 的蘋果視覺感受，且完全不影響功能與操作流程；若日後想要更進一步，再以「方案 C」階段性替換關鍵畫面。

> 附：若「蘋果化」目標僅是「看起來像 iOS」，方案 B 已足夠；若要求「每個 widget 都是原生 Cupertino」，則需接受方案 A 的高成本與高風險。

---

## 六、方案 B 實作進度（逐步更新）

| 狀態 | 項目 | 內容 |
|---|---|---|
| ✅ 完成 | Step 1：iOS 頁面轉場 | `pageTransitionsTheme` 全面改用 `CupertinoPageTransitionsBuilder`（全平台）|
| ✅ 完成 | Step 1：iOS 系統色 | 新增 `iosTheme` preset，套用官方 HIG 色票（背景/標籤/灰階/分隔線/系統色），**並設為預設主題** |
| ✅ 完成 | Step 2：SF Pro 字體階層 | `iosTheme.textTheme` 套用 iOS 字型階層（34/28/24/22/20/17/16/13/12/11）|
| ✅ 完成 | Step 3：iOS 控制元件 | `switchTheme` 綠色軌道 + 白色圓鈕（iOS Toggle）|
| ✅ 完成 | Step 4：icon 蘋果化 | **全部畫面**的常用 icon 已替換為 `CupertinoIcons.*`（主導航、裝置列表/詳情、即時追蹤、儀表板、設定、報告、通知、指令、CRUD 管理畫面、分享裝置等）；已加入 `cupertino_icons: ^1.0.9` 依賴。僅剩少數**無乾淨對應**的特化 icon（地圖圖層、`route`、`satellite_alt`、密碼可見性等）刻意保留 Material |
| ✅ 完成 | Step 5：導航與 AppBar | ✅ 底部導航 `CupertinoTabBar`；✅ **AppBar → `CupertinoNavigationBar`**（57 處中 49 處已轉換，含 actions→trailing）。**8 處例外保留 Material AppBar**（含 `bottom:` 搜尋列、`flexibleSpace:` 漸層、地圖覆蓋層、geofences 複雜雙動作）|
| 🔄 部分完成 | Step 6：表單/互動 | ✅ **Dialog 全數 iOS 化**：5 個確認型 → `CupertinoAlertDialog`；9 個複雜型（列表/單選/說明）→ `showCupertinoModalPopup` 底部彈出；刪除帳號 → `CupertinoAlertDialog`；✅ **Date/Time Picker → iOS 滾輪**（`cupertino_pickers.dart`，5 處）；✅ **Switch → `CupertinoSwitch`**（2 處）；⏳ 例外：`history_route` 自訂 `TableCalendar` 保留 Material；表單按鈕已由主題 iOS 化 |

**SF Pro 字體階層（已應用於 `iosTheme`）**：

| iOS 名稱 | 大小 | 字重 | Flutter `TextTheme` |
|---|---|---|---|
| LargeTitle | 34 | Bold (700) | `displayLarge` |
| Title 1 | 28 | Bold (700) | `headlineMedium` |
| Title 2 | 22 | Bold (700) | `titleLarge` |
| Title 3 | 20 | Semibold (600) | `titleMedium` |
| Headline | 17 | Semibold (600) | `titleSmall` |
| Body | 17 | Regular (400) | `bodyLarge` |
| Callout | 16 | Regular (400) | `bodyMedium` |
| Footnote | 13 | Regular (400) | `bodySmall` |
| Caption 1 | 12 | Medium (500) | `labelMedium` |
| Caption 2 | 11 | Regular (400) | `labelSmall` |

> 字型備註：iOS 裝置上 Flutter 自動使用系統 SF Pro；Android 無法合法打包 SF Pro，會以系統預設字型（Roboto）呈現相同大小/字重。

**SF Symbols（icon）說明**：
- Apple 官方 SF Symbols 共有 **1569 種**圖示。
- Flutter 內建的 **`CupertinoIcons`** 是對應 SF Symbols 的精選子集（數百種），可免費直接使用，足以覆蓋本 App 常見的 265 處 `Icons.*` 中約 7–8 成。
- 若要完整使用 1569 種，需自行帶入 SF Symbols 資源（字型/圖檔），會增加體積與授權處理，**不建議**；以 `CupertinoIcons` 為主即可。
