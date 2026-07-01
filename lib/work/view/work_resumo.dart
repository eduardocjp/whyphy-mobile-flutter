import 'package:flutter/material.dart';

import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import '../controller/work_controller.dart';
import '../models/work_modelos.dart';

class WorkResumo extends StatelessWidget {
  const WorkResumo({
    super.key,
    required this.controlador,
    required this.onVoltar,
  });

  final ControladorWorkNativo controlador;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final FichaWork? ficha = controlador.workout;

    if (ficha == null) {
      return _ResumoShell(
        onVoltar: onVoltar,
        title: 'Ficha não encontrada.',
        subtitle: 'Volte e selecione uma ficha disponível para iniciar.',
        child: const _ResumoVazioCard(
          mensagem: 'Nenhuma ficha foi selecionada.',
        ),
      );
    }

    return _ResumoShell(
      onVoltar: onVoltar,
      title: 'Ficha ${ficha.key} pronta para execução.',
      subtitle:
          'Confira o resumo da ficha, a carga recente e o histórico antes de iniciar.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _FichaSelecionadaCard(ficha: ficha),
          const SizedBox(height: EspacamentoApp.medio),

          _ResumoMetricCard(
            icon: Icons.schedule_rounded,
            label: 'Tempo estimado',
            value: '${ficha.estimatedMinutes} min',
          ),
          const SizedBox(height: EspacamentoApp.pequeno),

          _ResumoMetricCard(
            icon: Icons.format_list_bulleted_rounded,
            label: 'Séries concluídas',
            value: '${ficha.lastCompletedSets}/${ficha.totalPlannedSets}',
          ),
          const SizedBox(height: EspacamentoApp.pequeno),

          _ResumoMetricCard(
            icon: Icons.local_fire_department_outlined,
            label: 'Carga recente',
            value: _formatarCargaKg(ficha.loadProgress.lastLoadKg),
          ),
          const SizedBox(height: EspacamentoApp.pequeno),

          _ResumoMetricCard(
            icon: Icons.shield_outlined,
            label: 'Intervalo médio',
            value: _formatarIntervalo(ficha.restSeconds),
          ),
          const SizedBox(height: EspacamentoApp.medio),

          _ProgressoCargaCard(ficha: ficha),
          const SizedBox(height: EspacamentoApp.medio),

          _HistoricoResumoCard(ficha: ficha),
          const SizedBox(height: EspacamentoApp.grande),

          _IniciarExecucaoButton(
            onPressed: () {
              controlador.iniciarExecucaoSelecionada();
            },
          ),
        ],
      ),
    );
  }
}

class _ResumoShell extends StatelessWidget {
  const _ResumoShell({
    required this.child,
    required this.onVoltar,
    required this.subtitle,
    required this.title,
  });

  final Widget child;
  final VoidCallback onVoltar;
  final String subtitle;
  final String title;

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
            _ResumoTopBar(onVoltar: onVoltar),

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
                  const _ResumoEyebrow('Track de treino'),
                  const SizedBox(height: EspacamentoApp.medio),
                  Text(
                    title,
                    style: const TextStyle(
                      color: CoresApp.textoPrincipal,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                      letterSpacing: -0.5,
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

class _ResumoTopBar extends StatelessWidget {
  const _ResumoTopBar({required this.onVoltar});

  final VoidCallback onVoltar;

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
          _BotaoVoltarCompacto(onPressed: onVoltar),
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

class _FichaSelecionadaCard extends StatelessWidget {
  const _FichaSelecionadaCard({required this.ficha});

  final FichaWork ficha;

  @override
  Widget build(BuildContext context) {
    final String descricao = ficha.description.trim().isNotEmpty
        ? ficha.description.trim()
        : ficha.category.trim().isNotEmpty
        ? ficha.category.trim()
        : 'Treino próprio';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CoresApp.treinos.withValues(alpha: 0.10),
        border: Border.all(color: CoresApp.treinos.withValues(alpha: 0.45)),
        borderRadius: const BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _ResumoEyebrow('Ficha selecionada'),
          const SizedBox(height: EspacamentoApp.medio),
          Text(
            ficha.key,
            style: const TextStyle(
              color: CoresApp.treinos,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: EspacamentoApp.medio),
          Text(
            'Ficha ${ficha.key}',
            style: const TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            descricao,
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

class _ResumoMetricCard extends StatelessWidget {
  const _ResumoMetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(EspacamentoApp.medio),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.38),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(22)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: CoresApp.treinos, size: 20),
          const SizedBox(width: EspacamentoApp.medio),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ResumoEyebrow(label),
                const SizedBox(height: 7),
                Text(
                  value,
                  style: const TextStyle(
                    color: CoresApp.textoPrincipal,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
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

class _ProgressoCargaCard extends StatelessWidget {
  const _ProgressoCargaCard({required this.ficha});

  final FichaWork ficha;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EspacamentoApp.medio),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.38),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 22,
            backgroundColor: CoresApp.treinos.withValues(alpha: 0.15),
            child: const Icon(
              Icons.trending_up_rounded,
              color: CoresApp.treinos,
              size: 20,
            ),
          ),
          const SizedBox(width: EspacamentoApp.medio),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _ResumoEyebrow('Progressão de carga'),
                const SizedBox(height: 8),
                Text(
                  _formatarProgressoCarga(ficha.loadProgress.deltaKg),
                  style: const TextStyle(
                    color: CoresApp.textoPrincipal,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: EspacamentoApp.medio),
                _MiniResumoCard(
                  label: 'Última sessão',
                  value: ficha.lastCompletedAt == null
                      ? 'Sem histórico'
                      : _formatarDataCurta(ficha.lastCompletedAt!),
                ),
                const SizedBox(height: EspacamentoApp.pequeno),
                _MiniResumoCard(
                  label: 'Histórico salvo',
                  value: '${ficha.completionCount} registro(s)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoricoResumoCard extends StatelessWidget {
  const _HistoricoResumoCard({required this.ficha});

  final FichaWork ficha;

  @override
  Widget build(BuildContext context) {
    final List<HistoricoExecucaoWork> historico =
        ficha.recentHistory.toList(growable: false)..sort(
          (HistoricoExecucaoWork a, HistoricoExecucaoWork b) =>
              b.completedAt.compareTo(a.completedAt),
        );

    return Container(
      padding: const EdgeInsets.all(EspacamentoApp.medio),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.38),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: const <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: Color(0x221E73FF),
                child: Icon(
                  Icons.history_rounded,
                  color: CoresApp.treinos,
                  size: 20,
                ),
              ),
              SizedBox(width: EspacamentoApp.medio),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ResumoEyebrow('Histórico recente'),
                    SizedBox(height: 7),
                    Text(
                      'Últimas execuções da ficha',
                      style: TextStyle(
                        color: CoresApp.textoPrincipal,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: EspacamentoApp.medio),

          if (historico.isEmpty)
            const _ResumoVazioCard(
              mensagem: 'Ainda não há execuções registradas para esta ficha.',
            )
          else
            for (final HistoricoExecucaoWork item in historico.take(3))
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _formatarDataCurta(item.completedAt),
            style: const TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
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
    );
  }
}

class _MiniResumoCard extends StatelessWidget {
  const _MiniResumoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(EspacamentoApp.medio),
      decoration: BoxDecoration(
        color: CoresApp.superficie.withValues(alpha: 0.70),
        border: Border.all(color: CoresApp.borda),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ResumoEyebrow(label),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: CoresApp.textoPrincipal,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumoVazioCard extends StatelessWidget {
  const _ResumoVazioCard({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(EspacamentoApp.grande),
      decoration: BoxDecoration(
        color: CoresApp.fundo.withValues(alpha: 0.22),
        border: Border.all(
          color: CoresApp.borda.withValues(alpha: 0.75),
          style: BorderStyle.solid,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
      ),
      child: Text(
        mensagem,
        style: const TextStyle(
          color: CoresApp.textoSecundario,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
      ),
    );
  }
}

class _IniciarExecucaoButton extends StatelessWidget {
  const _IniciarExecucaoButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: const BoxDecoration(
            color: CoresApp.treinos,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'INICIAR EXECUÇÃO',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: Colors.black, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumoEyebrow extends StatelessWidget {
  const _ResumoEyebrow(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: const TextStyle(
        color: CoresApp.treinos,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 3.2,
      ),
    );
  }
}

String _formatarCargaKg(double? value) {
  if (value == null || value <= 0) {
    return 'Sem carga';
  }

  final bool inteiro = value % 1 == 0;
  final String numero = value.toStringAsFixed(inteiro ? 0 : 1);

  return '$numero kg';
}

String _formatarProgressoCarga(double? value) {
  if (value == null) {
    return 'Sem comparativo';
  }

  if (value == 0) {
    return 'Mesma carga da última sessão';
  }

  final String sinal = value > 0 ? '+' : '-';
  final double absoluto = value.abs();
  final bool inteiro = absoluto % 1 == 0;
  final String numero = absoluto.toStringAsFixed(inteiro ? 0 : 1);

  return '$sinal$numero kg vs. treino anterior';
}

String _formatarIntervalo(int segundos) {
  if (segundos <= 0) {
    return 'Sem intervalo';
  }

  return '${segundos}s';
}

String _formatarDataCurta(String isoString) {
  final DateTime? data = DateTime.tryParse(isoString);

  if (data == null) {
    return 'Sem histórico';
  }

  final DateTime local = data.toLocal();
  final String dia = local.day.toString().padLeft(2, '0');
  final String mes = local.month.toString().padLeft(2, '0');
  final String hora = local.hour.toString().padLeft(2, '0');
  final String minuto = local.minute.toString().padLeft(2, '0');

  return '$dia/$mes às $hora:$minuto';
}
