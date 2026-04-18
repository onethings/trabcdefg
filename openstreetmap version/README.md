# trabcdefg

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


AndroidManifest.xml should like this
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <application
        android:label="trabcdefg"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <!-- Specifies an Android theme to apply to this Activity as soon as
                 the Android process has started. This theme is visible to the user
                 while the Flutter UI initializes. After that, this theme continues
                 to determine the Window background behind the Flutter UI. -->
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="Your google map api key here" /> <!--Replace wi th your google map api key！！！-->
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <!-- Required to query activities that can process text, see:
         https://developer.android.com/training/package-visibility and
         https://developer.android.com/reference/android/content/Intent#ACTION_PROCESS_TEXT.

         In particular, this is used by the Flutter engine in io.flutter.plugin.text.ProcessTextPlugin. -->
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>



    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDeviceId', device.id!);
    await prefs.setString('selectedDeviceName', device.name!);


## Offline Reverse Geocde can use openstreetmap .osm.bpf to sperate stree name and add geohash to sqlite db.

## Street name Source are come from .osm.bpf .
## 数据来自 © OpenStreetMap 贡献者，基于 ODbL 许可。
## Contains information from OpenStreetMap which is made available here under the Open Database License (ODbL).
##  This app uses street data from © OpenStreetMap contributors. The data is processed into a derivative SQLite database format under the ODbL license.


BitRoad-LITE are
myanmar_roads_v2.db
空間解析度對比：* 城市區：約 $1.5m \times 3m$。郊區：約 $24m \times 48m$（抹除 4 位元後）。


orhter db are geohash + road name.


## 生成離線地名-----------------
# 生成緬甸語 (預計 46MB)
python3 scripts/geocoder_generator.py --lang my --out myanmar_ultra_res_my.db
# 生成英語 (預計 50MB 附近)
python3 scripts/geocoder_generator.py --lang en --out english_ultra_res.db
# 生成中文 (預計 50MB 附近)
python3 scripts/geocoder_generator.py --lang zh --out chinese_ultra_res.db

## 🚀 最新功能 (New Features)

### 導航記憶功能 (Navigation Memory)
為了提昇用戶體驗，App 會自動記憶您最後使用的分頁。
- **自動適應用戶習慣**：下次打開 App 時，會自動跳轉到您上次離開的分頁（例如：地圖、設備列表或報告）。
- **實作方式**：使用 `SharedPreferences` 持久化儲存 `last_main_tab_index`。