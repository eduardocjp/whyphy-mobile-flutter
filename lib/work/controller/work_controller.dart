import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../funcionalidades/work/servicos/servico_execucao_work.dart';
import '../models/work_modelos.dart';

enum EtapaWorkNativo {
  carregando,
  historico,
  selecao,
  resumo,
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
  static const int _duracaoExecucaoSerieSegundos = 28;

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
  final Map<String, int> _seriesPlanejadasPorExercicio = <String, int>{};
  final Map<String, Map<int, SerieDraftWork>> _seriesDrafts =
      <String, Map<int, SerieDraftWork>>{};

  bool _sincronizacaoEmAndamento = false;

  // Pausa somente da série. O cronômetro geral continua rodando.
  int? _segundosRestantesSeriePausada;

  // Quando termina o último exercício, fica aguardando avançar para o cardio.
  bool _aguardandoCardio = false;

  // O cardio entra preparado, mas só começa quando o aluno clicar.
  bool _cardioIniciado = false;

  BootstrapWorkMobile? get bootstrap => _bootstrap;
  EtapaWorkNativo get etapa => _etapa;
  String? get erro => _erro;
  ResultadoConclusaoWork? get resultadoConclusao => _resultadoConclusao;
  SnapshotSessaoWork? get snapshot => _snapshot;
  TaxaKcalWork? get taxaKcal => _taxaKcal;
  FichaWork? get workout => _workout;

  bool get cardioIniciado => _cardioIniciado;

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
    if (seriePausada) {
      return _segundosRestantesSeriePausada ?? 0;
    }

    final SnapshotSessaoWork? atual = _snapshot;

    if (atual == null) {
      return 0;
    }

    return servicoExecucaoWork.cronometro.segundosRestantes(atual);
  }

  bool get faseComContagemRegressiva {
    final FaseSessaoWork? fase = _snapshot?.phase;

    if (seriePausada) {
      return true;
    }

    return (fase == FaseSessaoWork.exercicioRodando &&
            _snapshot?.endsAtMs != null) ||
        fase == FaseSessaoWork.descansoSerie ||
        fase == FaseSessaoWork.transicaoProximoExercicio ||
        (fase == FaseSessaoWork.cardioRodando && _cardioIniciado);
  }

  // Agora "pular descanso" vale apenas para descanso entre séries.
  // Transição entre exercícios deve mostrar Avançar.
  bool get podePularDescanso {
    final FaseSessaoWork? fase = _snapshot?.phase;
    return fase == FaseSessaoWork.descansoSerie;
  }

  bool get descansoEntreExercicios {
    return _snapshot?.phase == FaseSessaoWork.transicaoProximoExercicio;
  }

  bool get descansoEntreExerciciosFinalizado {
    final SnapshotSessaoWork? atual = _snapshot;
    return atual?.phase == FaseSessaoWork.transicaoProximoExercicio &&
        atual?.endsAtMs == null;
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
      (int total, ExercicioWork exercicio) =>
          total + totalSeriesExercicio(exercicio),
    );
  }

  int get totalExercicios {
    return _workout?.exercises.length ?? 0;
  }

  int get exerciciosContabilizados {
    final FichaWork? ficha = _workout;

    if (ficha == null || ficha.exercises.isEmpty) {
      return 0;
    }

    return (indiceExercicioAtual + 1).clamp(0, ficha.exercises.length);
  }

  double get progressoExercicios {
    final int total = totalExercicios;

    if (total == 0) {
      return 0;
    }

    return exerciciosContabilizados / total;
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

    if (seriePausada) {
      return 'série pausada';
    }

    if (descansoEntreExerciciosFinalizado) {
      return _aguardandoCardio ? 'pronto para cardio' : 'pronto para avançar';
    }

    if (_etapa == EtapaWorkNativo.cardio && !_cardioIniciado) {
      return 'cardio pronto para iniciar';
    }

    return switch (fase) {
      FaseSessaoWork.descansoSerie => 'descanso',
      FaseSessaoWork.transicaoProximoExercicio => 'descanso entre exercícios',
      FaseSessaoWork.cardioRodando => 'cardio em andamento',
      FaseSessaoWork.pausado => 'pausado',
      FaseSessaoWork.concluido => 'concluído',
      FaseSessaoWork.cancelado => 'cancelado',
      FaseSessaoWork.exercicioRodando =>
        _snapshot?.endsAtMs == null
            ? 'pronto para iniciar série'
            : 'série em execução',
      null => 'não iniciado',
    };
  }

  bool serieConcluida(String exerciseId, int setNumber) {
    return _seriesConcluidas[exerciseId]?.contains(setNumber) ?? false;
  }

  bool get serieExecutando {
    final SnapshotSessaoWork? atual = _snapshot;

    return atual?.phase == FaseSessaoWork.exercicioRodando &&
        atual?.endsAtMs != null &&
        _segundosRestantesSeriePausada == null;
  }

  bool get seriePausada {
    final SnapshotSessaoWork? atual = _snapshot;

    return atual?.phase == FaseSessaoWork.exercicioRodando &&
        atual?.endsAtMs == null &&
        _segundosRestantesSeriePausada != null;
  }

  bool get serieEmAndamento {
    final FaseSessaoWork? fase = _snapshot?.phase;

    return serieExecutando ||
        seriePausada ||
        fase == FaseSessaoWork.descansoSerie ||
        fase == FaseSessaoWork.transicaoProximoExercicio;
  }

  bool get edicaoSeriesBloqueada {
    return serieEmAndamento;
  }

  bool get podeAcionarBotaoSerie {
    final SnapshotSessaoWork? atual = _snapshot;
    final ExercicioWork? exercicio = exercicioAtual;

    if (atual == null || exercicio == null) {
      return false;
    }

    if (serieExecutando || seriePausada) {
      return true;
    }

    if (atual.phase != FaseSessaoWork.exercicioRodando ||
        atual.endsAtMs != null) {
      return false;
    }

    return _primeiraSeriePendente(exercicio) != null;
  }

  String get textoBotaoSerie {
    if (seriePausada) {
      return 'Retomar série';
    }

    if (serieExecutando) {
      return 'Pausar série';
    }

    if (_snapshot?.phase == FaseSessaoWork.descansoSerie) {
      return 'Em descanso';
    }

    if (_snapshot?.phase == FaseSessaoWork.transicaoProximoExercicio) {
      return 'Avance para continuar';
    }

    final ExercicioWork? exercicio = exercicioAtual;

    if (exercicio != null && _primeiraSeriePendente(exercicio) == null) {
      return 'Séries concluídas';
    }

    return 'Iniciar série';
  }

  String get textoBotaoCardio {
    if (_etapa != EtapaWorkNativo.cardio) {
      return 'Cardio';
    }

    if (!_cardioIniciado) {
      return 'Iniciar cardio';
    }

    if (pausado) {
      return 'Retomar cardio';
    }

    return 'Pausar cardio';
  }

  Future<void> acionarBotaoSerieAtual() async {
    if (seriePausada) {
      await retomarSerieAtual();
      return;
    }

    if (serieExecutando) {
      await pausarSerieAtual();
      return;
    }

    await iniciarSerieAtual();
  }

  Future<void> pausarSerieAtual() async {
    final SnapshotSessaoWork? atual = _snapshot;

    if (atual == null || !serieExecutando || atual.endsAtMs == null) {
      return;
    }

    final int agora = servicoExecucaoWork.cronometro.agoraMs();
    final int restanteMs = atual.endsAtMs! - agora;
    final int restanteSegundos = restanteMs <= 0
        ? 0
        : (restanteMs / 1000).ceil();

    _segundosRestantesSeriePausada = restanteSegundos;

    // Não usa snapshot.pausar(), porque isso pausaria o cronômetro geral.
    // Apenas remove o endsAtMs da série. O total do treino continua correndo.
    _snapshot = atual
        .recalcular(agora)
        .copiarCom(
          endsAtMs: null,
          phase: FaseSessaoWork.exercicioRodando,
          updatedAtMs: agora,
        );

    notifyListeners();

    await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
  }

  Future<void> retomarSerieAtual() async {
    final SnapshotSessaoWork? atual = _snapshot;

    if (atual == null || !seriePausada) {
      return;
    }

    final int agora = servicoExecucaoWork.cronometro.agoraMs();
    final int restante = _segundosRestantesSeriePausada ?? 0;
    final SnapshotSessaoWork recalculado = atual.recalcular(agora);

    _segundosRestantesSeriePausada = null;

    _snapshot = recalculado.copiarCom(
      endsAtMs: agora + (restante * 1000),
      phase: FaseSessaoWork.exercicioRodando,
      phaseBaseElapsedSeconds: recalculado.exerciseElapsedSeconds,
      phaseStartedAtMs: agora,
      updatedAtMs: agora,
    );

    _iniciarTimer();
    notifyListeners();

    await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
  }

  bool serieAtualEmExecucao(String exerciseId, int setNumber) {
    final SnapshotSessaoWork? atual = _snapshot;
    final ExercicioWork? exercicio = exercicioAtual;

    final bool executando =
        atual?.phase == FaseSessaoWork.exercicioRodando &&
        atual?.endsAtMs != null;

    final bool pausada =
        atual?.phase == FaseSessaoWork.exercicioRodando &&
        atual?.endsAtMs == null &&
        _segundosRestantesSeriePausada != null;

    return (executando || pausada) &&
        exercicio?.id == exerciseId &&
        atual?.setIndex == setNumber - 1;
  }

  bool serieAtualEmDescanso(String exerciseId, int setNumber) {
    final SnapshotSessaoWork? atual = _snapshot;
    final ExercicioWork? exercicio = exercicioAtual;

    return atual?.phase == FaseSessaoWork.descansoSerie &&
        exercicio?.id == exerciseId &&
        atual?.setIndex == setNumber - 1;
  }

  int totalSeriesExercicio(ExercicioWork exercicio) {
    return _seriesPlanejadasPorExercicio[exercicio.id] ?? exercicio.sets;
  }

  SerieDraftWork draftSerie(String exerciseId, int setNumber) {
    return _seriesDrafts[exerciseId]?[setNumber] ?? SerieDraftWork.vazio;
  }

  Future<void> inicializar(SnapshotSessaoWork? snapshotInicial) async {
    _etapa = EtapaWorkNativo.carregando;
    _erro = null;
    _limparPausaSerie();
    _aguardandoCardio = false;
    _cardioIniciado = false;
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

          final bool estaNoCardio =
              snapshot.phase == FaseSessaoWork.cardioRodando ||
              (snapshot.phase == FaseSessaoWork.pausado &&
                  snapshot.cardioIndex != null);

          _etapa = estaNoCardio
              ? EtapaWorkNativo.cardio
              : EtapaWorkNativo.exercicio;

          _cardioIniciado = estaNoCardio && snapshot.endsAtMs != null;

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

  void selecionarFicha(FichaWork ficha) {
    _workout = ficha;
    _snapshot = null;
    _resultadoConclusao = null;
    _limparPausaSerie();
    _aguardandoCardio = false;
    _cardioIniciado = false;
    _popularSeriesIniciais(ficha);
    _etapa = EtapaWorkNativo.resumo;
    notifyListeners();
  }

  Future<void> iniciarExecucaoSelecionada() async {
    final FichaWork? ficha = _workout;

    if (ficha == null) {
      _etapa = EtapaWorkNativo.historico;
      notifyListeners();
      return;
    }

    _snapshot = _criarSnapshotInicial(ficha);
    _resultadoConclusao = null;
    _limparPausaSerie();
    _aguardandoCardio = false;
    _cardioIniciado = false;
    _popularSeriesIniciais(ficha);
    _etapa = EtapaWorkNativo.exercicio;

    // Cronômetro geral começa aqui.
    _iniciarTimer();
    notifyListeners();

    await _sincronizarSnapshot(metodo: 'abrirWorkNativo');
    await _carregarTaxaKcal();
  }

  Future<void> alternarSerie(String exerciseId, int setNumber) async {
    if (edicaoSeriesBloqueada) {
      return;
    }

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
    notifyListeners();
  }

  Future<void> iniciarSerieAtual() async {
    final SnapshotSessaoWork? atual = _snapshot;
    final ExercicioWork? exercicio = exercicioAtual;

    if (atual == null ||
        exercicio == null ||
        serieExecutando ||
        seriePausada ||
        atual.phase != FaseSessaoWork.exercicioRodando ||
        atual.endsAtMs != null) {
      return;
    }

    final int? proximaSerie = _primeiraSeriePendente(exercicio);

    if (proximaSerie == null) {
      return;
    }

    final int agora = servicoExecucaoWork.cronometro.agoraMs();
    _limparPausaSerie();

    _snapshot = _iniciarContagemSerie(
      atual.recalcular(agora).copiarCom(setIndex: proximaSerie - 1),
      agora,
    );

    _iniciarTimer();
    notifyListeners();

    await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
  }

  void adicionarSerie(ExercicioWork exercicio) {
    if (edicaoSeriesBloqueada) {
      return;
    }

    final int totalAtual = totalSeriesExercicio(exercicio);
    final int proximaSerie = totalAtual + 1;
    final SerieDraftWork draftAnterior = draftSerie(exercicio.id, totalAtual);

    _seriesPlanejadasPorExercicio[exercicio.id] = proximaSerie;
    _seriesDrafts.putIfAbsent(
      exercicio.id,
      () => <int, SerieDraftWork>{},
    )[proximaSerie] = draftAnterior;

    notifyListeners();
  }

  void atualizarDraftSerie(
    String exerciseId,
    int setNumber, {
    String? peso,
    String? reps,
  }) {
    final SerieDraftWork atual = draftSerie(exerciseId, setNumber);

    _seriesDrafts.putIfAbsent(
      exerciseId,
      () => <int, SerieDraftWork>{},
    )[setNumber] = atual.copiarCom(
      peso: peso?.replaceAll(',', '.'),
      reps: reps?.replaceAll(',', '.'),
    );

    notifyListeners();
  }

  bool exercicioAtualCompleto() {
    final ExercicioWork? exercicio = exercicioAtual;

    if (exercicio == null) {
      return false;
    }

    final Set<int> concluidas = _seriesConcluidas[exercicio.id] ?? <int>{};
    return concluidas.length >= totalSeriesExercicio(exercicio);
  }

  Future<void> avancarExercicio({required bool forcar}) async {
    final FichaWork? ficha = _workout;
    final SnapshotSessaoWork? atual = _snapshot;
    final ExercicioWork? exercicio = exercicioAtual;

    if (ficha == null || atual == null || exercicio == null) {
      return;
    }

    if (serieExecutando || seriePausada) {
      return;
    }

    final int agora = servicoExecucaoWork.cronometro.agoraMs();

    // Se está no descanso entre exercícios, o botão Avançar realmente troca
    // para o próximo exercício, mas não inicia a próxima série.
    if (atual.phase == FaseSessaoWork.transicaoProximoExercicio) {
      await servicoExecucaoWork.notificacaoWork.cancelarFase(atual);

      if (_aguardandoCardio) {
        await iniciarCardio();
        return;
      }

      final int proximoIndice = atual.exerciseIndex + 1;

      if (proximoIndice >= ficha.exercises.length) {
        await iniciarCardio();
        return;
      }

      final SnapshotSessaoWork recalculado = atual.recalcular(agora);

      _snapshot = recalculado.copiarCom(
        exerciseIndex: proximoIndice,
        setIndex: 0,
        endsAtMs: null,
        phase: FaseSessaoWork.exercicioRodando,
        phaseBaseElapsedSeconds: recalculado.exerciseElapsedSeconds,
        phaseStartedAtMs: agora,
        updatedAtMs: agora,
      );

      _limparPausaSerie();
      _aguardandoCardio = false;

      notifyListeners();

      await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
      await _carregarTaxaKcal();
      return;
    }

    // Mantém a regra atual: se houver séries pendentes, abre o modal
    // perguntando se deseja avançar mesmo assim.
    if (!forcar && !exercicioAtualCompleto()) {
      throw const WorkSeriesPendentes();
    }

    await servicoExecucaoWork.notificacaoWork.cancelarFase(atual);

    final int proximoIndice = atual.exerciseIndex + 1;

    if (proximoIndice >= ficha.exercises.length) {
      await _prepararTransicaoParaCardio(atual, exercicio, agora);
      return;
    }

    await _prepararTransicaoParaProximoExercicio(atual, exercicio, agora);
  }

  Future<void> pularDescanso() async {
    final SnapshotSessaoWork? atual = _snapshot;

    if (atual == null) {
      return;
    }

    // Agora só pula descanso entre séries.
    if (atual.phase != FaseSessaoWork.descansoSerie) {
      return;
    }

    final ResultadoEventoWork resultado = await servicoExecucaoWork
        .tratarEventoBridge(
          metodo: 'cancelarDescansoWorkNativo',
          payload: atual.toJson(),
        );

    onResultadoWeb?.call(resultado);
    _snapshot = SnapshotSessaoWork.fromJson(resultado.payload);

    final int agora = servicoExecucaoWork.cronometro.agoraMs();
    final SnapshotSessaoWork? proximo = _snapshot;

    // Não inicia automaticamente a próxima série.
    // Apenas deixa a próxima série pronta para o aluno clicar em Iniciar série.
    if (proximo != null && proximo.phase == FaseSessaoWork.exercicioRodando) {
      _snapshot = proximo
          .recalcular(agora)
          .copiarCom(
            endsAtMs: null,
            phase: FaseSessaoWork.exercicioRodando,
            updatedAtMs: agora,
          );
    }

    _limparPausaSerie();

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
    final SnapshotSessaoWork recalculado = atual.recalcular(agora);

    _snapshot = recalculado.copiarCom(
      cardioIndex: 0,
      endsAtMs: null,
      elapsedSeconds: recalculado.cardioElapsedSeconds,
      phase: FaseSessaoWork.cardioRodando,
      phaseBaseElapsedSeconds: recalculado.cardioElapsedSeconds,
      phaseStartedAtMs: agora,
      updatedAtMs: agora,
    );

    _etapa = EtapaWorkNativo.cardio;
    _aguardandoCardio = false;
    _cardioIniciado = false;
    _limparPausaSerie();

    notifyListeners();

    await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
    await _carregarTaxaKcal(kind: 'cardio');
  }

  Future<void> pausarOuRetomarCardio() async {
    final SnapshotSessaoWork? atual = _snapshot;
    final FichaWork? ficha = _workout;

    if (atual == null || ficha == null) {
      return;
    }

    final int agora = servicoExecucaoWork.cronometro.agoraMs();

    // Primeiro clique no cardio: inicia a contagem.
    if (!_cardioIniciado) {
      final int cardioTargetSeconds = _parseCardioDurationSeconds(ficha.cardio);

      _snapshot = atual
          .recalcular(agora)
          .copiarCom(
            endsAtMs: cardioTargetSeconds > 0
                ? agora + (cardioTargetSeconds * 1000)
                : null,
            phase: FaseSessaoWork.cardioRodando,
            phaseBaseElapsedSeconds: atual.cardioElapsedSeconds,
            phaseStartedAtMs: agora,
            updatedAtMs: agora,
          );

      _cardioIniciado = true;
      _iniciarTimer();
      notifyListeners();

      await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
      await _carregarTaxaKcal(kind: 'cardio');
      return;
    }

    _snapshot = atual.phase == FaseSessaoWork.pausado
        ? atual.retomar(agora)
        : atual.pausar(agora);

    notifyListeners();

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
    _seriesPlanejadasPorExercicio.clear();
    _seriesDrafts.clear();

    for (final ExercicioWork exercicio in ficha.exercises) {
      _seriesConcluidas.putIfAbsent(exercicio.id, () => <int>{});
      _seriesPlanejadasPorExercicio[exercicio.id] = exercicio.sets;
      _seriesDrafts[exercicio.id] = <int, SerieDraftWork>{
        for (int serie = 1; serie <= exercicio.sets; serie += 1)
          serie: SerieDraftWork(reps: exercicio.reps, peso: exercicio.weight),
      };
    }
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_processarTick());
    });
  }

  Future<void> _processarTick() async {
    final SnapshotSessaoWork? atual = _snapshot;

    if (atual == null || _sincronizacaoEmAndamento) {
      return;
    }

    final int agora = servicoExecucaoWork.cronometro.agoraMs();

    // Cardio preparado, mas ainda não iniciado pelo aluno.
    if (_etapa == EtapaWorkNativo.cardio && !_cardioIniciado) {
      return;
    }

    // Série pausada: o cronômetro geral continua rodando,
    // mas o tempo restante da série fica congelado.
    if (seriePausada) {
      _snapshot = atual
          .recalcular(agora)
          .copiarCom(
            endsAtMs: null,
            phase: FaseSessaoWork.exercicioRodando,
            updatedAtMs: agora,
          );
      notifyListeners();
      return;
    }

    if (_execucaoSerieVencida(atual, agora)) {
      await _finalizarExecucaoSerie(atual, agora);
      return;
    }

    if (_transicaoExercicioVencida(atual, agora)) {
      _snapshot = atual
          .recalcular(agora)
          .copiarCom(
            endsAtMs: null,
            phase: FaseSessaoWork.transicaoProximoExercicio,
            updatedAtMs: agora,
          );
      notifyListeners();
      unawaited(_sincronizarSnapshot(metodo: 'sincronizarWorkNativo'));
      return;
    }

    final SnapshotSessaoWork recalculado = servicoExecucaoWork.cronometro
        .recalcular(atual);

    // Não inicia automaticamente a próxima série após descanso.
    final bool descansoSerieTerminou =
        atual.phase == FaseSessaoWork.descansoSerie &&
        recalculado.phase == FaseSessaoWork.exercicioRodando;

    final SnapshotSessaoWork proximo = descansoSerieTerminou
        ? recalculado.copiarCom(
            endsAtMs: null,
            phase: FaseSessaoWork.exercicioRodando,
            updatedAtMs: agora,
          )
        : recalculado;

    final bool mudouFase =
        proximo.phase != atual.phase ||
        proximo.exerciseIndex != atual.exerciseIndex ||
        proximo.setIndex != atual.setIndex ||
        proximo.cardioIndex != atual.cardioIndex ||
        proximo.endsAtMs != atual.endsAtMs;

    _snapshot = proximo;
    notifyListeners();

    if (mudouFase) {
      unawaited(_sincronizarSnapshot(metodo: 'sincronizarWorkNativo'));
      unawaited(_carregarTaxaKcal());
    }
  }

  bool _execucaoSerieVencida(SnapshotSessaoWork snapshot, int agora) {
    return snapshot.phase == FaseSessaoWork.exercicioRodando &&
        snapshot.endsAtMs != null &&
        agora >= snapshot.endsAtMs!;
  }

  bool _transicaoExercicioVencida(SnapshotSessaoWork snapshot, int agora) {
    return snapshot.phase == FaseSessaoWork.transicaoProximoExercicio &&
        snapshot.endsAtMs != null &&
        agora >= snapshot.endsAtMs!;
  }

  Future<void> _finalizarExecucaoSerie(
    SnapshotSessaoWork atual,
    int agora,
  ) async {
    final FichaWork? ficha = _workout;
    final ExercicioWork? exercicio = _exercicioPorIndice(atual.exerciseIndex);

    if (ficha == null || exercicio == null) {
      return;
    }

    final SnapshotSessaoWork base = atual.recalcular(agora);
    final int setNumber = (base.setIndex + 1).clamp(
      1,
      totalSeriesExercicio(exercicio),
    );

    _seriesConcluidas.putIfAbsent(exercicio.id, () => <int>{}).add(setNumber);

    final int? proximaSerie = _primeiraSeriePendente(exercicio);

    // Ainda há séries neste exercício.
    if (proximaSerie != null) {
      final int descansoSegundos = _descansoExercicioSegundos(exercicio);

      if (descansoSegundos > 0) {
        _snapshot = base.copiarCom(
          endsAtMs: agora + (descansoSegundos * 1000),
          phase: FaseSessaoWork.descansoSerie,
          restSeconds: descansoSegundos,
          setIndex: setNumber - 1,
          updatedAtMs: agora,
        );
      } else {
        // Não inicia automaticamente a próxima série.
        _snapshot = base.copiarCom(
          endsAtMs: null,
          phase: FaseSessaoWork.exercicioRodando,
          setIndex: proximaSerie - 1,
          updatedAtMs: agora,
        );
      }

      _limparPausaSerie();
      notifyListeners();

      await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
      return;
    }

    final int proximoIndice = base.exerciseIndex + 1;

    // Acabaram as séries e existe próximo exercício:
    // entra em descanso/hint entre exercícios e depois mostra Avançar.
    if (proximoIndice < ficha.exercises.length) {
      await _prepararTransicaoParaProximoExercicio(base, exercicio, agora);
      return;
    }

    // Acabou o último exercício:
    // mostra Avançar para ir ao cardio, sem iniciar cardio automaticamente.
    await _prepararTransicaoParaCardio(base, exercicio, agora);
  }

  Future<void> _prepararTransicaoParaProximoExercicio(
    SnapshotSessaoWork atual,
    ExercicioWork exercicio,
    int agora,
  ) async {
    final int transicaoSegundos =
        _descansoExercicioSegundos(exercicio) +
        _extraTransicaoExercicioSegundos;

    _aguardandoCardio = false;
    _limparPausaSerie();

    _snapshot = atual.copiarCom(
      endsAtMs: transicaoSegundos > 0
          ? agora + (transicaoSegundos * 1000)
          : null,
      phase: FaseSessaoWork.transicaoProximoExercicio,
      restSeconds: transicaoSegundos,
      setIndex: totalSeriesExercicio(exercicio) - 1,
      updatedAtMs: agora,
    );

    notifyListeners();

    await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
  }

  Future<void> _prepararTransicaoParaCardio(
    SnapshotSessaoWork atual,
    ExercicioWork exercicio,
    int agora,
  ) async {
    final int descansoSegundos = _descansoExercicioSegundos(exercicio);

    _aguardandoCardio = true;
    _limparPausaSerie();

    _snapshot = atual.copiarCom(
      endsAtMs: descansoSegundos > 0 ? agora + (descansoSegundos * 1000) : null,
      phase: FaseSessaoWork.transicaoProximoExercicio,
      restSeconds: descansoSegundos,
      setIndex: totalSeriesExercicio(exercicio) - 1,
      updatedAtMs: agora,
    );

    notifyListeners();

    await _sincronizarSnapshot(metodo: 'sincronizarWorkNativo');
  }

  SnapshotSessaoWork _iniciarContagemSerie(SnapshotSessaoWork base, int agora) {
    final ExercicioWork? exercicio = _exercicioPorIndice(base.exerciseIndex);

    if (exercicio == null) {
      return base;
    }

    final int setNumber = base.setIndex + 1;

    if (setNumber < 1 ||
        setNumber > totalSeriesExercicio(exercicio) ||
        serieConcluida(exercicio.id, setNumber)) {
      return base;
    }

    return base.copiarCom(
      endsAtMs: agora + (_duracaoExecucaoSerieSegundos * 1000),
      phase: FaseSessaoWork.exercicioRodando,
      phaseBaseElapsedSeconds: base.exerciseElapsedSeconds,
      phaseStartedAtMs: agora,
      restSeconds: _descansoExercicioSegundos(exercicio),
      updatedAtMs: agora,
    );
  }

  int? _primeiraSeriePendente(ExercicioWork exercicio) {
    final Set<int> concluidas = _seriesConcluidas[exercicio.id] ?? <int>{};
    final int total = totalSeriesExercicio(exercicio);

    for (int serie = 1; serie <= total; serie += 1) {
      if (!concluidas.contains(serie)) {
        return serie;
      }
    }

    return null;
  }

  int _descansoExercicioSegundos(ExercicioWork exercicio) {
    return exercicio.restSeconds > 0
        ? exercicio.restSeconds
        : (_workout?.restSeconds ?? 0);
  }

  ExercicioWork? _exercicioPorIndice(int index) {
    final FichaWork? ficha = _workout;

    if (ficha == null || ficha.exercises.isEmpty) {
      return null;
    }

    final int seguro = index.clamp(0, ficha.exercises.length - 1);
    return ficha.exercises[seguro];
  }

  void _limparPausaSerie() {
    _segundosRestantesSeriePausada = null;
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
        final SnapshotSessaoWork snapshotWeb = SnapshotSessaoWork.fromJson(
          resultado.payload,
        );

        // Preserva pausa local de série, porque o web não sabe desse estado.
        if (seriePausada) {
          _snapshot = snapshotWeb.copiarCom(
            endsAtMs: null,
            phase: FaseSessaoWork.exercicioRodando,
          );
        } else {
          _snapshot = snapshotWeb;
        }
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
          final int total = totalSeriesExercicio(exercicio);

          return List<SerieConcluidaWork>.generate(total, (int index) {
            final int setNumber = index + 1;
            final SerieDraftWork draft = draftSerie(exercicio.id, setNumber);

            return SerieConcluidaWork(
              completed: serieConcluida(exercicio.id, setNumber),
              exerciseId: exercicio.id,
              repetitionsDone: _parseInteiro(draft.reps),
              setNumber: setNumber,
              weightUsedKg: _parseDouble(draft.peso),
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

class SerieDraftWork {
  const SerieDraftWork({required this.peso, required this.reps});

  static const SerieDraftWork vazio = SerieDraftWork(peso: '', reps: '');

  final String peso;
  final String reps;

  SerieDraftWork copiarCom({String? peso, String? reps}) {
    return SerieDraftWork(peso: peso ?? this.peso, reps: reps ?? this.reps);
  }
}
