# APPDESIGNME.md：以 Apple 人本設計打磨 Traccar 客戶端的使用者體驗

> **文件性質**：設計準則與改善提案，不是程式碼規格。
> **適用範圍**：Trabcdefg（Flutter 跨平台 Traccar 客戶端，Android 為主要目標平台，含 iOS / macOS 桌面建置）。功能涵蓋即時地圖追蹤、車隊列表、警報通知、歷史軌跡、報表、裝置與伺服器管理。
> **依據**：本文件基於 `lib/` 全程式碼庫的實際盤點（畫面、元件、狀態流），對照 Apple 官方《設計原則》（2026 HIG，見附錄 D 原文）與 Apple 人本設計四核心原則撰寫。每一項現況落差都可回溯到檔案位置。
> **關聯文件**：`APPLESTYLEME.md`（iOS 視覺蘋果化進度）、`OPTIMIZEME.md`（依賴與體積優化）。
>
> **更新日期**：2026-11-15（本次首版盤點；改善進度請在第七節更新狀態）

---

## before edit

## 0. 簡版摘要

本文件回答一個問題：**這個 App 怎麼做到「簡單、易用、超流暢」？**

答案分三層：

1. **產品層**：把「車隊即時狀態」當唯一主角，所有畫面圍繞它。用得少的設定往下沉，用得多的資訊往上浮。
2. **互動層**：每個資料畫面都有載入、空、錯誤三態；每個操作 500ms 內有回饋；破壞性動作先確認；地圖與列表只有一套手勢語言。
3. **感知層**：iOS 視覺骨架已在（見 `APPLESTYLEME.md`）。剩下的是把「像 iOS」升級成「用起來順」，動效、觸覺、連線狀態與無障礙補齊。

詳細提案從第七節開始，先看第十二節驗收清單最快。

---

## 1. 使用者與核心任務

App 服務三種人。同一套介面要同時讓三位使用者覺得「一眼就懂」。

| 使用者               | 情境                               | 一次開 App 要完成的任務              |
| -------------------- | ---------------------------------- | ------------------------------------ |
| 車隊管理者           | 辦公室或外出，管理數十台車         | 掌握全部車輛現況，找出離線或停滯的車 |
| 調度／客服           | 接到電話要回報「車在哪、什麼狀態」 | 三步內回答位置、速度、地址           |
| 車主（單車或少數車） | 查看自家車，偶爾回看行車紀錄       | 定位愛車、回放當日路線               |

**核心任務優先序**（做功能決策時先問這一題）：

1. **一眼掌握車隊現況**：線上／離線／警報，最好在 3 秒內完成。
2. **找到一台車並看清狀態**：從列表到某台車的位置，點擊次數不超過 2 次。
3. **處理值得處理的事**：警報、通知、歷史軌跡。事件有輕重，先讓重要的浮出來。
4. **產出報表**：週期性 deliverables，需要可靠、可匯出。
5. **管理設定**：裝置、司機、群組、圍欄等，頻率低但不可出錯。

**設計 KPI**（可以直接量）：

- 冷啟動到「我的車隊現在怎麼樣」可讀，小於 3 秒。
- 從任意畫面到「某台車的即時位置」，小於 2 次點擊。
- 每一次使用者動作，500 毫秒內要有可見回饋（載入、成功或錯誤）。
- 清單層級的資料更新不觸發整頁骨架，只更新變化處。

---

## 2. Apple 平台設計原則（八大原則）與本 App 的對應

Apple 現行《設計原則》有八條（原文見附錄 D）。每一條都是取捨工具，不是裝飾。以下把八原則翻譯成這個 App 的具體檢查點。

| 原則       | 一句話                               | 本 App 的檢查點                                                          | 現況                                                                                                                   |
| ---------- | ------------------------------------ | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| **目標感** | 創造有意義的產品，先問「用途是什麼」 | 開 App 第一屏回答「車隊現在怎麼樣」；主導航只有車隊、地圖、設定三件事    | ✅ 三 tab 已對準核心任務；但 dashboard 與 device list 的數字邏輯不一致（見 3.1）                                       |
| **能動性** | 讓用戶自由使用，不擋路，誤操作可恢復 | 任何步驟可跳過或退出；危險動作可撤銷或至少先確認；不把使用者困在特定流程 | ⚠️ 登出一鍵執行不可恢復（`settings_screen.dart:660`）；誤觸無 undo                                                     |
| **責任感** | 以用戶最佳利益為核心，透明、保護隱私 | 請求權限前說明用途；失敗時講清楚資料有沒有存；收集的資料用途可見         | ⚠️ 通知權限沒有前置說明；錯誤訊息裸露 exception（`command_screen.dart` 等）                                            |
| **熟悉感** | 基於既有認知與平台慣例               | Cupertino 導覽、滑動返回、grouped list；同一 App 內 icon 與回饋一致      | ✅ 轉場已統一；⚠️ 36 檔用 Cupertino 導覽、9 檔用 Material AppBar；icon 語意不一致                                      |
| **靈活**   | 適應各種情境、裝置與輸入方式         | 動態字體、RTL、深色模式、不同螢幕尺寸；鍵盤與語音                        | ⚠️ App 內字體滑桿已接，但系統動態字體被忽略（`main.dart:140` 直接 `TextScaler.linear`）；RTL 未處理；Semantics 僅 2 處 |
| **簡潔**   | 清晰直接，每個元素各得其所           | 一屏一主任務；不堆疊資訊；卡片只留去地圖後才補充的細節                   | ⚠️ 裝置卡塞名稱、狀態、收藏、速度、里程、地址、屬性 chip 七種資訊                                                      |
| **匠心**   | 重視細節，品質奠定基調               | 載入不跳動、數字有動效、間距 8pt 網格、字階統一                          | ⚠️ 169 處硬編碼 `fontSize`（最小 9–11px）；39 處裸 spinner                                                             |
| **愉悅感** | 融入人文關懷，但別蓋過任務           | 追蹤切換有觸覺、完成匯出有輕快確認、空狀態有人味                         | ⚠️ 觸覺全集中在 `map_screen.dart` 的三個位置；多數可互動元素按下無回饋                                                 |

八原則對應到本文的具體工作，方便你按原則挑選要做的項目：

| 原則   | 對應的章節與改善項目                                                                  |
| ------ | ------------------------------------------------------------------------------------- |
| 目標感 | 第一節核心任務；P0-4 數字同源；P1-1 地圖導航統一                                      |
| 能動性 | P0-2 空狀態帶下一步；P0-5 登出確認；P1-11 離線佇列（中斷可恢復）                      |
| 責任感 | P0-3 統一回饋；P0-8 地圖空白世界防護；P1-6 連線狀態；P1-11 離線佇列；第 10 節信任清單 |
| 熟悉感 | P0-6 觸控靶心；P0-7 硬編碼字串歸位；P1-10 語系補齊；第 11 節 tokens                   |
| 靈活   | P1-9 動態字體銜接系統；第 9 節無障礙清單                                              |
| 簡潔   | P0-1 骨架屏；P1-3 卡片收斂(不要動到地址)；P1-8 設定搜尋                               |
| 匠心   | P0-1 骨架屏；第 8 節動效與觸覺 tokens；第 11 節 design tokens                         |
| 愉悅感 | P1-2 追蹤視覺回饋；P1-5 播放器觸覺與時間軸；第 8 節觸覺映射                           |

---

## 3. Apple 人本設計四核心原則的落地

設計應以人為本，服務需求，而不是外觀漂亮或功能堆砌。以下四原則取自 Apple 的 HIG 精神，逐一落到本 App。

### 3.1 清晰（Clarity）

文字在所有尺寸下清晰易讀，圖示精準傳達意圖。移除干擾，讓內容成為主角。

| 檢查點       | 本 App 的落點                                                                                                               | 現況                                                                                                                                                                           |
| ------------ | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 字型階層統一 | 統一走 `textTheme` 角色（LargeTitle 34 / Title 22 / Headline 17 / Body 17 / Footnote 13 / Caption 11），禁用零散 `fontSize` | ⚠️ 169 處硬編碼 `fontSize`，最小到 9–11px。`device_list_screen.dart`、`dashboard_screen.dart`、`device_detail_panel.dart` 最嚴重                                               |
| 狀態語言一致 | 車輛狀態只有三種：`online`（綠）、`offline`（灰）、`unknown`（橘），顏色加文字標籤雙重表達                                  | ⚠️ 判定規則不一致：`dashboard_screen.dart:22-24` 直接讀 `d.status == 'online'`；`device_list_screen.dart:216-221` 用「10 分鐘內有定位才算 online」。同一車隊在兩頁顯示不同數字 |
| 一屏一主任務 | 裝置卡片承載名稱、狀態、收藏、速度、里程、地址、屬性 chip                                                                   | ⚠️ 資訊過載，視覺重心散成一片                                                                                                                                                  |
| 三態完整     | 每個資料畫面都有「載入中／沒有資料／出錯」三態，並說明下一步                                                                | ⚠️ 載入普遍是裸 `CircularProgressIndicator`（39 處，32/53 個畫面檔）；空狀態只有一句 `sharedNoData`；錯誤常被吞掉或變成 debugPrint                                             |
| 第一屏見重點 | 首頁問候 → 今日統計 → 最新警報的層級                                                                                        | ✅ 已有清楚三層結構（`dashboard_screen.dart`）                                                                                                                                 |

### 3.2 尊崇（Deference）

介面協助用戶理解與互動，但不搶內容的風采。流暢動態、極簡外觀。

| 檢查點         | 本 App 的落點                                                                                         | 現況                                                                                                                                             |
| -------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| 地圖是主角     | 地圖畫面用玻璃質感控制列（`map_screen.dart` 的 `_GlassSurface` / `_GlassIconButton`），不壓迫地圖內容 | ✅ 方向正確，面板還會自動讓出地圖空間（見 5）                                                                                                    |
| 回饋不打斷     | 成功用小提示，失敗就地說明，不用彈窗中斷思緒                                                          | ⚠️ 84 處 `showSnackBar` 加 33 處 `Get.snackbar` 兩套系統混用；`login_screen.dart` 同一支檔案混用三種失敗呈現（三個 snackbar 加一個 AlertDialog） |
| 動效不喧賓奪主 | 轉場、刪除、狀態變更都用短動效與彈性曲線                                                              | ⚠️ 大部分靜態；只有登入淡入、地圖追蹤、歷史播放有動效                                                                                            |
| 資料即時感     | WebSocket 推播，不需手動刷新                                                                          | ✅ 有（`traccar_provider.dart` 監聽推播），但使用者看不到「目前是即時資料還是延遲資料」                                                          |

### 3.3 深度（Depth）

清晰的視覺層次、流暢轉場、物理隱喻。視窗切換與層級深入時保有方位感。

| 檢查點                 | 本 App 的落點                                                     | 現況                                                                                                                                                                                  |
| ---------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 一套導航模型           | 底部三 tab（裝置、地圖、設定）為主軸；詳情以下拉面板或 sheet 疊層 | ⚠️ 有兩套地圖：tab 地圖（`map_screen.dart`，玻璃控制列＋追蹤）與點裝置卡開啟的 `LiveTrackingMapScreen`（相機鎖定＋底部 sheet）。同一支 App 兩種地圖手勢語言                           |
| 方向感                 | 從列表進詳情、從詳情回列表，路徑清楚                              | ✅ 頁面轉場統一走 `CupertinoPageTransitionsBuilder`（`app_theme.dart`），返回手勢一致                                                                                                 |
| 層級不重複             | 不做「看起來可點但不可點」的裝飾                                  | ⚠️ `dashboard_screen.dart` 的警報列右側有 `chevron_right`，但整列不可點。視覺暗示了一個不存在的操作                                                                                   |
| 診斷資訊與日常介面分離 | 開發者除錯層級要藏起來                                            | ⚠️ `device_details_screen.dart` 把請求層級欄位（`id`、`deviceId`、`protocol`、`serverTime`、`valid`）與未整理的巢狀 attribute 一起列在畫面上，多數只有工程師需要（同檔 311-464 行）   |
| 出錯時方位清楚         | 錯誤後知道自己在哪、資料是否還在                                  | ⚠️ 目前出錯只剩一個短暫 snackbar，畫面靜止如常，使用者不知道資料是不是舊的                                                                                                            |
| 地圖空白世界           | 沒有位置資料時也要有解釋，不能只給空的世界地圖                    | ⚠️ 死伺服器或新帳號會看到 (0,0) zoom 2 的空白世界地圖，配兩個載入指示，沒有說明（`map_screen.dart:1261,1266,1279`）；`_zoomToFitAll` 與追蹤切換在沒有定位時靜默 no-op（`493`、`355`） |
| 圖層切換               | 切換衛星／街道不應重置觀看位置                                    | ⚠️ 切換衛星模式會 re-key 整張地圖（`map_screen.dart:1315`），樣式重載後相機要手動還原                                                                                                 |

### 3.4 一致性（Consistency）

遵循平台慣例，App 內部行為邏輯與視覺前後一致。

| 檢查點           | 本 App 的落點                                                                                                                                | 現況                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 導覽列統一       | 36 個畫面用 `CupertinoNavigationBar`，9 個用 Material `AppBar`（`map_screen.dart`、`dashboard_screen.dart`、`notifications_screen.dart` 等） | ⚠️ 兩個 Chrome 語法混搭，外觀可辨識出「不同世界」                                                                                                                                                                                                                                                                                                                                                                       |
| 破壞性操作標準   | 問自己「這個動作能不能撤銷」：不可撤銷的先確認                                                                                               | ⚠️ 刪裝置有確認（`map_screen.dart:804`），但登出帳號一鍵就清（`settings_screen.dart:660-673`）；`device_detail_panel.dart` 的垃圾桶圖示緊鄰鉛筆圖示且沒有文字，誤觸即不可逆                                                                                                                                                                                                                                             |
| 觸控目標 44×44pt | 手指按得到、看得出可按                                                                                                                       | ⚠️ 收藏愛心被壓到 32×32（`device_list_screen.dart:283`）；登入頁主題點 18–22px 的純 `GestureDetector`；詳情面板頭部圖示約 34px                                                                                                                                                                                                                                                                                          |
| 資源風格一致     | 全用 `CupertinoIcons.*`，留下的 Material icon 有名單                                                                                         | ✅ `APPLESTYLEME.md` 已記錄進度；殘留的是 `map`、`route`、`satellite_alt` 等少數                                                                                                                                                                                                                                                                                                                                        |
| 語言一致         | 所有可見文字走 l10n（64 個語系檔）                                                                                                           | ⚠️ 兩層缺口。第一層，41 處硬編碼英文直接印在畫面上（`notifications_screen.dart:125,140-173`、`device_details_screen.dart:89,100,152`、`emulator_screen.dart:74`、`history_route_screen.dart:655,2003,2038`、`livetracking_map_screen.dart:487,493`）。第二層，63 個語系中 51 個只帶 666 個 key（參考 839），缺的 174 個剛好包含地圖控制與歷史量測整組詞彙，GetX fallback 到 `en_US`，德語與葡語使用者會看到整段英文選單 |
| 架構一致性       | 狀態由 Provider 管；GetX 只做路由（GetMaterialApp、Get.to）、翻譯（.tr）與 snackbar，不是狀態層                                              | ⚠️ 真正的風險不是「GetX 當狀態層」，而是兩套回饋系統（84+33）與認證跳轉散在 provider（`traccar_provider.dart:111,120,137` 直接 `Get.offAllNamed('/login')`）。長期若要統一狀態與路由，成本高（`OPTIMIZEME.md` 評估 25–40%），列 P2                                                                                                                                                                                      |
| 本地化與日期格式 | 日期時間跟隨語系，相對時間用 timeago                                                                                                         | ✅ 已有（`timeago` 語系註冊完整）                                                                                                                                                                                                                                                                                                                                                                                       |

---

## 4. 實作時的關鍵使用體驗（UX）考量

### 4.1 用途明確與功能優先

App 的使用方式要符合預期。核心功能做到極致。

本 App 的核心是「車隊的即時狀態」，不是「管理伺服器設定」。檢查點：

- 開 App 預設回到上次的 tab（已實作，`main_screen.dart` 記住 `last_main_tab_index`），保留使用者的動線記憶。
- 地圖頁的上方抽屜（`_buildDeviceListDrawer`）與底部裝置切換列（`_DeviceSwitcherBar`）重複提供「切換車輛」功能。兩者在多車情境同時出現時，使用者要猜哪個才是主要入口。
- 報表 hub 已有今日／本週／本月／上月／自訂的範圍捷徑（`reports_screen.dart` 的 `DateRangePreset`），並記得上次選的裝置。這個思路要推廣到所有清單篩選。

### 4.2 包容性與無障礙（Accessibility）

不同身心障礙人士都要用得順暢，支援多種互動方式、動態字體與輔助 API。

| 面向          | 現況                                                                                                                                                                        | 目標                                                                                   |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| 動態字體      | 設定頁有字體滑桿，但 `main.dart:140` 用 `TextScaler.linear(settingsProvider.fontSizeScale)` 直接覆蓋系統 scaler，系統「輔助使用字體大小」完全被忽略（預設 1.0 時不會放大）  | 系統 scaler 與 App 滑桿相乘；支援 200% 以上不破版；文字尺寸走 `textTheme` 角色         |
| 螢幕閱讀器    | 全庫僅 2 處 `Semantics(`，都在 `map_screen.dart`（1529、1605），1605 那處還是 `button: true` 卻沒有 label；地圖 marker 沒有語意，讀屏使用者無法逐台掃描                     | 所有 icon-only 按鈕要有語意標籤；地圖 marker 要能讀出「裝置名、狀態、最後更新」        |
| 觸控目標      | 多處低於 44pt                                                                                                                                                               | 全局下限 44×44，密度高的地方用擴大觸控區域                                             |
| 減少動態      | 全庫 0 處 `disableAnimations` / `accessibleNavigation` 偵測，對應 9 個隱式動畫 widget 與 2 個 `AnimationController`                                                         | 偵測後關閉非必要動效                                                                   |
| 方向性（RTL） | 有 ar / he 語系，但沒有 `Directionality` 處理                                                                                                                               | 至少讓文字、表單可用；有餘力再處理翻轉                                                 |
| 色彩對比      | 不均。`map_screen.dart:1101-1116` 的裝置名稱直接用原始 `Colors.green/red/grey`；未啟用 tab 標籤 60% alpha；`device_detail_panel.dart:326` 的 9px caption 在固定高度列被裁切 | 狀態色走 token；重要狀態不可只用顏色表達，一定搭配文字或圖示；小字不低於 Caption2 11pt |
| 語音操作      | 未支援                                                                                                                                                                      | 中期評估                                                                               |

### 4.3 流暢的操作感

介面與動畫應隱喻真實世界的物理反應，自然即時回饋。

已有基礎：Cupertino 轉場、地圖追蹤切換的 `HapticFeedback.selectionClick()`（`map_screen.dart:1536,1611`）、歷史播放的續播動畫（`history_route_screen.dart`）。

待補：

- 觸覺回饋只出現在地圖的三個位置，收藏、切換 tab、送出指令、刪除等關鍵動作沒有觸覺。
- 多處可互動元素是 `GestureDetector`，按下無縮放、無漣漪（Material 漣漪已刻意關閉，`app_theme.dart:29-31`），回饋全靠視覺邊界。
- 通知頁用 `Timer.periodic(1s)` 每秒 `setState` 整個畫面（`notifications_screen.dart:40`），清單一多就是持續的掉幀風險。
- 地圖 marker 更新逐台 `await addSymbol/updateSymbol` 序列化執行（`map_screen.dart:536-617`），車輛多時可能有肉眼可見的卡頓。
- 裝置詳情頁在 `build` 內直接 `_fetchDeviceAndPositions(...)`（`device_details_screen.dart:120`），每次重建都可能重拉資料，造成閃爍。
- 歷史播放器每個 vsync 發一次 `updateSymbol`（`history_route_screen.dart:1549`）；即時地圖的軌跡線每追加一個點就全量重傳 1000 點折線（`map_screen.dart:696-710`），Douglas-Peucker 還在 UI isolate 上對 sublist 遞迴（`729-753`）。
- 圖層切換用 re-key 整張地圖換樣式（`map_screen.dart:1315`），畫面會整張重建。

### 4.4 透明度與信任

使用者要能相信畫面上的資料，也要知道自己可以做什麼、做了什麼。（原稿此處未完，以下補齊）

| 信任來源   | 現況                                                                                                                                                                                                                             | 改善方向                                                                                                |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| 資料新鮮度 | 每張車卡有「最後更新」時間（`device_list_screen.dart` 的 10 分鐘規則），但沒有全局層級的「資料多久沒更新」提示                                                                                                                   | 每頁角落放低干擾的「最後同步：12 秒前」pill，隨時間變化但不高聲                                         |
| 連線狀態   | 伺服器健康檢查每 20 秒一次，連 2 次失敗才彈一次 snackbar（`traccar_provider.dart:100`）；WebSocket 重連有指數退避、上限 30 秒（`websocket_service.dart:97`），但這個狀態從沒顯示給使用者。一秒的斷線會打擾，十分鐘的斷線反而安靜 | 常駐但不搶眼的連線狀態指示：綠點即時、黃點重連中、灰點離線；重連成功要有一次明確回饋                    |
| 操作結果   | 成功回饋幾乎不存在，唯一有明顯成功提示的是刪除裝置（`map_screen.dart:839` 的 tinted snackbar）                                                                                                                                   | 統一：成功綠、失敗紅帶原因、可撤銷的提供 undo；失敗時列出「什麼沒存到、資料是否安全」                   |
| 權限與通知 | 通知設定頁存在，但沒有在首次使用通知前解釋用途                                                                                                                                                                                   | 首次開啟相關功能時，用一句話說明「通知會用來提醒你車輛警報」再請求權限                                  |
| 位置資料   | 位置只用於顯示與導航                                                                                                                                                                                                             | 在設定頁一段隱私說明，寫清楚資料去向（伺服器、本機離線地址庫）                                          |
| 離線可用性 | 地圖 tile 有 Hive 快取（`tile_cache_service.dart`），地址有緬甸文離線庫（`offline_address_service.dart`）                                                                                                                        | 明確告訴使用者「這些內容離線可用」，離線時不要把地圖畫成一片空白而不解釋                                |
| 離線操作   | 送指令、刪除、修改等寫入操作在斷網時直接失敗於 snackbar，沒有佇列或稍後重試（`command_screen.dart:143` 直接送出）                                                                                                                | 寫入操作離線時進入本機 outbox：顯示「等待連線」狀態，連上後自動重試；無法重試的操作明示「請連線後再試」 |
| 地圖空白   | 沒有位置資料或連不上伺服器時，地圖是一片空白世界地圖                                                                                                                                                                             | 顯示「目前沒有可顯示的車輛位置」與原因，離線時說明快取範圍                                              |

---

## 5. 現況盤點：已經做對的基礎（保留，不要動）

- **iOS 視覺語言有骨架**：`theme/app_theme.dart` 的 `iosTheme`（HIG 色票、SF Pro 字階、綠色開關、淡分隔線）、`CupertinoPageTransitionsBuilder` 全平台轉場。
- **地圖玻璃控制列**：`map_screen.dart` 的 `_GlassSurface` 系列，層次與按壓回饋都已是 iOS 手感。
- **地圖與面板協作**：底部面板高度跨 12 幀量測後回寫地圖 content inset，控制列會搬進面板內避免遮擋（`map_screen.dart:292-324,1051`）。
- **追蹤狀態機**：拖曳地圖取消追蹤、程式化移動有 250ms 寬限不自我取消（`map_screen.dart:266-282,1337-1343`）。
- **重疊 marker**：有選單可挑選；marker 點擊與地圖點擊有 guard 防誤觸（`map_screen.dart:411-442,1371-1375`）。
- **深色模式與主題預設**：四套主題（iOS 原生、Obsidian、Deep Sea、Mint）皆可切換。
- **多語系**：64 個 l10n 檔、完整 timeago 語系註冊。
- **動態字體基礎**：`fontSizeScale` 已接 `textScaler`（但忽略系統設定，見 4.2）。
- **下拉刷新**：裝置列表與儀表板有 `RefreshIndicator`。
- **收藏機制**：裝置可釘選到列表頂端，定位清楚。
- **報表範圍捷徑**：今日／本週／本月／上月／自訂，且記憶上次裝置。
- **歷史播放器**：速度選擇（1/5/10/20 倍，會記住）、拖曳校正地址、GPX 匯出；符號更新用批次 `addSymbols`。

## 6. 落差彙總（證據）

| 原則   | 落差                  | 證據                                                                                                                                        |
| ------ | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| 清晰   | 載入體驗扁平          | 39 處裸 spinner，0 處骨架                                                                                                                   |
| 清晰   | 空狀態無引導          | `device_list_screen.dart:184-202` 只有一個 `sharedNoData`，分不清「真的沒裝置」與「篩選沒結果」，也沒有「清除篩選」按鈕                     |
| 清晰   | 同一狀態兩種數字      | dashboard 與 device list 判定規則不同（見 3.1）                                                                                             |
| 尊崇   | 兩套回饋系統混用      | `showSnackBar` 84 次、`Get.snackbar` 33 次，同檔混用                                                                                        |
| 尊崇   | 長錯誤塞進短 snackbar | `command_screen.dart` 等處把 exception 訊息直接塞 snackbar                                                                                  |
| 深度   | 雙地圖、雙控制語言    | `map_screen.dart` vs `livetracking_map_screen.dart`                                                                                         |
| 深度   | 診斷 JSON 外洩        | `device_details_screen.dart:311-464`                                                                                                        |
| 深度   | 死連結暗示            | `dashboard_screen.dart:248` chevron 不可點                                                                                                  |
| 深度   | 地圖空白世界無解釋    | `map_screen.dart:1261,1266,1279`；fit-all 與追蹤無定位時無回饋（`493`、`355`）                                                              |
| 深度   | 回放缺精細控制        | `history_route_screen.dart` 只有速度與拖曳，缺倒轉、步進、跳站、事件標記                                                                    |
| 一致性 | 登出無確認            | `settings_screen.dart:660-673`                                                                                                              |
| 一致性 | 手機上的小元素        | `device_list_screen.dart:283` 32×32 愛心；登入頁主題點 18–22px                                                                              |
| 一致性 | 硬編碼英文            | 41 處 `Text('...')` 未走 `.tr`，含通知說明頁、詳情頁錯誤、`history_route_screen.dart:655,2003,2038`、`livetracking_map_screen.dart:487,493` |
| 一致性 | l10n 覆蓋缺口         | 51/63 語系只帶 666/839 個 key，缺地圖控制與歷史量測詞彙；GetX fallback 到 `en_US`                                                           |
| 一致性 | 架構分層              | 回饋系統兩套、認證跳轉由 provider 直接呼叫路由（`traccar_provider.dart:111,120,137`）；GetX 只用於路由與翻譯，不涉狀態                      |
| 信任   | 離線時的操作沒有防護  | `command_screen.dart:143` 直接 `postCommandsSend`，斷網時只彈錯，沒有佇列或重試；使用者可能以為指令已送出                                   |
| 流暢   | 每秒整頁重建          | `notifications_screen.dart:40`                                                                                                              |
| 流暢   | 序列化 marker 更新    | `map_screen.dart:536-617` 逐台 `await`，對照歷史頁的批次 `addSymbols`                                                                       |
| 流暢   | 軌跡線全量重傳        | `map_screen.dart:696-753`，每追加一個點重傳 1000 點折線，Douglas-Peucker 在 UI isolate 遞迴                                                 |
| 流暢   | 播放器每 vsync 更新   | `history_route_screen.dart:1549` 每個 vsync 發一次 `updateSymbol`                                                                           |
| 流暢   | 月里程逐日抓取        | `history_route_screen.dart:2220-2227` 逐日 Hive 加網路，每 4 天批次 `setState`                                                              |
| 流暢   | 地圖初始位置          | 歷史地圖在樣式載入前停在 `LatLng(0,0)`（`history_route_screen.dart:1633`）                                                                  |
| 流暢   | 整棵地圖樹重建        | `map_screen.dart:1258` 的 `Consumer2` 包住整個 build，任何推播都重建整棵子樹                                                                |
| 流暢   | 啟動阻塞              | `main.dart:47-57` 在 `runApp` 前等 Hive、prefs、日期初始化、session                                                                         |
| 無障礙 | 語意覆蓋極低          | 全庫 2 處 `Semantics(`；`tooltip:` 33 處（有用但不是語意）                                                                                  |
| 無障礙 | 系統動態字體被忽略    | `main.dart:140` 以 `TextScaler.linear` 覆蓋系統 scaler                                                                                      |
| 無障礙 | 對比不均              | `map_screen.dart:1101-1116` 原始 `Colors.green/red/grey`；未啟用 tab 60% alpha；`device_detail_panel.dart:326` 9px 文字在固定高度列裁切     |
| 信任   | 沒有連線與同步可視化  | 僅在健康檢查連續失敗時彈一次 snackbar；斷線一秒打擾、斷線十分鐘安靜                                                                         |

---

## 7. 體驗升級提案（按優先級）

> 每項包含：目標 → 做法 → 技術落點 → 驗收標準。
> P0 為低風險、有限範圍即可上線；P1 為主要體驗升級；P2 為中長期。時程為熟悉此程式碼庫的單人估算，超過 3 個新元件的項目請乘 1.5；P1-1 建議拆兩階段（先列表點擊切 tab，後合併 screen）。
> **★ 上線前必修（排在所有 P0 之前）：P0-4 狀態判定同源。** 兩頁數字對不上會直接傷害信任，其他體驗再好都補不回來。

### P0：立刻做（每個 0.5–2 天）

**P0-1 骨架屏取代裸 spinner**

- 目標：載入時保留版面形狀，避免空白跳內容的跳動感。
- 做法：新增通用 `SkeletonBlock`（Flutter 內建 `AnimatedOpacity` 呼吸即可，不引入套件）與各畫面的骨架組合（車卡骨架、統計卡骨架、報表列骨架）。替換 39 處裸 spinner 中的列表與卡片場景；地圖只留小面積載入指示。
- 落點：`device_list_screen.dart:151-153`、`dashboard_screen.dart`、`reports_screen.dart`、`map_screen.dart:1260-1277`。
- 驗收：首載出現與最終布局同高同寬的灰塊，載入完成無版面位移。

**P0-2 空狀態與錯誤狀態元件化**

- 目標：沒有資料時告訴使用者「為什麼」與「下一步」。
- 做法：建 `EmptyState(icon, title, hint, action)` 與 `ErrorState(message, retry)`。裝置列表區分「沒有裝置」與「搜尋無結果」，後者提供「清除篩選」。錯誤頁提供「重試」。
- 落點：`device_list_screen.dart:184-202`、`device_details_screen.dart:89-152`、`notifications_screen.dart:269-286`。
- 驗收：無資料、篩選無結果、請求失敗三種情境各自有獨立文案與動作。

**P0-3 統一回饋服務**

- 目標：全 App 只有一套提示語言與位置。
- 做法：封裝 `FeedbackService.show(type, message)`，內部用 `ScaffoldMessenger` 的 floating snackbar；錯誤用 `colorScheme.error` 樣式，成功用低調的 confirmation，可撤銷動作附 `SnackBarAction`。逐步移除 `Get.snackbar` 呼叫點與 exception 直接外露。
- 落點：全庫 33 處 `Get.snackbar` 與 84 處 `showSnackBar`。
- 驗收：任一動作的提示都可從同一個服務追溯；錯誤訊息不含原始 exception stack；提示不遮蔽底部導航。
- 注意：`settings_screen.dart:49-52` 已處理過「snackbar 被 tab bar 蓋住」的問題，保留該寫法。

**P0-4 ★ 狀態判定同源（上線前必修）**

- 目標：dashboard 與 device list 對同一車隊給出同一個數字。
- 做法：把 `_deviceStatus()` 的 10 分鐘新鮮度規則抽成 `lib/src/utils/status_utils.dart` 的單一函式（檔案已存在），兩邊共用；dashboard 的線上數、離線數、警報數都用它。
- 落點：`dashboard_screen.dart:22-24`、`device_list_screen.dart:216-221`。
- 驗收：同一時刻兩頁的「線上」數字一致（可寫 widget test 驗證）。

**P0-5 登出確認**

- 目標：不可逆動作先問。
- 做法：`settings_screen.dart` 的登出改為 `showCupertinoDialog` 確認，文案說明「將清除本機登入狀態」。
- 驗收：一鍵登出改為二次確認；與刪除裝置的處理一致。

**P0-6 觸控靶心下限**

- 目標：所有可按元素達 44×44。
- 做法：`device_list_screen.dart:283` 的愛心從 `minWidth/minHeight: 32` 調回 44；登入頁主題點改為 44pt 熱區（視覺點可維持 22px，用透明 padding 擴大）；詳情面板的 34px 圖示容器加大並加 `Tooltip`。
- 驗收：Inspector 熱區全部不小於 44×44。

**P0-7 硬編碼字串歸位**

- 目標：畫面文字 100% 走 l10n。
- 做法：41 處硬編碼字串進 l10n 檔（至少 `en_us.dart` 與 `zh_tw.dart`），並補上 `l10n_keys_test.dart` 的新 key。
- 落點：`notifications_screen.dart:125,140-173`、`device_details_screen.dart:89,100,152`、`history_route_screen.dart:655,2003,2038`、`livetracking_map_screen.dart:487,493`。
- 驗收：`grep -rn "Text('" lib/screens` 的結果不含非 `.tr` 的 UI 字串。

**P0-8 地圖空白世界防護**

- 目標：沒有位置或連不上伺服器時，地圖說明現況，而不是畫一片空白世界。
- 做法：地圖在 `positions` 為空或伺服器健康檢查失敗時顯示 `EmptyState`（「目前沒有可顯示的車輛位置」＋原因）；`_zoomToFitAll` 與追蹤切換在無資料時給一次輕量提示，不靜默無反應。
- 落點：`map_screen.dart:493,1261,1279`。
- 驗收：斷網或新帳號進入地圖，能看到文字說明；fit-all 在無位置時有提示。

### P1：核心體驗升級（每個 2–5 天）

**P1-1 地圖導航統一（最重要的一項）**

- 目標：App 只有一個「地圖的世界」。裝置列表的點擊直接落在主地圖，刪除 `LiveTrackingMapScreen`。
- 做法：新增 `MapNavigation`（`ChangeNotifier`，放 `lib/services/` 或 `lib/providers/`）持有 `focusDevice(int deviceId)` 的意圖。`main.dart` 註冊 provider；`MainScreen` 改用 `CupertinoTabController` 傳給 `CupertinoTabScaffold`（Flutter SDK 已支援 `controller` 參數），監聽意圖後設 `_controller.index = 1`；`MapScreen` 在地圖就緒（`_onStyleLoaded`）後取走意圖，呼叫既有的 `_onDeviceSelected(device, forceShowPanel: true, zoomToMax: true)`；`device_list_screen.dart:249` 改成 `context.read<MapNavigation>().focusDevice(device.id!)`。地圖左側的 `_buildDeviceListDrawer` 保留，已有搜尋、排序、收藏，不需要把裝置列表搬進抽屜。
- 落點：`device_list_screen.dart:249`（唯一呼叫點）、`main_screen.dart`、`main.dart`、`map_screen.dart`；刪除 `livetracking_map_screen.dart` 前，先確認它獨有的東西已進 `DeviceDetailPanel`（導航到 Google Maps、里程入口、地址列面板已有）。
- 驗收：從列表點一台車，直接切到地圖 tab，該車被選中、追蹤開啟、面板展開；地圖控制列與原本主地圖完全相同；地圖尚未建立時（首次點擊）同樣成立；系統返回鍵不回首頁，維持 tab 模型。
- 意圖只能消費一次：`takePendingDeviceId()` 取走即清空；`MapScreen` 另外用本地 `_pendingFocusDeviceId` 加一個「已套用」旗標，避免「監聽器」與「style 載入」兩條路徑重複套用。套用後設 `_hasInitialZoomed = true`，擋掉 `_onStyleLoaded` 裡的 prefs 還原或 fit-all 二次縮放。衛星模式切換會 re-key 地圖（`map_screen.dart:1315`），但 style 重載只走 `_syncSelectedDeviceFromProvider`（同檔 621-636，只換裝置物件、不動相機），不會再觸發聚焦。
- 返回鍵：目前全庫沒有任何 `PopScope` / `WillPopScope`，所以返回鍵現在對展開中的面板無作用。在 `MapScreen` 的 Scaffold 外包 `PopScope`：`canPop: !_isPanelOpen`，`onPopInvokedWithResult` 裡若面板開著就收合面板並把 `didPop` 維持 false，面板已收合則交回系統預設（Android 退出 App 或背景）。`CupertinoTabView` 內建自己的 Navigator，PopScope 放在 `MapScreen` 這層就能攔到地圖 tab 的返回。
- 決策取捨：這會改變「返回」的語意（原本 push 一頁可返回）。tab 架構本來不以返回鍵翻頁，統一後把返回交給底部分頁與面板收合；面板展開時返回鍵優先收面板，符合 Android 使用者的兩段式期待。
- 附帶好處：通知與深連結也能直接呼叫 `focusDevice(deviceId)`，不需要再新增一條導航路徑。

**P1-2 追蹤狀態有明確視覺**

- 目標：使用者知道「現在相機在跟著這台車」。
- 做法：追蹤中時裝置旗標放大、控制列上的追蹤按鈕保持高亮（`_GlassIconButton` 的 `isActive` 已有，強化）；手動平移地圖後，顯示「回到追蹤」的悬浮 pill 三秒，引導回來。
- 落點：`map_screen.dart:343-360,1371-1385`。
- 驗收：追蹤開啟→手動平移→按鈕取消高亮→出現回到追蹤提示，狀態循環明確；無定位時按追蹤要有「尚未取得定位」提示。

**P1-3 裝置列表卡片收斂**

- 目標：一張卡只承載三層：身分（名稱＋狀態）、關鍵數據（速度、里程、最後更新）、單一主要動作。
- 做法：屬性 chip 收進詳情頁；卡片點擊進地圖；右滑提供快速「導航」「分享」「指令」；保持愛心收藏在右上但加大熱區，地址不要去動到。
- 落點：`device_list_screen.dart:223-360`。
- 驗收：卡片高度降低三成；視線 1 秒可讀完；滑動快速動作可用且被發現。
- 概念示意（用英文標籤避免中文字寬讓框線歪掉）：
  ```
  Before                      After
  ┌───────────────┐           ┌───────────────┐
  │ Car-12  ● on  ♡│           │ Car-12  ● on  ♡│
  │ 62 km/h        │           │ 62 km/h · 12m │
  │ 8,120 km       │           │ Navigate · Share│
  │ Taipei ...     │           └───────────────┘
  │ [chip][chip]   │
  └───────────────┘
  ```

**P1-4 通知頁即時性與未讀處理**

- 目標：警報是核心業務，不能每秒掉幀，也要能清理。
- 做法：計時器改為每張卡獨立的 `Timer` 或 `Stopwatch` 與局部 `setState`；加入下拉刷新；「已讀／全部標為已讀」動作；過期事件可折疊或清除。
- 落點：`notifications_screen.dart:40`、`269-286`。
- 驗收：20 筆事件時無感掉幀（DevTools frame chart）；已讀狀態在重開後保留。

**P1-5 歷史播放器打磨**

- 目標：回放是「講故事」，要有時間軸與段落感。
- 做法：時間軸拖曳時在節點上方顯示時間 tooltip；補「倒轉、步進、跳至下一站」控制；把停留與事件標在時間軸上；播放／暫停與拖曳加觸覺刻度；播放中底部面板採 mini 版（`_buildMinimalPlaybackPanel` 已有），避免遮住地圖；GPX 匯出成功要有明確提示。
- 落點：`history_route_screen.dart:1843-1999`、`2001-2022`。
- 驗收：拖曳 10 秒路程可看到連續時間標記；播放中地圖可視範圍不低於 60%。

**P1-6 連線與同步狀態常駐化**

- 目標：資料是新還是舊，使用者要知道。
- 做法：地圖與列表頁角落放低調 pill（綠：即時；黃：重連中；灰：離線，最後同步 12 秒前）。重連成功給一次輕量回饋。健康檢查的失敗用 pill 呈現，不用 snackbar 打斷。
- 落點：`traccar_provider.dart:100`（健康檢查）、`websocket_service.dart:97`（退避）。
- 驗收：拔網路 10 秒內 pill 變灰並倒數；恢復後 3 秒內變綠。

**P1-7 報表 hub 一致化**

- 目標：每種報表都是同一個「選條件 → 產生 → 匯出」模型。
- 做法：範圍與裝置的選擇元件抽成共用 `ReportFilterBar`（今天已在 hub 有雛形）；記憶上次範圍（不只裝置）；結果空時給出「這個範圍沒有資料，試試上週」的建議；匯出按鈕位置固定。
- 落點：`reports_screen.dart`、`reports/*`。
- 驗收：進入任一報表，篩選列長相與行為一致；切換報表不重選條件。

**P1-8 設定頁可搜尋**

- 目標：21 個設定項目在低頻使用下仍可快速找到。
- 做法：`ListView` 加 `CupertinoSearchTextField`，做簡單的關鍵字過濾；或把 `_settingsTile` 分組加上 sticky header。
- 落點：`settings_screen.dart:516+`。
- 驗收：輸入「通知」可直接定位到通知設定。

**P1-9 動態字體銜接系統設定**

- 目標：系統「輔助使用 > 字體大小」真的會放大 App 文字。
- 做法：`main.dart:140` 改為把系統的 `textScaler` 與 App 滑桿相乘後再套用（保留 App 滑桿僅做微調），不要直接覆蓋。
- 落點：`main.dart:136-146`。
- 驗收：系統字體最大時，車卡與地圖控制列仍可完整顯示按鈕。

**P1-10 語系補齊**

- 目標：51 個只帶 666 key 的語系補到 839，地圖控制與歷史量測不再露出英文。
- 做法：以 `en_us.dart` 為參考補齊缺漏 key；優先德語、葡語、西語等使用者數大的語系。現有 `test/l10n_keys_test.dart` 只檢查 en_US 的存在性與 key 形式，不檢查其他語系。新增 `test/l10n_coverage_test.dart`：對每個 `lib/l10n/*.dart` 斷言其 key 集合等於 en_US，缺一個就讓 CI 紅燈（若對 63 個語系太嚴，先限制在本 Release 目標語系清單）。
- 落點：`lib/l10n/*.dart`。
- 驗收：任一語系在切換裝置後，地圖控制的 tooltip 與量測面板都是該語系文字。

**P1-11 離線操作佇列（outbox）**

- 目標：斷網時下達的指令與修改不丟失，恢復連線後自動補送，並讓使用者看見狀態。
- 做法：寫入操作（送指令、刪除裝置、改設定）先落本機 `Hive` 或 `sqflite` 的 outbox，UI 立即標「等待連線」；`WebSocketService` 或健康檢查恢復時依序重送，成功後轉「已送出」；不可重試的操作（例如修改密碼）明示需連線。
- 落點：目前 `command_screen.dart:143` 直接 `postCommandsSend`，沒有佇列；`traccar_provider.dart` 的健康檢查可當恢復訊號。
- 驗收：飛航模式送指令→顯示「等待連線」→恢復網路→指令自動送出且狀態更新；重開 App 佇列不遺失。

### P2：中長期（可排入季度計畫）

- **無障礙完整化**：語意標籤與地圖 marker 語意、reduce motion、RTL、對比 token 化。先從地圖與裝置列表做。
- **效能打磨**：map 的 `Consumer2` 收窄為 `Selector`；marker 更新改批處理；軌跡線節流；播放與月里程的重繪局部化；`main()` 初始化分流到 splash 後。
- **iOS 26 Liquid Glass 對齊**：玻璃控制列已是半套，評估換到原生 glass 材質（`APPLESTYLEME.md` 方案 C 延伸）。
- **Siri 捷徑／Widget**：車隊狀態 glanceable（遠期）。

---

## 8. 流暢度（超流暢）設計準則

「超流暢」在本 App 的定義：**資料到眼睛沒有空窗，操作到回饋沒有等待**。

### 8.1 動效與觸覺規範（tokens）

| 元素           | 規範                                                                                                |
| -------------- | --------------------------------------------------------------------------------------------------- |
| 轉場           | Cupertino 慣例（已用），時長 350ms，彈性 spring                                                     |
| 元素出現／消失 | 150–250ms `AnimatedSwitcher`，避免 >300ms                                                           |
| 按壓回饋       | 按鈕 scale 0.97、150ms 回彈；列表可長按出 context menu                                              |
| 觸覺映射       | 重要切換（追蹤、開始播放）：`selectionClick`；刪除確認：`mediumImpact`；下拉刷新完成：`lightImpact` |
| 數字變化       | 統計數字用 `AnimatedSwitcher` 或 count-up，避免硬跳                                                 |
| 減少動態       | 偵測 `MediaQuery.disableAnimations` 後全部降為 fade 或直接切換                                      |

### 8.2 效能預算與目前熱點

- 目標：60fps（16ms/幀）；地圖 marker 更新後 UI 執行緒無長任務 > 16ms。
- 現在要優先處理的熱點：
  1. `map_screen.dart:1258` 的 `Consumer2` 包住整個地圖 build，任一推播重建整棵子樹 → 改用 `Selector` 或拆分監聽。
  2. `map_screen.dart:536-617` marker 逐台序列化更新 → 批處理或節流；歷史頁的批次 `addSymbols` 是現成範本。
  3. `map_screen.dart:696-753` 軌跡線每點全量重傳，Douglas-Peucker 在 UI isolate 遞迴。先節流（拖曳與追蹤中都降低重算頻率，結束後再全量），再考慮 `Isolate.run` 只算「簡化後的點位索引」回傳 `List<int>`，幾何提交留在主 isolate（可用 `TransferableTypedData` 省複製），避免每追加一個點就重傳整條折線。
  4. `history_route_screen.dart:1549` 播放器每 vsync `updateSymbol` → 降到 UI 可接受的頻率。
  5. `history_route_screen.dart:2220-2227` 月里程逐日抓取加多段 `setState` → 一次算完再更新。
  6. `history_route_screen.dart:1633` 歷史地圖初始 `LatLng(0,0)` → 等樣式載入或先落到第一點。
  7. `main.dart:47-57` 在 `runApp` 前等完 Hive / prefs / 日期 / session → 先讓 splash 出現，資料就緒再進主畫面。
- 清單渲染：保持 `ListView.builder`（已用）；卡片內避免 `ShrinkWrap` 與嵌套滾動。
- 圖片：marker icon 已由 `marker_icon_service.dart` 管理載入狀態，維持。

---

## 9. 無障礙（Accessibility）落地清單

1. **語意標籤**：所有 icon-only 按鈕加 `Semantics(label: ...)` 或 `tooltip`（兩者不衝突，`tooltip` 產生長按說明）；修 `map_screen.dart:1605` 的 `button: true` 但無 label。
2. **地圖可讀性**：為裝置 marker 提供語意描述（裝置名＋狀態＋最後更新），讓 VoiceOver / TalkBack 可逐台掃描。
3. **動態字體**：系統 scaler 與 App 滑桿相乘（P1-9）；用 `textScaleFactor: 2.0` 實測地圖控制列、車卡、報表表格不破版。
4. **觸控**：44×44 全局下限（P0-6）。
5. **顏色不單獨承載資訊**：狀態一定加文字（已有 chip 文字，維持）；地圖上的裝置名稱顏色改用 token。
6. **減少動態**：實作 `MediaQuery.disableAnimations` 檢查（地圖追蹤動畫、列表刪除動畫）。
7. **焦點順序**：登入頁 `TextField` 加 `textInputAction`／`onSubmitted`，讓外部鍵盤與 TalkBack 可依序操作。
8. **RTL**：至少確認文字與表單可用；`Directionality` 全域包裝評估。

---

## 10. 透明度與信任實作清單

- [ ] 每頁「最後同步」時間（低調 pill，隨秒更新）。
- [ ] 連線狀態三色指示（即時／重連／離線），重連成功一次輕量回饋。
- [ ] 失敗訊息三段式：發生什麼 → 資料有沒有存 → 可不可以重試。
- [ ] 首次使用通知前說明用途再請求權限。
- [ ] 設定頁隱私段落：位置資料流向與本機快取範圍。
- [ ] 匯出與分享前預覽（GPX／Excel 檔名與範圍）。
- [ ] 地圖空白世界改成帶原因的 `EmptyState`（P0-8）。

---

## 11. 一致性規範（design tokens）

### 11.1 顏色

| 用途               | 色票                             |
| ------------------ | -------------------------------- |
| 系統藍（主要動作） | `#007AFF`（dark 模式 `#0A84FF`） |
| 線上               | `#34C759`（dark `#30D158`）      |
| 離線               | `#8E8E93`                        |
| 警報／錯誤         | `#FF3B30`（dark `#FF453A`）      |
| 未知               | `#FF9500`                        |
| 群組背景           | 亮 `#F2F2F7`／暗 `#000000`       |
| 分隔線             | `#000000` 12%／`#FFFFFF` 12%     |

（已是 `app_theme.dart` 的現有定義，維持。）

### 11.2 字型角色

統一走 `textTheme`：`displayLarge` 34／`headlineMedium` 28／`headlineSmall` 24／`titleLarge` 22／`titleMedium` 20／`titleSmall` 17／`bodyLarge` 17／`bodyMedium` 16／`bodySmall` 13／`labelMedium` 12／`labelSmall` 11。禁止新寫 `fontSize` 字面值；小字不得低於 Caption2 11pt（`device_detail_panel.dart:326` 的 9px 需修正）。

### 11.3 間距與圓角

8pt 網格；卡片圓角 12–16；底部 sheet 24–28；玻璃控制列沿用現有 `_GlassSurface`。

### 11.4 元件

- 清單：iOS grouped list（`CupertinoListSection` 或 `_settingsSection` 樣式）。
- 次要動作：`IconButton` 需有 `tooltip` 與語意；破壞性動作永遠有文字或確認。
- 空狀態：icon 40pt＋一句標題＋一句提示＋（可選）一個動作。
- 骨架：`SkeletonBlock` 統一呼吸節奏（1.2s 週期）。

---

## 12. 驗收與量測

### 12.1 可直接勾選的驗收清單

| #   | 項目                                         | 驗證方法                                     |
| --- | -------------------------------------------- | -------------------------------------------- |
| 1   | 冷啟動 3 秒內回報車隊概況                    | 錄影或 `flutter run --profile` 計時          |
| 2   | 列表 → 某台車位置 ≤ 2 點擊                   | 走查                                         |
| 3   | 所有按鈕 ≥ 44×44                             | Inspector 熱區檢查                           |
| 4   | 所有清單可下拉刷新                           | 逐一走查                                     |
| 5   | 每個畫面三態（載入／空／錯誤）齊全           | 空資料與斷網情境走查                         |
| 6   | 同資料兩頁數字一致                           | widget test（dashboard vs device list）      |
| 7   | 地圖無位置時顯示解釋性空狀態                 | 斷網與新帳號走查                             |
| 8   | 通知 20 筆時無掉幀                           | DevTools Performance                         |
| 9   | 系統字體放大到最大，App 文字確實變大且不破版 | 系統設定＋`textScaleFactor: 2.0` 測試        |
| 10  | 所有可見字串有翻譯                           | `l10n_keys_test.dart` 覆蓋率檢查 + grep 審查 |
| 11  | 減少動態時動畫降級                           | 系統設定開啟後檢視                           |

### 12.2 效能量測

- `flutter run --profile` + DevTools Performance 抓 10 秒地圖互動 frame chart。
- 目標：p95 frame < 16ms；marker 批次更新後無長幀；地圖 20 台車推播時整棵子樹重建次數降至局部。

---

## 附錄 A：畫面與檔案對照

| 功能             | 檔案                                        |
| ---------------- | ------------------------------------------- |
| 主框架（三 tab） | `lib/screens/main_screen.dart`              |
| 裝置列表         | `lib/screens/device_list_screen.dart`       |
| 首頁儀表板       | `lib/screens/home/dashboard_screen.dart`    |
| 即時地圖（多車） | `lib/screens/map_screen.dart`               |
| 單車地圖         | `lib/screens/livetracking_map_screen.dart`  |
| 裝置詳情         | `lib/screens/device_details_screen.dart`    |
| 歷史軌跡／回放   | `lib/screens/history_route_screen.dart`     |
| 通知             | `lib/screens/notifications_screen.dart`     |
| 報表 hub         | `lib/screens/reports/reports_screen.dart`   |
| 設定             | `lib/screens/settings/settings_screen.dart` |
| 登入             | `lib/screens/login_screen.dart`             |
| 地圖詳情面板     | `lib/widgets/device_detail_panel.dart`      |
| 全域狀態         | `lib/providers/traccar_provider.dart`       |
| WebSocket        | `lib/services/websocket_service.dart`       |
| 主題             | `lib/theme/app_theme.dart`                  |
| 啟動與 scaler    | `lib/main.dart`                             |

## 附錄 B：與其他文件的關係

- `APPLESTYLEME.md`：負責「視覺像 iOS」。本文件負責「用起來像 Apple 想的那樣」，以人為本、流暢、信任。兩者交集是元件庫（Cupertino 化、glass 材質）。
- `OPTIMIZEME.md`：負責體積與依賴。其效能相關建議（`Consumer2` 包裹整棵樹、靜態 instance）與本文第 8 節互補。

## 附錄 C：本次盤點使用的統計

- `lib/` 下 `screens`＋`widgets` 共 53 個 Dart 檔案。
- `CircularProgressIndicator` 39 處，分布於 32 個檔。
- `RefreshIndicator` 只出現在 3 個檔。
- `showSnackBar` 84 處、`Get.snackbar` 33 處。
- `Semantics(` 2 處；`tooltip:` 33 處。
- `fontSize:` 字面值 169 處；`textTheme` 使用 16 處。
- `CupertinoNavigationBar` 36 個檔；Material `AppBar` 9 個檔。
- l10n 檔 64 個（63 個語系＋1 個 timeago 語系檔）；其中 51 個語系只帶 666 個 key（參考語系 839 個）。
- 硬編碼 `Text('...')`（未走 `.tr`）41 處。
- 行號是 2026-11-15 的快照；程式一旦改動，行號會位移，查找時以檔案名加 grep 字串為準，不要依賴行號。

（以上計數可用 grep 重新產生；若與現況不符，以現況為準並更新此節。）

## 附錄 D：Apple 官方《設計原則》全文（使用者提供之原文，簡體保留）

設計原則：探索指導 Apple 平台設計的基本原則。

更成功且经久不衰的设计基于对用户如何思考、感受和与世界交互的深刻理解。下述原则体现了这一事实，并构成了贯穿《人机界面指南》的指导基础。这些原则的应用并非千篇一律，而是作为工具助你在实现优秀设计的过程中权衡优先级冲突和作出关键决策。

**目标感，创造有意义的产品。**
设计始于意图。识别对设计受众而言最重要的内容。专注于打磨这些内容，你将会打造出对用户真正有价值的体验。
提供价值。最佳的设计会体现“如何让产品真正有用”这一恒定不变的目标。在开发的每个阶段，问问自己，产品的用途是什么，以及设计是否服务于该用途。
保持专注。让 App 的使用方式符合用户预期，优先考虑 App 中最重要的功能，并专注于让这些功能变得真正出色。用途明确的产品更能有效帮助用户实现目标。
寻找解决问题的新方法。调查现有解决方案，并避免重复创建。定义产品的与众不同之处，并问问自己能如何通过设计体现。

**能动性，让用户随心所欲地使用。**
界面存在的意义在于帮助用户实现其目标。让用户可以自由操作、了解当下情况，并可轻松从误操作中恢复。
不妨碍工作。用户会使用你的产品来达成目的。助用户一臂之力的最佳方式通常是直接将其带到所需的任务或内容。最佳的设计是只在用户需要时低调呈现。
让用户自由探索。让其可在整个界面中移动和访问功能，而不受限于特定的流程或模式。使必要的引导流程易于跳过或退出，以便用户快速进入主要体验。
帮助用户从误操作中恢复。用户在知道可撤销操作或返回之前状态的情况下，会自由进行探索，而这种自由会让界面更具吸引力。将容错性融入设计，并让其易于实现。从意外情况中恢复不应花费用户的时间或精力。

**责任感，以用户最佳利益为核心。**
作品会影响用户的生活。为赢得其信任，优先考虑安全性和隐私，并使产品的用途和意图公开透明。
让产品的用途和意图完全透明。用户的首次交互是你与其建立关系的契机。确保从一开始就明确 App 的意图。在请求许可时提供清晰的依据，在收集数据时表明所收集的内容及其使用方式。
保护用户信息安全。用户相信你会维护其数据的完整性。仅收集产品运作所需的内容，并进行妥善处理。预测可能导致误用或伤害的方式，并相应安排保护措施以防止滥用和意外结果。

**熟悉感，基于用户既有认知。**
利用用户已了解的概念可帮助其快速适应。基于既有的现实和数字模式打造体验，并在整个设计应用中保持一致。
使用用户已知的概念。用户会将对真实世界和其他软件的认知带到每种新体验。利用这些认知使界面更具熟悉感和直观性。
保持视觉效果和交互方式一致。为元素建立行为或外观后，将其应用至整个设计。一致性可帮助用户更快速学习，并使其对新交互方式将会按其预期工作有信心。
提供清晰的反馈。在用户使用 App 时，为其提供清晰的信号指示当下情况。显示可用的控制，指示更改的内容，并使用系统模式显示提醒和提供选择。一致的反馈可帮助用户了解情况并保持掌控。

**灵活，适应各种不同的情境和需求。**
用户使用软件的方式因人而异。设计之中越认可这一点，用户越能在使用时感受到接纳。留意其他软件的体验，并尽量支持尽可能多的设备、交互类型和视角。
为所有人设计。考虑到用户的产品设计会让用户更有信心。思考可能接触设计的用户的多样性，并将其体验、视角和需求范围考虑在内。从一开始就重视无障碍设计。将包容性融入设计，这可收获尽可能广泛的受众，并为所有用户打造更佳体验。
保留用户的情境。在设计适配不同平台和配置时，帮助用户保持舒适感。保持内容和控制的位置一致且可预测，并使用自然动画缓解过渡。
考虑各种输入方式。用户与设备的交互方式多种多样。针对尽可能多的输入方式（包括语音、触控和键盘等）进行设计，意味着更多用户可按照其最适合的方式使用你的产品。
有意识地应对每个平台。在任何运行环境中，你的软件都应该令人感到精美且自在。请对支持的每个平台都给予同等关注。

**简洁，清晰直接。**
设计良好的体验中会去除不必要的内容，使每个元素各得其所。逻辑清晰且易于导览的界面有助于更轻松达成目的。
仅包含必要内容。简洁并非极简主义，而是追求目标明确且实用的体验。保持重要内容触手可及的同时，过滤其他无关内容。
力求精简。最简单的表达方式往往最通用、最有帮助。在传达概念或为控制添加标签时选用恰如其分的字词。
建立层级结构。当形式和功能一目了然时，用户便能知道如何获得想要的结果。优先使用可识别的控制和一致的结构，有助于用户了解其当前所在位置和后续内容。

**匠心，重视每一个细节。**
你的设计体现了你的用心程度，展示了你对为用户提供最佳体验的奉献。投入时间才能做好作品。
质量奠定基调。设计中的每个元素都会向用户展示你的用心程度。仔细考虑每一个决定，力求视觉效果惊艳、动画流畅、措辞精准和音频细致。
试验并迭代。尽早创建原型，尝试新方法，并乐于放弃无效方案。为每个功能设定高标准，进行优化，然后再次尝试。在真实世界环境下测试产品，确保其经久耐用、可靠且表现卓越。
保持匠心。发布并非终点。保持界面紧跟最新的平台功能和设计模式，并保持高质量标准。设计是一项长期承诺。

**愉悦感，融入人文关怀。**
用户会记住产品带来的感受。考虑符合体验的情绪，并力求以令人满意、丰富且具有使用乐趣的形式传达。
确定希望激发的情绪。并非所有软件的使用感受都相同。健身 App 可能带来活力，冥想 App 可能带来平静，而游戏可能带来兴奋。了解你希望调动的情绪，并用其塑造设计。
创造决定性时刻。每次交互都是展示软件定位的机会。无论是简单的按钮按下操作还是错误信息，每个时刻都值得考虑是否有机会添加一些可体现设计灵魂的特征。
不要将愉悦感当成装饰。请牢记，用户的目标是完成任务，不要让追求愉悦感本身影响到产品的核心目的。考虑整体美学：有些设计会受益于精心考虑的实用设计，有些则可能倾向于加入一点奇思妙想。多加尝试，找到平衡点。
全盘考虑。愉悦感涉及你对产品的各种考量，是用户在使用产品时的整体体验，这包括操作的自由、探索的安全性、熟悉隐喻的舒适感，以及从一种情境过渡到另一种情境的灵活性。当你带着意图、专注和关怀进行设计时，产品自然会带给用户愉悦感。
