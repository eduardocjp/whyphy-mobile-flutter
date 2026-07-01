import 'dart:convert';

import '../../app/configuracao_app.dart';
import '../../nucleo/armazenamento/servico_armazenamento_seguro.dart';
import '../../nucleo/rede/cliente_api.dart';
import '../../nucleo/rede/json_api.dart';
import '../../nucleo/rede/rotas_api_mobile.dart';
import '../models/work_modelos.dart';

class WorkApi {
  const WorkApi({
    required this.armazenamento,
    required this.clienteApi,
    required this.configuracao,
  });

  final ServicoArmazenamentoSeguro armazenamento;
  final ClienteApi clienteApi;
  final ConfiguracaoApp configuracao;

  Future<BootstrapWorkMobile> carregarBootstrap() async {
    final RespostaApi resposta = await clienteApi.enviar(
      RequisicaoApi(
        metodo: MetodoHttp.get,
        uri: configuracao.resolverApi(RotasApiMobile.work),
        headers: await _headersAutenticados(),
      ),
    );

    return BootstrapWorkMobile.fromJson(_validarResposta(resposta));
  }

  Future<SessaoWorkPayload> obterSessao() async {
    final RespostaApi resposta = await clienteApi.enviar(
      RequisicaoApi(
        metodo: MetodoHttp.get,
        uri: configuracao.resolverApi(RotasApiMobile.workSessao),
        headers: await _headersAutenticados(),
      ),
    );

    return SessaoWorkPayload.fromJson(
      lerObjetoJson(_validarResposta(resposta), 'session'),
    );
  }

  Future<SessaoWorkPayload> salvarSessao(SnapshotSessaoWork snapshot) async {
    final RespostaApi resposta = await clienteApi.enviar(
      RequisicaoApi(
        metodo: MetodoHttp.post,
        uri: configuracao.resolverApi(RotasApiMobile.workSessao),
        contentType: 'application/json; charset=utf-8',
        headers: await _headersAutenticados(),
        corpoBytes: utf8.encode(
          codificarObjetoJson(<String, Object?>{
            'action': 'upsert',
            'snapshot': snapshot.toJson(),
          }),
        ),
      ),
    );

    return SessaoWorkPayload.fromJson(
      lerObjetoJson(_validarResposta(resposta), 'session'),
    );
  }

  Future<SessaoWorkPayload> limparSessao() async {
    final RespostaApi resposta = await clienteApi.enviar(
      RequisicaoApi(
        metodo: MetodoHttp.post,
        uri: configuracao.resolverApi(RotasApiMobile.workSessao),
        contentType: 'application/json; charset=utf-8',
        headers: await _headersAutenticados(),
        corpoBytes: utf8.encode(
          codificarObjetoJson(<String, Object?>{'action': 'clear'}),
        ),
      ),
    );

    return SessaoWorkPayload.fromJson(
      lerObjetoJson(_validarResposta(resposta), 'session'),
    );
  }

  Future<TaxaKcalWork> obterTaxaKcal({
    required String workoutId,
    required String kind,
    String? exerciseId,
  }) async {
    final Uri uri = configuracao
        .resolverApi(RotasApiMobile.workKcalRate)
        .replace(
          queryParameters: <String, String>{
            'kind': kind,
            'workoutId': workoutId,
            if (exerciseId != null && exerciseId.trim().isNotEmpty)
              'exerciseId': exerciseId.trim(),
          },
        );

    final RespostaApi resposta = await clienteApi.enviar(
      RequisicaoApi(
        metodo: MetodoHttp.get,
        uri: uri,
        headers: await _headersAutenticados(),
      ),
    );

    return TaxaKcalWork.fromJson(_validarResposta(resposta));
  }

  Future<ResultadoConclusaoWork> concluir(ConclusaoWorkInput input) async {
    final RespostaApi resposta = await clienteApi.enviar(
      RequisicaoApi(
        metodo: MetodoHttp.post,
        uri: configuracao.resolverApi(RotasApiMobile.workConcluir),
        contentType: 'application/json; charset=utf-8',
        headers: await _headersAutenticados(),
        corpoBytes: utf8.encode(codificarObjetoJson(input.toJson())),
      ),
    );

    return ResultadoConclusaoWork.fromJson(_validarResposta(resposta));
  }

  Future<Map<String, String>> _headersAutenticados() async {
    final String? accessToken = await armazenamento.ler(
      ChavesArmazenamentoSeguro.tokenAcesso,
    );
    final String? deviceId = await armazenamento.ler(
      ChavesArmazenamentoSeguro.deviceId,
    );

    if (_vazio(accessToken) || _vazio(deviceId)) {
      throw const ErroApi(
        codigoStatus: 401,
        mensagem: 'Sessao mobile do Work indisponivel.',
      );
    }

    return <String, String>{
      'accept': 'application/json',
      'authorization': 'Bearer $accessToken',
      'x-device-id': deviceId!,
      'x-whyphy-app': ConfiguracaoApp.identificadorAppWebview,
    };
  }

  Map<String, Object?> _validarResposta(RespostaApi resposta) {
    final Map<String, Object?> json = decodificarObjetoJson(resposta.corpo);

    if (resposta.sucesso && lerBoolJson(json, 'success')) {
      return json;
    }

    throw ErroApi(
      codigo: lerStringOpcionalJson(json, 'code'),
      codigoStatus: resposta.codigoStatus,
      mensagem:
          lerStringOpcionalJson(json, 'message') ??
          'Nao foi possivel sincronizar o Work.',
    );
  }

  bool _vazio(String? value) {
    return value == null || value.trim().isEmpty;
  }
}
