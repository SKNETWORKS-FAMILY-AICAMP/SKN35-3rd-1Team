import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/auth/auth_session.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/docent_conversation.dart';
import 'package:artlog_web/main.dart';
import 'package:artlog_web/models.dart';
import 'package:artlog_web/state.dart';
import 'package:artlog_web/pages/detail_page.dart';
import 'package:artlog_web/ui/design.dart' show ArtworkGrid;
import 'package:artlog_web/ui/daily_artwork_hero.dart';

const work = {
  'id': 42,
  'slug': 'ssireum',
  'title': '씨름',
  'artist_id': 7,
  'artist_name': '김홍도',
};
const artist = {'id': 7, 'slug': 'kim-hong-do', 'name': '김홍도'};
const source = {
  'document_id': 1,
  'title': '씨름 해설',
  'source_name': '국립중앙박물관',
  'doc_type': 'artwork_commentary',
  'source_url': 'https://museum.go.kr/source',
  'license': '공공누리 제1유형',
  'basis_sources': [
    {'source_name': '국립중앙박물관 연구자료', 'source_url': 'https://museum.go.kr/basis'},
    {'source_name': '작품 연구 도록', 'source_url': null},
  ],
};
Json saved(String content) => {
  'id': 1,
  'role': 'assistant',
  'content': content,
  'refused': false,
  'sources': [source],
  'created_at': '2026-10-12T23:30:00Z',
};
http.Response jsonResponse(Object value) =>
    http.Response.bytes(utf8.encode(jsonEncode(value)), 200);

http.Response sseResponse(
  String answer, {
  List<Object> sources = const [],
}) => http.Response(
  'event: token\ndata: ${jsonEncode({'content': answer})}\n\n'
  'event: done\ndata: ${jsonEncode({'answer': answer, 'refused': false, 'sources': sources})}\n\n',
  200,
  headers: {'content-type': 'text/event-stream; charset=utf-8'},
);

class SessionFake implements AuthSession {
  AuthUser? current = const AuthUser(uid: 'a', email: 'a@example.invalid');
  final events = StreamController<AuthUser?>.broadcast(sync: true);
  void change(String? uid) {
    current = uid == null
        ? null
        : AuthUser(uid: uid, email: '$uid@example.invalid');
    events.add(current);
  }

  @override
  AuthUser? get user => current;
  @override
  Stream<AuthUser?> get changes => events.stream;
  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      current == null ? null : 'token-${current!.uid}';
  @override
  Future<void> signOut() async => change(null);
  @override
  Future<void> signIn(String email, String password) async => change('b');
  @override
  Future<void> register(String email, String password) async => change('b');
  @override
  Future<void> signInWithGoogle() async => change('b');
  @override
  Future<void> resetPassword(String email) async {}
}

class Fixture {
  final requests = <http.Request>[];
  Future<http.Response>? Function(http.Request)? override;
  Future<http.Response> respond(http.Request r) async {
    requests.add(r);
    final custom = override?.call(r);
    if (custom != null) return custom;
    final path = r.url.path;
    if (path == '/api/artworks/42/chat/stream') {
      return sseResponse('추가 해설', sources: [source]);
    }
    if (r.method == 'DELETE' || r.method == 'PUT' || path.endsWith('/views')) {
      return http.Response('', 204);
    }
    return jsonResponse(switch (path) {
      '/api/movements' => [
        {'id': 1, 'name': '조선 회화'},
      ],
      '/api/artists' => [artist],
      '/api/artists/7' => artist,
      '/api/artworks' => [work],
      '/api/artworks/42' => work,
      // Connected tests represent existing members. The removed explanation
      // priority field must not turn a missing profile fixture into onboarding.
      '/api/me/profile' => {
        'nickname': '감상가',
        'birth_date': null,
        'conversation_style': 'easy',
        'onboarding_completed': true,
      },
      '/api/artworks/42/chat/messages' => [saved('이전 감상')],
      '/api/artworks/42/chat' => {
        'answer': '추가 해설',
        'refused': false,
        'sources': [source],
      },
      '/api/me/chats' => [
        {
          'artwork': work,
          'last_message': '이전 감상',
          'updated_at': '2026-10-12T23:30:00Z',
        },
      ],
      '/api/me/recommendations/artworks' => [
        {...work, 'reason': '풍속화를 좋아해서'},
      ],
      '/api/me/recommendations/artists' => [
        {...artist, 'reason': '조선 회화를 즐겨 감상해서'},
      ],
      _ => [],
    });
  }
}

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
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<ArtlogState> boot(Fixture fixture, SessionFake session) async {
    final prefs = await SharedPreferences.getInstance();
    for (final uid in ['a', 'b']) {
      await prefs.setString(
        'flutter.profile.firebase.$uid',
        jsonEncode({
          'version': 1,
          'age_range': null,
          'gender': null,
          'explanation_style': 'standard',
        }),
      );
    }
    final state = ArtlogState(
      const AppConfig(demo: false, authProvider: 'firebase'),
      ArtlogApi(
        baseUrl: 'https://example.org/',
        client: MockClient(fixture.respond),
      ),
      prefs,
      session: session,
    );
    await state.load();
    return state;
  }

  test(
    'saved conversation endpoints preserve source license and Seoul time',
    () async {
      final f = Fixture();
      final api = ArtlogApi(
        baseUrl: 'https://example.org/api/',
        client: MockClient(f.respond),
      )..token = 'test';
      final messages = await api.chatMessages('42');
      expect(messages.single.sources.single.license, '공공누리 제1유형');
      expect(messages.single.sources.single.typeLabel, '작품 해설');
      expect(
        messages.single.sources.single.basisSources.first.url,
        'https://museum.go.kr/basis',
      );
      expect(Source.fromJson({'basis_sources': null}).basisSources, isEmpty);
      expect(Source.fromJson({}).basisSources, isEmpty);
      expect((await api.chats()).single.dateLabel, '2026-10-13 08:30');
      await api.resetChat('42');
      expect(f.requests.map((r) => '${r.method} ${r.url.path}'), [
        'GET /api/artworks/42/chat/messages',
        'GET /api/me/chats',
        'DELETE /api/artworks/42/chat',
      ]);
      expect(
        f.requests.every((r) => r.headers['Authorization'] == 'Bearer test'),
        true,
      );
      api.close();
    },
  );

  test(
    'ERD calendar keeps distinct artworks separate from repeated views',
    () async {
      final f = Fixture()
        ..override = (r) {
          if (r.url.path.endsWith('/calendar')) {
            return Future.value(
              jsonResponse([
                {'date': '2026-10-13', 'artwork_count': 1, 'total_views': 3},
              ]),
            );
          }
          if (r.url.path.contains('/library/days/')) {
            return Future.value(
              jsonResponse([
                {...work, 'view_count': 3, 'is_featured': true},
              ]),
            );
          }
          return null;
        };
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient(f.respond),
      )..token = 'test';
      final day = (await api.calendarDays('2026-10')).single;
      expect(day.artworkCount, 1);
      expect(day.totalViews, 3);
      final viewed = (await api.day('2026-10-13')).single;
      expect(viewed.viewCount, 3);
      expect(viewed.isFeatured, true);
      expect(
        Artwork.fromJson({...work, 'movement_id': null}).movementId,
        isEmpty,
      );
      api.close();
    },
  );

  test(
    'repeat opening records a view after the previous request completes',
    () async {
      final f = Fixture(), session = SessionFake();
      final state = await boot(f, session);
      final pending = Completer<http.Response>();
      f.override = (r) => r.url.path.endsWith('/views') ? pending.future : null;
      final first = state.recordView('42');
      await pumpEventQueue();
      await state.recordView('42');
      expect(f.requests.where((r) => r.url.path.endsWith('/views')).length, 1);
      pending.complete(http.Response('', 204));
      await first;
      f.override = null;
      await state.recordView('42');
      expect(f.requests.where((r) => r.url.path.endsWith('/views')).length, 2);
      state.dispose();
      await session.events.close();
    },
  );

  testWidgets('detail rebuilds do not record views but reopening does', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = Fixture(), session = SessionFake();
    final state = (await tester.runAsync(() => boot(f, session)))!;
    await tester.pumpWidget(
      ArtlogApp(state: state, initialLocation: '/artwork/42'),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('발견하기'), findsOneWidget);
    int views() =>
        f.requests.where((r) => r.url.path.endsWith('/views')).length;
    expect(views(), 1);
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(views(), 1);
    final router = GoRouter.of(tester.element(find.byType(DetailPage)));
    router.go('/library');
    await tester.pumpAndSettle();
    router.go('/artwork/42');
    await tester.pumpAndSettle();
    expect(views(), 2);
    router.go('/gallery');
    await tester.pumpAndSettle();
    router.go('/artwork/42');
    await tester.pumpAndSettle();
    expect(views(), 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
    await session.events.close();
    semantics.dispose();
  });

  testWidgets('featured works drive curator hero and keep stable grouping', (
    tester,
  ) async {
    final f = Fixture(), session = SessionFake();
    f.override = (r) => r.url.path == '/api/artworks'
        ? Future.value(
            jsonResponse([
              work,
              {...work, 'id': 43, 'title': '특별전', 'is_featured': true},
              {...work, 'id': 44, 'title': '두 번째 추천', 'is_featured': true},
            ]),
          )
        : null;
    final state = (await tester.runAsync(() => boot(f, session)))!;
    await tester.pumpWidget(ArtlogApp(state: state));
    await tester.pumpAndSettle();
    final hero = tester.widget<DailyArtworkHero>(find.byType(DailyArtworkHero));
    // The banner is a random pick per visit; the list keeps featured works first.
    expect(hero.works.map((a) => a.id).toSet(), {'42', '43', '44'});
    expect(find.byKey(const ValueKey('daily-fullscreen-hero')), findsOneWidget);
    expect(
      tester
          .widgetList<ArtworkGrid>(find.byType(ArtworkGrid))
          .map((g) => g.works.map((a) => a.id).join(',')),
      contains('43,44,42'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
    await session.events.close();
  });

  testWidgets('successful detail retry records the first view', (tester) async {
    final f = Fixture(), session = SessionFake();
    final state = (await tester.runAsync(() => boot(f, session)))!;
    f.override = (r) => r.url.path == '/api/artworks/42'
        ? Future.value(http.Response('', 503))
        : null;
    await tester.pumpWidget(
      ArtlogApp(state: state, initialLocation: '/artwork/42'),
    );
    await tester.pumpAndSettle();
    expect(f.requests.where((r) => r.url.path.endsWith('/views')), isEmpty);
    f.override = null;
    await tester.tap(find.text('다시 불러오기'));
    await tester.pumpAndSettle();
    expect(f.requests.where((r) => r.url.path.endsWith('/views')).length, 1);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
    await session.events.close();
  });

  test(
    'question limit is enforced before sending and long history fits server limits',
    () async {
      final f = Fixture();
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient(f.respond),
      );
      await expectLater(
        api.chat('42', '가' * 501, []),
        throwsA(isA<ApiException>()),
      );
      expect(f.requests, isEmpty);
      await api.chat('42', '질문', [ChatTurn('assistant', '😀' * 4001)]);
      final body = jsonDecode(f.requests.single.body);
      expect((body['history'][0]['content'] as String).runes.length, 4000);
      api.close();
    },
  );

  test(
    'account switch prevents a rejected mutation from retrying as another user',
    () async {
      final pending = Completer<http.Response>(), entered = Completer<void>();
      final requests = <http.Request>[];
      var uid = 'a', refreshes = 0;
      final api =
          ArtlogApi(
              baseUrl: 'https://example.org',
              client: MockClient((r) async {
                requests.add(r);
                if (requests.length == 1) {
                  entered.complete();
                  return pending.future;
                }
                return http.Response('', 204);
              }),
            )
            ..tokenProvider = (refresh) async {
              if (refresh) refreshes++;
              return uid;
            };
      final first = api.like('42', true);
      final check = expectLater(first, throwsA(isA<ApiException>()));
      await entered.future;
      uid = 'b';
      api.invalidateSession();
      pending.complete(http.Response('', 401));
      await check;
      expect(refreshes, 0);
      expect(requests, hasLength(1));
      await api.like('42', true);
      expect(requests.map((r) => r.headers['Authorization']), [
        'Bearer a',
        'Bearer b',
      ]);
      api.close();
    },
  );

  test(
    'restore, failed question retry and reset keep correct conversation context',
    () async {
      final f = Fixture(), session = SessionFake();
      var posts = 0;
      f.override = (r) =>
          r.method == 'POST' &&
              r.url.path.endsWith('/chat/stream') &&
              posts++ == 0
          ? Future.value(http.Response('', 503))
          : null;
      final state = await boot(f, session);
      final c = DocentConversation(state, Artwork.fromJson(work));
      await pumpEventQueue();
      expect(c.messages.single.content, '이전 감상');
      await c.ask('어떤 장면인가요?');
      expect(c.failedQuestion, '어떤 장면인가요?');
      await c.retry();
      expect(c.messages.map((m) => m.role), ['assistant', 'user', 'assistant']);
      final postBodies = f.requests
          .where(
            (r) => r.url.path.endsWith('/chat/stream') && r.method == 'POST',
          )
          .map((r) => jsonDecode(r.body))
          .toList();
      expect(postBodies[0]['history'], postBodies[1]['history']);
      await c.reset();
      expect(c.messages, isEmpty);
      expect(f.requests.last.method, 'DELETE');
      c.dispose();
      state.dispose();
      await session.events.close();
    },
  );

  test(
    'late response from user A never appears in user B conversation',
    () async {
      final f = Fixture(), session = SessionFake();
      final pending = Completer<http.Response>(), entered = Completer<void>();
      f.override = (r) {
        if (r.method == 'POST' && r.url.path.endsWith('/chat/stream')) {
          entered.complete();
          return pending.future;
        }
        if (r.url.path.endsWith('/chat/messages') &&
            r.headers['Authorization'] == 'Bearer token-b') {
          return Future.value(jsonResponse([saved('B의 감상')]));
        }
        return null;
      };
      final state = await boot(f, session);
      final c = DocentConversation(state, Artwork.fromJson(work));
      await pumpEventQueue();
      final asking = c.ask('A의 질문');
      await entered.future;
      session.change('b');
      await pumpEventQueue();
      pending.complete(sseResponse('A의 답변'));
      await asking;
      expect(c.messages.map((m) => m.content), ['B의 감상']);
      expect(c.busy, false);
      expect(c.error, isNull);
      c.dispose();
      state.dispose();
      await session.events.close();
    },
  );

  test(
    'late history restore cannot overwrite the newly signed-in user',
    () async {
      final f = Fixture(), session = SessionFake();
      final pending = Completer<http.Response>(), entered = Completer<void>();
      f.override = (r) {
        if (!r.url.path.endsWith('/chat/messages')) return null;
        if (r.headers['Authorization'] == 'Bearer token-a') {
          entered.complete();
          return pending.future;
        }
        return Future.value(jsonResponse([saved('B의 저장 기록')]));
      };
      final state = await boot(f, session);
      final c = DocentConversation(state, Artwork.fromJson(work));
      await entered.future;
      session.change('b');
      await pumpEventQueue();
      pending.complete(jsonResponse([saved('A의 저장 기록')]));
      await pumpEventQueue();
      expect(c.messages.map((m) => m.content), ['B의 저장 기록']);
      expect(c.loading, false);
      expect(c.historyError, isNull);
      c.dispose();
      state.dispose();
      await session.events.close();
    },
  );

  test('finishing old like does not unlock new account pending like', () async {
    final f = Fixture(), session = SessionFake();
    final oldReply = Completer<http.Response>(),
        newReply = Completer<http.Response>();
    final enteredOld = Completer<void>(), enteredNew = Completer<void>();
    f.override = (r) {
      if (r.method != 'PUT') return null;
      if (r.headers['Authorization'] == 'Bearer token-a') {
        enteredOld.complete();
        return oldReply.future;
      }
      enteredNew.complete();
      return newReply.future;
    };
    final state = await boot(f, session);
    final oldLike = state.toggleLike('42');
    await enteredOld.future;
    session.change('b');
    await pumpEventQueue();
    final newLike = state.toggleLike('42');
    await enteredNew.future;
    oldReply.complete(http.Response('', 204));
    await oldLike;
    expect(state.pendingLikes, contains('42'));
    expect(state.likes, isEmpty);
    newReply.complete(http.Response('', 204));
    await newLike;
    expect(state.pendingLikes, isEmpty);
    expect(state.likes, contains('42'));
    state.dispose();
    await session.events.close();
  });

  test('failed reset keeps the restored conversation', () async {
    final f = Fixture(), session = SessionFake();
    f.override = (r) =>
        r.method == 'DELETE' ? Future.value(http.Response('', 500)) : null;
    final state = await boot(f, session);
    final c = DocentConversation(state, Artwork.fromJson(work));
    await pumpEventQueue();
    await expectLater(c.reset(), throwsA(isA<ApiException>()));
    expect(c.messages.single.content, '이전 감상');
    expect(c.resetting, false);
    c.dispose();
    state.dispose();
    await session.events.close();
  });

  for (final width in [320.0, 1280.0]) {
    testWidgets(
      'calendar separates one artwork from three views at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = Fixture(), session = SessionFake();
        f.override = (r) {
          if (r.url.path.endsWith('/calendar')) {
            return Future.value(
              jsonResponse([
                {'date': seoulDate(), 'artwork_count': 1, 'total_views': 3},
              ]),
            );
          }
          if (r.url.path.contains('/library/days/')) {
            return Future.value(
              jsonResponse([
                {...work, 'view_count': 3},
              ]),
            );
          }
          return null;
        };
        final state = (await tester.runAsync(() => boot(f, session)))!;
        await tester.pumpWidget(
          ArtlogApp(state: state, initialLocation: '/library?tab=calendar'),
        );
        await tester.pumpAndSettle();
        expect(find.text('1일의 감상 · 총 3회 감상'), findsOneWidget);
        expect(find.text('이날 3회 감상'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
        await session.events.close();
      },
    );

    testWidgets(
      'personal recommendations show server reasons at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = Fixture(), session = SessionFake();
        final state = (await tester.runAsync(() => boot(f, session)))!;
        await tester.pumpWidget(ArtlogApp(state: state));
        await tester.pumpAndSettle();
        expect(find.text('풍속화를 좋아해서'), findsOneWidget);
        // 새롭게 만나볼 작가 was replaced by the artist stories section.
        expect(find.text('조선 회화를 즐겨 감상해서'), findsNothing);
        expect(find.text('그림 너머, 작가의 이야기'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
        await session.events.close();
      },
    );
  }

  testWidgets(
    'reset confirmation cannot delete a newly switched account conversation',
    (tester) async {
      final f = Fixture(), session = SessionFake();
      final state = (await tester.runAsync(() => boot(f, session)))!;
      await tester.pumpWidget(
        ArtlogApp(state: state, initialLocation: '/artwork/42'),
      );
      await tester.pumpAndSettle();
      final reset = find.byTooltip('대화 초기화');
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      session.change('b');
      await tester.pump();
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(TextButton, '대화 초기화'));
      await tester.pumpAndSettle();
      expect(f.requests.where((r) => r.method == 'DELETE'), isEmpty);
      expect(find.text('이전 감상'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      await session.events.close();
    },
  );
}
