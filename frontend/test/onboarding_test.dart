import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/auth/auth_session.dart';
import 'package:artlog_web/auth/firebase_session.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/main.dart';
import 'package:artlog_web/member_profile.dart';
import 'package:artlog_web/state.dart';
import 'connected_features_test.dart' show SessionFake;

class FakeCredential extends Fake implements firebase.UserCredential {}

class PopupAuth extends Fake implements firebase.FirebaseAuth {
  firebase.AuthProvider? provider;
  String? code;
  @override
  Future<firebase.UserCredential> signInWithPopup(
    firebase.AuthProvider value,
  ) async {
    provider = value;
    if (code != null) throw firebase.FirebaseAuthException(code: code!);
    return FakeCredential();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
  Future<ArtlogState> boot(SessionFake session) async {
    final state = ArtlogState(
      const AppConfig(demo: true, authProvider: 'firebase'),
      ArtlogApi(baseUrl: 'https://example.org'),
      await SharedPreferences.getInstance(),
      session: session,
    );
    await state.load();
    return state;
  }

  test(
    'Google uses Firebase popup provider and never sends a password to the team API',
    () async {
      final auth = PopupAuth();
      await FirebaseSession(auth).signInWithGoogle();
      expect(auth.provider!.providerId, 'google.com');
    },
  );
  for (final entry in {
    'popup-closed-by-user': '취소',
    'popup-blocked': '팝업',
    'operation-not-allowed': '준비 중',
    'unauthorized-domain': '운영 주소',
    'account-exists-with-different-credential': '처음 가입한 방법',
  }.entries) {
    test('Google failure ${entry.key} gives a useful Korean message', () async {
      final auth = PopupAuth()..code = entry.key;
      await expectLater(
        FirebaseSession(auth).signInWithGoogle(),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            contains(entry.value),
          ),
        ),
      );
    });
  }
  test(
    'optional profile persists by UID and never carries demographics to another account',
    () async {
      final session = SessionFake();
      final s = await boot(session);
      expect(s.needsOnboarding, true);
      await s.saveMemberProfile(
        const MemberProfile(
          ageRange: '20s',
          gender: 'female',
          explanationStyle: 'easy',
        ),
      );
      expect(s.needsOnboarding, false);
      session.change('b');
      expect(s.memberProfile, isNull);
      expect(s.needsOnboarding, true);
      await s.saveMemberProfile(const MemberProfile());
      expect(s.memberProfile!.gender, isNull);
      session.change('a');
      expect(s.memberProfile!.ageRange, '20s');
      expect(s.memberProfile!.gender, 'female');
      expect(s.memberProfile!.explanationStyle, 'easy');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('flutter.profile.firebase.a'), contains('20s'));
      await s.logout();
      expect(s.memberProfile, isNull);
      s.dispose();
      await session.events.close();
    },
  );
  test('malformed profile is not treated as completed onboarding', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'flutter.profile.firebase.a',
      jsonEncode({'version': 1, 'age_range': 'unknown'}),
    );
    final session = SessionFake();
    final s = await boot(session);
    expect(s.needsOnboarding, true);
    s.dispose();
    await session.events.close();
  });
  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets(
      'Google login clearly leads to optional onboarding at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = SessionFake()..change(null);
        final s = (await tester.runAsync(() => boot(session)))!;
        await tester.pumpWidget(
          ArtlogApp(state: s, initialLocation: '/library'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '로그인'));
        await tester.pumpAndSettle();
        expect(find.byType(SegmentedButton<bool>), findsOneWidget);
        await tester.tap(find.text('Google로 계속하기'));
        await tester.pumpAndSettle();
        expect(find.text('나만의 감상 취향을 알려주세요'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('profile-birth-date')),
          '2001-02-03',
        );
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
        final easy = find.text('편안하고 쉬운 대화');
        await tester.ensureVisible(easy);
        await tester.tap(easy);
        await tester.pumpAndSettle();
        final save = find.text('저장하고 시작하기');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(s.memberProfile!.birthDate, '2001-02-03');
        expect(s.memberProfile!.gender, isNull);
        expect(s.memberProfile!.explanationStyle, 'easy');
        expect(find.text('나만의 감상 취향을 알려주세요'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('navigation-/mypage')));
        await tester.pumpAndSettle();
        expect(find.text('감상 설정'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        s.dispose();
        await session.events.close();
      },
    );
  }
  testWidgets(
    'skipping onboarding saves no demographics and does not prompt on reload',
    (tester) async {
      final session = SessionFake();
      final s = (await tester.runAsync(() => boot(session)))!;
      await tester.pumpWidget(ArtlogApp(state: s));
      await tester.pumpAndSettle();
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      expect(s.memberProfile!.ageRange, isNull);
      expect(s.memberProfile!.gender, isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
      final restored = (await tester.runAsync(() => boot(session)))!;
      await tester.pumpWidget(ArtlogApp(state: restored));
      await tester.pumpAndSettle();
      expect(find.text('나만의 감상 취향을 알려주세요'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      restored.dispose();
      await session.events.close();
    },
  );
  testWidgets('switching accounts during onboarding dismisses the old form', (
    tester,
  ) async {
    final session = SessionFake();
    final s = (await tester.runAsync(() => boot(session)))!;
    await tester.pumpWidget(ArtlogApp(state: s));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-birth-date')),
      '2001-02-03',
    );
    session.change('b');
    await tester.pumpAndSettle();
    expect(s.memberProfile, isNull);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('profile-birth-date')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    expect(s.memberProfile!.gender, isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
    await session.events.close();
  });
}
