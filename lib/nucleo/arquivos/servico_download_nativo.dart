class ArquivoBaixado {
  const ArquivoBaixado({
    required this.nomeArquivo,
    required this.caminhoLocal,
    this.contentType,
  });

  final String nomeArquivo;
  final String caminhoLocal;
  final String? contentType;
}

abstract interface class ServicoDownloadNativo {
  Future<ArquivoBaixado> baixar(Uri url, {String? nomeArquivo});
}
