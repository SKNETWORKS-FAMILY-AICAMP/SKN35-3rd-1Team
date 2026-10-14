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
import 'ui/app_theme.dart';
import 'ui/shell.dart';
import 'pages/gallery_page.dart';
import 'pages/detail_page.dart';
import 'pages/artists_page.dart';
import 'pages/feed_page.dart';
import 'pages/artworks_page.dart';
import 'pages/community_page.dart';
import 'pages/collection_page.dart';

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

// Direct page changes avoid compositing the artwork behind incoming reading pages.
NoTransitionPage<void> _contentPage(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(
      key: state.pageKey,
      child: AppPage(key: ValueKey(state.uri.path), child: child),
    );

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
    // Collection pushes keep the originating profile tab in the back stack,
    // while the URL still identifies the collection for refresh and sharing.
    GoRouter.optionURLReflectsImperativeAPIs = true;
    router = GoRouter(
      initialLocation: widget.initialLocation,
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/gallery'),
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/gallery',
              pageBuilder: (_, state) =>
                  _contentPage(state, const GalleryPage()),
            ),
            GoRoute(
              path: '/artwork/:id',
              pageBuilder: (_, state) => _contentPage(
                state,
                DetailPage(
                  key: ValueKey(state.pathParameters['id']),
                  id: state.pathParameters['id']!,
                ),
              ),
            ),
            GoRoute(
              path: '/artworks',
              pageBuilder: (_, state) => _contentPage(
                state,
                ArtworksPage(
                  key: ValueKey(state.uri.queryParameters['view']),
                  initialView: state.uri.queryParameters['view'] ?? 'works',
                ),
              ),
            ),
            GoRoute(
              path: '/artists',
              redirect: (_, _) => '/artworks?view=artists',
            ),
            GoRoute(
              path: '/artist/:id',
              pageBuilder: (_, state) => _contentPage(
                state,
                ArtistDetailPage(
                  key: ValueKey(state.pathParameters['id']),
                  id: state.pathParameters['id']!,
                ),
              ),
            ),
            GoRoute(
              path: '/community',
              pageBuilder: (_, state) =>
                  _contentPage(state, const CommunityPage()),
            ),
            GoRoute(
              path: '/mypage',
              redirect: (_, state) =>
                  state.uri.queryParameters['tab'] == 'collections'
                  ? '/library?tab=collections'
                  : '/library',
            ),
            GoRoute(
              path: '/user/:id',
              pageBuilder: (_, state) => _contentPage(
                state,
                MemberPage(
                  key: ValueKey(state.pathParameters['id']),
                  id: state.pathParameters['id']!,
                ),
              ),
            ),
            GoRoute(
              path: '/collection/:id',
              pageBuilder: (_, state) => _contentPage(
                state,
                state.pathParameters['id'] == 'likes'
                    ? const LikedCollectionPage()
                    : CollectionPage(
                        key: ValueKey(state.pathParameters['id']),
                        id: state.pathParameters['id']!,
                      ),
              ),
            ),
            GoRoute(path: '/settings', redirect: (_, _) => '/library'),
            GoRoute(
              path: '/library',
              pageBuilder: (_, state) => _contentPage(
                state,
                MyFeedPage(
                  key: ValueKey(state.uri.query),
                  initialTab:
                      state.uri.queryParameters['tab'] ??
                      (state.uri.queryParameters['date'] != null
                          ? 'calendar'
                          : 'posts'),
                  initialDate: state.uri.queryParameters['date'],
                ),
              ),
            ),
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
      title: 'Docentalk · 일상에 한 점',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: const Locale('ko'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ko'), Locale('en')],
      theme: docentalkTheme(),
    ),
  );
}
