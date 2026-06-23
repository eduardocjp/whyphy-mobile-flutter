class NotificacaoLocal {
  const NotificacaoLocal({
    required this.titulo,
    required this.corpo,
    this.rotaInterna,
  });

  final String titulo;
  final String corpo;
  final String? rotaInterna;
}

abstract interface class ServicoNotificacaoLocal {
  Future<void> mostrar(NotificacaoLocal notificacao);
}
