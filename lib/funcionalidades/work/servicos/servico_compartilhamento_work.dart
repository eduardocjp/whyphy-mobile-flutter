import 'package:flutter/services.dart';

class ServicoCompartilhamentoWork {
  const ServicoCompartilhamentoWork();

  static const MethodChannel _canal = MethodChannel(
    'br.com.whyphy/compartilhamento_work',
  );

  Future<bool> compartilharTexto({
    required String texto,
    required String titulo,
    String tipo = 'simples',
  }) async {
    if (texto.trim().isEmpty) {
      return false;
    }

    try {
      return await _canal.invokeMethod<bool>(
            'compartilharTexto',
            <String, String>{'texto': texto, 'tipo': tipo, 'titulo': titulo},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> abrirCamera({
    required String texto,
    required String titulo,
    required String tipo,
  }) {
    return _invocarAcaoMidia(
      metodo: 'abrirCamera',
      texto: texto,
      tipo: tipo,
      titulo: titulo,
    );
  }

  Future<bool> abrirGaleria({
    required String texto,
    required String titulo,
    required String tipo,
  }) {
    return _invocarAcaoMidia(
      metodo: 'abrirGaleria',
      texto: texto,
      tipo: tipo,
      titulo: titulo,
    );
  }

  Future<bool> _invocarAcaoMidia({
    required String metodo,
    required String texto,
    required String tipo,
    required String titulo,
  }) async {
    try {
      return await _canal.invokeMethod<bool>(metodo, <String, String>{
            'texto': texto,
            'tipo': tipo,
            'titulo': titulo,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
