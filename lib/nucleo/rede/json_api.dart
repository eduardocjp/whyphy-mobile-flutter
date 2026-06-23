import 'dart:convert';

class ErroApi implements Exception {
  const ErroApi({
    required this.codigoStatus,
    required this.mensagem,
    this.codigo,
  });

  final String? codigo;
  final int codigoStatus;
  final String mensagem;

  @override
  String toString() {
    return mensagem;
  }
}

String codificarObjetoJson(Map<String, Object?> value) {
  return jsonEncode(value);
}

Map<String, Object?> decodificarObjetoJson(String value) {
  if (value.trim().isEmpty) {
    return <String, Object?>{};
  }

  final Object? decoded = jsonDecode(value) as Object?;

  if (decoded is Map<String, Object?>) {
    return decoded;
  }

  throw const FormatException('Resposta JSON inválida.');
}

Map<String, Object?> lerObjetoJson(Map<String, Object?> json, String chave) {
  final Object? value = json[chave];

  if (value is Map<String, Object?>) {
    return value;
  }

  return <String, Object?>{};
}

List<Object?> lerListaJson(Map<String, Object?> json, String chave) {
  final Object? value = json[chave];

  if (value is List<Object?>) {
    return value;
  }

  return <Object?>[];
}

String lerStringJson(Map<String, Object?> json, String chave) {
  final Object? value = json[chave];

  if (value is String) {
    return value;
  }

  return '';
}

String? lerStringOpcionalJson(Map<String, Object?> json, String chave) {
  final Object? value = json[chave];

  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  return null;
}

bool lerBoolJson(Map<String, Object?> json, String chave) {
  final Object? value = json[chave];
  return value is bool && value;
}
