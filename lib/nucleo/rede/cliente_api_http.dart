import 'dart:convert';
import 'dart:io';

import 'cliente_api.dart';

class ClienteApiHttp implements ClienteApi {
  ClienteApiHttp({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Future<RespostaApi> enviar(RequisicaoApi requisicao) async {
    final HttpClientRequest request = await _abrir(
      requisicao.metodo,
      requisicao.uri,
    );
    _aplicarHeaders(request, requisicao.headers);

    if (requisicao.contentType != null) {
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        requisicao.contentType!,
      );
    }

    final List<int>? corpoBytes = requisicao.corpoBytes;
    if (corpoBytes != null) {
      request.add(corpoBytes);
    }

    return _fechar(request);
  }

  @override
  Future<RespostaApi> enviarMultipart(RequisicaoMultipartApi requisicao) async {
    final String boundary = 'whyphy-${DateTime.now().microsecondsSinceEpoch}';
    final HttpClientRequest request = await _abrir(
      requisicao.metodo,
      requisicao.uri,
    );
    _aplicarHeaders(request, requisicao.headers);
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );

    for (final MapEntry<String, String> campo in requisicao.campos.entries) {
      request.add(_texto('--$boundary\r\n'));
      request.add(
        _texto('Content-Disposition: form-data; name="${campo.key}"\r\n\r\n'),
      );
      request.add(_texto('${campo.value}\r\n'));
    }

    for (final CampoArquivoMultipart arquivo in requisicao.arquivos) {
      final File file = File(arquivo.caminhoLocal);
      request.add(_texto('--$boundary\r\n'));
      request.add(
        _texto(
          'Content-Disposition: form-data; name="${arquivo.nomeCampo}"; filename="${arquivo.nomeArquivo}"\r\n',
        ),
      );
      request.add(_texto('Content-Type: ${arquivo.contentType}\r\n\r\n'));
      await request.addStream(file.openRead());
      request.add(_texto('\r\n'));
    }

    request.add(_texto('--$boundary--\r\n'));

    return _fechar(request);
  }

  Future<HttpClientRequest> _abrir(MetodoHttp metodo, Uri uri) {
    return switch (metodo) {
      MetodoHttp.get => _httpClient.getUrl(uri),
      MetodoHttp.post => _httpClient.postUrl(uri),
      MetodoHttp.put => _httpClient.putUrl(uri),
      MetodoHttp.patch => _httpClient.patchUrl(uri),
      MetodoHttp.delete => _httpClient.deleteUrl(uri),
    };
  }

  void _aplicarHeaders(HttpClientRequest request, Map<String, String> headers) {
    for (final MapEntry<String, String> header in headers.entries) {
      request.headers.set(header.key, header.value);
    }
  }

  Future<RespostaApi> _fechar(HttpClientRequest request) async {
    final HttpClientResponse response = await request.close();
    final String corpo = await utf8.decoder.bind(response).join();
    final Map<String, String> headers = <String, String>{};

    response.headers.forEach((String name, List<String> values) {
      headers[name] = values.join(',');
    });

    return RespostaApi(
      codigoStatus: response.statusCode,
      corpo: corpo,
      headers: headers,
    );
  }

  List<int> _texto(String value) {
    return utf8.encode(value);
  }
}
