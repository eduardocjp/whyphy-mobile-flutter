import 'package:flutter/foundation.dart';

import 'modelos_autenticacao.dart';

class SessaoWhyPhy {
  const SessaoWhyPhy({
    required this.accessToken,
    required this.deviceId,
    required this.expiraEm,
    required this.usuarioId,
    required this.nome,
    required this.papel,
    required this.rotaInicial,
    this.bootstrap,
  });

  factory SessaoWhyPhy.fromSessaoMobile(
    SessaoMobile sessao, {
    BootstrapWebview? bootstrap,
  }) {
    return SessaoWhyPhy(
      accessToken: sessao.accessToken,
      bootstrap: bootstrap,
      deviceId: sessao.deviceId,
      expiraEm: sessao.expiresAt,
      nome: sessao.displayName,
      papel: sessao.role,
      rotaInicial: sessao.redirectPath,
      usuarioId: sessao.userId,
    );
  }

  final String accessToken;
  final BootstrapWebview? bootstrap;
  final String deviceId;
  final String expiraEm;
  final String usuarioId;
  final String nome;
  final PapelWhyPhy papel;
  final String rotaInicial;

  SessaoWhyPhy copiarCom({BootstrapWebview? bootstrap}) {
    return SessaoWhyPhy(
      accessToken: accessToken,
      bootstrap: bootstrap ?? this.bootstrap,
      deviceId: deviceId,
      expiraEm: expiraEm,
      nome: nome,
      papel: papel,
      rotaInicial: rotaInicial,
      usuarioId: usuarioId,
    );
  }
}

class EstadoSessao extends ChangeNotifier {
  SessaoWhyPhy? _sessaoAtual;

  SessaoWhyPhy? get sessaoAtual => _sessaoAtual;

  bool get autenticado => _sessaoAtual != null;

  void definirSessao(SessaoWhyPhy sessao) {
    _sessaoAtual = sessao;
    notifyListeners();
  }

  void definirBootstrap(BootstrapWebview bootstrap) {
    final SessaoWhyPhy? sessao = _sessaoAtual;

    if (sessao == null) {
      return;
    }

    _sessaoAtual = sessao.copiarCom(bootstrap: bootstrap);
    notifyListeners();
  }

  void limpar() {
    _sessaoAtual = null;
    notifyListeners();
  }
}
