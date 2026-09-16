/*
  Copyright 2026 Farhan Sadik Galib. All rights reserved.
  Use of this source code is governed by a MIT license that can be
  found in the LICENSE file.
  source: https://github.com/farhansadikgalib/bd_map
  website: https://farhansadikgalib.com
 */

import 'dart:ui';

import 'bd_geo_data.dart';
import 'bd_union_data.dart';
import 'bd_union_geo_data.dart';

/// Administrative level of a [BdRegion].
enum BdArea {
  /// Division (বিভাগ) — top level, 8 in total.
  division,

  /// District / Zila (জেলা) — 64 in total.
  district,

  /// Upazila / Thana (উপজেলা / থানা) — sub-district level.
  upazila,

  /// Union / Ward (ইউনিয়ন / ওয়ার্ড) — the lowest tier, below upazila.
  union,
}

/// One administrative region of Bangladesh (a division, district or
/// upazila/thana) together with its boundary geometry.
///
/// Coordinates are normalized to the country bounding box: `x` and `y` are
/// in `[0, 1]`, `y` grows southward (screen convention). Use
/// [kBdMapAspectRatio] to correct the aspect ratio when rendering.
class BdRegion {
  const BdRegion({
    required this.id,
    required this.name,
    required this.bnName,
    required this.level,
    this.parentId,
    required this.rawPolygons,
  });

  /// Stable unique identifier: the lowercase English path from the
  /// division down, dot-separated — `'dhaka'`, `'dhaka.gazipur'`,
  /// `'dhaka.gazipur.kaliakair'`, `'dhaka.gazipur.kaliakair.atabaha'`.
  final String id;

  /// English name, e.g. `'Dhaka'`.
  final String name;

  /// Bangla name, e.g. `'ঢাকা'`. May be empty when unknown.
  final String bnName;

  /// Administrative level of this region.
  final BdArea level;

  /// [id] of the parent region (`null` for divisions).
  final String? parentId;

  /// Boundary geometry: polygons → rings → flat `[x1, y1, x2, y2, ...]`
  /// coordinate list. The first ring of each polygon is the outer boundary,
  /// any following rings are holes.
  final List<List<List<double>>> rawPolygons;

  /// Bangla name when available, otherwise the English name.
  String get displayNameBn => bnName.isEmpty ? name : bnName;

  /// Bounding box of this region in normalized country space.
  Rect get bounds {
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final polygon in rawPolygons) {
      final outer = polygon.first;
      for (var i = 0; i < outer.length; i += 2) {
        final x = outer[i], y = outer[i + 1];
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// A point inside the largest polygon, useful for placing labels.
  Offset get labelPoint {
    List<double>? largest;
    var largestArea = -1.0;
    for (final polygon in rawPolygons) {
      final area = _ringArea(polygon.first);
      if (area > largestArea) {
        largestArea = area;
        largest = polygon.first;
      }
    }
    final ring = largest!;
    final c = _ringCentroid(ring);
    if (_pointInRing(c.dx, c.dy, ring)) return c;
    // Centroid fell outside (concave shape) — use the midpoint of the
    // widest horizontal span at the centroid's height.
    final xs = <double>[];
    for (var i = 0; i < ring.length; i += 2) {
      final x1 = ring[i], y1 = ring[i + 1];
      final j = (i + 2) % ring.length;
      final x2 = ring[j], y2 = ring[j + 1];
      if ((y1 > c.dy) != (y2 > c.dy)) {
        xs.add(x1 + (c.dy - y1) / (y2 - y1) * (x2 - x1));
      }
    }
    xs.sort();
    if (xs.length >= 2) return Offset((xs[0] + xs[1]) / 2, c.dy);
    return c;
  }

  /// Whether the normalized country-space point ([x], [y]) lies inside
  /// this region.
  bool containsPoint(double x, double y) {
    for (final polygon in rawPolygons) {
      if (_pointInRing(x, y, polygon.first)) {
        var inHole = false;
        for (var i = 1; i < polygon.length; i++) {
          if (_pointInRing(x, y, polygon[i])) {
            inHole = true;
            break;
          }
        }
        if (!inHole) return true;
      }
    }
    return false;
  }

  /// Builds the boundary as a [Path] in normalized country space.
  Path buildPath() {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final polygon in rawPolygons) {
      for (final ring in polygon) {
        path.moveTo(ring[0], ring[1]);
        for (var i = 2; i < ring.length; i += 2) {
          path.lineTo(ring[i], ring[i + 1]);
        }
        path.close();
      }
    }
    return path;
  }

  static bool _pointInRing(double x, double y, List<double> ring) {
    var inside = false;
    final n = ring.length ~/ 2;
    var j = n - 1;
    for (var i = 0; i < n; i++) {
      final xi = ring[i * 2], yi = ring[i * 2 + 1];
      final xj = ring[j * 2], yj = ring[j * 2 + 1];
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  static double _ringArea(List<double> ring) {
    var area = 0.0;
    final n = ring.length ~/ 2;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += ring[i * 2] * ring[j * 2 + 1] - ring[j * 2] * ring[i * 2 + 1];
    }
    return area.abs() / 2;
  }

  static Offset _ringCentroid(List<double> ring) {
    var a = 0.0, cx = 0.0, cy = 0.0;
    final n = ring.length ~/ 2;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final x1 = ring[i * 2], y1 = ring[i * 2 + 1];
      final x2 = ring[j * 2], y2 = ring[j * 2 + 1];
      final cross = x1 * y2 - x2 * y1;
      a += cross;
      cx += (x1 + x2) * cross;
      cy += (y1 + y2) * cross;
    }
    if (a.abs() < 1e-12) {
      var sx = 0.0, sy = 0.0;
      for (var i = 0; i < n; i++) {
        sx += ring[i * 2];
        sy += ring[i * 2 + 1];
      }
      return Offset(sx / n, sy / n);
    }
    a *= 0.5;
    return Offset(cx / (6 * a), cy / (6 * a));
  }
}

/// A union (ইউনিয়ন) — the lowest administrative tier, below upazila.
///
/// Unions carry names only; their boundary geometry is not bundled to keep
/// the package size reasonable.
class BdUnion {
  const BdUnion({
    required this.name,
    required this.bnName,
    required this.upazilaId,
  });

  /// English name, e.g. `'Subil'`.
  final String name;

  /// Bangla name, e.g. `'সুবিল'`. May be empty when unknown.
  final String bnName;

  /// [BdRegion.id] of the upazila this union belongs to.
  final String upazilaId;

  /// Bangla name when available, otherwise the English name.
  String get displayNameBn => bnName.isEmpty ? name : bnName;
}

/// Lookup API over the administrative geography of Bangladesh.
///
/// ```dart
/// final dhaka = BdGeo.divisionByName('Dhaka')!;
/// final districts = BdGeo.childrenOf(dhaka); // 13 districts
/// ```
class BdGeo {
  BdGeo._();

  static Map<String, BdRegion>? _byId;
  static Map<String, List<BdRegion>>? _byParent;

  /// The 8 divisions of Bangladesh.
  static List<BdRegion> get divisions => kBdDivisions;

  /// All 64 districts.
  static List<BdRegion> get districts => kBdDistricts;

  /// All upazilas / thanas.
  static List<BdRegion> get upazilas => kBdUpazilas;

  /// All union / ward level regions, with boundary geometry.
  static List<BdRegion> get unionRegions => kBdUnionRegions;

  static Map<String, List<BdUnion>>? _unionsByUpazila;
  static List<BdUnion>? _allUnions;

  static void _indexUnions() {
    if (_unionsByUpazila != null) return;
    final byUpazila = <String, List<BdUnion>>{};
    final all = <BdUnion>[];
    kBdUnionNames.forEach((upazilaId, entries) {
      final list = <BdUnion>[
        for (final e in entries)
          BdUnion(name: e[0], bnName: e[1], upazilaId: upazilaId),
      ];
      byUpazila[upazilaId] = list;
      all.addAll(list);
    });
    _unionsByUpazila = byUpazila;
    _allUnions = all;
  }

  /// All unions (ইউনিয়ন) of Bangladesh — names only, no geometry.
  static List<BdUnion> get unions {
    _indexUnions();
    return _allUnions!;
  }

  /// Unions of the upazila with the given [BdRegion.id].
  ///
  /// Backed by the curated name dataset; for upazilas it does not cover
  /// (e.g. metro thanas, whose wards exist only as boundary geometry),
  /// the list is derived from the union-level [unionRegions] instead, so
  /// this never under-reports what the maps can actually draw.
  static List<BdUnion> unionsOf(String upazilaId) {
    _indexUnions();
    final named = _unionsByUpazila![upazilaId];
    if (named != null && named.isNotEmpty) return named;
    _index();
    final children = _byParent![upazilaId];
    if (children == null) return const <BdUnion>[];
    return [
      for (final r in children)
        if (r.level == BdArea.union)
          BdUnion(name: r.name, bnName: r.bnName, upazilaId: upazilaId),
    ];
  }

  static void _index() {
    if (_byId != null) return;
    final byId = <String, BdRegion>{};
    final byParent = <String, List<BdRegion>>{};
    for (final list in [
      kBdDivisions,
      kBdDistricts,
      kBdUpazilas,
      kBdUnionRegions,
    ]) {
      for (final r in list) {
        byId[r.id] = r;
        if (r.parentId != null) {
          (byParent[r.parentId!] ??= <BdRegion>[]).add(r);
        }
      }
    }
    _byId = byId;
    _byParent = byParent;
  }

  /// Region with the given [id], or `null`.
  static BdRegion? byId(String id) {
    _index();
    return _byId![id];
  }

  /// Direct children of [region] (districts of a division, upazilas of a
  /// district). Empty for upazilas.
  static List<BdRegion> childrenOf(BdRegion region) {
    _index();
    return _byParent![region.id] ?? const <BdRegion>[];
  }

  /// Parent of [region], or `null` for divisions.
  static BdRegion? parentOf(BdRegion region) {
    final pid = region.parentId;
    return pid == null ? null : byId(pid);
  }

  /// Division matching [name] (English or Bangla, case-insensitive).
  static BdRegion? divisionByName(String name) => _byName(kBdDivisions, name);

  /// District matching [name] (English or Bangla, case-insensitive).
  static BdRegion? districtByName(String name) => _byName(kBdDistricts, name);

  static BdRegion? _byName(List<BdRegion> list, String name) {
    final n = name.trim().toLowerCase();
    for (final r in list) {
      if (r.name.toLowerCase() == n || r.bnName == name.trim()) return r;
    }
    return null;
  }
}
