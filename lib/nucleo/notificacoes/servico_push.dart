class RegistroPush {
  const RegistroPush({
    this.appVersion,
    required this.token,
    required this.plataforma,
  });

  final String? appVersion;
  final String token;
  final String plataforma;
}

abstract interface class ServicoPush {
  Future<void> inicializar();

  Future<RegistroPush?> obterRegistro();

  Future<bool> registrar(RegistroPush registro);

  Future<bool> remover();
}
