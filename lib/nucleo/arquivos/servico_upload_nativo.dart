class ArquivoSelecionado {
  const ArquivoSelecionado({
    required this.nome,
    required this.caminhoLocal,
    required this.tamanhoBytes,
    this.mimeType,
  });

  final String nome;
  final String caminhoLocal;
  final int tamanhoBytes;
  final String? mimeType;
}

abstract interface class ServicoUploadNativo {
  Future<ArquivoSelecionado?> selecionarArquivo();
}
