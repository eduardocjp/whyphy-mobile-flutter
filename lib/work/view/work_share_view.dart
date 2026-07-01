import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../funcionalidades/work/servicos/servico_compartilhamento_work.dart';
import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import '../../nucleo/tema/raios_app.dart';
import '../models/work_modelos.dart';

class WorkShareView extends StatefulWidget {
  const WorkShareView({
    super.key,
    required this.cardioSeconds,
    required this.completedAt,
    required this.completedSeries,
    required this.exerciseSeconds,
    required this.kcalBurned,
    required this.totalSeries,
    required this.workout,
    this.onClose,
    this.onCompartilharInterno,
    this.servicoCompartilhamento = const ServicoCompartilhamentoWork(),
  });

  final int cardioSeconds;
  final DateTime completedAt;
  final int completedSeries;
  final int exerciseSeconds;
  final double kcalBurned;
  final VoidCallback? onClose;
  final VoidCallback? onCompartilharInterno;
  final ServicoCompartilhamentoWork servicoCompartilhamento;
  final int totalSeries;
  final FichaWork workout;

  @override
  State<WorkShareView> createState() => _WorkShareViewState();
}

class _WorkShareViewState extends State<WorkShareView> {
  final GlobalKey _previewKey = GlobalKey();
  bool _processando = false;
  String _tipo = 'simples';
  String? _mensagem;

  int get _durationSeconds {
    return widget.exerciseSeconds + widget.cardioSeconds;
  }

  String get _titulo {
    return _tipo == 'detalhado'
        ? 'Compartilhar treino detalhado'
        : 'Compartilhar treino simples';
  }

  String get _textoCompartilhamento {
    return [
      'Treino concluído no WhyPhy',
      'Ficha ${widget.workout.key}: ${widget.workout.title}',
      'Tempo total: ${_formatStopwatch(_durationSeconds)}',
      'Exercícios: ${_formatStopwatch(widget.exerciseSeconds)}',
      if (widget.cardioSeconds > 0)
        'Cardio: ${_formatStopwatch(widget.cardioSeconds)}',
      'Séries: ${widget.completedSeries}/${widget.totalSeries}',
      'Calorias estimadas: ${widget.kcalBurned.round()} kcal',
      'Profissional: ${widget.workout.professionalName}',
    ].join('\n');
  }

  Future<void> _executar(Future<bool> Function() acao) async {
    if (_processando) {
      return;
    }

    setState(() {
      _processando = true;
      _mensagem = null;
    });

    final bool abriu = await acao();

    if (!mounted) {
      return;
    }

    setState(() {
      _processando = false;
      _mensagem = abriu
          ? 'Ação aberta no dispositivo.'
          : 'Não foi possível abrir a ação nativa.';
    });
  }

  Future<bool> _compartilharImagemPreview() async {
    final RenderObject? renderObject = _previewKey.currentContext
        ?.findRenderObject();

    if (renderObject is! RenderRepaintBoundary) {
      return false;
    }

    final ui.Image image = await renderObject.toImage(pixelRatio: 3);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      return false;
    }

    return widget.servicoCompartilhamento.compartilharImagem(
      bytesPng: byteData.buffer.asUint8List(),
      texto: _textoCompartilhamento,
      tipo: _tipo,
      titulo: _titulo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              margin: const EdgeInsets.all(EspacamentoApp.medio),
              padding: const EdgeInsets.all(EspacamentoApp.grande),
              decoration: BoxDecoration(
                color: CoresApp.superficie,
                border: Border.all(
                  color: CoresApp.treinos.withValues(alpha: 0.42),
                ),
                borderRadius: const BorderRadius.all(
                  Radius.circular(RaiosApp.grande),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: CoresApp.treinos.withValues(alpha: 0.18),
                    blurRadius: 42,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _Eyebrow('Compartilhar'),
                              SizedBox(height: EspacamentoApp.pequeno),
                              Text(
                                'Resumo do treino',
                                style: TextStyle(
                                  color: CoresApp.textoPrincipal,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close_rounded),
                          color: CoresApp.textoSecundario,
                        ),
                      ],
                    ),
                    const SizedBox(height: EspacamentoApp.grande),
                    _TipoCompartilhamento(
                      tipo: _tipo,
                      onChanged: (String value) =>
                          setState(() => _tipo = value),
                    ),
                    const SizedBox(height: EspacamentoApp.medio),
                    RepaintBoundary(
                      key: _previewKey,
                      child: _SharePreview(
                        cardioSeconds: widget.cardioSeconds,
                        completedSeries: widget.completedSeries,
                        durationSeconds: _durationSeconds,
                        kcalBurned: widget.kcalBurned,
                        totalSeries: widget.totalSeries,
                        workout: widget.workout,
                      ),
                    ),
                    if (_mensagem != null) ...<Widget>[
                      const SizedBox(height: EspacamentoApp.medio),
                      Text(
                        _mensagem!,
                        style: const TextStyle(
                          color: CoresApp.textoSecundario,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: EspacamentoApp.grande),
                    _AcaoShare(
                      icon: Icons.camera_alt_outlined,
                      label: _tipo == 'detalhado'
                          ? 'Compartilhar imagem detalhada'
                          : 'Compartilhar imagem simples',
                      onTap: _processando
                          ? null
                          : () => _executar(_compartilharImagemPreview),
                    ),
                    const SizedBox(height: EspacamentoApp.pequeno),
                    _AcaoShare(
                      icon: Icons.image_outlined,
                      label: _tipo == 'detalhado'
                          ? 'Selecionar mídia detalhada'
                          : 'Selecionar mídia simples',
                      onTap: _processando
                          ? null
                          : () => _executar(
                              () => widget.servicoCompartilhamento.abrirGaleria(
                                texto: _textoCompartilhamento,
                                tipo: _tipo,
                                titulo: _titulo,
                              ),
                            ),
                    ),
                    const SizedBox(height: EspacamentoApp.pequeno),
                    FilledButton.icon(
                      onPressed: _processando
                          ? null
                          : () => _executar(
                              () => widget.servicoCompartilhamento
                                  .compartilharTexto(
                                    texto: _textoCompartilhamento,
                                    tipo: _tipo,
                                    titulo: _titulo,
                                  ),
                            ),
                      icon: Icon(
                        _processando
                            ? Icons.hourglass_top_rounded
                            : Icons.ios_share_rounded,
                      ),
                      label: Text(
                        _processando ? 'Preparando' : 'Share Android',
                      ),
                    ),
                    const SizedBox(height: EspacamentoApp.pequeno),
                    OutlinedButton.icon(
                      onPressed: widget.onCompartilharInterno,
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Compartilhar no chat'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TipoCompartilhamento extends StatelessWidget {
  const _TipoCompartilhamento({required this.onChanged, required this.tipo});

  final ValueChanged<String> onChanged;
  final String tipo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _TipoBotao(
            ativo: tipo == 'simples',
            label: 'Simples',
            onTap: () => onChanged('simples'),
          ),
        ),
        const SizedBox(width: EspacamentoApp.pequeno),
        Expanded(
          child: _TipoBotao(
            ativo: tipo == 'detalhado',
            label: 'Detalhado',
            onTap: () => onChanged('detalhado'),
          ),
        ),
      ],
    );
  }
}

class _TipoBotao extends StatelessWidget {
  const _TipoBotao({
    required this.ativo,
    required this.label,
    required this.onTap,
  });

  final bool ativo;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: ativo
            ? CoresApp.treinos.withValues(alpha: 0.14)
            : Colors.transparent,
        side: BorderSide(
          color: ativo
              ? CoresApp.treinos.withValues(alpha: 0.75)
              : CoresApp.borda,
        ),
      ),
      child: Text(label),
    );
  }
}

class _AcaoShare extends StatelessWidget {
  const _AcaoShare({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _SharePreview extends StatelessWidget {
  const _SharePreview({
    required this.cardioSeconds,
    required this.completedSeries,
    required this.durationSeconds,
    required this.kcalBurned,
    required this.totalSeries,
    required this.workout,
  });

  final int cardioSeconds;
  final int completedSeries;
  final int durationSeconds;
  final double kcalBurned;
  final int totalSeries;
  final FichaWork workout;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CoresApp.fundo,
          border: Border.all(color: CoresApp.borda),
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.15,
            colors: <Color>[
              CoresApp.treinos.withValues(alpha: 0.22),
              CoresApp.superficie,
              CoresApp.fundo,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(EspacamentoApp.grande),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text.rich(
                TextSpan(
                  text: 'WHY',
                  children: <InlineSpan>[
                    TextSpan(
                      text: 'PHY',
                      style: TextStyle(color: CoresApp.treinos),
                    ),
                  ],
                ),
                style: TextStyle(
                  color: CoresApp.textoPrincipal,
                  fontSize: 24,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                _formatStopwatch(durationSeconds),
                style: const TextStyle(
                  color: CoresApp.textoPrincipal,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                ),
              ),
              const SizedBox(height: EspacamentoApp.pequeno),
              Text(
                '${kcalBurned.round()} kcal',
                style: const TextStyle(
                  color: Color(0xFF86EFAC),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: EspacamentoApp.medio),
              Text(
                'Ficha ${workout.key} • ${workout.title}',
                style: const TextStyle(
                  color: CoresApp.textoPrincipal,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: EspacamentoApp.pequeno),
              Text(
                '$completedSeries/$totalSeries séries • cardio ${_formatStopwatch(cardioSeconds)}',
                style: const TextStyle(
                  color: CoresApp.textoSecundario,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: EspacamentoApp.pequeno),
              Text(
                workout.professionalName,
                style: const TextStyle(
                  color: CoresApp.textoSuave,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
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
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 5,
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
