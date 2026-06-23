import 'package:flutter/material.dart';

import '../../app/rotas.dart';
import '../autenticacao/servico_autenticacao.dart';
import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';

class TelaSplash extends StatefulWidget {
  const TelaSplash({super.key, required this.servicoAutenticacao});

  final ServicoAutenticacao servicoAutenticacao;

  @override
  State<TelaSplash> createState() => _TelaSplashState();
}

class _TelaSplashState extends State<TelaSplash> {
  @override
  void initState() {
    super.initState();
    _validarSessao();
  }

  Future<void> _validarSessao() async {
    final bool autenticado = await widget.servicoAutenticacao.restaurarSessao();

    if (!mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).pushReplacementNamed(autenticado ? RotasApp.shell : RotasApp.login);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'WhyPhy',
                style: TextStyle(
                  color: CoresApp.textoPrincipal,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              SizedBox(height: EspacamentoApp.grande),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: CoresApp.primaria,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
