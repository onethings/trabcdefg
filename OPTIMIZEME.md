# Flutter 記憶體與 CPU 優化分析

**目標重述。** 你的目標是讓這支 Traccar 用戶端在手機上更省記憶體與 CPU，前提是現有功能與畫面完全不變。所以本文只收錄「行為等價、畫面像素不變」的項目。任何會改變佈局、欄寬、動畫節奏、地址文字或請求語意的做法，都標成不建議或需要你先拍板。

**一句結論。** 錢花在三個地方：三個 Hive box 用 `openBox`（非 lazy）把資料整個載進 RAM、位址查詢鏈沒有上界且先打遠端、以及每一包 websocket 都讓整頁 widget 重建。地圖繪製、國際化、圖片資產、Android release 建置設定都不是問題（最後這項我原本猜錯了，實測的建置產物顯示 R8 與資源縮減已經在跑）。

**我的判斷。** §4 那一批（記憶體）投入小、風險低、體感最大，先做。§5 要一頁一頁改並逐頁截圖比對，別一次全上。

---

## 1. 證據等級

每個結論都標了等級，請照標籤決定要不要信。

| 標籤 | 意思 |
| --- | --- |
| **實測** | 我在這台機器上跑出來的數字，方法和輸出寫在文內 |
| **推論** | 從呼叫次數、資料量與框架語意推出來，沒有在裝置上量 |
| **猜測** | 方向合理但缺證據，只用來排優先順序，不要當承諾 |

實測的邊界講清楚，免得誤用。

- 微基準環境：`Dart SDK 3.13.1`、`intl 0.20.3`、macOS x64、**JIT**。
- 手機是 **AOT**，沒有 JIT 暖機成本，單次操作絕對值會不同（通常 AOT 慢一些），但「一次配置 vs 重複使用」的相對關係成立。
- 建置產物量測來自 `build/app/outputs/`，也就是 11-15 那次 release 建置的產物。
- 我**沒有**在手機上量 RSS 與 frame time。那需要你跑一次 `flutter run --profile` 搭配 DevTools，步驟在 §8。

---

## 2. 量測基線

### 2.1 APK 組成（實測）

`unzip -v build/app/outputs/apk/release/app-arm64-v8a-release.apk` 的關鍵幾行：

```
13239176  Stored   lib/arm64-v8a/libapp.so                       (Dart AOT 產物)
 3863528  Defl:N  1717252  classes.dex                            (R8 之後)
20774912  Defl:N  4762202  assets/flutter_assets/assets/sqldb/myanmar_ultra_res_my.db
   22280  Defl:N    12726  assets/flutter_assets/fonts/MaterialIcons-Regular.otf
lib/arm64-v8a 全部原生庫合計 41,152,136 bytes
```

arm64 APK 50,132,877 bytes，其中 41 MB 是原生庫（maplibre、scanner、file_picker、printing 等外掛），`libapp.so` 13.2 MB。這代表兩件事。第一，**體積的槓桿不在 Dart 程式碼**，在那 41 MB 原生庫。第二，`libapp.so` 已用 `Stored`（未壓縮）存放，開機是 mmap 而非解壓，這是正確且省啟動時間的做法。

### 2.2 本機微基準（實測）

用 `dart run` 直接跑 `intl` 與 app 的熱路徑函式，腳本放 `/tmp` 不進 repo。

| 項目 | 結果 | 說明 |
| --- | --- | --- |
| `initializeDateFormatting()` 建表範圍 | 120 個 locale 的 symbols、122 個 locale 的 patterns | 無參數版本會忽略參數、整表建立 |
| 冷啟動（含 JIT 編譯） | 250 到 290 ms、RSS +10 到 14 MB | **這幾乎全是 JIT 編譯成本**，不代表手機 |
| 暖機後重建兩張表 | 0 到 1 ms、RSS +48 到 +740 KiB | 三次量測，這才是 AOT 手機的真實量級 |
| `DateFormat('HH:mm:ss')` 每次新建 + format | 89 到 97 µs | 每次多花約 **70 µs** |
| 同一個 `DateFormat` 重複 format | 20 到 23 µs | 對照組 |

把 70 µs 換算成場景：60 Hz 面板每秒約 4.2 ms 純格式化垃圾（10 分鐘回放約 2.5 秒純 CPU）；報表 1000 列約 70 ms 的額外格式化。

---

## 3. 熱路徑

先確認錢花在哪條路上，排序才有依據。

```
WebSocket 每包 (data['positions'])
  └─ TraccarProvider._listenToWebSocket      lib/providers/traccar_provider.dart:386
       ├─ _positions / _positionMap 就地更新
       ├─ _positionsRevision++
       └─ notifyListeners()                  :426
            ├─ 地圖頁底部控制項 Consumer       lib/screens/map_screen.dart:1621
            ├─ 地圖頁資料監聽器               :1611（設計正確，不要動）
            ├─ 通知頁整頁                     lib/screens/notifications_screen.dart:166
            ├─ 儀表板整頁                     lib/screens/home/dashboard_screen.dart:19
            └─ 裝置清單每張卡                 lib/screens/device_list_screen.dart:422
```

三個結構性事實：

1. **訂閱範圍太大。** 通知頁與儀表板訂閱整個 `TraccarProvider`，但畫面上真正變的東西不是位置本身，而是位置附帶的少量衍生值。於是「位置更新頻率」直接變成「整頁重建頻率」。
2. **三個 Hive box 開成 eager。** hive 2.2.3 的 `openBox` 會把每個 entry 全部解碼進記憶體。證據在套件原始碼 `hive-2.2.3/lib/src/backend/vm/storage_backend_vm.dart:84` 的 `if (!lazy) { framesFromFile(...) }`，非 lazy 走「讀所有 frame 含值」，lazy 才走 `keysFromFile`。
3. **位址是隱形熱路徑。** 每次 GPS 新座標都可能觸發一個遠端 Nominatim 查詢，全 App 共用一條 1.5 秒間隔的串行佇列，而且遠端查詢排在離線資料庫**之前**。

---

## 4. P0 記憶體：先做這五項

共同特徵是「改完畫面一模一樣」，省下的是**常駐**記憶體而不是一次性尖峰。

### P0-1 `mapTilesCache` 是無上限的 eager box，而且兩處用不同 key 存同一份資料

**狀態：第一批已實作。**

- **位置**
  - `lib/services/tile_cache_service.dart:16` `_tileBox = await Hive.openBox<Uint8List>(boxName);`
  - 整個檔案沒有 `delete` / `clear` / `compact`（grep 零命中），快取圖磚只進不出。
  - `lib/screens/map_screen.dart:68` 建 service，`:127` `_cacheService.init()`，但整個檔案再也沒用到 `_cacheService`（grep 只有這兩行）。地圖頁只是為了「把 box 打開」而付全量載入的代價。
  - `lib/screens/settings/geofences_screen.dart:26` 另外複製了一份 `TileCacheService`，box 名相同 `'mapTilesCache'`（`:27`），但 key 用 `url.hashCode.toString()`（`:34`），而 `tile_cache_service.dart:24` 用完整 URL。
- **為什麼貴。** 兩套 key 讓同一張圖磚存兩份、下載兩次，兩邊還讀不到對方的快取。加上 eager open，開過地圖或地理圍欄頁之後，所有歷史圖磚位元組（每張 10 到 40 KB）就一直在 RAM 裡，並隨使用時間單調上升。這是全 App 最可能的長尾記憶體成長來源。
- **成本估計。** 推論。2000 張快取圖磚約 20 到 80 MB 常駐且只增不減，實際取決於使用者逛過多少區域。
- **風險。** 無畫面變動。`getTile` 本來就是 `Future`（`tile_cache_service.dart:19`），改成 lazy box 不用改呼叫端形狀。
- **最小修法。** 三件可分批做。
  1. `Hive.openBox` → `Hive.openLazyBox`，型別改 `LazyBox<Uint8List>`，`get`/`put` 本來就是 async。
  2. 刪掉 `map_screen.dart:127` 的 `_cacheService.init()`（它沒有用途），若 `_isCacheInitialized` 需要訊號就只留 `OfflineAddressService.initDatabase()`。
  3. 兩處 key 統一成完整 URL，並在 `saveTile` 後檢查 `_tileBox.length`，超過上限（例如 2000）刪最舊一批。

### P0-2 `address_cache` / `route_positions` / `daily_summaries` 同樣是 eager open

**狀態：第一批部分實作。** `route_positions` 與 `daily_summaries` 已改 lazy。`address_cache` **暫緩**，原因見下方「前提被推翻」。

- **位置** `lib/widgets/offline_address_service.dart:59`、`lib/screens/history_route_screen.dart:535`、`:609`、`lib/services/route_history_cache.dart:36`、`lib/screens/history_route_screen.dart:2179`
- **為什麼貴。** `address_cache` 是座標字串快取，程式自己預期它可能很大（`:61-63` 超過 50000 筆就 `compact()`），而 eager open 會把這 5 萬筆全解成物件放進 RAM。`route_positions` 更重，一個 entry 就是一整天的軌跡點 `List<Map<String,dynamic>>`，乘上裝置數與 60 天。
- **成本估計。** 推論。`address_cache` 5 萬筆約 5 到 15 MB；`route_positions` 每 entry 數百 KB 到數 MB。
- **風險。** 呼叫端要跟著 await。`route_history_cache.dart:37` 目前是同步 `box.get`，改 lazy 後必須 `await`（該函式本來就是 async，一行）。
- **最小修法。** 全部換 `Hive.openLazyBox`。另外 `history_route_screen.dart:535` 的 `cleanExpiredRouteHistory` 為了讀 `cachedAt` 把整天軌跡反序列化，在開頁時就是一次尖峰，建議另開一個只存 `key -> cachedAt` 的小 box 判斷過期。
- **前提被推翻（`address_cache`）。** 原本打算一起改 lazy，但 `getAddressFromCache`（`offline_address_service.dart:113`）是**同步**函式，有三個同步呼叫點：`map_screen.dart:1047` 設初始地址、`history_route_screen.dart:1389` 的 `_isAddressCached`（在 `_scheduleAddressRequest` 的迴圈裡逐點判斷）、與 `:1405` 的 `_applyCachedAddress`（動畫 tick 路徑）。lazy box 的 `get` 是 async，要改就得把這條鏈一起改成 async，而「逐點判斷快取」正是靠同步才成立。這一項的風險不是低，所以本批不做，維持 eager。想真正省下這 5 到 15 MB，需要先把那條判斷改成「一次查一批」的非同步介面，那是一個獨立設計題。

### P0-3 兩個無界 Map

**狀態：第二批已實作。** `_prefetchedHistory` 直接刪除（它是寫入後無人讀取），`_addressFutures` 改成完成即移除。

- **位置** `lib/providers/traccar_provider.dart:54` `_prefetchedHistory`、`lib/widgets/offline_address_service.dart:123` `static final Map<String, Future<String>> _addressFutures`。
- **為什麼貴。** `_prefetchedHistory` 只在 `clearLocalSession()`（`:571`）清空，登出才回收，所以「選過幾台裝置的 1 小時軌跡」留到 App 死。`_addressFutures` 只 `putIfAbsent` 從不刪，每個 entry 釘住一個 closure 與結果字串。
- **成本估計。** 推論。`_prefetchedHistory` 每台裝置 1 小時約 360 個 `api.Position`（10 秒一筆，含 attributes），數十 KB 起，30 台數 MB；`_addressFutures` 成長慢但無上界。
- **風險。** `_prefetchedHistory` 夾帶過期語意（`:675` 的 `containsKey` 擋掉重抓，資料可能是舊的），加時間戳淘汰會改變「是否重抓」的時機。保守做法是只在超過 N 台時淘汰最久未用，命中語意不動。
- **最小修法。** `_addressFutures` 用 `whenComplete` 移除已完成項（持久快取在 `address_cache` box，移除不會重算）。
- **實際做法比原本的建議更省。** 我原本建議把 `_prefetchedHistory` 包成「id → (資料, 抓取時間)」再加淘汰。實際上 `prefetchedHistory` 這個 getter 在整個 repo 沒有任何讀者（只有 `traccar_provider.dart:685` 寫入、`:571` 清空、`map_screen.dart:1069` 觸發），也就是每次選裝置都會多打一次 `GET /positions` 把 1 小時軌跡存進一個沒人看的 Map。所以正確的做法是刪掉，不是加時間戳。這也順手少掉一次由 prefetch 完成觸發的 `notifyListeners()` 重建。

### P0-4 20 MB 離線地址資料庫在開地圖頁時全量載入並複製

**狀態：第二批已實作。**

- **位置** `lib/widgets/offline_address_service.dart:92-98`，觸發點 `lib/screens/map_screen.dart:128` 與 `lib/screens/history_route_screen.dart:320`（後者是 `initState` 直接呼叫，不 await）。
  ```dart
  if (!(await databaseExists(path))) {
    ByteData data = await rootBundle.load("assets/sqldb/$dbName");   // :93
    List<int> bytes = data.buffer.asUint8List(...);
    await File(path).writeAsBytes(bytes, flush: true);                // :95
  }
  _db = await openDatabase(path, readOnly: true);                     // :98
  ```
- **為什麼貴（實測基礎）。** APK 內這個資產是壓縮存放（20,774,912 → 4,762,202），所以 `rootBundle.load` 必須把 20.8 MB 解壓進 heap 換成一個 `ByteData`，再寫 20.8 MB 並 `fsync`。等於一次 20.8 MB 的暫時 RSS 加 20.8 MB 的磁碟副本。
- **已經正確的部分。** 只有 `my` 語系會走這條路（`_getDbName` 在 `:68-73` 對其他語言回傳 null），所以多數使用者不會付這筆成本。
- **不受影響的部分。** 查詢本身沒問題。schema 用 `WITHOUT ROWID` 且 `gh` 是主鍵前導欄，兩種查詢形狀（`:196` 的 `IN`、`:207` 的 `BETWEEN`）都吃得到索引；`PRAGMA page_count` = 5072×4096，`freelist_count` = 0，檔案沒有膨脹空間可回收。
- **成本估計。** 尖峰 RSS 20.8 MB 為實測（資產大小與壓縮率），首次複製的 CPU 300 到 800 ms 為推論。`_db` 開著常駐的 page cache 只有數百 KB，不是 20 MB。
- **風險。** 低。`databaseExists`（`:92`）已經守住「只複製一次」，不要動這個語意。
- **最小修法。** 兩步。一，把 `map_screen.dart:128` 的 `initDatabase()` 移到 `addPostFrameCallback` 或 `SchedulerBinding.scheduleTask(..., Priority.idle)`，讓它不要跟首幀搶；更好的做法是等真的要查地址時才複製。二，寫到 `path.part` 再 `File.rename`，原子且省掉 `flush: true` 的第二次寫入。

### P0-5 標籤圖磚的 `Picture` 與 `Image` 沒有釋放

**狀態：第一批已實作。**

- **位置** `lib/services/marker_icon_service.dart:136-144`。取完 `pngBytes` 後 `img` 與 `picture` 都沒有 `dispose()`。
- **為什麼貴。** `ui.Image` 是原生 Skia 記憶體，Dart GC 看不到它的壓力。每次換圖層樣式都會重畫所有裝置標籤（`map_screen.dart:269` 清空 `_loadedIcons`），舊 image 只能等 finalizer。
- **成本估計。** 推論。每張 12 到 40 KB，乘裝置數乘樣式切換次數，尖峰型。
- **風險。** 無。回傳的 `Uint8List` 已是拷貝。
- **最小修法。** `img.dispose(); picture.dispose();`。

---

## 5. P1 CPU 與耗電：行為與畫面都不變

### P1-1 通知頁整頁訂閱 provider，且每筆事件配一個新 `Set`

**狀態：第三批部分實作。** 每筆事件的 `Set` 已消除，整頁訂閱的拆解還沒做。

- **位置** `lib/screens/notifications_screen.dart:166` `Provider.of<TraccarProvider>(context)`（預設 listen）、`:171-173` `.where((e) => _isEventVisible(e, provider))`、`:64` 在 `_isEventVisible` 內 `provider.getServerEventTypes()`，而後者（`lib/providers/traccar_provider.dart:525`）每次 `where().map().toSet()`。
- **為什麼貴。** 每一包位置都重建整頁（含 `BackdropFilter` 與漸層），並重跑最多 1000 筆事件的過濾；`getServerEventTypes()` 在逐筆判斷裡，於是每筆事件都重建同一個 Set。
- **成本估計。** 推論。封包 1 到 5 Hz，即每秒 1 到 5 次「全頁 + 1000 筆過濾 + 1000 次 Set 配置」。
- **風險。** 無，過濾結果完全相同。
- **最小修法。** 把 `final serverTypes = provider.getServerEventTypes();` 提到 `.where` 外，`_isEventVisible` 收這個 Set。再用 `Selector` 或只包住 `ListView` 的 `Consumer`，讓 AppBar 與漸層不再重建。

### P1-2 地圖頁底部控制項每包重算並重建玻璃容器

**狀態：第三批已實作。**

- **位置** `lib/screens/map_screen.dart:1621-1622` 的 `Consumer<TraccarProvider>` → `_buildBottomControls(provider, _currentDevice)`，其中 `:524` 每次 `_navigableDevices(...)`，`:519`、`:513` 各一次 `indexWhere`。
- **為什麼貴。** 這塊顯示的東西（裝置名、序號/總數、跟隨狀態）只在裝置清單或選中裝置變動時才變，卻跟著位置封包重建；裡面是 `GlassContainer(platformViewBackdrop: true)`（`:1675-1682`），重建等於重做一次玻璃合成。
- **成本估計。** 推論。重建頻率等於封包頻率，每次含一次線性掃描與一次玻璃容器重建。
- **風險。** 需確認顯示值只依賴「可導覽裝置 id 集合 + 目前裝置 id」。照現有 code 是這樣。
- **最小修法。** 改 `context.select`，key 取 `Object.hash(Object.hashAll(ids), 目前裝置 id)`，key 沒變就不重建。同區塊的 `:1611` `_DataUpdateListener` 是正確設計，不要動。

### P1-3 軌跡回放面板跟著 60 Hz 動畫每秒重建 60 次

**狀態：第三批已實作**（只做索引節流，formatter 快取被推翻，見下）。

- **位置** `lib/screens/history_route_screen.dart:1517-1541` 每格寫 `_playbackPositionRx.value`；`:1895-1905` 的 `Obx` 每次呼叫都 `DateFormat('HH:mm:ss')`；`:2017-2021` 另一個 `Obx` 用 `DateFormat('MM/dd HH:mm:ss')`。
- **為什麼貴。** 顯示的時間與速度是「索引」的函數，索引一秒只跳幾格，widget 卻每秒重建 60 次，每次重新編譯 `DateFormat`。
- **成本估計。** 實測（§2.2，本機 JIT）。每次新建 `DateFormat` 比重用多約 70 µs，60 Hz 等於每秒 4.2 ms 純格式化垃圾，10 分鐘回放約 2.5 秒純 CPU；再加每格兩個 `Row`/`Column` 重建與文字排版。AOT 絕對值不同，比例一致。
- **風險。** 渲染字串只依賴 index，用「index 變了才通知」可做到像素相同。
- **最小修法。** 加 `_shownIndexRx`，index 真的變時才更新，兩個 stats `Obx` 改讀它（`Slider` 保持讀 `_playbackPositionRx`）。
- **formatter 快取被推翻。** 原本建議把兩個 `DateFormat` 提成 `static final`。但 `DateFormat` 在建構時綁定當下 locale，而這支 App 允許在執行期切換語言（`LocalizationService.saveLocale`），靜態快取的 formatter 會繼續用舊語系的月份與星期名稱。`HH:mm:ss` 這種純數字格式看不出差異，但 `yMMMd`、`EEEE` 之類會錯。索引節流已經把建構次數從每秒 60 次降到約每秒 3 次，省下的不值得換一個潛在的語系 bug。

### P1-4 裝置卡每張一個 1 秒計時器，加上每次定位都新開位址 Future 再 `setState` 整頁

- **位置** `lib/screens/device_list_screen.dart:618-620`（ACC 開啟且停等時每卡 1 秒 ticker）、`:574`（每分鐘一個）、`:406` `FutureBuilder<String>(future: _getAddressAsync(...))`，key 是五位小數座標（`:402`），解析完 `:412` 對整個 State `setState`。
- **為什麼貴。** 重建的是徽章而非整張卡，這點先說清楚免得高估。真正的問題在 `:412`，一次位址回來就重繪搜尋列、篩選計數與所有卡片；而每次 GPS 新座標又會排一個新查詢進 Nominatim 串行佇列（見 P1-5）。
- **成本估計。** 推論。裝置數 × 定位頻率 = 每秒 2 到 20 次清單級重建，且與看得到的內容無關。
- **風險。** 顯示值不變。注意保留「解析失敗要重試」的現行語意。
- **最小修法。** 位址文字抽成獨立 `StatefulWidget`（只讓那一格重建），並用「進行中 Future」的 Map 去重。徽章計時器改由 `AppLifecycleListener` 在背景暫停，回前景再同步（現行每格都從 `lastUpdate` 重算，不會漂移）。

### P1-5 位址查詢鏈：先打遠端、1.5 秒串行、沒有上限

- **位置** `lib/widgets/offline_address_service.dart:158` 的 `_getRemoteAddressQueued` 排在 `:167` 的離線查詢**之前**；佇列在 `:304-309`，節流 `_minNominatimIntervalMs = 1500`（`:53`）；請求本身 `:331`，5 秒 timeout。
- **為什麼貴。** 每一次未命中的座標都先做一次 HTTPS 往返，所有查詢串在一條佇列上。20 台裝置每 10 秒一個新座標就是每 10 秒 20 個請求，佇列永遠追不上，而 `my` 語系的離線資料庫明明就在本機。這同時是 CPU、電量、流量，以及「地址顯示很慢」的來源。
- **成本估計。** 推論（呼叫次數由 code 決定）。這是本 App 最大的無線電與 CPU 消費者，遠大於其他項目。
- **風險。** **這一項會改變使用者看到的地址文字**（Nominatim 措辭與本機 DB 不同），所以它超出「功能不變」的邊界。要不要做請你決定。
- **最小修法（依風險由低到高）。**
  1. 佇列加上限，滿了就回座標 fallback（`:163-165` 已有這個 fallback），避免無限堆積。
  2. `_addressFutures` 完成即移除（同 P0-3）。
  3. 已快取或同 grid 已成功過的地點不再打遠端。
  4. 只有在你要接受地址文字變動時，才把遠端查詢移到離線查詢之後。

### P1-6 儀表板每包重建 `BackdropFilter`

- **位置** `lib/screens/home/dashboard_screen.dart:19` 整頁 `Provider.of`，`:51-56` AppBar 內 `BackdropFilter`。
- **為什麼貴。** 計數與告警清單的變化頻率是「裝置上下線」，比位置封包低一到兩個數量級，卻用封包頻率驅動整頁重建，連高斯模糊都重做。
- **成本估計。** 推論。每秒 1 到 5 次整頁重建加一次模糊區域重繪，GPU 主導。
- **風險。** 無，資料來源不變。
- **最小修法。** 抽出 `_StatusCounts` 與 `_AlarmList` 兩個各用 `Selector` 的小 widget，Scaffold/AppBar/漸層留在不會重建的層。

### P1-7 相機事件每次配一個 `Timer`，且 release 仍在寫 log

**狀態：第三批只做了一半。** 全域 log 靜音已做；debounce 的 Timer 配置維持原樣，因為原來的修法被推翻（見下）。

- **位置** `lib/screens/map_screen.dart:1508-1515` `onCameraMove` 內 `cancel()` 後立刻新建 `Timer`；`:1530` `debugPrint('Map zoom: ...')`；同樣的 debounce 樣式在 `lib/screens/history_route_screen.dart:1667-1672`。
- **為什麼貴。** `onCameraMove` 在平移與跟隨動畫期間逐幀回呼，等於每秒約 60 次 Timer 配置與取消。`debugPrint` **不會在 release 被編譯掉**（`packages/flutter/lib/src/foundation/print.dart:50` 顯示它只是被指派成 `debugPrintThrottled`），全 repo 共 103 處呼叫點，其中 `traccar_provider.dart` 有 14 處，包含 20 秒體檢與 websocket 錯誤路徑會走到的分支。
- **成本估計。** 推論。每秒約 60 次小物件配置（僅相機移動時）；log 成本小但持續，表現在 logcat 抖動。
- **風險。** 若只在 `_zoomDebounce == null` 時建立，存檔時機會從「停止後 300 ms」變成「手勢中每 300 ms 一次」，**最終存入值相同**。
- **最小修法。** 在 `main()` 用 `kReleaseMode` 守衛把 `debugPrint` 換成空函式，一行覆蓋全 repo 的 103 處呼叫點。
- **「只在 timer 為 null 時建立」被推翻。** 我在上面的風險欄寫「最終存入值相同」，這是錯的。原本每一幀 `cancel()` 再新建，timer 在**最後一次**相機移動之後 300 ms 才觸發，寫入的是手勢結束的位置。若改成「null 才建立」，timer 在手勢**第一幀**就建好，300 ms 後寫入的是手勢起點的位置，之後整個平移期間都不會再寫。結果是存到錯的縮放值。正確做法是把寫入搬到 `onCameraIdle`，但那樣要確認每個程式化移動都會觸發 idle，風險不對等於收益（每秒 60 個小物件的配置）。所以維持原樣，只留下 log 那一項。

### P1-8 軌跡頁為兩個座標點建了整條 `List<LatLng>`

**狀態：第三批已實作。**

- **位置** `lib/screens/history_route_screen.dart:711`，而結果只在 `:743-744` 用到 `first` 與 `last`。
- **為什麼貴。** 每點一個 `LatLng`，兩萬點的一天約 700 KB 垃圾，而換顏色模式（`:984`）、換樣式（`:400`）、換日期都會重跑。
- **成本估計。** 推論。尖峰型，非逐幀。
- **風險。** 無，兩個值完全相同。
- **最小修法。** 直接算 `first`/`last` 兩個 `LatLng`。

### P1-9 軌跡清理與 Hive JSON 編碼在 UI isolate

**狀態：第二批已實作。**

- **位置** `lib/screens/history_route_screen.dart:635` `PositionCleaner.clean(...)`、`:640` `RoutePositionsHive.toJsonList(...)` 後 `put`。
- **為什麼貴。** `clean` 對每點配 `_TimedPosition`、排序、去離群值時做三角函式；`toJsonList` 每點產一個約 15 key 的 `Map`。一萬點就是數十 MB 暫時物件，全在產生第一幀之前。
- **成本估計。** 推論。每個未命中的日期一次，20 到 80 ms 卡頓加上 GC 尖峰。
- **風險。** 需確認 `api.Position` 可跨 isolate（純資料類別，可以），清理結果要逐位元相同。
- **最小修法。** 用 `compute`/`Isolate.run` 移到背景。這頁已經對 GeoJSON 用過 `compute`（`:715-719`），照同一模式。
- **誠實的界線。** isolate 訊息會深拷貝整份 `List<api.Position>`，所以這個改動把卡頓移出影格，總 CPU **未必**變少。真正要減工作量的方向是「快取命中時不要再清一次」，但那一條我查完之後判定不成立，理由見下。
- **另一條被推翻的路。** 快取裡存的已經是清理過的軌跡，所以「命中快取時不要再 `clean()` 一次」看起來是免費的。但 `PositionCleaner.clean` **不是幂等的**，第 5 步移除離群點之後，原本隔著一個壞點的兩個鄰居會變成新的相鄰對，再跑一次可能再被判成不可能速度。也就是說現行的二次清理會讓軌跡比只清一次更短。跳過它會改變畫面，所以維持原樣。

### P1-10 報表頁的 `DataTable` 與骨架動畫

- **位置** `lib/screens/reports/summary_report_screen.dart:592` `DataTable`，rows 在 `:653` 每 build 重建；`lib/widgets/skeleton.dart:16` 每個 `SkeletonBox` 一個 `AnimationController`，`:45` 每幀重建 `BoxDecoration`，`:39` 在 builder 內 `Theme.of`。
- **為什麼貴。** `DataTable` 會建出所有列並做一次 intrinsic 寬度量測，「全部裝置」乘整月約 1500 格，為顯示幾十格建出數千 widget。骨架是 24 個獨立 ticker 每幀各自配置。
- **成本估計。** 推論。報表首幀重卡頓與載入期間持續 CPU。
- **風險。** 把 `DataRow` 快取到欄位**畫面完全不變**；改 `ListView.builder` **會**改變欄寬與 `TableBorder`，不建議。
- **最小修法。** rows 在 `setState` 內建一次存欄位；骨架改單一 `AnimationController` 往下傳，`Theme.of` 移出 builder。

### P1-11 20 秒一次的伺服器體檢

- **位置** `lib/providers/traccar_provider.dart:91` `Timer.periodic(const Duration(seconds: 20), (_) => _checkServerHealth());`
- **為什麼貴。** 每 20 秒一次 `GET /session`，每小時 180 次無線電喚醒；websocket 若還在收封包就已證明伺服器可達。
- **成本估計。** 推論。CPU 很少，耗電主要來自無線電。
- **風險。** 只在「socket 活著但 REST 掛掉」時延後偵測。保持 401/登出偵測路徑不動即可。
- **最小修法。** 記錄 `_lastSocketFrameAt`，區間內有封包且 `_serverFailCount == 0` 就跳過這次 ping。

### P1-12 同一個 summary 端點抓兩次，但兩次的「今天」定義不一樣

- **位置** `lib/providers/traccar_provider.dart:222` 的 `fetchTodayMileage`（`:662` 由 `fetchInitialData` 觸發，填 `_todayMileageKm`）與 `:177` 的 `fetchMileageData`（`lib/screens/device_list_screen.dart:102` 以 `_mileageDays` 呼叫，填 `_mileageMap`）。兩者都打 `GET /reports/summary`。
- **為什麼貴。** 每次刷新與回到前景各多一次請求、一次 JSON 解碼、一輪通知，兩個 map 分別給儀表板與裝置清單用，內容高度重疊。
- **先看清楚差異。** 兩者的日界線慣例不同。`fetchTodayMileage` 取**本地**日曆日再轉 UTC（`:231-233`），`fetchMileageData` 取 `DateTime.now().toUtc()` 的**UTC**日曆日（`:191-192`）。在 UTC+6:30 這類時區，同一天抓到的距離數字本來就會有數小時的差異。
- **成本估計。** 推論。每次刷新浪費一個請求。
- **風險。** **合併會改變其中一處顯示的數字**，所以「`mileageDays == 1` 時直接複製 `_todayMileageKm`」不是零風險改動。要做到真正的行為等價，得先決定「今天」是本地日還是 UTC 日，那是一個產品決定，不是重構。
- **最小修法（保守）。** 保持兩次請求，但把它們排在同一個 refresh 流程裡共用一次 `notifyListeners`，避免兩輪通知。要省掉請求，就先統一兩處的日界線慣例，再讓 `fetchMileageData(1)` 直接複製 `_todayMileageKm`。

---

## 6. P2 體積與啟動

### P2-1 Android release 設定：實測已經正確，不要動

我原本從 `android/app/build.gradle.kts:36-43` 讀到沒有 `isMinifyEnabled` / `isShrinkResources` 就以為沒開，**這個猜測是錯的**。建置產物反駁了它。

```
build/app/outputs/mapping/release/usage.txt   3,622,167 bytes（R8 有跑）
build/app/outputs/mapping/release/seeds.txt   1,214,518 bytes
build/app/outputs/apk/release/output-metadata.json  三個 ONE_OF_MANY，按 ABI 切分
MaterialIcons-Regular.otf 22,280 bytes（1.6 MB 字型 tree-shake 後）
lib/arm64-v8a 原生庫全部 Stored（mmap，不解壓）
```

結論是不用為體積改任何 Gradle 設定。唯一建議是**把意圖寫死**，在 `release` 區塊顯式加 `isMinifyEnabled = true`、`isShrinkResources = true`，免得未來工具鏈預設改變時靜默退化。這是防禦性動作，不是優化。

### P2-2 開 `--obfuscate --split-debug-info`

- **現況。** repo 內沒有任何 `*.symbols`，`strings libapp.so` 仍可讀到 `OfflineAddressService` 這類識別字。
- **為什麼值得。** 幾百 KB 的 `libapp.so`，加上 release crash 堆疊不外洩識別字。行為與畫面完全不變。
- **風險。** 必須把 symbols 歸檔，否則以後無法符號化。這是流程風險，不是程式風險。

### P2-3 `LiquidGlassWidgets.initialize()` 卡在首幀之前

- **位置** `lib/main.dart:47`，在 `runApp` 之前 `await`。
- **為什麼貴。** 它會預熱五個 `FragmentProgram`（最大一支 shader 原始碼 1,241,712 bytes）並 `precacheShaders`，全在 `ensureInitialized()` 到首幀之間。
- **成本估計。** 推論。啟動 50 到 150 ms。
- **風險。** 不 await 可能讓第一個玻璃元件先畫一幀佔位，也就是等於白閃一下，而預熱存在的目的正是避免它。
- **最小修法。** 本輪先不動。若要動，只能改成「不 await 但保留呼叫」，且要實際看過第一幀才決定。

### P2-4 死資產與誤導的設定（極小，但零風險）

- `lib/providers/map_style_provider.dart:23` 的 `fiord.json`（22,233 bytes）在執行期不可達。`_loadPreference`（`:39-41`）把任何不是 bright 或 satellite 的偏好值夾回 bright，`toggleMapType`（`:78-84`）只在這兩者間切換，而 `setMapType` 在 `lib/` 內沒有任何外部呼叫者。所以 `getStyle` 的 `terrain` 分支（`:69`）永遠不會被走到。
- `pubspec.yaml` 的 `flutter_native_splash` 指向 `assets/branding/appstore.png`，而 `android/app/src/main/res/` 只有預設的 `launch_background.xml`，這個設定沒有生效。改或不改都無害，但別以為它在管事。

### P2-5 65 個語系：實測顯示不是記憶體問題

- **位置** `lib/services/localization_service.dart:210-275` 的 `keys` 回傳 65 組 `const` Map，來源 `lib/l10n/*.dart`（1.9 MB 原始碼、約 945 個 key × 64 語言 ≈ 695 KB 字串資料）。
- **實測。** 兩張 intl 表暖機後建置只花 0 到 1 ms、RSS +48 到 +740 KiB（§2.2）。const 字串在 AOT snapshot 的唯讀段，可 mmap 按需分頁。
- **判斷。** 這是 **APK 體積與 `libapp.so` 大小**的問題（推論，約 1 到 1.5 MB），不是常駐 heap 的問題。`initializeDateFormatting()` 想瘦身只能用 `initializeDateFormattingCustom` 針對當前 locale 建表，但收益上限就是那 0.7 MB，卻要動到 `main()` 的初始化順序，而生成的 API client 在 splash 之後第一個請求就會解析日期。**風險大於收益，不建議做。**

---

## 7. 看起來貴、其實不貴（請不要動）

這節存在的目的是避免之後有人「順手優化」反而出事。

| 項目 | 位置 | 為什麼不用動 |
| --- | --- | --- |
| 一包觸發三次 `notifyListeners` | `lib/providers/traccar_provider.dart:406`、`:426`、`:449` | `markNeedsBuild` 在同一幀內合併，三次通知只產生**一次**重建。該修的是訂閱範圍（§5），不是通知次數 |
| `timeago` 一次註冊 38 語系 | `lib/main.dart:77-116` | 檢查過 `timeago-3.7.1` 的 Messages 類別，只有回傳字串的方法，沒有 RegExp 或大表，38 個實例幾 KB |
| `initializeDateFormatting()` 無參數建全表 | `lib/main.dart:60` | 實測暖機後 0 到 1 ms、0.7 MB 以內。冷啟動看起來 250 ms 是 JIT 成本，不是手機成本 |
| `List.from` / `[...list]` 複製 | `traccar_provider.dart:392`、`:430` | 複製的是每包進來的小批次（數個到數十個），不是整份清單 |
| sqflite 沒索引 | `lib/storage/*_helper.dart`、地址 DB | 都走主鍵；地址 DB 是 `WITHOUT ROWID` 且 `gh` 為前導主鍵，`IN` 與 `BETWEEN` 都吃得到 |
| Hive box 開著沒 `close()` | 全域 | 開著比重開便宜。問題在 lazy 與否，不在 close |
| `_events` 上限 1000 | `traccar_provider.dart:442-447` | 已有界，`removeRange` 成本可忽略 |
| 地圖 marker 每包更新 | `lib/screens/map_screen.dart:702-751` | 已批次化（一次 `addSymbols`），只在不同時才 `updateSymbol`，設計正確 |
| 已播放軌跡推送 | `lib/src/utils/played_prefix.dart:11`、`PublishBudget(100)` | 雙重上限且 10 Hz 而非 60 Hz |
| 三頁 tab 常駐 | `lib/screens/main_screen.dart:22` | `CupertinoTabScaffold` 既有行為，offstage 不重繪 |
| `deferred` 載入報表頁 | `lib/main.dart:22-32` | Android/iOS 的 AOT release **忽略** deferred loading，標成 `deferred as` 只是改變可讀性 |
| 圖片資產解析度 | `assets/images/` 共 912 KB | 最大是 `logo.png` 512×512 / 17 KB（180 dp 在 3× 只需 540 px），唯一異常是 `marker_animal_offline.png` 167×167 對比其他 32×32。不值得花時間 |

順帶一提（超出記憶體與 CPU 範圍，但既然看到了）：`android/app/build.gradle.kts:36` 的 release 用 `signingConfigs.getByName("debug")` 簽署，正式上架前要換掉。

---

## 8. 建議執行順序與驗證

分三批，每批都能獨立驗收。

| 批次 | 內容 | 預期收益 | 風險 | 驗證方式 |
| --- | --- | --- | --- | --- |
| 第一批（已完成） | P0-1、P0-2、P0-5 | 常駐記憶體明顯下降，長尾成長消失 | 低（純 lazy 化與 dispose） | 地圖頁與裝置清單各開 30 分鐘，DevTools Memory 曲線應從「單調上升」變「持平」 |
| 第二批（已完成） | P0-3、P0-4、P1-9 | 尖峰記憶體與首頁卡頓 | 低到中 | 選 30 台裝置後看 RSS；首次緬甸語地址查詢的記憶體尖峰 |
| 第三批（進行中，已完成 P1-1 部分、P1-2、P1-3、P1-7 部分、P1-8） | P1-1 到 P1-8、P1-10、P1-11 | 待機 CPU 與耗電 | 中（每頁需比對畫面） | 每頁改完立刻截圖對照，加上 Performance 錄 10 秒看 rebuild 次數 |
| 待你決定 | P1-5 第 4 步（地址文字會變）、P1-12（要先定「今天」的日界線）、P2-2、P2-4 | 最大宗無線電流量 | 高（改功能或改流程） | 需要你點頭才動 |

### 量測步驟（腳本已備好，實測跑通）

用 `scripts/measure_memory.sh` 取 Android 自己的 PSS 記帳。它每 N 秒呼叫一次 `dumpsys meminfo`，寫成 CSV，結束時印出 MB/min 斜率。CSV 落在 `build/memory/`（已在 gitignore 內）。

```bash
# 1. 定義一次可重現的劇本，前後兩次必須完全一樣
#    例：啟動 → 停在地圖 3 分鐘 → 沿固定路線平移縮放 → 進裝置清單 2 分鐘
#        → 開某台裝置某天的軌跡回放 3 分鐘 → 回地圖 2 分鐘
adb shell am force-stop com.example.trabcdefg     # 每次從乾淨狀態開始

# 2. 開始取樣（第二個參數是取樣間隔秒數，第四個是總時長秒數）
scripts/measure_memory.sh before 5 com.example.trabcdefg 600

# 3. 裝上新版本，跑同一個劇本再量一次
scripts/measure_memory.sh after 5 com.example.trabcdefg 600
```

**判讀哪幾欄。** 實測的地圖頁閒置參考點（改動前的 1.0.38，Redmi 2312DRAABC）是 `TOTAL PSS` 約 384 MB，其中 `graphics` 193 MB、`native` 97 MB、`private_other` 31 MB、`java` 4 MB。啟動到地圖初始化完成之間會先經過約 160 MB，初始化期間還有一次約 480 MB 的暫態尖峰，都會自己回落，不要拿那兩段當基準。

- `total_pss_kb` 是總量，看它的**斜率**而不是單點值。
- `native_kb` 與 `private_other_kb` 是 Dart heap 主要落點。Hive 把 entry 全解進記憶體時，成長會出現在這裡。
- `graphics_kb` 是 GL 表面與繪製快取，主要由地圖引擎一次性配置。第一次上地圖時它會從約 57 MB 跳到 193 MB，那是正常的初始化，不是洩漏，也不用期待它變小。**判讀 P0-1（圖磚快取）要看 `native_kb` 與 `private_other_kb`**，圖磚位元組是 Dart heap 裡的 `Uint8List`，不會算進 `graphics`。這一條我最初寫反了，實測後更正。

**注意事項。**

- 取樣間隔是「至少」N 秒。`dumpsys meminfo` 本身約 1.5 秒，所以間隔 5 會變成約 6.5 秒一次。
- 一定要用 release 或 profile 建置。debug 建置的數字不可比。
- 目前裝在裝置上的是改動前的版本（1.0.38，11-15 建置），所以現在跑出來的就是 `before`。
- 圖磚快取的磁碟佔用只有 debuggable 建置看得到：`adb shell run-as com.example.trabcdefg du -sb files/app_flutter`。

**歸因用 DevTools，不用它做驗收。** 要確認某段記憶體是 Dart heap 還是原生繪圖，才需要 `flutter run --profile` 配 DevTools 的 Memory 頁取 snapshot。RSS 曲線的驗收仍以 `dumpsys` 為準，因為那是使用者的真實情境。

**畫面不變的證據。** 地圖頁、裝置清單、通知頁、軌跡回放各截一張改前改後，逐像素比對。

### 一句提醒

第一批做完就會有明顯差別，而且幾乎不可能弄壞畫面。第三批要一頁一頁來，一頁一個 commit，壞了只回退一頁。

---

## 9. 檔案索引

改動會落在這些檔案。

- `lib/services/tile_cache_service.dart`，P0-1（lazy、統一 key、上限）
- `lib/screens/settings/geofences_screen.dart`，P0-1（重複的 tile service）
- `lib/screens/map_screen.dart`，P0-1（移除無用 init）、P0-4、P1-2、P1-7
- `lib/widgets/offline_address_service.dart`，P0-2、P0-3、P0-4、P1-5
- `lib/screens/history_route_screen.dart`，P0-2、P1-3、P1-8、P1-9
- `lib/services/route_history_cache.dart`，P0-2
- `lib/providers/traccar_provider.dart`，P0-3、P1-11、P1-12
- `lib/services/marker_icon_service.dart`，P0-5
- `lib/screens/notifications_screen.dart`，P1-1
- `lib/screens/device_list_screen.dart`，P1-4
- `lib/screens/home/dashboard_screen.dart`，P1-6
- `lib/screens/reports/summary_report_screen.dart`、`lib/widgets/skeleton.dart`，P1-10
- `lib/main.dart`，P1-7 的 `debugPrint` 全域守衛（但**不要**動國際化初始化）
- `test/tile_cache_service_test.dart`，P0-1 的淘汰行為測試（新增）
- `scripts/measure_memory.sh`，PSS 取樣與斜率摘要（新增，§8 在用）

**不要改**：`lib/l10n/*`、`lib/main.dart:60` 的 `initializeDateFormatting`、地圖 marker 更新邏輯、`lib/src/utils/played_prefix.dart`、Android Gradle 縮減設定。

---

## 10. 執行記錄

### 第一批（已完成，2026 本輪）

| 項目 | 做了什麼 | 檔案 |
| --- | --- | --- |
| P0-1 | `openBox` → `openLazyBox`，上限 2000 張，超過時依本次工作階段的讀寫順序淘汰最久沒用到的一批（降到 1800，避免每次存圖都重排） | `lib/services/tile_cache_service.dart` |
| P0-1 | 刪掉 `geofences_screen.dart` 裡那份重複的 `TileCacheService` / `CachedNetworkImageProvider` / `HiveTileProvider`（83 行），改用共用 service，key 統一成完整 URL | `lib/screens/settings/geofences_screen.dart` |
| P0-1 | 移除沒有任何用途的 `_cacheService.init()`；首頁 spinner 的條件改成「地址資料庫初始化完成」而不是「圖磚快取載完」 | `lib/screens/map_screen.dart` |
| P0-2 | `route_positions` 與 `daily_summaries` 全數改 lazy，5 個 `get` 呼叫點補 `await` | `lib/screens/history_route_screen.dart`、`lib/screens/monthly_mileage_screen.dart`、`lib/services/route_history_cache.dart` |
| P0-2 | `address_cache` **暫緩**（同步讀取鏈，見 P0-2 的「前提被推翻」） | 無 |
| P0-5 | `toByteData` 之後 `img.dispose()` 與 `picture.dispose()`，用 `finally` 保證例外時也釋放 | `lib/services/marker_icon_service.dart` |
| 驗證 | 新增 `test/tile_cache_service_test.dart`（3 個案例：讀回位元組一致、缺圖回 null、達上限後淘汰最久未用） | `test/tile_cache_service_test.dart` |

**驗證結果。**

- `flutter test`：69 passed（原本 66，加上新增 3 個）。`marker_label_icon_test.dart` 會解碼 `buildLabelPng` 回傳的 PNG，正好覆蓋 P0-5 的 dispose 改動。
- `dart analyze lib test`：0 error、0 warning；50 個 info 全是既有的 deprecation 與 `avoid_print`，與本次改動無關。

**新發現（未做，留給下一批）。** `lib/screens/reports/summary_report_screen.dart:189` 的 `summary_reports` box 也是 eager open（`Hive.box<ReportSummaryHive>` / `Hive.openBox<ReportSummaryHive>`），性質與 P0-2 相同。它不在原本的清單裡，下一批可以順手處理，但要先確認沒有其他同步讀取點。

### 第二批（已完成，本輪）

| 項目 | 做了什麼 | 檔案 |
| --- | --- | --- |
| P0-3 | 刪掉 `_prefetchedHistory` 與 `prefetchDeviceHistory` 整個死路徑（每次選裝置都打一次 `GET /positions`，結果無人讀取） | `lib/providers/traccar_provider.dart`、`lib/screens/map_screen.dart` |
| P0-3 | `_addressFutures` 改成 `whenComplete` 移除已完成項，只共享進行中的查詢 | `lib/widgets/offline_address_service.dart` |
| P0-4 | 20 MB 資料庫改成先寫 `$path.part` 再 rename，中斷的複製不會被下次啟動誤判為完整檔 | `lib/widgets/offline_address_service.dart` |
| P0-4 | 地圖頁不再等資料庫初始化，`_isCacheInitialized` 這個閘門與它的 spinner 分支一併移除（它唯一的等待對象已經在第一批拆掉） | `lib/screens/map_screen.dart` |
| P1-9 | 軌跡清理與 JSON 編碼移到背景 isolate，門檻 1000 點（與同檔既有的 GeoJSON 路徑一致），並依照是否需要寫快取決定要不要編碼 | `lib/screens/history_route_screen.dart` |

**驗證結果。**

- `flutter test`：69 passed。
- `dart analyze lib test`：0 error、0 warning，50 個 info 與改動前相同。

**這一輪沒有新增單元測試，講清楚為什麼。** 改到的四條路徑都需要裝置或網路才會走到（真實的 Nominatim 查詢、20 MB 資產複製、地圖首幀、軌跡頁載入），單元測試只能測到被我搬動的私有函式，測了等於測 `PositionCleaner` 自己。第一輪能加測試是因為圖磚淘汰是純本機邏輯。這兩項的驗收要靠 §8 的裝置量測。

### 第三批第一段（已完成，本輪）

| 項目 | 做了什麼 | 檔案 |
| --- | --- | --- |
| P1-1（部分） | `getServerEventTypes()` 從每筆事件的判斷式裡提到每次 build 一次，消除最多 1000 次 Set 配置 | `lib/screens/notifications_screen.dart` |
| P1-2 | 底部控制項的 `Consumer` 改成 `Selector`，key 取「可導覽裝置 id 與名稱」加目前裝置 id，位置封包不再重建玻璃容器 | `lib/screens/map_screen.dart` |
| P1-3 | 新增 `_shownIndexRx`，由 `_updatePlaybackUI` 這個唯一入口發布，兩個顯示時間與速度的 `Obx` 改讀它，重建頻率從 60 Hz 降到索引變化率（約 3 Hz） | `lib/screens/history_route_screen.dart` |
| P1-7（部分） | `main()` 在 `kReleaseMode` 下把 `debugPrint` 換成空函式，一次覆蓋全 repo 103 處呼叫點 | `lib/main.dart` |
| P1-8 | 起終點標記不再為整條軌跡建 `List<LatLng>`，只算兩端兩個點 | `lib/screens/history_route_screen.dart` |

**驗證結果。** `flutter test` 69 passed，`dart analyze lib test` 0 error 0 warning、50 個 info 與改動前相同。

**兩條被推翻的路。** formatter 靜態快取會踩到執行期切換語系。debounce timer 的「null 才建立」會存到錯誤的縮放值（我原本在風險欄寫的「最終值相同」是錯的）。兩條都寫進對應章節。

**第三批剩下的。** P1-1 的整頁訂閱拆解、P1-4（裝置清單的位址 widget 與計時器）、P1-6（儀表板拆訂閱）、P1-10（報表 DataTable 與骨架動畫）、P1-11（20 秒體檢）。這幾項都會動到畫面結構，建議每項一次 commit 並截圖比對。

**再下一批建議。** 照 §8 量 `before`（現在裝置上仍是改動前的 1.0.38）與 `after` 之後，再開 P1-4 之後的項目，因為它們的收益比前八項小。
