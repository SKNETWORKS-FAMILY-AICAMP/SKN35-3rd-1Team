import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/auth/auth_session.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/docent_conversation.dart';
import 'package:artlog_web/main.dart';
import 'package:artlog_web/models.dart';
import 'package:artlog_web/state.dart';

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
          r.method == 'POST' && r.url.path.endsWith('/chat') && posts++ == 0
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
          .where((r) => r.url.path.endsWith('/chat') && r.method == 'POST')
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
        if (r.method == 'POST' && r.url.path.endsWith('/chat')) {
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
      pending.complete(
        jsonResponse({'answer': 'A의 답변', 'refused': false, 'sources': []}),
      );
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
      'saved chats open restored conversation and licensed sources at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = Fixture(), session = SessionFake();
        final state = (await tester.runAsync(() => boot(f, session)))!;
        await tester.pumpWidget(
          ArtlogApp(state: state, initialLocation: '/library'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('대화 내역'));
        await tester.pumpAndSettle();
        expect(find.text('2026-10-13 08:30'), findsOneWidget);
        await tester.tap(find.text('씨름'));
        await tester.pumpAndSettle();
        expect(find.text('이전 감상'), findsOneWidget);
        final chip = find.widgetWithText(ActionChip, '1 · 국립중앙박물관');
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(find.text('이용 조건: 공공누리 제1유형'), findsOneWidget);
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
        expect(find.text('조선 회화를 즐겨 감상해서'), findsOneWidget);
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
