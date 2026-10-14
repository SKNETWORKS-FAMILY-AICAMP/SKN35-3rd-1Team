import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/auth/auth_session.dart';
import 'package:artlog_web/auth/firebase_session.dart';
import 'package:artlog_web/config.dart';
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
}
