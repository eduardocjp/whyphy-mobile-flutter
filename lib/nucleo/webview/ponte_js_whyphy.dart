enum TipoMensagemPonte { upload, downloadPdf, abrirExterno, desconhecida }

class MensagemPonteWhyPhy {
  const MensagemPonteWhyPhy({required this.tipo, required this.conteudo});

  final TipoMensagemPonte tipo;
  final String conteudo;
}

abstract interface class PonteJsWhyPhy {
  Future<void> tratar(MensagemPonteWhyPhy mensagem);
}
