import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/models/layer_filter.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/asset_detail_sheet.dart';
import 'package:frontend_tecsys/widgets/layer_filter_modal.dart';
import 'package:frontend_tecsys/widgets/map_controls.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _fallbackCenter = LatLng(-23.4532, -46.4438);

  final MapController _mapController = MapController();
  final AtivosService _ativosService = AtivosService();
  final TextEditingController _buscaController = TextEditingController();

  List<DistribuidoraResumo> _distribuidoras = [];
  String? _distribuidoraSelecionada;
  String? _municipioSelecionado;
  String _textoBusca = '';
  double _currentZoom = 15.2;

  List<AtivoBdgd> _todosAtivos = [];
  Map<TipoAtivo, bool> _camadasAtivas =
      CatalogoCamadas.obterEstadoInicialPadrao();
  AtivoBdgd? _ativoSelecionado;
  bool _carregando = true;
  String? _erro;

  Timer? _debounceTimer;
  int _sequenciaRequisicao = 0;
  bool _mapaPronto = false;
  bool _distribuidorasProntas = false;
  bool _cargaInicialFeita = false;

  static const int _limiteAtivos = 3000;

  final Map<Marker, AtivoBdgd> _markerAtivoMap = {};

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
    _mapaPronto = true;
    _tentarCargaInicial();
  }

  void _tentarCargaInicial() {
    if (!_mapaPronto || !_distribuidorasProntas || _cargaInicialFeita) {
      return;
    }
    _cargaInicialFeita = true;
    DistribuidoraResumo? inicial;
    for (final item in _distribuidoras) {
      if (item.nome == _distribuidoraSelecionada) {
        inicial = item;
        break;
      }
    }
    if (inicial == null) return;
    _mapController.move(LatLng(inicial.latitude, inicial.longitude), 12.5);
    _agendarCarregamento();
  }

  void _agendarCarregamento() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), _carregarDados);
  }

  Future<void> _carregarDados() async {
    if (!_mapaPronto || _distribuidoraSelecionada == null) return;

    final camadasApi = <String>{
      for (final entry in _camadasAtivas.entries)
        if (entry.value) entry.key.apiValue,
    };

    if (camadasApi.isEmpty) {
      setState(() {
        _todosAtivos = [];
        _carregando = false;
        _erro = null;
      });
      return;
    }

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
        limit: _limiteAtivos,
      );

      if (!mounted || sequencia != _sequenciaRequisicao) return;
      setState(() {
        _todosAtivos = resultado.ativos;
        _carregando = false;
      });
    } catch (error) {
      if (!mounted || sequencia != _sequenciaRequisicao) return;
      setState(() {
        _erro = 'Não foi possível carregar os ativos reais.';
        _carregando = false;
      });
    }
  }

  Future<void> _inicializar() async {
    try {
      final distribuidoras = await _ativosService.getDistribuidoras();
      if (!mounted || distribuidoras.isEmpty) return;
      setState(() {
        _distribuidoras = distribuidoras;
        _distribuidoraSelecionada = distribuidoras.first.nome;
        _distribuidorasProntas = true;
      });
      _tentarCargaInicial();
    } catch (error) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar as distribuidoras reais.';
          _carregando = false;
        });
      }
    }
  }

  int get _totalCamadasAtivas =>
      _camadasAtivas.values.where((ativa) => ativa).length;

  Future<void> _selecionarDistribuidora(String? distribuidora) async {
    if (distribuidora == null || distribuidora == _distribuidoraSelecionada) {
      return;
    }
    setState(() {
      _distribuidoraSelecionada = distribuidora;
      _todosAtivos = [];
      _ativoSelecionado = null;
      _municipioSelecionado = null;
      _textoBusca = '';
      _buscaController.clear();
    });
    final resumo = _distribuidoras.firstWhere(
      (item) => item.nome == distribuidora,
    );
    final centro = LatLng(resumo.latitude, resumo.longitude);
    _mapController.move(centro, 12.5);
    _agendarCarregamento();
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_mapController.camera.zoom + 1).clamp(3.0, 19.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_mapController.camera.zoom - 1).clamp(3.0, 19.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  void _centralizarRede() {
    final resumo = _distribuidoras.firstWhere(
      (item) => item.nome == _distribuidoraSelecionada,
    );
    final centro = LatLng(resumo.latitude, resumo.longitude);
    setState(() {
      _currentZoom = 15.2;
      _mapController.move(centro, _currentZoom);
    });
  }

  List<String> get _municipiosDisponiveis {
    final municipios =
        _todosAtivos
            .map((ativo) => ativo.municipio)
            .where((municipio) => municipio != 'Não informado')
            .toSet()
            .toList()
          ..sort();
    return municipios;
  }

  List<AtivoBdgd> get _ativosVisiveis {
    final termo = _textoBusca.trim().toLowerCase();
    return _todosAtivos.where((ativo) {
      final correspondeMunicipio =
          _municipioSelecionado == null ||
          ativo.municipio == _municipioSelecionado;
      if (!correspondeMunicipio) return false;
      if (termo.isEmpty) return true;
      return ativo.codId.toLowerCase().contains(termo) ||
          ativo.id.toLowerCase().contains(termo) ||
          ativo.municipio.toLowerCase().contains(termo) ||
          ativo.tipo.label.toLowerCase().contains(termo);
    }).toList();
  }

  void _aplicarBusca(String valor) {
    setState(() {
      _textoBusca = valor;
    });
  }

  void _abrirFiltroMunicipio() {
    final municipios = _municipiosDisponiveis;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Filtrar por cidade'),
                subtitle: Text(
                  'Selecione um município para filtrar os ativos no mapa.',
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      title: const Text('Todos os municípios'),
                      leading: Icon(
                        _municipioSelecionado == null
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: AppColors.primaryLime,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _municipioSelecionado = null);
                      },
                    ),
                    ...municipios.map(
                      (municipio) => ListTile(
                        title: Text(municipio),
                        leading: Icon(
                          municipio == _municipioSelecionado
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: AppColors.primaryLime,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _municipioSelecionado = municipio);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        child: _buildIconeMarcador(ativo, isSelected, cor),
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
          // 1. Mapa Interativo com OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _fallbackCenter,
              initialZoom: _currentZoom,
              minZoom: 4.0,
              maxZoom: 19.0,
              onMapReady: _aoMapaPronto,
              onPositionChanged: (camera, hasGesture) {
                _agendarCarregamento();
              },
              onTap: (tapPosition, latLng) {
                if (_ativoSelecionado != null) {
                  setState(() {
                    _ativoSelecionado = null;
                  });
                }
              },
            ),
            children: [
              // Camada de Tiles (OpenStreetMap com visual estilizado escuro)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tecsys.geomash',
              ),

              // Camada de Clustering de Marcadores da BDGD
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 50,
                  size: const Size(42, 42),
                  markers: marcadores,
                  showPolygon: false,
                  zoomToBoundsOnClick: true,
                  onMarkerTap: (marker) {
                    final ativo = _markerAtivoMap[marker];
                    if (ativo != null) {
                      _selecionarAtivo(ativo);
                    }
                  },
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryLime,
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryLime.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${markers.length}',
                          style: const TextStyle(
                            color: AppColors.primaryLime,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // 2. Barra Superior: Busca & Chips de Distribuidora e Região (Figma Tela 1)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra de Busca estilizada
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.search,
                        color: AppColors.textMuted,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _buscaController,
                          onChanged: _aplicarBusca,
                          style: const TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Buscar ativo ou município',
                            hintStyle: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.near_me_outlined,
                          color: AppColors.primaryLime,
                          size: 20,
                        ),
                        onPressed: _centralizarRede,
                        tooltip: 'Localizar',
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Chips de Filtro Rápido derivados dos ativos retornados pela API.
                Row(
                  children: [
                    _buildChipFiltro(
                      label: _distribuidoraSelecionada ?? 'Distribuidora',
                      destaque: true,
                      onTap: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => SafeArea(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.7,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const ListTile(
                                    title: Text('Selecionar distribuidora'),
                                    subtitle: Text(
                                      'Os ativos serão recarregados para a região escolhida.',
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  Flexible(
                                    child: ListView(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      children: _distribuidoras
                                          .map(
                                            (distribuidora) => ListTile(
                                              title: Text(distribuidora.nome),
                                              leading: Icon(
                                                distribuidora.nome ==
                                                        _distribuidoraSelecionada
                                                    ? Icons
                                                        .radio_button_checked
                                                    : Icons
                                                        .radio_button_unchecked,
                                                color: AppColors.primaryLime,
                                              ),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _selecionarDistribuidora(
                                                  distribuidora.nome,
                                                );
                                              },
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildChipFiltro(
                      label: _municipioSelecionado ?? 'Cidade / bairro',
                      onTap: _abrirFiltroMunicipio,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Controles Flutuantes à Direita (Camadas, Zoom, Localização)
          Positioned(
            right: 16,
            top: 130,
            child: MapControls(
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              onLocation: _centralizarRede,
              onAbrirCamadas: _abrirPainelCamadas,
              totalCamadasAtivas: _totalCamadasAtivas,
            ),
          ),

          // 4. Botão Inferior Flutuante: "+ Iniciar estudo" (Figma Tela 1)
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Avançar para seleção de área e criação de estudo (RF03 / RF04)',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: AppColors.primaryLime,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLime,
                foregroundColor: AppColors.textDark,
                elevation: 6,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                shadowColor: AppColors.primaryLime.withValues(alpha: 0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: AppColors.textDark, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Iniciar estudo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Indicador de Carregamento
          if (_carregando && _todosAtivos.isEmpty)
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
        ],
      ),
    );
  }

  Widget _buildChipFiltro({
    required String label,
    required VoidCallback onTap,
    bool destaque = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: destaque
                ? AppColors.primaryLime.withValues(alpha: 0.5)
                : AppColors.border,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (destaque) ...[
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLime,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: destaque ? AppColors.textWhite : AppColors.textMuted,
                fontSize: 12,
                fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              color: AppColors.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
