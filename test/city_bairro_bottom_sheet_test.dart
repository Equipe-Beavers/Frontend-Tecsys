import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/widgets/city_bairro_bottom_sheet.dart';

void main() {
  testWidgets('confirma a cidade e o bairro selecionados', (tester) async {
    String? cidadeConfirmada;
    String? bairroConfirmado;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CidadeBottomSheet(
            cidades: const ['Cidade A'],
            bairrosPorCidade: const {
              'Cidade A': ['Bairro A', 'Bairro B'],
            },
            onProsseguirComBairro: (cidade, bairro) {
              cidadeConfirmada = cidade;
              bairroConfirmado = bairro;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cidade A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bairro B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prosseguir'));

    expect(cidadeConfirmada, 'Cidade A');
    expect(bairroConfirmado, 'Bairro B');
  });
}
