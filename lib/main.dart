import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_tecsys/pages/biblioteca_page.dart';
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
          index: _abaSelecionada == 1 ? 1 : (_abaSelecionada == 2 ? 2 : 0),
          children: [
            const MapPage(),
            if (_abaSelecionada == 1)
              const EstudosPage()
            else
              const SizedBox.shrink(),
            if (_abaSelecionada == 2)
              const BibliotecaPage()
            else
              const SizedBox.shrink(),
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
