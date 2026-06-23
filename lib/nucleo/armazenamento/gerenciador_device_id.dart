import 'dart:math';

import 'servico_armazenamento_seguro.dart';

class GerenciadorDeviceId {
  const GerenciadorDeviceId({required this.armazenamento});

  final ServicoArmazenamentoSeguro armazenamento;

  Future<String> obterOuCriar() async {
    final String? deviceIdSalvo = await armazenamento.ler(
      ChavesArmazenamentoSeguro.deviceId,
    );

    if (deviceIdSalvo != null && deviceIdSalvo.trim().isNotEmpty) {
      return deviceIdSalvo;
    }

    final String novoDeviceId = _gerarUuidV4();
    await armazenamento.salvar(
      chave: ChavesArmazenamentoSeguro.deviceId,
      valor: novoDeviceId,
    );

    return novoDeviceId;
  }

  String _gerarUuidV4() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hexByte(int value) => value.toRadixString(16).padLeft(2, '0');

    final String hex = bytes.map(hexByte).join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
