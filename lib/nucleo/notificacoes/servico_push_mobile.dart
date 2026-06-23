import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../app/configuracao_app.dart';
import '../armazenamento/servico_armazenamento_seguro.dart';
import '../rede/cliente_api.dart';
import '../rede/json_api.dart';
import '../rede/rotas_api_mobile.dart';
import 'servico_push.dart';

class ServicoPushMobile implements ServicoPush {
  static final StreamController<Map<String, String>> _pushAbertos =
      StreamController<Map<String, String>>.broadcast();
  static final StreamController<Map<String, String>> _pushRecebidos =
      StreamController<Map<String, String>>.broadcast();
  static final List<Map<String, String>> _pushPendentes =
      <Map<String, String>>[];
  static final List<StreamSubscription<Object>> _assinaturas =
      <StreamSubscription<Object>>[];
  static bool _listenersConfigurados = false;

  static Stream<Map<String, String>> get pushAbertos => _pushAbertos.stream;

  static Stream<Map<String, String>> get pushRecebidos => _pushRecebidos.stream;

  static Map<String, String>? consumirPushPendente() {
    if (_pushPendentes.isEmpty) {
      return null;
    }

    return _pushPendentes.removeAt(0);
  }

  const ServicoPushMobile({
    required this.armazenamento,
    required this.clienteApi,
    required this.configuracao,
  });

  final ServicoArmazenamentoSeguro armazenamento;
  final ClienteApi clienteApi;
  final ConfiguracaoApp configuracao;

  @override
  Future<void> inicializar() async {
    try {
      final FirebaseMessaging mensagens = FirebaseMessaging.instance;

      await mensagens.requestPermission(alert: true, badge: true, sound: true);
      await mensagens.setAutoInitEnabled(true);
      await mensagens.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _configurarListeners(mensagens);
      final RemoteMessage? mensagemInicial = await mensagens
          .getInitialMessage();
      _publicarPushAberto(mensagemInicial);
    } on FirebaseException {
      return;
    } on UnsupportedError {
      return;
    } on StateError {
      return;
    }
  }

  @override
  Future<RegistroPush?> obterRegistro() async {
    try {
      final String token = (await FirebaseMessaging.instance.getToken() ?? '')
          .trim();
      final String plataforma = _plataformaAtual();

      if (token.isEmpty || plataforma.isEmpty) {
        return null;
      }

      return RegistroPush(
        appVersion: null,
        plataforma: plataforma,
        token: token,
      );
    } on FirebaseException {
      return null;
    } on UnsupportedError {
      return null;
    } on StateError {
      return null;
    }
  }

  @override
  Future<bool> registrar(RegistroPush registro) async {
    final String? accessToken = await armazenamento.ler(
      ChavesArmazenamentoSeguro.tokenAcesso,
    );
    final String? deviceId = await armazenamento.ler(
      ChavesArmazenamentoSeguro.deviceId,
    );

    if (_vazio(accessToken) || _vazio(deviceId)) {
      return false;
    }

    final RespostaApi resposta = await clienteApi.enviar(
      RequisicaoApi(
        metodo: MetodoHttp.post,
        uri: configuracao.resolverApi(RotasApiMobile.pushDevice),
        contentType: 'application/json; charset=utf-8',
        headers: _headersAutenticados(
          accessToken: accessToken!,
          deviceId: deviceId!,
        ),
        corpoBytes: utf8.encode(
          codificarObjetoJson(<String, Object?>{
            'appVersion': registro.appVersion,
            'deviceId': deviceId,
            'plataforma': registro.plataforma,
            'pushToken': registro.token,
          }),
        ),
      ),
    );

    return _respostaSucesso(resposta);
  }

  @override
  Future<bool> remover() async {
    final String? accessToken = await armazenamento.ler(
      ChavesArmazenamentoSeguro.tokenAcesso,
    );
    final String? deviceId = await armazenamento.ler(
      ChavesArmazenamentoSeguro.deviceId,
    );

    if (_vazio(accessToken) || _vazio(deviceId)) {
      return false;
    }

    final RespostaApi resposta = await clienteApi.enviar(
      RequisicaoApi(
        metodo: MetodoHttp.delete,
        uri: configuracao.resolverApi(RotasApiMobile.pushDevice),
        contentType: 'application/json; charset=utf-8',
        headers: _headersAutenticados(
          accessToken: accessToken!,
          deviceId: deviceId!,
        ),
        corpoBytes: utf8.encode(
          codificarObjetoJson(<String, Object?>{'deviceId': deviceId}),
        ),
      ),
    );

    final bool sucesso = _respostaSucesso(resposta);

    if (sucesso) {
      await _removerTokenFirebase();
    }

    return sucesso;
  }

  Future<void> _configurarListeners(FirebaseMessaging mensagens) async {
    if (_listenersConfigurados) {
      return;
    }

    _listenersConfigurados = true;

    _assinaturas.add(
      mensagens.onTokenRefresh.listen((String token) {
        final String tokenNormalizado = token.trim();

        if (tokenNormalizado.isEmpty) {
          return;
        }

        unawaited(
          registrar(
            RegistroPush(
              appVersion: null,
              plataforma: _plataformaAtual(),
              token: tokenNormalizado,
            ),
          ),
        );
      }),
    );

    _assinaturas.add(
      FirebaseMessaging.onMessageOpenedApp.listen(_publicarPushAberto),
    );
    _assinaturas.add(FirebaseMessaging.onMessage.listen(_publicarPushRecebido));
  }

  Future<void> _removerTokenFirebase() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } on FirebaseException {
      return;
    } on UnsupportedError {
      return;
    } on StateError {
      return;
    }
  }

  static void _publicarPushAberto(RemoteMessage? mensagem) {
    final Map<String, String>? carga = _extrairCargaPush(mensagem);

    if (carga == null) {
      return;
    }

    _pushPendentes.add(carga);
    _pushAbertos.add(carga);
  }

  static void _publicarPushRecebido(RemoteMessage mensagem) {
    final Map<String, String>? carga = _extrairCargaPush(mensagem);

    if (carga == null) {
      return;
    }

    _pushRecebidos.add(carga);
  }

  static Map<String, String>? _extrairCargaPush(RemoteMessage? mensagem) {
    if (mensagem == null) {
      return null;
    }

    final Map<String, String> data = mensagem.data.map((
      String chave,
      Object? valor,
    ) {
      return MapEntry<String, String>(chave, valor?.toString().trim() ?? '');
    });

    final String routePath = _primeiroValorNaoVazio(<String?>[
      data['routePath'],
      data['targetPath'],
      data['next'],
      data['url'],
    ]);

    if (!_rotaInternaValida(routePath)) {
      return null;
    }

    final Map<String, String> carga = <String, String>{'routePath': routePath};
    final String mensagemTexto = _primeiroValorNaoVazio(<String?>[
      data['mensagem'],
      data['body'],
      mensagem.notification?.body,
    ]);
    final String titulo = _primeiroValorNaoVazio(<String?>[
      data['title'],
      mensagem.notification?.title,
    ]);

    if (mensagemTexto.isNotEmpty) {
      carga['mensagem'] = mensagemTexto;
    }

    if (titulo.isNotEmpty) {
      carga['title'] = titulo;
    }

    for (final String chave in <String>[
      'tipo',
      'stage',
      'appointmentId',
      'appointmentKind',
      'consultaId',
    ]) {
      final String valor = data[chave] ?? '';

      if (valor.isNotEmpty) {
        carga[chave] = valor;
      }
    }

    return carga;
  }

  static String _primeiroValorNaoVazio(List<String?> valores) {
    for (final String? valor in valores) {
      final String normalizado = valor?.trim() ?? '';

      if (normalizado.isNotEmpty) {
        return normalizado;
      }
    }

    return '';
  }

  static bool _rotaInternaValida(String routePath) {
    return routePath.isNotEmpty &&
        routePath.startsWith('/') &&
        !routePath.startsWith('//');
  }

  String _plataformaAtual() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => '',
    };
  }

  Map<String, String> _headersAutenticados({
    required String accessToken,
    required String deviceId,
  }) {
    return <String, String>{
      'accept': 'application/json',
      'authorization': 'Bearer $accessToken',
      'x-device-id': deviceId,
      'x-whyphy-app': 'flutter',
    };
  }

  bool _respostaSucesso(RespostaApi resposta) {
    if (!resposta.sucesso) {
      return false;
    }

    final Map<String, Object?> json = decodificarObjetoJson(resposta.corpo);
    return lerBoolJson(json, 'success');
  }

  bool _vazio(String? value) {
    return value == null || value.trim().isEmpty;
  }
}
