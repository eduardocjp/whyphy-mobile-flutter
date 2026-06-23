enum MetodoHttp { get, post, put, patch, delete }

class RequisicaoApi {
  const RequisicaoApi({
    required this.metodo,
    required this.uri,
    this.contentType,
    this.corpoBytes,
    this.headers = const <String, String>{},
  });

  final MetodoHttp metodo;
  final Uri uri;
  final String? contentType;
  final List<int>? corpoBytes;
  final Map<String, String> headers;
}

class RespostaApi {
  const RespostaApi({
    required this.codigoStatus,
    required this.corpo,
    this.headers = const <String, String>{},
  });

  final int codigoStatus;
  final String corpo;
  final Map<String, String> headers;

  bool get sucesso => codigoStatus >= 200 && codigoStatus < 300;
}

class CampoArquivoMultipart {
  const CampoArquivoMultipart({
    required this.caminhoLocal,
    required this.nomeArquivo,
    required this.nomeCampo,
    this.contentType = 'application/octet-stream',
  });

  final String caminhoLocal;
  final String nomeArquivo;
  final String nomeCampo;
  final String contentType;
}

class RequisicaoMultipartApi {
  const RequisicaoMultipartApi({
    required this.arquivos,
    required this.metodo,
    required this.uri,
    this.campos = const <String, String>{},
    this.headers = const <String, String>{},
  });

  final List<CampoArquivoMultipart> arquivos;
  final Map<String, String> campos;
  final Map<String, String> headers;
  final MetodoHttp metodo;
  final Uri uri;
}

abstract interface class ClienteApi {
  Future<RespostaApi> enviar(RequisicaoApi requisicao);

  Future<RespostaApi> enviarMultipart(RequisicaoMultipartApi requisicao);
}
