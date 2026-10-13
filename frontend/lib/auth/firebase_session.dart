import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config.dart';
import 'auth_session.dart';

class FirebaseSession implements AuthSession {
  FirebaseSession(this._auth);
  final FirebaseAuth _auth;

  static Future<FirebaseSession> initialize(FirebaseWebConfig config) async {
    if (!config.complete) {
      throw const AuthFailure('로그인 서비스가 아직 설정되지 않았어요. 잠시 뒤 다시 이용해 주세요.');
    }
    final app = await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: config.apiKey,
        appId: config.appId,
        messagingSenderId: config.messagingSenderId,
        projectId: config.projectId,
        authDomain: config.authDomain,
      ),
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    await auth.setPersistence(Persistence.LOCAL);
    await auth.setLanguageCode('ko');
    await auth.authStateChanges().first;
    return FirebaseSession(auth);
  }

  AuthUser? _user(User? user) =>
      user == null ? null : AuthUser(uid: user.uid, email: user.email ?? '');
  @override
  AuthUser? get user => _user(_auth.currentUser);
  @override
  Stream<AuthUser?> get changes => _auth.idTokenChanges().map(_user);
  @override
  Future<void> signIn(String email, String password) => _guard(() async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  });
  @override
  Future<void> register(String email, String password) => _guard(() async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  });
  @override
  Future<void> signInWithGoogle() => _guard(() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    await _auth.signInWithPopup(provider);
  });
  @override
  Future<void> resetPassword(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email));
  @override
  Future<void> signOut() => _guard(_auth.signOut);
  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      _auth.currentUser?.getIdToken(forceRefresh);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(switch (e.code) {
        'invalid-email' => '이메일 주소를 확인해 주세요.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => '이메일 또는 비밀번호를 확인해 주세요.',
        'email-already-in-use' => '이미 가입된 이메일이에요. 로그인해 주세요.',
        'weak-password' ||
        'password-does-not-meet-requirements' => '비밀번호는 8자 이상으로 설정해 주세요.',
        'user-disabled' => '이 계정은 사용할 수 없어요. 관리자에게 문의해 주세요.',
        'too-many-requests' => '시도가 많아 잠시 쉬어가야 해요. 조금 뒤 다시 이용해 주세요.',
        'operation-not-allowed' => '이 로그인 방법은 아직 준비 중이에요. 다른 방법으로 로그인해 주세요.',
        'popup-closed-by-user' ||
        'cancelled-popup-request' => 'Google 로그인이 취소됐어요. 다시 시작할 수 있어요.',
        'popup-blocked' => '브라우저에서 팝업을 허용한 뒤 Google 로그인을 다시 눌러주세요.',
        'unauthorized-domain' =>
          '이 주소에서는 Google 로그인을 사용할 수 없어요. 아트로그 운영 주소를 이용해 주세요.',
        'account-exists-with-different-credential' =>
          '이미 다른 방법으로 가입한 이메일이에요. 처음 가입한 방법으로 로그인해 주세요.',
        'network-request-failed' => '로그인 서비스에 연결하지 못했어요. 인터넷 연결을 확인해 주세요.',
        _ => '로그인을 완료하지 못했어요. 잠시 뒤 다시 시도해 주세요.',
      });
    }
  }
}
