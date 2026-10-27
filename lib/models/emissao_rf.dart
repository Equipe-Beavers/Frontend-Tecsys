
class EmissaoRf {
  const EmissaoRf({
    required this.id,
    required this.sourceKey,
    required this.fonteDados,
    required this.latitude,
    required this.longitude,
    this.uid,
    this.status,
    this.entidade,
    this.numServico,
    this.numEstacao,
    this.municipio,
    this.uf,
    this.emissao,
    this.tecnologia,
    this.tipoTecnologia,
    this.meioAcesso,
    this.frequenciaTxMHz,
    this.frequenciaRxMHz,
    this.potenciaTransmissorW,
    this.ganhoAntena,
    this.azimuteGraus,
    this.anguloMeiaPotenciaGraus,
    this.frenteCostas,
    this.elevacaoGraus,
    this.polarizacao,
    this.alturaAntenaM,
    this.tipoAntena,
    this.dataLicenciamento,
    this.dataValidade,
  });

  final String id;
  final String sourceKey;
  final String fonteDados;
  final String? uid;
  final String? status;
  final String? entidade;
  final String? numServico;
  final String? numEstacao;
  final String? municipio;
  final String? uf;
  final String? emissao;
  final String? tecnologia;
  final String? tipoTecnologia;
  final String? meioAcesso;
  final double? frequenciaTxMHz;
  final double? frequenciaRxMHz;
  final double? potenciaTransmissorW;
  final double? ganhoAntena;
  final double? azimuteGraus;
  final double? anguloMeiaPotenciaGraus;
  final double? frenteCostas;
  final double? elevacaoGraus;
  final String? polarizacao;
  final double? alturaAntenaM;
  final String? tipoAntena;
  final double latitude;
  final double longitude;
  final String? dataLicenciamento;
  final String? dataValidade;

  /// Só os registros com os parâmetros mínimos devem entrar num cálculo RF básico.
  bool get possuiParametrosBasicosRf =>
      frequenciaTxMHz != null && frequenciaTxMHz! > 0 &&
      potenciaTransmissorW != null && potenciaTransmissorW! > 0;

  factory EmissaoRf.fromJson(Map<String, dynamic> json) => EmissaoRf(
        id: json['id']?.toString() ?? '',
        sourceKey: json['sourceKey']?.toString() ?? '',
        fonteDados: json['fonteDados']?.toString() ?? '',
        uid: _asNullableString(json['uid']),
        status: _asNullableString(json['status']),
        entidade: _asNullableString(json['entidade']),
        numServico: _asNullableString(json['numServico']),
        numEstacao: _asNullableString(json['numEstacao']),
        municipio: _asNullableString(json['municipio']),
        uf: _asNullableString(json['uf']),
        emissao: _asNullableString(json['emissao']),
        tecnologia: _asNullableString(json['tecnologia']),
        tipoTecnologia: _asNullableString(json['tipoTecnologia']),
        meioAcesso: _asNullableString(json['meioAcesso']),
        frequenciaTxMHz: _asNullableDouble(json['frequenciaTxMHz']),
        frequenciaRxMHz: _asNullableDouble(json['frequenciaRxMHz']),
        potenciaTransmissorW: _asNullableDouble(json['potenciaTransmissorW']),
        ganhoAntena: _asNullableDouble(json['ganhoAntena']),
        azimuteGraus: _asNullableDouble(json['azimuteGraus']),
        anguloMeiaPotenciaGraus: _asNullableDouble(json['anguloMeiaPotenciaGraus']),
        frenteCostas: _asNullableDouble(json['frenteCostas']),
        elevacaoGraus: _asNullableDouble(json['elevacaoGraus']),
        polarizacao: _asNullableString(json['polarizacao']),
        alturaAntenaM: _asNullableDouble(json['alturaAntenaM']),
        tipoAntena: _asNullableString(json['tipoAntena']),
        latitude: _asDouble(json['latitude']),
        longitude: _asDouble(json['longitude']),
        dataLicenciamento: _asNullableString(json['dataLicenciamento']),
        dataValidade: _asNullableString(json['dataValidade']),
      );

  static double _asDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String? _asNullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
