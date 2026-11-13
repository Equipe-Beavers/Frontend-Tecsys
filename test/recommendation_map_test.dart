import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/mocks/recomendacao_mock.dart';
import 'package:frontend_tecsys/models/mancha_cenario.dart';
import 'package:frontend_tecsys/models/recomendacao_resultado.dart';
import 'package:frontend_tecsys/pages/gateway_detail_page.dart';
import 'package:frontend_tecsys/widgets/recommendation_map.dart';
import 'package:frontend_tecsys/widgets/recommendation/recommendation_map_overlays.dart';
import 'package:frontend_tecsys/widgets/recommendation/recommendation_map_viewport.dart';
import 'package:frontend_tecsys/widgets/recommendation/responsive_recommendation_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('keeps coverage from the recommendation response in both maps', (
    tester,
  ) async {
    final gateway = GatewayProposto.fromJson({
      'id_estudo_ponto': 7,
      'latitude': -23.19,
      'longitude': -45.88,
      'quantidade_atendidos': 0,
      'mancha_cobertura': {
        'type': 'MultiPolygon',
        'coordinates': [
          [
            [
              [-45.89, -23.18],
              [-45.87, -23.18],
              [-45.88, -23.20],
              [-45.89, -23.18],
            ],
          ],
          [
            [
              [-45.90, -23.18],
              [-45.89, -23.18],
              [-45.90, -23.19],
              [-45.90, -23.18],
            ],
          ],
        ],
      },
    });
    for (final selected in [false, true]) {
      await _pumpMap(
        tester,
        RecommendationMap(
          gateways: [gateway],
          selectedGateway: selected ? gateway : null,
          showBaseMap: false,
        ),
      );
      final map = tester.widget<ResponsiveRecommendationMap>(
        find.byType(ResponsiveRecommendationMap),
      );
      expect(map.scenarioCoverage, hasLength(2));
      expect(
        map.scenarioCoverage.first.mancha.first,
        const LatLng(-23.18, -45.89),
      );
      expect(
        find.byKey(const ValueKey('scenario-coverage-layer-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('scenario-coverage-layer-1')),
        findsOneWidget,
      );
    }
  });

  testWidgets('renders backend scenario coverage as a polygon layer', (
    tester,
  ) async {
    final result = buildRecommendationMock();
    final gateway = result.gateways.first;
    final coverage = ManchaGatewayCenario(
      idEstudoPonto: gateway.idEstudoPonto,
      rotulo: gateway.rotulo,
      posicao: LatLng(gateway.latitude, gateway.longitude),
      alcanceMedioM: 4200,
      mancha: const [
        LatLng(-23.18, -45.90),
        LatLng(-23.18, -45.87),
        LatLng(-23.21, -45.88),
      ],
    );

    await _pumpMap(
      tester,
      RecommendationMap(
        gateways: result.gateways,
        assets: result.ativosMapa,
        scenarioCoverage: [coverage],
        showBaseMap: false,
      ),
    );

    expect(
      find.byKey(const ValueKey('scenario-coverage-layer-0')),
      findsOneWidget,
    );
    final map = tester.widget<ResponsiveRecommendationMap>(
      find.byType(ResponsiveRecommendationMap),
    );
    expect(map.scenarioCoverage.single.mancha, coverage.mancha);
  });

  testWidgets('gateway marker is selectable from the map', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = buildRecommendationMock();
    GatewayProposto? selected;
    await _pumpMap(
      tester,
      RecommendationMap(
        gateways: result.gateways,
        assets: result.ativosMapa,
        onGatewayTap: (gateway) => selected = gateway,
        showBaseMap: false,
      ),
    );

    expect(find.text('Ativo coberto'), findsOneWidget);
    expect(find.text('Sem cobertura'), findsOneWidget);
    expect(find.byKey(const ValueKey('covered-asset-1401')), findsOneWidget);
    expect(find.byKey(const ValueKey('uncovered-asset-1403')), findsOneWidget);

    tester
        .widget<GestureDetector>(find.byKey(const ValueKey('gateway-14')))
        .onTap!();
    await tester.pump();
    expect(selected?.idEstudoPonto, 14);
  });

  testWidgets('study result uses the same Mapbox map as the home page', (
    tester,
  ) async {
    final result = buildRecommendationMock();
    await _pumpMap(
      tester,
      RecommendationMap(gateways: result.gateways, assets: result.ativosMapa),
      settle: false,
    );

    final map = tester.widget<ResponsiveRecommendationMap>(
      find.byType(ResponsiveRecommendationMap),
    );
    expect(map.showBaseMap, isTrue);
    expect(map.gateways, result.gateways);
    expect(
      find.byKey(const ValueKey('recommendation-mapbox-test-surface')),
      findsOneWidget,
    );
  });

  testWidgets('map keeps the same Mapbox state after changing to mobile size', (
    tester,
  ) async {
    final result = buildRecommendationMock();
    var mobile = false;
    late StateSetter resize;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              resize = setState;
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: mobile ? 350 : 1000,
                  height: mobile ? 300 : 600,
                  child: RecommendationMap(
                    gateways: result.gateways,
                    assets: result.ativosMapa,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final initialMapState = tester.state(
      find.byType(ResponsiveRecommendationMap),
    );

    resize(() => mobile = true);
    await tester.pump();
    await tester.pump();

    expect(find.byType(ResponsiveRecommendationMap), findsOneWidget);
    expect(
      tester.state(find.byType(ResponsiveRecommendationMap)),
      same(initialMapState),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop gateway legend uses the cumulative 1.44 scale', (
    tester,
  ) async {
    final result = buildRecommendationMock();

    Future<Size> legendSizeAt(Size screenSize) async {
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1;
      await _pumpMap(
        tester,
        RecommendationMap(
          gateways: result.gateways,
          assets: result.ativosMapa,
          showBaseMap: false,
        ),
        settle: false,
      );
      return tester
          .getRect(find.byKey(const ValueKey('gateway-map-legend')))
          .size;
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final mobileSize = await legendSizeAt(const Size(390, 800));
    final desktopSize = await legendSizeAt(const Size(1200, 800));

    expect(desktopSize.width, closeTo(mobileSize.width * 1.44, .1));
    expect(desktopSize.height, closeTo(mobileSize.height * 1.44, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('focused gateway map allows dragging and zoom', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = buildRecommendationMock();
    await tester.pumpWidget(
      MaterialApp(
        home: GatewayDetailPage(
          gateway: result.gateways.first,
          assets: result.ativosMapa,
          showBaseMap: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final map = tester.widget<ResponsiveRecommendationMap>(
      find.byType(ResponsiveRecommendationMap),
    );
    expect(map.lockPosition, isTrue);
    expect(find.byType(RecommendationZoomHint), findsNothing);
    expect(
      find.byKey(const ValueKey('recommendation-zoom-controls')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'result and gateway maps fit coverage and allow controlled zoom out',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final result = buildRecommendationMock();

      for (final selectedGateway in <GatewayProposto?>[
        null,
        result.gateways.first,
      ]) {
        final visibleGateways = selectedGateway == null
            ? result.gateways
            : [selectedGateway];
        await _pumpMap(
          tester,
          RecommendationMap(
            gateways: result.gateways,
            assets: result.ativosMapa,
            selectedGateway: selectedGateway,
            showBaseMap: false,
          ),
        );

        final viewport = RecommendationMapViewport.fromGateways(
          visibleGateways,
        )!;
        final fit = viewport.displayBounds;
        final constraint = viewport.coverageBounds;

        expect(recommendationMinimumZoom(12), 9);
        expect(recommendationMinimumZoom(20), recommendationMaximumZoom);
        expect(
          recommendationCameraSafetyZoomOut(390, focused: true),
          closeTo(.928511623 - .263034406, .000001),
        );
        expect(recommendationCameraSafetyZoomOut(1200), .15);
        expect(recommendationCameraSafetyZoomOut(390), -.35);

        expect(fit.north, greaterThan(constraint.north));
        expect(fit.south, lessThan(constraint.south));
        expect(fit.east, greaterThan(constraint.east));
        expect(fit.west, lessThan(constraint.west));
        for (final gateway in visibleGateways) {
          expect(gateway.latitude, inInclusiveRange(fit.south, fit.north));
          expect(gateway.longitude, inInclusiveRange(fit.west, fit.east));
        }

        if (selectedGateway != null) {
          const distance = Distance();
          final marginRadius = distance.as(
            LengthUnit.Meter,
            LatLng(selectedGateway.latitude, selectedGateway.longitude),
            LatLng(fit.north, selectedGateway.longitude),
          );
          expect(
            marginRadius,
            closeTo(selectedGateway.raioCoberturaM * 1.2, 2),
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'focused map keeps every covered asset inside the selected gateway radius',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final result = buildRecommendationMock();
      await _pumpMap(
        tester,
        RecommendationMap(
          gateways: result.gateways,
          assets: result.ativosMapa,
          selectedGateway: result.gateways.first,
          showBaseMap: false,
        ),
      );

      for (final id in [1401, 1402, 1501, 1502, 1602]) {
        expect(find.byKey(ValueKey('covered-asset-$id')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('covered-asset-1601')), findsNothing);
      expect(
        find.byKey(const ValueKey('uncovered-asset-1403')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('uncovered-asset-1503')), findsNothing);
    },
  );
}

Future<void> _pumpMap(
  WidgetTester tester,
  Widget map, {
  bool settle = true,
}) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: map)));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
