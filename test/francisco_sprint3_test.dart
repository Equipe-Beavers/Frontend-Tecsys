import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/controllers/study_area_count_controller.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/models/recomendacao_resultado.dart';
import 'package:frontend_tecsys/mocks/recomendacao_mock.dart';
import 'package:frontend_tecsys/utils/study_area_format.dart';
import 'package:frontend_tecsys/widgets/city_bairro_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/map_navigation.dart';
import 'package:frontend_tecsys/widgets/study_area_step.dart';
import 'package:frontend_tecsys/widgets/recommendation/gateway_recommendation_card.dart';
import 'package:frontend_tecsys/widgets/recommendation/recommendation_kpis.dart';
import 'package:frontend_tecsys/widgets/recommendation/recommendation_map_overlays.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

const area = [LatLng(-23, -45), LatLng(-23, -44.999), LatLng(-22.999, -45)];
void main() {
  test('áreas pequenas são exibidas em metros quadrados', () {
    expect(formatStudyArea(0.000125), '125,0 m²');
    expect(formatStudyArea(0.00000025), '0,25 m²');
    expect(formatStudyArea(38.4), '38,4 km²');
  });
  test('contagem usa polígono fechado e não envia filtros de camadas ou limite', () async {
    final service = AtivosService(client: MockClient((request) async {
      expect(request.url.path, '/ativos/contagem-area');
      final payload = jsonDecode(request.body) as Map;
      expect(payload.keys.toSet(), {'geom', 'distribuidora'});
      final ring = payload['geom']['coordinates'][0] as List;
      expect(ring.first, [-45, -23]);
      expect(ring.last, ring.first);
      return http.Response('{"total":9876}', 200);
    }));
    addTearDown(service.dispose);
    expect(await service.contarAtivosNaArea(area, distribuidora: 'EDP SP'), 9876);
  });
  testWidgets('contagem ignora resposta antiga e reseta ao refazer área', (tester) async {
    final service = _Counts();
    final controller = StudyAreaCountController(service);
    addTearDown(controller.dispose);addTearDown(service.dispose);
    controller.updateArea(area);
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.loading, isTrue);
    expect(controller.count, isNull);
    controller.updateArea([...area, const LatLng(-22.999, -44.999)]);
    await tester.pump(const Duration(milliseconds: 400));
    service.requests[0].complete(4);
    await tester.pump();
    expect(controller.count, isNull);
    service.requests[1].complete(8000);
    await tester.pump();
    expect(controller.count, 8000);
    controller.updateArea(const []);
    expect(controller.count, 0);expect(controller.loading, isFalse);
  });
  testWidgets('falha de contagem não é apresentada como zero e pode repetir', (tester) async {
    final service = _Counts();final controller = StudyAreaCountController(service);
    addTearDown(controller.dispose);addTearDown(service.dispose);
    controller.updateArea(area);await tester.pump(const Duration(milliseconds: 400));
    service.requests.single.completeError(StateError('indisponível'));await tester.pump();
    expect(controller.count, isNull);expect(controller.error, isNotNull);
    controller.updateArea(area);await tester.pump(const Duration(milliseconds: 400));
    service.requests.last.complete(0);await tester.pump();
    expect(controller.count, 0);expect(controller.error, isNull);
  });
  testWidgets('resposta após descarte da contagem é ignorada', (tester) async {
    final service = _Counts();final controller = StudyAreaCountController(service);
    addTearDown(service.dispose);
    controller.updateArea(area);await tester.pump(const Duration(milliseconds: 400));
    controller.dispose();service.requests.single.complete(3);await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('navegação mantém apenas zoom e filtro oferece somente cidades', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      MapNavigationControls(onZoomIn: () {}, onZoomOut: () {}),
      Expanded(child: CidadeBottomSheet(cidades: const ['Jacareí'], onProsseguir: (_) {})),
    ]))));
    expect(find.byIcon(Icons.my_location), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.text('Cidade'), findsOneWidget);
    expect(find.textContaining('bairro'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Jac');await tester.pump();
    expect(find.text('Jacareí'), findsOneWidget);
  });
  testWidgets('gateway sem ID BDGD tem seta e legenda de ativos não cobertos sem custo', (tester) async {
    final gateway = GatewayProposto(idEstudoPonto: 1, idAtivoBdgd: null, rotulo: 'Manual', latitude: -23, longitude: -45, quantidadeAtendidos: 0, atributos: const {}, atendidos: const []);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      GatewayRecommendationCard(gateway: gateway, onTap: () {}),
      RecommendationKpis(result: buildRecommendationMock()),
      const RecommendationMapLegend(gatewayCount: 1),
    ]))));
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.textContaining('CUSTO'), findsNothing);
    expect(find.text('Ativo não coberto'), findsOneWidget);
  });
  testWidgets('área pequena e falha da contagem exibem unidade e ação corretas', (tester) async {
    var retry = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StudyAreaStep(
      locationLabel: '', areaDesenhada: true, areaKm2: 0.000125, ativosNaArea: null,
      erroAtivos: 'Tentar novamente', onTentarContagem: () => retry = true,
      onCancelar: () {}, onRefazer: () {}, onProsseguir: () {},
    ))));
    expect(find.text('125,0 m²'), findsOneWidget);expect(find.text('Indisponível'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));expect(retry, isTrue);
  });
}
class _Counts extends AtivosService {
  final requests = <Completer<int>>[];
  @override
  Future<int> contarAtivosNaArea(List<LatLng> pontos, {String? distribuidora}) {
    final request = Completer<int>();requests.add(request);return request.future;
  }
}
