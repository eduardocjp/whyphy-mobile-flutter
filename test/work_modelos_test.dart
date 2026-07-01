import 'package:flutter_test/flutter_test.dart';
import 'package:whyphy_app/work/models/work_modelos.dart';

void main() {
  group('SnapshotSessaoWork.recalcular', () {
    test('avanca descanso vencido sem recursao', () {
      final SnapshotSessaoWork snapshot = _snapshotBase(
        endsAtMs: 1200,
        phase: FaseSessaoWork.descansoSerie,
        setIndex: 0,
      );

      final SnapshotSessaoWork recalculado = snapshot.recalcular(1300);

      expect(recalculado.phase, FaseSessaoWork.exercicioRodando);
      expect(recalculado.endsAtMs, isNull);
      expect(recalculado.exerciseIndex, 0);
      expect(recalculado.setIndex, 1);
      expect(recalculado.updatedAtMs, 1300);
    });

    test('avanca transicao vencida para o proximo exercicio sem recursao', () {
      final SnapshotSessaoWork snapshot = _snapshotBase(
        endsAtMs: 1200,
        phase: FaseSessaoWork.transicaoProximoExercicio,
        setIndex: 2,
      );

      final SnapshotSessaoWork recalculado = snapshot.recalcular(1300);

      expect(recalculado.phase, FaseSessaoWork.exercicioRodando);
      expect(recalculado.endsAtMs, isNull);
      expect(recalculado.exerciseIndex, 1);
      expect(recalculado.setIndex, 0);
      expect(recalculado.updatedAtMs, 1300);
    });
  });
}

SnapshotSessaoWork _snapshotBase({
  required int? endsAtMs,
  required FaseSessaoWork phase,
  required int setIndex,
}) {
  return SnapshotSessaoWork(
    cardioElapsedSeconds: 0,
    cardioIndex: null,
    elapsedSeconds: 30,
    endsAtMs: endsAtMs,
    exerciseElapsedSeconds: 30,
    exerciseIndex: 0,
    pausedAccumulatedMs: 0,
    pausedFromPhase: null,
    pausedRemainingMs: null,
    phase: phase,
    phaseBaseElapsedSeconds: 30,
    phaseStartedAtMs: 1000,
    restSeconds: 20,
    setIndex: setIndex,
    startedAtMs: 0,
    status: StatusSessaoWork.ativo,
    updatedAtMs: 1000,
    workoutId: 'workout-1',
  );
}
