// // 1. Positron (簡潔淺色模式) - 非常適合用來凸顯彩色車輛圖標
//   static const String _positronStyle = "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json";

//   // 2. Dark Matter (酷炫深色模式) - 適合夜間使用
//   static const String _darkStyle = "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json";

//   // 3. OpenStreetMap Bright (明亮強化版)
//   static const String _osmBrightStyle = "https://tiles.openfreemap.org/styles/bright";

//   // 4. Terrain (地形等高線模式) - 使用 OpenFreeMap 提供的地形樣式
//   static const String _terrainStyle = "https://tiles.openfreemap.org/styles/topo";

//   // 5. Google Maps 混合風格 (混合衛星與路網) - 透過自定義 JSON 實作
//   static const String _hybridStyle = '''
// {
//   "version": 8,
//   "glyphs": "https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf",
//   "sources": {
//     "satellite": {
//       "type": "raster",
//       "tiles": ["https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}"],
//       "tileSize": 256
//     }
//   },
//   "layers": [
//     {
//       "id": "satellite-layer",
//       "type": "raster",
//       "source": "satellite",
//       "minzoom": 0,
//       "maxzoom": 22
//     }
//   ]
// }
// ''';


enum AppMapType {
  openStreetMap, // Will use standard OSM tiles
  satellite, // Will use an alternative satellite-like tile layer
  dark,      // Dark Matter
  terrain,   // Topo
  hybrid     // Google Hybrid
}