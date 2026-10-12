class AuthUser {
  const AuthUser({required this.uid, required this.email});
  final String uid, email;
}

abstract class AuthSession {
  AuthUser? get user;
  Stream<AuthUser?> get changes;
  Future<void> signIn(String email, String password);
  Future<void> register(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> signOut();
  Future<String?> idToken({bool forceRefresh = false});
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
