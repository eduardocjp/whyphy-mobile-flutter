import 'package:flutter/services.dart';

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

class ServicoUploadNativoCanal implements ServicoUploadNativo {
  const ServicoUploadNativoCanal();

  static const MethodChannel _canal = MethodChannel(
    'br.com.whyphy/upload_nativo',
  );

  @override
  Future<ArquivoSelecionado?> selecionarArquivo() async {
    final Object? resposta = await _canal.invokeMethod<Object?>(
      'selecionarArquivo',
    );

    if (resposta is! Map<Object?, Object?>) {
      return null;
    }

    final String nome = _lerString(resposta, 'nome');
    final String caminhoLocal = _lerString(resposta, 'caminhoLocal');
    final int tamanhoBytes = _lerInt(resposta, 'tamanhoBytes');

    if (nome.isEmpty || caminhoLocal.isEmpty || tamanhoBytes <= 0) {
      return null;
    }

    return ArquivoSelecionado(
      caminhoLocal: caminhoLocal,
      mimeType: _lerString(resposta, 'mimeType'),
      nome: nome,
      tamanhoBytes: tamanhoBytes,
    );
  }

  String _lerString(Map<Object?, Object?> map, String chave) {
    final Object? valor = map[chave];

    if (valor is String) {
      return valor.trim();
    }

    return '';
  }

  int _lerInt(Map<Object?, Object?> map, String chave) {
    final Object? valor = map[chave];

    if (valor is int) {
      return valor;
    }

    if (valor is double) {
      return valor.toInt();
    }

    return 0;
  }
}
