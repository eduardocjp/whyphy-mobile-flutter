import 'estado_sessao.dart';
import 'modelos_autenticacao.dart';

class CredenciaisLogin {
  const CredenciaisLogin({required this.email, required this.senha});

  final String email;
  final String senha;
}

enum StatusLogin {
  autenticado,
  recusado,
  conflitoSessao,
  bloqueioFinanceiro,
  configuracaoSenhaPendente,
  indisponivel,
}

class ResultadoLogin {
  const ResultadoLogin({
    required this.status,
    this.bootstrap,
    this.mensagem,
    this.sessao,
  });

  final BootstrapWebview? bootstrap;
  final StatusLogin status;
  final String? mensagem;
  final SessaoWhyPhy? sessao;

  bool get autenticado => status == StatusLogin.autenticado;
}

abstract interface class ServicoAutenticacao {
  Future<ResultadoLogin> entrar(CredenciaisLogin credenciais);

  Future<BootstrapWebview?> prepararWebview();

  Future<bool> restaurarSessao();

  Future<void> sair();
}
