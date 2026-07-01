import 'package:flutter/material.dart';

import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import '../controller/work_controller.dart';
import '../models/work_modelos.dart';

class WorkHistoricoView extends StatelessWidget {
  const WorkHistoricoView({
    super.key,
    required this.controlador,
    this.onVoltar,
  });

  final ControladorWorkNativo controlador;
  final VoidCallback? onVoltar;

  @override
  Widget build(BuildContext context) {
    final BootstrapWorkMobile? bootstrap = controlador.bootstrap;
    final List<FichaWork> fichas = bootstrap?.workouts ?? <FichaWork>[];

    final List<HistoricoExecucaoWork> historico =
        fichas
            .expand((FichaWork ficha) => ficha.recentHistory)
            .toList(growable: false)
          ..sort(
            (HistoricoExecucaoWork a, HistoricoExecucaoWork b) =>
                b.completedAt.compareTo(a.completedAt),
          );

    final FichaWork? fichaAtiva = fichas.isEmpty ? null : fichas.first;

    return _WorkEntradaShell(
      eyebrow: 'Track de treino',
      title: 'Escolha uma ficha do treino',
      subtitle:
          'O Work mostra somente o treino enviado pelo profissional e você escolhe qual ficha vai executar agora.',
      onVoltar: onVoltar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (fichas.isEmpty)
            _VazioCard(
              mensagem:
                  bootstrap?.emptyMessage ??
                  'Não há ficha disponível para execução agora.',
            )
          else
            for (final FichaWork ficha in fichas) ...<Widget>[
              _FichaCard(
                ficha: ficha,
                onTap: () => controlador.selecionarFicha(ficha),
              ),
              const SizedBox(height: EspacamentoApp.medio),
            ],

          if (fichaAtiva != null) ...<Widget>[
            _TreinoAtivoAlunoCard(ficha: fichaAtiva),
            const SizedBox(height: EspacamentoApp.medio),
          ],

          _HistoricoRecenteCard(historico: historico),
        ],
      ),
    );
  }
}

class WorkSelecionarExercicio extends StatelessWidget {
  const WorkSelecionarExercicio({
    super.key,
    required this.controlador,
    required this.onVoltar,
  });

  final ControladorWorkNativo controlador;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final List<FichaWork> fichas =
        controlador.bootstrap?.workouts ?? <FichaWork>[];

    return _WorkEntradaShell(
      eyebrow: 'Seleção',
      title: 'Escolha uma ficha',
      subtitle:
          'Ao selecionar, o app busca o snapshot inicial, inicia o cronômetro nativo e sincroniza com a WebView.',
      onVoltar: onVoltar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final FichaWork ficha in fichas) ...<Widget>[
            _FichaCard(
              ficha: ficha,
              onTap: () => controlador.selecionarFicha(ficha),
            ),
            const SizedBox(height: EspacamentoApp.pequeno),
          ],
          if (fichas.isEmpty)
            const _VazioCard(
              mensagem: 'Não há ficha disponível para execução agora.',
            ),
          /* const SizedBox(height: EspacamentoApp.grande),
          OutlinedButton.icon(
            onPressed: onVoltar,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Voltar ao histórico'),
          ), */
        ],
      ),
    );
  }
}

class _WorkEntradaShell extends StatelessWidget {
  const _WorkEntradaShell({
    required this.child,
    required this.eyebrow,
    required this.subtitle,
    required this.title,
    this.onVoltar,
  });

  final Widget child;
  final String eyebrow;
  final String subtitle;
  final String title;
  final VoidCallback? onVoltar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CoresApp.superficie,
          border: Border.all(color: CoresApp.borda),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: <Widget>[
            _WorkTopBar(onVoltar: onVoltar),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: BoxDecoration(
                border: const Border(bottom: BorderSide(color: CoresApp.borda)),
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.15,
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
                  _Eyebrow(eyebrow),
                  const SizedBox(height: EspacamentoApp.medio),
                  Text(
                    title,
                    style: const TextStyle(
                      color: CoresApp.textoPrincipal,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: EspacamentoApp.pequeno),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: CoresApp.textoSecundario,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkTopBar extends StatelessWidget {
  const _WorkTopBar({required this.onVoltar});

  final VoidCallback? onVoltar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CoresApp.borda)),
      ),
      child: Row(
        children: <Widget>[
          const Expanded(child: _WhyPhyLogoCompacto()),

          if (onVoltar != null) _BotaoVoltarCompacto(onPressed: onVoltar!),
        ],
      ),
    );
  }
}

class _WhyPhyLogoCompacto extends StatelessWidget {
  const _WhyPhyLogoCompacto();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        children: <TextSpan>[
          TextSpan(
            text: 'WHY',
            style: TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: -1.2,
            ),
          ),
          TextSpan(
            text: 'PHY',
            style: TextStyle(
              color: CoresApp.treinos,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: -1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoVoltarCompacto extends StatelessWidget {
  const _BotaoVoltarCompacto({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: Container(
          height: 38,
          padding: const EdgeInsets.only(left: 10, right: 14),
          decoration: BoxDecoration(
            color: CoresApp.fundo.withValues(alpha: 0.45),
            border: Border.all(color: CoresApp.borda),
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.arrow_back_rounded, color: CoresApp.treinos, size: 18),
              SizedBox(width: 6),
              Text(
                'Voltar',
                style: TextStyle(
                  color: CoresApp.textoPrincipal,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FichaCard extends StatelessWidget {
  const _FichaCard({required this.ficha, required this.onTap});

  final FichaWork ficha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final HistoricoExecucaoWork? ultimaExecucao = _ultimaExecucaoDaFicha(ficha);

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: Container(
        padding: const EdgeInsets.all(EspacamentoApp.medio),
        decoration: BoxDecoration(
          color: CoresApp.fundo.withValues(alpha: 0.36),
          border: Border.all(color: CoresApp.borda),
          borderRadius: const BorderRadius.all(Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: const <Widget>[
                Expanded(child: _Eyebrow('Ficha ativa')),
                Icon(
                  Icons.chevron_right_rounded,
                  color: CoresApp.textoSuave,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: EspacamentoApp.pequeno),

            Text(
              ficha.key,
              style: const TextStyle(
                color: CoresApp.treinos,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),

            const SizedBox(height: EspacamentoApp.medio),

            Text(
              'Ficha ${ficha.key}',
              style: const TextStyle(
                color: CoresApp.textoPrincipal,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ficha.title,
              style: const TextStyle(
                color: CoresApp.textoSecundario,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: EspacamentoApp.medio),

            Row(
              children: <Widget>[
                Expanded(
                  child: _MiniMetricaCard(
                    label: 'Séries da ficha',
                    value:
                        '${ultimaExecucao?.completedSets ?? 0}/${ficha.totalPlannedSets}',
                  ),
                ),
                const SizedBox(width: EspacamentoApp.pequeno),
                Expanded(
                  child: _MiniMetricaCard(
                    label: 'Carga recente',
                    value: _formatarCargaRecente(ultimaExecucao),
                  ),
                ),
              ],
            ),

            const SizedBox(height: EspacamentoApp.pequeno),

            _MiniMetricaCard(
              label: 'Última execução',
              value: ultimaExecucao == null
                  ? 'Sem histórico'
                  : _formatarDataCurta(ultimaExecucao.completedAt),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoricoCard extends StatelessWidget {
  const _HistoricoCard({required this.item});

  final HistoricoExecucaoWork item;

  @override
  Widget build(BuildContext context) {
    return _ResumoCard(
      icon: item.cardioDone
          ? Icons.monitor_heart_rounded
          : Icons.fitness_center_rounded,
      title: _formatarDataCurta(item.completedAt),
      subtitle:
          '${item.completedSets}/${item.totalSets} séries • ${item.totalLoadKg.round()} kg movimentados',
    );
  }
}

class _TreinoAtivoAlunoCard extends StatelessWidget {
  const _TreinoAtivoAlunoCard({required this.ficha});

  final FichaWork ficha;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspacamentoApp.medio),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.34),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Eyebrow('Treino ativo do aluno'),
          const SizedBox(height: EspacamentoApp.pequeno),
          Text(
            'Ficha ${ficha.key} com ${ficha.totalPlannedSets} séries planejadas.',
            style: const TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Profissional responsável: ${ficha.professionalName}',
            style: const TextStyle(
              color: CoresApp.textoSecundario,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoricoRecenteCard extends StatelessWidget {
  const _HistoricoRecenteCard({required this.historico});

  final List<HistoricoExecucaoWork> historico;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspacamentoApp.medio),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.34),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: const <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(0x221E73FF),
                child: Icon(
                  Icons.history_rounded,
                  color: CoresApp.treinos,
                  size: 20,
                ),
              ),
              SizedBox(width: EspacamentoApp.medio),
              Expanded(
                child: Text(
                  'Últimas execuções da ficha',
                  style: TextStyle(
                    color: CoresApp.textoPrincipal,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: EspacamentoApp.medio),

          if (historico.isEmpty)
            const _VazioCard(
              mensagem: 'Ainda não há execuções registradas para esta ficha.',
            )
          else
            for (final HistoricoExecucaoWork item in historico.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: EspacamentoApp.pequeno),
                child: _HistoricoLinha(item: item),
              ),
        ],
      ),
    );
  }
}

class _HistoricoLinha extends StatelessWidget {
  const _HistoricoLinha({required this.item});

  final HistoricoExecucaoWork item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspacamentoApp.medio),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.42),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 19,
            backgroundColor: CoresApp.treinos.withValues(alpha: 0.15),
            child: Icon(
              item.cardioDone
                  ? Icons.monitor_heart_rounded
                  : Icons.fitness_center_rounded,
              color: CoresApp.treinos,
              size: 19,
            ),
          ),
          const SizedBox(width: EspacamentoApp.medio),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _formatarDataCurta(item.completedAt),
                  style: const TextStyle(
                    color: CoresApp.textoPrincipal,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.completedSets}/${item.totalSets} séries • ${item.totalLoadKg.round()} kg movimentados',
                  style: const TextStyle(
                    color: CoresApp.textoSecundario,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
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

class _MiniMetricaCard extends StatelessWidget {
  const _MiniMetricaCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: EspacamentoApp.medio,
        vertical: EspacamentoApp.pequeno,
      ),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.38),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: CoresApp.textoSuave,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConclusaoHojeCard extends StatelessWidget {
  const _ConclusaoHojeCard({required this.conclusao});

  final ConclusaoHojeWork conclusao;

  @override
  Widget build(BuildContext context) {
    return _ResumoCard(
      icon: Icons.check_circle_outline_rounded,
      title: 'Treino de hoje concluído',
      subtitle:
          'Ficha ${conclusao.workoutKey} • ${_formatarDataCurta(conclusao.completedAt)}',
    );
  }
}

class _ResumoCard extends StatelessWidget {
  const _ResumoCard({
    required this.icon,
    required this.subtitle,
    required this.title,
  });

  final IconData icon;
  final String subtitle;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspacamentoApp.medio),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.34),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(22)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 21,
            backgroundColor: CoresApp.treinos.withValues(alpha: 0.15),
            child: Icon(icon, color: CoresApp.treinos, size: 22),
          ),
          const SizedBox(width: EspacamentoApp.medio),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: CoresApp.textoPrincipal,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: CoresApp.textoSecundario,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
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

class _VazioCard extends StatelessWidget {
  const _VazioCard({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(EspacamentoApp.grande),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.28),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(22)),
      ),
      child: Text(
        mensagem,
        style: const TextStyle(
          color: CoresApp.textoSecundario,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
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
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
      ),
    );
  }
}

String _formatarDataCurta(String isoString) {
  final DateTime? data = DateTime.tryParse(isoString);

  if (data == null) {
    return 'Data indisponível';
  }

  final DateTime local = data.toLocal();
  final String dia = local.day.toString().padLeft(2, '0');
  final String mes = local.month.toString().padLeft(2, '0');
  final String hora = local.hour.toString().padLeft(2, '0');
  final String minuto = local.minute.toString().padLeft(2, '0');

  return '$dia/$mes às $hora:$minuto';
}

HistoricoExecucaoWork? _ultimaExecucaoDaFicha(FichaWork ficha) {
  if (ficha.recentHistory.isEmpty) {
    return null;
  }

  final List<HistoricoExecucaoWork> historico =
      ficha.recentHistory.toList(growable: false)..sort(
        (HistoricoExecucaoWork a, HistoricoExecucaoWork b) =>
            b.completedAt.compareTo(a.completedAt),
      );

  return historico.first;
}

String _formatarCargaRecente(HistoricoExecucaoWork? historico) {
  if (historico == null || historico.totalLoadKg <= 0) {
    return 'Sem carga';
  }

  return '${historico.totalLoadKg.round()} kg';
}
