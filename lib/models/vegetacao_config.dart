class VegetacaoClasse {
  const VegetacaoClasse({
    required this.codigo,
    required this.nome,
    required this.cor,
  });

  final int codigo;
  final String nome;
  final String cor;

  factory VegetacaoClasse.fromJson(Map<String, dynamic> json) {
    return VegetacaoClasse(
      codigo: (json['codigo'] as num?)?.toInt() ?? 0,
      nome: json['nome']?.toString() ?? '',
      cor: json['cor']?.toString() ?? '#808080',
    );
  }
}

class VegetacaoConfig {
  const VegetacaoConfig({
    required this.product,
    required this.baseUrl,
    required this.layer,
    required this.version,
    required this.format,
    required this.attribution,
    required this.classes,
    this.observacao,
  });

  final String product;
  final String baseUrl;
  final String layer;
  final String version;
  final String format;
  final String attribution;
  final List<VegetacaoClasse> classes;
  final String? observacao;

  factory VegetacaoConfig.fromJson(Map<String, dynamic> json) {
    final rawClasses = json['classes'];
    return VegetacaoConfig(
      product: json['product']?.toString() ?? 'ESA WorldCover 2021',
      baseUrl: json['baseUrl']?.toString() ?? 'https://services.terrascope.be/wms/v2?',
      layer: json['layer']?.toString() ?? 'WORLDCOVER_2021_MAP',
      version: json['version']?.toString() ?? '1.3.0',
      format: json['format']?.toString() ?? 'image/png',
      attribution: json['attribution']?.toString() ?? '© ESA WorldCover project 2021 © Contains modified Copernicus Sentinel data (2021) processed by ESA WorldCover consortium',
      classes: rawClasses is List
          ? rawClasses
              .whereType<Map>()
              .map((item) => VegetacaoClasse.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : <VegetacaoClasse>[],
      observacao: json['observacao']?.toString(),
    );
  }

  factory VegetacaoConfig.fallback() => const VegetacaoConfig(
        product: 'ESA WorldCover 2021',
        baseUrl: 'https://services.terrascope.be/wms/v2?',
        layer: 'WORLDCOVER_2021_MAP',
        version: '1.3.0',
        format: 'image/png',
        attribution: '© ESA WorldCover project 2021 © Contains modified Copernicus Sentinel data (2021) processed by ESA WorldCover consortium',
        classes: [
          VegetacaoClasse(codigo: 10, nome: 'Cobertura arbórea', cor: '#006400'),
          VegetacaoClasse(codigo: 20, nome: 'Arbustos', cor: '#FFBB22'),
          VegetacaoClasse(codigo: 30, nome: 'Gramíneas', cor: '#FFFF4C'),
          VegetacaoClasse(codigo: 40, nome: 'Cultivos', cor: '#F096FF'),
          VegetacaoClasse(codigo: 50, nome: 'Área construída', cor: '#FA0000'),
          VegetacaoClasse(codigo: 60, nome: 'Vegetação esparsa / solo exposto', cor: '#B4B4B4'),
          VegetacaoClasse(codigo: 70, nome: 'Neve e gelo', cor: '#F0F0F0'),
          VegetacaoClasse(codigo: 80, nome: 'Água permanente', cor: '#0064C8'),
          VegetacaoClasse(codigo: 90, nome: 'Área úmida herbácea', cor: '#0096A0'),
          VegetacaoClasse(codigo: 95, nome: 'Manguezal', cor: '#00CF75'),
          VegetacaoClasse(codigo: 100, nome: 'Musgos e líquens', cor: '#FAE6A0'),
        ],
        observacao: 'Camada visual de cobertura do solo. Não representa diretamente perda de sinal de RF.',
      );
}
