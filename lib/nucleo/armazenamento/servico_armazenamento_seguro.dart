import 'package:flutter/services.dart';

abstract interface class ServicoArmazenamentoSeguro {
  Future<String?> ler(String chave);

  Future<void> salvar({required String chave, required String valor});

  Future<void> remover(String chave);

  Future<void> limpar();
}

abstract final class ChavesArmazenamentoSeguro {
  static const String tokenAcesso = 'whyphy_token_acesso';
  static const String refreshToken = 'whyphy_refresh_token';
  static const String deviceId = 'whyphy_device_id';
  static const String sessaoMinima = 'whyphy_sessao_minima';
}

class ServicoArmazenamentoSeguroCanal implements ServicoArmazenamentoSeguro {
  const ServicoArmazenamentoSeguroCanal();

  static const MethodChannel _canal = MethodChannel(
    'br.com.whyphy/armazenamento_seguro',
  );

  @override
  Future<void> limpar() async {
    try {
      await _canal.invokeMethod<void>('limpar');
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<String?> ler(String chave) async {
    try {
      return _canal.invokeMethod<String>('ler', <String, String>{
        'chave': chave,
      });
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> remover(String chave) async {
    try {
      await _canal.invokeMethod<void>('remover', <String, String>{
        'chave': chave,
      });
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> salvar({required String chave, required String valor}) async {
    try {
      await _canal.invokeMethod<void>('salvar', <String, String>{
        'chave': chave,
        'valor': valor,
      });
    } on MissingPluginException {
      return;
    }
  }
}
