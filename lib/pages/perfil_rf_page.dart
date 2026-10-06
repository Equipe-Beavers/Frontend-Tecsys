import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frontend_tecsys/models/perfil_rf.dart';
import 'package:frontend_tecsys/services/perfis_rf_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class PerfilRfPage extends StatefulWidget {
  const PerfilRfPage({super.key, this.perfil, required this.servico});
  final PerfilRf? perfil;
  final PerfisRfService servico;

  @override
  State<PerfilRfPage> createState() => _PerfilRfPageState();
}

class _PerfilRfPageState extends State<PerfilRfPage> {
  final _formulario = GlobalKey<FormState>();
  final Map<String, TextEditingController> _campos = {};
  bool _salvando = false;
  late bool _relevo;
  late bool _vegetacao;
  late bool _edificacoes;
  late bool _antenas;

  @override
  void initState() {
    super.initState();
    final perfil = widget.perfil ?? PerfilRf.padrao;
    final valores = {
      'nome': widget.perfil?.nome ?? '',
      'frequencia': perfil.frequenciaMhz,
      'potencia': perfil.potenciaTransmissaoDbm,
      'alturaAntena':
          perfil.caracteristicasAntena['altura_m'] ?? perfil.alturaGatewayM,
      'alturaGateway': perfil.alturaGatewayM,
      'alturaDispositivo': perfil.alturaDispositivoM,
      'capacidade': perfil.capacidadeMaxEquipamentos,
    };
    for (final entrada in valores.entries) {
      _campos[entrada.key] = TextEditingController(
        text: entrada.value?.toString() ?? '',
      );
    }
    _relevo = perfil.consideraRelevo;
    _vegetacao = perfil.consideraVegetacao;
    _edificacoes = perfil.consideraEdificacoes;
    _antenas = perfil.caracteristicasAntena['considera_antenas'] == true;
  }

  @override
  void dispose() {
    for (final campo in _campos.values) {
      campo.dispose();
    }
    super.dispose();
  }

  double? _numero(String chave) =>
      double.tryParse(_campos[chave]!.text.trim().replaceAll(',', '.'));

  Future<void> _salvar() async {
    if (_salvando || !_formulario.currentState!.validate()) return;
    final potencia = _numero('potencia')!;
    final perfil = widget.perfil ?? PerfilRf.padrao;
    final sensibilidade = perfil.sensibilidadeRecepcaoDbm;
    if (sensibilidade >= potencia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A sensibilidade RX deve ser menor que a potência TX.'),
        ),
      );
      return;
    }
    setState(() => _salvando = true);
    try {
      await widget.servico.salvar(
        PerfilRf(
          id: widget.perfil?.id,
          idUsuario: widget.perfil?.idUsuario ?? 1,
          nome: _campos['nome']!.text.trim(),
          modeloGateway: perfil.modeloGateway,
          frequenciaMhz: _numero('frequencia')!,
          potenciaTransmissaoDbm: potencia,
          sensibilidadeRecepcaoDbm: sensibilidade,
          alturaGatewayM: _numero('alturaGateway')!,
          alturaDispositivoM: _numero('alturaDispositivo')!,
          alcanceEstimadoM: widget.perfil?.alcanceEstimadoM,
          capacidadeMaxEquipamentos: _numero('capacidade')?.toInt(),
          quantidadeCanais: perfil.quantidadeCanais,
          limiteMensagens: perfil.limiteMensagens,
          periodoLimiteMensagens: perfil.periodoLimiteMensagens,
          custoEstimadoGateway: perfil.custoEstimadoGateway,
          caracteristicasAntena: {
            ...perfil.caracteristicasAntena,
            'altura_m': _numero('alturaAntena'),
            'considera_antenas': _antenas,
          },
          parametrosAdicionais: perfil.parametrosAdicionais,
          consideraRelevo: _relevo,
          consideraVegetacao: _vegetacao,
          consideraEdificacoes: _edificacoes,
          consideraObstaculos: perfil.consideraObstaculos,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (erro) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar o perfil: $erro')),
        );
      }
    }
  }

  Widget _campo(
    String chave,
    String rotulo, {
    bool numerico = true,
    bool obrigatorio = true,
    double? minimo,
    double? maximo,
    bool inteiro = false,
    String? unidade,
  }) => TextFormField(
    key: ValueKey(chave),
    controller: _campos[chave],
    enabled: !_salvando,
    keyboardType: numerico
        ? const TextInputType.numberWithOptions(decimal: true, signed: true)
        : TextInputType.text,
    decoration: InputDecoration(
      labelText: rotulo,
      suffixText: unidade,
      filled: true,
      fillColor: AppColors.surfaceInput,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
    validator: (texto) {
      if (texto == null || texto.trim().isEmpty) {
        return obrigatorio ? 'Campo obrigatório' : null;
      }
      if (!numerico) return null;
      final valor = _numero(chave);
      if (valor == null || !valor.isFinite) return 'Informe um número válido';
      if (inteiro && valor != valor.roundToDouble()) {
        return 'Informe um número inteiro';
      }
      if (minimo != null && valor < minimo) return 'Valor mínimo: $minimo';
      if (maximo != null && valor > maximo) return 'Valor máximo: $maximo';
      return null;
    },
  );

  Widget _secao(String titulo, List<Widget> campos) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        titulo,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 16),
      for (final campo in campos)
        Padding(padding: const EdgeInsets.only(bottom: 16), child: campo),
    ],
  );

  Widget _par(Widget primeiro, Widget segundo) => LayoutBuilder(
    builder: (contexto, limites) => limites.maxWidth < 280
        ? Column(children: [primeiro, const SizedBox(height: 16), segundo])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: primeiro),
              const SizedBox(width: 12),
              Expanded(child: segundo),
            ],
          ),
  );

  String _formatar(double valor) =>
      valor.toStringAsFixed(1).replaceAll('.', ',');

  double? get _alcanceKm {
    final alcance = widget.perfil?.alcanceEstimadoM;
    return alcance != null && alcance.isFinite && alcance > 0
        ? alcance / 1000
        : null;
  }

  Widget _alcance() => TextFormField(
    key: const ValueKey('alcance'),
    initialValue: _alcanceKm == null ? '—' : _formatar(_alcanceKm!),
    readOnly: true,
    style: const TextStyle(color: AppColors.primaryLime),
    decoration: InputDecoration(
      labelText: 'Alcance estimado',
      suffixText: 'km',
      filled: true,
      fillColor: AppColors.surfaceInput,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryLime),
      ),
    ),
  );

  Widget _opcao(String titulo, bool valor, ValueChanged<bool> alterar) =>
      Material(
        color: AppColors.surfaceInput,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(titulo, style: const TextStyle(fontSize: 13)),
          activeThumbColor: AppColors.primaryLime,
          value: valor,
          onChanged: _salvando ? null : alterar,
        ),
      );

  Widget _previa() {
    final alcance = _alcanceKm;
    final cobertura = alcance == null ? null : math.pi * alcance * alcance;
    final custo = widget.perfil?.custoEstimadoGateway;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: _secao('PRÉVIA DO PERFIL', [
        AspectRatio(
          aspectRatio: 2.2,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceBackground,
              gradient: alcance == null
                  ? null
                  : RadialGradient(
                      colors: [
                        AppColors.primaryLime.withValues(alpha: 0.3),
                        AppColors.surfaceBackground,
                      ],
                      radius: 0.65,
                    ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLime,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Text(
                    'raio ${alcance == null ? '—' : _formatar(alcance)} km',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _indicador(
              'COBERTURA/GW',
              cobertura == null ? '—' : '${_formatar(cobertura)} km²',
            ),
            _indicador(
              'CUSTO/km²',
              cobertura == null || custo == null
                  ? '—'
                  : 'R\$ ${_formatar(custo / cobertura)}',
              cor: Colors.orange,
            ),
          ],
        ),
      ]),
    );
  }

  Widget _indicador(String rotulo, String valor, {Color? cor}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        rotulo,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
      ),
      const SizedBox(height: 4),
      Text(valor, style: TextStyle(color: cor ?? AppColors.textWhite)),
    ],
  );

  Widget _acoes() => Wrap(
    alignment: WrapAlignment.end,
    spacing: 12,
    runSpacing: 8,
    children: [
      OutlinedButton(
        onPressed: _salvando ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryLime,
          foregroundColor: AppColors.textDark,
        ),
        onPressed: _salvando ? null : _salvar,
        icon: _salvando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined, size: 18),
        label: Text(_salvando ? 'Salvando' : 'Salvar perfil'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_salvando,
    child: Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBackground,
        title: Text(
          widget.perfil == null ? 'Novo perfil de RF' : 'Editar perfil de RF',
          style: const TextStyle(fontSize: 18),
        ),
        actions: MediaQuery.sizeOf(context).width >= 800
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: _acoes(),
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formulario,
        child: LayoutBuilder(
          builder: (contexto, limites) {
            final radio = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secao('NOME DO PERFIL', [
                  _campo('nome', 'Nome do perfil', numerico: false),
                ]),
                _secao('PARÂMETROS DE RF', [
                  _par(
                    _campo(
                      'frequencia',
                      'Frequência',
                      minimo: 0.001,
                      unidade: 'MHz',
                    ),
                    _campo(
                      'potencia',
                      'Potência TX',
                      minimo: -100,
                      maximo: 100,
                      unidade: 'dBm',
                    ),
                  ),
                  _par(
                    _campo(
                      'alturaAntena',
                      'Altura da antena',
                      minimo: 0.01,
                      unidade: 'm',
                    ),
                    _alcance(),
                  ),
                ]),
                _secao('PARÂMETROS DE IMPLANTAÇÃO', [
                  _campo(
                    'alturaGateway',
                    'Altura do gateway em relação ao solo',
                    minimo: 0.01,
                    unidade: 'm',
                  ),
                  _campo(
                    'alturaDispositivo',
                    'Altura do ativo em relação ao solo',
                    minimo: 0.01,
                    unidade: 'm',
                  ),
                ]),
              ],
            );
            final capacidade = _secao('CONDIÇÕES DE COBERTURA', [
              _campo(
                'capacidade',
                'Máx. equipamentos atendidos',
                obrigatorio: false,
                minimo: 1,
                inteiro: true,
              ),
              _opcao(
                'Consideração de relevo',
                _relevo,
                (valor) => setState(() => _relevo = valor),
              ),
              _opcao(
                'Consideração de vegetação',
                _vegetacao,
                (valor) => setState(() => _vegetacao = valor),
              ),
              _opcao(
                'Consideração de edificações',
                _edificacoes,
                (valor) => setState(() => _edificacoes = valor),
              ),
              _opcao(
                'Consideração de antenas',
                _antenas,
                (valor) => setState(() => _antenas = valor),
              ),
              _previa(),
            ]);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: limites.maxWidth >= 800
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: radio),
                            const SizedBox(width: 24),
                            Expanded(child: capacidade),
                          ],
                        )
                      : Column(children: [radio, capacidade]),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width >= 800
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceCard,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: _acoes(),
              ),
            ),
    ),
  );
}
