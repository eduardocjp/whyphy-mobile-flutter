import 'dart:async';

import 'package:flutter/material.dart';

import '../../funcionalidades/work/servicos/servico_execucao_work.dart';
import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import '../models/work_modelos.dart';

class WorkTimerFlutuante extends StatefulWidget {
  const WorkTimerFlutuante({
    super.key,
    required this.onTap,
    required this.servicoExecucaoWork,
    required this.visivel,
  });

  final VoidCallback onTap;
  final ServicoExecucaoWork servicoExecucaoWork;
  final bool visivel;

  @override
  State<WorkTimerFlutuante> createState() => _WorkTimerFlutuanteState();
}

class _WorkTimerFlutuanteState extends State<WorkTimerFlutuante> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.servicoExecucaoWork.addListener(_atualizar);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _atualizar());
  }

  @override
  void didUpdateWidget(covariant WorkTimerFlutuante oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.servicoExecucaoWork != widget.servicoExecucaoWork) {
      oldWidget.servicoExecucaoWork.removeListener(_atualizar);
      widget.servicoExecucaoWork.addListener(_atualizar);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.servicoExecucaoWork.removeListener(_atualizar);
    super.dispose();
  }

  void _atualizar() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final SnapshotSessaoWork? snapshotBase =
        widget.servicoExecucaoWork.snapshotAtual;

    if (!widget.visivel || snapshotBase == null || !snapshotBase.ativo) {
      return const SizedBox.shrink();
    }

    final SnapshotSessaoWork snapshot = widget.servicoExecucaoWork.cronometro
        .recalcular(snapshotBase);

    return Positioned(
      left: 16,
      right: 16,
      bottom: 18,
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: EspacamentoApp.medio,
                vertical: EspacamentoApp.pequeno,
              ),
              decoration: BoxDecoration(
                color: CoresApp.superficieElevada,
                border: Border.all(
                  color: CoresApp.treinos.withValues(alpha: 0.72),
                ),
                borderRadius: const BorderRadius.all(Radius.circular(24)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: CoresApp.treinos.withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                  const BoxShadow(
                    color: Color(0xAA000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: CoresApp.treinos,
                    child: Icon(
                      Icons.timer_outlined,
                      color: CoresApp.fundo,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: EspacamentoApp.pequeno),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'Work em andamento',
                          style: TextStyle(
                            color: CoresApp.textoPrincipal,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          _labelFase(snapshot),
                          style: const TextStyle(
                            color: CoresApp.textoSecundario,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatStopwatch(snapshot.totalElapsedSeconds),
                    style: const TextStyle(
                      color: CoresApp.textoPrincipal,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _labelFase(SnapshotSessaoWork snapshot) {
  return switch (snapshot.phase) {
    FaseSessaoWork.descansoSerie => 'Descanso ativo',
    FaseSessaoWork.transicaoProximoExercicio => 'Transição de exercício',
    FaseSessaoWork.cardioRodando => 'Cardio ativo',
    FaseSessaoWork.pausado => 'Pausado',
    _ => 'Toque para retomar',
  };
}

String _formatStopwatch(int seconds) {
  final int safeSeconds = seconds < 0 ? 0 : seconds;
  final int hours = safeSeconds ~/ 3600;
  final int minutes = (safeSeconds % 3600) ~/ 60;
  final int remainingSeconds = safeSeconds % 60;

  return <int>[
    hours,
    minutes,
    remainingSeconds,
  ].map((int value) => value.toString().padLeft(2, '0')).join(':');
}
