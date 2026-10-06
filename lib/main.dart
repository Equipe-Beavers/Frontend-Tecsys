import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_tecsys/pages/map_page.dart';
import 'package:frontend_tecsys/pages/criteria_library_page.dart';
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
  bool _libraryOpened = false;
  bool _editingCriterion = false;

  void _selectTab(int index, BuildContext context) {
    if (_editingCriterion) return;
    if (index == 1 || index == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta seção ainda não está disponível.')),
      );
      return;
    }
    setState(() {
      _abaSelecionada = index;
      if (index == 2) _libraryOpened = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geomash Tecsys',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.surfaceBackground,
        primaryColor: AppColors.primaryLime,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryLime,
          secondary: AppColors.secondaryTeal,
          surface: AppColors.surfaceCardLight,
        ),
        fontFamily: 'sans-serif',
      ),
      home: Builder(
        builder: (context) => LayoutBuilder(
          builder: (context, box) {
            final desktop = box.maxWidth >= 900;
            return Scaffold(
              body: SafeArea(
                child: Row(
                  children: [
                    if (desktop)
                      Container(
                        width: 200,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceCardLight,
                          border: Border(
                            right: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 28,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.sensors,
                                    color: AppColors.primaryLime,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'GEOMASH',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: AppColors.border),
                            const Padding(
                              padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
                              child: Text(
                                'NAVEGAÇÃO',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            for (final item in [
                              (0, Icons.home_outlined, 'Início'),
                              (1, Icons.layers_outlined, 'Estudos'),
                              (2, Icons.description_outlined, 'Biblioteca'),
                              (3, Icons.person_outline, 'Perfil'),
                            ])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 3,
                                ),
                                child: ListTile(
                                  enabled: !_editingCriterion,
                                  selected: _abaSelecionada == item.$1,
                                  selectedColor: AppColors.primaryLime,
                                  selectedTileColor: AppColors.primaryLime
                                      .withValues(alpha: .12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  leading: Icon(item.$2, size: 20),
                                  title: Text(
                                    item.$3,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  onTap: () => _selectTab(item.$1, context),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: IndexedStack(
                        index: _abaSelecionada == 2 ? 1 : 0,
                        children: [
                          const MapPage(),
                          if (_libraryOpened)
                            CriteriaLibraryPage(
                              onEditingChanged: (editing) =>
                                  setState(() => _editingCriterion = editing),
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: desktop || _editingCriterion
                  ? null
                  : SafeArea(
                      top: false,
                      child: Navbar(
                        currentIndex: _abaSelecionada,
                        onTap: (index) => _selectTab(index, context),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}
