import 'dart:async';

import '../controllers/study_area_count_controller.dart';

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:frontend_tecsys/widgets/auth/auth_scope.dart';
import 'package:frontend_tecsys/widgets/layer_filter_button.dart';
import 'package:frontend_tecsys/widgets/search_bar.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/city_bairro_bottom_sheet.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:frontend_tecsys/models/antena_anatel.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/models/edificacao.dart';
import 'package:frontend_tecsys/models/layer_filter.dart';
import 'package:frontend_tecsys/models/vegetacao_config.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/services/camadas_externas_service.dart';
import 'package:frontend_tecsys/services/edificacoes_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/asset_detail_sheet.dart';
import 'package:frontend_tecsys/widgets/layer_filter_modal.dart';
import 'package:frontend_tecsys/widgets/map_navigation.dart';
import 'package:frontend_tecsys/widgets/filter_chip.dart';
import 'package:frontend_tecsys/pages/study_form.dart';
import 'package:frontend_tecsys/utils/map_utils.dart';
import 'package:frontend_tecsys/widgets/study_area_step.dart';
import 'package:frontend_tecsys/widgets/study_database_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/study_import_bottom_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, this.ativosService});

  final AtivosService? ativosService;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _ativoAnnotationManager;
  PolygonAnnotationManager? _polygonAnnotationManager;
  CircleAnnotationManager? _vertexAnnotationManager;
  CircleAnnotationManager? _antenaAnnotationManager;
  Cancelable? _ativoTapEvents;
  Cancelable? _antenaTapEvents;
  final Map<String, AtivoBdgd> _ativosPorAnnotationId = {};
  final Map<String, AntenaAnatel> _antenasPorAnnotationId = {};

  late final AtivosService _ativosService;
  late final StudyAreaCountController _contagemArea;
  final EdificacoesService _edificacoesService = EdificacoesService();
  final CamadasExternasService _camadasExternasService =
      CamadasExternasService();
  final TextEditingController _buscaController = TextEditingController();

  List<DistribuidoraResumo> _distribuidoras = [];
  List<MunicipioResumo> _municipios = [];
  String? _distribuidoraSelecionada;
  String? _municipioSelecionado;
  String? _bairroSelecionado;
  String? _estadoSelecionado;
  double _currentZoom = 3.8;
  String _textoBusca = '';

  List<AtivoBdgd> _todosAtivos = [];
  List<AtivoBdgd>? _ativosImportados;
  List<AntenaAnatel> _antenas = [];
  VegetacaoConfig? _vegetacaoConfig;
  bool _vegetacaoAtiva = false;
  bool _relevoAtivo = true;
  bool _antenasAtivas = false;
  bool _legendaExpandida = false;
  Map<TipoAtivo, bool> _camadasAtivas =
      CatalogoCamadas.obterEstadoInicialPadrao();
  AtivoBdgd? _ativoSelecionado;
  bool _carregando = true;
  String? _erro;
  String? _erroMapa;
  String? _erroMunicipios;
  final ValueNotifier<bool> _carregandoMunicipios = ValueNotifier(false);
  bool _iniciandoEstudo = false;

  Timer? _debounceTimer;
  int _sequenciaRequisicao = 0;
  String? _consultaDadosEmAndamento;
  String? _ultimaConsultaDados;
  int _sequenciaMunicipios = 0;
  bool _mapaPronto = false;
  bool _distribuidorasProntas = false;
  bool _carregandoDistribuidoras = false;
  String? _erroDistribuidoras;
  bool _cargaInicialFeita = false;

  bool _edificacoesAtivas = false;
  List<Edificacao> _edificacoes = [];
  bool _carregandoEdificacoes = false;
  String? _avisoEdificacoes;
  String? _avisoAtivos;
  int _sequenciaEdificacoes = 0;
  String? _consultaEdificacoesEmAndamento;
  String? _ultimaConsultaEdificacoes;

  static const int _limiteAtivos = 3000;
  static const double _ladoMaximoGrausAtivos = 0.2;
  static const String _terrainSourceId = 'study-terrain-dem';
  static const String _vegetacaoSourceId = 'study-vegetation-source';
  static const String _vegetacaoLayerId = 'study-vegetation-layer';
  static const String _edificacoesSourceId = 'study-buildings';
  static const String _edificacoesFillLayerId = 'study-buildings-fill';
  static const String _edificacoesLabelLayerId = 'study-buildings-label';
  // Zoom a partir do qual altura e material aparecem escritos no edifício.
  static const double _zoomRotulosEdificacoes = 17;

  List<latlong2.LatLng> polygonPoints = [];
  List<double?> _relevoPontos = [];
  List<Future<void>> _consultasRelevo = [];
  int _polygonRevision = 0;
  final Completer<void> _terrainReady = Completer<void>();
  String? _erroRelevo;
  bool isDrawing = false;

  @override
  void initState() {
    super.initState();
    _ativosService = widget.ativosService ?? AtivosService();
    _contagemArea = StudyAreaCountController(_ativosService);
    _inicializar();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _buscaController.dispose();
    _ativoTapEvents?.cancel();
    _antenaTapEvents?.cancel();
    _carregandoMunicipios.dispose();
    _contagemArea.dispose();
    if (widget.ativosService == null) _ativosService.dispose();
    _camadasExternasService.dispose();
    _edificacoesService.dispose();
    super.dispose();
  }

  String _montarUrlWmsVegetacao(VegetacaoConfig config) {
    final base = config.baseUrl.endsWith('?')
        ? config.baseUrl
        : '${config.baseUrl}${config.baseUrl.contains('?') ? '&' : '?'}';

    return '${base}SERVICE=WMS'
        '&REQUEST=GetMap'
        '&VERSION=1.1.1'
        '&LAYERS=${Uri.encodeQueryComponent(config.layer)}'
        '&STYLES='
        '&FORMAT=${Uri.encodeQueryComponent(config.format)}'
        '&TRANSPARENT=TRUE'
        '&SRS=EPSG:3857'
        '&BBOX={bbox-epsg-3857}'
        '&WIDTH=256'
        '&HEIGHT=256';
  }

  Future<void> _configurarCamadaVegetacao() async {
    final map = _mapboxMap;
    final config = _vegetacaoConfig;

    if (map == null || config == null) return;

    try {
      if (!await map.styleSourceExists(_vegetacaoSourceId)) {
        await map.addStyleSource(
          _vegetacaoSourceId,
          jsonEncode({
            'type': 'raster',
            'tiles': [_montarUrlWmsVegetacao(config)],
            'tileSize': 256,
            'attribution': config.attribution,
          }),
        );
      }

      if (!await map.styleLayerExists(_vegetacaoLayerId)) {
        await map.addLayer(
          RasterLayer(
            id: _vegetacaoLayerId,
            sourceId: _vegetacaoSourceId,
            slot: 'top',
            rasterOpacity: 0.65,
            rasterFadeDuration: 0,
            visibility: _vegetacaoAtiva ? Visibility.VISIBLE : Visibility.NONE,
          ),
        );
      }

      await _atualizarVisibilidadeVegetacao();
    } catch (error, stackTrace) {
      debugPrint('Falha ao configurar vegetação: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _atualizarVisibilidadeVegetacao() async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      if (!await map.styleLayerExists(_vegetacaoLayerId)) return;

      await map.setStyleLayerProperty(
        _vegetacaoLayerId,
        'visibility',
        _vegetacaoAtiva ? 'visible' : 'none',
      );
    } catch (error) {
      debugPrint('Falha ao alterar visibilidade da vegetação: $error');
    }
  }

  void _onMapCreated(MapboxMap controller) async {
    _mapboxMap = controller;
    controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    if (!kIsWeb) {
      _ativoAnnotationManager = await controller.annotations
          .createCircleAnnotationManager();
      _ativoTapEvents = _ativoAnnotationManager!.tapEvents(
        onTap: (annotation) {
          final ativo = _ativosPorAnnotationId[annotation.id];
          if (ativo != null) _selecionarAtivo(ativo);
        },
      );
      _vertexAnnotationManager = await controller.annotations
          .createCircleAnnotationManager();
      _polygonAnnotationManager = await controller.annotations
          .createPolygonAnnotationManager();
      _antenaAnnotationManager = await controller.annotations
          .createCircleAnnotationManager();
      _antenaTapEvents = _antenaAnnotationManager!.tapEvents(
        onTap: (annotation) {
          final antena = _antenasPorAnnotationId[annotation.id];
          if (antena != null) _abrirDetalhesAntena(antena);
        },
      );
    }

    await controller.setBounds(
      CameraBoundsOptions(minZoom: 3.0, maxZoom: 20.0),
    );

    controller.addInteraction(
      TapInteraction.onMap((context) {
        unawaited(_tratarToqueMapa(context));
      }),
    );

    _mapaPronto = true;
    _tentarCargaInicial();
  }

  void _onStyleLoaded(StyleLoadedEventData _) {
    unawaited(
      Future.wait([
        _configurarRelevo(),
        _configurarCamadaEdificacoes().catchError(
          (Object error) =>
              debugPrint('Falha ao configurar edificações: $error'),
        ),
        _configurarCamadaVegetacao(),
      ]).whenComplete(() {
        if (!_terrainReady.isCompleted) {
          _terrainReady.complete();
        }
      }),
    );
  }

  Future<void> _configurarRelevo() async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      if (!await map.styleSourceExists(_terrainSourceId)) {
        await map.addStyleSource(
          _terrainSourceId,
          jsonEncode({
            'type': 'raster-dem',
            'url': 'mapbox://mapbox.mapbox-terrain-dem-v1',
            'tileSize': 514,
          }),
        );
      }
      await _atualizarVisibilidadeRelevo();
    } catch (error, stackTrace) {
      debugPrint('Falha ao configurar o relevo do Mapbox: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _erroRelevo =
              'Não foi possível carregar a fonte de relevo do Mapbox.';
        });
      }
    }
  }

  Future<void> _atualizarVisibilidadeRelevo() async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      if (_relevoAtivo) {
        await map.setStyleTerrain(
          jsonEncode({'source': _terrainSourceId, 'exaggeration': 1.0}),
        );
      } else {
        await map.removeStyleTerrain();
      }
    } catch (error) {
      debugPrint('Falha ao alternar relevo: $error');
    }
  }

  Future<void> _configurarCamadaEdificacoes() async {
    final map = _mapboxMap;
    if (map == null) return;

    if (!await map.styleSourceExists(_edificacoesSourceId)) {
      await map.addSource(
        GeoJsonSource(
          id: _edificacoesSourceId,
          data: _geoJsonEdificacoes(),
          dynamicData: true,
        ),
      );
    }
    if (!await map.styleLayerExists(_edificacoesFillLayerId)) {
      await map.addLayer(
        FillLayer(
          id: _edificacoesFillLayerId,
          sourceId: _edificacoesSourceId,
          slot: 'top',
          fillColorExpression: const ['get', 'color'],
          fillOpacity: 0.45,
          fillOutlineColor: AppColors.textDark.toARGB32(),
        ),
      );
    }
    if (!await map.styleLayerExists(_edificacoesLabelLayerId)) {
      await map.addLayer(
        SymbolLayer(
          id: _edificacoesLabelLayerId,
          sourceId: _edificacoesSourceId,
          slot: 'top',
          minZoom: _zoomRotulosEdificacoes,
          textFieldExpression: const ['get', 'label'],
          textSize: 10,
          textColor: AppColors.textDark.toARGB32(),
          textAllowOverlap: false,
        ),
      );
    }
  }

  String _geoJsonEdificacoes() {
    final features = <Map<String, Object?>>[];
    for (final edificacao in _edificacoes) {
      final cor =
          '#${(edificacao.cor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      for (final aneis in edificacao.poligonos) {
        if (aneis.isEmpty || aneis.first.length < 3) continue;
        final coordinates = <List<List<double>>>[];
        for (final anel in aneis) {
          if (anel.length < 3) continue;
          final pontos = anel
              .map((ponto) => [ponto.longitude, ponto.latitude])
              .toList();
          if (pontos.first[0] != pontos.last[0] ||
              pontos.first[1] != pontos.last[1]) {
            pontos.add(List<double>.from(pontos.first));
          }
          coordinates.add(pontos);
        }
        if (coordinates.isEmpty) continue;
        features.add({
          'type': 'Feature',
          'properties': {
            'edificacaoId': edificacao.id,
            'color': cor,
            'label':
                '${edificacao.alturaFormatada}\n${edificacao.nomeMaterial}',
          },
          'geometry': {'type': 'Polygon', 'coordinates': coordinates},
        });
      }
    }
    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  Future<void> _atualizarEdificacoesNoMapa() async {
    final map = _mapboxMap;
    if (map == null || !await map.styleSourceExists(_edificacoesSourceId)) {
      return;
    }
    final source = await map.getSource(_edificacoesSourceId);
    if (source is GeoJsonSource) {
      await source.updateGeoJSON(_geoJsonEdificacoes());
    }
  }

  Future<void> _tratarToqueMapa(MapContentGestureContext context) async {
    if (isDrawing) {
      _adicionarPontoDesenho(context.point);
      return;
    }

    final map = _mapboxMap;
    if (map == null || !_edificacoesAtivas || _edificacoes.isEmpty) return;
    final features = await map.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(context.touchPosition),
      RenderedQueryOptions(
        layerIds: const [_edificacoesFillLayerId],
        filter: null,
      ),
    );
    if (features.isEmpty) return;

    final feature = features.first?.queriedFeature.feature;
    final properties = feature?['properties'];
    if (properties is! Map) return;
    final id = properties['edificacaoId']?.toString();
    if (id == null) return;
    for (final edificacao in _edificacoes) {
      if (edificacao.id == id) {
        _exibirEdificacao(edificacao);
        return;
      }
    }
  }

  Future<void> _sincronizarZoom() async {
    final map = _mapboxMap;
    if (map == null) return;
    _currentZoom = (await map.getCameraState()).zoom;
  }

  void _adicionarPontoDesenho(Point point) {
    final map = _mapboxMap;
    if (map == null) return;

    late final int indice;
    late final int revisao;
    setState(() {
      polygonPoints.add(
        latlong2.LatLng(
          point.coordinates.lat.toDouble(),
          point.coordinates.lng.toDouble(),
        ),
      );
      _relevoPontos.add(null);
      indice = _relevoPontos.length - 1;
      revisao = _polygonRevision;
    });
    _consultarAtivosDaArea();
    _atualizarPoligono();
    final consulta = _consultarRelevoDoPonto(map, point, indice, revisao);
    _consultasRelevo.add(consulta);
    unawaited(consulta);
  }

  Future<void> _consultarRelevoDoPonto(
    MapboxMap map,
    Point point,
    int indice,
    int revisao,
  ) async {
    try {
      await _terrainReady.future;
      final elevation = await map.getElevation(point);
      if (!mounted ||
          revisao != _polygonRevision ||
          indice >= _relevoPontos.length) {
        return;
      }

      setState(() {
        _relevoPontos[indice] = elevation;
      });
    } catch (error, stackTrace) {
      if (!mounted ||
          revisao != _polygonRevision ||
          indice >= _relevoPontos.length) {
        return;
      }
      debugPrint('Falha ao consultar o relevo de um ponto: $error');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        _relevoPontos[indice] = null;
        _erroRelevo = 'Falha ao consultar o relevo dos pontos desenhados.';
      });
    }
  }

  void _limparPontosDesenho() {
    _contagemArea.updateArea(const []);
    polygonPoints = [];
    _relevoPontos = [];
    _consultasRelevo = [];
    _polygonRevision++;
    _erroRelevo = null;
  }

  void _refazerDesenhoArea() {
    setState(() {
      _limparPontosDesenho();
    });
    _atualizarPoligono();
  }

  void _consultarAtivosDaArea() {
    _contagemArea.updateArea(
      polygonPoints,
      distributor: _distribuidoraSelecionada,
      ativosImportados: _ativosImportados,
    );
  }

  String get _locationLabel => [
    _distribuidoraSelecionada,
    _estadoSelecionado,
    _municipioSelecionado,
    _bairroSelecionado,
  ].where((value) => value != null && value.trim().isNotEmpty).join(' · ');

  Future<void> _atualizarAnnotations() async {
    final ativosFiltrados = _ativosVisiveis.where((a) {
      return _camadasAtivas[a.tipo] ?? false;
    }).toList();

    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _erroMapa = ativosFiltrados.isEmpty
              ? null
              : 'Ativos carregados, mas a versão web do Mapbox não suporta '
                    'a criação de marcadores usada pelo app.';
        });
      }
      return;
    }
    final manager = _ativoAnnotationManager;
    if (manager == null) return;

    final optionsList = ativosFiltrados
        .map(
          (ativo) => CircleAnnotationOptions(
            geometry: Point(
              coordinates: Position(ativo.longitude, ativo.latitude),
            ),
            circleRadius: _ativoSelecionado?.id == ativo.id ? 11 : 8,
            circleColor: ativo.tipo.cor.toARGB32(),
            circleStrokeWidth: 1.5,
            circleStrokeColor: Colors.white.toARGB32(),
          ),
        )
        .toList();

    try {
      await manager.deleteAll();
      final annotations = await manager.createMulti(optionsList);
      _ativosPorAnnotationId.clear();
      for (var index = 0; index < annotations.length; index++) {
        final annotation = annotations[index];
        if (annotation != null) {
          _ativosPorAnnotationId[annotation.id] = ativosFiltrados[index];
        }
      }
      if (mounted && _erroMapa != null) {
        setState(() {
          _erroMapa = null;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Falha ao renderizar ativos no mapa: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _erroMapa = 'Falha ao renderizar ativos no mapa: $error';
        });
      }
    }

    await _atualizarAntenasNoMapa();
  }

  Future<void> _atualizarAntenasNoMapa() async {
    if (kIsWeb) return;
    final manager = _antenaAnnotationManager;
    if (manager == null) return;

    try {
      await manager.deleteAll();
      _antenasPorAnnotationId.clear();

      if (!_antenasAtivas || _antenas.isEmpty) return;

      final optionsList = _antenas
          .map(
            (antena) => CircleAnnotationOptions(
              geometry: Point(
                coordinates: Position(antena.longitude, antena.latitude),
              ),
              circleRadius: 7.0,
              circleColor: AppColors.surfaceCard.toARGB32(),
              circleStrokeWidth: 2.5,
              circleStrokeColor: AppColors.secondaryTeal.toARGB32(),
            ),
          )
          .toList();

      final annotations = await manager.createMulti(optionsList);
      for (var index = 0; index < annotations.length; index++) {
        final annotation = annotations[index];
        if (annotation != null) {
          _antenasPorAnnotationId[annotation.id] = _antenas[index];
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Falha ao renderizar antenas no mapa: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
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
          fillColor: AppColors.navBarBackground.toARGB32(),
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
            circleColor: AppColors.navBarBackground.toARGB32(),
            circleStrokeWidth: 2.0,
            circleStrokeColor: Colors.white.toARGB32(),
          ),
        );
      }
      await _vertexAnnotationManager!.createMulti(vertexOptions);
    }
  }

  void _tentarCargaInicial() {
    if (!_mapaPronto || !_distribuidorasProntas || _cargaInicialFeita) {
      return;
    }

    _cargaInicialFeita = true;
    _agendarCarregamento();
  }

  void _agendarCarregamento() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _carregarDados();
      _carregarEdificacoes();
    });
  }

  Future<void> _carregarEdificacoes() async {
    final map = _mapboxMap;
    if (!_mapaPronto || map == null) return;

    if (!_edificacoesAtivas) {
      _sequenciaEdificacoes++;
      _consultaEdificacoesEmAndamento = null;
      _ultimaConsultaEdificacoes = null;
      setState(() {
        _edificacoes = [];
        _carregandoEdificacoes = false;
        _avisoEdificacoes = null;
      });
      await _atualizarEdificacoesNoMapa();
      return;
    }

    final cameraState = await map.getCameraState();
    final bounds = await map.coordinateBoundsForCamera(
      CameraOptions(
        center: cameraState.center,
        zoom: cameraState.zoom,
        bearing: cameraState.bearing,
        pitch: cameraState.pitch,
      ),
    );
    final north = bounds.northeast.coordinates.lat.toDouble();
    final south = bounds.southwest.coordinates.lat.toDouble();
    final east = bounds.northeast.coordinates.lng.toDouble();
    final west = bounds.southwest.coordinates.lng.toDouble();

    if (north - south > EdificacoesService.ladoMaximoGraus ||
        east - west > EdificacoesService.ladoMaximoGraus) {
      _sequenciaEdificacoes++;
      _consultaEdificacoesEmAndamento = null;
      _ultimaConsultaEdificacoes = null;
      setState(() {
        _edificacoes = [];
        _carregandoEdificacoes = false;
        _avisoEdificacoes = 'Aproxime o mapa para ver os edifícios';
      });
      await _atualizarEdificacoesNoMapa();
      return;
    }

    final consulta = jsonEncode([
      south.toStringAsFixed(5),
      north.toStringAsFixed(5),
      west.toStringAsFixed(5),
      east.toStringAsFixed(5),
    ]);

    if (consulta == _consultaEdificacoesEmAndamento) return;

    final sequencia = ++_sequenciaEdificacoes;
    if (consulta == _ultimaConsultaEdificacoes) {
      _consultaEdificacoesEmAndamento = null;
      setState(() => _carregandoEdificacoes = false);
      return;
    }

    _consultaEdificacoesEmAndamento = consulta;
    setState(() {
      _carregandoEdificacoes = true;
      _avisoEdificacoes = null;
    });

    try {
      final edificacoes = await _edificacoesService.getEdificacoes(
        minLatitude: south,
        maxLatitude: north,
        minLongitude: west,
        maxLongitude: east,
      );

      if (!mounted || sequencia != _sequenciaEdificacoes) return;

      _consultaEdificacoesEmAndamento = null;
      _ultimaConsultaEdificacoes = consulta;
      setState(() {
        _edificacoes = edificacoes;
        _carregandoEdificacoes = false;
      });
      await _atualizarEdificacoesNoMapa();
    } catch (error) {
      if (!mounted || sequencia != _sequenciaEdificacoes) return;

      _consultaEdificacoesEmAndamento = null;
      setState(() {
        _carregandoEdificacoes = false;
        _avisoEdificacoes = 'Não foi possível carregar os edifícios.';
      });
    }
  }

  Future<void> _carregarDados() async {
    if (!_mapaPronto || _mapboxMap == null) {
      return;
    }

    final camadasApi = <String>{
      for (final entry in _camadasAtivas.entries)
        if (entry.value) entry.key.apiValue,
    };
    final deveCarregarAtivos = camadasApi.isNotEmpty;
    final deveCarregarAntenas = _antenasAtivas;

    if (!deveCarregarAtivos && !deveCarregarAntenas) {
      if (!mounted) return;
      _sequenciaRequisicao++;
      _consultaDadosEmAndamento = null;
      _ultimaConsultaDados = null;
      setState(() {
        _todosAtivos = [];
        _antenas = [];
        _carregando = false;
        _erro = null;
        _avisoAtivos = null;
      });
      _atualizarAnnotations();
      return;
    }

    int? sequencia;
    String? consulta;

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
      final minLatitude = bounds.southwest.coordinates.lat.toDouble();
      final maxLatitude = bounds.northeast.coordinates.lat.toDouble();
      final minLongitude = bounds.southwest.coordinates.lng.toDouble();
      final maxLongitude = bounds.northeast.coordinates.lng.toDouble();

      final areaMuitoAmpla =
          (maxLatitude - minLatitude) > _ladoMaximoGrausAtivos ||
          (maxLongitude - minLongitude) > _ladoMaximoGrausAtivos;
      if (areaMuitoAmpla) {
        if (!mounted) return;
        _sequenciaRequisicao++;
        _consultaDadosEmAndamento = null;
        _ultimaConsultaDados = null;
        setState(() {
          _todosAtivos = [];
          _antenas = [];
          _carregando = false;
          _erro = null;
          _avisoAtivos = 'Aproxime o mapa para carregar os ativos.';
        });
        _atualizarAnnotations();
        return;
      }

      final tiposOrdenados = camadasApi.toList()..sort();
      consulta = jsonEncode([
        minLatitude.toStringAsFixed(5),
        maxLatitude.toStringAsFixed(5),
        minLongitude.toStringAsFixed(5),
        maxLongitude.toStringAsFixed(5),
        _distribuidoraSelecionada,
        _ativosImportados != null,
        tiposOrdenados,
        deveCarregarAntenas,
      ]);

      if (consulta == _consultaDadosEmAndamento) return;

      sequencia = ++_sequenciaRequisicao;
      if (consulta == _ultimaConsultaDados) {
        _consultaDadosEmAndamento = null;
        if (mounted) {
          setState(() {
            _carregando = false;
            _erro = null;
          });
        }
        return;
      }

      _consultaDadosEmAndamento = consulta;
      if (mounted) {
        setState(() {
          if (_todosAtivos.isEmpty) _carregando = true;
          _erro = null;
        });
      }

      var ativosCarregados = <AtivoBdgd>[];
      var antenasCarregadas = <AntenaAnatel>[];
      String? erroCarregamento;

      await Future.wait<void>([
        () async {
          if (!deveCarregarAtivos) return;
          try {
            final ativosImportados = _ativosImportados;
            if (ativosImportados != null) {
              ativosCarregados = ativosImportados
                  .where(
                    (ativo) =>
                        ativo.latitude >= minLatitude &&
                        ativo.latitude <= maxLatitude &&
                        ativo.longitude >= minLongitude &&
                        ativo.longitude <= maxLongitude &&
                        camadasApi.contains(ativo.tipo.apiValue),
                  )
                  .take(_limiteAtivos)
                  .toList();
            } else {
              final resultado = await _ativosService.getAtivos(
                minLatitude: minLatitude,
                maxLatitude: maxLatitude,
                minLongitude: minLongitude,
                maxLongitude: maxLongitude,
                distribuidora: _distribuidoraSelecionada,
                tipos: camadasApi,
                limit: _limiteAtivos,
              );
              ativosCarregados = resultado.ativos;
            }
          } catch (error) {
            erroCarregamento ??=
                'Não foi possível carregar os ativos elétricos: $error';
          }
        }(),
        () async {
          if (!deveCarregarAntenas) return;
          try {
            final resultado = await _camadasExternasService.getAntenas(
              minLatitude: minLatitude,
              maxLatitude: maxLatitude,
              minLongitude: minLongitude,
              maxLongitude: maxLongitude,
              limit: 1000,
            );
            antenasCarregadas = resultado.antenas;
          } catch (error) {
            erroCarregamento ??=
                'Não foi possível carregar as estações da Anatel: $error';
          }
        }(),
      ]);

      if (!mounted || sequencia != _sequenciaRequisicao) {
        return;
      }

      _consultaDadosEmAndamento = null;
      if (erroCarregamento == null) {
        _ultimaConsultaDados = consulta;
      }
      setState(() {
        _todosAtivos = ativosCarregados;
        _antenas = antenasCarregadas;
        _carregando = false;
        _erro = erroCarregamento;
        _avisoAtivos = null;
      });

      _atualizarAnnotations();
    } catch (error, stackTrace) {
      if (sequencia != null && sequencia != _sequenciaRequisicao) {
        return;
      }

      if (sequencia == null) {
        _sequenciaRequisicao++;
      }
      _consultaDadosEmAndamento = null;
      if (!mounted) return;
      debugPrint('Falha ao carregar dados do mapa: $error');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        _erro = 'Falha ao carregar dados do mapa: $error';
        _carregando = false;
      });
    }
  }

  Future<void> _inicializar() async {
    // As duas cargas são independentes: a de distribuidoras pode levar dezenas
    // de segundos e não deve esperar a configuração de vegetação.
    await Future.wait([_carregarConfigVegetacao(), _carregarDistribuidoras()]);
  }

  Future<void> _carregarConfigVegetacao() async {
    var configVegetacao = VegetacaoConfig.fallback();
    try {
      configVegetacao = await _camadasExternasService.getVegetacaoConfig();
    } catch (_) {
      // A camada tem configuração pública de fallback; a falha não bloqueia o mapa.
    }

    if (!mounted) return;
    setState(() {
      _vegetacaoConfig = configVegetacao;
    });
    if (_mapboxMap != null) {
      unawaited(_configurarCamadaVegetacao());
    }
  }

  Future<void> _carregarDistribuidoras({bool novaTentativa = false}) async {
    if (_carregandoDistribuidoras) return;

    // Na primeira carga isto roda dentro de initState, onde setState não é
    // permitido; o build inicial já lê os campos atualizados.
    _carregandoDistribuidoras = true;
    _erroDistribuidoras = null;
    if (novaTentativa) setState(() {});

    try {
      final distribuidoras = await _ativosService.getDistribuidoras();

      if (!mounted) return;

      setState(() {
        _distribuidoras = distribuidoras;
        _distribuidoraSelecionada = null;
        _distribuidorasProntas = true;
        _carregandoDistribuidoras = false;
        _erroDistribuidoras = distribuidoras.isEmpty
            ? 'Nenhuma distribuidora encontrada.'
            : null;
        _carregando = false;
      });

      if (distribuidoras.isNotEmpty) _tentarCargaInicial();
    } catch (error, stackTrace) {
      debugPrint('Falha ao carregar distribuidoras: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _carregandoDistribuidoras = false;
          _carregando = false;
          _erroDistribuidoras = 'Não foi possível carregar as distribuidoras.';
        });
      }
    }
  }

  /// Garante que a lista de distribuidoras está disponível antes de abrir um
  /// seletor. Enquanto carrega, avisa o usuário; se falhou, tenta de novo.
  bool _distribuidorasDisponiveis() {
    if (_distribuidoras.isNotEmpty) return true;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (_carregandoDistribuidoras) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Carregando distribuidoras… isso pode levar até 1 minuto.',
          ),
        ),
      );
      return false;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Tentando carregar as distribuidoras novamente…'),
      ),
    );
    _carregarDistribuidoras(novaTentativa: true);
    return false;
  }

  int get _totalCamadasAtivas =>
      _camadasAtivas.values.where((ativa) => ativa).length +
      (_vegetacaoAtiva ? 1 : 0) +
      (_antenasAtivas ? 1 : 0) +
      (_edificacoesAtivas ? 1 : 0) +
      (_relevoAtivo ? 1 : 0);

  Future<void> _abrirDistribuidoraDoFiltro() async {
    if (!_distribuidorasDisponiveis()) return;
    var confirmado = false;
    String? escolhida;
    await SelectionBottomSheet.show<String>(
      context: context,
      title: 'Distribuidora',
      searchHint: 'Buscar distribuidora',
      items: _distribuidoras
          .map((dist) => SelectionItem(title: dist.nome, value: dist.nome))
          .toList(),
      selectedValue: _distribuidoraSelecionada,
      onSelected: (nome) {
        confirmado = true;
        escolhida = nome;
      },
    );
    if (!mounted || !confirmado || escolhida == null) return;
    // A consulta inicia antes do seletor, que acompanha sua conclusão ao vivo.
    await Future.wait<void>([
      _selecionarDistribuidora(escolhida),
      _abrirFiltroMunicipio(),
    ]);
  }

  Future<void> _selecionarDistribuidora(String? distribuidora) async {
    if (distribuidora == null ||
        (distribuidora == _distribuidoraSelecionada &&
            _ativosImportados == null)) {
      return;
    }

    final correspondentes = _distribuidoras.where(
      (item) => item.nome == distribuidora,
    );
    final selecionada = correspondentes.isEmpty ? null : correspondentes.first;
    setState(() {
      _distribuidoraSelecionada = distribuidora;
      _estadoSelecionado = selecionada?.uf;
      _municipios = [];
      _erroMunicipios = null;
      _ativosImportados = null;
      _ultimaConsultaDados = null;
      _consultaDadosEmAndamento = null;
      _sequenciaRequisicao++;
      _todosAtivos = [];
      _ativoSelecionado = null;
      _municipioSelecionado = null;
      _bairroSelecionado = null;
      _textoBusca = '';
      _buscaController.clear();
      _limparPontosDesenho();
      isDrawing = false;
      _carregando = false;
    });

    if (selecionada != null) {
      await _carregarMunicipios(selecionada);
    }
    if (!mounted || _distribuidoraSelecionada != distribuidora) return;
    _atualizarPoligono();
    await _atualizarAnnotations();
    _agendarCarregamento();
  }

  void _selecionarMunicipioDoFiltro(String? municipio) {
    if (_municipioSelecionado == municipio) return;

    setState(() {
      _municipioSelecionado = municipio;
      _bairroSelecionado = null;
      if (isDrawing) {
        _limparPontosDesenho();
        isDrawing = false;
      }
    });
    _atualizarPoligono();
    _atualizarAnnotations();
    if (municipio != null) {
      unawaited(_centralizarNoMunicipio(municipio));
    }
  }

  Future<void> _centralizarNoMunicipio(String municipio) async {
    final map = _mapboxMap;
    if (map == null) return;

    final correspondentes = _municipios.where((m) => m.nome == municipio);
    final selecionado = correspondentes.isEmpty ? null : correspondentes.first;
    final latitude = selecionado?.latitude;
    final longitude = selecionado?.longitude;
    if (latitude == null || longitude == null) return;

    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: 13.0,
      ),
      MapAnimationOptions(duration: 700),
    );
  }

  Future<void> _iniciarEstudo() async {
    if (_iniciandoEstudo) return;
    _iniciandoEstudo = true;
    try {
      final anoBdgd = _distribuidoras.fold<int>(
        0,
        (ano, distribuidora) =>
            distribuidora.anoBdgd > ano ? distribuidora.anoBdgd : ano,
      );
      final fonte = await StudyDatabaseBottomSheet.show(
        context: context,
        distributorCount: _distribuidoras.length,
        databaseYear: anoBdgd == 0 ? DateTime.now().year : anoBdgd,
      );
      if (!mounted || fonte == null) return;

      if (fonte == StudyDatabaseSource.importFile) {
        List<AtivoBdgd>? ativosImportados;
        List<MunicipioResumo>? municipiosImportados;

        final distribuidora = await StudyImportBottomSheet.show(
          context: context,
          onImport: (versaoBdgd, nomeArquivo, arquivo) async {
            final resposta = await _ativosService.importarArquivoBdgd(
              versaoBdgd: versaoBdgd,
              nomeArquivo: nomeArquivo,
              arquivo: arquivo,
            );
            final metadata = DistribuidoraResumo.fromImportJson(resposta);
            final dadosPostes = resposta['postes'];
            if (dadosPostes is! List) {
              throw const FormatException(
                'A resposta da importação não contém a lista de postes.',
              );
            }
            final postes = dadosPostes
                .map((item) {
                  if (item is! Map) {
                    throw const FormatException(
                      'A lista de postes contém um item inválido.',
                    );
                  }
                  return Map<String, dynamic>.from(item);
                })
                .toList(growable: false);
            final municipios = await _carregarMunicipios(
              metadata,
              filtrarPorDistribuidora: false,
            );
            if (municipios == null) {
              throw StateError(
                _erroMunicipios ?? 'Não foi possível carregar os municípios.',
              );
            }

            final municipiosPorCodigo = <String, String>{};
            ativosImportados = postes.map((poste) {
              final codigo = _normalizarCodigoMunicipio(poste['MUN']);
              final chave = codigo.isEmpty
                  ? _normalizarCodigoMunicipio(poste['COD_ID'])
                  : codigo;
              final nomeMunicipio = municipiosPorCodigo.putIfAbsent(
                chave,
                () => _municipioDoPoste(poste, municipios),
              );
              return AtivoBdgd.fromBdgdPoste(
                poste,
                distribuidora: metadata.nome,
                municipio: nomeMunicipio,
              );
            }).toList();
            municipiosImportados = municipios;
            return metadata;
          },
        );
        if (!mounted || distribuidora == null) return;
        final ativos = ativosImportados;
        final municipios = municipiosImportados;
        if (ativos == null || municipios == null) {
          throw StateError('A importação não retornou os dados esperados.');
        }

        setState(() {
          _ativosImportados = ativos;
          _camadasAtivas = {
            ..._camadasAtivas,
            TipoAtivo.poste: true,
          };
          _ultimaConsultaDados = null;
          _consultaDadosEmAndamento = null;
          _sequenciaRequisicao++;
        });
        await _selecionarDistribuidoraParaEstudo(
          distribuidora,
          municipiosPrecarregados: municipios,
        );
        return;
      }

      final trocarBaseImportada = _ativosImportados != null;
      setState(() {
        _ativosImportados = null;
        _sequenciaMunicipios++;
        _ultimaConsultaDados = null;
        _consultaDadosEmAndamento = null;
        _sequenciaRequisicao++;
        if (trocarBaseImportada) {
          _distribuidoraSelecionada = null;
          _estadoSelecionado = null;
          _municipioSelecionado = null;
          _bairroSelecionado = null;
          _municipios = [];
          _erroMunicipios = null;
          _carregandoMunicipios.value = false;
          _todosAtivos = [];
          _ativoSelecionado = null;
          _carregando = false;
          _limparPontosDesenho();
          isDrawing = false;
        }
      });
      if (trocarBaseImportada) {
        await _atualizarAnnotations();
        await _atualizarPoligono();
      }
      if (!mounted) return;
      if (!_distribuidorasDisponiveis()) return;

      var confirmado = false;
      String? distribuidoraEscolhida;
      await SelectionBottomSheet.show<String>(
        context: context,
        title: 'Distribuidora',
        stepLabel: 'PASSO 2 DE 5',
        searchHint: 'Buscar distribuidora',
        notFoundMessage: _distribuidoras.isEmpty
            ? 'Não foi possível carregar as distribuidoras.'
            : 'Não encontrada',
        items: _distribuidoras
            .map((dist) => SelectionItem(title: dist.nome, value: dist.nome))
            .toList(),
        selectedValue: _distribuidoraSelecionada,
        onSelected: (nome) {
          confirmado = true;
          distribuidoraEscolhida = nome;
        },
      );
      // O seletor fecha antes de abrir a próxima etapa do estudo.
      if (!mounted || !confirmado) return;
      final distribuidora = distribuidoraEscolhida;
      if (distribuidora != null) {
        final resumo = _distribuidoras
            .where((item) => item.nome == distribuidora)
            .first;
        await _selecionarDistribuidoraParaEstudo(resumo);
        return;
      }
      _debounceTimer?.cancel();
      setState(() {
        _distribuidoraSelecionada = null;
        _estadoSelecionado = null;
        _municipioSelecionado = null;
        _bairroSelecionado = null;
        _municipios = [];
        _ativosImportados = null;
        _sequenciaMunicipios++;
        _carregandoMunicipios.value = false;
        _erroMunicipios = null;
        _todosAtivos = [];
        _carregando = false;
        _limparPontosDesenho();
        isDrawing = false;
      });
      await _abrirCidadeDoEstudo();
    } finally {
      _iniciandoEstudo = false;
    }
  }

  Future<void> _selecionarDistribuidoraParaEstudo(
    DistribuidoraResumo distribuidora, {
    List<MunicipioResumo>? municipiosPrecarregados,
  }) async {
    if (!mounted) return;
    final nome = distribuidora.nome;

    if (municipiosPrecarregados == null &&
        nome == _distribuidoraSelecionada &&
        !_carregandoMunicipios.value &&
        _erroMunicipios == null &&
        _municipios.isNotEmpty) {
      // A cidade já escolhida continua marcada ao confirmar a mesma distribuidora.
      setState(() {
        _limparPontosDesenho();
        isDrawing = false;
      });
      await _abrirCidadeDoEstudo();
      return;
    }

    _debounceTimer?.cancel();

    setState(() {
      _distribuidoraSelecionada = nome;
      _estadoSelecionado = distribuidora.uf;
      _municipios = municipiosPrecarregados ?? [];
      _erroMunicipios = null;
      _todosAtivos = [];
      _ativoSelecionado = null;
      _municipioSelecionado = null;
      _bairroSelecionado = null;
      _textoBusca = '';
      _buscaController.clear();
      _limparPontosDesenho();
      isDrawing = false;
      _carregando = false;
    });

    await _atualizarPoligono();
    if (municipiosPrecarregados == null) {
      await _carregarMunicipios(distribuidora);
    } else {
      _sequenciaMunicipios++;
      _carregandoMunicipios.value = false;
    }
    if (!mounted) return;
    // A seleção da cidade depende dos municípios, não das camadas do mapa.
    _agendarCarregamento();
    await _abrirCidadeDoEstudo();
  }

  Future<void> _abrirCidadeDoEstudo() async {
    final cidades = _municipiosDisponiveis;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CidadeBottomSheet(
          cidades: cidades,
          cidadeSelecionada: _municipioSelecionado,
          bairroSelecionado: _bairroSelecionado,
          stepLabel: 'PASSO 3 DE 5',
          breadcrumb: _distribuidoraSelecionada != null
              ? '$_distribuidoraSelecionada · Selecione o município'
              : null,
          notFoundMessage: cidades.isEmpty
              ? _erroMunicipios ?? 'Nenhuma cidade encontrada para a distribuidora selecionada.'
              : 'Não encontrada',
          allowEmptySelection: cidades.isEmpty,
          onProsseguirComBairro: (cidade, bairro) {
            if (cidade == null && cidades.isNotEmpty) return;
            setState(() {
              _municipioSelecionado = cidade;
              _bairroSelecionado = bairro;
              isDrawing = true;
              _limparPontosDesenho();
            });
            _atualizarPoligono();
            if (cidade != null) unawaited(_centralizarNoMunicipio(cidade));
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

  List<String> get _municipiosDisponiveis {
    return _municipios.map((municipio) => municipio.nome).toList();
  }

  String _municipioDoPoste(
    Map<String, dynamic> poste,
    List<MunicipioResumo> municipios,
  ) {
    final codigo = _normalizarCodigoMunicipio(poste['MUN']);
    if (codigo.isNotEmpty) {
      for (final municipio in municipios) {
        if (_normalizarCodigoMunicipio(municipio.codigoIbge) == codigo) {
          return municipio.nome;
        }
      }
    }

    final latitude = _numero(poste['Y']);
    final longitude = _numero(poste['X']);
    if (latitude == null || longitude == null) {
      return codigo.isEmpty ? 'Não informado' : codigo;
    }

    MunicipioResumo? maisProximo;
    var menorDistancia = double.infinity;
    final correcaoLongitude = math.cos(latitude * math.pi / 180);
    for (final municipio in municipios) {
      final latMunicipio = municipio.latitude;
      final lngMunicipio = municipio.longitude;
      if (latMunicipio == null || lngMunicipio == null) continue;

      final deltaLat = latitude - latMunicipio;
      final deltaLng = (longitude - lngMunicipio) * correcaoLongitude;
      final distancia = deltaLat * deltaLat + deltaLng * deltaLng;
      if (distancia < menorDistancia) {
        menorDistancia = distancia;
        maisProximo = municipio;
      }
    }
    return maisProximo?.nome ?? (codigo.isEmpty ? 'Não informado' : codigo);
  }

  String _normalizarCodigoMunicipio(dynamic codigo) {
    final texto = codigo?.toString().trim() ?? '';
    final numerico = num.tryParse(texto);
    return numerico == null ? texto : numerico.toInt().toString();
  }

  double? _numero(dynamic valor) {
    final numero = valor is num ? valor.toDouble() : double.tryParse('$valor');
    return numero != null && numero.isFinite ? numero : null;
  }

  Future<List<MunicipioResumo>?> _carregarMunicipios(
    DistribuidoraResumo distribuidora, {
    bool filtrarPorDistribuidora = true,
  }) async {
    final sequencia = ++_sequenciaMunicipios;
    final uf = distribuidora.uf?.trim();

    if (uf == null || uf.isEmpty) {
      setState(() {
        _municipios = [];
        _carregandoMunicipios.value = false;
        _erroMunicipios =
            'A distribuidora selecionada não possui UF cadastrada.';
      });
      return null;
    }

    setState(() {
      _municipios = [];
      _carregandoMunicipios.value = true;
      _erroMunicipios = null;
    });

    try {
      final municipios = await _ativosService.getMunicipios(
        distribuidora: filtrarPorDistribuidora ? distribuidora.nome : null,
        uf: uf,
      );
      if (!mounted || sequencia != _sequenciaMunicipios) return null;

      setState(() {
        _municipios = municipios;
        _carregandoMunicipios.value = false;
      });
      return municipios;
    } catch (error, stackTrace) {
      if (!mounted || sequencia != _sequenciaMunicipios) return null;

      debugPrint('Falha ao carregar municípios: $error');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        _municipios = [];
        _carregandoMunicipios.value = false;
        _erroMunicipios = 'Não foi possível carregar os municípios: $error';
      });
      return null;
    }
  }

  List<AtivoBdgd> get _ativosVisiveis {
    final termo = _textoBusca.trim().toLowerCase();
    return _todosAtivos.where((ativo) {
      final correspondeMunicipio =
          _municipioSelecionado == null ||
          ativo.municipio == _municipioSelecionado;
      if (!correspondeMunicipio) return false;
      final correspondeBairro =
          _bairroSelecionado == null ||
          ativo.bairro.trim() == _bairroSelecionado;
      if (!correspondeBairro) return false;
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

  Future<void> _abrirFiltroMunicipio() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: _carregandoMunicipios,
        builder: (context, carregandoMunicipios, _) {
          final municipios = _municipiosDisponiveis;
          return SafeArea(
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
                    child: carregandoMunicipios
                        ? const Center(child: CircularProgressIndicator())
                        : municipios.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                _erroMunicipios ?? 'Selecione uma distribuidora para carregar os municípios.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          )
                        : ListView(
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
                                  _selecionarMunicipioDoFiltro(null);
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
                                    _selecionarMunicipioDoFiltro(municipio);
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _abrirPainelCamadas() {
    LayerFilterModal.exibir(
      context,
      camadasAtivas: _camadasAtivas,
      vegetacaoAtiva: _vegetacaoAtiva,
      antenasAtivas: _antenasAtivas,
      edificacoesAtivas: _edificacoesAtivas,
      onSalvarVegetacao: (ativa) {
        setState(() {
          _vegetacaoAtiva = ativa;
          if (!ativa) _legendaExpandida = false;
        });
        unawaited(_configurarCamadaVegetacao());
      },
      relevoAtivo: _relevoAtivo,
      onSalvarRelevo: (ativo) {
        setState(() => _relevoAtivo = ativo);
        unawaited(_atualizarVisibilidadeRelevo());
      },
      onSalvarAntenas: (ativa) {
        setState(() => _antenasAtivas = ativa);
      },
      onSalvarEdificacoes: (ativas) {
        _edificacoesAtivas = ativas;
      },
      onSalvarFiltro: (novasCamadas) {
        setState(() {
          _camadasAtivas = novasCamadas;
        });

        _agendarCarregamento();
        _atualizarAnnotations();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Camadas atualizadas: $_totalCamadasAtivas de ${_camadasAtivas.length + 4} ativas',
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

  void _exibirEdificacao(Edificacao edificacao) {
    Widget linha(String rotulo, String valor) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                rotulo,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            Text(
              valor,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.apartment, color: edificacao.cor),
                  const SizedBox(width: 10),
                  const Text(
                    'Edifício',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              linha(
                'Altura',
                edificacao.origemAltura == 'INFORMADA'
                    ? edificacao.alturaFormatada
                    : '${edificacao.alturaFormatada} (estimada)',
              ),
              if (edificacao.pavimentos != null)
                linha('Pavimentos', '${edificacao.pavimentos}'),
              linha(
                'Material',
                edificacao.origemMaterial == 'INFORMADO'
                    ? edificacao.nomeMaterial
                    : '${edificacao.nomeMaterial} (padrão)',
              ),
              linha(
                'Perda do material',
                '${edificacao.perdaMaterialDb.toStringAsFixed(1)} dB',
              ),
              if (edificacao.areaM2 != null)
                linha('Área', '${edificacao.areaM2!.toStringAsFixed(0)} m²'),
            ],
          ),
        ),
      ),
    );
  }

  bool get _areaDesenhada => polygonPoints.length >= 3;

  void _cancelarArea() {
    setState(() {
      _limparPontosDesenho();
      isDrawing = false;
      _municipioSelecionado = null;
      _bairroSelecionado = null;
    });
    _atualizarPoligono();
  }

  Future<void> _prosseguirArea() async {
    final autenticado = await AuthScope.ensureSignedIn(context);
    if (!autenticado || !mounted) return;

    final userId = AuthScope.maybeOf(context)?.controller.user?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível identificar o usuário.'),
        ),
      );
      return;
    }

    final revisao = _polygonRevision;
    setState(() => isDrawing = false);
    final consultasRelevo = List<Future<void>>.of(_consultasRelevo);
    await Future.wait(consultasRelevo);
    if (!mounted || revisao != _polygonRevision) return;

    final estudoCriado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NovoEstudoPage(
          userId: userId,
          distribuidora: _distribuidoraSelecionada ?? '',
          municipio: _municipioSelecionado,
          bairro: _bairroSelecionado,
          uf: _estadoSelecionado,
          areaKm2: calculatePolygonAreaKm2(polygonPoints),
          pontosArea: List.unmodifiable(polygonPoints),
          ativosImportados: List.unmodifiable(_ativosImportados ?? const []),
          usarBaseImportada: _ativosImportados != null,
          relevoPontos: List.unmodifiable(_relevoPontos),
        ),
      ),
    );

    if (estudoCriado == true && mounted) {
      setState(() {
        _limparPontosDesenho();
        isDrawing = false;
        _municipioSelecionado = null;
        _bairroSelecionado = null;
      });
      _atualizarPoligono();
    } else if (mounted) {
      setState(() => isDrawing = true);
    }
  }

  Widget _linhaDetalheAntena(String titulo, String valor) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(color: AppColors.textWhite),
        children: [
          TextSpan(
            text: '$titulo: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: valor),
        ],
      ),
    );
  }

  void _abrirDetalhesAntena(AntenaAnatel antena) {
    final tecnologias = antena.tecnologias.isEmpty
        ? 'Não informado'
        : antena.tecnologias.join(', ');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                antena.nomeEntidade ?? 'Estação licenciada pela Anatel',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textWhite,
                ),
              ),
              const SizedBox(height: 12),

              _linhaDetalheAntena(
                'Município',
                '${antena.municipio ?? 'Não informado'}'
                    '${antena.uf == null ? '' : ' / ${antena.uf}'}',
              ),

              _linhaDetalheAntena('Tecnologias', tecnologias),

              _linhaDetalheAntena(
                'Registros de emissão agrupados',
                '${antena.totalRegistros}',
              ),

              if (antena.tipoEstacao != null)
                _linhaDetalheAntena('Tipo de estação', antena.tipoEstacao!),

              if (antena.alturaAntenaMediaM != null)
                _linhaDetalheAntena(
                  'Altura média informada',
                  '${antena.alturaAntenaMediaM!.toStringAsFixed(1)} m',
                ),

              _linhaDetalheAntena(
                'Latitude / longitude',
                '${antena.latitude.toStringAsFixed(6)} / '
                    '${antena.longitude.toStringAsFixed(6)}',
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  bool get _emTesteDeWidget => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  // Viewport usado somente na criação do mapa. Manter constante evita que
  // rebuilds de estado (setState) recriem o CameraViewportState e o Mapbox
  // voe de volta para a posição inicial durante a interação do usuário.
  static final CameraViewportState _viewportInicial = CameraViewportState(
    center: Point(coordinates: Position(-51.9253, -14.2350)),
    zoom: 3.8,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_emTesteDeWidget)
            const ColoredBox(color: AppColors.surfaceBackground)
          else
            MapWidget(
              key: const ValueKey('mapWidget'),
              styleUri: MapboxStyles.STANDARD,
              viewport: _viewportInicial,
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded,
              onCameraChangeListener: (_) => unawaited(_sincronizarZoom()),
              onMapIdleListener: (_) => _agendarCarregamento(),
            ),
          if (!isDrawing)
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
                        label: _distribuidoraSelecionada != null
                            ? 'DIST. $_distribuidoraSelecionada'
                            : _carregandoDistribuidoras
                            ? 'DIST. (carregando…)'
                            : _distribuidoras.isEmpty
                            ? 'DIST. (tentar novamente)'
                            : 'DIST.',
                        isSelected: _distribuidoraSelecionada != null,
                        onTap: _abrirDistribuidoraDoFiltro,
                      ),
                      FilterChipWidget(
                        label: _municipioSelecionado ?? 'Cidade',
                        onTap: _abrirFiltroMunicipio,
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: MapNavigationControls(
                      onZoomIn: _zoomIn,
                      onZoomOut: _zoomOut,
                    ),
                  ),
                ],
              ),
            ),
          if (isDrawing)
            Positioned.fill(
              child: ListenableBuilder(
                listenable: _contagemArea,
                builder: (context, _) => StudyAreaStep(
                  locationLabel: _locationLabel,
                  areaDesenhada: _areaDesenhada,
                  areaKm2: calculatePolygonAreaKm2(polygonPoints),
                  ativosNaArea: _contagemArea.count,
                  carregandoAtivos: _contagemArea.loading,
                  erroAtivos: _contagemArea.error,
                  onTentarContagem: _consultarAtivosDaArea,
                  onCancelar: _cancelarArea,
                  onRefazer: _refazerDesenhoArea,
                  onProsseguir: _prosseguirArea,
                ),
              ),
            )
          else
            Positioned(
              left: 15,
              right: 15,
              bottom: 10,
              child: ElevatedButton(
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
          if (_vegetacaoAtiva &&
              _vegetacaoConfig != null &&
              _vegetacaoConfig!.classes.isNotEmpty)
            Positioned(
              left: 15,
              bottom: 90,
              child: Container(
                width: _legendaExpandida ? 220 : 160,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _legendaExpandida = !_legendaExpandida;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Legenda',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textWhite,
                                  ),
                                ),
                              ),
                              Icon(
                                _legendaExpandida
                                    ? Icons.close_fullscreen
                                    : Icons.open_in_full,
                                size: 17,
                                color: AppColors.textWhite,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (_legendaExpandida) ...[
                      const Divider(height: 1, color: AppColors.border),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tipos de Vegetação',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textWhite,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const SizedBox(height: 8),
                            for (final classe in _vegetacaoConfig!.classes)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Color(
                                          int.parse(
                                            'FF${classe.cor.replaceFirst('#', '')}',
                                            radix: 16,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${classe.codigo} · ${classe.nome}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textWhite,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_edificacoesAtivas &&
              (_carregandoEdificacoes || _avisoEdificacoes != null))
            Positioned(
              left: 0,
              right: 0,
              bottom: 76,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      if (_carregandoEdificacoes)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryLime,
                          ),
                        )
                      else
                        const Icon(
                          Icons.apartment,
                          size: 16,
                          color: AppColors.layerEdificacao,
                        ),
                      Text(
                        _carregandoEdificacoes
                            ? 'Carregando edifícios...'
                            : _avisoEdificacoes!,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_carregando && _todosAtivos.isEmpty)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primaryLime),
              ),
            ),
          if (_erro != null ||
              _erroDistribuidoras != null ||
              _erroMapa != null ||
              _erroRelevo != null ||
              _avisoAtivos != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 100,
              child: Card(
                color: AppColors.surfaceCard,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        [
                          _erroDistribuidoras,
                          _erro,
                          _erroMapa,
                          _erroRelevo,
                          _avisoAtivos,
                        ].whereType<String>().join('\n'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textWhite),
                      ),
                      if (_erroDistribuidoras != null &&
                          !_carregandoDistribuidoras)
                        TextButton.icon(
                          onPressed: () =>
                              _carregarDistribuidoras(novaTentativa: true),
                          icon: const Icon(
                            Icons.refresh,
                            color: AppColors.primaryLime,
                          ),
                          label: const Text(
                            'Tentar novamente',
                            style: TextStyle(color: AppColors.primaryLime),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
