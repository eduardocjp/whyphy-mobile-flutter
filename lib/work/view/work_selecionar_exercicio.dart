import 'package:flutter/material.dart';

import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import '../controller/work_controller.dart';
import '../models/work_modelos.dart';

class WorkHistoricoView extends StatelessWidget {
  const WorkHistoricoView({
    super.key,
    required this.controlador,
    required this.onSelecionar,
  });

  final ControladorWorkNativo controlador;
  final VoidCallback onSelecionar;

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

    return _WorkEntradaShell(
      eyebrow: 'Histórico',
      title: 'Seu Work nativo',
      subtitle:
          'Veja o último treino registrado e selecione uma ficha para iniciar a execução nativa.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (bootstrap?.todayCompletion != null)
            _ConclusaoHojeCard(conclusao: bootstrap!.todayCompletion!)
          else
            _ResumoCard(
              icon: Icons.history_rounded,
              title: fichas.isEmpty
                  ? 'Nenhuma ficha disponível'
                  : '${fichas.length} ficha${fichas.length == 1 ? '' : 's'} disponível${fichas.length == 1 ? '' : 'is'}',
              subtitle: fichas.isEmpty
                  ? (bootstrap?.emptyMessage ??
                        'Não há nenhum treino cadastrado para você ainda.')
                  : 'O cronômetro nativo permanece ativo mesmo fora da tela do Work.',
            ),
          const SizedBox(height: EspacamentoApp.medio),
          _ResumoCard(
            icon: Icons.person_outline_rounded,
            title: bootstrap?.profile.userName.isNotEmpty == true
                ? bootstrap!.profile.userName
                : 'Aluno WhyPhy',
            subtitle:
                'Nível: ${bootstrap?.profile.trainingLevel ?? 'Não informado'} • Horário: ${bootstrap?.profile.workoutTime ?? 'Não informado'}',
          ),
          const SizedBox(height: EspacamentoApp.grande),
          const _Eyebrow('Últimas execuções'),
          const SizedBox(height: EspacamentoApp.pequeno),
          if (historico.isEmpty)
            const _VazioCard(
              mensagem: 'As execuções concluídas aparecerão aqui.',
            )
          else
            for (final HistoricoExecucaoWork item in historico.take(
              5,
            )) ...<Widget>[
              _HistoricoCard(item: item),
              const SizedBox(height: EspacamentoApp.pequeno),
            ],
          const SizedBox(height: EspacamentoApp.grande),
          FilledButton.icon(
            onPressed: fichas.isEmpty ? null : onSelecionar,
            icon: const Icon(Icons.list_alt_rounded),
            label: const Text('Selecionar treino'),
          ),
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
          const SizedBox(height: EspacamentoApp.grande),
          OutlinedButton.icon(
            onPressed: onVoltar,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Voltar ao histórico'),
          ),
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
  });

  final Widget child;
  final String eyebrow;
  final String subtitle;
  final String title;

  @override
  Widget build(BuildContext context) {
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(EspacamentoApp.grande),
              decoration: BoxDecoration(
                border: const Border(bottom: BorderSide(color: CoresApp.borda)),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
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
                  _Eyebrow(eyebrow),
                  const SizedBox(height: EspacamentoApp.medio),
                  Text(
                    title,
                    style: const TextStyle(
                      color: CoresApp.textoPrincipal,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: EspacamentoApp.pequeno),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: CoresApp.textoSecundario,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(EspacamentoApp.grande),
                child: child,
              ),
            ),
          ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: Container(
        padding: const EdgeInsets.all(EspacamentoApp.medio),
        decoration: BoxDecoration(
          color: CoresApp.fundo.withValues(alpha: 0.35),
          border: Border.all(color: CoresApp.borda),
          borderRadius: const BorderRadius.all(Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Ficha ${ficha.key}',
                  style: const TextStyle(
                    color: CoresApp.treinos,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: CoresApp.treinos,
                ),
              ],
            ),
            const SizedBox(height: EspacamentoApp.pequeno),
            Text(
              ficha.title,
              style: const TextStyle(
                color: CoresApp.textoPrincipal,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: EspacamentoApp.pequeno),
            Text(
              '${ficha.totalPlannedSets} séries • ${ficha.estimatedMinutes} min • ${ficha.professionalName}',
              style: const TextStyle(
                color: CoresApp.textoSecundario,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (ficha.lastCompletedAt != null) ...<Widget>[
              const SizedBox(height: EspacamentoApp.pequeno),
              Text(
                'Última execução: ${_formatarDataCurta(ficha.lastCompletedAt!)}',
                style: const TextStyle(
                  color: CoresApp.textoSuave,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
