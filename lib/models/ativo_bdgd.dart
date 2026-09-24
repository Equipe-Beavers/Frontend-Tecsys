import 'package:flutter/material.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

enum CategoriaAtivo { estruturas, protecaoManobra, regulacao }

enum TipoAtivo {
  // Estruturas
  poste,
  transformador,
  subestacao,
  dispositivo,

  // Proteção e Manobra
  chaveFusivel,
  chaveSeccionadora,
  religador,
  seccionadorAutomatico,

  // Regulação
  reguladorTensao,
  bancoCapacitores,
}

extension TipoAtivoExtension on TipoAtivo {
  String get label {
    switch (this) {
      case TipoAtivo.poste:
        return 'Poste';
      case TipoAtivo.transformador:
        return 'Transformador de Distribuição';
      case TipoAtivo.subestacao:
        return 'Subestação';
      case TipoAtivo.dispositivo:
        return 'Dispositivo';
      case TipoAtivo.chaveFusivel:
        return 'Chave Fusível / Corta-Circuito';
      case TipoAtivo.chaveSeccionadora:
        return 'Chave Seccionadora';
      case TipoAtivo.religador:
        return 'Religador';
      case TipoAtivo.seccionadorAutomatico:
        return 'Seccionador Automático';
      case TipoAtivo.reguladorTensao:
        return 'Regulador de Tensão';
      case TipoAtivo.bancoCapacitores:
        return 'Banco de Capacitores';
    }
  }

  Color get cor {
    switch (this) {
      case TipoAtivo.poste:
        return AppColors.layerPoste;
      case TipoAtivo.transformador:
        return AppColors.layerTransformador;
      case TipoAtivo.subestacao:
        return AppColors.layerSubestacao;
      case TipoAtivo.dispositivo:
        return AppColors.secondaryTeal;
      case TipoAtivo.chaveFusivel:
        return AppColors.layerChaveFusivel;
      case TipoAtivo.chaveSeccionadora:
        return AppColors.layerChaveSeccionadora;
      case TipoAtivo.religador:
        return AppColors.layerReligador;
      case TipoAtivo.seccionadorAutomatico:
        return AppColors.layerSeccionador;
      case TipoAtivo.reguladorTensao:
        return AppColors.layerRegulador;
      case TipoAtivo.bancoCapacitores:
        return AppColors.layerBancoCapacitores;
    }
  }

  IconData get icone {
    switch (this) {
      case TipoAtivo.poste:
        return Icons.location_pin;
      case TipoAtivo.transformador:
        return Icons.offline_bolt;
      case TipoAtivo.subestacao:
        return Icons.business;
      case TipoAtivo.dispositivo:
        return Icons.electrical_services;
      case TipoAtivo.chaveFusivel:
        return Icons.electrical_services;
      case TipoAtivo.chaveSeccionadora:
        return Icons.toggle_on;
      case TipoAtivo.religador:
        return Icons.autorenew;
      case TipoAtivo.seccionadorAutomatico:
        return Icons.power_settings_new;
      case TipoAtivo.reguladorTensao:
        return Icons.tune;
      case TipoAtivo.bancoCapacitores:
        return Icons.battery_charging_full;
    }
  }

  CategoriaAtivo get categoria {
    switch (this) {
      case TipoAtivo.poste:
      case TipoAtivo.transformador:
      case TipoAtivo.subestacao:
      case TipoAtivo.dispositivo:
        return CategoriaAtivo.estruturas;
      case TipoAtivo.chaveFusivel:
      case TipoAtivo.chaveSeccionadora:
      case TipoAtivo.religador:
      case TipoAtivo.seccionadorAutomatico:
        return CategoriaAtivo.protecaoManobra;
      case TipoAtivo.reguladorTensao:
      case TipoAtivo.bancoCapacitores:
        return CategoriaAtivo.regulacao;
    }
  }

  String get apiValue {
    switch (this) {
      case TipoAtivo.poste:
        return 'POSTE';
      case TipoAtivo.transformador:
        return 'TRANSFORMADOR';
      case TipoAtivo.subestacao:
        return 'SUBESTACAO';
      case TipoAtivo.dispositivo:
        return 'DISPOSITIVO';
      case TipoAtivo.chaveFusivel:
        return 'CHAVE_FUSIVEL';
      case TipoAtivo.chaveSeccionadora:
        return 'CHAVE_SECCIONADORA';
      case TipoAtivo.religador:
        return 'RELIGADOR';
      case TipoAtivo.seccionadorAutomatico:
        return 'SECCIONADOR_AUTOMATICO';
      case TipoAtivo.reguladorTensao:
        return 'REGULADOR_TENSAO';
      case TipoAtivo.bancoCapacitores:
        return 'BANCO_CAPACITORES';
    }
  }
}

class AtivoBdgd {
  final String id;
  final String codId;
  final TipoAtivo tipo;
  final double latitude;
  final double longitude;
  final String statusOperacional; // ex: 'AT1' / 'EM OPERACAO'
  final String material; // ex: 'CQ'
  final String esforcoTracao; // ex: '7'
  final String altura; // ex: '13'
  final String potenciaNominal; // ex: '37,5'
  final String situacaoAtivo;
  final String subestacaoConectada; // ex: 'DMBE'
  final String municipio;
  final String bairro;
  final String distribuidora; // ex: 'Enel SP'
  final int? tipoDispositivoId;
  final String? tipoDispositivoNome;
  final String? tipoDispositivoCategoria;

  const AtivoBdgd({
    required this.id,
    required this.codId,
    required this.tipo,
    required this.latitude,
    required this.longitude,
    this.statusOperacional = 'Não informado',
    this.material = 'Não informado',
    this.esforcoTracao = 'Não informado',
    this.altura = 'Não informado',
    this.potenciaNominal = 'Não informado',
    this.situacaoAtivo = 'Não informado',
    this.subestacaoConectada = 'Não informado',
    this.municipio = 'Não informado',
    this.bairro = 'Não informado',
    this.distribuidora = 'Não informada',
    this.tipoDispositivoId,
    this.tipoDispositivoNome,
    this.tipoDispositivoCategoria,
  });

  factory AtivoBdgd.fromJson(Map<String, dynamic> json) {
    final atributos = _asMap(json['atributos']);
    final tipo = _tipoFromApi(json['tipo']);

    return AtivoBdgd(
      id: _asString(json['id']),
      codId: _asString(json['codId'], fallback: _asString(json['id'])),
      tipo: tipo,
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      municipio: _asString(json['municipio'], fallback: 'Não informado'),
      bairro: _asString(json['bairro'], fallback: 'Não informado'),
      tipoDispositivoId: _asInt(
        json['tipoDispositivoId'] ?? atributos['tip_unid'],
      ),
      tipoDispositivoNome: _asNullableString(
        json['tipoDispositivoNome'] ?? atributos['tipo_dispositivo_nome'],
      ),
      tipoDispositivoCategoria: _asNullableString(
        json['tipoDispositivoCategoria'] ??
            atributos['tipo_dispositivo_categoria'],
      ),
      material: _asString(
        atributos['material'] ?? atributos['mat'],
        fallback: 'Não informado',
      ),
      esforcoTracao: _asString(
        atributos['esforco'] ?? atributos['esf'],
        fallback: 'Não informado',
      ),
      altura: _asString(atributos['alt'], fallback: 'Não informado'),
      potenciaNominal: _asString(
        atributos['pot_nom'],
        fallback: 'Não informado',
      ),
      subestacaoConectada: _asString(
        atributos['subestacao'] ?? atributos['sub'],
        fallback: 'Não informado',
      ),
      statusOperacional: _asString(
        atributos['statusOperacional'] ??
            atributos['sitcont'] ??
            atributos['sit_ativ'],
        fallback: 'Não informado',
      ),
      situacaoAtivo: _asString(
        atributos['situacaoAtivo'] ??
            atributos['sitcont'] ??
            atributos['sit_ativ'],
        fallback: 'Não informado',
      ),
      distribuidora: _asString(json['distribuidora'], fallback: 'Não informada'),
    );
  }

  static TipoAtivo _tipoFromApi(dynamic value) {
    switch (value.toString().toUpperCase()) {
      case 'POSTE':
        return TipoAtivo.poste;
      case 'SUBESTACAO':
        return TipoAtivo.subestacao;
      case 'TRANSFORMADOR':
        return TipoAtivo.transformador;
      case 'CHAVE_FUSIVEL':
        return TipoAtivo.chaveFusivel;
      case 'CHAVE_SECCIONADORA':
        return TipoAtivo.chaveSeccionadora;
      case 'RELIGADOR':
        return TipoAtivo.religador;
      case 'SECCIONADOR_AUTOMATICO':
        return TipoAtivo.seccionadorAutomatico;
      case 'REGULADOR_TENSAO':
        return TipoAtivo.reguladorTensao;
      case 'BANCO_CAPACITORES':
        return TipoAtivo.bancoCapacitores;
      case 'DISPOSITIVO':
        return TipoAtivo.dispositivo;
      default:
        throw FormatException('Tipo de ativo não suportado: $value');
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static String _asString(dynamic value, {String fallback = ''}) =>
      value?.toString() ?? fallback;

  static String? _asNullableString(dynamic value) =>
      value?.toString();

  static int? _asInt(dynamic value) =>
      value is int ? value : int.tryParse('$value');

  static double _asDouble(dynamic value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null || !parsed.isFinite) {
      throw const FormatException('Coordenada de ativo inválida.');
    }
    return parsed;
  }
}
