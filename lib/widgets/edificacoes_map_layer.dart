import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend_tecsys/models/edificacao.dart';
import 'package:frontend_tecsys/services/edificacoes_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/edificacao_detail_sheet.dart';

/// Estado e camadas das edificações e da mancha de cobertura no mapa principal.
///
/// Fica separado do `MapPage` para que a tela só precise:
/// - repassar `aoPressionarLongo` no `onLongPress` das `MapOptions`;
/// - incluir `...camadas()` nos `children` do `FlutterMap`;
/// - chamar `alternarEdificacoes` no chip "Edificações".
class EdificacoesMapController extends ChangeNotifier {
  EdificacoesMapController(this._mapController, {EdificacoesService? service})
      : _service = service ?? EdificacoesService() {
    // Recarrega as edificações quando o mapa se move, sem depender do onPositionChanged da tela.
    _inscricaoMapa = _mapController.mapEventStream.listen((_) {
      if (mostrarEdificacoes) _agendarCarregamento();
    });
  }

  static const double zoomMinimo = 16;

  final MapController _mapController;
  final EdificacoesService _service;

  bool mostrarEdificacoes = false;
  List<Edificacao> edificacoes = [];
  ManchaCobertura? mancha;
  LatLng? gatewaySimulado;
  bool calculandoMancha = false;

  Timer? _debounce;
  bool carregandoEdificacoes = false;
  String? erroEdificacoes;
  BuildContext? _contextoAvisos;
  StreamSubscription<MapEvent>? _inscricaoMapa;
  int _sequencia = 0;
  bool _descartado = false;

  void _atualizar() {
    if (!_descartado) notifyListeners();
  }

  static void _aviso(BuildContext context, String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensagem,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primaryLime,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void alternarEdificacoes(BuildContext context) {
    mostrarEdificacoes = !mostrarEdificacoes;
    if (!mostrarEdificacoes) edificacoes = [];
    _atualizar();

    if (!mostrarEdificacoes) return;

    _contextoAvisos = context;
    if (_mapController.camera.zoom < zoomMinimo) {
      _aviso(context, 'Aproxime o mapa (zoom 16 ou mais) para ver as edificações.');
    }
    _agendarCarregamento();
  }

  void _agendarCarregamento() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _carregarEdificacoes);
  }

  Future<void> _carregarEdificacoes() async {
    if (!mostrarEdificacoes || _descartado) return;

    final camera = _mapController.camera;
    if (camera.zoom < zoomMinimo) {
      if (edificacoes.isNotEmpty) {
        edificacoes = [];
        _atualizar();
      }
      return;
    }

    final sequencia = ++_sequencia;
    final bounds = camera.visibleBounds;
    carregandoEdificacoes = true;
    _atualizar();

    // O backend consulta a Overture Maps sob demanda; nada é importado para o banco.
    try {
      final resultado = await _service.getEdificacoes(
        minLatitude: bounds.south,
        maxLatitude: bounds.north,
        minLongitude: bounds.west,
        maxLongitude: bounds.east,
      );
      if (sequencia != _sequencia || !mostrarEdificacoes) return;
      edificacoes = resultado;
      erroEdificacoes = null;
    } catch (error) {
      if (sequencia != _sequencia) return;
      debugPrint('Falha ao carregar edificações: $error');
      final mensagem = error is StateError ? error.message : 'Não foi possível carregar as edificações.';
      // Avisa uma vez por erro, para não repetir a cada movimento do mapa.
      final contexto = _contextoAvisos;
      if (mensagem != erroEdificacoes && contexto != null && contexto.mounted) {
        _aviso(contexto, mensagem);
      }
      erroEdificacoes = mensagem;
    } finally {
      if (sequencia == _sequencia) {
        carregandoEdificacoes = false;
        _atualizar();
      }
    }
  }

  Edificacao? _edificacaoNoPonto(LatLng ponto) {
    for (final edificacao in edificacoes) {
      if (edificacao.contem(ponto)) return edificacao;
    }
    return null;
  }

  /// Pressionar e segurar no mapa: ver a edificação ou calcular a mancha de um gateway no ponto.
  Future<void> aoPressionarLongo(BuildContext context, LatLng ponto) async {
    final edificacao = _edificacaoNoPonto(ponto);

    final opcao = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (edificacao != null)
              ListTile(
                leading: Icon(Icons.apartment, color: edificacao.cor),
                title: const Text(
                  'Ver edificação',
                  style: TextStyle(color: AppColors.textWhite),
                ),
                subtitle: Text(
                  '${edificacao.alturaM.toStringAsFixed(1)} m de altura · ${edificacao.nomeMaterial}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                onTap: () => Navigator.pop(ctx, 'edificacao'),
              ),
            ListTile(
              leading: const Icon(Icons.wifi_tethering, color: AppColors.primaryLime),
              title: const Text(
                'Calcular mancha de um gateway aqui',
                style: TextStyle(color: AppColors.textWhite),
              ),
              subtitle: const Text(
                'Usa um perfil de RF cadastrado e as edificações da região.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              onTap: () => Navigator.pop(ctx, 'mancha'),
            ),
            if (mancha != null)
              ListTile(
                leading: const Icon(Icons.layers_clear, color: AppColors.textMuted),
                title: const Text(
                  'Remover mancha do mapa',
                  style: TextStyle(color: AppColors.textWhite),
                ),
                onTap: () => Navigator.pop(ctx, 'limpar'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (context is Element && !context.mounted) return;

    if (opcao == 'edificacao' && edificacao != null) {
      await EdificacaoDetailSheet.exibir(context, edificacao: edificacao);
    } else if (opcao == 'mancha') {
      await _calcularMancha(context, ponto);
    } else if (opcao == 'limpar') {
      mancha = null;
      gatewaySimulado = null;
      _atualizar();
    }
  }

  Future<int?> _perguntarPerfilRf(BuildContext context) {
    final controller = TextEditingController(text: '1');

    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Perfil de RF', style: TextStyle(color: AppColors.textWhite)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: const InputDecoration(
            labelText: 'ID do perfil de RF',
            labelStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: const Text('Calcular'),
          ),
        ],
      ),
    );
  }

  Future<void> _calcularMancha(BuildContext context, LatLng ponto) async {
    final idPerfilRf = await _perguntarPerfilRf(context);
    if (idPerfilRf == null || (context is Element && !context.mounted)) return;

    calculandoMancha = true;
    _atualizar();
    _aviso(context, 'Calculando a mancha de cobertura...');

    try {
      final resultado = await _service.gerarMancha(
        latitude: ponto.latitude,
        longitude: ponto.longitude,
        idPerfilRf: idPerfilRf,
      );

      mancha = resultado;
      gatewaySimulado = ponto;

      if (resultado.pontos.length >= 3) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(resultado.pontos),
            padding: const EdgeInsets.all(48),
          ),
        );
      }

      if (context is Element && context.mounted) {
        _aviso(
          context,
          'Alcance médio de ${resultado.alcanceMedioM} m'
          '${resultado.edificacoesConsideradas ? ' (com ${resultado.quantidadeEdificacoes} edificações)' : ' (sem edificações)'}.'
          '${resultado.erroEdificacoes != null ? ' ${resultado.erroEdificacoes}' : ''}',
        );
      }
    } catch (error) {
      if (context is Element && context.mounted) _aviso(context, '$error');
    } finally {
      calculandoMancha = false;
      _atualizar();
    }
  }

  /// Camadas para os `children` do `FlutterMap` (depois do `TileLayer`).
  List<Widget> camadas() {
    return [
      if (mostrarEdificacoes && edificacoes.isNotEmpty)
        PolygonLayer(
          polygons: <Polygon<Object>>[
            for (final edificacao in edificacoes)
              for (final poligono in edificacao.poligonos)
                Polygon<Object>(
                  points: poligono,
                  color: edificacao.cor.withOpacity(0.45),
                  borderColor: edificacao.cor,
                  borderStrokeWidth: 1,
                ),
          ],
        ),
      if (mancha != null && mancha!.pontos.length >= 3)
        PolygonLayer(
          polygons: <Polygon<Object>>[
            Polygon<Object>(
              points: mancha!.pontos,
              color: AppColors.secondaryTeal.withOpacity(0.25),
              borderColor: AppColors.secondaryTeal,
              borderStrokeWidth: 2,
            ),
          ],
        ),
      if (gatewaySimulado != null)
        MarkerLayer(
          markers: [
            Marker(
              point: gatewaySimulado!,
              width: 36,
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.secondaryTeal, width: 2),
                ),
                child: const Icon(
                  Icons.wifi_tethering,
                  color: AppColors.secondaryTeal,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
    ];
  }

  @override
  void dispose() {
    _descartado = true;
    _debounce?.cancel();
    _inscricaoMapa?.cancel();
    _service.dispose();
    super.dispose();
  }
}
