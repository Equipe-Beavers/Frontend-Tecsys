import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:frontend_tecsys/widgets/layer_filter_button.dart';
import 'package:frontend_tecsys/widgets/search_bar.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/city_bairro_bottom_sheet.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/models/layer_filter.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/asset_detail_sheet.dart';
import 'package:frontend_tecsys/widgets/layer_filter_modal.dart';
import 'package:frontend_tecsys/widgets/map_navigation.dart';
import 'package:frontend_tecsys/widgets/filter_chip.dart';
import 'package:frontend_tecsys/pages/study_form.dart';
import 'package:frontend_tecsys/utils/map_utils.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolygonAnnotationManager? _polygonAnnotationManager;
  CircleAnnotationManager? _vertexAnnotationManager;

  final AtivosService _ativosService = AtivosService();
  final TextEditingController _buscaController = TextEditingController();

  List<DistribuidoraResumo> _distribuidoras = [];
  String? _distribuidoraSelecionada;
  String? _municipioSelecionado;
  double _currentZoom = 3.8;
  String _textoBusca = '';

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

  List<latlong2.LatLng> polygonPoints = [];
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
    _ativosService.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap controller) async {
    _mapboxMap = controller;
    controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    _pointAnnotationManager = await controller.annotations
        .createPointAnnotationManager();

    if (!kIsWeb) {
      _vertexAnnotationManager = await controller.annotations
          .createCircleAnnotationManager();
      _polygonAnnotationManager = await controller.annotations
          .createPolygonAnnotationManager();
    }

    await controller.setBounds(
      CameraBoundsOptions(minZoom: 3.0, maxZoom: 20.0),
    );

    controller.addInteraction(
      TapInteraction.onMap((context) {
        if (!isDrawing) return;
        final point = context.point;
        setState(() {
          polygonPoints.add(
            latlong2.LatLng(
              point.coordinates.lat.toDouble(),
              point.coordinates.lng.toDouble(),
            ),
          );
        });
        _atualizarPoligono();
      }),
    );

    _mapaPronto = true;
    _tentarCargaInicial();
  }

  Future<void> _atualizarAnnotations() async {
    if (_pointAnnotationManager == null) return;

    await _pointAnnotationManager!.deleteAll();

    final ativosFiltrados = _ativosVisiveis.where((a) {
      return _camadasAtivas[a.tipo] ?? false;
    }).toList();

    List<PointAnnotationOptions> optionsList = [];
    for (var ativo in ativosFiltrados) {
      optionsList.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(ativo.longitude, ativo.latitude),
          ),
          iconSize: _ativoSelecionado?.id == ativo.id ? 1.5 : 1.0,
        ),
      );
    }
    await _pointAnnotationManager!.createMulti(optionsList);
  }

  Future<void> _atualizarPoligono() async {
    if (kIsWeb) return;
    if (_polygonAnnotationManager == null || _vertexAnnotationManager == null) {
      return;
    }
    await _polygonAnnotationManager!.deleteAll();
    await _vertexAnnotationManager!.deleteAll();

    if (polygonPoints.length >= 3) {
      final positions = polygonPoints
          .map((p) => Position(p.longitude, p.latitude))
          .toList();
      if (positions.first != positions.last) {
        positions.add(positions.first);
      }

      await _polygonAnnotationManager!.create(
        PolygonAnnotationOptions(
          geometry: Polygon(coordinates: [positions]),
          fillColor: AppColors.navBarBackground.value,
          fillOpacity: 0.4,
        ),
      );
    }

    if (polygonPoints.isNotEmpty) {
      List<CircleAnnotationOptions> vertexOptions = [];
      for (var point in polygonPoints) {
        vertexOptions.add(
          CircleAnnotationOptions(
            geometry: Point(
              coordinates: Position(point.longitude, point.latitude),
            ),
            circleRadius: 6.0,
            circleColor: AppColors.navBarBackground.value,
            circleStrokeWidth: 2.0,
            circleStrokeColor: Colors.white.value,
          ),
        );
      }
      await _vertexAnnotationManager!.createMulti(vertexOptions);
    }
  }

  void _tentarCargaInicial() {
    if (!_mapaPronto ||
        !_distribuidorasProntas ||
        _cargaInicialFeita ||
        _distribuidoraSelecionada == null) {
      return;
    }

    _cargaInicialFeita = true;
    _agendarCarregamento();
  }

  void _agendarCarregamento() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), _carregarDados);
  }

  Future<void> _carregarDados() async {
    if (!_mapaPronto ||
        _distribuidoraSelecionada == null ||
        _mapboxMap == null) {
      return;
    }

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
      _atualizarAnnotations();
      return;
    }

    final sequencia = ++_sequenciaRequisicao;

    try {
      final cameraState = await _mapboxMap!.getCameraState();
      final bounds = await _mapboxMap!.coordinateBoundsForCamera(
        CameraOptions(
          center: cameraState.center,
          zoom: cameraState.zoom,
          bearing: cameraState.bearing,
          pitch: cameraState.pitch,
        ),
      );

      if (mounted) {
        setState(() {
          if (_todosAtivos.isEmpty) _carregando = true;
          _erro = null;
        });
      }

      final resultado = await _ativosService.getAtivos(
        minLatitude: bounds.southwest.coordinates.lat.toDouble(),
        maxLatitude: bounds.northeast.coordinates.lat.toDouble(),
        minLongitude: bounds.southwest.coordinates.lng.toDouble(),
        maxLongitude: bounds.northeast.coordinates.lng.toDouble(),
        distribuidora: _distribuidoraSelecionada,
        tipos: camadasApi,
        limit: _limiteAtivos,
      );

      if (!mounted || sequencia != _sequenciaRequisicao) {
        return;
      }

      setState(() {
        _todosAtivos = resultado.ativos;
        _carregando = false;
      });

      _atualizarAnnotations();
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

      if (!mounted || distribuidoras.isEmpty) {
        return;
      }

      setState(() {
        _distribuidoras = distribuidoras;
        _distribuidoraSelecionada = distribuidoras.first.nome;
        _distribuidorasProntas = true;
        _carregando = false;
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
      _todosAtivos = [];
      _ativoSelecionado = null;
      _municipioSelecionado = null;
      _textoBusca = '';
      _buscaController.clear();
      _carregando = true;
    });

    await _atualizarAnnotations();
    _agendarCarregamento();
  }

  Future<void> _iniciarEstudo() async {
    await SelectionBottomSheet.show<String>(
      context: context,
      title: 'Selecionar distribuidora',
      subtitle: 'Os ativos serão recarregados para a região escolhida.',
      stepLabel: 'PASSO 1 DE 4',
      searchHint: 'Buscar distribuidora',
      notFoundMessage: _distribuidoras.isEmpty
          ? 'Não foi possível carregar as distribuidoras.'
          : 'Não encontrada',
      items: _distribuidoras
          .map((dist) => SelectionItem(title: dist.nome, value: dist.nome))
          .toList(),
      selectedValue: _distribuidoraSelecionada,
      onSelected: (distribuidoraNome) async {
        if (distribuidoraNome == null) {
          await _abrirCidadeBairroDoEstudo();
          return;
        }

        await _selecionarDistribuidoraParaEstudo(distribuidoraNome);
      },
    );
  }

  Future<void> _selecionarDistribuidoraParaEstudo(String distribuidora) async {
    if (!mounted) return;

    _debounceTimer?.cancel();

    setState(() {
      _distribuidoraSelecionada = distribuidora;
      _todosAtivos = [];
      _ativoSelecionado = null;
      _municipioSelecionado = null;
      _textoBusca = '';
      _buscaController.clear();
      _carregando = true;
    });

    try {
      await _carregarDados();
      if (!mounted) return;
      await _abrirCidadeBairroDoEstudo();
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  Future<void> _abrirCidadeBairroDoEstudo() async {
    final cidades = _municipiosDisponiveis;
    final bairrosPorCidade = <String, List<String>>{};

    for (final cidade in cidades) {
      final bairros =
          _todosAtivos
              .where((ativo) => ativo.municipio == cidade)
              .map((ativo) => ativo.bairro.trim())
              .where((bairro) => bairro.isNotEmpty && bairro != 'Não informado')
              .toSet()
              .toList()
            ..sort();

      bairrosPorCidade[cidade] = bairros;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CidadeBairroBottomSheet(
          cidades: cidades,
          bairrosPorCidade: bairrosPorCidade,
          cidadeSelecionada: _municipioSelecionado,
          stepLabel: 'PASSO 2 DE 4',
          breadcrumb: _distribuidoraSelecionada != null
              ? '$_distribuidoraSelecionada · Selecione o município'
              : null,
          notFoundMessage: cidades.isEmpty
              ? 'Nenhuma cidade encontrada para a distribuidora selecionada.'
              : 'Não encontrada',
          onProsseguir: (cidade, bairro) {
            setState(() {
              _municipioSelecionado = cidade;
            });
          },
        );
      },
    );
  }

  Future<void> _zoomIn() async {
    if (_mapboxMap == null) return;
    final cameraState = await _mapboxMap!.getCameraState();
    _currentZoom = (cameraState.zoom + 1).clamp(3.8, 18.0);
    _mapboxMap!.flyTo(
      CameraOptions(zoom: _currentZoom),
      MapAnimationOptions(duration: 300),
    );
  }

  Future<void> _zoomOut() async {
    if (_mapboxMap == null) return;
    final cameraState = await _mapboxMap!.getCameraState();
    _currentZoom = (cameraState.zoom - 1).clamp(3.8, 18.0);
    _mapboxMap!.flyTo(
      CameraOptions(zoom: _currentZoom),
      MapAnimationOptions(duration: 300),
    );
  }

  void _onLocationPressed() {}

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
    _atualizarAnnotations();
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
        _atualizarAnnotations();

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

    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(ativo.longitude, ativo.latitude)),
        zoom: 16.0,
      ),
      MapAnimationOptions(duration: 400),
    );

    _atualizarAnnotations();

    AssetDetailSheet.exibir(
      context,
      ativo: ativo,
      onFechar: () {
        if (mounted) {
          setState(() {
            _ativoSelecionado = null;
          });
          _atualizarAnnotations();
        }
      },
    );
  }

  bool get _areaDesenhada => polygonPoints.length >= 3;

  void _cancelarArea() {
    setState(() => polygonPoints = []);
    _atualizarPoligono();
  }

  Future<void> _prosseguirArea() async {
    final estudoCriado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NovoEstudoPage(
          distribuidora: _distribuidoraSelecionada ?? '',
          municipio: _municipioSelecionado,
          areaKm2: calculatePolygonAreaKm2(polygonPoints),
          pontosArea: List.unmodifiable(polygonPoints),
        ),
      ),
    );

    if (estudoCriado == true && mounted) {
      setState(() => polygonPoints = []);
      _atualizarPoligono();
    }
  }

  Widget _buildBotoesArea() {
    return Row(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('mapWidget'),
            styleUri: MapboxStyles.STANDARD,
            viewport: CameraViewportState(
              center: Point(coordinates: Position(-51.9253, -14.2350)),
              zoom: _currentZoom,
            ),
            onMapCreated: _onMapCreated,
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
                          title: 'Selecionar distribuidora',
                          subtitle: 'Os ativos serão recarregados para a região escolhida.',
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
          if (_carregando && _todosAtivos.isEmpty)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primaryLime,
                ),
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