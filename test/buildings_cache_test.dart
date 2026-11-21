import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/services/edificacoes_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> building(String id, double lat, double lon) => {
  'id': id,
  'latitude': lat,
  'longitude': lon,
  'altura_m': 6,
  'geometria': {
    'type': 'Polygon',
    'coordinates': [
      [
        [lon - .001, lat - .001],
        [lon + .001, lat - .001],
        [lon + .001, lat + .001],
        [lon - .001, lat + .001],
        [lon - .001, lat - .001],
      ],
    ],
  },
};
http.Response response({int total = 2}) => http.Response(
  jsonEncode({
    'data': [building('a', -23.15, -45.85), building('b', -23.12, -45.82)],
    'total': total,
  }),
  200,
);
Future<dynamic> query(
  EdificacoesService service, {
  bool inside = false,
  int limit = 2000,
}) => service.getEdificacoes(
  minLatitude: inside ? -23.151 : -23.2,
  maxLatitude: inside ? -23.149 : -23.1,
  minLongitude: inside ? -45.851 : -45.9,
  maxLongitude: inside ? -45.849 : -45.8,
  limit: limit,
);
void main() {
  test('compartilha requisições simultâneas e reutiliza resposta ao reativar camada', () async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final service = EdificacoesService(
      client: MockClient((_) {
        calls++;
        return pending.future;
      }),
    );
    addTearDown(service.dispose);
    final a = query(service), b = query(service);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    pending.complete(response());
    await Future.wait([a, b]);
    expect((await query(service)).length, 2);
    expect(calls, 1);
  });
  test(
    'recorta viewport já carregado sem nova requisição e inclui borda',
    () async {
      var calls = 0;
      final service = EdificacoesService(
        client: MockClient((_) async {
          calls++;
          return response();
        }),
      );
      addTearDown(service.dispose);
      await query(service);
      final smaller = await query(service, inside: true);
      expect(smaller.map((b) => b.id), ['a']);
      expect(calls, 1);
    },
  );
  test(
    'não recorta resposta truncada nem a reutiliza com limite diferente',
    () async {
      var calls = 0;
      final service = EdificacoesService(
        client: MockClient((_) async {
          calls++;
          return response(total: 10);
        }),
      );
      addTearDown(service.dispose);
      await query(service, limit: 2);
      await query(service, inside: true, limit: 2);
      await query(service, limit: 5);
      expect(calls, 3);
    },
  );
  test('expira dados antigos e não guarda falha como cache vazio', () async {
    var calls = 0;
    var now = DateTime(2026);
    final service = EdificacoesService(
      now: () => now,
      client: MockClient((_) async {
        calls++;
        return calls == 1 ? http.Response('{}', 503) : response();
      }),
    );
    addTearDown(service.dispose);
    await expectLater(query(service), throwsStateError);
    await query(service);
    expect(calls, 2);
    await query(service);
    expect(calls, 2);
    now = now.add(const Duration(minutes: 6));
    await query(service);
    expect(calls, 3);
  });
}
