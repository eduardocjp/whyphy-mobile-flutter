import '../../nucleo/rede/json_api.dart';

enum FaseSessaoWork {
  exercicioRodando('exercise_running'),
  descansoSerie('set_rest'),
  transicaoProximoExercicio('next_exercise_transition'),
  cardioRodando('cardio_running'),
  pausado('paused'),
  concluido('completed'),
  cancelado('cancelled');

  const FaseSessaoWork(this.valorApi);

  final String valorApi;

  static FaseSessaoWork? fromJson(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final FaseSessaoWork fase in FaseSessaoWork.values) {
      if (fase.valorApi == value) {
        return fase;
      }
    }

    return null;
  }
}

enum StatusSessaoWork {
  ativo('active'),
  concluido('completed'),
  cancelado('cancelled');

  const StatusSessaoWork(this.valorApi);

  final String valorApi;

  static StatusSessaoWork? fromJson(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final StatusSessaoWork status in StatusSessaoWork.values) {
      if (status.valorApi == value) {
        return status;
      }
    }

    return null;
  }
}

class SnapshotSessaoWork {
  const SnapshotSessaoWork({
    required this.cardioIndex,
    required this.cardioElapsedSeconds,
    required this.elapsedSeconds,
    required this.endsAtMs,
    required this.exerciseIndex,
    required this.exerciseElapsedSeconds,
    required this.pausedAccumulatedMs,
    required this.pausedFromPhase,
    required this.pausedRemainingMs,
    required this.phaseBaseElapsedSeconds,
    required this.phaseStartedAtMs,
    required this.phase,
    required this.restSeconds,
    required this.setIndex,
    required this.startedAtMs,
    required this.status,
    required this.updatedAtMs,
    required this.workoutId,
  });

  factory SnapshotSessaoWork.fromJson(Map<String, Object?> json) {
    final FaseSessaoWork? fase = FaseSessaoWork.fromJson(json['phase']);
    final StatusSessaoWork? status = StatusSessaoWork.fromJson(json['status']);
    final String workoutId = lerStringJson(json, 'workoutId').trim();

    if (workoutId.isEmpty || fase == null || status == null) {
      throw const FormatException('Snapshot Work invalido.');
    }

    return SnapshotSessaoWork(
      cardioIndex: _lerInteiroOpcional(json['cardioIndex']),
      cardioElapsedSeconds:
          _lerInteiroOpcional(json['cardioElapsedSeconds']) ??
          (fase == FaseSessaoWork.cardioRodando
              ? _lerInteiro(json['elapsedSeconds'])
              : 0),
      elapsedSeconds: _lerInteiro(json['elapsedSeconds']),
      endsAtMs: _lerInteiroOpcional(json['endsAtMs']),
      exerciseIndex: _lerInteiro(json['exerciseIndex']),
      exerciseElapsedSeconds:
          _lerInteiroOpcional(json['exerciseElapsedSeconds']) ??
          (fase == FaseSessaoWork.cardioRodando
              ? 0
              : _lerInteiro(json['elapsedSeconds'])),
      pausedAccumulatedMs: _lerInteiro(json['pausedAccumulatedMs']),
      pausedFromPhase: FaseSessaoWork.fromJson(json['pausedFromPhase']),
      pausedRemainingMs: _lerInteiroOpcional(json['pausedRemainingMs']),
      phaseBaseElapsedSeconds:
          _lerInteiroOpcional(json['phaseBaseElapsedSeconds']) ??
          _lerInteiro(json['elapsedSeconds']),
      phaseStartedAtMs:
          _lerInteiroOpcional(json['phaseStartedAtMs']) ??
          _lerInteiro(json['updatedAtMs']),
      phase: fase,
      restSeconds: _lerInteiro(json['restSeconds']),
      setIndex: _lerInteiro(json['setIndex']),
      startedAtMs: _lerInteiro(json['startedAtMs']),
      status: status,
      updatedAtMs: _lerInteiro(json['updatedAtMs']),
      workoutId: workoutId,
    );
  }

  final int? cardioIndex;
  final int cardioElapsedSeconds;
  final int elapsedSeconds;
  final int? endsAtMs;
  final int exerciseIndex;
  final int exerciseElapsedSeconds;
  final int pausedAccumulatedMs;
  final FaseSessaoWork? pausedFromPhase;
  final int? pausedRemainingMs;
  final int phaseBaseElapsedSeconds;
  final int phaseStartedAtMs;
  final FaseSessaoWork phase;
  final int restSeconds;
  final int setIndex;
  final int startedAtMs;
  final StatusSessaoWork status;
  final int updatedAtMs;
  final String workoutId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'cardioIndex': cardioIndex,
      'cardioElapsedSeconds': cardioElapsedSeconds,
      'elapsedSeconds': elapsedSeconds,
      'endsAtMs': endsAtMs,
      'exerciseIndex': exerciseIndex,
      'exerciseElapsedSeconds': exerciseElapsedSeconds,
      'pausedAccumulatedMs': pausedAccumulatedMs,
      'pausedFromPhase': pausedFromPhase?.valorApi,
      'pausedRemainingMs': pausedRemainingMs,
      'phaseBaseElapsedSeconds': phaseBaseElapsedSeconds,
      'phaseStartedAtMs': phaseStartedAtMs,
      'phase': phase.valorApi,
      'restSeconds': restSeconds,
      'setIndex': setIndex,
      'startedAtMs': startedAtMs,
      'status': status.valorApi,
      'updatedAtMs': updatedAtMs,
      'workoutId': workoutId,
    };
  }

  int get totalElapsedSeconds {
    return exerciseElapsedSeconds + cardioElapsedSeconds;
  }

  bool get ativo {
    return status == StatusSessaoWork.ativo &&
        phase != FaseSessaoWork.concluido &&
        phase != FaseSessaoWork.cancelado;
  }

  String get notificationId {
    if (phase == FaseSessaoWork.cardioRodando) {
      return 'workout-$workoutId-cardio-${cardioIndex ?? 0}';
    }

    if (phase == FaseSessaoWork.transicaoProximoExercicio) {
      return 'workout-$workoutId-exercise-$exerciseIndex-next';
    }

    return 'workout-$workoutId-exercise-$exerciseIndex-set-$setIndex-rest';
  }

  SnapshotSessaoWork copiarCom({
    Object? cardioIndex = _semAlteracao,
    int? cardioElapsedSeconds,
    int? elapsedSeconds,
    Object? endsAtMs = _semAlteracao,
    int? exerciseIndex,
    int? exerciseElapsedSeconds,
    int? pausedAccumulatedMs,
    Object? pausedFromPhase = _semAlteracao,
    Object? pausedRemainingMs = _semAlteracao,
    int? phaseBaseElapsedSeconds,
    int? phaseStartedAtMs,
    FaseSessaoWork? phase,
    int? restSeconds,
    int? setIndex,
    int? startedAtMs,
    StatusSessaoWork? status,
    int? updatedAtMs,
    String? workoutId,
  }) {
    return SnapshotSessaoWork(
      cardioIndex: identical(cardioIndex, _semAlteracao)
          ? this.cardioIndex
          : cardioIndex as int?,
      cardioElapsedSeconds: cardioElapsedSeconds ?? this.cardioElapsedSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      endsAtMs: identical(endsAtMs, _semAlteracao)
          ? this.endsAtMs
          : endsAtMs as int?,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      exerciseElapsedSeconds:
          exerciseElapsedSeconds ?? this.exerciseElapsedSeconds,
      pausedAccumulatedMs: pausedAccumulatedMs ?? this.pausedAccumulatedMs,
      pausedFromPhase: identical(pausedFromPhase, _semAlteracao)
          ? this.pausedFromPhase
          : pausedFromPhase as FaseSessaoWork?,
      pausedRemainingMs: identical(pausedRemainingMs, _semAlteracao)
          ? this.pausedRemainingMs
          : pausedRemainingMs as int?,
      phaseBaseElapsedSeconds:
          phaseBaseElapsedSeconds ?? this.phaseBaseElapsedSeconds,
      phaseStartedAtMs: phaseStartedAtMs ?? this.phaseStartedAtMs,
      phase: phase ?? this.phase,
      restSeconds: restSeconds ?? this.restSeconds,
      setIndex: setIndex ?? this.setIndex,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      status: status ?? this.status,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      workoutId: workoutId ?? this.workoutId,
    );
  }

  SnapshotSessaoWork recalcular(int agoraMs) {
    if (phase == FaseSessaoWork.pausado) {
      return copiarCom(updatedAtMs: agoraMs);
    }

    if ((phase == FaseSessaoWork.descansoSerie ||
            phase == FaseSessaoWork.transicaoProximoExercicio ||
            phase == FaseSessaoWork.cardioRodando) &&
        endsAtMs != null &&
        agoraMs >= endsAtMs!) {
      if (phase == FaseSessaoWork.cardioRodando) {
        final SnapshotSessaoWork atualizado = _recalcularCronometro(agoraMs);
        return atualizado.copiarCom(
          endsAtMs: null,
          phase: FaseSessaoWork.pausado,
          pausedFromPhase: FaseSessaoWork.cardioRodando,
          pausedRemainingMs: 0,
          updatedAtMs: agoraMs,
        );
      }

      return avancarDescanso(agoraMs);
    }

    return _recalcularCronometro(agoraMs);
  }

  SnapshotSessaoWork pausar(int agoraMs) {
    final SnapshotSessaoWork atualizado = recalcular(agoraMs);
    final int? restante = atualizado.endsAtMs == null
        ? null
        : (atualizado.endsAtMs! - agoraMs).clamp(0, 1 << 31);

    return atualizado.copiarCom(
      endsAtMs: null,
      pausedFromPhase: atualizado.phase,
      pausedRemainingMs: restante,
      phase: FaseSessaoWork.pausado,
      updatedAtMs: agoraMs,
    );
  }

  SnapshotSessaoWork retomar(int agoraMs) {
    final FaseSessaoWork faseAnterior =
        pausedFromPhase ??
        (cardioIndex == null
            ? FaseSessaoWork.exercicioRodando
            : FaseSessaoWork.cardioRodando);
    final int baseElapsed = faseAnterior == FaseSessaoWork.cardioRodando
        ? cardioElapsedSeconds
        : exerciseElapsedSeconds;
    final int? proximoFim = pausedRemainingMs == null || pausedRemainingMs == 0
        ? null
        : agoraMs + pausedRemainingMs!;

    return copiarCom(
      endsAtMs: proximoFim,
      pausedFromPhase: null,
      pausedRemainingMs: null,
      phase: faseAnterior,
      phaseBaseElapsedSeconds: baseElapsed,
      phaseStartedAtMs: agoraMs,
      updatedAtMs: agoraMs,
    );
  }

  SnapshotSessaoWork avancarDescanso(int agoraMs) {
    final FaseSessaoWork proximaFase = FaseSessaoWork.exercicioRodando;
    final bool eraTransicao = phase == FaseSessaoWork.transicaoProximoExercicio;
    final SnapshotSessaoWork base =
        phase == FaseSessaoWork.descansoSerie ||
            phase == FaseSessaoWork.transicaoProximoExercicio
        ? copiarCom(updatedAtMs: agoraMs)
        : _recalcularCronometro(agoraMs);

    return base.copiarCom(
      endsAtMs: null,
      exerciseIndex: eraTransicao ? exerciseIndex + 1 : exerciseIndex,
      pausedFromPhase: null,
      pausedRemainingMs: null,
      phase: proximaFase,
      phaseBaseElapsedSeconds: exerciseElapsedSeconds,
      phaseStartedAtMs: agoraMs,
      setIndex: eraTransicao ? 0 : setIndex + 1,
      updatedAtMs: agoraMs,
    );
  }

  SnapshotSessaoWork _recalcularCronometro(int agoraMs) {
    if (phase != FaseSessaoWork.exercicioRodando &&
        phase != FaseSessaoWork.cardioRodando) {
      return copiarCom(updatedAtMs: agoraMs);
    }

    final int elapsed =
        (phaseBaseElapsedSeconds +
                ((agoraMs - phaseStartedAtMs) / 1000).floor())
            .clamp(0, 1 << 31);

    if (phase == FaseSessaoWork.cardioRodando) {
      return copiarCom(
        cardioElapsedSeconds: elapsed,
        elapsedSeconds: elapsed,
        updatedAtMs: agoraMs,
      );
    }

    return copiarCom(
      elapsedSeconds: elapsed,
      exerciseElapsedSeconds: elapsed,
      updatedAtMs: agoraMs,
    );
  }
}

class SessaoWorkPayload {
  const SessaoWorkPayload({
    required this.active,
    required this.snapshot,
    required this.status,
    required this.updatedAt,
  });

  factory SessaoWorkPayload.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> snapshotJson = lerObjetoJson(json, 'snapshot');

    return SessaoWorkPayload(
      active: lerBoolJson(json, 'active'),
      snapshot: snapshotJson.isEmpty
          ? null
          : SnapshotSessaoWork.fromJson(snapshotJson),
      status: StatusSessaoWork.fromJson(json['status']),
      updatedAt: lerStringOpcionalJson(json, 'updatedAt'),
    );
  }

  final bool active;
  final SnapshotSessaoWork? snapshot;
  final StatusSessaoWork? status;
  final String? updatedAt;
}

class ExercicioWork {
  const ExercicioWork({
    required this.id,
    required this.mediaImageUrl,
    required this.mediaVideoUrl,
    required this.mediaYoutubeUrl,
    required this.mediaYoutubeVideoId,
    required this.name,
    required this.observation,
    required this.order,
    required this.reps,
    required this.restSeconds,
    required this.sets,
    required this.weight,
  });

  factory ExercicioWork.fromJson(Map<String, Object?> json) {
    return ExercicioWork(
      id: lerStringJson(json, 'id'),
      mediaImageUrl: lerStringOpcionalJson(json, 'mediaImageUrl'),
      mediaVideoUrl: lerStringOpcionalJson(json, 'mediaVideoUrl'),
      mediaYoutubeUrl: lerStringOpcionalJson(json, 'mediaYoutubeUrl'),
      mediaYoutubeVideoId: lerStringOpcionalJson(json, 'mediaYoutubeVideoId'),
      name: lerStringJson(json, 'name'),
      observation: lerStringJson(json, 'observation'),
      order: _lerInteiro(json['order']),
      reps: lerStringJson(json, 'reps'),
      restSeconds: _lerInteiro(json['restSeconds']),
      sets: _lerInteiro(json['sets']),
      weight: lerStringJson(json, 'weight'),
    );
  }

  final String id;
  final String? mediaImageUrl;
  final String? mediaVideoUrl;
  final String? mediaYoutubeUrl;
  final String? mediaYoutubeVideoId;
  final String name;
  final String observation;
  final int order;
  final String reps;
  final int restSeconds;
  final int sets;
  final String weight;
}

class CardioWork {
  const CardioWork({
    required this.duration,
    required this.id,
    required this.type,
  });

  factory CardioWork.fromJson(Map<String, Object?> json) {
    return CardioWork(
      duration: lerStringJson(json, 'duration'),
      id: lerStringJson(json, 'id'),
      type: lerStringJson(json, 'type'),
    );
  }

  final String duration;
  final String id;
  final String type;
}

class FichaWork {
  const FichaWork({
    required this.cardio,
    required this.category,
    required this.completionCount,
    required this.createdAt,
    required this.description,
    required this.estimatedMinutes,
    required this.exercises,
    required this.fichaTreinoId,
    required this.id,
    required this.key,
    required this.lastCompletedAt,
    required this.lastCompletedSets,
    required this.loadProgress,
    required this.professionalId,
    required this.professionalName,
    required this.recentHistory,
    required this.restSeconds,
    required this.title,
    required this.totalPlannedSets,
  });

  factory FichaWork.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> cardioJson = lerObjetoJson(json, 'cardio');

    return FichaWork(
      cardio: cardioJson.isEmpty ? null : CardioWork.fromJson(cardioJson),
      category: lerStringJson(json, 'category'),
      completionCount: _lerInteiro(json['completionCount']),
      createdAt: lerStringJson(json, 'createdAt'),
      description: lerStringJson(json, 'description'),
      estimatedMinutes: _lerInteiro(json['estimatedMinutes']),
      exercises: lerListaJson(json, 'exercises')
          .whereType<Map<String, Object?>>()
          .map(ExercicioWork.fromJson)
          .toList(growable: false),
      fichaTreinoId: lerStringJson(json, 'fichaTreinoId'),
      id: lerStringJson(json, 'id'),
      key: lerStringJson(json, 'key'),
      lastCompletedAt: lerStringOpcionalJson(json, 'lastCompletedAt'),
      lastCompletedSets: _lerInteiro(json['lastCompletedSets']),
      loadProgress: ProgressoCargaWork.fromJson(
        lerObjetoJson(json, 'loadProgress'),
      ),
      professionalId: lerStringJson(json, 'professionalId'),
      professionalName: lerStringJson(json, 'professionalName'),
      recentHistory: lerListaJson(json, 'recentHistory')
          .whereType<Map<String, Object?>>()
          .map(HistoricoExecucaoWork.fromJson)
          .toList(growable: false),
      restSeconds: _lerInteiro(json['restSeconds']),
      title: lerStringJson(json, 'title'),
      totalPlannedSets: _lerInteiro(json['totalPlannedSets']),
    );
  }

  final CardioWork? cardio;
  final String category;
  final int completionCount;
  final String createdAt;
  final String description;
  final int estimatedMinutes;
  final List<ExercicioWork> exercises;
  final String fichaTreinoId;
  final String id;
  final String key;
  final String? lastCompletedAt;
  final int lastCompletedSets;
  final ProgressoCargaWork loadProgress;
  final String professionalId;
  final String professionalName;
  final List<HistoricoExecucaoWork> recentHistory;
  final int restSeconds;
  final String title;
  final int totalPlannedSets;
}

class HistoricoExecucaoWork {
  const HistoricoExecucaoWork({
    required this.cardioDone,
    required this.completedAt,
    required this.completedSets,
    required this.id,
    required this.totalLoadKg,
    required this.totalSets,
  });

  factory HistoricoExecucaoWork.fromJson(Map<String, Object?> json) {
    return HistoricoExecucaoWork(
      cardioDone: lerBoolJson(json, 'cardioDone'),
      completedAt: lerStringJson(json, 'completedAt'),
      completedSets: _lerInteiro(json['completedSets']),
      id: lerStringJson(json, 'id'),
      totalLoadKg: _lerDouble(json['totalLoadKg']),
      totalSets: _lerInteiro(json['totalSets']),
    );
  }

  final bool cardioDone;
  final String completedAt;
  final int completedSets;
  final String id;
  final double totalLoadKg;
  final int totalSets;
}

class ProgressoCargaWork {
  const ProgressoCargaWork({
    required this.deltaKg,
    required this.lastLoadKg,
    required this.previousLoadKg,
  });

  factory ProgressoCargaWork.fromJson(Map<String, Object?> json) {
    return ProgressoCargaWork(
      deltaKg: _lerDoubleOpcional(json['deltaKg']),
      lastLoadKg: _lerDoubleOpcional(json['lastLoadKg']),
      previousLoadKg: _lerDoubleOpcional(json['previousLoadKg']),
    );
  }

  final double? deltaKg;
  final double? lastLoadKg;
  final double? previousLoadKg;
}

class BootstrapWorkMobile {
  const BootstrapWorkMobile({
    required this.activeSession,
    required this.emptyMessage,
    required this.profile,
    required this.success,
    required this.todayCompletion,
    required this.workouts,
  });

  factory BootstrapWorkMobile.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> todayCompletionJson = lerObjetoJson(
      json,
      'todayCompletion',
    );

    return BootstrapWorkMobile(
      activeSession: SessaoWorkPayload.fromJson(
        lerObjetoJson(json, 'activeSession'),
      ),
      emptyMessage: lerStringJson(json, 'emptyMessage'),
      profile: PerfilWorkMobile.fromJson(lerObjetoJson(json, 'profile')),
      success: lerBoolJson(json, 'success'),
      todayCompletion: todayCompletionJson.isEmpty
          ? null
          : ConclusaoHojeWork.fromJson(todayCompletionJson),
      workouts: lerListaJson(json, 'workouts')
          .whereType<Map<String, Object?>>()
          .map(FichaWork.fromJson)
          .toList(growable: false),
    );
  }

  final SessaoWorkPayload activeSession;
  final String emptyMessage;
  final PerfilWorkMobile profile;
  final bool success;
  final ConclusaoHojeWork? todayCompletion;
  final List<FichaWork> workouts;
}

class PerfilWorkMobile {
  const PerfilWorkMobile({
    required this.personalName,
    required this.trainingLevel,
    required this.userName,
    required this.workoutTime,
  });

  factory PerfilWorkMobile.fromJson(Map<String, Object?> json) {
    return PerfilWorkMobile(
      personalName: lerStringJson(json, 'personalName'),
      trainingLevel: lerStringJson(json, 'trainingLevel'),
      userName: lerStringJson(json, 'userName'),
      workoutTime: lerStringJson(json, 'workoutTime'),
    );
  }

  final String personalName;
  final String trainingLevel;
  final String userName;
  final String workoutTime;
}

class ConclusaoHojeWork {
  const ConclusaoHojeWork({
    required this.completedAt,
    required this.executionId,
    required this.workoutId,
    required this.workoutKey,
    required this.workoutTitle,
  });

  factory ConclusaoHojeWork.fromJson(Map<String, Object?> json) {
    return ConclusaoHojeWork(
      completedAt: lerStringJson(json, 'completedAt'),
      executionId: lerStringJson(json, 'executionId'),
      workoutId: lerStringJson(json, 'workoutId'),
      workoutKey: lerStringJson(json, 'workoutKey'),
      workoutTitle: lerStringJson(json, 'workoutTitle'),
    );
  }

  final String completedAt;
  final String executionId;
  final String workoutId;
  final String workoutKey;
  final String workoutTitle;
}

class TaxaKcalWork {
  const TaxaKcalWork({
    required this.kcalPerMinute,
    required this.method,
    required this.met,
    required this.observation,
    required this.success,
    required this.workoutId,
  });

  factory TaxaKcalWork.fromJson(Map<String, Object?> json) {
    return TaxaKcalWork(
      kcalPerMinute: _lerDouble(json['kcalPerMinute']),
      method: lerStringOpcionalJson(json, 'method'),
      met: _lerDoubleOpcional(json['met']),
      observation: lerStringOpcionalJson(json, 'observation'),
      success: lerBoolJson(json, 'success'),
      workoutId: lerStringJson(json, 'workoutId'),
    );
  }

  final double kcalPerMinute;
  final String? method;
  final double? met;
  final String? observation;
  final bool success;
  final String workoutId;
}

class SerieConcluidaWork {
  const SerieConcluidaWork({
    required this.completed,
    required this.exerciseId,
    required this.repetitionsDone,
    required this.setNumber,
    required this.weightUsedKg,
  });

  factory SerieConcluidaWork.fromJson(Map<String, Object?> json) {
    return SerieConcluidaWork(
      completed: lerBoolJson(json, 'completed'),
      exerciseId: lerStringJson(json, 'exerciseId'),
      repetitionsDone: _lerInteiroOpcional(json['repetitionsDone']),
      setNumber: _lerInteiro(json['setNumber']),
      weightUsedKg: _lerDoubleOpcional(json['weightUsedKg']),
    );
  }

  final bool completed;
  final String exerciseId;
  final int? repetitionsDone;
  final int setNumber;
  final double? weightUsedKg;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'completed': completed,
      'exerciseId': exerciseId,
      'repetitionsDone': repetitionsDone,
      'setNumber': setNumber,
      'weightUsedKg': weightUsedKg,
    };
  }
}

class ConclusaoWorkInput {
  const ConclusaoWorkInput({
    required this.cardioDone,
    required this.completedSeries,
    required this.estimatedKcalBurned,
    required this.workoutId,
  });

  factory ConclusaoWorkInput.fromJson(Map<String, Object?> json) {
    return ConclusaoWorkInput(
      cardioDone: lerBoolJson(json, 'cardioDone'),
      completedSeries: lerListaJson(json, 'completedSeries')
          .whereType<Map<String, Object?>>()
          .map(SerieConcluidaWork.fromJson)
          .toList(growable: false),
      estimatedKcalBurned: _lerDoubleOpcional(json['estimatedKcalBurned']),
      workoutId: lerStringJson(json, 'workoutId'),
    );
  }

  final bool cardioDone;
  final List<SerieConcluidaWork> completedSeries;
  final double? estimatedKcalBurned;
  final String workoutId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'cardioDone': cardioDone,
      'completedSeries': completedSeries
          .map((SerieConcluidaWork serie) => serie.toJson())
          .toList(growable: false),
      'estimatedKcalBurned': estimatedKcalBurned,
      'workoutId': workoutId,
    };
  }
}

class ResultadoConclusaoWork {
  const ResultadoConclusaoWork({
    required this.completedAt,
    required this.executionId,
    required this.message,
    required this.success,
  });

  factory ResultadoConclusaoWork.fromJson(Map<String, Object?> json) {
    return ResultadoConclusaoWork(
      completedAt: lerStringOpcionalJson(json, 'completedAt'),
      executionId: lerStringOpcionalJson(json, 'executionId'),
      message: lerStringJson(json, 'message'),
      success: lerBoolJson(json, 'success'),
    );
  }

  final String? completedAt;
  final String? executionId;
  final String message;
  final bool success;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'completedAt': completedAt,
      'executionId': executionId,
      'message': message,
      'success': success,
    };
  }
}

int _lerInteiro(Object? value) {
  if (value is int) {
    return value < 0 ? 0 : value;
  }

  if (value is double && value.isFinite) {
    return value < 0 ? 0 : value.floor();
  }

  return 0;
}

int? _lerInteiroOpcional(Object? value) {
  if (value == null) {
    return null;
  }

  return _lerInteiro(value);
}

double _lerDouble(Object? value) {
  if (value is int) {
    return value.toDouble();
  }

  if (value is double && value.isFinite) {
    return value;
  }

  return 0;
}

double? _lerDoubleOpcional(Object? value) {
  if (value == null) {
    return null;
  }

  return _lerDouble(value);
}

const Object _semAlteracao = Object();
