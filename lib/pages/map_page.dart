import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:frontend_tecsys/widgets/layer_filter_button.dart';
import 'package:frontend_tecsys/widgets/search_bar.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/models/layer_filter.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/layer_filter_modal.dart';
import 'package:frontend_tecsys/widgets/map_navigation.dart';
import 'package:frontend_tecsys/widgets/filter_chip.dart';

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
  String? _estadoSelecionado;
  String? _municipioSelecionado;
  double _currentZoom = 15.2;

  List<AtivoBdgd> _todosAtivos = [];
  Map<TipoAtivo, bool> _camadasAtivas =
      CatalogoCamadas.obterEstadoInicialPadrao();
  bool _carregando = true;

  Timer? _debounceTimer;
  int _sequenciaRequisicao = 0;
  bool _mapaPronto = false;
  bool _distribuidorasProntas = false;
  bool _cargaInicialFeita = false;

  static const int _limiteAtivos = 3000;

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
      });
      return;
    }

    final sequencia = ++_sequenciaRequisicao;
    final bounds = _mapController.camera.visibleBounds;
    final busca = _buscaController.text.trim();

    if (mounted) {
      setState(() {
        if (_todosAtivos.isEmpty) _carregando = true;
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
        estado: _estadoSelecionado,
        municipio: _municipioSelecionado,
        busca: busca,
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
      _estadoSelecionado = null;
      _todosAtivos = [];
      _municipioSelecionado = null;
      _buscaController.clear();
    });
    final resumo = _distribuidoras.firstWhere(
      (item) => item.nome == distribuidora,
    );
    final centro = LatLng(resumo.latitude, resumo.longitude);
    _mapController.move(centro, 12.5);
    _agendarCarregamento();
  }

  Future<void> _selecionarEstado(String? estado) async {
    if (estado == null || estado == _estadoSelecionado) return;

    setState(() {
      _estadoSelecionado = estado;
      _municipioSelecionado = null;
      _buscaController.clear();
    });
    _agendarCarregamento();
  }

  void _onBuscaAlterada(String valor) {
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

  List<String> get _estadosDisponiveis {
    final estados =
        _todosAtivos
            .map((ativo) {
              final municipio = ativo.municipio.trim();
              if (municipio.isEmpty || municipio == 'Não informado') {
                return null;
              }
              if (municipio.contains('-')) {
                return municipio.split('-').last.trim();
              }
              return municipio;
            })
            .whereType<String>()
            .where((estado) => estado.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return estados;
  }

  List<String> get _municipiosDisponiveis {
    final municipios =
        _todosAtivos
            .map((ativo) => ativo.municipio)
            .where((municipio) => municipio != 'Não informado')
            .where((municipio) {
              if (_estadoSelecionado == null) return true;
              if (!municipio.contains('-')) return true;
              final estado = municipio.split('-').last.trim();
              return estado == _estadoSelecionado;
            })
            .map((municipio) {
              if (municipio.contains('-')) {
                return municipio.split('-').first.trim();
              }
              return municipio.trim();
            })
            .where((municipio) => municipio.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return municipios;
  }

  void _abrirFiltroEstado() {
    final estados = _estadosDisponiveis;
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
                title: Text('Filtrar por estado'),
                subtitle: Text('Selecione o estado para refinar a busca regional.'),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      title: const Text('Todos os estados'),
                      leading: Icon(
                        _estadoSelecionado == null
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: AppColors.primaryLime,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _estadoSelecionado = null;
                          _municipioSelecionado = null;
                        });
                        _agendarCarregamento();
                      },
                    ),
                    ...estados.map(
                      (estado) => ListTile(
                        title: Text(estado),
                        leading: Icon(
                          estado == _estadoSelecionado
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: AppColors.primaryLime,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _selecionarEstado(estado);
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
                        _agendarCarregamento();
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
                          _agendarCarregamento();
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

  @override
  Widget build(BuildContext context) {
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
              onMapReady: _aoMapaPronto,
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
                    Expanded(
                      child: MapSearchBar(
                        controller: _buscaController,
                        onChanged: _onBuscaAlterada,
                      ),
                    ),
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
                      label: _estadoSelecionado ?? 'Estado',
                      onTap: _abrirFiltroEstado,
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
                final totalAtivos = _todosAtivos.length;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      totalAtivos > 0
                          ? 'Estudo iniciado com $totalAtivos ativos em ${_distribuidoraSelecionada ?? 'todos os ativos'}.'
                          : 'Estudo iniciado sem ativos no filtro atual.',
                      style: const TextStyle(
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
          // Erros do backend ficam ocultos para a tela final; a app mantém o mapa
          // limpo enquanto a integração real com a API estiver sendo conectada.
        ],
      ),
    );
  }
}
