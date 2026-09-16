/*
  Copyright 2026 Farhan Sadik Galib. All rights reserved.
  Use of this source code is governed by a MIT license that can be
  found in the LICENSE file.
  source: https://github.com/farhansadikgalib/bd_map
  website: https://farhansadikgalib.com
 */

import 'dart:convert';

import 'package:flutter/material.dart';

import 'bd_region.dart';

/// User data attached to the Bangladesh maps, keyed by [BdRegion.id].
///
/// Works at every administrative level — the same object can carry values
/// for divisions, districts, upazilas/thanas, and unions at once, because
/// all region ids share one namespace (`'dhaka'`, `'dhaka.gazipur'`,
/// `'dhaka.gazipur.kaliakair'`, ...).
///
/// Numeric values are automatically rendered as a choropleth: each region
/// is filled with a color interpolated between [minColor] and [maxColor]
/// according to where its value sits between the smallest and largest
/// values in [values]. Non-numeric values are shown as text only.
///
/// ```dart
/// final population = BdMapData<num>(
///   {
///     'dhaka': 44.2, 'chattagram': 33.2, 'rajshahi': 20.4, ...
///   },
///   title: 'Population',
///   format: (v) => '${v}M',
/// );
///
/// BdMap(data: population, showDataList: true)
/// ```
class BdMapData<T> {
  BdMapData(
    this.values, {
    this.title,
    this.format,
    this.colorBuilder,
    this.minColor = const Color(0xFFC8E6C9),
    this.maxColor = const Color(0xFF1B5E20),
  });

  /// Builds a dataset from a user-friendly JSON map — the easiest way to
  /// feed data into the maps. Region keys are plain **names** (English,
  /// case-insensitive, or Bangla) or region ids; no knowledge of internal
  /// ids is needed.
  ///
  /// The primary shape is the mapped tree, nested the way the country is
  /// organized — division → district → thana → union — under a `"data"`
  /// key. Each region holds its own `"value"` and its children (either
  /// directly by name, or wrapped in a `"districts"` / `"thanas"` /
  /// `"unions"` key); a child that is a plain number is just its value,
  /// and a region may carry only children with no value of its own:
  ///
  /// ```json
  /// {
  ///   "title": "Population",
  ///   "unit": "M",
  ///   "data": {
  ///     "Dhaka": {
  ///       "value": 44.2,
  ///       "Gazipur": {
  ///         "value": 3.4,
  ///         "Kaliakair": {
  ///           "value": 0.4,
  ///           "Atabaha": 0.05
  ///         }
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// Nested names are resolved among the parent's children only, so
  /// repeated names (`Sadar`...) are never ambiguous.
  ///
  /// Flat per-level sections are also accepted, for data that is already
  /// shaped as simple lists:
  ///
  /// ```json
  /// {
  ///   "divisions": { "Dhaka": 44.2, "চট্টগ্রাম": 33.2 },
  ///   "districts": { "Gazipur": 3.4 },
  ///   "upazilas":  { "Gazipur/Kaliakair": 0.4 },
  ///   "unions":    { "Gazipur/Kaliakair/Atabaha": 0.05 }
  /// }
  /// ```
  ///
  /// - `"thanas"` is accepted as an alias of `"upazilas"`.
  /// - In the flat sections, a key can be a `Parent/Child` path
  ///   (e.g. `"Dhaka/Gazipur"`) to disambiguate names that repeat across
  ///   the country. A plain ambiguous name applies to every region that
  ///   matches.
  /// - `"values"` may hold raw region-id keys of any level.
  /// - `"unit"` is appended to displayed values; whole numbers drop the
  ///   decimals (`3.0` → `3M`).
  /// - `"minColor"` / `"maxColor"` accept hex strings like `"#C8E6C9"`.
  factory BdMapData.fromJson(Map<String, dynamic> json) {
    final values = <String, T>{};

    void addResolved(String key, dynamic raw, List<BdRegion> level) {
      final value = _coerce(raw);
      if (value is! T) return;
      for (final region in _resolveKey(key, level)) {
        values[region.id] = value;
      }
    }

    void section(String name, List<BdRegion> level) {
      final map = json[name];
      if (map is Map) {
        map.forEach((k, v) => addResolved('$k', v, level));
      }
    }

    section('divisions', BdGeo.divisions);
    section('districts', BdGeo.districts);
    section('upazilas', BdGeo.upazilas);
    section('thanas', BdGeo.upazilas);
    section('unions', BdGeo.unionRegions);

    // Nested tree: division -> district -> thana -> union.
    void walkTree(BdRegion region, dynamic node) {
      if (node is! Map) {
        final value = _coerce(node);
        if (value is T) values[region.id] = value;
        return;
      }
      final children = BdGeo.childrenOf(region);
      node.forEach((rawKey, childNode) {
        final key = '$rawKey';
        if (key == 'value') {
          final value = _coerce(childNode);
          if (value is T) values[region.id] = value;
          return;
        }
        // Optional level-wrapper keys around the children map.
        if (const {'districts', 'upazilas', 'thanas', 'unions', 'children'}
                .contains(key) &&
            childNode is Map) {
          childNode.forEach((k, v) {
            for (final child in _resolveIn('$k', children)) {
              walkTree(child, v);
            }
          });
          return;
        }
        // Otherwise the key is a child region's name.
        for (final child in _resolveIn(key, children)) {
          walkTree(child, childNode);
        }
      });
    }

    final tree = json['data'];
    if (tree is Map) {
      tree.forEach((k, v) {
        for (final division in _resolveIn('$k', BdGeo.divisions)) {
          walkTree(division, v);
        }
      });
    }

    final raw = json['values'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final value = _coerce(v);
        if (value is T && BdGeo.byId('$k') != null) {
          values['$k'] = value;
        }
      });
    }

    final unit = json['unit'] as String?;
    return BdMapData<T>(
      values,
      title: json['title'] as String?,
      format: unit == null
          ? (T == num || T == int || T == double
              ? (v) => _trimNum(v as num)
              : null)
          : (v) => v is num ? '${_trimNum(v)}$unit' : '$v$unit',
      minColor: _parseHex(json['minColor']) ?? const Color(0xFFC8E6C9),
      maxColor: _parseHex(json['maxColor']) ?? const Color(0xFF1B5E20),
    );
  }

  /// Builds a dataset from a JSON **list** — the shape most APIs return:
  ///
  /// ```dart
  /// // e.g. the decoded body of an HTTP response:
  /// // [
  /// //   {"district": "Gazipur", "value": 3.4},
  /// //   {"district": "Cumilla", "value": 5.6},
  /// //   {"division": "Dhaka", "thana": "Savar", "population": 1.4}
  /// // ]
  /// final data = BdMapData<num>.fromList(response, title: 'Population');
  /// ```
  ///
  /// Each item names its region with a level field — `"division"`,
  /// `"district"`, `"thana"` / `"upazila"`, or `"union"` — where the
  /// deepest field present is the target and any shallower ones qualify
  /// it (so `{"division": "Dhaka", "thana": "Savar"}` resolves Savar
  /// inside Dhaka). Items may instead use a generic `"name"`, `"region"`,
  /// or `"id"` field, matched at any level.
  ///
  /// The value is read from [valueKey] when given, otherwise from the
  /// first of `value` / `count` / `total` / `amount` / `population` /
  /// `percentage`, otherwise from the first numeric field left over.
  /// Pass [regionKey] to name the region field explicitly.
  factory BdMapData.fromList(
    List<dynamic> items, {
    String? regionKey,
    String? valueKey,
    String? title,
    String? unit,
    Color minColor = const Color(0xFFC8E6C9),
    Color maxColor = const Color(0xFF1B5E20),
  }) {
    final values = <String, T>{};
    const levelFields = <String, int>{
      'division': 0,
      'district': 1,
      'upazila': 2,
      'thana': 2,
      'union': 3,
    };
    const valueFields = [
      'value',
      'count',
      'total',
      'amount',
      'population',
      'percentage',
    ];
    final levels = <List<BdRegion>>[
      BdGeo.divisions,
      BdGeo.districts,
      BdGeo.upazilas,
      BdGeo.unionRegions,
    ];

    for (final raw in items) {
      if (raw is! Map) continue;
      final item = raw.map((k, v) => MapEntry('$k'.toLowerCase(), v));

      // --- find the region.
      List<BdRegion> matches = const [];
      if (regionKey != null) {
        final key = item[regionKey.toLowerCase()];
        if (key != null) {
          for (final level in levels) {
            matches = _resolveKey('$key', level);
            if (matches.isNotEmpty) break;
          }
        }
      } else {
        // Deepest level field present is the target; shallower ones
        // qualify the path.
        var deepest = -1;
        for (final f in levelFields.keys) {
          if (item[f] != null && levelFields[f]! > deepest) {
            deepest = levelFields[f]!;
          }
        }
        if (deepest >= 0) {
          final path = <String>[
            for (final f in const [
              'division',
              'district',
              'upazila',
              'thana',
              'union'
            ])
              if (item[f] != null && levelFields[f]! <= deepest) '${item[f]}',
          ];
          matches = _resolveKey(path.join('/'), levels[deepest]);
        } else {
          final key = item['id'] ?? item['region'] ?? item['name'];
          if (key != null) {
            for (final level in levels) {
              matches = _resolveKey('$key', level);
              if (matches.isNotEmpty) break;
            }
          }
        }
      }
      if (matches.isEmpty) continue;

      // --- find the value.
      dynamic rawValue;
      if (valueKey != null) {
        rawValue = item[valueKey.toLowerCase()];
      } else {
        for (final f in valueFields) {
          if (item[f] != null) {
            rawValue = item[f];
            break;
          }
        }
        rawValue ??= item.entries
            .where((e) =>
                !levelFields.containsKey(e.key) &&
                !const {'id', 'region', 'name'}.contains(e.key) &&
                _coerce(e.value) is num)
            .map((e) => e.value)
            .cast<dynamic>()
            .firstOrNull;
      }
      final value = _coerce(rawValue);
      if (value is! T) continue;
      for (final region in matches) {
        values[region.id] = value;
      }
    }

    return BdMapData<T>(
      values,
      title: title,
      format: unit == null
          ? (T == num || T == int || T == double
              ? (v) => _trimNum(v as num)
              : null)
          : (v) => v is num ? '${_trimNum(v)}$unit' : '$v$unit',
      minColor: minColor,
      maxColor: maxColor,
    );
  }

  /// [BdMapData.fromJson] / [BdMapData.fromList] for a raw JSON string —
  /// pair it with an asset or an HTTP response body. A top-level object
  /// uses the file format; a top-level **array** (or an object whose
  /// `"data"` is an array) is treated as an API-style list:
  ///
  /// ```dart
  /// final jsonString = await rootBundle.loadString('assets/my_data.json');
  /// final data = BdMapData<num>.fromJsonString(jsonString);
  ///
  /// final body = await http.get(uri);          // e.g. [{"district": ...}]
  /// final live = BdMapData<num>.fromJsonString(body.body);
  /// ```
  factory BdMapData.fromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is List) return BdMapData<T>.fromList(decoded);
    final map = decoded as Map<String, dynamic>;
    if (map['data'] is List) {
      return BdMapData<T>.fromList(
        map['data'] as List,
        title: map['title'] as String?,
        unit: map['unit'] as String?,
        minColor: _parseHex(map['minColor']) ?? const Color(0xFFC8E6C9),
        maxColor: _parseHex(map['maxColor']) ?? const Color(0xFF1B5E20),
      );
    }
    return BdMapData<T>.fromJson(map);
  }

  static dynamic _coerce(dynamic raw) {
    if (raw is num || raw is String) {
      return raw is String ? num.tryParse(raw) ?? raw : raw;
    }
    return null;
  }

  static String _trimNum(num v) {
    if (v == v.roundToDouble()) return '${v.round()}';
    final s = v.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }

  static Color? _parseHex(dynamic raw) {
    if (raw is! String) return null;
    var hex = raw.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(value);
  }

  static bool _matches(BdRegion r, String key) {
    final k = key.trim();
    return r.name.toLowerCase() == k.toLowerCase() ||
        r.bnName == k ||
        r.id == k.toLowerCase() ||
        r.id.split('.').last == k.toLowerCase();
  }

  /// Resolves a key directly against [candidates] — used in the nested
  /// tree, where children are already scoped to their parent and a literal
  /// `/` may be part of the name (e.g. the union `Nuralla Pur U/C`).
  static List<BdRegion> _resolveIn(String key, List<BdRegion> candidates) => [
        for (final r in candidates)
          if (_matches(r, key)) r
      ];

  /// Resolves a JSON key (name, id, or `Parent/Child` path) to the regions
  /// of [level] it refers to. The whole key is tried as a name first, so
  /// names containing a literal `/` (e.g. `Nuralla Pur U/C`) still work.
  static List<BdRegion> _resolveKey(String key, List<BdRegion> level) {
    final direct = _resolveIn(key, level);
    if (direct.isNotEmpty) return direct;
    final segments =
        key.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty);
    if (segments.isEmpty) return const [];
    final target = segments.last;
    final ancestors = segments.toList()..removeLast();
    final matches = <BdRegion>[];
    for (final region in level) {
      if (!_matches(region, target)) continue;
      // Every path ancestor must appear (in order, deepest last) in the
      // region's ancestor chain.
      var r = BdGeo.parentOf(region);
      var ok = true;
      for (final wanted in ancestors.reversed) {
        while (r != null && !_matches(r, wanted)) {
          r = BdGeo.parentOf(r);
        }
        if (r == null) {
          ok = false;
          break;
        }
        r = BdGeo.parentOf(r);
      }
      if (ok) matches.add(region);
    }
    return matches;
  }

  /// Region values keyed by [BdRegion.id].
  final Map<String, T> values;

  /// What this dataset measures, e.g. `'Population'`. Shown next to values
  /// in info panels and data lists.
  final String? title;

  /// Formats a value for display. Defaults to `toString()`.
  final String Function(T value)? format;

  /// Overrides the choropleth color per value. Return `null` to fall back
  /// to the automatic numeric scale (or no data color for non-numeric
  /// values).
  final Color? Function(T value)? colorBuilder;

  /// Fill for the smallest numeric value on the automatic scale.
  final Color minColor;

  /// Fill for the largest numeric value on the automatic scale.
  final Color maxColor;

  double? _min, _max;
  bool _scanned = false;

  void _scan() {
    if (_scanned) return;
    _scanned = true;
    for (final v in values.values) {
      if (v is num) {
        final d = v.toDouble();
        _min = (_min == null || d < _min!) ? d : _min;
        _max = (_max == null || d > _max!) ? d : _max;
      }
    }
  }

  /// Smallest numeric value in [values], or `null` if none are numeric.
  double? get minValue {
    _scan();
    return _min;
  }

  /// Largest numeric value in [values], or `null` if none are numeric.
  double? get maxValue {
    _scan();
    return _max;
  }

  /// The value for [region], or `null` when none was provided.
  T? valueOf(BdRegion region) => values[region.id];

  /// The value for the region with [id], or `null`.
  T? operator [](String id) => values[id];

  /// Whether a value exists for [region].
  bool has(BdRegion region) => values.containsKey(region.id);

  /// The display string for [region]'s value, or `null` when it has none.
  String? labelOf(BdRegion region) {
    final v = values[region.id];
    if (v == null) return null;
    return format != null ? format!(v) : '$v';
  }

  /// The choropleth fill for [region], or `null` when it has no value (or
  /// a non-numeric value and no [colorBuilder]).
  Color? colorOf(BdRegion region) {
    final v = values[region.id];
    if (v == null) return null;
    final custom = colorBuilder?.call(v);
    if (custom != null) return custom;
    if (v is! num) return null;
    _scan();
    if (_min == null || _max == null) return null;
    final t = _max == _min
        ? 1.0
        : ((v.toDouble() - _min!) / (_max! - _min!)).clamp(0.0, 1.0);
    return Color.lerp(minColor, maxColor, t);
  }
}

/// A ready-made scrollable list of regions with their attached data —
/// the list companion to the map widgets.
///
/// Give it either an explicit list of [regions], a whole [level]
/// (every division, district, upazila, or union region in the country),
/// or a [parent] region (its direct children). Attach a [BdMapData] to
/// show and sort by each region's value; rows are colored with the same
/// choropleth fill the maps use, so list and map always match.
///
/// ```dart
/// BdRegionDataList(
///   level: BdArea.district,   // all 64 districts
///   data: literacyRate,
///   onTap: (region) => ...,
/// )
/// ```
class BdRegionDataList extends StatelessWidget {
  const BdRegionDataList({
    super.key,
    this.regions,
    this.level,
    this.parent,
    this.data,
    this.useBanglaNames = false,
    this.sortByValue = true,
    this.onTap,
    this.regionColor,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.dense = false,
  }) : assert(regions != null || level != null || parent != null,
            'Provide regions, level, or parent.');

  /// Explicit regions to list. Takes precedence over [level] and [parent].
  final List<BdRegion>? regions;

  /// List every region of this level in the country
  /// (8 divisions / 64 districts / 500+ upazilas / 5,000+ unions).
  final BdArea? level;

  /// List the direct children of this region.
  final BdRegion? parent;

  /// Values (and colors) to show per region.
  final BdMapData? data;

  /// Show Bangla names first.
  final bool useBanglaNames;

  /// Sort rows by numeric value, largest first. Regions without a value
  /// keep their original order at the end. Ignored when [data] is `null`.
  final bool sortByValue;

  /// Called when a row is tapped.
  final ValueChanged<BdRegion>? onTap;

  /// Color of each row's dot and value bar. The map widgets pass their own
  /// palette assignment here so the list always matches the map's colors.
  /// When `null`, falls back to [BdMapData.colorOf], then a neutral dot.
  final Color? Function(BdRegion region)? regionColor;

  /// Passed to the underlying [ListView].
  final bool shrinkWrap;

  /// Passed to the underlying [ListView].
  final ScrollPhysics? physics;

  /// Passed to the underlying [ListView].
  final EdgeInsetsGeometry? padding;

  /// Compact rows.
  final bool dense;

  List<BdRegion> _resolveRegions() {
    if (regions != null) return regions!;
    if (parent != null) return BdGeo.childrenOf(parent!);
    switch (level!) {
      case BdArea.division:
        return BdGeo.divisions;
      case BdArea.district:
        return BdGeo.districts;
      case BdArea.upazila:
        return BdGeo.upazilas;
      case BdArea.union:
        return BdGeo.unionRegions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var items = _resolveRegions();
    final d = data;
    if (d != null && sortByValue) {
      final withValue = <BdRegion>[];
      final withoutValue = <BdRegion>[];
      for (final r in items) {
        (d.has(r) ? withValue : withoutValue).add(r);
      }
      withValue.sort((a, b) {
        final va = d.valueOf(a), vb = d.valueOf(b);
        if (va is num && vb is num) return vb.compareTo(va);
        return 0;
      });
      items = [...withValue, ...withoutValue];
    }

    // Scale value bars against the largest value among the listed rows
    // (not the whole dataset), so bars stay readable at every drill level.
    double? localMax;
    if (d != null) {
      for (final r in items) {
        final v = d.valueOf(r);
        if (v is num && (localMax == null || v > localMax)) {
          localMax = v.toDouble();
        }
      }
    }

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final r = items[index];
        final valueLabel = d?.labelOf(r);
        final color = regionColor?.call(r) ??
            d?.colorOf(r) ??
            theme.colorScheme.surfaceContainerHighest;

        // Proportional bar: this region's share of the largest listed value.
        double? fraction;
        final v = d?.valueOf(r);
        if (v is num && localMax != null && localMax > 0) {
          fraction = (v.toDouble() / localMax).clamp(0.0, 1.0);
        }
        final otherName = useBanglaNames ? r.name : r.bnName;

        return ListTile(
          dense: dense,
          visualDensity: dense ? VisualDensity.compact : null,
          leading: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
          ),
          title: Text(useBanglaNames ? r.displayNameBn : r.name),
          subtitle: otherName.isEmpty && fraction == null
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (otherName.isNotEmpty) Text(otherName),
                    if (fraction != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            height: 5,
                            width: double.infinity,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: fraction == 0 ? 0.01 : fraction,
                              child: ColoredBox(color: color),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
          trailing: valueLabel == null
              ? null
              : Text(
                  valueLabel,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
          onTap: onTap == null ? null : () => onTap!(r),
        );
      },
    );
  }
}
