import 'package:flutter/material.dart';

import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import '../controller/work_controller.dart';
import '../models/work_modelos.dart';

class WorkCardio extends StatelessWidget {
  const WorkCardio({
    super.key,
    required this.controlador,
    required this.onCompartilhar,
    this.onHome,
  });

  final ControladorWorkNativo controlador;
  final VoidCallback onCompartilhar;
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    final FichaWork? workout = controlador.workout;
    final CardioWork? cardio = workout?.cardio;
    final FaseSessaoWork? fase = controlador.snapshot?.phase;
    final bool pausado = fase == FaseSessaoWork.pausado;
    final bool rodando = fase == FaseSessaoWork.cardioRodando;
    final bool podeFinalizar = !rodando;

    if (workout == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CoresApp.superficie,
          border: Border.all(color: CoresApp.borda),
          borderRadius: const BorderRadius.all(Radius.circular(30)),
        ),
        child: Column(
          children: <Widget>[
            const _CardioHero(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(EspacamentoApp.grande),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _CardioResumo(cardio: cardio, pronto: rodando || pausado),
                    const SizedBox(height: EspacamentoApp.medio),
                    _CardioInfo(
                      controlador: controlador,
                      status: rodando
                          ? 'em andamento'
                          : pausado
                          ? 'pausado'
                          : 'não iniciado',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (cardio != null)
                    FilledButton.icon(
                      onPressed: controlador.pausarOuRetomarCardio,
                      icon: Icon(
                        rodando
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                      ),
                      label: Text(
                        rodando
                            ? 'Pausar'
                            : pausado
                            ? 'Retomar track'
                            : 'Iniciar track',
                      ),
                    ),
                  const SizedBox(height: EspacamentoApp.pequeno),
                  OutlinedButton.icon(
                    onPressed: podeFinalizar
                        ? controlador.concluirTreino
                        : null,
                    icon: const Icon(Icons.fitness_center_rounded),
                    label: Text(
                      podeFinalizar
                          ? 'Finalizar treino'
                          : 'Pause para finalizar',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardioHero extends StatelessWidget {
  const _CardioHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(EspacamentoApp.grande),
      decoration: BoxDecoration(
        border: const Border(bottom: BorderSide(color: CoresApp.borda)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.2,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.12),
            CoresApp.superficie,
            CoresApp.superficie,
          ],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Eyebrow('Track de treino'),
          SizedBox(height: EspacamentoApp.medio),
          Text(
            'Hora de fechar com cardio.',
            style: TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          SizedBox(height: EspacamentoApp.pequeno),
          Text(
            'Finalize a sessão com o cardio para registrar o treino.',
            style: TextStyle(
              color: CoresApp.textoSecundario,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardioResumo extends StatelessWidget {
  const _CardioResumo({required this.cardio, required this.pronto});

  final CardioWork? cardio;
  final bool pronto;

  @override
  Widget build(BuildContext context) {
    return _Painel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            cardio?.type ?? 'Cardio livre',
            style: const TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: EspacamentoApp.medio),
          Row(
            children: <Widget>[
              Expanded(
                child: _Metrica(
                  label: 'Duração',
                  value: cardio?.duration ?? 'Livre',
                ),
              ),
              const SizedBox(width: EspacamentoApp.pequeno),
              Expanded(child: _CheckCard(pronto: pronto)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardioInfo extends StatelessWidget {
  const _CardioInfo({required this.controlador, required this.status});

  final ControladorWorkNativo controlador;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _InfoLine(
          icon: Icons.monitor_heart_outlined,
          label: 'Status',
          value: 'Track atual: $status',
        ),
        const SizedBox(height: EspacamentoApp.pequeno),
        _Painel(
          child: Row(
            children: <Widget>[
              const _IconeModulo(icon: Icons.access_time_rounded),
              const SizedBox(width: EspacamentoApp.medio),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _Eyebrow('Cronômetro'),
                    Text(
                      _formatStopwatch(controlador.totalElapsedSeconds),
                      style: const TextStyle(
                        color: CoresApp.textoPrincipal,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    Text(
                      'Calorias estimadas: ${controlador.kcalEstimadas.round()} kcal',
                      style: const TextStyle(
                        color: Color(0xFF86EFAC),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Exercícios: ${_formatStopwatch(controlador.exerciseElapsedSeconds)} | Cardio: ${_formatStopwatch(controlador.cardioElapsedSeconds)}',
                      style: const TextStyle(
                        color: CoresApp.textoSuave,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (controlador.segundosRestantesFase > 0)
                      Text(
                        'Meta restante: ${_formatStopwatch(controlador.segundosRestantesFase)}',
                        style: const TextStyle(
                          color: CoresApp.textoSecundario,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({required this.pronto});

  final bool pronto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspacamentoApp.medio),
      decoration: BoxDecoration(
        color: pronto
            ? CoresApp.treinos.withValues(alpha: 0.12)
            : CoresApp.fundo.withValues(alpha: 0.35),
        border: Border.all(
          color: pronto
              ? CoresApp.treinos.withValues(alpha: 0.72)
              : CoresApp.borda,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 17,
            backgroundColor: pronto
                ? CoresApp.treinos
                : CoresApp.superficieElevada,
            child: Icon(
              Icons.check_rounded,
              color: pronto ? CoresApp.fundo : CoresApp.textoSuave,
              size: 20,
            ),
          ),
          const SizedBox(width: EspacamentoApp.pequeno),
          Expanded(
            child: Text(
              pronto ? 'Pronto' : 'Pendente',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CoresApp.textoPrincipal,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _Painel(
      child: Row(
        children: <Widget>[
          _IconeModulo(icon: icon),
          const SizedBox(width: EspacamentoApp.medio),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Eyebrow(label),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: CoresApp.textoSecundario,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspacamentoApp.medio),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.35),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Eyebrow(label),
          const SizedBox(height: EspacamentoApp.pequeno),
          Text(
            value,
            style: const TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconeModulo extends StatelessWidget {
  const _IconeModulo({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: CoresApp.treinos.withValues(alpha: 0.15),
      child: Icon(icon, color: CoresApp.treinos, size: 20),
    );
  }
}

class _Painel extends StatelessWidget {
  const _Painel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspacamentoApp.medio),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.34),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(22)),
      ),
      child: child,
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: const TextStyle(
        color: CoresApp.treinos,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
      ),
    );
  }
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
