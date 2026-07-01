import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/configuracao_app.dart';
import '../../app/rotas.dart';
import '../../nucleo/notificacoes/servico_push_mobile.dart';
import '../../nucleo/tema/cores_app.dart';
import '../../nucleo/tema/espacamento_app.dart';
import '../autenticacao/estado_sessao.dart';
import '../autenticacao/servico_autenticacao.dart';

class TelaShellWebviewIOS extends StatefulWidget {
  const TelaShellWebviewIOS({
    super.key,
    required this.estadoSessao,
    required this.servicoAutenticacao,
  });

  final EstadoSessao estadoSessao;
  final ServicoAutenticacao servicoAutenticacao;

  @override
  State<TelaShellWebviewIOS> createState() => _TelaShellWebviewIOSState();
}

class _TelaShellWebviewIOSState extends State<TelaShellWebviewIOS> {
  bool _atualizando = false;
  bool _logoutInterceptado = false;
  bool _logoutEmAndamento = false;
  bool _webviewCarregando = true;
  String? _hostPermitidoAtual;
  String? _mensagemTopo;
  String? _moduloMensagemTopo;
  String? _rotaPushPendente;
  Timer? _timerMensagemTopo;
  WebViewController? _controladorWebview;
  StreamSubscription<Map<String, String>>? _assinaturaPushAberto;
  StreamSubscription<Map<String, String>>? _assinaturaPushRecebido;

  @override
  void initState() {
    super.initState();
    widget.estadoSessao.addListener(_atualizar);
    _escutarPushFlutter();
    unawaited(_consumirPushInicial());
  }

  @override
  void dispose() {
    widget.estadoSessao.removeListener(_atualizar);
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

  Future<void> _consumirPushInicial() async {
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
      _controladorWebview = null;
    });
  }

  Future<void> _voltarParaLoginAposLogoutWeb() async {
    if (_logoutInterceptado) {
      return;
    }

    setState(() {
      _logoutInterceptado = true;
      _logoutEmAndamento = true;
    });

    await widget.servicoAutenticacao.sair();

    if (!mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RotasApp.login, (_) => false);
  }

  Future<void> _tratarVoltarFisico() async {
    final WebViewController? controlador = _controladorWebview;

    if (controlador != null && await controlador.canGoBack()) {
      await controlador.goBack();
      return;
    }

    _mostrarAvisoTopo('Use a navegação do WhyPhy para sair ou voltar.');
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
      _webviewCarregando = true;
    });

    final SessaoWhyPhy? sessao = widget.estadoSessao.sessaoAtual;
    final WebViewController? controlador = _controladorWebview;

    if (sessao?.bootstrap != null && controlador != null) {
      unawaited(
        controlador.loadRequest(
          Uri.parse(_resolverUrlWebview(sessao!.bootstrap!.webviewUrl)),
          headers: _headersWebview(sessao),
        ),
      );
    }
  }

  WebViewController _obterControlador(
    BuildContext context,
    SessaoWhyPhy sessao,
    double viewportHeight,
  ) {
    final WebViewController? controladorAtual = _controladorWebview;
    final String webviewUrl = _resolverUrlWebview(sessao.bootstrap!.webviewUrl);
    final String hostPermitido = Uri.parse(webviewUrl).host;

    if (controladorAtual != null && _hostPermitidoAtual == hostPermitido) {
      return controladorAtual;
    }

    _hostPermitidoAtual = hostPermitido;

    final WebViewController controlador = WebViewController();

    controlador
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(CoresApp.fundo)
      ..addJavaScriptChannel(
        'WhyPhyLogout',
        onMessageReceived: (_) {
          unawaited(_voltarParaLoginAposLogoutWeb());
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _webviewCarregando = true;
            });
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _webviewCarregando = false;
              });
            }

            unawaited(
              _instalarMetricasWebview(controlador, context, viewportHeight),
            );
            unawaited(_instalarPonteLogout(controlador));
          },
          onNavigationRequest: (NavigationRequest request) {
            return _decidirNavegacao(request.url);
          },
          onWebResourceError: (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _webviewCarregando = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(webviewUrl), headers: _headersWebview(sessao));

    _controladorWebview = controlador;

    return controlador;
  }

  NavigationDecision _decidirNavegacao(String url) {
    final Uri? uri = Uri.tryParse(url);

    if (uri == null) {
      return NavigationDecision.prevent;
    }

    if (_ehRotaLogout(uri)) {
      unawaited(_voltarParaLoginAposLogoutWeb());
      return NavigationDecision.prevent;
    }

    if (_hostPermitido(uri.host)) {
      return NavigationDecision.navigate;
    }

    if (_deveAbrirExternamente(uri)) {
      _mostrarAvisoTopo('Abra este link fora do app para continuar.');
      return NavigationDecision.prevent;
    }

    _mostrarAvisoTopo('Navegação externa bloqueada pelo app WhyPhy.');
    return NavigationDecision.prevent;
  }

  String _metricasWebviewJson(BuildContext context, double viewportHeight) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Map<String, num> metricas = <String, num>{
      'safeAreaBottom': mediaQuery.padding.bottom,
      'screenHeight': mediaQuery.size.height,
      'viewportHeight': viewportHeight,
    };

    return jsonEncode(metricas);
  }

  Future<void> _instalarMetricasWebview(
    WebViewController controlador,
    BuildContext context,
    double viewportHeight,
  ) async {
    final String metricasJson = _metricasWebviewJson(context, viewportHeight);

    await controlador.runJavaScript('''
      (function() {
        var metricas = $metricasJson;
        var root = document.documentElement;
        if (!root || !metricas) return;
        var safeBottom = Math.max(Number(metricas.safeAreaBottom) || 0, 0);
        root.style.setProperty("--flutter-safe-bottom", safeBottom + "px");
        window.__whyphyViewportInfo = metricas;
        window.dispatchEvent(new CustomEvent("whyphy:flutter-viewport", { detail: metricas }));
      })();
    ''');
  }

  Future<void> _instalarPonteLogout(WebViewController controlador) async {
    await controlador.runJavaScript('''
      (function() {
        if (window.__whyphyIosLogoutBridge) return;
        window.__whyphyIosLogoutBridge = true;

        function ehLogout(url) {
          try {
            var destino = new URL(String(url || window.location.href), window.location.href);
            var path = destino.pathname;
            return path === "/login" ||
              path === "/logout" ||
              path === "/api/auth/logout" ||
              path === "/api/mobile/auth/logout" ||
              path === "/api/auth/force-logout";
          } catch (_) {
            return false;
          }
        }

        function notificarLogout() {
          if (window.WhyPhyLogout && window.WhyPhyLogout.postMessage) {
            window.WhyPhyLogout.postMessage(window.location.href);
          }
        }

        if (window.fetch) {
          var fetchOriginal = window.fetch;
          window.fetch = function(input, init) {
            var url = typeof input === "string" ? input : input && input.url;
            var resposta = fetchOriginal.apply(this, arguments);
            if (ehLogout(url)) {
              Promise.resolve(resposta).finally(function() {
                window.setTimeout(notificarLogout, 0);
              });
            }
            return resposta;
          };
        }

        if (window.XMLHttpRequest) {
          var abrirOriginal = XMLHttpRequest.prototype.open;
          var enviarOriginal = XMLHttpRequest.prototype.send;
          XMLHttpRequest.prototype.open = function(method, url) {
            this.__whyphyLogoutUrl = url;
            return abrirOriginal.apply(this, arguments);
          };
          XMLHttpRequest.prototype.send = function() {
            if (ehLogout(this.__whyphyLogoutUrl)) {
              this.addEventListener("loadend", function() {
                window.setTimeout(notificarLogout, 0);
              });
            }
            return enviarOriginal.apply(this, arguments);
          };
        }

        document.addEventListener("click", function(event) {
          var alvo = event.target && event.target.closest ? event.target.closest("a[href]") : null;
          if (alvo && ehLogout(alvo.href)) {
            window.setTimeout(notificarLogout, 0);
          }
        }, true);

        if (ehLogout(window.location.href)) {
          window.setTimeout(notificarLogout, 0);
        }
      })();
    ''');
  }

  String _resolverUrlWebview(String urlBase) {
    final String rota = (_rotaPushPendente ?? '').trim();

    if (rota.isEmpty || !rota.startsWith('/') || rota.startsWith('//')) {
      return urlBase;
    }

    final Uri uriBase = Uri.parse(urlBase);
    final Map<String, String> query = <String, String>{
      ...uriBase.queryParameters,
      'next': rota,
    };

    return uriBase.replace(queryParameters: query).toString();
  }

  Map<String, String> _headersWebview(SessaoWhyPhy sessao) {
    return <String, String>{
      'Authorization': 'Bearer ${sessao.accessToken}',
      'x-device-id': sessao.deviceId,
      'x-whyphy-app': ConfiguracaoApp.identificadorAppWebview,
    };
  }

  bool _hostPermitido(String host) {
    final String hostAtual = _hostPermitidoAtual ?? '';

    if (host == hostAtual) {
      return true;
    }

    const String dominioPrincipal = 'whyphy.com.br';
    final bool ambienteWhyPhy =
        hostAtual == dominioPrincipal ||
        hostAtual.endsWith('.$dominioPrincipal');

    return ambienteWhyPhy &&
        (host == dominioPrincipal || host.endsWith('.$dominioPrincipal'));
  }

  bool _ehRotaLogout(Uri uri) {
    if (!_hostPermitido(uri.host)) {
      return false;
    }

    return uri.path == '/login' ||
        uri.path == '/logout' ||
        uri.path == '/api/auth/logout' ||
        uri.path == '/api/mobile/auth/logout' ||
        uri.path == '/api/auth/force-logout';
  }

  bool _deveAbrirExternamente(Uri uri) {
    return uri.scheme == 'mailto' || uri.scheme == 'tel' || uri.host == 'wa.me';
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

  String _lerString(Map<Object?, Object?> map, String chave) {
    final Object? valor = map[chave];

    if (valor is String) {
      return valor.trim();
    }

    return '';
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

  @override
  Widget build(BuildContext context) {
    final SessaoWhyPhy? sessao = widget.estadoSessao.sessaoAtual;
    final bool temWebviewAutenticada = sessao?.bootstrap != null;
    final Widget conteudo = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _buildConteudo(context, sessao),
        if (temWebviewAutenticada && _webviewCarregando)
          const _CarregamentoWebviewIOS(),
        if (_logoutEmAndamento)
          const _CarregamentoWebviewIOS(
            descricao: 'Limpando o acesso e voltando para o login seguro.',
            mostrarPulsos: false,
            titulo: 'Encerrando sessão',
          ),
        if (_mensagemTopo != null)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _AvisoTopoWebviewIOS(
              mensagem: _mensagemTopo!,
              modulo: _moduloMensagemTopo ?? '',
            ),
          ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_tratarVoltarFisico());
        }
      },
      child: ColoredBox(
        color: CoresApp.fundo,
        child: temWebviewAutenticada
            ? SafeArea(top: true, bottom: false, child: conteudo)
            : SafeArea(child: conteudo),
      ),
    );
  }

  Widget _buildConteudo(BuildContext context, SessaoWhyPhy? sessao) {
    if (sessao?.bootstrap != null) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return WebViewWidget(
            controller: _obterControlador(
              context,
              sessao!,
              constraints.maxHeight,
            ),
          );
        },
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

class _CarregamentoWebviewIOS extends StatelessWidget {
  const _CarregamentoWebviewIOS({
    this.descricao = 'Sincronizando sua sessão e preparando o ambiente.',
    this.mostrarPulsos = true,
    this.titulo = 'Carregando WhyPhy',
  });

  final String descricao;
  final bool mostrarPulsos;
  final String titulo;

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
            child: _FaixaCarregamentoIOS(
              cor: CoresApp.primaria.withValues(alpha: 0.22),
              largura: 260,
            ),
          ),
          Positioned(
            bottom: 92,
            left: -92,
            child: _FaixaCarregamentoIOS(
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
                        titulo,
                        style: textos.headlineSmall?.copyWith(
                          color: CoresApp.textoPrincipal,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: EspacamentoApp.pequeno),
                      Text(
                        descricao,
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
                      if (mostrarPulsos) ...<Widget>[
                        const SizedBox(height: EspacamentoApp.medio),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const <Widget>[
                            _PulsoModuloIOS(cor: CoresApp.dieta),
                            SizedBox(width: EspacamentoApp.pequeno),
                            _PulsoModuloIOS(cor: CoresApp.treinos),
                            SizedBox(width: EspacamentoApp.pequeno),
                            _PulsoModuloIOS(cor: CoresApp.consultas),
                          ],
                        ),
                      ],
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

class _FaixaCarregamentoIOS extends StatelessWidget {
  const _FaixaCarregamentoIOS({required this.cor, required this.largura});

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

class _PulsoModuloIOS extends StatelessWidget {
  const _PulsoModuloIOS({required this.cor});

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

class _AvisoTopoWebviewIOS extends StatelessWidget {
  const _AvisoTopoWebviewIOS({required this.mensagem, required this.modulo});

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
                offset: const Offset(0, 10),
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
