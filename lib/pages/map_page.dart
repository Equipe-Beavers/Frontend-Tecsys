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
  Uint8List? _poleIconImage;

  final AtivosService _ativosService = AtivosService();
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

  static const int _limiteAtivos = 3000;
  static const String _terrainSourceId = 'study-terrain-dem';

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
    _ativosService.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap controller) async {
    _mapboxMap = controller;
    controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    _pointAnnotationManager = await controller.annotations
        .createPointAnnotationManager();
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
        _adicionarPontoDesenho(context.point);
      }),
    );

    _mapaPronto = true;
    _tentarCargaInicial();
  }

  void _onStyleLoaded(StyleLoadedEventData _) {
    unawaited(
      _configurarRelevo().whenComplete(() {
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
    if (_pointAnnotationManager == null) return;

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
      await _pointAnnotationManager!.createMulti(optionsList);
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
    if (!_mapaPronto || !_distribuidorasProntas || _cargaInicialFeita) {
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
    if (!_mapaPronto || _mapboxMap == null) {
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
    } catch (error, stackTrace) {
      if (!mounted || sequencia != _sequenciaRequisicao) {
        return;
      }

      debugPrint('Falha ao carregar ativos: $error');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        _erro = 'Falha ao carregar ativos: $error';
        _carregando = false;
      });
    }
  }

  Future<void> _inicializar() async {
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
      _camadasAtivas.values.where((ativa) => ativa).length;

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
            onStyleLoadedListener: _onStyleLoaded,
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
          if (_carregando && _todosAtivos.isEmpty)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primaryLime),
              ),
            ),
          if (_erro != null || _erroMapa != null || _erroRelevo != null)
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
