import 'package:flutter/material.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

enum CategoriaAtivo {
  rede,
  estruturas,
  protecaoManobra,
  regulacao,
}

enum TipoAtivo {
  // Estruturas
  poste,
  transformador,
  subestacao,

  // Proteção e Manobra
  chaveFusivel,
  chaveSeccionadora,
  religador,
  seccionadorAutomatico,

  // Regulação
  reguladorTensao,
  bancoCapacitores,

  // Rede (Polylines)
  redeMT,
  redeBT,
  redeNeutro,
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
      case TipoAtivo.redeMT:
        return 'Cabo de Média Tensão (MT)';
      case TipoAtivo.redeBT:
        return 'Cabo de Baixa Tensão (BT)';
      case TipoAtivo.redeNeutro:
        return 'Condutor Terminal / Neutro';
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
      case TipoAtivo.redeMT:
        return AppColors.layerRedeMT;
      case TipoAtivo.redeBT:
        return AppColors.layerRedeBT;
      case TipoAtivo.redeNeutro:
        return AppColors.layerNeutro;
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
      case TipoAtivo.redeMT:
      case TipoAtivo.redeBT:
      case TipoAtivo.redeNeutro:
        return Icons.linear_scale;
    }
  }

  CategoriaAtivo get categoria {
    switch (this) {
      case TipoAtivo.redeMT:
      case TipoAtivo.redeBT:
      case TipoAtivo.redeNeutro:
        return CategoriaAtivo.rede;
      case TipoAtivo.poste:
      case TipoAtivo.transformador:
      case TipoAtivo.subestacao:
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
}

class AtivoBdgd {
  final String id;
  final String codId;
  final TipoAtivo tipo;
  final double latitude;
  final double longitude;
  final String statusOperacional; // ex: 'Em operação'
  final String material;          // ex: 'Concreto - Duplo T'
  final String esforcoTracao;     // ex: '600 daN - 11 m'
  final String ordemImobilizacao; // ex: 'OI-2023-554812'
  final String situacaoAtivo;     // ex: 'Ativo - sem restrições'
  final String subestacaoConectada;// ex: 'SE Boa Vista - 138 kV'
  final String pontoAcesso;       // ex: 'PAC 10417'
  final String municipio;         // ex: 'Uberlândia - MG'
  final String distribuidora;     // ex: 'CEMIG Distribuição'

  const AtivoBdgd({
    required this.id,
    required this.codId,
    required this.tipo,
    required this.latitude,
    required this.longitude,
    this.statusOperacional = 'Em operação',
    this.material = 'Concreto - Duplo T',
    this.esforcoTracao = '600 daN - 11 m',
    this.ordemImobilizacao = 'OI-2023-554812',
    this.situacaoAtivo = 'Ativo - sem restrições',
    this.subestacaoConectada = 'SE Boa Vista - 138 kV',
    this.pontoAcesso = 'PAC 10417',
    this.municipio = 'Uberlândia - MG',
    this.distribuidora = 'CEMIG Distribuição',
  });
}

