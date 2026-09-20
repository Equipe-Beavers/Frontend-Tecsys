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
  final MapController _mapController = MapController();
  final AtivosService _ativosService = AtivosService();

  // Coordenadas iniciais baseadas no protótipo (Uberlândia - MG / CEMIG)
  final LatLng _centroInicial = const LatLng(-18.9112, -48.2619);
  double _currentZoom = 15.2;

  List<AtivoBdgd> _todosAtivos = [];
  List<SegmentoRede> _segmentosRede = [];
  Map<TipoAtivo, bool> _camadasAtivas = CatalogoCamadas.obterEstadoInicialPadrao();
  AtivoBdgd? _ativoSelecionado;
  bool _carregando = true;

  final Map<Marker, AtivoBdgd> _markerAtivoMap = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    final ativos = await _ativosService.getAtivos();
    final segmentos = await _ativosService.getSegmentosRede();

    if (mounted) {
      setState(() {
        _todosAtivos = ativos;
        _segmentosRede = segmentos;
        _carregando = false;
      });
    }
  }

  int get _totalCamadasAtivas =>
      _camadasAtivas.values.where((ativa) => ativa).length;

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
    setState(() {
      _currentZoom = 15.2;
      _mapController.move(_centroInicial, _currentZoom);
    });
  }

  void _abrirPainelCamadas() {
    LayerFilterModal.exibir(
      context,
      camadasAtivas: _camadasAtivas,
      onSalvarFiltro: (novasCamadas) {
        setState(() {
          _camadasAtivas = novasCamadas;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Camadas atualizadas: $_totalCamadasAtivas de ${_camadasAtivas.length} ativas',
              style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
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

    final ativosFiltrados = _todosAtivos.where((a) {
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
            color: (isSelected ? AppColors.primaryLime : cor).withValues(alpha: isSelected ? 0.6 : 0.3),
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

  List<Polyline> _gerarLinhasRede() {
    final polylines = <Polyline>[];

    for (final segmento in _segmentosRede) {
      final isAtiva = _camadasAtivas[segmento.tipo] ?? false;
      if (isAtiva) {
        polylines.add(
          Polyline(
            points: segmento.pontos,
            color: segmento.cor,
            strokeWidth: segmento.largura,
          ),
        );
      }
    }

    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    final marcadores = _gerarMarcadores();
    final polylines = _gerarLinhasRede();

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: Stack(
        children: [
          // 1. Mapa Interativo com OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centroInicial,
              initialZoom: _currentZoom,
              minZoom: 4.0,
              maxZoom: 19.0,
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

              // Camada de Redes Elétricas (Polylines MT, BT, Neutro)
              PolylineLayer(polylines: polylines),

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
                            color: AppColors.primaryLime.withValues(alpha: 0.35),
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
                      const Expanded(
                        child: Text(
                          'Buscar alimentador ou município',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
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

                // Chips de Filtro Rápido (381 - CEMIG ▼ | Cidade / bairro ▼)
                Row(
                  children: [
                    _buildChipFiltro(
                      label: '381 - CEMIG',
                      destaque: true,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Distribuidora ativa: CEMIG (381)'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildChipFiltro(
                      label: 'Cidade / bairro',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Região: Uberlândia - MG'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
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
                      style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
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
          if (_carregando)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryLime,
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
            color: destaque ? AppColors.primaryLime.withValues(alpha: 0.5) : AppColors.border,
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
