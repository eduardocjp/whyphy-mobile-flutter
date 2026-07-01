import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import '../../nucleo/tema/raios_app.dart';
import '../controller/work_controller.dart';
import '../models/work_modelos.dart';

const Color _corExecucaoSerie = CoresApp.serieExecucao;
const Color _corDescansoSerie = CoresApp.serieDescanso;

const double _gapWork = EspacamentoApp.gapCompacto;
const double _alturaBotaoInferior = 48;
const double _alturaBotaoSerie = 32;
const double _alturaPreviewCompacta = 92;
const double _larguraPreviewCompacta = 132;

const String _youtubeOrigin = 'https://whyphy.com.br';
const String _youtubeReferer = 'https://whyphy.com.br/';

class WorkExecutar extends StatefulWidget {
  const WorkExecutar({
    super.key,
    required this.controlador,
    this.onClose,
    this.onHome,
  });

  final ControladorWorkNativo controlador;
  final VoidCallback? onClose;
  final VoidCallback? onHome;

  @override
  State<WorkExecutar> createState() => _WorkExecutarState();
}

class _WorkExecutarState extends State<WorkExecutar> {
  bool _avisoSeriesPendente = false;
  ExercicioWork? _midiaAberta;

  ControladorWorkNativo get controlador => widget.controlador;

  Future<void> _avancar({required bool forcar}) async {
    try {
      await controlador.avancarExercicio(forcar: forcar);
      setState(() => _avisoSeriesPendente = false);
    } on WorkSeriesPendentes {
      setState(() => _avisoSeriesPendente = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FichaWork? workout = controlador.workout;
    final ExercicioWork? exercicio = controlador.exercicioAtual;

    if (workout == null || exercicio == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: CoresApp.fundo,
            border: Border.all(color: CoresApp.borda),
          ),
          child: Column(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    EspacamentoApp.pequeno,
                    EspacamentoApp.gapCompacto,
                    EspacamentoApp.pequeno,
                    EspacamentoApp.minimo,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _ProgressoTreino(controlador: controlador),
                      const SizedBox(height: _gapWork),
                      _CardExercicio(
                        exercicio: exercicio,
                        indice: controlador.indiceExercicioAtual,
                        seriesTotal: controlador.totalSeriesExercicio(
                          exercicio,
                        ),
                        total: workout.exercises.length,
                        onAbrirMidia: _temMidia(exercicio)
                            ? () => setState(() => _midiaAberta = exercicio)
                            : null,
                      ),
                      const SizedBox(height: _gapWork),
                      Expanded(
                        flex: 4,
                        child: _SeriesList(
                          controlador: controlador,
                          exercicio: exercicio,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _AcoesExecucao(
                onAvancar: controlador.podePularDescanso
                    ? controlador.pularDescanso
                    : () => _avancar(forcar: false),
                onClose: widget.onHome ?? widget.onClose,
                textoAvancar: controlador.podePularDescanso
                    ? 'Pular descanso'
                    : 'Avançar',
                iconeAvancar: controlador.podePularDescanso
                    ? Icons.skip_next_rounded
                    : Icons.arrow_forward_rounded,
              ),
            ],
          ),
        ),
        if (_avisoSeriesPendente)
          _ModalSeriesPendentes(
            onAvancar: () => _avancar(forcar: true),
            onVoltar: () => setState(() => _avisoSeriesPendente = false),
          ),
        if (_midiaAberta != null)
          _ModalMidiaExercicio(
            exercicio: _midiaAberta!,
            onClose: () => setState(() => _midiaAberta = null),
          ),
      ],
    );
  }
}

class _ProgressoTreino extends StatelessWidget {
  const _ProgressoTreino({required this.controlador});

  final ControladorWorkNativo controlador;

  @override
  Widget build(BuildContext context) {
    final int totalSeries = controlador.totalSeries;
    final int completedSeries = controlador.completedSeries;
    final double progress = totalSeries == 0
        ? 0
        : completedSeries / totalSeries;

    return _Painel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: _Eyebrow('Progresso')),
              _PillStatus(
                text: '${controlador.kcalEstimadas.round()} kcal',
                color: _corDescansoSerie,
              ),
            ],
          ),
          const SizedBox(height: _gapWork),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${controlador.exerciciosContabilizados}/${controlador.totalExercicios}',
                  style: const TextStyle(
                    color: CoresApp.textoPrincipal,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              _PillStatus(
                text: _formatStopwatch(controlador.totalElapsedSeconds),
                color: CoresApp.textoPrincipal,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(RaiosApp.total),
            ),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 8,
              color: CoresApp.treinos,
              backgroundColor: CoresApp.superficieElevada,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillStatus extends StatelessWidget {
  const _PillStatus({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.40),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _CardExercicio extends StatelessWidget {
  const _CardExercicio({
    required this.exercicio,
    required this.indice,
    required this.seriesTotal,
    required this.total,
    this.onAbrirMidia,
  });

  final ExercicioWork exercicio;
  final int indice;
  final VoidCallback? onAbrirMidia;
  final int seriesTotal;
  final int total;

  @override
  Widget build(BuildContext context) {
    final bool temMidia = onAbrirMidia != null;

    return _Painel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Eyebrow('Exercício'),
          const SizedBox(height: EspacamentoApp.minimo),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      exercicio.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CoresApp.textoPrincipal,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: EspacamentoApp.pequeno),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _Metrica(
                            label: 'Séries',
                            value: '$seriesTotal',
                          ),
                        ),
                        const SizedBox(width: _gapWork),
                        Expanded(
                          child: _Metrica(label: 'Reps', value: exercicio.reps),
                        ),
                        const SizedBox(width: _gapWork),
                        Expanded(
                          child: _Metrica(
                            label: 'Peso',
                            value: exercicio.weight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (temMidia) ...<Widget>[
                const SizedBox(width: EspacamentoApp.pequeno),
                SizedBox(
                  width: _larguraPreviewCompacta,
                  height: _alturaPreviewCompacta,
                  child: _PreviewMidiaExercicio(
                    exercicio: exercicio,
                    onTap: onAbrirMidia!,
                  ),
                ),
              ],
            ],
          ),

          if (exercicio.observation.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: EspacamentoApp.pequeno),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: EspacamentoApp.regular,
                vertical: EspacamentoApp.pequeno,
              ),
              decoration: BoxDecoration(
                color: CoresApp.fundo.withValues(alpha: 0.38),
                border: Border.all(color: CoresApp.borda),
                borderRadius: const BorderRadius.all(
                  Radius.circular(RaiosApp.pequeno),
                ),
              ),
              child: Text(
                exercicio.observation,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CoresApp.textoSecundario,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewMidiaExercicio extends StatelessWidget {
  const _PreviewMidiaExercicio({required this.exercicio, required this.onTap});

  final ExercicioWork exercicio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? thumbnail = _resolverThumbnailUrl(exercicio);

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(RaiosApp.pequeno)),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(RaiosApp.pequeno)),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (thumbnail != null)
              Image.network(thumbnail, fit: BoxFit.cover)
            else
              const ColoredBox(color: CoresApp.fundo),

            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.38),
              ),
            ),

            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(RaiosApp.total),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.play_circle_outline_rounded,
                      color: CoresApp.textoPrincipal,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'VÍDEO',
                      style: TextStyle(
                        color: CoresApp.textoPrincipal,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesList extends StatelessWidget {
  const _SeriesList({required this.controlador, required this.exercicio});

  final ControladorWorkNativo controlador;
  final ExercicioWork exercicio;

  @override
  Widget build(BuildContext context) {
    final int total = controlador.totalSeriesExercicio(exercicio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: _Eyebrow('Séries e carga usada')),
            _ControleSerieButton(
              enabled: controlador.podeAcionarBotaoSerie,
              text: controlador.textoBotaoSerie,
              onPressed: () {
                controlador.acionarBotaoSerieAtual();
              },
            ),
          ],
        ),
        const SizedBox(height: _gapWork),
        Expanded(
          child: ListView.separated(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: total,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: _gapWork),
            itemBuilder: (BuildContext context, int index) {
              final int numero = index + 1;
              final SerieDraftWork draft = controlador.draftSerie(
                exercicio.id,
                numero,
              );
              final bool emExecucao = controlador.serieAtualEmExecucao(
                exercicio.id,
                numero,
              );
              final bool descanso = controlador.serieAtualEmDescanso(
                exercicio.id,
                numero,
              );

              return _SerieCard(
                bloqueado: controlador.edicaoSeriesBloqueada,
                concluida: controlador.serieConcluida(exercicio.id, numero),
                descanso: descanso,
                draft: draft,
                emExecucao: emExecucao,
                numero: numero,
                segundosRestantes: emExecucao || descanso
                    ? controlador.segundosRestantesFase
                    : null,
                onPesoChanged: (String value) {
                  controlador.atualizarDraftSerie(
                    exercicio.id,
                    numero,
                    peso: value,
                  );
                },
                onRepsChanged: (String value) {
                  controlador.atualizarDraftSerie(
                    exercicio.id,
                    numero,
                    reps: value,
                  );
                },
                onTap: () {
                  controlador.alternarSerie(exercicio.id, numero);
                },
              );
            },
          ),
        ),
        const SizedBox(height: _gapWork),
        _AdicionarSerieButton(
          enabled: !controlador.edicaoSeriesBloqueada,
          onPressed: () => controlador.adicionarSerie(exercicio),
        ),
      ],
    );
  }
}

class _ControleSerieButton extends StatelessWidget {
  const _ControleSerieButton({
    required this.enabled,
    required this.onPressed,
    required this.text,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final String text;

  @override
  Widget build(BuildContext context) {
    final String textoNormalizado = text.toLowerCase();
    final bool pausando = textoNormalizado.contains('pausar');
    final bool retomando = textoNormalizado.contains('retomar');

    final Color corBotao = pausando
        ? CoresApp.serieExecucao
        : retomando
        ? CoresApp.serieDescanso
        : CoresApp.treinos;

    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: Container(
          height: _alturaBotaoSerie,
          padding: const EdgeInsets.symmetric(
            horizontal: EspacamentoApp.regular,
          ),
          decoration: BoxDecoration(
            color: corBotao.withValues(alpha: 0.16),
            border: Border.all(color: corBotao.withValues(alpha: 0.55)),
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          ),
          child: Center(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                color: corBotao,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdicionarSerieButton extends StatelessWidget {
  const _AdicionarSerieButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: CoresApp.fundo.withValues(alpha: 0.28),
          border: Border.all(color: CoresApp.borda),
          borderRadius: const BorderRadius.all(Radius.circular(999)),
        ),
        child: const Center(
          child: Text(
            '+  ADICIONAR SÉRIE',
            style: TextStyle(
              color: CoresApp.textoSuave,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _AcoesExecucao extends StatelessWidget {
  const _AcoesExecucao({
    required this.iconeAvancar,
    required this.onAvancar,
    required this.textoAvancar,
    this.onClose,
  });

  final IconData iconeAvancar;
  final VoidCallback onAvancar;
  final VoidCallback? onClose;
  final String textoAvancar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        EspacamentoApp.pequeno,
        EspacamentoApp.minimo,
        EspacamentoApp.pequeno,
        MediaQuery.paddingOf(context).bottom + EspacamentoApp.gapCompacto,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _BotaoAcaoInferior(
              outlined: true,
              icon: Icons.arrow_back_rounded,
              label: 'Voltar',
              onTap: onClose,
            ),
          ),
          const SizedBox(width: EspacamentoApp.pequeno),
          Expanded(
            child: _BotaoAcaoInferior(
              outlined: false,
              icon: iconeAvancar,
              label: textoAvancar,
              onTap: onAvancar,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoAcaoInferior extends StatelessWidget {
  const _BotaoAcaoInferior({
    required this.icon,
    required this.label,
    required this.outlined,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool outlined;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: Container(
        height: _alturaBotaoInferior,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : CoresApp.treinos,
          border: Border.all(
            color: outlined ? CoresApp.textoPrincipal : CoresApp.treinos,
            width: 1.2,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(999)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              color: outlined ? CoresApp.textoPrincipal : Colors.black,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: outlined ? CoresApp.textoPrincipal : Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SerieCard extends StatelessWidget {
  const _SerieCard({
    required this.bloqueado,
    required this.concluida,
    required this.descanso,
    required this.draft,
    required this.emExecucao,
    required this.numero,
    required this.onPesoChanged,
    required this.onRepsChanged,
    required this.onTap,
    this.segundosRestantes,
  });

  final bool bloqueado;
  final bool concluida;
  final bool descanso;
  final SerieDraftWork draft;
  final bool emExecucao;
  final int numero;
  final ValueChanged<String> onPesoChanged;
  final ValueChanged<String> onRepsChanged;
  final VoidCallback onTap;
  final int? segundosRestantes;

  @override
  Widget build(BuildContext context) {
    final bool ativa = emExecucao || descanso;
    final Color corEstado = descanso
        ? _corDescansoSerie
        : emExecucao
        ? _corExecucaoSerie
        : concluida
        ? _corDescansoSerie
        : CoresApp.borda;

    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: descanso
            ? _corDescansoSerie.withValues(alpha: 0.12)
            : emExecucao
            ? _corExecucaoSerie.withValues(alpha: 0.12)
            : CoresApp.fundo.withValues(alpha: 0.36),
        border: Border.all(
          color: corEstado.withValues(alpha: ativa || concluida ? 0.95 : 1),
          width: ativa ? 1.4 : 1,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 66,
            child: ativa
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        descanso ? 'DESCANSO' : 'EXECUÇÃO',
                        style: TextStyle(
                          color: corEstado,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatSeriesCountdown(segundosRestantes ?? 0),
                        style: const TextStyle(
                          color: CoresApp.textoPrincipal,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'SÉRIE $numero',
                        style: const TextStyle(
                          color: CoresApp.textoSuave,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                          height: 1,
                        ),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Série $numero',
                      style: const TextStyle(
                        color: CoresApp.textoPrincipal,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _CampoSerie(
                    enabled: !bloqueado,
                    initialValue: draft.reps,
                    label: 'REPS:',
                    onChanged: onRepsChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CampoSerie(
                    enabled: !bloqueado,
                    initialValue: draft.peso,
                    label: 'PESO:',
                    onChanged: onPesoChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CheckSerieButton(
            bloqueado: bloqueado,
            color: corEstado,
            concluida: concluida,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _CheckSerieButton extends StatelessWidget {
  const _CheckSerieButton({
    required this.bloqueado,
    required this.color,
    required this.concluida,
    required this.onTap,
  });

  final bool bloqueado;
  final Color color;
  final bool concluida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: bloqueado ? null : onTap,
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: concluida ? color.withValues(alpha: 0.20) : Colors.transparent,
          border: Border.all(
            color: concluida ? color : CoresApp.borda,
            width: 1.4,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(999)),
        ),
        child: Icon(
          concluida ? Icons.check_rounded : Icons.circle_outlined,
          color: concluida ? color : CoresApp.textoSuave,
          size: 19,
        ),
      ),
    );
  }
}

class _CampoSerie extends StatelessWidget {
  const _CampoSerie({
    required this.enabled,
    required this.initialValue,
    required this.label,
    required this.onChanged,
  });

  final bool enabled;
  final String initialValue;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextFormField(
        enabled: enabled,
        initialValue: initialValue,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          color: CoresApp.textoPrincipal,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          height: 1.6,
        ),
        decoration: InputDecoration(
          isDense: true,
          prefixText: '$label ',
          prefixStyle: const TextStyle(
            color: CoresApp.textoSuave,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
          filled: true,
          fillColor: CoresApp.fundo.withValues(alpha: 0.45),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(
              Radius.circular(RaiosApp.total),
            ),
            borderSide: BorderSide(color: CoresApp.borda),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(
              Radius.circular(RaiosApp.total),
            ),
            borderSide: BorderSide(
              color: CoresApp.borda.withValues(alpha: 0.70),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(
              Radius.circular(RaiosApp.total),
            ),
            borderSide: BorderSide(
              color: CoresApp.treinos.withValues(alpha: 0.75),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),
        ),
      ),
    );
  }
}

class _ModalSeriesPendentes extends StatelessWidget {
  const _ModalSeriesPendentes({
    required this.onAvancar,
    required this.onVoltar,
  });

  final VoidCallback onAvancar;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(EspacamentoApp.medio),
          padding: const EdgeInsets.all(EspacamentoApp.grande),
          decoration: BoxDecoration(
            color: CoresApp.superficie,
            border: Border.all(color: CoresApp.treinos.withValues(alpha: 0.4)),
            borderRadius: const BorderRadius.all(Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _Eyebrow('Séries pendentes'),
              const SizedBox(height: EspacamentoApp.medio),
              const Text(
                'Avançar sem marcar tudo?',
                style: TextStyle(
                  color: CoresApp.textoPrincipal,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: EspacamentoApp.medio),
              const Text(
                'Nem todas as séries deste exercício foram marcadas como feitas. Você pode voltar e concluir as séries ou avançar mesmo assim.',
                style: TextStyle(
                  color: CoresApp.textoSecundario,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: EspacamentoApp.grande),
              FilledButton(
                onPressed: onAvancar,
                child: const Text('Avançar mesmo assim'),
              ),
              const SizedBox(height: _gapWork),
              OutlinedButton(
                onPressed: onVoltar,
                child: const Text('Voltar para marcar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalMidiaExercicio extends StatefulWidget {
  const _ModalMidiaExercicio({required this.exercicio, required this.onClose});

  final ExercicioWork exercicio;
  final VoidCallback onClose;

  @override
  State<_ModalMidiaExercicio> createState() => _ModalMidiaExercicioState();
}

class _ModalMidiaExercicioState extends State<_ModalMidiaExercicio> {
  WebViewController? _webController;

  @override
  void initState() {
    super.initState();
    final String? embedUrl = _resolverEmbedUrl(widget.exercicio);

    if (embedUrl != null) {
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(CoresApp.fundo)
        ..loadRequest(
          Uri.parse(embedUrl),
          headers: const <String, String>{'Referer': _youtubeReferer},
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.exercicio.mediaImageUrl ?? '';

    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: SafeArea(
        child: Center(
          child: Container(
            width: double.infinity,
            height: MediaQuery.sizeOf(context).height * 0.9,
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CoresApp.superficie,
              border: Border.all(
                color: CoresApp.treinos.withValues(alpha: 0.42),
              ),
              borderRadius: const BorderRadius.all(Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.exercicio.name,
                        style: const TextStyle(
                          color: CoresApp.textoPrincipal,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded),
                      color: CoresApp.textoSecundario,
                    ),
                  ],
                ),
                const SizedBox(height: _gapWork),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    child: _webController != null
                        ? WebViewWidget(controller: _webController!)
                        : imageUrl.isEmpty
                        ? const ColoredBox(
                            color: CoresApp.fundo,
                            child: Center(
                              child: Text(
                                'Mídia indisponível.',
                                style: TextStyle(
                                  color: CoresApp.textoSecundario,
                                ),
                              ),
                            ),
                          )
                        : Image.network(imageUrl, fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        color: CoresApp.superficieElevada.withValues(alpha: 0.55),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(RaiosApp.pequeno)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CoresApp.textoSuave,
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
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

bool _temMidia(ExercicioWork exercicio) {
  return (exercicio.mediaImageUrl ?? '').isNotEmpty ||
      (exercicio.mediaVideoUrl ?? '').isNotEmpty ||
      (exercicio.mediaYoutubeUrl ?? '').isNotEmpty ||
      (exercicio.mediaYoutubeVideoId ?? '').isNotEmpty;
}

String? _resolverEmbedUrl(ExercicioWork exercicio) {
  if ((exercicio.mediaYoutubeVideoId ?? '').isNotEmpty) {
    final String videoId = exercicio.mediaYoutubeVideoId!;
    return _montarYoutubeEmbedUrl(videoId);
  }

  final String youtubeUrl = exercicio.mediaYoutubeUrl ?? '';
  final RegExpMatch? match = RegExp(
    r'(?:youtu\.be/|v=|embed/)([A-Za-z0-9_-]{8,})',
  ).firstMatch(youtubeUrl);

  if (match != null) {
    final String videoId = match.group(1) ?? '';
    return 'https://www.youtube.com/embed/$videoId?autoplay=1&mute=1&loop=1&playlist=$videoId&playsinline=1';
  }

  final String videoUrl = exercicio.mediaVideoUrl ?? '';

  if (videoUrl.isNotEmpty) {
    final String safeVideoUrl = const HtmlEscape().convert(videoUrl);

    return Uri.dataFromString(
      '<html><body style="margin:0;background:#000;display:flex;align-items:center;justify-content:center"><video src="$safeVideoUrl" controls autoplay loop muted playsinline style="width:100%;height:100%;object-fit:contain"></video></body></html>',
      mimeType: 'text/html',
    ).toString();
  }

  return null;
}

String? _resolverThumbnailUrl(ExercicioWork exercicio) {
  final String imageUrl = exercicio.mediaImageUrl ?? '';

  if (imageUrl.isNotEmpty) {
    return imageUrl;
  }

  final String videoId = (exercicio.mediaYoutubeVideoId ?? '').isNotEmpty
      ? exercicio.mediaYoutubeVideoId!
      : _extrairYoutubeVideoId(exercicio.mediaYoutubeUrl ?? '') ?? '';

  if (videoId.isEmpty) {
    return null;
  }

  return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
}

String? _extrairYoutubeVideoId(String youtubeUrl) {
  final RegExpMatch? match = RegExp(
    r'(?:youtu\.be/|v=|embed/)([A-Za-z0-9_-]{8,})',
  ).firstMatch(youtubeUrl);

  return match?.group(1);
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

String _formatSeriesCountdown(int seconds) {
  final int safeSeconds = seconds < 0 ? 0 : seconds;
  final int minutes = safeSeconds ~/ 60;
  final int remainingSeconds = safeSeconds % 60;

  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

String _montarYoutubeEmbedUrl(String videoId) {
  return Uri.https('www.youtube.com', '/embed/$videoId', <String, String>{
    'autoplay': '1',
    'mute': '0',
    'loop': '1',
    'playlist': videoId,
    'playsinline': '1',
    'enablejsapi': '1',
    'origin': _youtubeOrigin,
  }).toString();
}
