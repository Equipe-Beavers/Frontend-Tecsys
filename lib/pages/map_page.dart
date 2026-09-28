import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:frontend_tecsys/widgets/layer_filter_button.dart';
import 'package:frontend_tecsys/widgets/search_bar.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/city_bairro_bottom_sheet.dart';
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
  static const _fallbackCenter = LatLng(-23.4532, -46.4438);

  final MapController _mapController = MapController();
  final AtivosService _ativosService = AtivosService();
  final TextEditingController _buscaController = TextEditingController();

  List<DistribuidoraResumo> _distribuidoras = [];
  List<MunicipioResumo> _municipios = [];
  String? _distribuidoraSelecionada;
  String? _municipioSelecionado;
  String? _bairroSelecionado;
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
  bool _municipiosCarregando = false;
  bool _cargaInicialFeita = false;

  static const int _limiteAtivos = 3000;

  final Map<Marker, AtivoBdgd> _markerAtivoMap = {};

  List<LatLng> polygonPoints = [];
  bool isDrawing = true;

  @override
  void initState() {
    super.initState();
    _inicializar();
    _carregarMunicipios();
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
    if (!_mapaPronto || _distribuidoraSelecionada == null) {
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

      if (!mounted || sequencia != _sequenciaRequisicao) {
        return;
      }

      setState(() {
        _todosAtivos = resultado.ativos;
        _carregando = false;
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
          _erro = 'Nenhuma distribuidora foi encontrada.';
          _carregando = false;
        });
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
          _erro = 'Não foi possível carregar as distribuidoras.';
          _carregando = false;
        });
      }
    }
  }

  Future<void> _carregarMunicipios() async {
    if (_municipiosCarregando) return;

    setState(() => _municipiosCarregando = true);
    try {
      final municipios = await _ativosService.getMunicipios();
      if (!mounted) return;

      setState(() => _municipios = municipios);
    } catch (_) {
      if (mounted && _erro == null) {
        setState(() => _erro = 'Não foi possível carregar as cidades.');
      }
    } finally {
      if (mounted) setState(() => _municipiosCarregando = false);
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
      _bairroSelecionado = null;
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

    final distribuidoraAlterada = distribuidora != _distribuidoraSelecionada;
    setState(() {
      _distribuidoraSelecionada = distribuidora;
      _todosAtivos = [];
      _ativoSelecionado = null;
      if (distribuidoraAlterada) {
        _municipioSelecionado = null;
        _bairroSelecionado = null;
      }
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
    if (_municipios.isEmpty) await _carregarMunicipios();
    if (!mounted) return;

    final cidades = _municipiosDisponiveis;
    String? cidadeEscolhida;
    String? bairroEscolhido;

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
          ufPorCidade: {
            for (final municipio in _municipios) municipio.nome: municipio.uf,
          },
          cidadeSelecionada: _municipioSelecionado,
          bairroSelecionado: _bairroSelecionado,
          stepLabel: 'PASSO 2 DE 4',
          breadcrumb: _distribuidoraSelecionada != null
              ? '$_distribuidoraSelecionada · Selecione o município'
              : null,
          notFoundMessage: cidades.isEmpty
              ? 'Nenhuma cidade encontrada para a distribuidora selecionada.'
              : 'Não encontrada',
          onProsseguir: (cidade, bairro) {
            cidadeEscolhida = cidade;
            bairroEscolhido = bairro;
          },
        );
      },
    );

    if (!mounted || cidadeEscolhida == null) return;

    final municipio = _municipios.firstWhere(
      (item) => item.nome == cidadeEscolhida,
      orElse: () => const MunicipioResumo(nome: '', uf: null),
    );

    setState(() {
      _municipioSelecionado = cidadeEscolhida;
      _bairroSelecionado = bairroEscolhido;
    });

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NovoEstudoPage(
          distribuidora: _distribuidoraSelecionada ?? '',
          municipio: cidadeEscolhida,
          bairro: bairroEscolhido,
          uf: municipio.uf,
          areaKm2: 0,
          pontosArea: const [],
        ),
      ),
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
    return _municipios.map((municipio) => municipio.nome).toList();
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

  Future<void> _abrirFiltroMunicipio() async {
    if (_municipios.isEmpty) await _carregarMunicipios();
    if (!mounted) return;

    final municipios = _municipiosDisponiveis;
    final bairrosPorCidade = <String, List<String>>{};

    for (final cidade in municipios) {
      bairrosPorCidade[cidade] =
          _todosAtivos
              .where((ativo) => ativo.municipio == cidade)
              .map((ativo) => ativo.bairro.trim())
              .where((bairro) => bairro.isNotEmpty && bairro != 'Não informado')
              .toSet()
              .toList()
            ..sort();
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CidadeBairroBottomSheet(
        cidades: municipios,
        bairrosPorCidade: bairrosPorCidade,
        ufPorCidade: {
          for (final municipio in _municipios) municipio.nome: municipio.uf,
        },
        cidadeSelecionada: _municipioSelecionado,
        bairroSelecionado: _bairroSelecionado,
        notFoundMessage: _municipiosCarregando
            ? 'Carregando cidades...'
            : 'Nenhuma cidade encontrada.',
        onProsseguir: (cidade, bairro) {
          setState(() {
            _municipioSelecionado = cidade;
            _bairroSelecionado = bairro;
          });
        },
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

  bool get _areaDesenhada => polygonPoints.length >= 3;

  void _cancelarArea() {
    setState(() => polygonPoints = []);
  }

  Future<void> _prosseguirArea() async {
    final uf = _municipios
        .where((municipio) => municipio.nome == _municipioSelecionado)
        .firstOrNull
        ?.uf;
    final estudoCriado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NovoEstudoPage(
          distribuidora: _distribuidoraSelecionada ?? '',
          municipio: _municipioSelecionado,
          bairro: _bairroSelecionado,
          uf: uf,
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
        child: _buildIconeMarcador(ativo, isSelected, cor),
      );

      _markerAtivoMap[marker] = ativo;
      return marker;
    }).toList();
  }

  Widget _buildIconeMarcador(AtivoBdgd ativo, bool isSelected, Color cor) {
    return GestureDetector(
      onTap: () => _selecionarAtivo(ativo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.surfaceCardLight
              : AppColors.surfaceCard,
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
              MarkerLayer(markers: marcadores),
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
