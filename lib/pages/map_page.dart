import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
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
  CircleAnnotationManager? _antenaAnnotationManager;
  Cancelable? _pointTapEvents;
  Cancelable? _antenaTapEvents;
  final Map<String, AtivoBdgd> _ativosPorAnnotationId = {};
  final Map<String, AntenaAnatel> _antenasPorAnnotationId = {};
  Uint8List? _poleIconImage;

  final AtivosService _ativosService = AtivosService();
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
  List<AntenaAnatel> _antenas = [];
  VegetacaoConfig? _vegetacaoConfig;
  bool _vegetacaoAtiva = false;
  bool _antenasAtivas = false;
  bool _legendaExpandida = false;
  Map<TipoAtivo, bool> _camadasAtivas =
      CatalogoCamadas.obterEstadoInicialPadrao();
  AtivoBdgd? _ativoSelecionado;
  bool _carregando = true;
  String? _erro;
  String? _erroMapa;
  String? _erroMunicipios;
  bool _carregandoMunicipios = false;

  Timer? _debounceTimer;
  int _sequenciaRequisicao = 0;
  int _sequenciaMunicipios = 0;
  bool _mapaPronto = false;
  bool _distribuidorasProntas = false;
  bool _cargaInicialFeita = false;

  bool _edificacoesAtivas = false;
  List<Edificacao> _edificacoes = [];
  bool _carregandoEdificacoes = false;
  String? _avisoEdificacoes;
  String? _avisoAtivos;
  int _sequenciaEdificacoes = 0;

  static const int _limiteAtivos = 3000;
  static const double _ladoMaximoGrausAtivos = 0.2;
  static const String _terrainSourceId = 'study-terrain-dem';
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
    _inicializar();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _buscaController.dispose();
    _pointTapEvents?.cancel();
    _antenaTapEvents?.cancel();
    _ativosService.dispose();
    _camadasExternasService.dispose();
    _edificacoesService.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap controller) async {
    _mapboxMap = controller;
    controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    try {
      final image = await rootBundle.load('assets/images/PoleIcon.png');
      _poleIconImage = image.buffer.asUint8List(
        image.offsetInBytes,
        image.lengthInBytes,
      );
    } catch (error, stackTrace) {
      debugPrint('Falha ao carregar o ícone de poste: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _erroMapa = 'Não foi possível carregar o ícone dos postes.';
        });
      }
    }

    if (!kIsWeb) {
      _pointAnnotationManager = await controller.annotations
          .createPointAnnotationManager();
      _pointTapEvents = _pointAnnotationManager!.tapEvents(
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
      Future.wait([_configurarRelevo(), _configurarCamadaEdificacoes()])
          .whenComplete(() {
            if (!_terrainReady.isCompleted) _terrainReady.complete();
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
      await map.setStyleTerrain(
        jsonEncode({'source': _terrainSourceId, 'exaggeration': 1.0}),
      );
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

  bool _ativoDentroDaArea(AtivoBdgd ativo) {
    if (polygonPoints.length < 3) return false;

    var dentro = false;
    for (
      var i = 0, j = polygonPoints.length - 1;
      i < polygonPoints.length;
      j = i++
    ) {
      final atual = polygonPoints[i];
      final anterior = polygonPoints[j];
      final cruzaLatitude =
          (atual.latitude > ativo.latitude) !=
          (anterior.latitude > ativo.latitude);
      if (!cruzaLatitude) continue;

      final longitudeIntersecao =
          (anterior.longitude - atual.longitude) *
              (ativo.latitude - atual.latitude) /
              (anterior.latitude - atual.latitude) +
          atual.longitude;
      if (ativo.longitude < longitudeIntersecao) dentro = !dentro;
    }
    return dentro;
  }

  int get _ativosNaArea => _todosAtivos
      .where(
        (ativo) =>
            _municipioSelecionado == null ||
            ativo.municipio == _municipioSelecionado,
      )
      .where(_ativoDentroDaArea)
      .length;

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
    if (_pointAnnotationManager == null) return;

    List<PointAnnotationOptions> optionsList = [];
    for (var ativo in ativosFiltrados) {
      optionsList.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(ativo.longitude, ativo.latitude),
          ),
          image: ativo.tipo == TipoAtivo.poste ? _poleIconImage : null,
          iconSize: _ativoSelecionado?.id == ativo.id ? 3 : 4,
        ),
      );
    }

    try {
      await _pointAnnotationManager!.deleteAll();
      final annotations = await _pointAnnotationManager!.createMulti(
        optionsList,
      );
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

    final sequencia = ++_sequenciaEdificacoes;

    if (!_edificacoesAtivas) {
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
      setState(() {
        _edificacoes = [];
        _carregandoEdificacoes = false;
        _avisoEdificacoes = 'Aproxime o mapa para ver os edifícios';
      });
      await _atualizarEdificacoesNoMapa();
      return;
    }

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

      setState(() {
        _edificacoes = edificacoes;
        _carregandoEdificacoes = false;
      });
      await _atualizarEdificacoesNoMapa();
    } catch (error) {
      if (!mounted || sequencia != _sequenciaEdificacoes) return;

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
      final minLatitude = bounds.southwest.coordinates.lat.toDouble();
      final maxLatitude = bounds.northeast.coordinates.lat.toDouble();
      final minLongitude = bounds.southwest.coordinates.lng.toDouble();
      final maxLongitude = bounds.northeast.coordinates.lng.toDouble();

      final areaMuitoAmpla =
          (maxLatitude - minLatitude) > _ladoMaximoGrausAtivos ||
          (maxLongitude - minLongitude) > _ladoMaximoGrausAtivos;
      if (areaMuitoAmpla) {
        if (!mounted) return;
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

      setState(() {
        _todosAtivos = ativosCarregados;
        _antenas = antenasCarregadas;
        _carregando = false;
        _erro = erroCarregamento;
        _avisoAtivos = null;
      });

      _atualizarAnnotations();
    } catch (error, stackTrace) {
      if (!mounted || sequencia != _sequenciaRequisicao) {
        return;
      }

      debugPrint('Falha ao carregar dados do mapa: $error');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        _erro = 'Falha ao carregar dados do mapa: $error';
        _carregando = false;
      });
    }
  }

  Future<void> _inicializar() async {
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

    try {
      final distribuidoras = await _ativosService.getDistribuidoras();

      if (!mounted) return;

      setState(() {
        _distribuidoras = distribuidoras;
        _distribuidoraSelecionada = null;
        _distribuidorasProntas = true;
        _carregando = false;
        _erro = null;
      });

      if (distribuidoras.isNotEmpty) _tentarCargaInicial();
    } catch (error, stackTrace) {
      debugPrint('Falha ao carregar distribuidoras: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = 'Não foi possível carregar as distribuidoras.';
        });
      }
    }
  }

  int get _totalCamadasAtivas =>
      _camadasAtivas.values.where((ativa) => ativa).length +
      (_vegetacaoAtiva ? 1 : 0) +
      (_antenasAtivas ? 1 : 0) +
      (_edificacoesAtivas ? 1 : 0);

  Future<void> _selecionarDistribuidora(String? distribuidora) async {
    if (distribuidora == null || distribuidora == _distribuidoraSelecionada) {
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
      _todosAtivos = [];
      _ativoSelecionado = null;
      _municipioSelecionado = null;
      _bairroSelecionado = null;
      _textoBusca = '';
      _buscaController.clear();
      _limparPontosDesenho();
      isDrawing = false;
      _carregando = true;
    });

    if (selecionada != null) {
      await _carregarMunicipios(selecionada);
    }
    _atualizarPoligono();
    await _atualizarAnnotations();
    _agendarCarregamento();
  }

  void _selecionarMunicipioDoFiltro(String? municipio) {
    if (_municipioSelecionado == municipio) return;

    setState(() {
      _municipioSelecionado = municipio;
      if (isDrawing) {
        _limparPontosDesenho();
        isDrawing = false;
        _bairroSelecionado = null;
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
    await SelectionBottomSheet.show<String>(
      context: context,
      title: 'Distribuidora',
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
          _debounceTimer?.cancel();
          setState(() {
            _distribuidoraSelecionada = null;
            _estadoSelecionado = null;
            _municipioSelecionado = null;
            _bairroSelecionado = null;
            _municipios = [];
            _sequenciaMunicipios++;
            _carregandoMunicipios = false;
            _erroMunicipios = null;
            _todosAtivos = [];
            _carregando = false;
            _limparPontosDesenho();
            isDrawing = false;
          });
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
    final distribuidoraSelecionada = _distribuidoras
        .where((item) => item.nome == distribuidora)
        .first;

    setState(() {
      _distribuidoraSelecionada = distribuidora;
      _estadoSelecionado = distribuidoraSelecionada.uf;
      _municipios = [];
      _erroMunicipios = null;
      _todosAtivos = [];
      _ativoSelecionado = null;
      _municipioSelecionado = null;
      _bairroSelecionado = null;
      _textoBusca = '';
      _buscaController.clear();
      _limparPontosDesenho();
      isDrawing = false;
      _carregando = true;
    });

    await _atualizarPoligono();
    await _carregarMunicipios(distribuidoraSelecionada);
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
          bairroSelecionado: _bairroSelecionado,
          stepLabel: 'PASSO 2 DE 4',
          breadcrumb: _distribuidoraSelecionada != null
              ? '$_distribuidoraSelecionada · Selecione o município'
              : null,
          notFoundMessage: cidades.isEmpty
              ? _erroMunicipios ?? 'Nenhuma cidade encontrada para a distribuidora selecionada.'
              : 'Não encontrada',
          allowEmptySelection: cidades.isEmpty,
          onProsseguir: (cidade, bairro) {
            if (cidade == null && cidades.isNotEmpty) return;
            setState(() {
              _municipioSelecionado = cidade;
              _bairroSelecionado = bairro;
              isDrawing = true;
              _limparPontosDesenho();
            });
            _atualizarPoligono();
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
    return _municipios.map((municipio) => municipio.nome).toList();
  }

  Future<void> _carregarMunicipios(DistribuidoraResumo distribuidora) async {
    final sequencia = ++_sequenciaMunicipios;
    final uf = distribuidora.uf?.trim();

    if (uf == null || uf.isEmpty) {
      setState(() {
        _municipios = [];
        _carregandoMunicipios = false;
        _erroMunicipios =
            'A distribuidora selecionada não possui UF cadastrada.';
      });
      return;
    }

    setState(() {
      _municipios = [];
      _carregandoMunicipios = true;
      _erroMunicipios = null;
    });

    try {
      final municipios = await _ativosService.getMunicipios(
        distribuidora: distribuidora.nome,
        uf: uf,
      );
      if (!mounted || sequencia != _sequenciaMunicipios) return;

      setState(() {
        _municipios = municipios;
        _carregandoMunicipios = false;
      });
    } catch (error, stackTrace) {
      if (!mounted || sequencia != _sequenciaMunicipios) return;

      debugPrint('Falha ao carregar municípios: $error');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        _municipios = [];
        _carregandoMunicipios = false;
        _erroMunicipios = 'Não foi possível carregar os municípios: $error';
      });
    }
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
                child: _carregandoMunicipios
                    ? const Center(child: CircularProgressIndicator())
                    : municipios.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _erroMunicipios ?? 'Selecione uma distribuidora para carregar os municípios.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMuted),
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
        setState(() => _vegetacaoAtiva = ativa);
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
              'Camadas atualizadas: $_totalCamadasAtivas de ${_camadasAtivas.length + 3} ativas',
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
    final revisao = _polygonRevision;
    setState(() => isDrawing = false);
    final consultasRelevo = List<Future<void>>.of(_consultasRelevo);
    await Future.wait(consultasRelevo);
    if (!mounted || revisao != _polygonRevision) return;

    final estudoCriado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NovoEstudoPage(
          distribuidora: _distribuidoraSelecionada ?? '',
          municipio: _municipioSelecionado,
          bairro: _bairroSelecionado,
          uf: _estadoSelecionado,
          areaKm2: calculatePolygonAreaKm2(polygonPoints),
          pontosArea: List.unmodifiable(polygonPoints),
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
                      if (_distribuidoraSelecionada != null &&
                          _municipioSelecionado != null)
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
                        label: _distribuidoraSelecionada == null
                            ? 'DIST.'
                            : 'DIST. $_distribuidoraSelecionada',
                        isSelected: _distribuidoraSelecionada != null,
                        onTap: () {
                          SelectionBottomSheet.show<String>(
                            context: context,
                            title: 'Distribuidora',
                            searchHint: 'Buscar distribuidora',
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
          if (isDrawing)
            Positioned.fill(
              child: StudyAreaStep(
                locationLabel: _locationLabel,
                areaDesenhada: _areaDesenhada,
                areaKm2: calculatePolygonAreaKm2(polygonPoints),
                ativosNaArea: _ativosNaArea,
                onCancelar: _cancelarArea,
                onRefazer: _refazerDesenhoArea,
                onProsseguir: _prosseguirArea,
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
                  child: Text(
                    [
                      _erro,
                      _erroMapa,
                      _erroRelevo,
                      _avisoAtivos,
                    ].whereType<String>().join('\n'),
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
