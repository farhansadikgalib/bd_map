/*
  Copyright 2026 Farhan Sadik Galib. All rights reserved.
  Use of this source code is governed by a MIT license that can be
  found in the LICENSE file.
  source: https://github.com/farhansadikgalib/bd_map
  website: https://farhansadikgalib.com
 */

import 'package:flutter/material.dart';

import 'bd_geo_data.dart';
import 'bd_map_data.dart';
import 'bd_region.dart';

/// A full-country administrative map of Bangladesh at a chosen [level] —
/// Division (বিভাগ), District (জেলা), or Upazila/Thana (উপজেলা/থানা) — in the
/// style of a printed wall map: every region of that level drawn at once in
/// varied shades, with the boundary hierarchy emphasized (thick national
/// border, dashed parent-level borders, thin region borders) and printed-map
/// labels.
///
/// The map is pannable and pinch-zoomable. Tapping a region highlights it
/// and shows an info panel with its names, lineage, and (for upazilas) its
/// unions — plus anything you add through [infoBuilder].
///
/// ```dart
/// BdCountryMap(BdArea.district)
/// ```
class BdCountryMap extends StatefulWidget {
  const BdCountryMap(
    this.level, {
    super.key,
    this.useBanglaNames = false,
    this.onRegionTap,
    this.showInfoPanel = true,
    this.infoBuilder,
    this.showLabels = true,
    this.maxZoom = 16,
    this.regionColorBuilder,
    this.data,
    this.showDataList = false,
    this.palette,
    this.nationalBorderColor = const Color(0xFF616161),
    this.nationalBorderWidth = 2.5,
    this.parentBorderColor,
    this.parentBorderWidth = 1.1,
    this.regionBorderColor = const Color(0x8837474F),
    this.regionBorderWidth = 0.4,
    this.backgroundColor,
    this.primaryLabelStyle,
    this.secondaryLabelStyle,
  });

  /// Which administrative level fills the map.
  final BdArea level;

  /// Use Bangla (বাংলা) names for labels and the info panel.
  final bool useBanglaNames;

  /// Called when a region is tapped.
  final ValueChanged<BdRegion>? onRegionTap;

  /// Whether the built-in info panel is shown for the selected region.
  final bool showInfoPanel;

  /// Extra content for the info panel — attach your own data here.
  final Widget Function(BuildContext context, BdRegion region)? infoBuilder;

  /// Whether name labels are painted on the map.
  final bool showLabels;

  /// Maximum pinch-zoom scale.
  final double maxZoom;

  /// Overrides the fill color per region. Return `null` to use the default
  /// palette for this [level].
  final Color? Function(BdRegion region)? regionColorBuilder;

  /// Your data, keyed by [BdRegion.id]. The map keeps its normal colors;
  /// the info panel shows the selected region's value and [showDataList]
  /// adds a ranked list (with value bars) of every region at this [level].
  /// For a choropleth, pass `regionColorBuilder: (r) => myData.colorOf(r)`.
  final BdMapData? data;

  /// Show a tappable, value-sorted list of this [level]'s regions below
  /// the map (tapping a row selects it, exactly like tapping the map).
  /// Only shown when [data] is provided.
  final bool showDataList;

  /// Fill shades cycled deterministically per region. When `null`, each
  /// [level] gets its own default palette: soft categorical hues for
  /// divisions, an emerald-teal mosaic for districts, the classic green
  /// mosaic for thanas/upazilas, and pale sage pastels for unions.
  final List<Color>? palette;

  final Color nationalBorderColor;
  final double nationalBorderWidth;

  /// Color of the dashed borders one level above [level] (districts on
  /// the upazila map, divisions on the district map). When `null`, a
  /// contrasting default is chosen per level. Unused on the division map.
  final Color? parentBorderColor;
  final double parentBorderWidth;

  /// Color/width of the thin borders around each painted region.
  final Color regionBorderColor;
  final double regionBorderWidth;

  /// Background behind the map.
  final Color? backgroundColor;

  /// Style for the primary (bold) labels of this level's parent grouping —
  /// district names on the upazila map, or the level's own names on the
  /// district/division maps.
  final TextStyle? primaryLabelStyle;

  /// Style for the small per-region labels on the upazila map.
  final TextStyle? secondaryLabelStyle;

  @override
  State<BdCountryMap> createState() => _BdCountryMapState();
}

/// A full-country upazila/thana map — [BdCountryMap] fixed to
/// [BdArea.upazila]. Kept for convenience and backward compatibility.
class BdUpazilaMap extends StatelessWidget {
  const BdUpazilaMap({
    super.key,
    this.useBanglaNames = false,
    this.onUpazilaTap,
    this.showInfoPanel = true,
    this.infoBuilder,
    this.showDistrictLabels = true,
    this.showUpazilaLabels = true,
    this.maxZoom = 16,
    this.regionColorBuilder,
    this.data,
    this.showDataList = false,
    this.palette,
    this.backgroundColor,
  });

  final bool useBanglaNames;
  final ValueChanged<BdRegion>? onUpazilaTap;
  final bool showInfoPanel;
  final Widget Function(BuildContext context, BdRegion region)? infoBuilder;
  final bool showDistrictLabels;
  final bool showUpazilaLabels;
  final double maxZoom;
  final Color? Function(BdRegion region)? regionColorBuilder;
  final BdMapData? data;
  final bool showDataList;
  final List<Color>? palette;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return BdCountryMap(
      BdArea.upazila,
      useBanglaNames: useBanglaNames,
      onRegionTap: onUpazilaTap,
      showInfoPanel: showInfoPanel,
      infoBuilder: infoBuilder,
      showLabels: showDistrictLabels || showUpazilaLabels,
      maxZoom: maxZoom,
      regionColorBuilder: regionColorBuilder,
      data: data,
      showDataList: showDataList,
      palette: palette,
      backgroundColor: backgroundColor,
    );
  }
}

class _BdCountryMapState extends State<BdCountryMap> {
  /// Division map: soft, muted categorical hues (ColorBrewer Set2 style) —
  /// clearly distinct without clashing.
  static const List<Color> _divisionPalette = <Color>[
    Color(0xFF66C2A5), // soft teal
    Color(0xFFFC8D62), // soft coral
    Color(0xFF8DA0CB), // periwinkle
    Color(0xFFE78AC3), // rose
    Color(0xFFA6D854), // soft green
    Color(0xFFFFD92F), // soft yellow
    Color(0xFF80B1D3), // dusty blue
    Color(0xFFE5C494), // sand
  ];

  /// District map: emerald-and-teal mosaic — cohesive with the green
  /// national theme, adjacent shades still contrast.
  static const List<Color> _districtPalette = <Color>[
    Color(0xFF26A69A),
    Color(0xFF9CCC65),
    Color(0xFF80CBC4),
    Color(0xFF66BB6A),
    Color(0xFF00897B),
    Color(0xFFA5D6A7),
    Color(0xFF4DB6AC),
    Color(0xFF7CB342),
    Color(0xFFB2DFDB),
    Color(0xFF43A047),
    Color(0xFF81C784),
    Color(0xFF00796B),
  ];

  /// Thana/upazila map: the classic printed-map green mosaic.
  static const List<Color> _upazilaPalette = <Color>[
    Color(0xFF66BB6A),
    Color(0xFF9CCC65),
    Color(0xFF43A047),
    Color(0xFFA5D6A7),
    Color(0xFF7CB342),
    Color(0xFF81C784),
    Color(0xFF558B2F),
    Color(0xFFC5E1A5),
    Color(0xFF388E3C),
    Color(0xFF8BC34A),
    Color(0xFF2E7D32),
    Color(0xFFAED581),
    Color(0xFF689F38),
    Color(0xFFDCEDC8),
  ];

  /// Union map: pale sage-and-water pastels, so the dashed thana borders
  /// and labels stay readable over 5000+ tiny cells.
  static const List<Color> _unionPalette = <Color>[
    Color(0xFFC8E6C9),
    Color(0xFFB2DFDB),
    Color(0xFFDCEDC8),
    Color(0xFFB2EBF2),
    Color(0xFFE6EE9C),
    Color(0xFFA5D6A7),
    Color(0xFF80CBC4),
    Color(0xFFC5E1A5),
    Color(0xFFE0F2F1),
    Color(0xFFAED581),
  ];

  static List<Color> _defaultPaletteFor(BdArea level) {
    switch (level) {
      case BdArea.division:
        return _divisionPalette;
      case BdArea.district:
        return _districtPalette;
      case BdArea.upazila:
        return _upazilaPalette;
      case BdArea.union:
        return _unionPalette;
    }
  }

  static Color _defaultParentBorderFor(BdArea level) {
    switch (level) {
      case BdArea.division:
      case BdArea.district:
      case BdArea.upazila:
        // Amber dashed borders pop over the green/teal mosaics — the
        // classic printed-map look.
        return const Color(0xFFF9A825);
      case BdArea.union:
        // Slightly deeper orange over the pale pastel union cells.
        return const Color(0xFFEF6C00);
    }
  }

  final TransformationController _transformation = TransformationController();
  BdRegion? _selected;

  @override
  void didUpdateWidget(BdCountryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _selected = null;
      _transformation.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  List<BdRegion> get _regions {
    switch (widget.level) {
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

  BdRegion? _regionAt(Offset local, Size size) {
    final t = _FitTransform(size);
    final world = t.toWorld(local);
    final x = world.dx / kBdMapAspectRatio;
    final y = world.dy;
    if (widget.level == BdArea.union) {
      // Two-stage lookup: find the upazila first, then search only its
      // unions — much faster than testing all 5000+ union polygons.
      for (final u in BdGeo.upazilas) {
        if (u.containsPoint(x, y)) {
          for (final un in BdGeo.childrenOf(u)) {
            if (un.containsPoint(x, y)) return un;
          }
          return null;
        }
      }
      return null;
    }
    for (final r in _regions) {
      if (r.containsPoint(x, y)) return r;
    }
    return null;
  }

  void _handleTap(Offset local, Size size) {
    final r = _regionAt(local, size);
    if (r == null) return;
    _select(r);
  }

  void _select(BdRegion r) {
    widget.onRegionTap?.call(r);
    setState(() {
      _selected = identical(_selected, r) ? null : r;
    });
  }

  /// The palette fill the painter gives [r] — mirrors the painter's
  /// assignment so the data list's color dots match the map.
  Color _paletteColorOf(BdRegion r) {
    final custom = widget.regionColorBuilder?.call(r);
    if (custom != null) return custom;
    final palette = widget.palette ?? _defaultPaletteFor(widget.level);
    final regions = _regions;
    if (regions.length <= palette.length) {
      final index = regions.indexOf(r);
      return palette[(index < 0 ? 0 : index) % palette.length];
    }
    return palette[r.id.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: AspectRatio(
            aspectRatio: kBdMapAspectRatio,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return InteractiveViewer(
                  transformationController: _transformation,
                  maxScale: widget.maxZoom,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _handleTap(d.localPosition, size),
                    child: CustomPaint(
                      size: size,
                      painter: _AdminMapPainter(
                        level: widget.level,
                        useBanglaNames: widget.useBanglaNames,
                        selected: _selected,
                        regionColorBuilder: widget.regionColorBuilder,
                        palette:
                            widget.palette ?? _defaultPaletteFor(widget.level),
                        nationalBorderColor: widget.nationalBorderColor,
                        nationalBorderWidth: widget.nationalBorderWidth,
                        parentBorderColor: widget.parentBorderColor ??
                            _defaultParentBorderFor(widget.level),
                        parentBorderWidth: widget.parentBorderWidth,
                        regionBorderColor: widget.regionBorderColor,
                        regionBorderWidth: widget.regionBorderWidth,
                        showLabels: widget.showLabels,
                        backgroundColor: widget.backgroundColor,
                        primaryLabelStyle: widget.primaryLabelStyle,
                        secondaryLabelStyle: widget.secondaryLabelStyle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_selected != null && widget.showInfoPanel)
          _buildInfoPanel(context, _selected!),
        if (widget.data != null && widget.showDataList)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: BdRegionDataList(
              level: widget.level,
              data: widget.data,
              useBanglaNames: widget.useBanglaNames,
              onTap: _select,
              regionColor: _paletteColorOf,
              shrinkWrap: true,
              dense: true,
              padding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  Widget _buildInfoPanel(BuildContext context, BdRegion region) {
    final theme = Theme.of(context);
    final parent = BdGeo.parentOf(region);
    final grandParent = parent == null ? null : BdGeo.parentOf(parent);
    final children = BdGeo.childrenOf(region);
    // List the same union regions the map draws, so the panel can never
    // under-report (the curated name list misses metro-thana wards).
    final unions =
        region.level == BdArea.upazila ? children : const <BdRegion>[];
    final bn = widget.useBanglaNames;
    String nameOf(BdRegion? r) =>
        r == null ? '' : (bn ? r.displayNameBn : r.name);

    String levelName(BdArea l) {
      switch (l) {
        case BdArea.division:
          return bn ? 'বিভাগ' : 'Division';
        case BdArea.district:
          return bn ? 'জেলা' : 'District';
        case BdArea.upazila:
          return bn ? 'উপজেলা / থানা' : 'Upazila / Thana';
        case BdArea.union:
          return bn ? 'ইউনিয়ন / ওয়ার্ড' : 'Union / Ward';
      }
    }

    String? lineage;
    if (region.level == BdArea.district) {
      lineage = bn ? '${nameOf(parent)} বিভাগ' : '${nameOf(parent)} Division';
    } else if (region.level == BdArea.upazila && parent != null) {
      lineage = bn
          ? '${nameOf(parent)} জেলা, ${nameOf(grandParent)} বিভাগ'
          : '${nameOf(parent)} District, ${nameOf(grandParent)} Division';
    } else if (region.level == BdArea.union && parent != null) {
      lineage = bn
          ? '${nameOf(parent)} উপজেলা/থানা, ${nameOf(grandParent)} জেলা'
          : '${nameOf(parent)} Upazila/Thana, '
              '${nameOf(grandParent)} District';
    }

    String? childSummary;
    if (region.level == BdArea.division) {
      final upazilaCount =
          children.fold<int>(0, (sum, d) => sum + BdGeo.childrenOf(d).length);
      childSummary = bn
          ? '${children.length}টি জেলা, $upazilaCountটি উপজেলা/থানা'
          : '${children.length} districts, $upazilaCount upazilas / thanas';
    } else if (region.level == BdArea.district) {
      childSummary = bn
          ? '${children.length}টি উপজেলা/থানা'
          : '${children.length} upazilas / thanas';
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bn ? region.displayNameBn : region.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(levelName(region.level)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (region.bnName.isNotEmpty && !bn)
              Text(region.bnName, style: theme.textTheme.bodyMedium),
            if (widget.data?.labelOf(region) != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.bar_chart,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      widget.data!.title == null
                          ? widget.data!.labelOf(region)!
                          : '${widget.data!.title}: '
                              '${widget.data!.labelOf(region)!}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            if (lineage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(lineage, style: theme.textTheme.bodySmall),
              ),
            if (childSummary != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(childSummary, style: theme.textTheme.bodySmall),
              ),
            if (unions.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  bn
                      ? 'ইউনিয়নসমূহ (${unions.length}টি)'
                      : 'Unions (${unions.length})',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final u in unions)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              bn ? u.displayNameBn : u.name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else if (region.level == BdArea.upazila)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  bn
                      ? 'কোনো ইউনিয়ন তথ্য নেই (সিটি থানা)'
                      : 'No union data (city thana)',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (widget.infoBuilder != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: widget.infoBuilder!(context, region),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fit-contain transform from world space (aspect x 1) to a canvas size.
class _FitTransform {
  _FitTransform(Size size) {
    const worldW = kBdMapAspectRatio;
    const worldH = 1.0;
    final sw = size.width / worldW;
    final sh = size.height / worldH;
    scale = sw < sh ? sw : sh;
    offset = Offset(
      (size.width - worldW * scale) / 2,
      (size.height - worldH * scale) / 2,
    );
  }

  late final double scale;
  late final Offset offset;

  Offset toCanvas(Offset world) => world * scale + offset;
  Offset toWorld(Offset canvas) => (canvas - offset) / scale;
}

class _AdminMapPainter extends CustomPainter {
  _AdminMapPainter({
    required this.level,
    required this.useBanglaNames,
    required this.selected,
    required this.regionColorBuilder,
    required this.palette,
    required this.nationalBorderColor,
    required this.nationalBorderWidth,
    required this.parentBorderColor,
    required this.parentBorderWidth,
    required this.regionBorderColor,
    required this.regionBorderWidth,
    required this.showLabels,
    required this.backgroundColor,
    required this.primaryLabelStyle,
    required this.secondaryLabelStyle,
  });

  final BdArea level;
  final bool useBanglaNames;
  final BdRegion? selected;
  final Color? Function(BdRegion)? regionColorBuilder;
  final List<Color> palette;
  final Color nationalBorderColor;
  final double nationalBorderWidth;
  final Color parentBorderColor;
  final double parentBorderWidth;
  final Color regionBorderColor;
  final double regionBorderWidth;
  final bool showLabels;
  final Color? backgroundColor;
  final TextStyle? primaryLabelStyle;
  final TextStyle? secondaryLabelStyle;

  // World-space paths never change — cache them across repaints.
  static final Map<String, Path> _pathCache = <String, Path>{};

  static Path _worldPath(BdRegion region) {
    return _pathCache.putIfAbsent(region.id, () {
      final path = Path()..fillType = PathFillType.evenOdd;
      for (final polygon in region.rawPolygons) {
        for (final ring in polygon) {
          path.moveTo(ring[0] * kBdMapAspectRatio, ring[1]);
          for (var i = 2; i < ring.length; i += 2) {
            path.lineTo(ring[i] * kBdMapAspectRatio, ring[i + 1]);
          }
          path.close();
        }
      }
      return path;
    });
  }

  List<BdRegion> get _regions {
    switch (level) {
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

  /// Regions whose dashed borders sit one level above the filled regions.
  List<BdRegion> get _parentBorderRegions {
    switch (level) {
      case BdArea.division:
        return const <BdRegion>[];
      case BdArea.district:
        return BdGeo.divisions;
      case BdArea.upazila:
        return BdGeo.districts;
      case BdArea.union:
        return BdGeo.upazilas;
    }
  }

  Color _fillFor(BdRegion r, int index, int regionCount) {
    final custom = regionColorBuilder?.call(r);
    if (custom != null) return custom;
    // When every region fits in the palette (the division map), assign by
    // index so all colors are guaranteed distinct; otherwise hash the id so
    // neighbors tend to differ, like a printed mosaic map.
    final shade = regionCount <= palette.length
        ? palette[index % palette.length]
        : palette[r.id.hashCode.abs() % palette.length];
    if (identical(r, selected)) {
      return Color.lerp(shade, Colors.white, 0.45)!;
    }
    return shade;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColor != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor!);
    }
    final t = _FitTransform(size);

    canvas.save();
    canvas.translate(t.offset.dx, t.offset.dy);
    canvas.scale(t.scale);

    // 1. Region fills + thin borders.
    final regionStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = regionBorderWidth / t.scale
      ..strokeJoin = StrokeJoin.round
      ..color = regionBorderColor;
    final regions = _regions;
    for (var i = 0; i < regions.length; i++) {
      final path = _worldPath(regions[i]);
      canvas.drawPath(
          path, Paint()..color = _fillFor(regions[i], i, regions.length));
      canvas.drawPath(path, regionStroke);
    }

    // 2. Parent-level borders on top (dashed, printed-map style).
    final parentStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = parentBorderWidth / t.scale
      ..strokeJoin = StrokeJoin.round
      ..color = parentBorderColor;
    for (final p in _parentBorderRegions) {
      canvas.drawPath(
        _dashed('dash_${p.id}', _worldPath(p), 0.008, 0.004),
        parentStroke,
      );
    }

    // 3. National border (division outlines merge into it visually).
    final nationalStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = nationalBorderWidth / t.scale
      ..strokeJoin = StrokeJoin.round
      ..color = nationalBorderColor;
    for (final d in BdGeo.divisions) {
      canvas.drawPath(_worldPath(d), nationalStroke);
    }

    // 4. Selected region outline.
    if (selected != null) {
      canvas.drawPath(
        _worldPath(selected!),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / t.scale
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFD32F2F),
      );
    }
    canvas.restore();

    // 5. Labels (screen space, at printed-map sizes).
    if (!showLabels) return;
    switch (level) {
      case BdArea.division:
        final style = primaryLabelStyle ??
            const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xE6263238),
              letterSpacing: 0.5,
            );
        for (final d in BdGeo.divisions) {
          _paintLabel(canvas, t, d, style,
              upperCase: !useBanglaNames, maxWidthFactor: 2.0);
        }
      case BdArea.district:
        final style = primaryLabelStyle ??
            const TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              color: Color(0xE6263238),
              letterSpacing: 0.3,
            );
        for (final d in BdGeo.districts) {
          _paintLabel(canvas, t, d, style,
              upperCase: !useBanglaNames, maxWidthFactor: 2.0);
        }
      case BdArea.upazila:
      case BdArea.union:
        // At union level the individual unions are far too small and
        // numerous to label — the upazila/district labels orient the reader
        // instead (union names appear in the tap panel).
        final secondary = secondaryLabelStyle ??
            const TextStyle(fontSize: 3.2, color: Color(0xCC1B2A1B));
        for (final u in BdGeo.upazilas) {
          _paintLabel(canvas, t, u, secondary, maxWidthFactor: 1.4);
        }
        final primary = primaryLabelStyle ??
            const TextStyle(
              fontSize: 6.5,
              fontWeight: FontWeight.w700,
              color: Color(0xE6263238),
              letterSpacing: 0.3,
            );
        for (final d in BdGeo.districts) {
          _paintLabel(canvas, t, d, primary,
              upperCase: !useBanglaNames, maxWidthFactor: 2.0);
        }
    }
  }

  // Dashed world-space paths are expensive to build; cache per region.
  static final Map<String, Path> _dashCache = <String, Path>{};

  static Path _dashed(String key, Path source, double dash, double gap) {
    return _dashCache.putIfAbsent(key, () {
      final out = Path();
      for (final metric in source.computeMetrics()) {
        var distance = 0.0;
        var draw = true;
        while (distance < metric.length) {
          final len = draw ? dash : gap;
          if (draw) {
            out.addPath(
              metric.extractPath(distance, distance + len),
              Offset.zero,
            );
          }
          distance += len;
          draw = !draw;
        }
      }
      return out;
    });
  }

  void _paintLabel(
    Canvas canvas,
    _FitTransform t,
    BdRegion region,
    TextStyle style, {
    bool upperCase = false,
    double maxWidthFactor = 1.2,
  }) {
    var text = useBanglaNames ? region.displayNameBn : region.name;
    if (upperCase) text = text.toUpperCase();
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final b = region.bounds;
    final regionWidthPx = b.width * kBdMapAspectRatio * t.scale;
    if (tp.width > regionWidthPx * maxWidthFactor) return;
    final p = region.labelPoint;
    final c = t.toCanvas(Offset(p.dx * kBdMapAspectRatio, p.dy));
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_AdminMapPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.selected != selected ||
      oldDelegate.useBanglaNames != useBanglaNames ||
      oldDelegate.palette != palette ||
      oldDelegate.showLabels != showLabels;
}
