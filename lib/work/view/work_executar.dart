import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import '../../nucleo/tema/raios_app.dart';
import '../controller/work_controller.dart';
import '../models/work_modelos.dart';

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
            color: CoresApp.superficie,
            border: Border.all(color: CoresApp.borda),
          ),
          child: Column(
            children: <Widget>[
              _HeroExecucao(exercicio: exercicio, workout: workout),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _ProgressoTreino(controlador: controlador),
                      const SizedBox(height: EspacamentoApp.pequeno),
                      Flexible(
                        flex: 5,
                        child: _CardExercicio(
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
                      ),
                      const SizedBox(height: EspacamentoApp.pequeno),
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

class _HeroExecucao extends StatelessWidget {
  const _HeroExecucao({required this.exercicio, required this.workout});

  final ExercicioWork exercicio;
  final FichaWork workout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        border: const Border(bottom: BorderSide(color: CoresApp.borda)),
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
          const SizedBox(height: 6),
          Text(
            exercicio.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Ficha ${workout.key} - ${workout.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CoresApp.textoSecundario,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _formatStopwatch(controlador.totalElapsedSeconds),
                style: const TextStyle(
                  color: CoresApp.textoPrincipal,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Status: ${controlador.statusFase}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CoresApp.textoSecundario,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${controlador.kcalEstimadas.round()} kcal',
                style: const TextStyle(
                  color: Color(0xFF86EFAC),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Exercícios ${controlador.exerciciosContabilizados}/${controlador.totalExercicios}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CoresApp.textoSuave,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(RaiosApp.total),
                  ),
                  child: LinearProgressIndicator(
                    value: controlador.progressoExercicios.clamp(0, 1),
                    minHeight: 5,
                    color: Color.lerp(CoresApp.treinos, Colors.white, 0.18),
                    backgroundColor: CoresApp.superficieElevada,
                  ),
                ),
              ),
            ],
          ),
          if (controlador.faseComContagemRegressiva) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Tempo restante: ${_formatStopwatch(controlador.segundosRestantesFase)}',
              style: const TextStyle(
                color: CoresApp.treinos,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(RaiosApp.total),
            ),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 7,
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
    return _Painel(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _Eyebrow('Exercício ${indice + 1}/$total')),
                if (onAbrirMidia != null)
                  SizedBox.square(
                    dimension: 34,
                    child: IconButton.filledTonal(
                      padding: EdgeInsets.zero,
                      onPressed: onAbrirMidia,
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      color: CoresApp.treinos,
                    ),
                  ),
              ],
            ),
            if (onAbrirMidia != null) ...<Widget>[
              const SizedBox(height: EspacamentoApp.pequeno),
              _PreviewMidiaExercicio(
                exercicio: exercicio,
                onTap: onAbrirMidia!,
              ),
            ],
            const SizedBox(height: EspacamentoApp.pequeno),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Metrica(label: 'Séries', value: '$seriesTotal'),
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
              const SizedBox(height: EspacamentoApp.pequeno),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: CoresApp.superficieElevada.withValues(alpha: 0.42),
                  border: Border.all(color: CoresApp.borda),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                ),
                child: Text(
                  exercicio.observation,
                  style: const TextStyle(
                    color: CoresApp.textoSecundario,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.28,
                  ),
                ),
              ),
            ],
          ],
        ),
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
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: AspectRatio(
          aspectRatio: 16 / 7,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (thumbnail != null)
                Image.network(thumbnail, fit: BoxFit.cover)
              else
                const ColoredBox(color: CoresApp.fundo),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.58),
                    ],
                  ),
                ),
              ),
              Center(
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.black.withValues(alpha: 0.55),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: CoresApp.textoPrincipal,
                    size: 32,
                  ),
                ),
              ),
              const Positioned(
                left: 10,
                bottom: 8,
                child: Text(
                  'Visualizar exercício',
                  style: TextStyle(
                    color: CoresApp.textoPrincipal,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
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
            const Expanded(child: _Eyebrow('Séries')),
            TextButton.icon(
              onPressed: controlador.edicaoSeriesBloqueada
                  ? null
                  : () => controlador.adicionarSerie(exercicio),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: controlador.serieEmAndamento
              ? null
              : controlador.iniciarSerieAtual,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(controlador.textoBotaoSerie),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.separated(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: total,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 6),
            itemBuilder: (BuildContext context, int index) {
              final int numero = index + 1;
              final SerieDraftWork draft = controlador.draftSerie(
                exercicio.id,
                numero,
              );

              return _SerieCard(
                bloqueado: controlador.edicaoSeriesBloqueada,
                concluida: controlador.serieConcluida(exercicio.id, numero),
                descanso: controlador.serieAtualEmDescanso(
                  exercicio.id,
                  numero,
                ),
                draft: draft,
                emExecucao: controlador.serieAtualEmExecucao(
                  exercicio.id,
                  numero,
                ),
                numero: numero,
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
      ],
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
        8,
        4,
        8,
        MediaQuery.paddingOf(context).bottom + 8,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Voltar'),
            ),
          ),
          const SizedBox(width: EspacamentoApp.pequeno),
          Expanded(
            child: FilledButton.icon(
              onPressed: onAvancar,
              icon: Icon(iconeAvancar),
              label: Text(textoAvancar),
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final bool ativa = emExecucao || descanso;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ativa
            ? CoresApp.treinos.withValues(alpha: 0.18)
            : concluida
            ? CoresApp.treinos.withValues(alpha: 0.13)
            : CoresApp.fundo.withValues(alpha: 0.35),
        border: Border.all(
          color: ativa
              ? Colors.white.withValues(alpha: 0.55)
              : concluida
              ? CoresApp.treinos.withValues(alpha: 0.72)
              : CoresApp.borda,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  ativa
                      ? emExecucao
                            ? 'Série $numero em execução'
                            : 'Série $numero em descanso'
                      : 'Série $numero',
                  style: const TextStyle(
                    color: CoresApp.textoPrincipal,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: bloqueado ? null : onTap,
                icon: Icon(
                  concluida ? Icons.check_rounded : Icons.circle_outlined,
                ),
                color: concluida ? CoresApp.treinos : CoresApp.textoSuave,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: _CampoSerie(
                  enabled: !bloqueado,
                  initialValue: draft.reps,
                  label: 'Reps feitas',
                  onChanged: onRepsChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CampoSerie(
                  enabled: !bloqueado,
                  initialValue: draft.peso,
                  label: 'Peso kg',
                  onChanged: onPesoChanged,
                ),
              ),
            ],
          ),
        ],
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
    return TextFormField(
      enabled: enabled,
      initialValue: initialValue,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: const TextStyle(
        color: CoresApp.textoPrincipal,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: const TextStyle(
          color: CoresApp.textoSuave,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: CoresApp.superficieElevada.withValues(alpha: 0.42),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                const SizedBox(height: EspacamentoApp.pequeno),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CoresApp.textoSuave,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 13,
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
      padding: const EdgeInsets.all(10),
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
    return 'https://www.youtube.com/embed/$videoId?autoplay=1&mute=1&loop=1&playlist=$videoId&playsinline=1';
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
