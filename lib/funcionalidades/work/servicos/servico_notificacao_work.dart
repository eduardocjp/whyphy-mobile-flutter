import 'package:flutter/services.dart';

import '../../../work/models/work_modelos.dart';

class ServicoNotificacaoWork {
  const ServicoNotificacaoWork();

  static const MethodChannel _canal = MethodChannel(
    'br.com.whyphy/notificacoes_locais',
  );

  Future<void> agendarFase(SnapshotSessaoWork snapshot) async {
    final int? endsAtMs = snapshot.endsAtMs;

    if (!snapshot.ativo || endsAtMs == null) {
      return;
    }

    if (snapshot.phase == FaseSessaoWork.exercicioRodando) {
      return;
    }

    final _TextoNotificacaoWork texto = _textoParaFase(snapshot.phase);

    try {
      await _canal.invokeMethod<void>('agendar', <String, Object?>{
        'action': 'schedule',
        'body': texto.corpo,
        'notificationId': snapshot.notificationId,
        'routePath': '/work?resume=1',
        'title': texto.titulo,
        'triggerAtMillis': endsAtMs,
        'type': 'workout_phase',
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> cancelarFase(SnapshotSessaoWork snapshot) {
    return cancelarPorId(snapshot.notificationId);
  }

  Future<void> cancelarPorId(String notificationId) async {
    if (notificationId.trim().isEmpty) {
      return;
    }

    try {
      await _canal.invokeMethod<void>('cancelar', <String, Object?>{
        'notificationId': notificationId,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  _TextoNotificacaoWork _textoParaFase(FaseSessaoWork fase) {
    return switch (fase) {
      FaseSessaoWork.descansoSerie => const _TextoNotificacaoWork(
        titulo: 'Hora da proxima serie',
        corpo: 'O descanso terminou.',
      ),
      FaseSessaoWork.transicaoProximoExercicio => const _TextoNotificacaoWork(
        titulo: 'Proximo exercicio',
        corpo: 'A transicao do treino terminou.',
      ),
      FaseSessaoWork.cardioRodando => const _TextoNotificacaoWork(
        titulo: 'Cardio concluido',
        corpo: 'O tempo previsto de cardio terminou.',
      ),
      _ => const _TextoNotificacaoWork(
        titulo: 'WhyPhy Work',
        corpo: 'Seu treino precisa de atencao.',
      ),
    };
  }
}

class _TextoNotificacaoWork {
  const _TextoNotificacaoWork({required this.corpo, required this.titulo});

  final String corpo;
  final String titulo;
}
