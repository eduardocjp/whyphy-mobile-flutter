import 'dart:convert';

import '../../app/configuracao_app.dart';
import '../../nucleo/armazenamento/gerenciador_device_id.dart';
import '../../nucleo/armazenamento/servico_armazenamento_seguro.dart';
import '../../nucleo/notificacoes/servico_push.dart';
import '../../nucleo/rede/cliente_api.dart';
import '../../nucleo/rede/json_api.dart';
import '../../nucleo/rede/rotas_api_mobile.dart';
import 'estado_sessao.dart';
import 'modelos_autenticacao.dart';
import 'servico_autenticacao.dart';

class ServicoAutenticacaoMobile implements ServicoAutenticacao {
  const ServicoAutenticacaoMobile({
    required this.armazenamento,
    required this.clienteApi,
    required this.configuracao,
    required this.estadoSessao,
    required this.gerenciadorDeviceId,
    required this.servicoPush,
  });

  final ServicoArmazenamentoSeguro armazenamento;
  final ClienteApi clienteApi;
  final ConfiguracaoApp configuracao;
  final EstadoSessao estadoSessao;
  final GerenciadorDeviceId gerenciadorDeviceId;
  final ServicoPush servicoPush;

  @override
  Future<ResultadoLogin> entrar(CredenciaisLogin credenciais) async {
    final String deviceId = await gerenciadorDeviceId.obterOuCriar();
    final RespostaApi resposta = await clienteApi.enviar(
      RequisicaoApi(
        metodo: MetodoHttp.post,
        uri: configuracao.resolverApi(RotasApiMobile.login),
        contentType: 'application/json; charset=utf-8',
        headers: _headersBase(),
        corpoBytes: utf8.encode(
          codificarObjetoJson(<String, Object?>{
            'deviceId': deviceId,
            'email': credenciais.email.trim(),
            'senha': credenciais.senha,
          }),
        ),
      ),
    );

    final Map<String, Object?> json = decodificarObjetoJson(resposta.corpo);

    if (!resposta.sucesso || !lerBoolJson(json, 'success')) {
      return ResultadoLogin(
        status: _mapearStatusFalha(lerStringOpcionalJson(json, 'code')),
        mensagem:
            lerStringOpcionalJson(json, 'message') ??
            'Não foi possível entrar no WhyPhy.',
      );
    }

    final SessaoMobile sessaoMobile = SessaoMobile.fromLoginJson(json);
    await _persistirSessao(sessaoMobile);
    await _sincronizarPushAtual();

    final BootstrapWebview? bootstrap = await prepararWebview();
    final SessaoWhyPhy sessao =
        estadoSessao.sessaoAtual ??
        SessaoWhyPhy.fromSessaoMobile(sessaoMobile, bootstrap: bootstrap);

    estadoSessao.definirSessao(sessao.copiarCom(bootstrap: bootstrap));

    return ResultadoLogin(
      bootstrap: bootstrap,
      mensagem: 'Sessão iniciada.',
      sessao: estadoSessao.sessaoAtual,
      status: StatusLogin.autenticado,
    );
  }

  @override
  Future<void> esquecerCredenciaisLembradas() async {
    await armazenamento.remover(ChavesArmazenamentoSeguro.loginEmailLembrado);
    await armazenamento.remover(ChavesArmazenamentoSeguro.loginSenhaLembrada);
  }

  @override
  Future<CredenciaisLembradas?> obterCredenciaisLembradas() async {
    final String? email = await armazenamento.ler(
      ChavesArmazenamentoSeguro.loginEmailLembrado,
    );
    final String? senha = await armazenamento.ler(
      ChavesArmazenamentoSeguro.loginSenhaLembrada,
    );

    final CredenciaisLembradas credenciais = CredenciaisLembradas(
      email: email?.trim() ?? '',
      senha: senha ?? '',
    );

    return credenciais.preenchidas ? credenciais : null;
  }

  @override
  Future<BootstrapWebview?> prepararWebview() async {
    final String? accessToken = await armazenamento.ler(
      ChavesArmazenamentoSeguro.tokenAcesso,
    );
    final String? deviceId = await armazenamento.ler(
      ChavesArmazenamentoSeguro.deviceId,
    );

    if (_vazio(accessToken) || _vazio(deviceId)) {
      return null;
    }

    final RespostaApi resposta = await clienteApi.enviar(
      RequisicaoApi(
        metodo: MetodoHttp.get,
        uri: configuracao.resolverApi(RotasApiMobile.webview),
        headers: _headersAutenticados(
          accessToken: accessToken!,
          deviceId: deviceId!,
        ),
      ),
    );

    if (!resposta.sucesso) {
      return null;
    }

    final Map<String, Object?> json = decodificarObjetoJson(resposta.corpo);
    final Map<String, Object?> bootstrapJson = lerObjetoJson(json, 'bootstrap');

    if (bootstrapJson.isEmpty) {
      return null;
    }

    final BootstrapWebview bootstrap = BootstrapWebview.fromJson(bootstrapJson);
    estadoSessao.definirBootstrap(bootstrap);

    return bootstrap;
  }

  @override
  Future<bool> restaurarSessao() async {
    final String? accessToken = await armazenamento.ler(
      ChavesArmazenamentoSeguro.tokenAcesso,
    );
    final String? deviceId = await armazenamento.ler(
      ChavesArmazenamentoSeguro.deviceId,
    );

    if (_vazio(accessToken) || _vazio(deviceId)) {
      estadoSessao.limpar();
      return false;
    }

    final RespostaApi resposta = await clienteApi.enviar(
      RequisicaoApi(
        metodo: MetodoHttp.get,
        uri: configuracao.resolverApi(RotasApiMobile.sessao),
        headers: _headersAutenticados(
          accessToken: accessToken!,
          deviceId: deviceId!,
        ),
      ),
    );

    if (!resposta.sucesso) {
      await _limparSessaoLocal();
      return false;
    }

    final Map<String, Object?> json = decodificarObjetoJson(resposta.corpo);

    if (!lerBoolJson(json, 'success')) {
      await _limparSessaoLocal();
      return false;
    }

    final SessaoMobile sessaoMobile = SessaoMobile.fromSessionJson(
      accessToken: accessToken,
      json: lerObjetoJson(json, 'session'),
    );

    estadoSessao.definirSessao(SessaoWhyPhy.fromSessaoMobile(sessaoMobile));
    await _sincronizarPushAtual();
    await prepararWebview();

    return true;
  }

  @override
  Future<void> salvarCredenciaisLembradas(CredenciaisLogin credenciais) async {
    await armazenamento.salvar(
      chave: ChavesArmazenamentoSeguro.loginEmailLembrado,
      valor: credenciais.email.trim(),
    );
    await armazenamento.salvar(
      chave: ChavesArmazenamentoSeguro.loginSenhaLembrada,
      valor: credenciais.senha,
    );
  }

  @override
  Future<void> sair() async {
    final String? accessToken = await armazenamento.ler(
      ChavesArmazenamentoSeguro.tokenAcesso,
    );
    final String? deviceId = await armazenamento.ler(
      ChavesArmazenamentoSeguro.deviceId,
    );

    if (!_vazio(accessToken) && !_vazio(deviceId)) {
      await servicoPush.remover();
      await clienteApi.enviar(
        RequisicaoApi(
          metodo: MetodoHttp.post,
          uri: configuracao.resolverApi(RotasApiMobile.logout),
          headers: _headersAutenticados(
            accessToken: accessToken!,
            deviceId: deviceId!,
          ),
        ),
      );
    }

    await _limparSessaoLocal();
  }

  Future<void> _sincronizarPushAtual() async {
    await servicoPush.inicializar();
    final RegistroPush? registro = await servicoPush.obterRegistro();

    if (registro == null) {
      return;
    }

    await servicoPush.registrar(registro);
  }

  Map<String, String> _headersBase() {
    return const <String, String>{
      'accept': 'application/json',
      'x-whyphy-app': 'flutter',
    };
  }

  Map<String, String> _headersAutenticados({
    required String accessToken,
    required String deviceId,
  }) {
    return <String, String>{
      ..._headersBase(),
      'authorization': 'Bearer $accessToken',
      'x-device-id': deviceId,
    };
  }

  Future<void> _limparSessaoLocal() async {
    await armazenamento.remover(ChavesArmazenamentoSeguro.tokenAcesso);
    await armazenamento.remover(ChavesArmazenamentoSeguro.refreshToken);
    await armazenamento.remover(ChavesArmazenamentoSeguro.sessaoMinima);
    estadoSessao.limpar();
  }

  StatusLogin _mapearStatusFalha(String? codigo) {
    return switch (codigo) {
      'SESSION_CONFLICT' => StatusLogin.conflitoSessao,
      'FINANCIAL_BLOCK' => StatusLogin.bloqueioFinanceiro,
      'PASSWORD_SETUP_REQUIRED' => StatusLogin.configuracaoSenhaPendente,
      'LOGIN_UNAVAILABLE' => StatusLogin.indisponivel,
      _ => StatusLogin.recusado,
    };
  }

  Future<void> _persistirSessao(SessaoMobile sessao) async {
    await armazenamento.salvar(
      chave: ChavesArmazenamentoSeguro.tokenAcesso,
      valor: sessao.accessToken,
    );
    await armazenamento.salvar(
      chave: ChavesArmazenamentoSeguro.deviceId,
      valor: sessao.deviceId,
    );
    await armazenamento.salvar(
      chave: ChavesArmazenamentoSeguro.sessaoMinima,
      valor: codificarObjetoJson(<String, Object?>{
        'displayName': sessao.displayName,
        'expiresAt': sessao.expiresAt,
        'redirectPath': sessao.redirectPath,
        'role': sessao.role.valorApi,
        'sessionId': sessao.sessionId,
        'userId': sessao.userId,
      }),
    );

    estadoSessao.definirSessao(SessaoWhyPhy.fromSessaoMobile(sessao));
  }

  bool _vazio(String? value) {
    return value == null || value.trim().isEmpty;
  }
}
