import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_tecsys/pages/map_page.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/appbar.dart';
import 'package:frontend_tecsys/widgets/navbar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _abaSelecionada = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geomash Tecsys',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.surfaceBackground,
        primaryColor: AppColors.primaryLime,
        fontFamily: 'sans-serif',
      ),
      home: Scaffold(
        appBar: const PreferredSize(
          preferredSize: Size.fromHeight(24),
          child: AppBarTime(),
        ),
        body: IndexedStack(
          index: _abaSelecionada,
          children: [
            const MapPage(),
            _buildPlaceholderPagina('Estudos e Cenários', Icons.layers_outlined),
            _buildPlaceholderPagina('Biblioteca de Itens', Icons.description_outlined),
            _buildPlaceholderPagina('Perfil do Usuário', Icons.person_outline),
          ],
        ),
        bottomNavigationBar: Navbar(
          currentIndex: _abaSelecionada,
          onTap: (index) {
            setState(() {
              _abaSelecionada = index;
            });
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholderPagina(String titulo, IconData icone) {
    return Container(
      color: AppColors.surfaceBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 48, color: AppColors.primaryLime.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textWhite,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Módulo em desenvolvimento nas próximas etapas',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
