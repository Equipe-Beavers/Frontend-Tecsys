import 'package:flutter/material.dart';
import 'package:frontend_tecsys/models/perfil_rf.dart';
import 'package:frontend_tecsys/pages/perfil_rf_page.dart';
import 'package:frontend_tecsys/services/perfis_rf_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class BibliotecaPage extends StatefulWidget {
  const BibliotecaPage({super.key, this.servico});

  final PerfisRfService? servico;

  @override
  State<BibliotecaPage> createState() => _BibliotecaPageState();
}

class _BibliotecaPageState extends State<BibliotecaPage> {
  late final PerfisRfService _servico = widget.servico ?? PerfisRfService();
  List<PerfilRf> _perfis = [];
  bool _carregando = true;
  String? _erro;
  int _aba = 1;
  final Set<int> _excluindo = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    if (widget.servico == null) _servico.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final perfis = await _servico.listar();
      if (mounted)
        setState(() {
          _perfis = perfis;
          _carregando = false;
        });
    } catch (erro) {
      if (mounted)
        setState(() {
          _erro = erro.toString();
          _carregando = false;
        });
    }
  }

  Future<void> _abrirFormulario([PerfilRf? perfil]) async {
    final salvo = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PerfilRfPage(perfil: perfil, servico: _servico),
      ),
    );
    if (salvo == true && mounted) await _carregar();
  }

  Future<void> _excluir(PerfilRf perfil) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Excluir perfil RF?'),
        content: Text(
          'Excluir "${perfil.nome}"? Os parâmetros dos estudos já salvos serão mantidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    setState(() => _excluindo.add(perfil.id!));
    try {
      await _servico.excluir(perfil.id!);
      if (mounted)
        setState(() => _perfis.removeWhere((item) => item.id == perfil.id));
    } catch (erro) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível excluir: $erro')),
        );
    } finally {
      if (mounted) setState(() => _excluindo.remove(perfil.id));
    }
  }

  String _numero(num? valor) =>
      valor == null ? '—' : valor.toString().replaceAll('.', ',');

  Widget _cartao(PerfilRf perfil) => Material(
    color: AppColors.surfaceCard,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _excluindo.contains(perfil.id)
          ? null
          : () => _abrirFormulario(perfil),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    perfil.nome,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Excluir perfil',
                  onPressed: _excluindo.contains(perfil.id)
                      ? null
                      : () => _excluir(perfil),
                  icon: _excluindo.contains(perfil.id)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                ),
              ],
            ),
            Text(
              perfil.modeloGateway,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 14,
              children: [
                _detalhe('FREQUÊNCIA', '${_numero(perfil.frequenciaMhz)} MHz'),
                _detalhe(
                  'POTÊNCIA TX',
                  '${_numero(perfil.potenciaTransmissaoDbm)} dBm',
                ),
                _detalhe(
                  'SENSIBILIDADE RX',
                  '${_numero(perfil.sensibilidadeRecepcaoDbm)} dBm',
                ),
                _detalhe('ALTURA', '${_numero(perfil.alturaGatewayM)} m'),
                _detalhe(
                  'CAPACIDADE',
                  _numero(perfil.capacidadeMaxEquipamentos),
                ),
                _detalhe(
                  'CUSTO',
                  perfil.custoEstimadoGateway == null
                      ? '—'
                      : 'R\$ ${_numero(perfil.custoEstimadoGateway)}',
                  cor: Colors.amber,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _detalhe(
    String rotulo,
    String valor, {
    Color cor = AppColors.textWhite,
  }) => SizedBox(
    width: 132,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(valor, style: TextStyle(fontSize: 13, color: cor)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Biblioteca',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              if (_aba == 1)
                FilledButton.icon(
                  onPressed: () => _abrirFormulario(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Novo perfil'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryLime,
                    foregroundColor: AppColors.textDark,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Critérios')),
                ButtonSegment(value: 1, label: Text('Perfis de RF')),
              ],
              selected: {_aba},
              showSelectedIcon: false,
              onSelectionChanged: (selecionadas) =>
                  setState(() => _aba = selecionadas.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primaryLime,
                selectedForegroundColor: AppColors.textDark,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _aba == 0 ? const SizedBox.expand() : _conteudo()),
      ],
    ),
  );

  Widget _conteudo() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryLime),
      );
    }
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Não foi possível carregar os perfis.\n$_erro',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _carregar,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _carregar,
      child: LayoutBuilder(
        builder: (contexto, limites) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            if (_perfis.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nenhum perfil RF cadastrado.',
                  textAlign: TextAlign.center,
                ),
              ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _perfis
                  .map(
                    (perfil) => SizedBox(
                      width: limites.maxWidth >= 760
                          ? (limites.maxWidth - 56) / 2
                          : limites.maxWidth - 40,
                      child: _cartao(perfil),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
