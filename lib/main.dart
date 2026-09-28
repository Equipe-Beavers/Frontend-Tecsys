import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_tecsys/pages/estudos_page.dart';
import 'package:frontend_tecsys/pages/map_page.dart';
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
  static const int _totalAbas = 2;
  static const int _abaEstudos = 1;

  final GlobalKey<EstudosPageState> _estudosPageKey =
      GlobalKey<EstudosPageState>();

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
          children: [
            const MapPage(),
            EstudosPage(key: _estudosPageKey),
          ],
        ),
        bottomNavigationBar: Navbar(
          currentIndex: _abaSelecionada,
          onTap: (index) {
            if (index >= _totalAbas) return;
            setState(() {
              _abaSelecionada = index;
            });
            if (index == _abaEstudos) {
              _estudosPageKey.currentState?.recarregar();
            }
          },
        ),
      ),
    );
  }
}
