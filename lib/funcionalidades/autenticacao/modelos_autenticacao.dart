import '../../nucleo/rede/json_api.dart';

enum PapelWhyPhy {
  admin,
  aluno,
  guest,
  master,
  profissional;

  static PapelWhyPhy fromJson(String value) {
    return switch (value.trim().toUpperCase()) {
      'ADMIN' => PapelWhyPhy.admin,
      'ALUNO' => PapelWhyPhy.aluno,
      'GUEST' => PapelWhyPhy.guest,
      'MASTER' => PapelWhyPhy.master,
      'PROFISSIONAL' => PapelWhyPhy.profissional,
      _ => PapelWhyPhy.guest,
    };
  }

  String get valorApi {
    return switch (this) {
      PapelWhyPhy.admin => 'ADMIN',
      PapelWhyPhy.aluno => 'ALUNO',
      PapelWhyPhy.guest => 'GUEST',
      PapelWhyPhy.master => 'MASTER',
      PapelWhyPhy.profissional => 'PROFISSIONAL',
    };
  }

  String get rotulo {
    return switch (this) {
      PapelWhyPhy.admin => 'Administrador',
      PapelWhyPhy.aluno => 'Aluno',
      PapelWhyPhy.guest => 'Acesso',
      PapelWhyPhy.master => 'Master',
      PapelWhyPhy.profissional => 'Profissional',
    };
  }
}

class SessaoMobile {
  const SessaoMobile({
    required this.accessToken,
    required this.deviceId,
    required this.displayName,
    required this.expiresAt,
    required this.redirectPath,
    required this.role,
    required this.sessionId,
    required this.userId,
  });

  factory SessaoMobile.fromLoginJson(Map<String, Object?> json) {
    return SessaoMobile(
      accessToken: lerStringJson(json, 'accessToken'),
      deviceId: lerStringJson(json, 'deviceId'),
      displayName: lerStringJson(json, 'displayName'),
      expiresAt: lerStringJson(json, 'expiresAt'),
      redirectPath: lerStringJson(json, 'redirectPath'),
      role: PapelWhyPhy.fromJson(lerStringJson(json, 'role')),
      sessionId: lerStringJson(json, 'sessionId'),
      userId: lerStringJson(json, 'userId'),
    );
  }

  factory SessaoMobile.fromSessionJson({
    required String accessToken,
    required Map<String, Object?> json,
  }) {
    return SessaoMobile(
      accessToken: accessToken,
      deviceId: lerStringJson(json, 'deviceId'),
      displayName: lerStringJson(json, 'displayName'),
      expiresAt: lerStringJson(json, 'expiresAt'),
      redirectPath: lerStringJson(json, 'redirectPath'),
      role: PapelWhyPhy.fromJson(lerStringJson(json, 'role')),
      sessionId: lerStringJson(json, 'sessionId'),
      userId: lerStringJson(json, 'userId'),
    );
  }

  final String accessToken;
  final String deviceId;
  final String displayName;
  final String expiresAt;
  final String redirectPath;
  final PapelWhyPhy role;
  final String sessionId;
  final String userId;
}

class BootstrapWebview {
  const BootstrapWebview({
    required this.redirectPath,
    required this.webviewUrl,
  });

  factory BootstrapWebview.fromJson(Map<String, Object?> json) {
    return BootstrapWebview(
      redirectPath: lerStringJson(json, 'redirectPath'),
      webviewUrl: lerStringJson(json, 'webviewUrl'),
    );
  }

  final String redirectPath;
  final String webviewUrl;
}
