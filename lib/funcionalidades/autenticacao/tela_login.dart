import 'package:flutter/material.dart';

import '../../app/rotas.dart';
import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import 'servico_autenticacao.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key, required this.servicoAutenticacao});

  final ServicoAutenticacao servicoAutenticacao;

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _carregando = false;
  String? _mensagemErro;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_carregando) {
      return;
    }

    final String email = _emailController.text.trim();
    final String senha = _senhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      setState(() {
        _mensagemErro = 'Informe e-mail e senha.';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    final ResultadoLogin resultado = await widget.servicoAutenticacao.entrar(
      CredenciaisLogin(email: email, senha: senha),
    );

    if (!mounted) {
      return;
    }

    if (resultado.autenticado) {
      await Navigator.of(context).pushReplacementNamed(RotasApp.shell);
      return;
    }

    setState(() {
      _carregando = false;
      _mensagemErro = resultado.mensagem ?? 'Não foi possível entrar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(EspacamentoApp.medio),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Entrar no WhyPhy',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: EspacamentoApp.pequeno),
              Text(
                'Acesse sua rotina WhyPhy.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: EspacamentoApp.grande),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: CoresApp.textoPrincipal),
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: EspacamentoApp.medio),
              TextField(
                controller: _senhaController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: CoresApp.textoPrincipal),
                decoration: const InputDecoration(labelText: 'Senha'),
                onSubmitted: (_) => _entrar(),
              ),
              if (_mensagemErro != null) ...<Widget>[
                const SizedBox(height: EspacamentoApp.medio),
                Text(
                  _mensagemErro!,
                  style: const TextStyle(
                    color: CoresApp.consultas,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: EspacamentoApp.grande),
              ElevatedButton(
                onPressed: _carregando ? null : _entrar,
                child: _carregando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: CoresApp.textoPrincipal,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Entrar',
                        style: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
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
