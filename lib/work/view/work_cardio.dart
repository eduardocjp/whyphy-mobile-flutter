import 'package:flutter/material.dart';

import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import '../../nucleo/tema/raios_app.dart';
import '../controller/work_controller.dart';
import '../models/work_modelos.dart';

const double _gapCardio = EspacamentoApp.gapCompacto;
const double _cardioButtonHeight = 48;
const Color _corCardioOk = Color(0xFF34D399);

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

    if (workout == null) {
      return const SizedBox.shrink();
    }

    final bool cardioIniciado = controlador.cardioIniciado;
    final bool pausado = cardioIniciado && fase == FaseSessaoWork.pausado;
    final bool rodando = cardioIniciado && fase == FaseSessaoWork.cardioRodando;
    final bool pronto = cardioIniciado || controlador.cardioElapsedSeconds > 0;
    final bool podeFinalizar = !rodando;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EspacamentoApp.pequeno,
        EspacamentoApp.gapCompacto,
        EspacamentoApp.pequeno,
        EspacamentoApp.minimo,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CoresApp.fundo,
          border: Border.all(color: CoresApp.borda),
          borderRadius: const BorderRadius.all(Radius.circular(RaiosApp.medio)),
        ),
        child: Column(
          children: <Widget>[
            const _CardioHero(),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(EspacamentoApp.pequeno),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _CardioResumo(cardio: cardio, pronto: pronto),
                    const SizedBox(height: _gapCardio),
                    _CardioInfo(
                      controlador: controlador,
                      status: rodando
                          ? 'em andamento'
                          : pausado
                          ? 'pausado'
                          : cardioIniciado
                          ? 'pronto'
                          : 'não iniciado',
                    ),
                  ],
                ),
              ),
            ),
            _CardioActions(
              controlador: controlador,
              cardio: cardio,
              rodando: rodando,
              podeFinalizar: podeFinalizar,
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
      padding: const EdgeInsets.all(EspacamentoApp.pequeno),
      decoration: BoxDecoration(
        border: const Border(bottom: BorderSide(color: CoresApp.borda)),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RaiosApp.medio),
        ),
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.15,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.10),
            CoresApp.fundo,
            CoresApp.fundo,
          ],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Eyebrow('Track de treino'),
          SizedBox(height: EspacamentoApp.minimo),
          Text(
            'Hora de fechar com cardio.',
            style: TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: EspacamentoApp.minimo),
          Text(
            'Inicie o cardio quando estiver pronto. O cronômetro do cardio só começa após o toque em iniciar.',
            style: TextStyle(
              color: CoresApp.textoSecundario,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.28,
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
          const _Eyebrow('Cardio'),
          const SizedBox(height: EspacamentoApp.minimo),
          Text(
            cardio?.type ?? 'Cardio livre',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: EspacamentoApp.pequeno),
          Row(
            children: <Widget>[
              Expanded(
                child: _Metrica(
                  label: 'Duração',
                  value: cardio?.duration ?? 'Livre',
                ),
              ),
              const SizedBox(width: _gapCardio),
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
          value: 'Cardio: $status',
        ),
        const SizedBox(height: _gapCardio),
        _Painel(
          child: Row(
            children: <Widget>[
              const _IconeModulo(icon: Icons.access_time_rounded),
              const SizedBox(width: EspacamentoApp.pequeno),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _Eyebrow('Cronômetro cardio'),
                    const SizedBox(height: EspacamentoApp.minimo),
                    Text(
                      _formatStopwatch(controlador.cardioElapsedSeconds),
                      style: const TextStyle(
                        color: CoresApp.textoPrincipal,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: EspacamentoApp.minimo),
                    Text(
                      'Calorias estimadas: ${controlador.kcalEstimadas.round()} kcal',
                      style: const TextStyle(
                        color: _corCardioOk,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Exercícios: ${_formatStopwatch(controlador.exerciseElapsedSeconds)} · Total: ${_formatStopwatch(controlador.totalElapsedSeconds)}',
                      style: const TextStyle(
                        color: CoresApp.textoSuave,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    if (controlador.cardioIniciado &&
                        controlador.segundosRestantesFase > 0) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        'Meta restante: ${_formatStopwatch(controlador.segundosRestantesFase)}',
                        style: const TextStyle(
                          color: CoresApp.textoSecundario,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _CardioActions extends StatelessWidget {
  const _CardioActions({
    required this.controlador,
    required this.cardio,
    required this.rodando,
    required this.podeFinalizar,
  });

  final ControladorWorkNativo controlador;
  final CardioWork? cardio;
  final bool rodando;
  final bool podeFinalizar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        EspacamentoApp.pequeno,
        EspacamentoApp.minimo,
        EspacamentoApp.pequeno,
        MediaQuery.paddingOf(context).bottom + EspacamentoApp.gapCompacto,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (cardio != null)
            _BotaoCardio(
              primary: true,
              enabled: true,
              icon: rodando
                  ? Icons.pause_circle_outline_rounded
                  : Icons.play_circle_outline_rounded,
              label: controlador.textoBotaoCardio,
              onTap: () {
                controlador.pausarOuRetomarCardio();
              },
            ),
          if (cardio != null) const SizedBox(height: _gapCardio),
          _BotaoCardio(
            primary: false,
            enabled: podeFinalizar,
            icon: Icons.fitness_center_rounded,
            label: podeFinalizar ? 'Finalizar treino' : 'Pause para finalizar',
            onTap: podeFinalizar
                ? () {
                    controlador.concluirTreino();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _BotaoCardio extends StatelessWidget {
  const _BotaoCardio({
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primary,
  });

  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final Color background = primary
        ? CoresApp.treinos
        : CoresApp.fundo.withValues(alpha: 0.30);
    final Color border = primary ? CoresApp.treinos : CoresApp.borda;
    final Color foreground = primary ? Colors.black : CoresApp.textoPrincipal;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: const BorderRadius.all(Radius.circular(RaiosApp.total)),
        child: Container(
          height: _cardioButtonHeight,
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: border, width: 1.2),
            borderRadius: const BorderRadius.all(
              Radius.circular(RaiosApp.total),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 10),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({required this.pronto});

  final bool pronto;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(
        horizontal: EspacamentoApp.pequeno,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: pronto
            ? CoresApp.treinos.withValues(alpha: 0.12)
            : CoresApp.fundo.withValues(alpha: 0.35),
        border: Border.all(
          color: pronto
              ? CoresApp.treinos.withValues(alpha: 0.72)
              : CoresApp.borda,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(RaiosApp.pequeno)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 13,
            backgroundColor: pronto
                ? CoresApp.treinos
                : CoresApp.superficieElevada,
            child: Icon(
              Icons.check_rounded,
              color: pronto ? CoresApp.fundo : CoresApp.textoSuave,
              size: 17,
            ),
          ),
          const SizedBox(width: EspacamentoApp.pequeno),
          Expanded(
            child: Text(
              pronto ? 'Pronto' : 'Pendente',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CoresApp.textoPrincipal,
                fontSize: 13,
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
          const SizedBox(width: EspacamentoApp.pequeno),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Eyebrow(label),
                const SizedBox(height: EspacamentoApp.minimo),
                Text(
                  value,
                  style: const TextStyle(
                    color: CoresApp.textoSecundario,
                    fontSize: 13,
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
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(
        horizontal: EspacamentoApp.pequeno,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.35),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(RaiosApp.pequeno)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Eyebrow(label),
          const SizedBox(height: 3),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
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
      radius: 17,
      backgroundColor: CoresApp.treinos.withValues(alpha: 0.15),
      child: Icon(icon, color: CoresApp.treinos, size: 18),
    );
  }
}

class _Painel extends StatelessWidget {
  const _Painel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspacamentoApp.pequeno),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.34),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(RaiosApp.medio)),
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
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
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
