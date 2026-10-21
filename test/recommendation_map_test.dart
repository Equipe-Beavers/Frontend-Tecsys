import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/mocks/recomendacao_mock.dart';
import 'package:frontend_tecsys/models/recomendacao_resultado.dart';
import 'package:frontend_tecsys/pages/gateway_detail_page.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/recommendation_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
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

    await tester.tap(find.byKey(const ValueKey('gateway-14')));
    await tester.pump();
    expect(selected?.idEstudoPonto, 14);
  });

  testWidgets('study result uses the same light map tiles as the home page', (
    tester,
  ) async {
    final result = buildRecommendationMock();
    await _pumpMap(
      tester,
      RecommendationMap(gateways: result.gateways, assets: result.ativosMapa),
      settle: false,
    );

    final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(tileLayer.tileBuilder, isNull);
    expect(tileLayer.panBuffer, 0);
    expect(tileLayer.tileDisplay, isA<InstantaneousTileDisplay>());

    final circle = tester
        .widget<CircleLayer>(find.byType(CircleLayer))
        .circles
        .first;
    expect(circle.color, AppColors.coverageArea.withValues(alpha: .24));
    expect(circle.borderColor, AppColors.coverageBorder.withValues(alpha: .9));
    expect(circle.borderStrokeWidth, 1.8);
  });

  testWidgets('map keeps the same tile layer after changing to a mobile size', (
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
    final initialTileLayer = tester.state(find.byType(TileLayer));

    resize(() => mobile = true);
    await tester.pump();
    await tester.pump();

    expect(find.byType(TileLayer), findsOneWidget);
    expect(tester.state(find.byType(TileLayer)), same(initialTileLayer));
    expect(tester.widget<TileLayer>(find.byType(TileLayer)).panBuffer, 0);
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

    final flags = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .options
        .interactionOptions
        .flags;
    expect(InteractiveFlag.hasDrag(flags), isTrue);
    expect(InteractiveFlag.hasPinchZoom(flags), isTrue);
    expect(InteractiveFlag.hasScrollWheelZoom(flags), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'result and gateway maps fit coverage with 20 percent margin and block zoom out',
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

        final options = tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .options;
        final fit = options.initialCameraFit! as FitBounds;
        final constraint = options.cameraConstraint as ContainCameraCenter;

        expect(options.minZoom, closeTo(options.initialZoom, .0001));
        expect(fit.bounds.north, greaterThan(constraint.bounds.north));
        expect(fit.bounds.south, lessThan(constraint.bounds.south));
        expect(fit.bounds.east, greaterThan(constraint.bounds.east));
        expect(fit.bounds.west, lessThan(constraint.bounds.west));
        for (final gateway in visibleGateways) {
          expect(
            fit.bounds.contains(LatLng(gateway.latitude, gateway.longitude)),
            isTrue,
          );
        }

        if (selectedGateway != null) {
          const distance = Distance();
          final marginRadius = distance.as(
            LengthUnit.Meter,
            LatLng(selectedGateway.latitude, selectedGateway.longitude),
            LatLng(fit.bounds.north, selectedGateway.longitude),
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
