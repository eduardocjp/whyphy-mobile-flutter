import 'guarda_navegacao_whyphy.dart';

class ControladorWebviewWhyPhy {
  const ControladorWebviewWhyPhy({required this.guardaNavegacao});

  final GuardaNavegacaoWhyPhy guardaNavegacao;

  bool podeAbrirNaWebView(Uri uri) {
    return guardaNavegacao.podeAbrirNaWebView(uri);
  }

  bool deveAbrirExternamente(Uri uri) {
    return guardaNavegacao.deveAbrirExternamente(uri);
  }
}
