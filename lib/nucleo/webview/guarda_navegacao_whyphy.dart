import '../../app/configuracao_app.dart';

class GuardaNavegacaoWhyPhy {
  const GuardaNavegacaoWhyPhy({this.configuracao = ConfiguracaoApp.producao});

  final ConfiguracaoApp configuracao;

  static const Set<String> esquemasExternosPermitidos = <String>{
    'mailto',
    'tel',
  };

  static const Set<String> hostsExternosPermitidos = <String>{'wa.me'};

  bool podeAbrirNaWebView(Uri uri) {
    final Uri origemPermitida = configuracao.origemWeb;

    return uri.scheme == origemPermitida.scheme &&
        uri.host == origemPermitida.host;
  }

  bool deveAbrirExternamente(Uri uri) {
    return esquemasExternosPermitidos.contains(uri.scheme) ||
        hostsExternosPermitidos.contains(uri.host);
  }
}
