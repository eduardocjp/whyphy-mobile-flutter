import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/rotas.dart';
import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import '../../nucleo/notificacoes/servico_push_mobile.dart';
import '../../nucleo/webview/webview_whyphy_android.dart';
import '../autenticacao/estado_sessao.dart';
import '../autenticacao/servico_autenticacao.dart';

class TelaShellWebview extends StatefulWidget {
  const TelaShellWebview({
    super.key,
    required this.estadoSessao,
    required this.servicoAutenticacao,
  });

  final EstadoSessao estadoSessao;
  final ServicoAutenticacao servicoAutenticacao;

  @override
  State<TelaShellWebview> createState() => _TelaShellWebviewState();
}

class _TelaShellWebviewState extends State<TelaShellWebview> {
  static const MethodChannel _canalEventosWebview = MethodChannel(
    'br.com.whyphy/webview_eventos',
  );

  bool _atualizando = false;
  bool _logoutInterceptado = false;
  int _versaoNavegacaoPush = 0;
  bool _webviewCarregando = true;
  String? _mensagemTopo;
  String? _moduloMensagemTopo;
  String? _rotaPushPendente;
  StreamSubscription<Map<String, String>>? _assinaturaPushAberto;
  StreamSubscription<Map<String, String>>? _assinaturaPushRecebido;
  Timer? _timerMensagemTopo;

  @override
  void initState() {
    super.initState();
    widget.estadoSessao.addListener(_atualizar);
    _canalEventosWebview.setMethodCallHandler(_tratarEventoWebview);
    _escutarPushFlutter();
    unawaited(_consumirPushInicial());
  }

  @override
  void dispose() {
    widget.estadoSessao.removeListener(_atualizar);
    _canalEventosWebview.setMethodCallHandler(null);
    _assinaturaPushAberto?.cancel();
    _assinaturaPushRecebido?.cancel();
    _timerMensagemTopo?.cancel();
    super.dispose();
  }

  void _atualizar() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _tratarEventoWebview(MethodCall call) async {
    if (call.method == 'logoutDetectado') {
      await _voltarParaLoginAposLogoutWeb();
      return;
    }

    if (call.method == 'pushAberto') {
      _aplicarCargaPush(_extrairCargaPush(call.arguments));
      return;
    }

    if (call.method == 'notificacaoWeb') {
      _mostrarAvisoTopo(
        _extrairMensagem(call.arguments),
        modulo: _extrairModuloAviso(call.arguments),
      );
      return;
    }

    if (call.method == 'carregamentoWebviewIniciado') {
      _definirCarregamentoWebview(true);
      return;
    }

    if (call.method == 'carregamentoWebviewConcluido') {
      _definirCarregamentoWebview(false);
      return;
    }

    if (call.method == 'popupNativoWeb') {
      await _mostrarPopupNativoWeb(_extrairPopupNativo(call.arguments));
    }
  }

  Future<void> _consumirPushInicial() async {
    final Object? arguments = await _canalEventosWebview.invokeMethod<Object?>(
      'consumirPushAberto',
    );

    _aplicarCargaPush(_extrairCargaPush(arguments));

    Map<String, String>? pushPendente =
        ServicoPushMobile.consumirPushPendente();

    while (pushPendente != null) {
      _aplicarCargaPush(_extrairCargaPush(pushPendente));
      pushPendente = ServicoPushMobile.consumirPushPendente();
    }
  }

  void _escutarPushFlutter() {
    _assinaturaPushAberto = ServicoPushMobile.pushAbertos.listen((
      Map<String, String> carga,
    ) {
      _aplicarCargaPush(_extrairCargaPush(carga));
    });
    _assinaturaPushRecebido = ServicoPushMobile.pushRecebidos.listen((
      Map<String, String> carga,
    ) {
      final String mensagem = _primeiroValorNaoVazio(<String?>[
        carga['mensagem'],
        carga['title'],
      ]);

      if (mensagem.isNotEmpty) {
        _mostrarAvisoTopo(mensagem);
      }
    });
  }

  void _definirCarregamentoWebview(bool carregando) {
    if (!mounted || _webviewCarregando == carregando) {
      return;
    }

    setState(() {
      _webviewCarregando = carregando;
    });
  }

  Future<void> _atualizarBootstrap() async {
    if (_atualizando) {
      return;
    }

    setState(() {
      _atualizando = true;
    });

    await widget.servicoAutenticacao.prepararWebview();

    if (!mounted) {
      return;
    }

    setState(() {
      _atualizando = false;
    });
  }

  Future<void> _voltarParaLoginAposLogoutWeb() async {
    if (_logoutInterceptado) {
      return;
    }

    _logoutInterceptado = true;
    await widget.servicoAutenticacao.sair();

    if (!mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RotasApp.login, (_) => false);
  }

  String _extrairMensagem(Object? arguments) {
    if (arguments is Map<Object?, Object?>) {
      final Object? mensagem = arguments['mensagem'];

      if (mensagem is String && mensagem.trim().isNotEmpty) {
        return mensagem.trim();
      }
    }

    return 'Notificação do WhyPhy.';
  }

  String _extrairModuloAviso(Object? arguments) {
    if (arguments is Map<Object?, Object?>) {
      return _lerString(arguments, 'modulo');
    }

    return '';
  }

  void _mostrarAvisoTopo(String mensagem, {String modulo = ''}) {
    if (!mounted) {
      return;
    }

    _timerMensagemTopo?.cancel();

    setState(() {
      _mensagemTopo = mensagem;
      _moduloMensagemTopo = modulo;
    });

    _timerMensagemTopo = Timer(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _mensagemTopo = null;
        _moduloMensagemTopo = null;
      });
    });
  }

  void _aplicarCargaPush(_CargaPushAberta? carga) {
    if (!mounted || carga == null) {
      return;
    }

    if (carga.mensagem.isNotEmpty) {
      _mostrarAvisoTopo(
        carga.mensagem,
        modulo: _moduloPorRota(carga.routePath),
      );
    }

    if (carga.routePath.isEmpty) {
      return;
    }

    setState(() {
      _rotaPushPendente = carga.routePath;
      _versaoNavegacaoPush += 1;
    });
  }

  _PopupNativoWeb _extrairPopupNativo(Object? arguments) {
    if (arguments is Map<Object?, Object?>) {
      return _PopupNativoWeb(
        id: _lerString(arguments, 'id'),
        mensagem: _lerString(arguments, 'mensagem'),
        textoPadrao: _lerString(arguments, 'textoPadrao'),
        tipo: _lerString(arguments, 'tipo'),
      );
    }

    return const _PopupNativoWeb(
      id: '',
      mensagem: 'O WhyPhy precisa da sua confirmação.',
      textoPadrao: '',
      tipo: 'alerta',
    );
  }

  String _lerString(Map<Object?, Object?> map, String chave) {
    final Object? valor = map[chave];

    if (valor is String) {
      return valor.trim();
    }

    return '';
  }

  _CargaPushAberta? _extrairCargaPush(Object? arguments) {
    if (arguments is! Map<Object?, Object?>) {
      return null;
    }

    final String routePath = _lerString(arguments, 'routePath');

    if (!_rotaInternaValida(routePath)) {
      return null;
    }

    final String mensagem = _lerString(arguments, 'mensagem');
    final String titulo = _lerString(arguments, 'title');

    return _CargaPushAberta(
      mensagem: mensagem.isNotEmpty ? mensagem : titulo,
      routePath: routePath,
    );
  }

  String _primeiroValorNaoVazio(List<String?> valores) {
    for (final String? valor in valores) {
      final String normalizado = valor?.trim() ?? '';

      if (normalizado.isNotEmpty) {
        return normalizado;
      }
    }

    return '';
  }

  bool _rotaInternaValida(String routePath) {
    return routePath.isNotEmpty &&
        routePath.startsWith('/') &&
        !routePath.startsWith('//');
  }

  String _moduloPorRota(String routePath) {
    final String rota = routePath.toLowerCase();

    if (rota.startsWith('/work') || rota.contains('/treino')) {
      return 'treinos';
    }

    if (rota.contains('/dieta')) {
      return 'dieta';
    }

    if (rota.contains('/evolucao') || rota.contains('/evolucoes')) {
      return 'evolucao';
    }

    return '';
  }

  Future<void> _mostrarPopupNativoWeb(_PopupNativoWeb popup) async {
    if (!mounted || popup.id.isEmpty) {
      return;
    }

    final _RespostaPopupNativo resposta =
        await showDialog<_RespostaPopupNativo>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return _ModalPopupNativoWeb(popup: popup);
          },
        ) ??
        const _RespostaPopupNativo(confirmado: false, texto: '');

    await _canalEventosWebview.invokeMethod<void>(
      'responderPopupNativo',
      <String, Object?>{
        'confirmado': resposta.confirmado,
        'id': popup.id,
        'texto': resposta.texto,
      },
    );
  }

  Future<void> _tratarVoltarFisico() async {
    try {
      final bool voltouNaWebview =
          await _canalEventosWebview.invokeMethod<bool>('voltarWebview') ??
          false;

      if (voltouNaWebview || !mounted) {
        return;
      }
    } on PlatformException {
      if (!mounted) {
        return;
      }
    }

    _mostrarAvisoTopo('Use a navegação do WhyPhy para sair ou voltar.');
  }

  @override
  Widget build(BuildContext context) {
    final SessaoWhyPhy? sessao = widget.estadoSessao.sessaoAtual;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_tratarVoltarFisico());
        }
      },
      child: ColoredBox(
        color: CoresApp.fundo,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _buildConteudo(context, sessao),
              if (sessao?.bootstrap != null && _webviewCarregando)
                const _CarregamentoWebview(),
              if (_mensagemTopo != null)
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: _AvisoTopoWebview(
                    mensagem: _mensagemTopo!,
                    modulo: _moduloMensagemTopo ?? '',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConteudo(BuildContext context, SessaoWhyPhy? sessao) {
    if (sessao?.bootstrap != null) {
      return WebviewWhyPhyAndroid(
        sessao: sessao!,
        rotaInterna: _rotaPushPendente,
        versaoNavegacao: _versaoNavegacaoPush,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(EspacamentoApp.medio),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: CoresApp.superficie,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(EspacamentoApp.grande),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Preparando painel',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: EspacamentoApp.medio),
                  Text(
                    'A sessão autenticada da WebView ainda não foi carregada.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: EspacamentoApp.grande),
                  OutlinedButton(
                    onPressed: _atualizando ? null : _atualizarBootstrap,
                    child: Text(
                      _atualizando ? 'Atualizando...' : 'Tentar novamente',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CargaPushAberta {
  const _CargaPushAberta({required this.mensagem, required this.routePath});

  final String mensagem;
  final String routePath;
}

class _PopupNativoWeb {
  const _PopupNativoWeb({
    required this.id,
    required this.mensagem,
    required this.textoPadrao,
    required this.tipo,
  });

  final String id;
  final String mensagem;
  final String textoPadrao;
  final String tipo;

  bool get exigeEntrada {
    return tipo == 'entrada';
  }

  bool get exigeConfirmacao {
    return tipo == 'confirmacao' || exigeEntrada;
  }
}

class _RespostaPopupNativo {
  const _RespostaPopupNativo({required this.confirmado, required this.texto});

  final bool confirmado;
  final String texto;
}

class _ModalPopupNativoWeb extends StatefulWidget {
  const _ModalPopupNativoWeb({required this.popup});

  final _PopupNativoWeb popup;

  @override
  State<_ModalPopupNativoWeb> createState() => _ModalPopupNativoWebState();
}

class _ModalPopupNativoWebState extends State<_ModalPopupNativoWeb> {
  late final TextEditingController _controladorTexto;

  @override
  void initState() {
    super.initState();
    _controladorTexto = TextEditingController(text: widget.popup.textoPadrao);
  }

  @override
  void dispose() {
    _controladorTexto.dispose();
    super.dispose();
  }

  void _responder(bool confirmado) {
    Navigator.of(context).pop(
      _RespostaPopupNativo(
        confirmado: confirmado,
        texto: confirmado ? _controladorTexto.text : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String mensagem = widget.popup.mensagem.isEmpty
        ? 'O WhyPhy precisa da sua confirmação.'
        : widget.popup.mensagem;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CoresApp.superficieElevada,
          border: Border.all(color: CoresApp.borda),
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0xCC000000),
              blurRadius: 28,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(EspacamentoApp.grande),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'WhyPhy',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: CoresApp.primaria,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: EspacamentoApp.pequeno),
              Text(
                widget.popup.exigeConfirmacao
                    ? 'Confirmação necessária'
                    : 'Aviso do sistema',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CoresApp.textoPrincipal,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: EspacamentoApp.medio),
              Text(
                mensagem,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CoresApp.textoSecundario,
                  height: 1.4,
                ),
              ),
              if (widget.popup.exigeEntrada) ...<Widget>[
                const SizedBox(height: EspacamentoApp.medio),
                TextField(
                  controller: _controladorTexto,
                  autofocus: true,
                  style: const TextStyle(color: CoresApp.textoPrincipal),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: CoresApp.superficie,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: EspacamentoApp.grande),
              if (widget.popup.exigeConfirmacao)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _responder(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: EspacamentoApp.pequeno),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _responder(true),
                        child: const Text('Continuar'),
                      ),
                    ),
                  ],
                )
              else
                FilledButton(
                  onPressed: () => _responder(true),
                  child: const Text('Entendi'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarregamentoWebview extends StatelessWidget {
  const _CarregamentoWebview();

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[CoresApp.fundo, CoresApp.superficie, CoresApp.fundo],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 72,
            right: -76,
            child: _FaixaCarregamento(
              cor: CoresApp.primaria.withValues(alpha: 0.22),
              largura: 260,
            ),
          ),
          Positioned(
            bottom: 92,
            left: -92,
            child: _FaixaCarregamento(
              cor: CoresApp.dieta.withValues(alpha: 0.16),
              largura: 300,
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(EspacamentoApp.grande),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Align(
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: CoresApp.superficieElevada,
                            border: Border.all(
                              color: CoresApp.primaria.withValues(alpha: 0.52),
                            ),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(22),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: CoresApp.primaria.withValues(
                                  alpha: 0.24,
                                ),
                                blurRadius: 34,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.all(
                                Radius.circular(18),
                              ),
                              child: Image(
                                image: AssetImage('assets/logo.png'),
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: EspacamentoApp.grande),
                      Text(
                        'Carregando WhyPhy',
                        style: textos.headlineSmall?.copyWith(
                          color: CoresApp.textoPrincipal,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: EspacamentoApp.pequeno),
                      Text(
                        'Sincronizando sua sessão e preparando o ambiente.',
                        style: textos.bodyMedium?.copyWith(
                          color: CoresApp.textoSecundario,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: EspacamentoApp.grande),
                      ClipRRect(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(999),
                        ),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          color: CoresApp.primaria,
                          backgroundColor: CoresApp.superficieElevada,
                        ),
                      ),
                      const SizedBox(height: EspacamentoApp.medio),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const <Widget>[
                          _PulsoModulo(cor: CoresApp.dieta),
                          SizedBox(width: EspacamentoApp.pequeno),
                          _PulsoModulo(cor: CoresApp.treinos),
                          SizedBox(width: EspacamentoApp.pequeno),
                          _PulsoModulo(cor: CoresApp.consultas),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaixaCarregamento extends StatelessWidget {
  const _FaixaCarregamento({required this.cor, required this.largura});

  final Color cor;
  final double largura;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: -0.22,
        child: Container(
          width: largura,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            gradient: LinearGradient(
              colors: <Color>[Colors.transparent, cor, Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsoModulo extends StatelessWidget {
  const _PulsoModulo({required this.cor});

  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 5,
      decoration: BoxDecoration(
        color: cor,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: cor.withValues(alpha: 0.34),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _AvisoTopoWebview extends StatelessWidget {
  const _AvisoTopoWebview({required this.mensagem, required this.modulo});

  final String mensagem;
  final String modulo;

  Color get _corBorda {
    return switch (modulo) {
      'treinos' => CoresApp.treinos,
      'dieta' => CoresApp.dieta,
      'evolucao' => CoresApp.evolucao,
      _ => CoresApp.borda,
    };
  }

  @override
  Widget build(BuildContext context) {
    final Color corBorda = _corBorda;

    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CoresApp.superficieElevada,
            border: Border.all(color: corBorda.withValues(alpha: 0.72)),
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: corBorda.withValues(alpha: 0.24),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
              const BoxShadow(
                color: Color(0x99000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: EspacamentoApp.medio,
              vertical: EspacamentoApp.pequeno,
            ),
            child: Text(
              mensagem,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CoresApp.textoPrincipal,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
