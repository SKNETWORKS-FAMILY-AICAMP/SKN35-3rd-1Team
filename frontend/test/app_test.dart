import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/main.dart';
import 'package:artlog_web/models.dart';
import 'package:artlog_web/state.dart';
import 'package:artlog_web/ui/design.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'NotoSansKR': 'NotoSansKR',
      'NotoSerifKR': 'NotoSerifKR',
      'DMSans': 'DMSans',
      'Cormorant': 'CormorantGaramond',
    }.entries) {
      await (FontLoader(entry.key)
            ..addFont(rootBundle.load('assets/fonts/${entry.value}-400.ttf')))
          .load();
    }
  });
  Future<ArtlogState> demo() async {
    SharedPreferences.setMockInitialValues({});
    final state = ArtlogState(
      const AppConfig(demo: true, apiBaseUrl: 'http://localhost:8000'),
      ArtlogApi(baseUrl: 'http://localhost:8000'),
      await SharedPreferences.getInstance(),
    );
    await state.load();
    return state;
  }

  for (final width in [1440.0, 850.0, 768.0, 390.0, 320.0]) {
    for (final route in [
      '/gallery',
      '/artists',
      '/artwork/kim-hongdo-ssireum',
      '/artist/jeong-seon',
      '/library',
    ]) {
      testWidgets('$route fits ${width.toInt()}px without layout exceptions', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = (await tester.runAsync(demo))!;
        await tester.pumpWidget(
          ArtlogApp(state: state, initialLocation: route),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('© 2026 DOCENTALK'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      });
    }
  }

  testWidgets(
    'movement filtering and title search update the actual artwork list',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = (await tester.runAsync(demo))!;
      await tester.pumpWidget(
        ArtlogApp(state: state, initialLocation: '/artworks'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '조선 회화'));
      await tester.pumpAndSettle();
      expect(find.byType(ArtworkCard), findsNWidgets(2));
      await tester.enterText(
        find.byKey(const ValueKey('artworks-search')),
        '인왕',
      );
      await tester.pumpAndSettle();
      expect(find.byType(ArtworkCard), findsOneWidget);
      expect(find.text('인왕제색도'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('artworks-search')),
        '없는작품',
      );
      await tester.pumpAndSettle();
      expect(find.byType(ArtworkCard), findsNothing);
      expect(find.text('찾는 그림이 없어요.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  test(
    'demo likes, follows, date records and account-scoped notes persist',
    () async {
      final s = await demo();
      final id = s.artworks.first.id;
      await s.toggleLike(id);
      await s.toggleFollow(s.artists.first.id);
      await s.recordView(id);
      await s.recordView(id);
      expect(s.views[seoulDate()], [id]);
      await s.saveNote('2026-10-12', '오늘의 감상');
      await s.load();
      expect(s.likes, contains(id));
      expect(s.note('2026-10-12'), '오늘의 감상');
      s.dispose();
    },
  );

  test(
    'failed live mutations never commit preview data or favourite state',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient((_) async => http.Response('error', 500)),
      )..token = 'test-token';
      final s = ArtlogState(
        const AppConfig(demo: false),
        api,
        await SharedPreferences.getInstance(),
      );
      await s.load();
      expect(s.error, isNotNull);
      expect(s.artworks, isEmpty);
      await expectLater(s.toggleLike('42'), throwsA(isA<ApiException>()));
      expect(s.likes, isEmpty);
      expect(s.pendingLikes, isEmpty);
      await expectLater(s.toggleFollow('7'), throwsA(isA<ApiException>()));
      expect(s.follows, isEmpty);
      expect(s.pendingFollows, isEmpty);
      s.dispose();
    },
  );

  test(
    'saved server items outside the first catalog response remain visible',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(switch (r.url.path) {
              '/api/auth/login' => {'access_token': 'test-token'},
              '/api/me/likes' => [
                {'id': 42, 'title': '씨름', 'artist_id': 7},
              ],
              '/api/me/follows' => [
                {'id': 7, 'name': '김홍도'},
              ],
              _ => [],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      final s = ArtlogState(
        const AppConfig(demo: false),
        api,
        await SharedPreferences.getInstance(),
      );
      await s.load();
      await s.login('member@example.org', 'test-only');
      expect(s.likedWorks.single.title, '씨름');
      expect(s.followedArtists.single.name, '김홍도');
      s.logout();
      expect(s.likedWorks, isEmpty);
      expect(s.followedArtists, isEmpty);
      s.dispose();
    },
  );
}
