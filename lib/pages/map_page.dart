import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:frontend_tecsys/widgets/layer_filter_button.dart';
import 'package:frontend_tecsys/widgets/search_bar.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/city_bairro_bottom_sheet.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/models/antena_anatel.dart';
import 'package:frontend_tecsys/models/vegetacao_config.dart';
import 'package:frontend_tecsys/models/layer_filter.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/services/camadas_externas_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/asset_detail_sheet.dart';
import 'package:frontend_tecsys/widgets/layer_filter_modal.dart';
import 'package:frontend_tecsys/widgets/map_navigation.dart';
import 'package:frontend_tecsys/widgets/filter_chip.dart';
import 'package:frontend_tecsys/pages/novo_estudo_page.dart';
import 'package:frontend_tecsys/utils/map_utils.dart';
import 'package:frontend_tecsys/widgets/map_switch.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _fallbackCenter = LatLng(-23.4532, -46.4438);

  final MapController _mapController = MapController();
  final AtivosService _ativosService = AtivosService();
  final CamadasExternasService _camadasExternasService = CamadasExternasService();
  final TextEditingController _buscaController = TextEditingController();

  List<DistribuidoraResumo> _distribuidoras = [];
  String? _distribuidoraSelecionada;
  String? _municipioSelecionado;
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

  Timer? _debounceTimer;
  int _sequenciaRequisicao = 0;
  bool _mapaPronto = false;
  bool _distribuidorasProntas = false;
  bool _cargaInicialFeita = false;

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
    _camadasExternasService.dispose();
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
    _agendarCarregamento();
  }

  void _agendarCarregamento() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), _carregarDados);
  }

  Future<void> _carregarDados() async {
    if (!_mapaPronto) return;

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
      });
      return;
    }

    final sequencia = ++_sequenciaRequisicao;
    final bounds = _mapController.camera.visibleBounds;
    if (mounted) {
      setState(() {
        _carregando = _todosAtivos.isEmpty && _antenas.isEmpty;
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
            minLatitude: bounds.south,
            maxLatitude: bounds.north,
            minLongitude: bounds.west,
            maxLongitude: bounds.east,
            distribuidora: _distribuidoraSelecionada,
            tipos: camadasApi,
            limit: _limiteAtivos,
          );
          ativosCarregados = resultado.ativos;
        } catch (error) {
          erroCarregamento ??= 'Não foi possível carregar os ativos elétricos: $error';
        }
      }(),
      () async {
        if (!deveCarregarAntenas) return;
        try {
          final resultado = await _camadasExternasService.getAntenas(
            minLatitude: bounds.south,
            maxLatitude: bounds.north,
            minLongitude: bounds.west,
            maxLongitude: bounds.east,
            limit: 1000,
          );
          antenasCarregadas = resultado.antenas;
        } catch (error) {
          erroCarregamento ??= 'Não foi possível carregar as estações da Anatel: $error';
        }
      }(),
    ]);

    if (!mounted || sequencia != _sequenciaRequisicao) return;
    setState(() {
      _todosAtivos = ativosCarregados;
      _antenas = antenasCarregadas;
      _carregando = false;
      _erro = erroCarregamento;
    });
  }

  Future<void> _inicializar() async {
    var configVegetacao = VegetacaoConfig.fallback();
    var distribuidoras = <DistribuidoraResumo>[];

    try {
      configVegetacao = await _camadasExternasService.getVegetacaoConfig();
    } catch (_) {
      // A camada tem configuração pública de fallback; a falha não bloqueia o mapa.
    }
    try {
      distribuidoras = await _ativosService.getDistribuidoras();
    } catch (_) {
      // As camadas externas ainda podem ser usadas sem uma distribuidora.
    }

    if (!mounted) return;
    setState(() {
      _vegetacaoConfig = configVegetacao;
      _distribuidoras = distribuidoras;
      _distribuidoraSelecionada = distribuidoras.isEmpty ? null : distribuidoras.first.nome;
      _distribuidorasProntas = true;
      _carregando = false;
    });
    _tentarCargaInicial();
  }

  int get _totalCamadasAtivas =>
      _camadasAtivas.values.where((ativa) => ativa).length +
      (_vegetacaoAtiva ? 1 : 0) +
      (_antenasAtivas ? 1 : 0);

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
          // Nenhuma distribuidora disponível (lista vazia);
          // o usuário optou por prosseguir mesmo assim.
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

    // Mesma regra: o sheet abre mesmo com "cidades" vazia,
    // mostrando a mensagem de "não encontrada" no lugar da lista.
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
            // Reaproveita o mesmo filtro local que o chip
            // "Cidade / bairro" já usa (_ativosVisiveis),
            // então isso já atualiza o mapa automaticamente.
            setState(() {
              _municipioSelecionado = cidade;
            });
          },
        );
      },
    );
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_mapController.camera.zoom + 1).clamp(3.8, 18.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_mapController.camera.zoom - 1).clamp(3.8, 18.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
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
    return municipios.toList();
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
      vegetacaoAtiva: _vegetacaoAtiva,
      antenasAtivas: _antenasAtivas,
      onSalvarVegetacao: (ativa) {
        setState(() => _vegetacaoAtiva = ativa);
      },
      onSalvarAntenas: (ativa) {
        setState(() => _antenasAtivas = ativa);
      },
      onSalvarFiltro: (novasCamadas) {
        setState(() {
          _camadasAtivas = novasCamadas;
        });

        _agendarCarregamento();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Camadas atualizadas: $_totalCamadasAtivas de ${_camadasAtivas.length + 2} ativas',
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
          areaKm2: calculatePolygonAreaKm2(polygonPoints),
          pontosArea: List.unmodifiable(polygonPoints),
        ),
      ),
    );

    if (estudoCriado == true && mounted) {
      setState(() => polygonPoints = []);
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

  List<Marker> _gerarMarcadoresAntenas() {
    if (!_antenasAtivas) return [];
    return _antenas.map((antena) {
      return Marker(
        point: LatLng(antena.latitude, antena.longitude),
        width: 38,
        height: 38,
        child: GestureDetector(
          onTap: () => _abrirDetalhesAntena(antena),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.secondaryTeal, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondaryTeal.withValues(alpha: 0.35),
                  blurRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.cell_tower, color: AppColors.secondaryTeal, size: 21),
          ),
        ),
      );
    }).toList();
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textWhite),
              ),
              const SizedBox(height: 12),
              Text('Município: ${antena.municipio ?? 'Não informado'}${antena.uf == null ? '' : ' / ${antena.uf}'}'),
              Text('Tecnologias: $tecnologias'),
              Text('Registros de emissão agrupados: ${antena.totalRegistros}'),
              if (antena.tipoEstacao != null) Text('Tipo de estação: ${antena.tipoEstacao}'),
              if (antena.alturaAntenaMediaM != null)
                Text('Altura média informada: ${antena.alturaAntenaMediaM!.toStringAsFixed(1)} m'),
              Text('Latitude / longitude: ${antena.latitude.toStringAsFixed(6)} / ${antena.longitude.toStringAsFixed(6)}'),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
              onMapReady: _aoMapaPronto,
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
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) _agendarCarregamento();
              },
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
              if (_vegetacaoAtiva && _vegetacaoConfig != null)
                TileLayer(
                  wmsOptions: WMSTileLayerOptions(
                    baseUrl: _vegetacaoConfig!.baseUrl,
                    layers: [_vegetacaoConfig!.layer],
                    version: _vegetacaoConfig!.version,
                    format: _vegetacaoConfig!.format,
                    transparent: true,
                    crs: const Epsg3857(),
                  ),
                  userAgentPackageName: 'com.example.frontend_tecsys',
                  tileBuilder: (context, tileWidget, tile) =>
                      Opacity(opacity: 0.58, child: tileWidget),
                ),
              MarkerLayer(markers: [...marcadores, ..._gerarMarcadoresAntenas()]),
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
                          subtitle:
                              'Os ativos serão recarregados para a região escolhida.',
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
                  border: Border.all(
                    color: AppColors.border,
                  ),
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
                      const Divider(
                        height: 1,
                        color: AppColors.border,
                      ),
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
                      shadowColor:
                          AppColors.primaryLime.withValues(alpha: 0.4),
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