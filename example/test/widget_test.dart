import 'package:bd_map/bd_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('example app renders all three pages', (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The app decodes its JSON asset on a background isolate, so let that
    // finish in real time before pumping on the fake clock.
    await tester.runAsync(() async {
      await tester.pumpWidget(const BangladeshMapApp());
      await rootBundle.loadString('assets/bd_data_full_country.json');
    });
    await tester.pumpAndSettle();

    // Explore page is shown first with the drill-down map.
    expect(find.byType(BdMap), findsOneWidget);

    // The JSON asset (assets/bd_data_full_country.json) loaded: the ranked
    // data list below the map shows Dhaka's population.
    expect(find.byType(BdRegionDataList), findsOneWidget);
    expect(find.text('44.2M'), findsOneWidget);

    // Atlas page shows the full-country wall map with the level switcher.
    await tester.tap(find.text('Atlas'));
    await tester.pumpAndSettle();
    expect(find.byType(BdCountryMap), findsOneWidget);
    expect(find.text('Division'), findsOneWidget);
    expect(find.text('Union'), findsOneWidget);

    // Classic page renders the original widget.
    await tester.tap(find.text('Classic'));
    await tester.pumpAndSettle();
    expect(find.byType(Bangladesh), findsOneWidget);
  });

  testWidgets('API list source feeds the maps through the same pattern',
      (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(const BangladeshMapApp());
      await rootBundle.loadString('assets/bd_data_full_country.json');
    });
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.storage));
    await tester.pumpAndSettle();
    await tester.tap(find.text('API list'));
    await tester.pumpAndSettle();

    // The canned API response lists three divisions; Rajshahi is only in it.
    expect(find.byType(BdRegionDataList), findsOneWidget);
    expect(find.text('20.4M'), findsOneWidget);
  });

  testWidgets('language toggle switches the app to Bangla', (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BangladeshMapApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();
    expect(find.text('বাংলাদেশ'), findsWidgets);
  });
}
