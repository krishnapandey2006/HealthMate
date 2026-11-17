/// Runtime configuration for HealthMate's public-data proxy.
///
/// Personal profiles, vaccination records and reports never leave the device.
/// Only public requests (news, campaigns, geocoding and nearby facilities) go
/// through this proxy. No private API keys belong in the Flutter bundle.
class AppConfig {
  AppConfig._();

  static const String _defaultProxyUrl = 'http://localhost:8787';

  /// Base URL of the HealthMate public-data proxy
  /// (tools/healthmate_server.js).
  ///
  /// Native builds do not use this default: `localhost` on a phone points to
  /// the phone itself. They use keyless HTTPS OpenStreetMap/news providers
  /// directly. Set `--dart-define=HEALTHMATE_PROXY_URL=https://...` to route
  /// native traffic through a deployed proxy instead.
  static const String proxyBaseUrl = String.fromEnvironment(
    'HEALTHMATE_PROXY_URL',
    defaultValue: _defaultProxyUrl,
  );

  /// True when a proxy URL was supplied at build time. The local development
  /// default is only meaningful for the browser build, where the proxy runs on
  /// the same machine as the browser.
  static bool get hasExplicitProxy =>
      proxyBaseUrl.trim().isNotEmpty && proxyBaseUrl != _defaultProxyUrl;
}
