import 'package:flutter/foundation.dart';

import '../../../nucleo/rede/json_api.dart';
import '../../../work/dados/work_repositorio.dart';
import '../../../work/models/work_modelos.dart';
import 'servico_cronometro_work.dart';
import 'servico_notificacao_work.dart';

enum AcaoWebWork {
  aplicarSnapshot('aplicarSnapshot'),
  descansoConcluido('descansoConcluido'),
  exercicioAvancado('exercicioAvancado'),
  finalizar('finalizar'),
  erro('erro');

  const AcaoWebWork(this.metodo);

  final String metodo;
}

class ResultadoEventoWork {
  const ResultadoEventoWork({required this.acao, required this.payload});

  final AcaoWebWork acao;
  final Map<String, Object?> payload;
}

class ServicoExecucaoWork extends ChangeNotifier {
  ServicoExecucaoWork({
    required this.cronometro,
    required this.notificacaoWork,
    required this.repositorio,
  });

  final ServicoCronometroWork cronometro;
  final ServicoNotificacaoWork notificacaoWork;
  final WorkRepositorio repositorio;

  SnapshotSessaoWork? _snapshotAtual;
  bool _sincronizando = false;

  SnapshotSessaoWork? get snapshotAtual => _snapshotAtual;

  bool get sincronizando => _sincronizando;

  Future<ResultadoEventoWork> tratarEventoBridge({
    required String metodo,
    required Map<String, Object?> payload,
  }) async {
    try {
      return switch (metodo) {
        'abrirWorkNativo' => _abrirOuSincronizar(payload),
        'sincronizarWorkNativo' => _abrirOuSincronizar(payload),
        'pausarWorkNativo' => _pausar(payload),
        'cancelarDescansoWorkNativo' => _cancelarDescanso(payload),
        'finalizarWorkNativo' => _finalizar(payload),
        _ => _erro('Evento Work nao suportado pelo app.'),
      };
    } catch (erro) {
      return _erro(erro.toString());
    }
  }

  Future<void> restaurarCheckpoint() async {
    final SnapshotSessaoWork? snapshot = await repositorio
        .carregarCheckpointLocal();

    if (snapshot == null) {
      return;
    }

    _definirSnapshot(cronometro.recalcular(snapshot));
    await notificacaoWork.agendarFase(_snapshotAtual!);
  }

  Future<ResultadoEventoWork> _abrirOuSincronizar(
    Map<String, Object?> payload,
  ) async {
    final SnapshotSessaoWork snapshot = _extrairSnapshot(payload);
    final SnapshotSessaoWork recalculado = cronometro.recalcular(snapshot);
    await _persistirSnapshot(recalculado);

    return ResultadoEventoWork(
      acao: AcaoWebWork.aplicarSnapshot,
      payload: recalculado.toJson(),
    );
  }

  Future<ResultadoEventoWork> _pausar(Map<String, Object?> payload) async {
    final SnapshotSessaoWork base = _extrairSnapshotOuAtual(payload);
    await notificacaoWork.cancelarFase(base);

    final SnapshotSessaoWork pausado = base.pausar(cronometro.agoraMs());
    await _persistirSnapshot(pausado);

    return ResultadoEventoWork(
      acao: AcaoWebWork.aplicarSnapshot,
      payload: pausado.toJson(),
    );
  }

  Future<ResultadoEventoWork> _cancelarDescanso(
    Map<String, Object?> payload,
  ) async {
    final SnapshotSessaoWork base = _extrairSnapshotOuAtual(payload);
    await notificacaoWork.cancelarFase(base);

    final SnapshotSessaoWork avancado = base.avancarDescanso(
      cronometro.agoraMs(),
    );
    await _persistirSnapshot(avancado);

    return ResultadoEventoWork(
      acao: AcaoWebWork.exercicioAvancado,
      payload: avancado.toJson(),
    );
  }

  Future<ResultadoEventoWork> _finalizar(Map<String, Object?> payload) async {
    final SnapshotSessaoWork? snapshot = _tentarExtrairSnapshot(payload);

    if (snapshot != null) {
      await notificacaoWork.cancelarFase(snapshot);
    }

    final ConclusaoWorkInput conclusao = ConclusaoWorkInput.fromJson(payload);
    final ResultadoConclusaoWork resultado = await repositorio.concluir(
      conclusao,
    );

    _definirSnapshot(null);

    return ResultadoEventoWork(
      acao: AcaoWebWork.finalizar,
      payload: resultado.toJson(),
    );
  }

  Future<void> _persistirSnapshot(SnapshotSessaoWork snapshot) async {
    final SnapshotSessaoWork? anterior = _snapshotAtual;
    _sincronizando = true;
    _definirSnapshot(snapshot);

    if (anterior != null &&
        anterior.notificationId != snapshot.notificationId) {
      await notificacaoWork.cancelarFase(anterior);
    }

    if (snapshot.ativo) {
      await repositorio.salvarCheckpoint(snapshot);
      await notificacaoWork.agendarFase(snapshot);
    } else {
      await repositorio.limparCheckpoint();
      await notificacaoWork.cancelarFase(snapshot);
    }

    _sincronizando = false;
    notifyListeners();
  }

  void _definirSnapshot(SnapshotSessaoWork? snapshot) {
    _snapshotAtual = snapshot;
    notifyListeners();
  }

  SnapshotSessaoWork _extrairSnapshotOuAtual(Map<String, Object?> payload) {
    return _tentarExtrairSnapshot(payload) ??
        _snapshotAtual ??
        (throw const FormatException('Snapshot Work ausente.'));
  }

  SnapshotSessaoWork _extrairSnapshot(Map<String, Object?> payload) {
    final SnapshotSessaoWork? snapshot = _tentarExtrairSnapshot(payload);

    if (snapshot == null) {
      throw const FormatException('Snapshot Work ausente.');
    }

    return snapshot;
  }

  SnapshotSessaoWork? _tentarExtrairSnapshot(Map<String, Object?> payload) {
    final Map<String, Object?> snapshotJson = lerObjetoJson(
      payload,
      'snapshot',
    );

    if (snapshotJson.isNotEmpty) {
      return SnapshotSessaoWork.fromJson(snapshotJson);
    }

    if (payload.containsKey('workoutId') && payload.containsKey('phase')) {
      return SnapshotSessaoWork.fromJson(payload);
    }

    return null;
  }

  ResultadoEventoWork _erro(String mensagem) {
    return ResultadoEventoWork(
      acao: AcaoWebWork.erro,
      payload: <String, Object?>{'message': mensagem, 'success': false},
    );
  }
}
