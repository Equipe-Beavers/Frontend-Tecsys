import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/theme/app_colors.dart';

const fixture = <String, dynamic>{
  'id_criterio_instalacao': 7,
  'id_usuario': 1,
  'nome': 'Padrão urbano — Postes e SEs',
  'tipos_elementos_permitidos': ['POSTE', 'SUBESTACAO'],
  'tipos_elementos_proibidos': ['ESTRUTURAS_PROVISORIAS'],
  'requer_alimentacao_eletrica': true,
  'distancia_maxima_ativos_m': 1500,
  'limite_gateways': 40,
  'locais_autorizados': ['POSTE:123'],
};

Widget host(Widget child) => MaterialApp(
  theme: ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.surfaceBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryLime,
      secondary: AppColors.secondaryTeal,
    ),
  ),
  home: Scaffold(body: SafeArea(child: child)),
);

http.Response jsonResponse(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
