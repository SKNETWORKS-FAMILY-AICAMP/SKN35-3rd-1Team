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
import 'package:artlog_web/main.dart';
import 'package:artlog_web/state.dart';

class TestAuth implements AuthSession {
  TestAuth([this.current]);
  AuthUser? current;
  String? lastEmail, lastPassword;
  bool failLogin = false;
  final events = StreamController<AuthUser?>.broadcast(sync: true);
  @override
  AuthUser? get user => current;
  @override
  Stream<AuthUser?> get changes => events.stream;
  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      current == null ? null : 'token-${current!.uid}';
  @override
  Future<void> signIn(String email, String password) async {
    lastEmail = email;
    lastPassword = password;
    if (failLogin) throw const AuthFailure('이메일 또는 비밀번호를 확인해 주세요.');
    current = AuthUser(uid: 'uid-$email', email: email);
    events.add(current);
  }

  @override
  Future<void> register(String email, String password) =>
      signIn(email, password);
  @override
  Future<void> resetPassword(String email) async {
    lastEmail = email;
  }

  @override
  Future<void> signOut() async {
    current = null;
    events.add(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<ArtlogState> preview(TestAuth? auth) async {
    final s = ArtlogState(
      const AppConfig(demo: true, authProvider: 'firebase'),
      ArtlogApi(baseUrl: 'https://example.org'),
      await SharedPreferences.getInstance(),
      session: auth,
    );
    await s.load();
    return s;
  }

  test(
    'Firebase preview requires real authentication, never grants a guest session',
    () async {
      final auth = TestAuth();
      final s = await preview(auth);
      expect(s.authenticated, false);
      expect(s.artworks, isNotEmpty);
      await expectLater(
        s.toggleLike(s.artworks.first.id),
        throwsA(isA<ApiException>()),
      );
      auth.failLogin = true;
      await expectLater(
        s.login('member@example.org', 'invalid'),
        throwsA(isA<AuthFailure>()),
      );
      expect(s.authenticated, false);
      expect(s.likes, isEmpty);
      s.dispose();
      await auth.events.close();
    },
  );

  test(
    'missing Firebase initialization stays logged out with a useful error',
    () async {
      final s = await preview(null);
      expect(s.authenticated, false);
      expect(s.canAuthenticate, false);
      await expectLater(
        s.login('member@example.org', 'test-only'),
        throwsA(isA<AuthFailure>()),
      );
      s.dispose();
    },
  );

  test(
    'Firebase login bypasses legacy auth endpoint and separates account records',
    () async {
      final auth = TestAuth();
      final s = await preview(auth);
      final id = s.artworks.first.id;
      await s.login('one@example.org', 'test-only');
      expect(auth.lastEmail, 'one@example.org');
      await s.toggleLike(id);
      await s.saveNote('2026-10-12', '첫 번째 계정');
      await s.logout();
      expect(s.authenticated, false);
      expect(s.likes, isEmpty);
      await s.login('two@example.org', 'test-only');
      expect(s.likes, isEmpty);
      expect(s.note('2026-10-12'), '');
      await s.logout();
      await s.login('one@example.org', 'test-only');
      expect(s.likes, contains(id));
      expect(s.note('2026-10-12'), '첫 번째 계정');
      s.dispose();
      await auth.events.close();
    },
  );

  test('restored Firebase session is recognized before login UI', () async {
    final auth = TestAuth(
      const AuthUser(uid: 'saved', email: 'saved@example.org'),
    );
    final s = await preview(auth);
    expect(s.authenticated, true);
    expect(s.email, 'saved@example.org');
    expect(s.userKey, 'saved');
    s.dispose();
    await auth.events.close();
  });

  test(
    'Firebase token is refreshed once on 401 and retry uses new token',
    () async {
      var refreshed = false, attempts = 0;
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient((r) async {
          attempts++;
          expect(
            r.headers['Authorization'],
            attempts == 1 ? 'Bearer old-token' : 'Bearer new-token',
          );
          return http.Response(
            attempts == 1 ? '' : '[]',
            attempts == 1 ? 401 : 200,
          );
        }),
      );
      api.tokenProvider = (force) async {
        if (force) refreshed = true;
        return refreshed ? 'new-token' : 'old-token';
      };
      expect(await api.likes(), isEmpty);
      expect(attempts, 2);
      expect(refreshed, true);
      api.close();
    },
  );

  test('repeated 401 cannot cause an infinite refresh loop', () async {
    var attempts = 0, failures = 0;
    final api =
        ArtlogApi(
            baseUrl: 'https://example.org',
            client: MockClient((r) async {
              attempts++;
              return http.Response('', 401);
            }),
          )
          ..tokenProvider = ((_) async => 'test-token')
          ..onUnauthorized = () => failures++;
    await expectLater(api.likes(), throwsA(isA<ApiException>()));
    expect(attempts, 2);
    expect(failures, 1);
    api.close();
  });

  test(
    'late like response from old user cannot update new user state',
    () async {
      final pending = Completer<http.Response>();
      final auth = TestAuth();
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient((r) async {
          if (r.method == 'PUT') return pending.future;
          return http.Response(jsonEncode([]), 200);
        }),
      );
      final s = ArtlogState(
        const AppConfig(demo: false, authProvider: 'firebase'),
        api,
        await SharedPreferences.getInstance(),
        session: auth,
      );
      await s.login('one@example.org', 'test-only');
      final liking = s.toggleLike('42');
      await s.logout();
      await s.login('two@example.org', 'test-only');
      pending.complete(http.Response('', 204));
      await liking;
      expect(s.email, 'two@example.org');
      expect(s.likes, isEmpty);
      s.dispose();
      await auth.events.close();
    },
  );

  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('Firebase login and signup dialog fit ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        for (final entry in {
          'NotoSansKR': 'NotoSansKR',
          'NotoSerifKR': 'NotoSerifKR',
          'Cormorant': 'CormorantGaramond',
          'DMSans': 'DMSans',
        }.entries) {
          await (FontLoader(entry.key)..addFont(
                rootBundle.load('assets/fonts/${entry.value}-400.ttf'),
              ))
              .load();
        }
      });
      final auth = TestAuth();
      final s = (await tester.runAsync(() => preview(auth)))!;
      await tester.pumpWidget(ArtlogApp(state: s, initialLocation: '/library'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await tester.pumpAndSettle();
      expect(find.text('나만의 미술관에 로그인'), findsOneWidget);
      await tester.tap(find.text('처음 오셨나요? 회원가입'));
      await tester.pumpAndSettle();
      expect(find.text('나만의 미술관 시작하기'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '회원가입'));
      await tester.pumpAndSettle();
      expect(find.text('이메일 주소를 확인해 주세요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
      await auth.events.close();
    });
  }
}
