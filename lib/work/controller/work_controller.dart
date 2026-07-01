import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../funcionalidades/work/servicos/servico_execucao_work.dart';
import '../models/work_modelos.dart';

enum EtapaWorkNativo {
  carregando,
  historico,
  selecao,
  exercicio,
  cardio,
  concluido,
  erro,
}

class ControladorWorkNativo extends ChangeNotifier {
  ControladorWorkNativo({
    required this.servicoExecucaoWork,
    this.onResultadoWeb,
  });

  static const int _extraTransicaoExercicioSegundos = 20;

  final void Function(ResultadoEventoWork resultado)? onResultadoWeb;
  final ServicoExecucaoWork servicoExecucaoWork;

  BootstrapWorkMobile? _bootstrap;
  FichaWork? _workout;
  SnapshotSessaoWork? _snapshot;
  EtapaWorkNativo _etapa = EtapaWorkNativo.carregando;
  String? _erro;
  TaxaKcalWork? _taxaKcal;
  Timer? _timer;
  ResultadoConclusaoWork? _resultadoConclusao;
  final Map<String, Set<int>> _seriesConcluidas = <String, Set<int>>{};
  bool _sincronizacaoEmAndamento = false;

  BootstrapWorkMobile? get bootstrap => _bootstrap;
  EtapaWorkNativo get etapa => _etapa;
  String? get erro => _erro;
  ResultadoConclusaoWork? get resultadoConclusao => _resultadoConclusao;
  SnapshotSessaoWork? get snapshot => _snapshot;
  TaxaKcalWork? get taxaKcal => _taxaKcal;
  FichaWork? get workout => _workout;

  int get cardioElapsedSeconds {
    return _snapshot?.cardioElapsedSeconds ?? 0;
  }

  int get elapsedSeconds {
    return _snapshot?.elapsedSeconds ?? 0;
  }

  int get exerciseElapsedSeconds {
    return _snapshot?.exerciseElapsedSeconds ?? 0;
  }

  int get totalElapsedSeconds {
    return _snapshot?.totalElapsedSeconds ?? 0;
  }

  int get segundosRestantesFase {
    final SnapshotSessaoWork? atual = _snapshot;

    if (atual == null) {
      return 0;
    }

    return servicoExecucaoWork.cronometro.segundosRestantes(atual);
  }

  bool get faseComContagemRegressiva {
    final FaseSessaoWork? fase = _snapshot?.phase;
    return fase == FaseSessaoWork.descansoSerie ||
        fase == FaseSessaoWork.transicaoProximoExercicio ||
        fase == FaseSessaoWork.cardioRodando;
  }

  bool get pausado {
    return _snapshot?.phase == FaseSessaoWork.pausado;
  }

  int get completedSeries {
    return _seriesConcluidas.values.fold<int>(
      0,
      (int total, Set<int> series) => total + series.length,
    );
  }

  int get totalSeries {
    final FichaWork? ficha = _workout;

    if (ficha == null) {
      return 0;
    }

    return ficha.exercises.fold<int>(
      0,
      (int total, ExercicioWork exercicio) => total + exercicio.sets,
    );
  }

  double get kcalEstimadas {
    final double taxa = _taxaKcal?.kcalPerMinute ?? 0;
    return taxa * (totalElapsedSeconds / 60);
  }

  ExercicioWork? get exercicioAtual {
    final FichaWork? ficha = _workout;
    final SnapshotSessaoWork? atual = _snapshot;

    if (ficha == null || atual == null || ficha.exercises.isEmpty) {
      return null;
    }

    final int index = atual.exerciseIndex.clamp(0, ficha.exercises.length - 1);
    return ficha.exercises[index];
  }

  int get indiceExercicioAtual {
    final FichaWork? ficha = _workout;
    final SnapshotSessaoWork? atual = _snapshot;

    if (ficha == null || atual == null || ficha.exercises.isEmpty) {
      return 0;
    }

    return atual.exerciseIndex.clamp(0, ficha.exercises.length - 1);
  }

  String get statusFase {
    final FaseSessaoWork? fase = _snapshot?.phase;

    return switch (fase) {
      FaseSessaoWork.descansoSerie => 'descanso',
      FaseSessaoWork.transicaoProximoExercicio => 'próximo exercício',
      FaseSessaoWork.cardioRodando => 'cardio em andamento',
      FaseSessaoWork.pausado => 'pausado',
      FaseSessaoWork.concluido => 'concluído',
      FaseSessaoWork.cancelado => 'cancelado',
      FaseSessaoWork.exercicioRodando => 'em execução',
      null => 'não iniciado',
    };
  }

  bool serieConcluida(String exerciseId, int setNumber) {
    return _seriesConcluidas[exerciseId]?.contains(setNumber) ?? false;
  }

  Future<void> inicializar(SnapshotSessaoWork? snapshotInicial) async {
    _etapa = EtapaWorkNativo.carregando;
    _erro = null;
    notifyListeners();

    try {
      final BootstrapWorkMobile bootstrap = await servicoExecucaoWork
          .repositorio
          .carregarBootstrap();
      final SnapshotSessaoWork? snapshotBase =
          snapshotInicial ??
          bootstrap.activeSession.snapshot ??
          servicoExecucaoWork.snapshotAtual;
      final SnapshotSessaoWork? snapshot = snapshotBase == null
          ? null
          : servicoExecucaoWork.cronometro.recalcular(snapshotBase);

      _bootstrap = bootstrap;

      if (snapshot != null) {
        final FichaWork? ficha = _encontrarFicha(bootstrap, snapshot.workoutId);

        if (ficha != null) {
          _workout = ficha;
          _snapshot = snapshot;
          _popularSeriesIniciais(ficha);
          _etapa =
              snapshot.phase == FaseSessaoWork.cardioRodando ||
                  (snapshot.phase == FaseSessaoWork.pausado &&
                      snapshot.cardioIndex != null)
              ? EtapaWorkNativo.cardio
              : EtapaWorkNativo.exercicio;
          _iniciarTimer();
          await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
          await _carregarTaxaKcal(
            kind: _etapa == EtapaWorkNativo.cardio ? 'cardio' : 'exercise',
          );
          return;
        }
      }

      _etapa = EtapaWorkNativo.historico;
      notifyListeners();
    } catch (erro) {
      _erro = erro.toString();
      _etapa = EtapaWorkNativo.erro;
      notifyListeners();
    }
  }

  void abrirSelecao() {
    _etapa = EtapaWorkNativo.selecao;
    notifyListeners();
  }

  void voltarParaHistorico() {
    _etapa = EtapaWorkNativo.historico;
    notifyListeners();
  }

  Future<void> selecionarFicha(FichaWork ficha) async {
    _workout = ficha;
    _snapshot = _criarSnapshotInicial(ficha);
    _resultadoConclusao = null;
    _popularSeriesIniciais(ficha);
    _etapa = EtapaWorkNativo.exercicio;
    _iniciarTimer();
    await _sincronizarSnapshot(metodo: 'abrirWorkNativo');
    await _carregarTaxaKcal();
  }

  Future<void> alternarSerie(String exerciseId, int setNumber) async {
    final Set<int> series = _seriesConcluidas.putIfAbsent(
      exerciseId,
      () => <int>{},
    );
    final bool estavaConcluida = series.contains(setNumber);

    if (estavaConcluida) {
      series.remove(setNumber);
      notifyListeners();
      return;
    }

    series.add(setNumber);

    final ExercicioWork? exercicio = exercicioAtual;

    if (exercicio?.id == exerciseId) {
      await _iniciarDescansoDaSerie(exercicio!, setNumber);
    } else {
      notifyListeners();
    }
  }

  bool exercicioAtualCompleto() {
    final ExercicioWork? exercicio = exercicioAtual;

    if (exercicio == null) {
      return false;
    }

    final Set<int> concluidas = _seriesConcluidas[exercicio.id] ?? <int>{};
    return concluidas.length >= exercicio.sets;
  }

  Future<void> avancarExercicio({required bool forcar}) async {
    final FichaWork? ficha = _workout;
    final SnapshotSessaoWork? atual = _snapshot;
    final ExercicioWork? exercicio = exercicioAtual;

    if (ficha == null || atual == null || exercicio == null) {
      return;
    }

    if (!forcar && !exercicioAtualCompleto()) {
      throw const WorkSeriesPendentes();
    }

    await servicoExecucaoWork.notificacaoWork.cancelarFase(atual);

    final int proximoIndice = atual.exerciseIndex + 1;

    if (proximoIndice >= ficha.exercises.length) {
      await iniciarCardio();
      return;
    }

    final int agora = servicoExecucaoWork.cronometro.agoraMs();
    final int descansoSegundos =
        (exercicio.restSeconds > 0
            ? exercicio.restSeconds
            : ficha.restSeconds) +
        _extraTransicaoExercicioSegundos;

    _snapshot = atual
        .recalcular(agora)
        .copiarCom(
          endsAtMs: agora + (descansoSegundos * 1000),
          phase: FaseSessaoWork.transicaoProximoExercicio,
          restSeconds: descansoSegundos,
          setIndex: exercicio.sets - 1,
          updatedAtMs: agora,
        );
    await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
  }

  Future<void> pularDescanso() async {
    final SnapshotSessaoWork? atual = _snapshot;

    if (atual == null) {
      return;
    }

    final ResultadoEventoWork resultado = await servicoExecucaoWork
        .tratarEventoBridge(
          metodo: 'cancelarDescansoWorkNativo',
          payload: atual.toJson(),
        );
    onResultadoWeb?.call(resultado);
    _snapshot = SnapshotSessaoWork.fromJson(resultado.payload);
    await _carregarTaxaKcal();
    notifyListeners();
  }

  Future<void> iniciarCardio() async {
    final SnapshotSessaoWork? atual = _snapshot;
    final FichaWork? ficha = _workout;

    if (atual == null || ficha == null) {
      return;
    }

    await servicoExecucaoWork.notificacaoWork.cancelarFase(atual);

    final int agora = servicoExecucaoWork.cronometro.agoraMs();
    final int cardioTargetSeconds = _parseCardioDurationSeconds(ficha.cardio);

    _snapshot = atual
        .recalcular(agora)
        .copiarCom(
          cardioIndex: 0,
          endsAtMs: cardioTargetSeconds > 0
              ? agora + (cardioTargetSeconds * 1000)
              : null,
          elapsedSeconds: atual.cardioElapsedSeconds,
          phase: FaseSessaoWork.cardioRodando,
          phaseBaseElapsedSeconds: atual.cardioElapsedSeconds,
          phaseStartedAtMs: agora,
          updatedAtMs: agora,
        );
    _etapa = EtapaWorkNativo.cardio;
    await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
    await _carregarTaxaKcal(kind: 'cardio');
  }

  Future<void> pausarOuRetomarCardio() async {
    final SnapshotSessaoWork? atual = _snapshot;

    if (atual == null) {
      return;
    }

    final int agora = servicoExecucaoWork.cronometro.agoraMs();
    _snapshot = atual.phase == FaseSessaoWork.pausado
        ? atual.retomar(agora)
        : atual.pausar(agora);
    await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
  }

  Future<void> concluirTreino() async {
    final FichaWork? ficha = _workout;
    final SnapshotSessaoWork? atual = _snapshot;

    if (ficha == null) {
      return;
    }

    if (atual != null) {
      await servicoExecucaoWork.notificacaoWork.cancelarFase(atual);
      _snapshot = atual.recalcular(servicoExecucaoWork.cronometro.agoraMs());
    }

    final ConclusaoWorkInput input = ConclusaoWorkInput(
      cardioDone: ficha.cardio == null || cardioElapsedSeconds > 0,
      completedSeries: _seriesParaConclusao(ficha),
      estimatedKcalBurned: kcalEstimadas,
      workoutId: ficha.id,
    );
    final ResultadoEventoWork resultado = await servicoExecucaoWork
        .tratarEventoBridge(
          metodo: 'finalizarWorkNativo',
          payload: input.toJson(),
        );

    onResultadoWeb?.call(resultado);
    _resultadoConclusao = ResultadoConclusaoWork.fromJson(resultado.payload);
    _etapa = EtapaWorkNativo.concluido;
    _timer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  FichaWork? _encontrarFicha(BootstrapWorkMobile bootstrap, String workoutId) {
    for (final FichaWork ficha in bootstrap.workouts) {
      if (ficha.id == workoutId) {
        return ficha;
      }
    }

    return null;
  }

  SnapshotSessaoWork _criarSnapshotInicial(FichaWork ficha) {
    final int agora = servicoExecucaoWork.cronometro.agoraMs();

    return SnapshotSessaoWork(
      cardioElapsedSeconds: 0,
      cardioIndex: null,
      elapsedSeconds: 0,
      endsAtMs: null,
      exerciseElapsedSeconds: 0,
      exerciseIndex: 0,
      pausedAccumulatedMs: 0,
      pausedFromPhase: null,
      pausedRemainingMs: null,
      phase: FaseSessaoWork.exercicioRodando,
      phaseBaseElapsedSeconds: 0,
      phaseStartedAtMs: agora,
      restSeconds: ficha.restSeconds,
      setIndex: 0,
      startedAtMs: agora,
      status: StatusSessaoWork.ativo,
      updatedAtMs: agora,
      workoutId: ficha.id,
    );
  }

  void _popularSeriesIniciais(FichaWork ficha) {
    _seriesConcluidas.clear();

    for (final ExercicioWork exercicio in ficha.exercises) {
      _seriesConcluidas.putIfAbsent(exercicio.id, () => <int>{});
    }
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final SnapshotSessaoWork? atual = _snapshot;

      if (atual == null || _sincronizacaoEmAndamento) {
        return;
      }

      final SnapshotSessaoWork recalculado = servicoExecucaoWork.cronometro
          .recalcular(atual);
      final bool mudouFase =
          recalculado.phase != atual.phase ||
          recalculado.exerciseIndex != atual.exerciseIndex ||
          recalculado.setIndex != atual.setIndex ||
          recalculado.cardioIndex != atual.cardioIndex;

      _snapshot = recalculado;
      notifyListeners();

      if (mudouFase) {
        unawaited(_sincronizarSnapshot(metodo: 'sincronizarWorkNativo'));
        unawaited(_carregarTaxaKcal());
      }
    });
  }

  Future<void> _iniciarDescansoDaSerie(
    ExercicioWork exercicio,
    int setNumber,
  ) async {
    final SnapshotSessaoWork? atual = _snapshot;

    if (atual == null) {
      return;
    }

    final int agora = servicoExecucaoWork.cronometro.agoraMs();
    final bool ultimaSerie = setNumber >= exercicio.sets;
    final int descansoSegundos = exercicio.restSeconds > 0
        ? exercicio.restSeconds
        : (_workout?.restSeconds ?? 0);

    if (ultimaSerie || descansoSegundos <= 0) {
      _snapshot = atual
          .recalcular(agora)
          .copiarCom(
            phase: FaseSessaoWork.exercicioRodando,
            setIndex: setNumber - 1,
            updatedAtMs: agora,
          );
    } else {
      _snapshot = atual
          .recalcular(agora)
          .copiarCom(
            endsAtMs: agora + (descansoSegundos * 1000),
            phase: FaseSessaoWork.descansoSerie,
            restSeconds: descansoSegundos,
            setIndex: setNumber - 1,
            updatedAtMs: agora,
          );
    }

    await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
  }

  Future<void> _sincronizarSnapshot({required String metodo}) async {
    final SnapshotSessaoWork? atual = _snapshot;

    if (atual == null) {
      return;
    }

    _sincronizacaoEmAndamento = true;

    try {
      final ResultadoEventoWork resultado = await servicoExecucaoWork
          .tratarEventoBridge(metodo: metodo, payload: atual.toJson());
      onResultadoWeb?.call(resultado);

      if (resultado.acao == AcaoWebWork.aplicarSnapshot) {
        _snapshot = SnapshotSessaoWork.fromJson(resultado.payload);
      }
    } finally {
      _sincronizacaoEmAndamento = false;
    }

    notifyListeners();
  }

  Future<void> _carregarTaxaKcal({String kind = 'exercise'}) async {
    final FichaWork? ficha = _workout;
    final ExercicioWork? exercicio = exercicioAtual;

    if (ficha == null) {
      return;
    }

    try {
      _taxaKcal = await servicoExecucaoWork.repositorio.obterTaxaKcal(
        exerciseId: kind == 'exercise' ? exercicio?.id : null,
        kind: kind,
        workoutId: ficha.id,
      );
      notifyListeners();
    } catch (_) {
      return;
    }
  }

  List<SerieConcluidaWork> _seriesParaConclusao(FichaWork ficha) {
    return ficha.exercises
        .expand((ExercicioWork exercicio) {
          return List<SerieConcluidaWork>.generate(exercicio.sets, (int index) {
            final int setNumber = index + 1;

            return SerieConcluidaWork(
              completed: serieConcluida(exercicio.id, setNumber),
              exerciseId: exercicio.id,
              repetitionsDone: _parseInteiro(exercicio.reps),
              setNumber: setNumber,
              weightUsedKg: _parseDouble(exercicio.weight),
            );
          });
        })
        .toList(growable: false);
  }

  int _parseCardioDurationSeconds(CardioWork? cardio) {
    if (cardio == null) {
      return 0;
    }

    final RegExpMatch? match = RegExp(r'\d+').firstMatch(cardio.duration);

    if (match == null) {
      return 0;
    }

    final int minutes = int.tryParse(match.group(0) ?? '') ?? 0;
    return minutes * 60;
  }

  int? _parseInteiro(String value) {
    final RegExpMatch? match = RegExp(r'\d+').firstMatch(value);

    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(0) ?? '');
  }

  double? _parseDouble(String value) {
    final RegExpMatch? match = RegExp(r'\d+(?:[,.]\d+)?').firstMatch(value);

    if (match == null) {
      return null;
    }

    return double.tryParse((match.group(0) ?? '').replaceAll(',', '.'));
  }
}

class WorkSeriesPendentes implements Exception {
  const WorkSeriesPendentes();
}
