import 'dart:convert';

import '../../app/configuracao_app.dart';
import '../armazenamento/servico_armazenamento_seguro.dart';
import '../rede/cliente_api.dart';
import '../rede/json_api.dart';
import '../rede/rotas_api_mobile.dart';
import 'servico_upload_nativo.dart';

class ResultadoUploadMobile {
  const ResultadoUploadMobile({
    required this.corpo,
    required this.mensagem,
    required this.sucesso,
  });

  final String corpo;
  final String mensagem;
  final bool sucesso;
}

class ServicoUploadMobile {
  const ServicoUploadMobile({
    required this.armazenamento,
    required this.clienteApi,
    required this.configuracao,
  });

  final ServicoArmazenamentoSeguro armazenamento;
  final ClienteApi clienteApi;
  final ConfiguracaoApp configuracao;

  Future<ResultadoUploadMobile> enviarFotoPerfil(ArquivoSelecionado arquivo) {
    return _enviarMultipart(
      arquivos: <CampoArquivoMultipart>[_arquivo('photo', arquivo)],
      metodo: MetodoHttp.post,
      path: RotasApiMobile.uploadPerfil,
    );
  }

  Future<ResultadoUploadMobile> enviarFotoRefeicao({
    required ArquivoSelecionado arquivo,
    required String refeicaoLogId,
    String? mealId,
  }) {
    return _enviarMultipart(
      arquivos: <CampoArquivoMultipart>[_arquivo('photo', arquivo)],
      campos: <String, String>{
        'refeicaoLogId': refeicaoLogId,
        if (mealId != null && mealId.trim().isNotEmpty) 'mealId': mealId,
      },
      metodo: MetodoHttp.post,
      path: RotasApiMobile.uploadRefeicao,
    );
  }

  Future<ResultadoUploadMobile> enviarFotoFisica(ArquivoSelecionado arquivo) {
    return _enviarMultipart(
      arquivos: <CampoArquivoMultipart>[_arquivo('photo', arquivo)],
      metodo: MetodoHttp.post,
      path: RotasApiMobile.uploadFisico,
    );
  }

  Future<ResultadoUploadMobile> atualizarFotoFisica({
    required ArquivoSelecionado arquivo,
    required String mediaId,
  }) {
    return _enviarMultipart(
      arquivos: <CampoArquivoMultipart>[_arquivo('photo', arquivo)],
      campos: <String, String>{'mediaId': mediaId},
      metodo: MetodoHttp.put,
      path: RotasApiMobile.uploadFisico,
    );
  }

  Future<ResultadoUploadMobile> removerFotoFisica(String mediaId) {
    return _enviarJson(
      body: <String, Object?>{'mediaId': mediaId},
      metodo: MetodoHttp.delete,
      path: RotasApiMobile.uploadFisico,
    );
  }

  Future<ResultadoUploadMobile> listarExames() {
    return _enviarJson(
      body: const <String, Object?>{},
      metodo: MetodoHttp.get,
      path: RotasApiMobile.uploadExame,
    );
  }

  Future<ResultadoUploadMobile> enviarExames(
    List<ArquivoSelecionado> arquivos,
  ) {
    return _enviarMultipart(
      arquivos: arquivos
          .map((ArquivoSelecionado arquivo) => _arquivo('files[]', arquivo))
          .toList(growable: false),
      metodo: MetodoHttp.post,
      path: RotasApiMobile.uploadExame,
    );
  }

  CampoArquivoMultipart _arquivo(String nomeCampo, ArquivoSelecionado arquivo) {
    return CampoArquivoMultipart(
      caminhoLocal: arquivo.caminhoLocal,
      contentType: arquivo.mimeType ?? 'application/octet-stream',
      nomeArquivo: arquivo.nome,
      nomeCampo: nomeCampo,
    );
  }

  Future<ResultadoUploadMobile> _enviarJson({
    required Map<String, Object?> body,
    required MetodoHttp metodo,
    required String path,
  }) async {
    final Map<String, String>? headers = await _headersAutenticados();

    if (headers == null) {
      return const ResultadoUploadMobile(
        corpo: '',
        mensagem: 'Sessão mobile não encontrada.',
        sucesso: false,
      );
    }

    final RespostaApi resposta = await clienteApi.enviar(
      RequisicaoApi(
        metodo: metodo,
        uri: configuracao.resolverApi(path),
        contentType: metodo == MetodoHttp.get
            ? null
            : 'application/json; charset=utf-8',
        headers: headers,
        corpoBytes: metodo == MetodoHttp.get
            ? null
            : utf8.encode(codificarObjetoJson(body)),
      ),
    );

    return _mapearResultado(resposta);
  }

  Future<ResultadoUploadMobile> _enviarMultipart({
    required List<CampoArquivoMultipart> arquivos,
    required MetodoHttp metodo,
    required String path,
    Map<String, String> campos = const <String, String>{},
  }) async {
    final Map<String, String>? headers = await _headersAutenticados();

    if (headers == null) {
      return const ResultadoUploadMobile(
        corpo: '',
        mensagem: 'Sessão mobile não encontrada.',
        sucesso: false,
      );
    }

    final RespostaApi resposta = await clienteApi.enviarMultipart(
      RequisicaoMultipartApi(
        arquivos: arquivos,
        campos: campos,
        headers: headers,
        metodo: metodo,
        uri: configuracao.resolverApi(path),
      ),
    );

    return _mapearResultado(resposta);
  }

  Future<Map<String, String>?> _headersAutenticados() async {
    final String? accessToken = await armazenamento.ler(
      ChavesArmazenamentoSeguro.tokenAcesso,
    );
    final String? deviceId = await armazenamento.ler(
      ChavesArmazenamentoSeguro.deviceId,
    );

    if (_vazio(accessToken) || _vazio(deviceId)) {
      return null;
    }

    return <String, String>{
      'accept': 'application/json',
      'authorization': 'Bearer $accessToken',
      'x-device-id': deviceId!,
      'x-whyphy-app': 'flutter',
    };
  }

  ResultadoUploadMobile _mapearResultado(RespostaApi resposta) {
    final Map<String, Object?> json = decodificarObjetoJson(resposta.corpo);

    return ResultadoUploadMobile(
      corpo: resposta.corpo,
      mensagem: lerStringOpcionalJson(json, 'message') ?? '',
      sucesso: resposta.sucesso && lerBoolJson(json, 'success'),
    );
  }

  bool _vazio(String? value) {
    return value == null || value.trim().isEmpty;
  }
}
