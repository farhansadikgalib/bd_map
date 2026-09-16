## 1.1.0

- Fresh screenshots: the drill-down sequence from division to union and one shot per map widget, captured on an iPhone and framed.
- New banner and app icon in a blue palette.
- README: a map-types row under "Show a map", the Features table moved below it, and Sreepur as the example upazila throughout the docs.
- Example app: a shared colorful palette for both maps, a lean screenshot capture flow in the integration test, and iOS deployment target 15.0 so it builds with current Xcode.

## 1.0.0

Initial release.

- `BdMap`: drill-down map from division to district, upazila and union, with animated zoom, breadcrumb navigation and an info panel.
- `BdCountryMap`: the whole country at any level, with pinch-zoom and tap-to-select. `BdUpazilaMap` is the upazila shortcut.
- `BdMapData`: your own values from a JSON file, an API response or a Dart map, shown in the info panel, a ranked `BdRegionDataList` and, optionally, as choropleth colors.
- `BdGeo`: 8 divisions, 64 districts, 544 upazilas and 5,160 unions with boundaries, English and Bangla names, and hierarchy lookups.
- `Bangladesh` and `BangladeshMap`: the classic division map with per-division colors, tooltips and tap callbacks.
- Pure Dart with no assets, plugins or network. Sample data files and a full example app included.
