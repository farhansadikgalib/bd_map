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

/// An interactive, drillable map of Bangladesh.
///
/// Starts at the country level showing the 8 divisions. Tapping a division
/// zooms into it and shows its districts; tapping a district shows its
/// upazilas / thanas. A breadcrumb bar allows navigating back up, and an
/// info panel shows details (and any data you attach) for the selected
/// region.
///
/// ```dart
/// BdMap(
///   onRegionTap: (region) => debugPrint(region.name),
///   infoBuilder: (context, region) => Text('Population of ${region.name}'),
/// )
/// ```
class BdMap extends StatefulWidget {
  const BdMap({
    super.key,
    this.maxLevel = BdArea.union,
    this.showLabels = true,
    this.useBanglaNames = false,
    this.showBreadcrumb = true,
    this.showInfoPanel = true,
    this.palette,
    this.regionColorBuilder,
    this.data,
    this.showDataList = false,
    this.borderColor = Colors.white,
    this.borderWidth = 1.0,
    this.highlightColor,
    this.labelTextStyle,
    this.infoBuilder,
    this.onRegionTap,
    this.onLevelChanged,
    this.animationDuration = const Duration(milliseconds: 450),
    this.animationCurve = Curves.easeInOutCubic,
    this.backgroundColor,
  });

  /// Deepest level the map drills into. Set to [BdArea.district] to
  /// stop at districts (no upazila view).
  final BdArea maxLevel;

  /// Whether region name labels are painted on the map.
  final bool showLabels;

  /// Use Bangla (বাংলা) names for labels, breadcrumb and info panel.
  final bool useBanglaNames;

  /// Whether the breadcrumb navigation bar is shown above the map.
  final bool showBreadcrumb;

  /// Whether the default info panel is shown for the selected region.
  /// Ignored when [infoBuilder] is provided (the builder is always shown).
  final bool showInfoPanel;

  /// Fill colors cycled through the visible regions. Defaults to a
  /// green-toned palette.
  final List<Color>? palette;

  /// Overrides the fill color per region. Return `null` to fall back to the
  /// [palette]. Use this to build choropleth (data) maps.
  final Color? Function(BdRegion region)? regionColorBuilder;

  /// Your data, keyed by [BdRegion.id], for any mix of levels — divisions,
  /// districts, upazilas/thanas, and unions all at once. The map keeps its
  /// normal colors; the info panel shows the selected region's value and
  /// [showDataList] adds a ranked list (with value bars) of the visible
  /// regions. For a choropleth, pass
  /// `regionColorBuilder: (r) => myData.colorOf(r)`.
  final BdMapData? data;

  /// Show a tappable, value-sorted list of the currently visible regions
  /// below the map (tapping a row drills in, exactly like tapping the map).
  /// Only shown when [data] is provided.
  final bool showDataList;

  /// Color of region borders.
  final Color borderColor;

  /// Width of region borders in logical pixels.
  final double borderWidth;

  /// Fill color of the currently selected region. Defaults to a lightened
  /// version of its own color.
  final Color? highlightColor;

  /// Style for the painted region labels.
  final TextStyle? labelTextStyle;

  /// Builds the content of the info panel for the selected region — the
  /// place to show your own data (population, offices, statistics...).
  final Widget Function(BuildContext context, BdRegion region)? infoBuilder;

  /// Called whenever any region is tapped (before drilling in).
  final ValueChanged<BdRegion>? onRegionTap;

  /// Called when the view drills in or out. `null` means country level.
  final ValueChanged<BdRegion?>? onLevelChanged;

  /// Duration of the zoom animation between levels.
  final Duration animationDuration;

  /// Curve of the zoom animation between levels.
  final Curve animationCurve;

  /// Background color behind the map.
  final Color? backgroundColor;

  @override
  State<BdMap> createState() => _BdMapState();
}

class _BdMapState extends State<BdMap> with SingleTickerProviderStateMixin {
  static const List<Color> _defaultPalette = <Color>[
    Color(0xFF00796B),
    Color(0xFF43A047),
    Color(0xFF7CB342),
    Color(0xFF26A69A),
    Color(0xFF2E7D32),
    Color(0xFF66BB6A),
    Color(0xFF00897B),
    Color(0xFF558B2F),
    Color(0xFF388E3C),
    Color(0xFF4DB6AC),
    Color(0xFF81C784),
    Color(0xFF33691E),
    Color(0xFF00695C),
  ];

  /// Drill path: empty = country level (divisions visible).
  final List<BdRegion> _stack = <BdRegion>[];

  BdRegion? _selected;
  BdRegion? _hovered;

  late final AnimationController _controller;
  late Animation<Rect?> _viewport;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    final country = _countryViewport();
    _viewport = AlwaysStoppedAnimation<Rect?>(country);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- geometry

  /// World space: x in [0, aspect], y in [0, 1] (uniform units).
  static Rect _worldBounds(BdRegion region) {
    final b = region.bounds;
    return Rect.fromLTRB(
      b.left * kBdMapAspectRatio,
      b.top,
      b.right * kBdMapAspectRatio,
      b.bottom,
    );
  }

  Rect _countryViewport() =>
      const Rect.fromLTWH(0, 0, kBdMapAspectRatio, 1).inflate(0.01);

  Rect _viewportFor(BdRegion? region) {
    if (region == null) return _countryViewport();
    final b = _worldBounds(region);
    return b.inflate(b.longestSide * 0.04);
  }

  // -------------------------------------------------------------- navigation

  List<BdRegion> get _visibleRegions {
    if (_stack.isEmpty) return BdGeo.divisions;
    return BdGeo.childrenOf(_stack.last);
  }

  bool _canDrillInto(BdRegion region) =>
      region.level.index < widget.maxLevel.index &&
      BdGeo.childrenOf(region).isNotEmpty;

  void _animateTo(Rect target) {
    final current = _viewport.value ?? _countryViewport();
    _viewport = _controller.drive(
      RectTween(begin: current, end: target).chain(
        CurveTween(curve: widget.animationCurve),
      ),
    );
    _controller.forward(from: 0);
  }

  void _drillInto(BdRegion region) {
    setState(() {
      _stack.add(region);
      _selected = null;
      _hovered = null;
    });
    _animateTo(_viewportFor(region));
    widget.onLevelChanged?.call(region);
  }

  void _popTo(int depth) {
    if (depth >= _stack.length) return;
    setState(() {
      _stack.removeRange(depth, _stack.length);
      _selected = null;
      _hovered = null;
    });
    _animateTo(_viewportFor(_stack.isEmpty ? null : _stack.last));
    widget.onLevelChanged?.call(_stack.isEmpty ? null : _stack.last);
  }

  void _handleTap(BdRegion region) {
    widget.onRegionTap?.call(region);
    if (_canDrillInto(region)) {
      _drillInto(region);
    } else if (identical(_selected, region)) {
      _clearSelection();
    } else {
      // Leaf region (upazila/thana): select it and zoom the map into it.
      setState(() => _selected = region);
      _animateTo(_viewportFor(region));
    }
  }

  void _clearSelection() {
    if (_selected == null) return;
    setState(() => _selected = null);
    _animateTo(_viewportFor(_stack.isEmpty ? null : _stack.last));
  }

  // -------------------------------------------------------------- hit testing

  BdRegion? _regionAt(Offset local, Size size) {
    final viewport = _viewport.value ?? _countryViewport();
    final t = _MapTransform.fit(viewport, size);
    final world = t.toWorld(local);
    final x = world.dx / kBdMapAspectRatio;
    final y = world.dy;
    for (final region in _visibleRegions) {
      if (region.containsPoint(x, y)) return region;
    }
    return null;
  }

  // -------------------------------------------------------------------- build

  String _labelOf(BdRegion r) =>
      widget.useBanglaNames ? r.displayNameBn : r.name;

  /// The palette fill the painter gives [r] at the current level — used to
  /// keep the data list's color dots in sync with the map.
  Color _paletteColorOf(BdRegion r) {
    final palette = widget.palette ?? _defaultPalette;
    final index = _visibleRegions.indexOf(r);
    return palette[(index < 0 ? 0 : index) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showBreadcrumb) _buildBreadcrumb(context),
        Flexible(
          child: AspectRatio(
            aspectRatio: kBdMapAspectRatio,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return MouseRegion(
                  onHover: (event) {
                    final r = _regionAt(event.localPosition, size);
                    if (!identical(r, _hovered)) {
                      setState(() => _hovered = r);
                    }
                  },
                  onExit: (_) {
                    if (_hovered != null) setState(() => _hovered = null);
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final r = _regionAt(details.localPosition, size);
                      if (r != null) _handleTap(r);
                    },
                    child: AnimatedBuilder(
                      animation: _controller,
                      // Clip: a zoomed-in viewport paints geometry well
                      // outside the canvas otherwise (over the breadcrumb
                      // and neighboring widgets).
                      builder: (context, _) => ClipRect(
                        child: CustomPaint(
                          size: size,
                          painter: _DrilldownPainter(
                            regions: _visibleRegions,
                            viewport: _viewport.value ?? _countryViewport(),
                            palette: widget.palette ?? _defaultPalette,
                            regionColorBuilder: widget.regionColorBuilder,
                            borderColor: widget.borderColor,
                            borderWidth: widget.borderWidth,
                            selected: _selected,
                            hovered: _hovered,
                            highlightColor: widget.highlightColor,
                            showLabels: widget.showLabels,
                            labelOf: _labelOf,
                            labelTextStyle: widget.labelTextStyle ??
                                Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: Colors.white) ??
                                const TextStyle(
                                    fontSize: 10, color: Colors.white),
                            backgroundColor: widget.backgroundColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_selected != null &&
            (widget.infoBuilder != null || widget.showInfoPanel))
          _buildInfoPanel(context, _selected!),
        if (widget.data != null && widget.showDataList)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: BdRegionDataList(
              regions: _visibleRegions,
              data: widget.data,
              useBanglaNames: widget.useBanglaNames,
              onTap: _handleTap,
              regionColor: _paletteColorOf,
              shrinkWrap: true,
              dense: true,
              padding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  Widget _buildBreadcrumb(BuildContext context) {
    final theme = Theme.of(context);
    final crumbs = <Widget>[
      _crumb(context, widget.useBanglaNames ? 'বাংলাদেশ' : 'Bangladesh',
          onTap: _stack.isEmpty ? null : () => _popTo(0)),
    ];
    for (var i = 0; i < _stack.length; i++) {
      crumbs.add(Icon(Icons.chevron_right,
          size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)));
      final isLast = i == _stack.length - 1;
      crumbs.add(_crumb(context, _labelOf(_stack[i]),
          onTap: isLast && _selected == null
              ? null
              : isLast
                  ? _clearSelection
                  : () => _popTo(i + 1)));
    }
    if (_selected != null) {
      crumbs.add(Icon(Icons.chevron_right,
          size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)));
      crumbs.add(_crumb(context, _labelOf(_selected!)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (_stack.isNotEmpty || _selected != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              tooltip: 'Back',
              visualDensity: VisualDensity.compact,
              onPressed: () => _selected != null
                  ? _clearSelection()
                  : _popTo(_stack.length - 1),
            ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: crumbs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _crumb(BuildContext context, String text, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleSmall?.copyWith(
      color: onTap == null
          ? theme.colorScheme.onSurface
          : theme.colorScheme.primary,
      fontWeight: onTap == null ? FontWeight.w600 : FontWeight.w400,
    );
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(text, style: style),
    );
    if (onTap == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: child,
    );
  }

  Widget _buildInfoPanel(BuildContext context, BdRegion region) {
    final theme = Theme.of(context);
    final children = BdGeo.childrenOf(region);
    // List the same union regions the map draws, so the panel can never
    // under-report (the curated name list misses metro-thana wards).
    final unions =
        region.level == BdArea.upazila ? children : const <BdRegion>[];
    String levelName(BdArea l) {
      switch (l) {
        case BdArea.division:
          return widget.useBanglaNames ? 'বিভাগ' : 'Division';
        case BdArea.district:
          return widget.useBanglaNames ? 'জেলা' : 'District';
        case BdArea.upazila:
          return widget.useBanglaNames ? 'উপজেলা / থানা' : 'Upazila / Thana';
        case BdArea.union:
          return widget.useBanglaNames ? 'ইউনিয়ন / ওয়ার্ড' : 'Union / Ward';
      }
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
                    widget.useBanglaNames ? region.displayNameBn : region.name,
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
            if (region.bnName.isNotEmpty && !widget.useBanglaNames)
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
            if (children.isNotEmpty &&
                (region.level == BdArea.division ||
                    region.level == BdArea.district))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  region.level == BdArea.division
                      ? (widget.useBanglaNames
                          ? '${children.length}টি জেলা'
                          : '${children.length} districts')
                      : (widget.useBanglaNames
                          ? '${children.length}টি উপজেলা/থানা'
                          : '${children.length} upazilas / thanas'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (unions.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  widget.useBanglaNames
                      ? 'ইউনিয়নসমূহ (${unions.length}টি)'
                      : 'Unions (${unions.length})',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
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
                              widget.useBanglaNames ? u.displayNameBn : u.name,
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
                  widget.useBanglaNames
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

/// Maps a world-space viewport rect onto a canvas of the given size
/// (fit-contain, centered).
class _MapTransform {
  _MapTransform(this.scale, this.offset);

  factory _MapTransform.fit(Rect viewport, Size size) {
    final scale = (size.width / viewport.width)
        .clamp(0.0, size.height / viewport.height)
        .toDouble();
    final dx =
        (size.width - viewport.width * scale) / 2 - viewport.left * scale;
    final dy =
        (size.height - viewport.height * scale) / 2 - viewport.top * scale;
    return _MapTransform(scale, Offset(dx, dy));
  }

  final double scale;
  final Offset offset;

  Offset toCanvas(Offset world) => world * scale + offset;
  Offset toWorld(Offset canvas) => (canvas - offset) / scale;
}

class _DrilldownPainter extends CustomPainter {
  _DrilldownPainter({
    required this.regions,
    required this.viewport,
    required this.palette,
    required this.regionColorBuilder,
    required this.borderColor,
    required this.borderWidth,
    required this.selected,
    required this.hovered,
    required this.highlightColor,
    required this.showLabels,
    required this.labelOf,
    required this.labelTextStyle,
    required this.backgroundColor,
  });

  final List<BdRegion> regions;
  final Rect viewport;
  final List<Color> palette;
  final Color? Function(BdRegion)? regionColorBuilder;
  final Color borderColor;
  final double borderWidth;
  final BdRegion? selected;
  final BdRegion? hovered;
  final Color? highlightColor;
  final bool showLabels;
  final String Function(BdRegion) labelOf;
  final TextStyle labelTextStyle;
  final Color? backgroundColor;

  Path _worldPath(BdRegion region) {
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
  }

  Color _fillFor(BdRegion region, int index) {
    final custom = regionColorBuilder?.call(region);
    final base = custom ?? palette[index % palette.length];
    if (identical(region, selected)) {
      return highlightColor ?? Color.lerp(base, Colors.white, 0.35)!;
    }
    if (identical(region, hovered)) {
      return Color.lerp(base, Colors.white, 0.18)!;
    }
    if (selected != null) {
      // Another region is zoomed in — fade its siblings into the background.
      return base.withValues(alpha: 0.35);
    }
    return base;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColor != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor!);
    }
    final t = _MapTransform.fit(viewport, size);

    canvas.save();
    canvas.translate(t.offset.dx, t.offset.dy);
    canvas.scale(t.scale);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth / t.scale
      ..strokeJoin = StrokeJoin.round
      ..color = borderColor;

    for (var i = 0; i < regions.length; i++) {
      final region = regions[i];
      final path = _worldPath(region);
      canvas.drawPath(path, Paint()..color = _fillFor(region, i));
      canvas.drawPath(path, stroke);
    }
    canvas.restore();

    if (!showLabels) return;

    for (final region in regions) {
      final label = labelOf(region);
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelTextStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final b = region.bounds;
      final regionWidthPx = b.width * kBdMapAspectRatio * t.scale;
      // Skip labels that clearly do not fit inside their region.
      if (tp.width > regionWidthPx * 1.05) continue;

      final p = region.labelPoint;
      final c = t.toCanvas(Offset(p.dx * kBdMapAspectRatio, p.dy));
      if (c.dx < -tp.width ||
          c.dy < -tp.height ||
          c.dx > size.width + tp.width ||
          c.dy > size.height + tp.height) {
        continue;
      }
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_DrilldownPainter oldDelegate) =>
      oldDelegate.regions != regions ||
      oldDelegate.viewport != viewport ||
      oldDelegate.selected != selected ||
      oldDelegate.hovered != hovered ||
      oldDelegate.palette != palette ||
      oldDelegate.showLabels != showLabels;
}
