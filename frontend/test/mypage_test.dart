import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/main.dart';
import 'package:artlog_web/member_profile.dart';
import 'package:artlog_web/state.dart';
import 'connected_features_test.dart' show SessionFake;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<ArtlogState> demo({SessionFake? session}) async {
    final s = ArtlogState(
      AppConfig(
        demo: true,
        authProvider: session == null ? 'none' : 'firebase',
      ),
      ArtlogApi(baseUrl: 'https://example.org'),
      await SharedPreferences.getInstance(),
      session: session,
    );
    await s.load();
    return s;
  }

  test(
    'collections persist, deduplicate, edit, remove and remain UID scoped',
    () async {
      final auth = SessionFake(), s = await demo(session: auth);
      final c = await s.saveCollection('내 전시', '풍경'), art = s.artworks.first.id;
      await s.collect(c.id, art);
      await s.collect(c.id, art);
      expect((await s.collections()).single.count, 1);
      expect((await s.collectionItems(c.id)).items.single.id, art);
      await s.saveCollection('비 오는 전시', '새 소개', id: c.id);
      expect((await s.collections()).single.name, '비 오는 전시');
      auth.change('b');
      expect(await s.collections(), isEmpty);
      auth.change('a');
      expect((await s.collections()).single.count, 1);
      await s.collect(c.id, art, remove: true);
      expect((await s.collectionItems(c.id)).items, isEmpty);
      await s.deleteCollection(c.id);
      expect(await s.collections(), isEmpty);
      s.dispose();
      await auth.events.close();
    },
  );
  test('API contracts carry bearer token and owner-free payloads', () async {
    final observed = <http.Request>[];
    final api = ArtlogApi(
      baseUrl: 'https://example.org/api',
      client: MockClient((r) async {
        observed.add(r);
        if (r.url.path.endsWith('/profile')) {
          return http.Response(
            jsonEncode({
              'nickname': '나',
              'birth_date': '2000-01-02',
              'conversation_style': 'professional',
              'onboarding_completed': true,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (r.url.path.endsWith('/chat')) {
          return http.Response(
            jsonEncode({
              'answer': '담을까요?',
              'proposal': {
                'action': 'add',
                'collection_id': 1,
                'artwork_id': 2,
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'id': 1,
            'name': '컬렉션',
            'description': '',
            'artwork_count': 1,
            'previews': [],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..token = 'firebase-token';
    final p = await api.saveProfile(
      const MemberProfile(
        birthDate: '2000-01-02',
        explanationStyle: 'deep',
      ),
    );
    expect(p.conversationStyle, 'professional');
    await api.collect('1', '2');
    final reply = await api.collectionChat('그림을 담아줘', collectionId: '1');
    expect(reply.proposal!.artworkId, '2');
    expect(
      observed.every(
        (r) => r.headers['Authorization'] == 'Bearer firebase-token',
      ),
      true,
    );
    expect(observed[1].url.path, '/api/me/collections/1/items/2');
    expect(jsonDecode(observed[0].body)['user_id'], isNull);
    expect(
      jsonDecode(observed[0].body).containsKey('explanation_priorities'),
      false,
    );
    expect(jsonDecode(observed[2].body)['collection_id'], 1);
    api.close();
  });
  test(
    'old profile response cannot overwrite a newly signed-in account',
    () async {
      final pending = Completer<http.Response>(), session = SessionFake();
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient((r) async {
          if (r.url.path.endsWith('/profile')) {
            if (r.headers['Authorization'] == 'Bearer token-a') {
              return pending.future;
            }
            return http.Response(
              jsonEncode({
                'nickname': 'B',
                'birth_date': null,
                'conversation_style': 'easy',
                'onboarding_completed': true,
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('[]', 200);
        }),
      );
      final s = ArtlogState(
        const AppConfig(demo: false, authProvider: 'firebase'),
        api,
        await SharedPreferences.getInstance(),
        session: session,
      );
      await Future<void>.delayed(Duration.zero);
      session.change('b');
      await s.loadProfile();
      pending.complete(
        http.Response(
          jsonEncode({
            'nickname': 'A',
            'birth_date': '2000-01-01',
            'conversation_style': 'easy',
            'onboarding_completed': true,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(s.memberProfile!.nickname, 'B');
      expect(s.memberProfile!.birthDate, isNull);
      s.dispose();
      await session.events.close();
    },
  );
  for (final width in [320.0, 1280.0]) {
    testWidgets('my page settings save without topic order at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = (await tester.runAsync(() => demo()))!;
      await tester.pumpWidget(ArtlogApp(state: s, initialLocation: '/mypage'));
      await tester.pumpAndSettle();
      // 마이페이지 opens as a side panel; /mypage itself now lands on 내 피드.
      expect(find.byKey(const ValueKey('profile-tab-posts')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('navigation-/mypage')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-drawer')), findsOneWidget);
      await tester.tap(find.text('감상 설정'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-birth-date')),
        '2000-02-03',
      );
      expect(find.text('어떤 이야기부터 들을까요?'), findsNothing);
      final professional = find.text('전문용어 적극 사용');
      await tester.ensureVisible(professional);
      await tester.tap(professional);
      await tester.pumpAndSettle();
      final save = find.text('설정 저장');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(s.memberProfile!.birthDate, '2000-02-03');
      expect(s.memberProfile!.conversationStyle, 'professional');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    });
  }
  testWidgets('create collection and add an artwork through real widgets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = (await tester.runAsync(() => demo()))!;
    await tester.pumpWidget(ArtlogApp(state: s, initialLocation: '/mypage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 컬렉션'));
    await tester.pumpAndSettle();
    final create = find.text('새 컬렉션');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '컬렉션 이름'),
      '느리게 보는 그림',
    );
    await tester.tap(find.text('컬렉션 저장'));
    await tester.pumpAndSettle();
    final title = find.text('느리게 보는 그림');
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pumpAndSettle();
    final art = s.artworks.first;
    await tester.enterText(
      find.widgetWithText(TextField, '담고 싶은 작품 찾기'),
      art.title,
    );
    await tester.pumpAndSettle();
    final add = find.byTooltip('${art.title} 담기');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect((await s.collections()).single.count, 1);
    expect(find.text('컬렉션에 담았어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
}
