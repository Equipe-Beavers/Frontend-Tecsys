import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:frontend_tecsys/widgets/layer_filter_button.dart';
import 'package:frontend_tecsys/widgets/search_bar.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/models/layer_filter.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/asset_detail_sheet.dart';
import 'package:frontend_tecsys/widgets/layer_filter_modal.dart';
import 'package:frontend_tecsys/widgets/map_navigation.dart';
import 'package:frontend_tecsys/widgets/filter_chip.dart';

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

  List<LatLng> polygonPoints = [];
  bool isDrawing = false;

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

  void _onLocationPressed() {
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
              initialCenter: LatLng(-14.2350, -51.9253),
              initialZoom: _currentZoom,
              minZoom: 2.0,
              maxZoom: 18.0,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  LatLng(-89.9, -180.0),
                  LatLng(89.9, 180.0),
                ),
              ),
              onTap: (tapPosition, point) {
                if (!isDrawing) return;
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
                    Expanded(child: MapSearchBar()),
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
                      label: _distribuidoraSelecionada ?? 'DIST.',
                      isSelected: true,
                      onTap: () {
                        SelectionBottomSheet.show<String>(
                          context: context,
                          title: "Selecionar distribuidora",
                          subtitle: "Os ativos serão recarregados para a região escolhida.",
                          items: _distribuidoras
                              .map(
                                (dist) => SelectionItem(
                                  title: dist.nome,
                                  value: dist.nome,
                                ),
                              )
                              .toList(),
                          selectedValue: _distribuidoraSelecionada,
                          onSelected: (distribuidoraNome) {
                            _selecionarDistribuidora(distribuidoraNome);
                          },
                        );
                      },
                    ),
                    FilterChipWidget(
                      label: _municipioSelecionado ?? 'Cidade / bairro',
                      onTap: _abrirFiltroMunicipio,
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
}
