import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import '../../nucleo/tema/raios_app.dart';
import '../controller/work_controller.dart';
import '../models/work_modelos.dart';

class WorkExecutar extends StatefulWidget {
  const WorkExecutar({super.key, required this.controlador, this.onClose});

  final ControladorWorkNativo controlador;
  final VoidCallback? onClose;

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CoresApp.superficie,
              border: Border.all(color: CoresApp.borda),
              borderRadius: const BorderRadius.all(Radius.circular(30)),
            ),
            child: Column(
              children: <Widget>[
                _HeroExecucao(workout: workout),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(EspacamentoApp.grande),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _ProgressoTreino(controlador: controlador),
                        const SizedBox(height: EspacamentoApp.medio),
                        _CardExercicio(
                          exercicio: exercicio,
                          indice: controlador.indiceExercicioAtual,
                          total: workout.exercises.length,
                          onAbrirMidia: _temMidia(exercicio)
                              ? () => setState(() => _midiaAberta = exercicio)
                              : null,
                        ),
                        const SizedBox(height: EspacamentoApp.medio),
                        _SeriesList(
                          controlador: controlador,
                          exercicio: exercicio,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Voltar'),
                        ),
                      ),
                      const SizedBox(width: EspacamentoApp.pequeno),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: controlador.faseComContagemRegressiva
                              ? controlador.pularDescanso
                              : () => _avancar(forcar: false),
                          icon: Icon(
                            controlador.faseComContagemRegressiva
                                ? Icons.skip_next_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(
                            controlador.faseComContagemRegressiva
                                ? 'Pular descanso'
                                : 'Avançar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

class _HeroExecucao extends StatelessWidget {
  const _HeroExecucao({required this.workout});

  final FichaWork workout;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Eyebrow('Track de treino'),
          const SizedBox(height: EspacamentoApp.medio),
          Text(
            workout.title,
            style: const TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: EspacamentoApp.pequeno),
          Text(
            workout.description.isEmpty
                ? 'Execute as séries e avance para fechar o treino.'
                : workout.description,
            style: const TextStyle(
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

class _ProgressoTreino extends StatelessWidget {
  const _ProgressoTreino({required this.controlador});

  final ControladorWorkNativo controlador;

  @override
  Widget build(BuildContext context) {
    final int total = controlador.totalSeries;
    final int completed = controlador.completedSeries;
    final double progress = total == 0 ? 0 : completed / total;

    return _Painel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _IconeModulo(icon: Icons.fitness_center_rounded),
              const SizedBox(width: EspacamentoApp.pequeno),
              Expanded(
                child: Text(
                  '$completed/$total séries concluídas',
                  style: const TextStyle(
                    color: CoresApp.textoPrincipal,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _formatStopwatch(controlador.totalElapsedSeconds),
                style: const TextStyle(
                  color: CoresApp.textoPrincipal,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: EspacamentoApp.pequeno),
          Text(
            'Status: ${controlador.statusFase}',
            style: const TextStyle(
              color: CoresApp.textoSecundario,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (controlador.faseComContagemRegressiva) ...<Widget>[
            const SizedBox(height: EspacamentoApp.pequeno),
            Text(
              'Tempo restante: ${_formatStopwatch(controlador.segundosRestantesFase)}',
              style: const TextStyle(
                color: CoresApp.treinos,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const SizedBox(height: EspacamentoApp.medio),
          ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(RaiosApp.total),
            ),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 9,
              color: CoresApp.treinos,
              backgroundColor: CoresApp.superficieElevada,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardExercicio extends StatelessWidget {
  const _CardExercicio({
    required this.exercicio,
    required this.indice,
    required this.total,
    this.onAbrirMidia,
  });

  final ExercicioWork exercicio;
  final int indice;
  final VoidCallback? onAbrirMidia;
  final int total;

  @override
  Widget build(BuildContext context) {
    return _Painel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Eyebrow('Exercício ${indice + 1}/$total'),
                    const SizedBox(height: EspacamentoApp.pequeno),
                    Text(
                      exercicio.name,
                      style: const TextStyle(
                        color: CoresApp.textoPrincipal,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              if (onAbrirMidia != null)
                IconButton.filledTonal(
                  onPressed: onAbrirMidia,
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  color: CoresApp.treinos,
                ),
            ],
          ),
          const SizedBox(height: EspacamentoApp.medio),
          Row(
            children: <Widget>[
              Expanded(
                child: _Metrica(label: 'Séries', value: '${exercicio.sets}'),
              ),
              const SizedBox(width: EspacamentoApp.pequeno),
              Expanded(
                child: _Metrica(label: 'Reps', value: exercicio.reps),
              ),
              const SizedBox(width: EspacamentoApp.pequeno),
              Expanded(
                child: _Metrica(label: 'Carga', value: exercicio.weight),
              ),
            ],
          ),
          if (exercicio.observation.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: EspacamentoApp.medio),
            Text(
              exercicio.observation,
              style: const TextStyle(
                color: CoresApp.textoSecundario,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _Eyebrow('Séries'),
        const SizedBox(height: EspacamentoApp.pequeno),
        for (int index = 0; index < exercicio.sets; index++) ...<Widget>[
          _SerieCard(
            concluida: controlador.serieConcluida(exercicio.id, index + 1),
            numero: index + 1,
            onTap: () {
              controlador.alternarSerie(exercicio.id, index + 1);
            },
          ),
          const SizedBox(height: EspacamentoApp.pequeno),
        ],
      ],
    );
  }
}

class _SerieCard extends StatelessWidget {
  const _SerieCard({
    required this.concluida,
    required this.numero,
    required this.onTap,
  });

  final bool concluida;
  final int numero;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(EspacamentoApp.medio),
        decoration: BoxDecoration(
          color: concluida
              ? CoresApp.treinos.withValues(alpha: 0.13)
              : CoresApp.fundo.withValues(alpha: 0.35),
          border: Border.all(
            color: concluida
                ? CoresApp.treinos.withValues(alpha: 0.72)
                : CoresApp.borda,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(18)),
        ),
        child: Row(
          children: <Widget>[
            Text(
              'Série $numero',
              style: const TextStyle(
                color: CoresApp.textoPrincipal,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            CircleAvatar(
              radius: 17,
              backgroundColor: concluida
                  ? CoresApp.treinos
                  : CoresApp.superficieElevada,
              child: Icon(
                Icons.check_rounded,
                color: concluida ? CoresApp.fundo : CoresApp.textoSuave,
                size: 20,
              ),
            ),
          ],
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
              const SizedBox(height: EspacamentoApp.pequeno),
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
        ..loadRequest(Uri.parse(embedUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.exercicio.mediaImageUrl ?? '';

    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(EspacamentoApp.medio),
          padding: const EdgeInsets.all(EspacamentoApp.medio),
          decoration: BoxDecoration(
            color: CoresApp.superficie,
            border: Border.all(color: CoresApp.treinos.withValues(alpha: 0.42)),
            borderRadius: const BorderRadius.all(Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: EspacamentoApp.pequeno),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: _webController != null
                      ? WebViewWidget(controller: _webController!)
                      : imageUrl.isEmpty
                      ? const ColoredBox(
                          color: CoresApp.fundo,
                          child: Center(
                            child: Text(
                              'Mídia indisponível.',
                              style: TextStyle(color: CoresApp.textoSecundario),
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
      padding: const EdgeInsets.all(EspacamentoApp.pequeno),
      decoration: BoxDecoration(
        color: CoresApp.superficieElevada.withValues(alpha: 0.55),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: CoresApp.textoSuave,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 14,
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

bool _temMidia(ExercicioWork exercicio) {
  return (exercicio.mediaImageUrl ?? '').isNotEmpty ||
      (exercicio.mediaVideoUrl ?? '').isNotEmpty ||
      (exercicio.mediaYoutubeUrl ?? '').isNotEmpty ||
      (exercicio.mediaYoutubeVideoId ?? '').isNotEmpty;
}

String? _resolverEmbedUrl(ExercicioWork exercicio) {
  if ((exercicio.mediaYoutubeVideoId ?? '').isNotEmpty) {
    return 'https://www.youtube.com/embed/${exercicio.mediaYoutubeVideoId}';
  }

  final String youtubeUrl = exercicio.mediaYoutubeUrl ?? '';
  final RegExpMatch? match = RegExp(
    r'(?:youtu\.be/|v=|embed/)([A-Za-z0-9_-]{8,})',
  ).firstMatch(youtubeUrl);

  if (match != null) {
    return 'https://www.youtube.com/embed/${match.group(1)}';
  }

  final String videoUrl = exercicio.mediaVideoUrl ?? '';

  if (videoUrl.isNotEmpty) {
    final String safeVideoUrl = const HtmlEscape().convert(videoUrl);

    return Uri.dataFromString(
      '<html><body style="margin:0;background:#000;display:flex;align-items:center;justify-content:center"><video src="$safeVideoUrl" controls autoplay playsinline style="width:100%;height:100%;object-fit:contain"></video></body></html>',
      mimeType: 'text/html',
    ).toString();
  }

  return null;
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
