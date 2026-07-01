import '../../../work/models/work_modelos.dart';

class ServicoCronometroWork {
  const ServicoCronometroWork();

  int agoraMs() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  int segundosRestantes(SnapshotSessaoWork snapshot) {
    final int? endsAtMs = snapshot.endsAtMs;

    if (endsAtMs == null) {
      return 0;
    }

    final int restanteMs = endsAtMs - agoraMs();

    if (restanteMs <= 0) {
      return 0;
    }

    return (restanteMs / 1000).ceil();
  }

  SnapshotSessaoWork recalcular(SnapshotSessaoWork snapshot) {
    return snapshot.recalcular(agoraMs());
  }
}
