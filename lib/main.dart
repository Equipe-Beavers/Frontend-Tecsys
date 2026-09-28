import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_tecsys/pages/map_page.dart';
import 'package:frontend_tecsys/pages/estudos_page.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
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
        body: IndexedStack(
          index: _abaSelecionada,
          children: const [
            MapPage(),
            EstudosPage(),
            _AbaIndisponivel(titulo: 'Biblioteca'),
            _AbaIndisponivel(titulo: 'Perfil'),
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
}

class _AbaIndisponivel extends StatelessWidget {
  const _AbaIndisponivel({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBackground,
        title: Text(
          titulo,
          style: const TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: const Center(
        child: Text('Em breve', style: TextStyle(color: AppColors.textMuted)),
      ),
    );
  }
}
