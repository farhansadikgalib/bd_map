import 'package:bd_map/bd_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:example/main.dart' as app;

/// Mirrors the internal viewport/fit math of [BdMap] so
/// tests can convert a region's normalized [BdRegion.labelPoint] into a
/// global screen offset to tap.
Offset screenPointFor(
  WidgetTester tester,
  Finder mapPaint,
  BdRegion region, {
  BdRegion? zoomedInto,
}) {
  final rect = tester.getRect(mapPaint);

  Rect worldBounds(BdRegion r) {
    final b = r.bounds;
    return Rect.fromLTRB(
      b.left * kBdMapAspectRatio,
      b.top,
      b.right * kBdMapAspectRatio,
      b.bottom,
    );
  }

  final Rect viewport = zoomedInto == null
      ? const Rect.fromLTWH(0, 0, kBdMapAspectRatio, 1).inflate(0.01)
      : () {
          final b = worldBounds(zoomedInto);
          return b.inflate(b.longestSide * 0.04);
        }();

  final scale = (rect.width / viewport.width)
      .clamp(0.0, rect.height / viewport.height)
      .toDouble();
  final dx = (rect.width - viewport.width * scale) / 2 - viewport.left * scale;
  final dy = (rect.height - viewport.height * scale) / 2 - viewport.top * scale;

  final world = Offset(
    region.labelPoint.dx * kBdMapAspectRatio,
    region.labelPoint.dy,
  );
  final local = world * scale + Offset(dx, dy);
  return rect.topLeft + local;
}

/// The map canvas is the CustomPaint inside the drill-down map's
/// AspectRatio. (Scoping matters: on Android other widgets in the
/// breadcrumb row can introduce their own CustomPaint.)
Finder drilldownPaint() => find
    .descendant(
      of: find.descendant(
        of: find.byType(BdMap),
        matching: find.byType(AspectRatio),
      ),
      matching: find.byType(CustomPaint),
    )
    .first;

Future<void> settle(WidgetTester tester) =>
    tester.pumpAndSettle(const Duration(milliseconds: 100));

/// Taps [region] on the drill-down canvas and waits for the animation.
/// Logs the geometry so failures are diagnosable from the driver output.
Future<void> tapRegion(
  WidgetTester tester,
  BdRegion region, {
  BdRegion? zoomedInto,
}) async {
  final paint = drilldownPaint();
  final rect = tester.getRect(paint);
  final point = screenPointFor(tester, paint, region, zoomedInto: zoomedInto);
  final view = tester.view.physicalSize / tester.view.devicePixelRatio;
  debugPrint('TAP ${region.id}: rect=$rect point=$point view=$view');
  await tester.tapAt(point);
  await settle(tester);
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .take(12)
      .join(' | ');
  debugPrint('TAP ${region.id}: visible texts after tap: $texts');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('BdGeo data API', () {
    test('has all 8 divisions and 64 districts', () {
      expect(BdGeo.divisions, hasLength(8));
      expect(BdGeo.districts, hasLength(64));
    });

    test('hierarchy lookups work in English and Bangla', () {
      final dhaka = BdGeo.divisionByName('Dhaka');
      expect(dhaka, isNotNull);
      expect(BdGeo.divisionByName('ঢাকা')!.id, dhaka!.id);
      expect(BdGeo.childrenOf(dhaka), hasLength(13));

      final cumilla = BdGeo.districtByName('Cumilla');
      expect(cumilla, isNotNull);
      expect(BdGeo.childrenOf(cumilla!), isNotEmpty);
    });

    test('every district belongs to a division, upazilas have geometry', () {
      for (final district in BdGeo.districts) {
        expect(district.parentId, isNotNull);
      }
      final upazilas = BdGeo.childrenOf(BdGeo.districtByName('Dhaka')!);
      for (final u in upazilas) {
        expect(u.rawPolygons, isNotEmpty);
        expect(u.bnName, isNotEmpty);
      }
    });
  });

  testWidgets('full drill-down journey', (tester) async {
    app.main();
    await settle(tester);

    // --- Country level: all 8 divisions visible, breadcrumb shows root.
    expect(find.byType(BdMap), findsOneWidget);
    expect(find.text('Bangladesh'), findsWidgets);

    // --- Tap Dhaka division -> drills into its districts.
    final dhakaDivision = BdGeo.divisionByName('Dhaka')!;
    await tapRegion(tester, dhakaDivision);
    expect(find.text('Dhaka'), findsWidgets,
        reason: 'breadcrumb should now contain Dhaka');

    // --- Tap Gazipur district -> drills into its upazilas.
    final gazipur = BdGeo.districtByName('Gazipur')!;
    await tapRegion(tester, gazipur, zoomedInto: dhakaDivision);
    expect(find.text('Gazipur'), findsWidgets);

    // --- Tap an upazila -> drills into its union map.
    final upazilas = BdGeo.childrenOf(gazipur);
    final kaliakair = upazilas.firstWhere((u) => u.name.contains('Kaliakair'),
        orElse: () => upazilas.first);
    await tapRegion(tester, kaliakair, zoomedInto: gazipur);
    expect(find.text(kaliakair.name), findsWidgets,
        reason: 'breadcrumb should now contain the upazila');

    // --- Tap a union (leaf) -> selects it and opens the info panel.
    final unions = BdGeo.childrenOf(kaliakair);
    await tapRegion(tester, unions.first, zoomedInto: kaliakair);
    expect(find.text('Union / Ward'), findsOneWidget,
        reason: 'info panel should show the level chip for the selection');

    // --- Breadcrumb "Bangladesh" pops all the way back to country level.
    await tester.tap(find.descendant(
      of: find.byType(BdMap),
      matching: find.text('Bangladesh'),
    ));
    await settle(tester);
    expect(find.text('Gazipur'), findsNothing);

    // --- Bangla mode: toggle the language button, labels become Bangla.
    await tester.tap(find.text('বাংলা'));
    await settle(tester);
    expect(find.text('বাংলাদেশ'), findsWidgets);
    await tester.tap(find.text('EN'));
    await settle(tester);

    // --- Classic page renders the original widget.
    await tester.tap(find.text('Classic'));
    await settle(tester);
    expect(find.byType(Bangladesh), findsOneWidget);

    // --- Atlas page: whole country at district level; tap a district to
    // open its info panel. The canvas has the world aspect ratio, so a
    // label point maps to the canvas by proportion.
    await tester.tap(find.text('Atlas'));
    await settle(tester);
    expect(find.byType(BdCountryMap), findsOneWidget);
    final atlasPaint = find
        .descendant(
          of: find.descendant(
            of: find.byType(BdCountryMap),
            matching: find.byType(AspectRatio),
          ),
          matching: find.byType(CustomPaint),
        )
        .first;
    final atlasRect = tester.getRect(atlasPaint);
    final dhakaDistrict = BdGeo.districtByName('Dhaka')!;
    await tester.tapAt(atlasRect.topLeft +
        Offset(dhakaDistrict.labelPoint.dx * atlasRect.width,
            dhakaDistrict.labelPoint.dy * atlasRect.height));
    await settle(tester);
    expect(find.text('District'), findsWidgets,
        reason: 'info panel should show the district level chip');
  });

  testWidgets('map-only screenshots', (tester) async {
    // A lean screen with just a map and no app bar, so the map fills the
    // phone. Uses the example palette so the shots match the demo app.
    Widget lean(Widget map) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: const Color(0xFF006A4E)),
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                child: map,
              ),
            ),
          ),
        );

    // Country level without the breadcrumb, which would only read
    // "Bangladesh" here.
    await tester.pumpWidget(
        lean(const BdMap(palette: app.kMapPalette, showBreadcrumb: false)));
    await settle(tester);
    await binding.convertFlutterSurfaceToImage();
    await settle(tester);
    await binding.takeScreenshot('01-drilldown-divisions');

    // Drill sequence with the breadcrumb visible.
    await tester.pumpWidget(lean(const BdMap(palette: app.kMapPalette)));
    await settle(tester);

    final dhaka = BdGeo.divisionByName('Dhaka')!;
    await tapRegion(tester, dhaka);
    await binding.takeScreenshot('02-drilldown-districts');

    final gazipur = BdGeo.districtByName('Gazipur')!;
    await tapRegion(tester, gazipur, zoomedInto: dhaka);
    await binding.takeScreenshot('03-drilldown-upazilas');

    final upazilas = BdGeo.childrenOf(gazipur);
    final kaliakair = upazilas.firstWhere((u) => u.name.contains('Kaliakair'),
        orElse: () => upazilas.first);
    await tapRegion(tester, kaliakair, zoomedInto: gazipur);
    await binding.takeScreenshot('04-drilldown-unions');

    // --- One shot per map widget in the package default look, for the
    // "Show a map" table.
    await tester.pumpWidget(lean(
        const BdMap(key: ValueKey('default-look'), showBreadcrumb: false)));
    await settle(tester);
    await binding.takeScreenshot('map-drilldown');

    await tester.pumpWidget(lean(const BdCountryMap(BdArea.district)));
    await settle(tester);
    await binding.takeScreenshot('map-country');

    await tester.pumpWidget(lean(const Center(child: Bangladesh())));
    await settle(tester);
    await binding.takeScreenshot('map-classic');
  });

  testWidgets('back button navigates one level up', (tester) async {
    app.main();
    await settle(tester);

    final dhakaDivision = BdGeo.divisionByName('Dhaka')!;
    await tapRegion(tester, dhakaDivision);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);
    expect(find.byIcon(Icons.arrow_back), findsNothing,
        reason: 'back at country level the back button disappears');
  });
}
