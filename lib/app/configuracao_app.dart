import 'package:flutter/foundation.dart';

@immutable
class ConfiguracaoApp {
  const ConfiguracaoApp({required this.dominioWeb, required this.apiBaseUrl});

  static const String identificadorAppWebview = 'flutter-webview';

  static const String versaoApp = String.fromEnvironment(
    'WHY_PHY_APP_VERSION',
    defaultValue: '1.0.0',
  );

  static const String _dominioPadrao = String.fromEnvironment(
    'WHY_PHY_WEB_BASE_URL',
    defaultValue: 'https://www.whyphy.com.br',
  );

  static const ConfiguracaoApp padrao = ConfiguracaoApp(
    dominioWeb: _dominioPadrao,
    apiBaseUrl: String.fromEnvironment(
      'WHY_PHY_API_BASE_URL',
      defaultValue: _dominioPadrao,
    ),
  );

  static const ConfiguracaoApp producao = ConfiguracaoApp(
    dominioWeb: 'https://www.whyphy.com.br',
    apiBaseUrl: 'https://www.whyphy.com.br',
  );

  final String dominioWeb;
  final String apiBaseUrl;

  Uri get origemWeb => Uri.parse(dominioWeb);

  Uri get origemApi => Uri.parse(apiBaseUrl);

  Uri resolverApi(String path) {
    return origemApi.resolve(path);
  }
}
