import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/models/perfil_rf.dart';

void main() {
  test('Preserva os parametros de RF na conversao da API', () {
    final dados = {
      ...PerfilRf.padrao.toJson(),
      'id_perfil_rf': 7,
      'parametros_adicionais': {
        'ganho_adicional_db': -3,
        'modelo_propagacao': 'hata',
      },
      'considera_relevo': true,
      'capacidade_max_equipamentos': 1200,
    };
    final perfil = PerfilRf.fromJson(dados);
    expect(perfil.id, 7);
    expect(perfil.toJson(), {...dados}..remove('id_perfil_rf'));
  });
}
