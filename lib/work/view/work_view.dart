import 'package:flutter/material.dart';

import '../../funcionalidades/work/servicos/servico_execucao_work.dart';
import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import '../controller/work_controller.dart';
import '../models/work_modelos.dart';
import 'work_cardio.dart';
import 'work_executar.dart';
import 'work_selecionar_exercicio.dart';
import 'work_share_view.dart';

class WorkView extends StatefulWidget {
  const WorkView({
    super.key,
    required this.servicoExecucaoWork,
    this.onAbrirRotaWeb,
    this.onClose,
    this.onResultadoWeb,
    this.snapshotInicial,
  });

  final void Function(String routePath)? onAbrirRotaWeb;
  final VoidCallback? onClose;
  final void Function(ResultadoEventoWork resultado)? onResultadoWeb;
  final ServicoExecucaoWork servicoExecucaoWork;
  final SnapshotSessaoWork? snapshotInicial;

  @override
  State<WorkView> createState() => _WorkViewState();
}

class _WorkViewState extends State<WorkView> {
  late final ControladorWorkNativo _controlador;
  bool _shareAberto = false;

  @override
  void initState() {
    super.initState();
    _controlador = ControladorWorkNativo(
      onResultadoWeb: widget.onResultadoWeb,
      servicoExecucaoWork: widget.servicoExecucaoWork,
    );
    _controlador.inicializar(widget.snapshotInicial);
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CoresApp.fundo,
      child: AnimatedBuilder(
        animation: _controlador,
        builder: (BuildContext context, _) {
          final bool etapaExecucao =
              _controlador.etapa == EtapaWorkNativo.exercicio;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              SafeArea(
                child: Column(
                  children: <Widget>[
                    if (!etapaExecucao) _WorkHeader(onClose: widget.onClose),
                    Expanded(child: _buildConteudo()),
                  ],
                ),
              ),
              if (_shareAberto && _controlador.workout != null)
                WorkShareView(
                  cardioSeconds: _controlador.cardioElapsedSeconds,
                  completedAt: DateTime.now(),
                  completedSeries: _controlador.completedSeries,
                  exerciseSeconds: _controlador.exerciseElapsedSeconds,
                  kcalBurned: _controlador.kcalEstimadas,
                  onClose: () => setState(() => _shareAberto = false),
                  onCompartilharInterno: _abrirFeedback,
                  totalSeries: _controlador.totalSeries,
                  workout: _controlador.workout!,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConteudo() {
    return switch (_controlador.etapa) {
      EtapaWorkNativo.carregando => const _WorkLoading(),
      EtapaWorkNativo.erro => _WorkErro(
        mensagem: _controlador.erro ?? 'Não foi possível abrir o Work nativo.',
        onClose: widget.onClose,
      ),
      EtapaWorkNativo.historico => WorkHistoricoView(
        controlador: _controlador,
        onSelecionar: _controlador.abrirSelecao,
      ),
      EtapaWorkNativo.selecao => WorkSelecionarExercicio(
        controlador: _controlador,
        onVoltar: _controlador.voltarParaHistorico,
      ),
      EtapaWorkNativo.cardio => WorkCardio(
        controlador: _controlador,
        onCompartilhar: () => setState(() => _shareAberto = true),
        onHome: widget.onClose,
      ),
      EtapaWorkNativo.concluido => WorkConclusao(
        controlador: _controlador,
        onAbrirFeedback: _abrirFeedback,
        onCompartilhar: () => setState(() => _shareAberto = true),
        onHome: widget.onClose,
      ),
      EtapaWorkNativo.exercicio => WorkExecutar(
        controlador: _controlador,
        onClose: widget.onClose,
        onHome: _voltarParaHome,
      ),
    };
  }

  void _voltarParaHome() {
    widget.onAbrirRotaWeb?.call('/users/home');
    widget.onClose?.call();
  }

  void _abrirFeedback() {
    final String professionalId = _controlador.workout?.professionalId ?? '';
    final Uri route = Uri(
      path: '/users/feedback',
      queryParameters: <String, String>{
        'returnTo': 'home',
        if (professionalId.trim().isNotEmpty)
          'recipientId': professionalId.trim(),
      },
    );

    widget.onAbrirRotaWeb?.call(route.toString());
    setState(() => _shareAberto = false);
    widget.onClose?.call();
  }
}

class _WorkHeader extends StatelessWidget {
  const _WorkHeader({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      decoration: const BoxDecoration(
        color: CoresApp.fundo,
        border: Border(bottom: BorderSide(color: CoresApp.borda)),
      ),
      child: Row(
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
              fontSize: 30,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Voltar'),
          ),
        ],
      ),
    );
  }
}

class _WorkLoading extends StatelessWidget {
  const _WorkLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(EspacamentoApp.grande),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(color: CoresApp.treinos),
            SizedBox(height: EspacamentoApp.medio),
            Text(
              'Carregando Work nativo.',
              style: TextStyle(
                color: CoresApp.textoSecundario,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkErro extends StatelessWidget {
  const _WorkErro({required this.mensagem, this.onClose});

  final String mensagem;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EspacamentoApp.grande),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.warning_amber_rounded,
              color: CoresApp.suporte,
              size: 42,
            ),
            const SizedBox(height: EspacamentoApp.medio),
            Text(
              mensagem,
              style: const TextStyle(
                color: CoresApp.textoSecundario,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: EspacamentoApp.grande),
            FilledButton(onPressed: onClose, child: const Text('Voltar')),
          ],
        ),
      ),
    );
  }
}

class WorkConclusao extends StatelessWidget {
  const WorkConclusao({
    super.key,
    required this.controlador,
    required this.onAbrirFeedback,
    required this.onCompartilhar,
    this.onHome,
  });

  final ControladorWorkNativo controlador;
  final VoidCallback onAbrirFeedback;
  final VoidCallback onCompartilhar;
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    final FichaWork? workout = controlador.workout;

    return Padding(
      padding: const EdgeInsets.all(EspacamentoApp.grande),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CoresApp.superficie,
            border: Border.all(color: CoresApp.treinos.withValues(alpha: 0.42)),
            borderRadius: const BorderRadius.all(Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(EspacamentoApp.grande),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: CoresApp.treinos,
                  child: Icon(
                    Icons.check_rounded,
                    color: CoresApp.fundo,
                    size: 38,
                  ),
                ),
                const SizedBox(height: EspacamentoApp.grande),
                const _Eyebrow('Parabéns', align: TextAlign.center),
                const SizedBox(height: EspacamentoApp.pequeno),
                const Text(
                  'Treino concluído',
                  style: TextStyle(
                    color: CoresApp.textoPrincipal,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: EspacamentoApp.medio),
                Text(
                  workout == null
                      ? 'Execução registrada.'
                      : 'A ficha ${workout.key} foi concluída',
                  style: const TextStyle(
                    color: CoresApp.textoSecundario,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: EspacamentoApp.grande),
                FilledButton(
                  onPressed: onHome,
                  child: const Text('Voltar para home'),
                ),
                const SizedBox(height: EspacamentoApp.pequeno),
                OutlinedButton.icon(
                  onPressed: onCompartilhar,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Compartilhar'),
                ),
                const SizedBox(height: EspacamentoApp.pequeno),
                OutlinedButton.icon(
                  onPressed: onAbrirFeedback,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Feedback ao profissional'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.texto, {this.align = TextAlign.left});

  final TextAlign align;
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
      textAlign: align,
    );
  }
}
