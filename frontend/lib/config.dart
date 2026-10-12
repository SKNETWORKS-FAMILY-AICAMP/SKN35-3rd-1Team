class AppConfig {
  const AppConfig({
    this.demo = const bool.fromEnvironment('ARTLOG_DEMO', defaultValue: true),
    this.apiBaseUrl = const String.fromEnvironment('API_BASE_URL'),
  });

  final bool demo;
  // Empty means same origin. Supply the server root, with an optional /api suffix.
  final String apiBaseUrl;
}
