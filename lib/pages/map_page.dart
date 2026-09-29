import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:frontend_tecsys/widgets/layer_filter_button.dart';
import 'package:frontend_tecsys/widgets/search_bar.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/cidade_bottom_sheet.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/models/layer_filter.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/asset_detail_sheet.dart';
import 'package:frontend_tecsys/widgets/layer_filter_modal.dart';
import 'package:frontend_tecsys/widgets/map_navigation.dart';
import 'package:frontend_tecsys/widgets/filter_chip.dart';
import 'package:frontend_tecsys/pages/novo_estudo_page.dart';
import 'package:frontend_tecsys/utils/map_utils.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final AtivosService _ativosService = AtivosService();
  final TextEditingController _buscaController = TextEditingController();

  List<DistribuidoraResumo> _distribuidoras = [];
  String? _distribuidoraSelecionada;
  String? _municipioSelecionado;
  bool _regiaoConfirmada = false;
  double _currentZoom = 3.8;
  String _textoBusca = '';

  List<MunicipioResumo> _municipiosDaRegiao = [];
  bool _carregandoRegiao = false;
  String? _erroRegiao;

  List<AtivoBdgd> _todosAtivos = [];
  Map<TipoAtivo, bool> _camadasAtivas =
      CatalogoCamadas.obterEstadoInicialPadrao();
  AtivoBdgd? _ativoSelecionado;
  bool _carregando = false;
  String? _erro;

  Timer? _debounceTimer;
  int _sequenciaRequisicao = 0;
  bool _mapaPronto = false;

  static const int _limiteAtivos = 3000;

  final Map<Marker, AtivoBdgd> _markerAtivoMap = {};

  List<LatLng> polygonPoints = [];
  bool isDrawing = true;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _buscaController.dispose();
    _mapController.dispose();
    _ativosService.dispose();
    super.dispose();
  }

  void _aoMapaPronto() {
    setState(() => _mapaPronto = true);
  }

  void _agendarCarregamento() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), _carregarDados);
  }

  /// A região só fica pronta depois de distribuidora + cidade,
  /// e os ativos só são buscados quando há camada marcada nessa região.
  bool get _podeExibirBotaoCamadas => _regiaoConfirmada;

  bool get _podeCarregarAtivos =>
      _regiaoConfirmada &&
      _distribuidoraSelecionada != null &&
      _totalCamadasAtivas > 0;

  String get _rotuloRegiao {
    final cidade = _municipioSelecionado;

    if (cidade == null || cidade.isEmpty) return 'Região inteira';
    return cidade;
  }

  Future<void> _carregarDados() async {
    if (!_mapaPronto || !_podeCarregarAtivos) {
      if (_todosAtivos.isNotEmpty) {
        setState(() {
          _todosAtivos = [];
          _carregando = false;
          _erro = null;
        });
      }
      return;
    }

    final camadasApi = <String>{
      for (final entry in _camadasAtivas.entries)
        if (entry.value) entry.key.apiValue,
    };

    final sequencia = ++_sequenciaRequisicao;
    final bounds = _mapController.camera.visibleBounds;

    if (mounted) {
      setState(() {
        if (_todosAtivos.isEmpty) _carregando = true;
        _erro = null;
      });
    }

    try {
      final resultado = await _ativosService.getAtivos(
        minLatitude: bounds.south,
        maxLatitude: bounds.north,
        minLongitude: bounds.west,
        maxLongitude: bounds.east,
        distribuidora: _distribuidoraSelecionada,
        tipos: camadasApi,
        municipio: _municipioSelecionado,
        limit: _limiteAtivos,
      );

      if (!mounted || sequencia != _sequenciaRequisicao) {
        return;
      }

      setState(() {
        _todosAtivos = resultado.ativos;
        _carregando = false;
        _erro = resultado.ativos.isEmpty
            ? 'Nenhum ativo do banco local para '
                  '${_distribuidoraSelecionada ?? 'esta distribuidora'}'
                  '${_municipioSelecionado != null ? ' em $_municipioSelecionado' : ''} '
                  'nesta região do mapa.'
            : null;
      });
    } catch (error) {
      if (!mounted || sequencia != _sequenciaRequisicao) {
        return;
      }

      setState(() {
        _erro = 'Não foi possível carregar os ativos reais.';
        _carregando = false;
      });
    }
  }

  Future<void> _inicializar() async {
    try {
      final distribuidoras = await _ativosService.getDistribuidoras();

      if (!mounted) {
        return;
      }

      if (distribuidoras.isEmpty) {
        setState(() {
          _carregando = false;
          _erro = 'Nenhuma distribuidora foi retornada pela API.';
        });
        return;
      }

      // Nenhuma distribuidora é escolhida automaticamente: o fluxo exige
      // que o usuário selecione distribuidora e depois a cidade
      // antes de liberar o carregamento de ativos.
      setState(() {
        _distribuidoras = distribuidoras;
        _carregando = false;
        _erro = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = 'Não foi possível carregar as distribuidoras.';
        });
      }
    }
  }

  int get _totalCamadasAtivas =>
      _camadasAtivas.values.where((ativa) => ativa).length;

  bool get _nenhumaCamadaAtiva =>
      _camadasAtivas.values.every((ativa) => !ativa);

  String _rotuloAtivos(DistribuidoraResumo dist) {
    if (dist.totalAtivos <= 0) {
      return 'Sem ativos';
    }
    return '${_formatarContagem(dist.totalAtivos)} ativos';
  }

  String _formatarContagem(int valor) {
    final texto = valor.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < texto.length; i++) {
      if (i > 0 && (texto.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(texto[i]);
    }

    return buffer.toString();
  }

  Future<void> _selecionarDistribuidora(
    String? distribuidora, {
    String? stepLabel,
  }) async {
    if (distribuidora == null || distribuidora.isEmpty) {
      return;
    }

    final mudou = distribuidora != _distribuidoraSelecionada;

    if (mudou) {
      _debounceTimer?.cancel();
      // Invalida qualquer requisição de ativos ainda em andamento.
      _sequenciaRequisicao++;

      setState(() {
        _distribuidoraSelecionada = distribuidora;
        _municipioSelecionado = null;
        _regiaoConfirmada = false;
        _municipiosDaRegiao = [];
        _camadasAtivas = CatalogoCamadas.obterEstadoInicialPadrao();
        _todosAtivos = [];
        _ativoSelecionado = null;
        _textoBusca = '';
        _buscaController.clear();
        _erro = null;
        _carregando = false;
      });
    }

    await _abrirSelecaoCidade(stepLabel: stepLabel);
  }

  /// PASSO 2: busca as cidades da distribuidora (consulta leve,
  /// sem tocar na tabela de ativos) e abre o sheet de seleção.
  Future<void> _abrirSelecaoCidade({String? stepLabel}) async {
    final distribuidora = _distribuidoraSelecionada;
    if (distribuidora == null || !mounted) {
      return;
    }

    setState(() {
      _carregandoRegiao = true;
      _erroRegiao = null;
    });

    List<MunicipioResumo> municipios = [];
    String? erroRegiao;

    try {
      municipios = await _ativosService.getMunicipios(
        distribuidora: distribuidora,
      );
    } catch (_) {
      erroRegiao =
          'Não foi possível carregar as cidades da distribuidora selecionada.';
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _municipiosDaRegiao = municipios;
      _carregandoRegiao = false;
      _erroRegiao = erroRegiao;
    });

    await _mostrarSheetCidade(stepLabel: stepLabel);
  }

  Future<void> _mostrarSheetCidade({String? stepLabel}) async {
    final cidades = _municipiosDaRegiao
        .map((municipio) => municipio.nome)
        .toSet()
        .toList();
    var prosseguiu = false;
    String? cidadeEscolhida;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CidadeBottomSheet(
          cidades: cidades,
          cidadeSelecionada: _municipioSelecionado,
          stepLabel: stepLabel,
          breadcrumb: _distribuidoraSelecionada != null
              ? '$_distribuidoraSelecionada · Selecione o município'
              : null,
          notFoundMessage:
              _erroRegiao ??
              'Nenhuma cidade encontrada para a distribuidora selecionada.',
          onProsseguir: (cidade) {
            prosseguiu = true;
            cidadeEscolhida = cidade;
          },
        );
      },
    );

    if (!prosseguiu || !mounted) {
      return;
    }

    setState(() {
      _municipioSelecionado = cidadeEscolhida;
      _regiaoConfirmada = true;
      _erro = null;
    });

    _centralizarNaCidade(cidadeEscolhida);
    _agendarCarregamento();
  }

  void _centralizarNaCidade(String? cidade) {
    if (cidade == null || !_mapaPronto) {
      return;
    }

    MunicipioResumo? alvo;
    for (final municipio in _municipiosDaRegiao) {
      if (municipio.nome == cidade) {
        alvo = municipio;
        break;
      }
    }

    final latitude = alvo?.latitude;
    final longitude = alvo?.longitude;
    if (latitude == null || longitude == null) {
      return;
    }

    _currentZoom = 11.0;
    _mapController.move(LatLng(latitude, longitude), _currentZoom);
  }

  /// UF do município selecionado, usada para preencher o formulário de estudo.
  String? get _ufSelecionada {
    final cidade = _municipioSelecionado;
    if (cidade == null) return null;

    for (final municipio in _municipiosDaRegiao) {
      if (municipio.nome == cidade) {
        return municipio.uf;
      }
    }

    return null;
  }

  /// PASSO 1: escolha da distribuidora. Ao confirmar, abre direto o
  /// PASSO 2 (cidade) — só então o botão de camadas aparece.
  Future<void> _abrirSelecaoDistribuidora({
    String? stepLabel,
    String? proximoStepLabel,
  }) async {
    if (_distribuidoras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível carregar as distribuidoras.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await SelectionBottomSheet.show<String>(
      context: context,
      title: 'Selecionar distribuidora',
      subtitle: 'Os ativos só serão carregados após escolher a cidade.',
      stepLabel: stepLabel,
      searchHint: 'Buscar distribuidora',
      notFoundMessage: 'Não encontrada',
      items: _distribuidoras
          .map(
            (dist) => SelectionItem(
              title: dist.nome,
              subtitle: _rotuloAtivos(dist),
              value: dist.nome,
            ),
          )
          .toList(),
      selectedValue: _distribuidoraSelecionada,
      onSelected: (distribuidoraNome) async {
        await _selecionarDistribuidora(
          distribuidoraNome,
          stepLabel: proximoStepLabel,
        );
      },
    );
  }

  Future<void> _iniciarEstudo() async {
    await _abrirSelecaoDistribuidora(
      stepLabel: 'PASSO 1 DE 4',
      proximoStepLabel: 'PASSO 2 DE 4',
    );
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_mapController.camera.zoom + 1).clamp(3.8, 18.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
    _agendarCarregamento();
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_mapController.camera.zoom - 1).clamp(3.8, 18.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
    _agendarCarregamento();
  }

  void _onLocationPressed() {}

  List<AtivoBdgd> get _ativosVisiveis {
    final termo = _textoBusca.trim().toLowerCase();
    return _todosAtivos.where((ativo) {
      if (termo.isNotEmpty &&
          !(ativo.codId.toLowerCase().contains(termo) ||
              ativo.id.toLowerCase().contains(termo) ||
              ativo.municipio.toLowerCase().contains(termo) ||
              ativo.tipo.label.toLowerCase().contains(termo))) {
        return false;
      }

      if (_areaDesenhada &&
          !isPointInPolygon(
            LatLng(ativo.latitude, ativo.longitude),
            polygonPoints,
          )) {
        return false;
      }

      return true;
    }).toList();
  }

  void _aplicarBusca(String valor) {
    setState(() {
      _textoBusca = valor;
    });
  }

  /// Chip "Cidade": se ainda não há distribuidora escolhida,
  /// começa pelo PASSO 1; caso contrário vai direto ao PASSO 2.
  Future<void> _trocarCidade() async {
    if (_distribuidoraSelecionada == null) {
      await _abrirSelecaoDistribuidora();
      return;
    }

    await _abrirSelecaoCidade();
  }

  void _abrirPainelCamadas() {
    LayerFilterModal.exibir(
      context,
      camadasAtivas: _camadasAtivas,
      onSalvarFiltro: (novasCamadas) {
        setState(() {
          _camadasAtivas = novasCamadas;
        });

        _agendarCarregamento();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Camadas atualizadas: $_totalCamadasAtivas de ${_camadasAtivas.length} ativas',
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppColors.primaryLime,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _selecionarAtivo(AtivoBdgd ativo) {
    setState(() {
      _ativoSelecionado = ativo;
    });

    _mapController.move(
      LatLng(ativo.latitude, ativo.longitude),
      _mapController.camera.zoom.clamp(15.0, 18.0),
    );

    AssetDetailSheet.exibir(
      context,
      ativo: ativo,
      onFechar: () {
        if (mounted) {
          setState(() {
            _ativoSelecionado = null;
          });
        }
      },
    );
  }

  bool get _areaDesenhada => polygonPoints.length >= 3;

  void _cancelarArea() {
    setState(() => polygonPoints = []);
  }

  Future<void> _prosseguirArea() async {
    final estudoCriado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NovoEstudoPage(
          distribuidora: _distribuidoraSelecionada ?? '',
          municipio: _municipioSelecionado,
          uf: _ufSelecionada,
          areaKm2: calculatePolygonAreaKm2(polygonPoints),
          pontosArea: List.unmodifiable(polygonPoints),
          ativos: List.unmodifiable(_ativosVisiveis),
        ),
      ),
    );

    if (estudoCriado == true && mounted) {
      setState(() => polygonPoints = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Estudo criado e salvo no banco. Acompanhe na aba Estudos.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildBotoesArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: AppColors.surfaceCard,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${_ativosVisiveis.length} ativo(s) dentro da área selecionada',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelarArea,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceCard,
                  foregroundColor: AppColors.textWhite,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _prosseguirArea,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLime,
                  foregroundColor: AppColors.textDark,
                  elevation: 6,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  shadowColor: AppColors.primaryLime.withValues(alpha: 0.4),
                ),
                child: const Text(
                  'Prosseguir',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Marker> _gerarMarcadores() {
    _markerAtivoMap.clear();

    final ativosFiltrados = _ativosVisiveis.where((a) {
      return _camadasAtivas[a.tipo] ?? false;
    }).toList();

    return ativosFiltrados.map((ativo) {
      final isSelected = _ativoSelecionado?.id == ativo.id;
      final cor = ativo.tipo.cor;

      final marker = Marker(
        point: LatLng(ativo.latitude, ativo.longitude),
        width: isSelected ? 42 : 32,
        height: isSelected ? 42 : 32,
        child: GestureDetector(
          onTap: () => _selecionarAtivo(ativo),
          child: _buildIconeMarcador(ativo, isSelected, cor),
        ),
      );

      _markerAtivoMap[marker] = ativo;
      return marker;
    }).toList();
  }

  Widget _buildIconeMarcador(AtivoBdgd ativo, bool isSelected, Color cor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.surfaceCardLight : AppColors.surfaceCard,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.primaryLime : cor,
          width: isSelected ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isSelected ? AppColors.primaryLime : cor).withValues(
              alpha: isSelected ? 0.6 : 0.3,
            ),
            blurRadius: isSelected ? 10 : 5,
            spreadRadius: isSelected ? 2 : 0,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          ativo.tipo.icone,
          color: isSelected ? AppColors.primaryLime : cor,
          size: isSelected ? 22 : 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marcadores = _gerarMarcadores();

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(-14.2350, -51.9253),
              initialZoom: _currentZoom,
              minZoom: 2.0,
              maxZoom: 18.0,
              onMapReady: _aoMapaPronto,
              onPositionChanged: (camera, hasGesture) {
                // Só recarrega quando o usuário navega de fato (pan/zoom).
                // Movimentos programáticos (fly-to, seleção de marcador)
                // não devem descartar os ativos já carregados.
                if (!hasGesture || !_podeCarregarAtivos) {
                  return;
                }
                _agendarCarregamento();
              },
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  LatLng(-89.9, -180.0),
                  LatLng(89.9, 180.0),
                ),
              ),
              onTap: (tapPosition, point) {
                if (!isDrawing) {
                  return;
                }

                setState(() {
                  polygonPoints.add(point);
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.frontend_tecsys',
              ),
              PolygonLayer(
                polygons: polygonPoints.length >= 3
                    ? <Polygon<Object>>[
                        Polygon<Object>(
                          points: polygonPoints,
                          color: AppColors.navBarBackground.withAlpha(100),
                          borderColor: AppColors.navBarBackground,
                          borderStrokeWidth: 2.5,
                          pattern: StrokePattern.dashed(segments: [10, 5]),
                        ),
                      ]
                    : <Polygon<Object>>[],
              ),
              MarkerLayer(
                markers: polygonPoints.map((point) {
                  return Marker(
                    point: point,
                    width: 14.0,
                    height: 14.0,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.navBarBackground,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.navBarBackground,
                          width: 2.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              MarkerLayer(markers: marcadores),
            ],
          ),
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: MapSearchBar(
                        controller: _buscaController,
                        onChanged: _aplicarBusca,
                      ),
                    ),
                    // O botão de camadas só existe depois que a região
                    // (distribuidora + cidade) foi confirmada.
                    if (_podeExibirBotaoCamadas)
                      LayerFilterButton(
                        onPressed: _abrirPainelCamadas,
                        activeLayersCount: _totalCamadasAtivas,
                      ),
                  ],
                ),
                Row(
                  spacing: 10,
                  children: [
                    FilterChipWidget(
                      label: _distribuidoraSelecionada ?? 'Distribuidora',
                      isSelected: _distribuidoraSelecionada != null,
                      onTap: () => _abrirSelecaoDistribuidora(),
                    ),
                    FilterChipWidget(
                      label: _regiaoConfirmada
                          ? _rotuloRegiao
                          : 'Cidade',
                      isSelected: _regiaoConfirmada,
                      onTap: _trocarCidade,
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: MapNavigationControls(
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut,
                    onLocationPressed: _onLocationPressed,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 15,
            right: 15,
            bottom: 10,
            child: _areaDesenhada
                ? _buildBotoesArea()
                : ElevatedButton(
                    onPressed: _iniciarEstudo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLime,
                      foregroundColor: AppColors.textDark,
                      elevation: 6,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      shadowColor: AppColors.primaryLime.withValues(alpha: 0.4),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 8,
                      children: [
                        Icon(
                          Icons.add,
                          color: AppColors.textDark,
                          size: 16,
                          weight: 10.0,
                        ),
                        Text(
                          'Iniciar estudo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (_carregandoRegiao)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primaryLime),
              ),
            ),
          if (_carregando && _todosAtivos.isEmpty && !_carregandoRegiao)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primaryLime),
              ),
            ),
          if (_erro != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 100,
              child: Card(
                color: AppColors.surfaceCard,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _erro!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textWhite),
                  ),
                ),
              ),
            ),
          // Aviso guiando o fluxo: distribuidora -> cidade -> camadas.
          if (!_regiaoConfirmada && _erro == null && !_carregandoRegiao)
            Positioned(
              left: 24,
              right: 24,
              bottom: 100,
              child: Card(
                color: AppColors.surfaceCard,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Selecione a distribuidora e depois a cidade. '
                    'O painel de camadas só aparece depois dessa seleção, '
                    'para não carregar os ativos da rede inteira.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textWhite),
                  ),
                ),
              ),
            ),
          if (_regiaoConfirmada &&
              _erro == null &&
              !_carregando &&
              _todosAtivos.isEmpty &&
              _nenhumaCamadaAtiva)
            Positioned(
              left: 24,
              right: 24,
              bottom: 100,
              child: Card(
                color: AppColors.surfaceCard,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Nenhuma camada ativa. Toque no ícone de camadas e marque '
                    'os tipos de ativo que deseja exibir no mapa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textWhite),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
