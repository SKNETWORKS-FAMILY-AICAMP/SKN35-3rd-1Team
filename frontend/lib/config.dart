class AppConfig {
  const AppConfig({
    this.demo = const bool.fromEnvironment('ARTLOG_DEMO', defaultValue: true),
    this.apiBaseUrl = const String.fromEnvironment('API_BASE_URL'),
    this.authProvider = const String.fromEnvironment(
      'AUTH_PROVIDER',
      defaultValue: 'auto',
    ),
    this.firebase = const FirebaseWebConfig(),
  });

  final bool demo;
  // Empty means same origin. Supply the server root, with an optional /api suffix.
  final String apiBaseUrl;
  final String authProvider;
  final FirebaseWebConfig firebase;
  bool get firebaseAuth =>
      authProvider == 'firebase' ||
      (authProvider == 'auto' && firebase.complete);
}

// Firebase web configuration is public app metadata, never an Admin service account.
class FirebaseWebConfig {
  const FirebaseWebConfig({
    this.apiKey = const String.fromEnvironment('FIREBASE_API_KEY'),
    this.appId = const String.fromEnvironment('FIREBASE_APP_ID'),
    this.messagingSenderId = const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    this.projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    this.authDomain = const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
  });
  final String apiKey, appId, messagingSenderId, projectId, authDomain;
  bool get complete => [
    apiKey,
    appId,
    messagingSenderId,
    projectId,
    authDomain,
  ].every((v) => v.isNotEmpty);
}
