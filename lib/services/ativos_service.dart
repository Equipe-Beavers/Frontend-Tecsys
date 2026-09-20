import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class SegmentoRede {
  final String id;
  final TipoAtivo tipo;
  final List<LatLng> pontos;
  final Color cor;
  final double largura;

  const SegmentoRede({
    required this.id,
    required this.tipo,
    required this.pontos,
    required this.cor,
    this.largura = 2.5,
  });
}

class AtivosService {
  /// Retorna os ativos georreferenciados da região de estudo
  Future<List<AtivoBdgd>> getAtivos() async {
    // Simula delay de rede instantâneo ou rápido
    await Future.delayed(const Duration(milliseconds: 50));

    return [
      // Ativo principal exatamente como demonstrado no Figma (Tela 2)
      const AtivoBdgd(
        id: '1548123',
        codId: 'PON-381-1548123',
        tipo: TipoAtivo.poste,
        latitude: -18.9112,
        longitude: -48.2619,
        statusOperacional: 'Em operação',
        material: 'Concreto - Duplo T',
        esforcoTracao: '600 daN - 11 m',
        ordemImobilizacao: 'OI-2023-554812',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10417',
        municipio: 'Uberlândia - MG',
        distribuidora: 'CEMIG Distribuição',
      ),

      // Postes adjacentes ao longo da rede
      const AtivoBdgd(
        id: '1548124',
        codId: 'PON-381-1548124',
        tipo: TipoAtivo.poste,
        latitude: -18.9125,
        longitude: -48.2635,
        statusOperacional: 'Em operação',
        material: 'Concreto - Circular',
        esforcoTracao: '400 daN - 10 m',
        ordemImobilizacao: 'OI-2023-554813',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10418',
        municipio: 'Uberlândia - MG',
      ),
      const AtivoBdgd(
        id: '1548125',
        codId: 'PON-381-1548125',
        tipo: TipoAtivo.poste,
        latitude: -18.9098,
        longitude: -48.2602,
        statusOperacional: 'Em operação',
        material: 'Concreto - Duplo T',
        esforcoTracao: '600 daN - 11 m',
        ordemImobilizacao: 'OI-2023-554814',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10419',
        municipio: 'Uberlândia - MG',
      ),
      const AtivoBdgd(
        id: '1548126',
        codId: 'PON-381-1548126',
        tipo: TipoAtivo.poste,
        latitude: -18.9140,
        longitude: -48.2650,
        statusOperacional: 'Em operação',
        material: 'Madeira Tratada',
        esforcoTracao: '300 daN - 9 m',
        ordemImobilizacao: 'OI-2023-554815',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10420',
        municipio: 'Uberlândia - MG',
      ),
      const AtivoBdgd(
        id: '1548127',
        codId: 'PON-381-1548127',
        tipo: TipoAtivo.poste,
        latitude: -18.9085,
        longitude: -48.2588,
        statusOperacional: 'Em operação',
        material: 'Concreto - Duplo T',
        esforcoTracao: '600 daN - 11 m',
        ordemImobilizacao: 'OI-2023-554816',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10421',
        municipio: 'Uberlândia - MG',
      ),
      const AtivoBdgd(
        id: '1548128',
        codId: 'PON-381-1548128',
        tipo: TipoAtivo.poste,
        latitude: -18.9152,
        longitude: -48.2670,
        statusOperacional: 'Em operação',
        material: 'Concreto - Circular',
        esforcoTracao: '400 daN - 10 m',
        ordemImobilizacao: 'OI-2023-554817',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10422',
        municipio: 'Uberlândia - MG',
      ),

      // Subestações
      const AtivoBdgd(
        id: 'SUB-01',
        codId: 'SUB-381-0001',
        tipo: TipoAtivo.subestacao,
        latitude: -18.9050,
        longitude: -48.2550,
        statusOperacional: 'Em operação',
        material: 'Alvenaria / Blindada',
        esforcoTracao: 'N/A',
        ordemImobilizacao: 'OI-2020-001240',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 0001',
        municipio: 'Uberlândia - MG',
      ),

      // Transformadores
      const AtivoBdgd(
        id: 'TR-102',
        codId: 'TRD-381-00102',
        tipo: TipoAtivo.transformador,
        latitude: -18.9112,
        longitude: -48.2619,
        statusOperacional: 'Em operação',
        material: 'Óleo Mineral - 75 kVA',
        esforcoTracao: 'N/A',
        ordemImobilizacao: 'OI-2022-77123',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10417',
        municipio: 'Uberlândia - MG',
      ),
      const AtivoBdgd(
        id: 'TR-103',
        codId: 'TRD-381-00103',
        tipo: TipoAtivo.transformador,
        latitude: -18.9140,
        longitude: -48.2650,
        statusOperacional: 'Em operação',
        material: 'Óleo Mineral - 112.5 kVA',
        esforcoTracao: 'N/A',
        ordemImobilizacao: 'OI-2022-77124',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10420',
        municipio: 'Uberlândia - MG',
      ),

      // Chaves Fusíveis / Corta-Circuito
      const AtivoBdgd(
        id: 'CF-201',
        codId: 'CHF-381-00201',
        tipo: TipoAtivo.chaveFusivel,
        latitude: -18.9075,
        longitude: -48.2575,
        statusOperacional: 'Em operação',
        material: 'Porcelana / Polimérica 15 kV',
        esforcoTracao: '100 A',
        ordemImobilizacao: 'OI-2021-33120',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10390',
        municipio: 'Uberlândia - MG',
      ),
      const AtivoBdgd(
        id: 'CF-202',
        codId: 'CHF-381-00202',
        tipo: TipoAtivo.chaveFusivel,
        latitude: -18.9130,
        longitude: -48.2640,
        statusOperacional: 'Em operação',
        material: 'Polimérica 15 kV',
        esforcoTracao: '100 A',
        ordemImobilizacao: 'OI-2021-33121',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10419',
        municipio: 'Uberlândia - MG',
      ),

      // Religadores
      const AtivoBdgd(
        id: 'RL-301',
        codId: 'REL-381-00301',
        tipo: TipoAtivo.religador,
        latitude: -18.9062,
        longitude: -48.2562,
        statusOperacional: 'Em operação',
        material: 'Vácuo / SF6 Microprocessado',
        esforcoTracao: '630 A - 12.5 kA',
        ordemImobilizacao: 'OI-2023-88912',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10385',
        municipio: 'Uberlândia - MG',
      ),

      // Seccionador Automático
      const AtivoBdgd(
        id: 'SA-401',
        codId: 'SEC-381-00401',
        tipo: TipoAtivo.seccionadorAutomatico,
        latitude: -18.9165,
        longitude: -48.2690,
        statusOperacional: 'Em operação',
        material: 'Polimérico 15 kV',
        esforcoTracao: '400 A',
        ordemImobilizacao: 'OI-2022-44129',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10435',
        municipio: 'Uberlândia - MG',
      ),

      // Regulador de Tensão
      const AtivoBdgd(
        id: 'REG-501',
        codId: 'REG-381-00501',
        tipo: TipoAtivo.reguladorTensao,
        latitude: -18.9175,
        longitude: -48.2710,
        statusOperacional: 'Em operação',
        material: 'Monofásico 15 kV - 32 degraus',
        esforcoTracao: '200 A',
        ordemImobilizacao: 'OI-2021-66231',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10440',
        municipio: 'Uberlândia - MG',
      ),

      // Banco de Capacitores
      const AtivoBdgd(
        id: 'BC-601',
        codId: 'CAP-381-00601',
        tipo: TipoAtivo.bancoCapacitores,
        latitude: -18.9185,
        longitude: -48.2730,
        statusOperacional: 'Em operação',
        material: 'Automático 600 kvar',
        esforcoTracao: '15 kV',
        ordemImobilizacao: 'OI-2020-55110',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        pontoAcesso: 'PAC 10450',
        municipio: 'Uberlândia - MG',
      ),
    ];
  }

  /// Retorna os segmentos de linhas da rede elétrica (MT, BT e Neutro)
  Future<List<SegmentoRede>> getSegmentosRede() async {
    return [
      // Tronco principal de Média Tensão (MT)
      const SegmentoRede(
        id: 'MT-TRONCO-01',
        tipo: TipoAtivo.redeMT,
        cor: AppColors.layerRedeMT,
        largura: 3.0,
        pontos: [
          LatLng(-18.9050, -48.2550), // Subestação
          LatLng(-18.9062, -48.2562), // Religador
          LatLng(-18.9075, -48.2575), // Chave Fusível
          LatLng(-18.9085, -48.2588), // Poste
          LatLng(-18.9098, -48.2602), // Poste
          LatLng(-18.9112, -48.2619), // Poste principal (Tela 2)
          LatLng(-18.9125, -48.2635), // Poste
          LatLng(-18.9140, -48.2650), // Poste + TR
          LatLng(-18.9152, -48.2670), // Poste
          LatLng(-18.9165, -48.2690), // Seccionador
          LatLng(-18.9175, -48.2710), // Regulador
        ],
      ),

      // Ramal de Baixa Tensão (BT)
      const SegmentoRede(
        id: 'BT-RAMAL-01',
        tipo: TipoAtivo.redeBT,
        cor: AppColors.layerRedeBT,
        largura: 2.0,
        pontos: [
          LatLng(-18.9112, -48.2619),
          LatLng(-18.9118, -48.2612),
          LatLng(-18.9124, -48.2605),
          LatLng(-18.9130, -48.2598),
        ],
      ),

      const SegmentoRede(
        id: 'BT-RAMAL-02',
        tipo: TipoAtivo.redeBT,
        cor: AppColors.layerRedeBT,
        largura: 2.0,
        pontos: [
          LatLng(-18.9140, -48.2650),
          LatLng(-18.9148, -48.2642),
          LatLng(-18.9155, -48.2634),
        ],
      ),

      // Condutor Neutro
      const SegmentoRede(
        id: 'NEUTRO-01',
        tipo: TipoAtivo.redeNeutro,
        cor: AppColors.layerNeutro,
        largura: 1.5,
        pontos: [
          LatLng(-18.9050, -48.2550),
          LatLng(-18.9085, -48.2588),
          LatLng(-18.9112, -48.2619),
          LatLng(-18.9152, -48.2670),
        ],
      ),
    ];
  }
}

