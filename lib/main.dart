import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend_tecsys/pages/map_page.dart';
import 'package:frontend_tecsys/pages/library_page.dart';
import 'package:frontend_tecsys/pages/studies_page.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/navbar.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'controllers/auth_controller.dart';
import 'pages/auth_page.dart';
import 'pages/profile_page.dart';
import 'pages/password_recovery_page.dart';
import 'services/session_store.dart';
import 'widgets/auth/auth_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  MapboxOptions.setAccessToken(mapboxToken);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.authController});
  final AuthController? authController;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthController _auth =
      widget.authController ??
      AuthController(store: const SecureSessionStore());
  final _navigator = GlobalKey<NavigatorState>();
  int? _sessionUserId;
  int _mapGeneration = 0;
  int _abaSelecionada = 0;
  bool _libraryOpened = false;
  bool _studiesOpened = false;
  bool _editingCriterion = false;

  @override
  void initState() {
    super.initState();
    _sessionUserId = _auth.user?.id;
    _auth.addListener(_sessionChanged);
    if (widget.authController == null) unawaited(_auth.restore());
  }

  void _sessionChanged() {
    if (!mounted) return;
    final id = _auth.user?.id;
    final changedAccount = _sessionUserId != null && id != _sessionUserId;
    setState(() {
      if (id != _sessionUserId) {
        _abaSelecionada = 0;
        _studiesOpened = false;
        _libraryOpened = false;
        _editingCriterion = false;
        if (changedAccount) _mapGeneration++;
      }
      _sessionUserId = id;
    });
    if (changedAccount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _auth.user?.id != id) return;
        final navigator = _navigator.currentState;
        navigator?.popUntil((route) => route.isFirst);
        if (id == null) {
          navigator?.push(
            MaterialPageRoute<void>(
              builder: (_) => AuthPage(controller: _auth),
            ),
          );
        }
      });
    }
  }

  Future<void> _selectTab(int index, BuildContext context) async {
    if (_editingCriterion) return;
    if ((index == 1 || index == 2) &&
        !await AuthScope.ensureSignedIn(context)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _abaSelecionada = index;
      if (index == 1) _studiesOpened = true;
      if (index == 2) _libraryOpened = true;
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_sessionChanged);
    if (widget.authController == null) _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geomash Tecsys',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigator,
      builder: (context, child) => AuthScope(controller: _auth, child: child!),
      routes: {
        '/cadastro': (_) => AuthPage(controller: _auth, register: true),
        '/login': (_) => AuthPage(controller: _auth),
      },
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri?.path == '/redefinir-senha') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => PasswordRecoveryPage(
              controller: _auth,
              token: uri!.queryParameters['token'] ?? '',
            ),
          );
        }
        return null;
      },
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
        builder: (context) => _auth.restoring
            ? const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Restaurando sessão',
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, box) {
                  final desktop = box.maxWidth >= 900;
                  return Scaffold(
                    body: SafeArea(
                      child: Row(
                        children: [
                          Offstage(
                            offstage: !desktop,
                            child: Container(
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
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 28,
                                    ),
                                    child: Row(
                                      children: [
                                        Image.asset(
                                          'assets/images/logo_geomash.png',
                                          width: 24,
                                          height: 24,
                                          semanticLabel: 'Símbolo da Geomash',
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
                                  const Divider(
                                    height: 1,
                                    color: AppColors.border,
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      24,
                                      24,
                                      24,
                                      12,
                                    ),
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
                                    (
                                      2,
                                      Icons.description_outlined,
                                      'Biblioteca',
                                    ),
                                    (3, Icons.person_outline, 'Perfil'),
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 3,
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: ListTile(
                                          enabled: !_editingCriterion,
                                          selected: _abaSelecionada == item.$1,
                                          selectedColor: AppColors.primaryLime,
                                          selectedTileColor: AppColors
                                              .primaryLime
                                              .withValues(alpha: .12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              9,
                                            ),
                                          ),
                                          leading: Icon(item.$2, size: 20),
                                          title: Text(
                                            item.$3,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          onTap: () =>
                                              _selectTab(item.$1, context),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: IndexedStack(
                              index: _abaSelecionada,
                              children: [
                                MapPage(key: ValueKey(_mapGeneration)),
                                if (_studiesOpened && _auth.user != null)
                                  StudiesPage(
                                    userId: _auth.user!.id,
                                    key: ValueKey('studies-${_auth.user!.id}'),
                                    isActive: _abaSelecionada == 1,
                                  )
                                else
                                  const SizedBox.shrink(),
                                if (_libraryOpened && _auth.user != null)
                                  CriteriaLibraryPage(
                                    userId: _auth.user!.id,
                                    key: ValueKey('library-${_auth.user!.id}'),
                                    onEditingChanged: (editing) => setState(
                                      () => _editingCriterion = editing,
                                    ),
                                  )
                                else
                                  const SizedBox.shrink(),
                                ProfilePage(controller: _auth),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    bottomNavigationBar: Offstage(
                      offstage: desktop || _editingCriterion,
                      child: SafeArea(
                        top: false,
                        child: Navbar(
                          currentIndex: _abaSelecionada,
                          onTap: (index) => _selectTab(index, context),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
