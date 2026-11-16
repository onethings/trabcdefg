# SIMPLEMODEME.md：簡易模式（Simple Mode）分析與實作計畫

> 文件性質：設計分析與實作紀錄，不是 API 規格。
> 適用範圍：Trabcdefg（Flutter 跨平台 Traccar 客戶端）。所有行號引用都對應本次盤點的 `lib/` 內容。
> 關聯文件：`APPDESIGNME.md`（設計準則）、`OPTIMIZEME.md`（效能優化）、`APPLESTYLEME.md`（視覺風格）。
> 更新日期：2026-11-16。

---

**目標重述。** 在設定頁新增一個可持久化的 Simple Mode（簡易模式）開關。開啟後，介面只留下年長使用者真正需要的操作，非必要按鍵一律不出現。現有功能不能被拿掉，關掉簡易模式後所有畫面要回到原狀。你另外指定：地圖詳細面板裡的「刪除設備」按鈕在簡易模式下要藏起來，看不到也刪不了。

**一句結論。** 這個 App 的「按鍵太多」問題集中在四個表面：設定頁的 10 個管理入口、裝置列表的篩選列與工具列、地圖右上角的 5 個玻璃按鈕、以及地圖詳細面板的 6 個動作按鈕。簡易模式只要過濾這四處，加上把字級與圖示大小兩項既有設定暴露在同一區塊，就能讓年長使用者只看到「車在哪、車況如何、怎麼切換」，而不必學新流程。

---

## 1 為什麼需要簡易模式

- 現有介面是為「車隊管理者」設計的。`device_list_screen.dart` 一開頭就有搜尋框、5 個篩選 chip、里程量測開關與通知鈴；`settings_screen.dart` 列出 10 個裝置管理入口；`map_screen.dart` 右上角疊了 5 個圖示按鈕。每一項對管理員都合理，對長輩都是要猜的圖示。
- 這個 App 已經有「放大字級」與「放大地圖圖標」兩個無障礙設定（`lib/providers/settings_provider.dart` 的 `fontSizeScale`、`markerSizeScale`），但沒有「減少選項」的設定。字放大之後按鍵不會變少，擁擠感反而更明顯。簡易模式補的就是這一塊。
- 使用者是「幫長輩裝好、偶爾回來設定的晚輩」。長輩本身不會進設定頁調參數，所以簡易模式必須是一個開關，預設關閉，由晚輩一次設定好。

## 2 設計原則

以下每一條都對應後面的實作決策。

1. **只過濾，不刪功能。** 除了你指定的「刪除設備」按鈕，簡易模式只決定元件出不出的來。所有底層能力（存檔、API、資料模型）不動，關閉開關後完整介面復原。這是「不改變現有功能」的可逆做法。
2. **一條判準決定什麼留下。** 「這個控制項是在回答『車在哪、車況如何』，還是在改資料、改顯示、進管理頁？」前者留下，後者隱藏。直覺、可稽核，新畫面也能照同一條判準分類。
3. **按鍵變少優先於功能變少。** 長按手勢（卡片長按選單）不是可見按鍵，簡易模式保留導航這類作用，但不額外畫出任何按鈕。
4. **預設關閉、狀態持久化、單一真相。** 開關狀態存在既有的設定儲存層，所有畫面從同一個 `SettingsProvider` 讀，不各自記一份。
5. **不新增畫面、不改資料模型、不動 API。** 只動既有 Widget 的條件渲染。

## 3 現況盤點與分級

每個畫面列出目前可見的控制項，以及簡易模式下的去留。「進階」表示簡易模式下不渲染。

### 3.1 底部導覽（`lib/screens/main_screen.dart`）

- 裝置列表、地圖、設定三個分頁：**核心**。簡易模式不動分頁結構，這樣長輩學會的入口永遠不變。

### 3.2 裝置列表（`lib/screens/device_list_screen.dart`）

| 控制項 | 位置 | 分級 |
| --- | --- | --- |
| 搜尋框 | `_buildSearchBar` | 核心 |
| 狀態篩選 chips（全部、上線、離線、未知、我的最愛） | `_buildFilterAndToggle` | 進階 |
| 里程量測開關按鈕 | `_buildSearchBar` 的 `_toggleMileage` | 進階 |
| 里程天數選單 | `_buildSearchBar` 的 `PopupMenuButton` | 進階 |
| 通知鈴鐺 | `_buildSearchBar` 尾端 | 進階 |
| 卡片上的愛心（我的最愛） | `_buildDeviceCard` | 進階 |
| 卡片點擊（聚焦地圖） | `onTap` | 核心 |
| 卡片長按選單：導航、分享、下指令 | `_showCardActions` | 導航核心，分享與下指令進階 |

判準應用：搜尋在裝置很多時是「找車」的必需手段，留下；篩選 chip 只是搜尋的替代形式，重複了搜尋，隱藏。里程量測是報表功能的前哨，屬於改顯示，隱藏，但卡片上的里程徽章不會消失（既有偏好值仍生效）。

### 3.3 地圖（`lib/screens/map_screen.dart`）

| 控制項 | 位置 | 分級 |
| --- | --- | --- |
| 右上角：圖層切換 | `Positioned` 內 `_GlassIconButton` | 進階 |
| 右上角：指北針 | 同上 | 進階 |
| 右上角：跟隨裝置 | 同上 | 核心 |
| 右上角：自動縮放到全部裝置 | 同上 | 進階 |
| 右上角：裝置清單（無障礙面板） | 同上 | 核心 |
| 底部：定位、放大、縮小 | `_buildBottomControls` | 核心 |
| 底部：裝置切換列（上一台、下一台、車牌） | `_DeviceSwitcherBar` | 核心 |
| 抽屜：搜尋裝置 | `_buildDeviceListDrawer` | 核心 |
| 抽屜：排序選單 | `_buildDeviceListDrawer` 的 `PopupMenuButton` | 進階 |
| 「回到跟隨」浮動提示 | `_showReturnToFollow` | 核心 |

判準應用：地圖的核心任務是「找到車、看它在哪」。手指縮放比按鈕更自然，但年長使用者常用按鈕，所以放大縮小留下。圖層、指北針、全部縮放是專業操作，隱藏。

### 3.4 地圖詳細面板（`lib/widgets/device_detail_panel.dart`）

| 控制項 | 位置 | 分級 |
| --- | --- | --- |
| 名稱、時間、狀態格、地址 | 面板主體 | 核心 |
| 里程報表（`route_rounded` 圖示） | `_buildHeaderActionIcons` | 進階 |
| 重新整理 | 同上 | 核心 |
| 我的最愛愛心 | 同上 | 進階 |
| 展開、收合動作列（chevron） | 同上 | 進階 |
| 動作列：導航、資訊、指令、更多、編輯、刪除 | `_buildAppleActionButtons` | 動作列整體進階；導航例外，簡易模式改為面板底部的大按鍵 |

**你指定的例外。** 刪除設備按鈕在簡易模式下看不到也按不到：整條動作列不渲染，刪除按鈕就在其中，沒有先展開再誤按的路徑。重新整理按鈕留下，它只讀不寫。

**導航例外。** 導航是回答「怎麼去車子那裡」的核心動作（`_navigateToGoogleMaps` 開 Google 或 Apple Maps），所以簡易模式把它單獨拉出來，做成地址列下方一顆全寬、高 52、圓角 16 的大按鍵，文字用既有 `actionNavigate` 鍵。它不經過展開動作列，長輩一步就能按到。

### 3.5 設定（`lib/screens/settings/settings_screen.dart`）

| 控制項 | 分級 |
| --- | --- |
| 搜尋框 | 核心 |
| **簡易模式開關（新）** | 核心 |
| 報表入口 | 進階 |
| 語言、主題、字級、圖標大小 | 核心 |
| 通知、編輯帳號 | 核心 |
| 裝置列表（新增、修改） | 核心 |
| 地理圍欄、群組、司機、行事曆、計算屬性、保養、常用指令、伺服器資訊、模擬器 | 進階 |
| 登出 | 核心 |
| 版本、伺服器資訊卡片 | 核心 |
| 檢查更新（版本卡右上文字按鈕） | 進階 |

判準應用：語言與字級是長輩真正會用的設定（字太小、看不懂英文），必須留在畫面上；報表與 9 個管理入口是給管理員的，全部隱藏。帳號相關（通知、編輯帳號）留下，因為報警設定與密碼遺失是實際會遇到的狀況。版本卡片留著，但檢查更新是進階。

### 3.6 本次不處理的頁面（列出，避免誤以為漏做）

下列頁面簡易模式下仍可經由長按手勢或關閉簡易模式到達，本次不改，列進第 8 節候選：

- 通知中心與通知設定（`lib/screens/notifications_screen.dart`、`lib/screens/settings/notification_page.dart`）
- 報表全家（`lib/screens/reports/`）
- 指令頁（`lib/screens/command_screen.dart`）
- 裝置詳細頁（`lib/screens/device_details_screen.dart`）
- 月里程與軌跡（`lib/screens/monthly_mileage_screen.dart`、`lib/screens/history_route_screen.dart`）
- 分享裝置（`lib/screens/share_device_screen.dart`）
- 登入、註冊、忘記密碼（前置流程，與是否登入後的介面無關）

另記：`lib/screens/home/dashboard_screen.dart` 目前沒有任何 import 引用（grep 全 `lib/` 零命中），屬於未接線的頁面，不在簡易模式範圍。

## 4 資料形狀與機制

### 4.1 設定值

簡易模式是「單一布林顯示偏好」。資料形狀照既有模式走，不新增儲存層：

- 存放：`SettingsDatabaseHelper` 的 `app_settings` 表（`key TEXT PRIMARY KEY, value REAL`）。布林值以 `1.0`、`0.0` 存。新增 `saveFlag`、`getFlag` 兩個薄包裝，讓呼叫端不必知道這件事。
- 記憶體：`SettingsProvider.simpleMode`（`ChangeNotifier`），啟動時在 `_loadSettings` 讀取，預設 `false`。
- 讀不到值時預設關閉。既有使用者升級後看到的還是完整介面，沒有遷移風險。
- 字級與圖標：開啟時把使用者原本的倍率記進 `simple_mode_prev_font_scale`、`simple_mode_prev_marker_scale`，套用大級預設（字級 1.4、圖標 2.0，值與設定頁的大級選項一致）；關閉時原樣還原。這讓「一鍵」成立，又不會永久改掉使用者自己調過的數字。

### 4.2 共用機制

新增 `lib/widgets/simple_mode.dart`：

- `AdvancedOnly`：包裹元件，簡易模式開啟時渲染 `SizedBox.shrink()`，關閉時渲染子元件。元件名稱就是規則，看程式碼不用回頭翻文件。
- `isSimpleMode(context)`：在 build 內取得布林值的輔助函式。

所有畫面透過 `context.watch<SettingsProvider>()` 訂閱，開關一開一關，正在顯示的頁面立刻重建。旗標在 `main.dart` 的 root `Consumer2` 也在監聽，所以持久化切換不會出現要重開 App 才生效。

### 4.3 為什麼不用 data-driven 的「頁面政策表」

可以做成 `Set<SimpleModeFlag>` 或 enum 表，但目前只有四個頁面、一個布林旗標。多加一層表只是多一個要同步的地方，違反最小改動原則。等第 8 節的多頁面階段真的需要「哪個頁面藏哪些元素」時再抽表，屆時 `AdvancedOnly` 的呼叫點就是現成的盤點清單。

## 5 實作計畫（Phase 1）

1. `lib/storage/settings_database_helper.dart`：新增 `saveFlag`、`getFlag`。
2. `lib/providers/settings_provider.dart`：新增 `simpleMode` 欄位、getter、`setSimpleMode`，並在 `_loadSettings` 讀取；`setSimpleMode` 一併記住與還原字級、圖標倍率（大級預設 1.4、2.0）。
3. `lib/widgets/simple_mode.dart`：新增 `AdvancedOnly` 與 `isSimpleMode`。
4. `lib/screens/settings/settings_screen.dart`：新增「簡易模式」區塊與開關；簡易模式下隱藏報表區塊、9 個管理入口、檢查更新按鈕；搜尋比對加入新標題。
5. `lib/screens/device_list_screen.dart`：隱藏篩選 chips、里程開關、里程天數選單、通知鈴、愛心；長按選單保留導航，隱藏分享與下指令。
6. `lib/screens/map_screen.dart`：右上角只留「跟隨裝置」與「裝置清單」；抽屜隱藏排序選單。
7. `lib/widgets/device_detail_panel.dart`：簡易模式下動作列整條不渲染（含刪除）、里程與愛心與展開 chevron 不渲染，只留重新整理；另在地址列下方加一顆大導航按鍵（`_buildSimpleNavigateButton`）。
8. `lib/l10n/`：`en_us`、`zh_tw`、`zh`、`ja`、`ko`、`th`、`my` 七個完整語系加入 `settingsSimpleMode` 與 `settingsSimpleModeHint` 兩個鍵；其餘 51 個語系沿用 GetX 的 en_US 回退（與 `settingsSearchHint` 等近期鍵的既有做法一致）。
9. 本文件同步更新。

實作順序照上述步驟，每一步都跑 `dart analyze`，最後跑既有測試（`test/l10n_keys_test.dart` 會驗證新鍵存在於 `en_us`）。

## 6 取捨與風險

- **長按手勢是隱性能力。** 簡易模式下卡片長按仍可導航，地圖詳細面板仍可重新整理。這讓「不改變功能」成立，但長輩自己不會發現。若你要求「長輩只靠看得見的按鍵」就能導航，第 8 節第一項就是這件事。
- **搜尋可能顯示「被藏起來的入口」。** 簡易模式下搜尋「報表」，設定頁不會出現任何結果。這是預期行為，代表入口被過濾，不是壞掉。文件已記。
- **刪除是唯一從元件樹消失的功能入口。** 這是你明確要求的取捨。復原路徑是關掉簡易模式；資料本身不受影響。
- **語系落後。** 新鍵只進 7 個完整語系。其餘語系顯示英文，和本專案目前的翻譯維護模式一致，不影響正確性。
- **系統字級疊加。** 簡易模式會把字級套成 1.4、圖標 2.0。若使用者在簡易模式期間又手動調字級，關閉時會回到開啟前的原值，不是他後來調的數字。語系、行為與說明文字都照此寫，文件已記。

## 7 驗證方式與結果

- 靜態：`dart analyze` 於工作區根目錄（本沙盒不能寫 Flutter SDK 快取，用 SDK 內的 Dart 直接跑）。結果：0 error、0 warning，僅有既有程式碼的 deprecation info。
- 翻譯鍵：本沙盒跑不了 `flutter test`（Flutter 工具寫 SDK 快取被沙盒擋住），改用與 `test/l10n_keys_test.dart` 相同規則的純 Dart 腳本檢查 `lib/` 全部 `.tr` 鍵。結果：全部鍵都在 `en_us`，沒有句子式 key，`trParams` 佔位符一致。腳本是臨時檔，驗證後刪除。
- 未在實機驗證（需要 `flutter run` 或真機）：開關切換後各頁面即時重建的行為，本次以程式結構與 `context.watch` 訂閱關係推論，屬推論級。
- 手動矩陣（待實機跑一次）：
  - 設定頁：簡易模式區塊出現、開關能保存；開啟後全 App 字級變大、地圖圖標變大；關掉後報表與 9 個入口回來，字級與圖標回到原值。
  - 裝置列表：開關開啟後只剩搜尋框與卡片；卡片只剩名稱、狀態、地址、時間。
  - 地圖：右上角只剩兩個圖示；抽屜沒有排序選單；詳細面板沒有刪除、編輯、指令、愛心、chevron，只剩重新整理與一顆全寬導航鍵。
  - 重開 App：開關狀態保留。

## 8 Phase 2 候選（本次不做）

1. ~~把「導航」變成詳細面板唯一的大按鍵。~~ 已完成，見 §3.4 導航例外。
2. 通知中心與通知設定頁的內容分級。使用者決定保留現狀，簡易模式下照常運作（2026-11-16）。
3. 裝置詳細頁、指令頁、月里程與軌跡頁的內容分級。
4. ~~設定頁「簡易模式 + 字級大 + 圖標大」一鍵組合。~~ 已完成：開關同時套用字級 1.4 與圖標 2.0，並記住原值。
5. 首次啟用引導：開關旁一句說明「適合不熟悉智慧手機的家人」。
6. 報表入口。使用者決定保留現狀：簡易模式下維持隱藏，關掉簡易模式即恢復（2026-11-16）。

## 9 不做的事

- 不新增任何畫面或路由。
- 不改資料模型、API 或儲存表結構。
- 不改底部導覽的分頁數量。
- 不改正常模式的任何像素。所有變更都在 `simpleMode == true` 的條件內。
