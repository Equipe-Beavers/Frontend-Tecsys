import 'package:flutter/material.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';

enum TipoIndicadorVisual {
  linha,
  ponto,
  quadrado,
  anel,
}

class ItemCamadaFiltro {
  final TipoAtivo tipo;
  final String titulo;
  final TipoIndicadorVisual indicadorVisual;
  final Color corIndicador;

  const ItemCamadaFiltro({
    required this.tipo,
    required this.titulo,
    required this.indicadorVisual,
    required this.corIndicador,
  });
}

class GrupoCamadasFiltro {
  final String titulo;
  final CategoriaAtivo categoria;
  final List<ItemCamadaFiltro> itens;

  const GrupoCamadasFiltro({
    required this.titulo,
    required this.categoria,
    required this.itens,
  });
}

class CatalogoCamadas {
  static List<GrupoCamadasFiltro> obterGrupos() {
    return [
      GrupoCamadasFiltro(
        titulo: 'REDE',
        categoria: CategoriaAtivo.rede,
        itens: [
          ItemCamadaFiltro(
            tipo: TipoAtivo.redeMT,
            titulo: 'Cabo de Média Tensão (MT)',
            indicadorVisual: TipoIndicadorVisual.linha,
            corIndicador: TipoAtivo.redeMT.cor,
          ),
          ItemCamadaFiltro(
            tipo: TipoAtivo.redeBT,
            titulo: 'Cabo de Baixa Tensão (BT)',
            indicadorVisual: TipoIndicadorVisual.linha,
            corIndicador: TipoAtivo.redeBT.cor,
          ),
          ItemCamadaFiltro(
            tipo: TipoAtivo.redeNeutro,
            titulo: 'Condutor Terminal / Neutro',
            indicadorVisual: TipoIndicadorVisual.linha,
            corIndicador: TipoAtivo.redeNeutro.cor,
          ),
        ],
      ),
      GrupoCamadasFiltro(
        titulo: 'ESTRUTURAS',
        categoria: CategoriaAtivo.estruturas,
        itens: [
          ItemCamadaFiltro(
            tipo: TipoAtivo.poste,
            titulo: 'Poste',
            indicadorVisual: TipoIndicadorVisual.ponto,
            corIndicador: TipoAtivo.poste.cor,
          ),
          ItemCamadaFiltro(
            tipo: TipoAtivo.transformador,
            titulo: 'Transformador de Distribuição',
            indicadorVisual: TipoIndicadorVisual.anel,
            corIndicador: TipoAtivo.transformador.cor,
          ),
          ItemCamadaFiltro(
            tipo: TipoAtivo.subestacao,
            titulo: 'Subestação',
            indicadorVisual: TipoIndicadorVisual.quadrado,
            corIndicador: TipoAtivo.subestacao.cor,
          ),
        ],
      ),
      GrupoCamadasFiltro(
        titulo: 'PROTEÇÃO E MANOBRA',
        categoria: CategoriaAtivo.protecaoManobra,
        itens: [
          ItemCamadaFiltro(
            tipo: TipoAtivo.chaveFusivel,
            titulo: 'Chave Fusível / Corta-Circuito',
            indicadorVisual: TipoIndicadorVisual.ponto,
            corIndicador: TipoAtivo.chaveFusivel.cor,
          ),
          ItemCamadaFiltro(
            tipo: TipoAtivo.chaveSeccionadora,
            titulo: 'Chave Seccionadora',
            indicadorVisual: TipoIndicadorVisual.ponto,
            corIndicador: TipoAtivo.chaveSeccionadora.cor,
          ),
          ItemCamadaFiltro(
            tipo: TipoAtivo.religador,
            titulo: 'Religador',
            indicadorVisual: TipoIndicadorVisual.ponto,
            corIndicador: TipoAtivo.religador.cor,
          ),
          ItemCamadaFiltro(
            tipo: TipoAtivo.seccionadorAutomatico,
            titulo: 'Seccionador Automático',
            indicadorVisual: TipoIndicadorVisual.ponto,
            corIndicador: TipoAtivo.seccionadorAutomatico.cor,
          ),
        ],
      ),
      GrupoCamadasFiltro(
        titulo: 'REGULAÇÃO',
        categoria: CategoriaAtivo.regulacao,
        itens: [
          ItemCamadaFiltro(
            tipo: TipoAtivo.reguladorTensao,
            titulo: 'Regulador de Tensão',
            indicadorVisual: TipoIndicadorVisual.ponto,
            corIndicador: TipoAtivo.reguladorTensao.cor,
          ),
          ItemCamadaFiltro(
            tipo: TipoAtivo.bancoCapacitores,
            titulo: 'Banco de Capacitores',
            indicadorVisual: TipoIndicadorVisual.ponto,
            corIndicador: TipoAtivo.bancoCapacitores.cor,
          ),
        ],
      ),
    ];
  }

  static Map<TipoAtivo, bool> obterEstadoInicialPadrao() {
    return {
      TipoAtivo.redeMT: true,
      TipoAtivo.redeBT: true,
      TipoAtivo.redeNeutro: false,
      TipoAtivo.poste: true,
      TipoAtivo.transformador: false,
      TipoAtivo.subestacao: true,
      TipoAtivo.chaveFusivel: true,
      TipoAtivo.chaveSeccionadora: false,
      TipoAtivo.religador: true,
      TipoAtivo.seccionadorAutomatico: true, // total 7 de 12 ativas como no Figma
      TipoAtivo.reguladorTensao: false,
      TipoAtivo.bancoCapacitores: false,
    };
  }
}

