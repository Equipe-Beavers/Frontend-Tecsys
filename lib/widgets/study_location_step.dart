import 'package:flutter/material.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/widgets/city_bairro_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/filter_chip.dart';

class StudyLocationStep extends StatelessWidget {
  const StudyLocationStep({
    super.key,
    required this.distribuidoras,
    required this.ativos,
    required this.distribuidoraSelecionada,
    required this.municipioSelecionado,
    required this.bairroSelecionado,
    required this.localizacaoHabilitada,
    required this.onDistribuidoraChanged,
    required this.onLocationConfirmed,
  });

  final List<DistribuidoraResumo> distribuidoras;
  final List<AtivoBdgd> ativos;
  final DistribuidoraResumo? distribuidoraSelecionada;
  final String? municipioSelecionado;
  final String? bairroSelecionado;
  final bool localizacaoHabilitada;
  final ValueChanged<DistribuidoraResumo?> onDistribuidoraChanged;
  final void Function(String? municipio, String? bairro) onLocationConfirmed;

  List<String> get _municipiosDisponiveis {
    final municipios =
        ativos
            .map((ativo) => ativo.municipio.trim())
            .where(
              (municipio) =>
                  municipio.isNotEmpty && municipio != 'Não informado',
            )
            .toSet()
            .toList()
          ..sort();
    return municipios;
  }

  Map<String, List<String>> get _bairrosPorMunicipio {
    return {
      for (final municipio in _municipiosDisponiveis)
        municipio:
            (ativos
                .where((ativo) => ativo.municipio.trim() == municipio)
                .map((ativo) => ativo.bairro.trim())
                .where(
                  (bairro) => bairro.isNotEmpty && bairro != 'Não informado',
                )
                .toSet()
                .toList()
              ..sort()),
    };
  }

  Future<void> _abrirSelecaoDistribuidora(BuildContext context) {
    return SelectionBottomSheet.show<DistribuidoraResumo>(
      context: context,
      title: 'Selecionar distribuidora',
      stepLabel: 'PASSO 1 DE 4',
      searchHint: 'Buscar distribuidora',
      notFoundMessage: distribuidoras.isEmpty
          ? 'Não foi possível carregar as distribuidoras.'
          : 'Não encontrada',
      items: distribuidoras
          .map(
            (distribuidora) => SelectionItem<DistribuidoraResumo>(
              title: distribuidora.nome,
              value: distribuidora,
            ),
          )
          .toList(),
      selectedValue: distribuidoraSelecionada,
      onSelected: onDistribuidoraChanged,
    );
  }

  Future<void> _abrirSelecaoMunicipioBairro(BuildContext context) {
    final municipios = _municipiosDisponiveis;
    final nomeDistribuidora = distribuidoraSelecionada?.nome;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CidadeBairroBottomSheet(
        cidades: municipios,
        bairrosPorCidade: _bairrosPorMunicipio,
        cidadeSelecionada: municipioSelecionado,
        bairroSelecionado: bairroSelecionado,
        stepLabel: 'PASSO 2 DE 4',
        allowEmptySelection: false,
        breadcrumb: nomeDistribuidora == null
            ? null
            : '$nomeDistribuidora · Selecione o município',
        notFoundMessage: municipios.isEmpty
            ? 'Nenhuma cidade encontrada para a distribuidora selecionada.'
            : 'Não encontrada',
        onProsseguir: onLocationConfirmed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      children: [
        FilterChipWidget(
          label: distribuidoraSelecionada?.nome ?? 'DIST.',
          isSelected: true,
          onTap: () => _abrirSelecaoDistribuidora(context),
        ),
        FilterChipWidget(
          label: municipioSelecionado ?? 'Cidade / bairro',
          onTap: () {
            if (!localizacaoHabilitada || distribuidoraSelecionada == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Selecione uma distribuidora e aguarde o carregamento dos ativos.',
                  ),
                ),
              );
              return;
            }
            _abrirSelecaoMunicipioBairro(context);
          },
        ),
      ],
    );
  }
}
