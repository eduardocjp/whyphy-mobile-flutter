import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/configuracao_app.dart';
import '../../funcionalidades/autenticacao/estado_sessao.dart';
import '../tema/cores_app.dart';

class WebviewWhyPhyAndroid extends StatelessWidget {
  const WebviewWhyPhyAndroid({
    super.key,
    required this.sessao,
    this.rotaInterna,
  });

  final SessaoWhyPhy sessao;
  final String? rotaInterna;

  String _resolverUrlWebview(String urlBase) {
    final String rota = (rotaInterna ?? '').trim();

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

  @override
  Widget build(BuildContext context) {
    final bootstrap = sessao.bootstrap;

    if (bootstrap == null) {
      return const SizedBox.shrink();
    }

    if (!Platform.isAndroid) {
      return const Center(
        child: Text(
          'WebView disponível para Android nesta etapa.',
          style: TextStyle(color: CoresApp.textoSecundario),
          textAlign: TextAlign.center,
        ),
      );
    }

    final String webviewUrl = _resolverUrlWebview(bootstrap.webviewUrl);
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return AndroidView(
          key: const ValueKey<String>('whyphy-webview-android'),
          viewType: 'br.com.whyphy/webview',
          creationParams: <String, Object?>{
            'allowedHost': Uri.parse(webviewUrl).host,
            'safeAreaBottom': mediaQuery.padding.bottom,
            'screenHeight': mediaQuery.size.height,
            'viewportHeight': constraints.maxHeight,
            'initialHeaders': <String, String>{
              'authorization': 'Bearer ${sessao.accessToken}',
              'x-device-id': sessao.deviceId,
              'x-whyphy-app': ConfiguracaoApp.identificadorAppWebview,
            },
            'url': webviewUrl,
          },
          creationParamsCodec: const StandardMessageCodec(),
        );
      },
    );
  }
}
