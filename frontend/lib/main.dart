import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/artlog_api.dart';
import 'auth/auth_session.dart';
import 'auth/firebase_session.dart';
import 'config.dart';
import 'state.dart';
import 'ui/design.dart';
import 'ui/shell.dart';
import 'pages/gallery_page.dart';
import 'pages/detail_page.dart';
import 'pages/artists_page.dart';
import 'pages/library_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig();
  AuthSession? session;
  String? authError;
  if (config.firebaseAuth) {
    try {
      session = await FirebaseSession.initialize(config.firebase);
    } catch (e) {
      authError = e is AuthFailure
          ? e.message
          : '로그인 서비스에 연결하지 못했어요. 새로고침해 다시 시도해 주세요.';
    }
  }
  final state = ArtlogState(
    config,
    ArtlogApi(baseUrl: config.apiBaseUrl),
    await SharedPreferences.getInstance(),
    session: session,
    authError: authError,
  );
  LicenseRegistry.addLicense(() async* {
    final licenses =
        jsonDecode(await rootBundle.loadString('assets/fonts/licenses.json'))
            as Map<String, dynamic>;
    for (final entry in licenses.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], entry.value['license'] as String);
    }
  });
  runApp(ArtlogApp(state: state));
  unawaited(state.load());
}

class ArtlogApp extends StatefulWidget {
  const ArtlogApp({
    super.key,
    required this.state,
    this.initialLocation = '/gallery',
  });
  final ArtlogState state;
  final String initialLocation;
  @override
  State<ArtlogApp> createState() => _ArtlogAppState();
}

class _ArtlogAppState extends State<ArtlogApp> {
  late final GoRouter router;
  SemanticsHandle? semantics;
  @override
  void initState() {
    super.initState();
    if (kIsWeb) semantics = SemanticsBinding.instance.ensureSemantics();
    router = GoRouter(
      initialLocation: widget.initialLocation,
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/gallery'),
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(path: '/gallery', builder: (_, _) => const GalleryPage()),
            GoRoute(
              path: '/artwork/:id',
              builder: (_, state) => DetailPage(
                key: ValueKey(state.pathParameters['id']),
                id: state.pathParameters['id']!,
              ),
            ),
            GoRoute(path: '/artists', builder: (_, _) => const ArtistsPage()),
            GoRoute(
              path: '/artist/:id',
              builder: (_, state) => ArtistDetailPage(
                key: ValueKey(state.pathParameters['id']),
                id: state.pathParameters['id']!,
              ),
            ),
            GoRoute(path: '/library', builder: (_, _) => const LibraryPage()),
          ],
        ),
      ],
      errorBuilder: (context, _) => Scaffold(
        body: EmptyView(
          '이 페이지를 찾을 수 없어요.',
          action: ArtButton('작품 둘러보기', onTap: () => context.go('/gallery')),
        ),
      ),
    );
  }

  @override
  void dispose() {
    router.dispose();
    semantics?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ArtlogScope(
    state: widget.state,
    child: MaterialApp.router(
      title: '아트로그 · 일상에 한 점',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: const Locale('ko'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ko'), Locale('en')],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: paper,
        fontFamily: 'NotoSansKR',
        colorScheme: ColorScheme.fromSeed(seedColor: green, surface: paper),
        dividerColor: line,
        textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'NotoSansKR',
          bodyColor: ink,
          displayColor: ink,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: line),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: green),
        ),
      ),
    ),
  );
}
