import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../funcionalidades/autenticacao/estado_sessao.dart';
import '../tema/cores_app.dart';

class WebviewWhyPhyAndroid extends StatelessWidget {
  const WebviewWhyPhyAndroid({
    super.key,
    required this.sessao,
    this.rotaInterna,
    this.versaoNavegacao = 0,
  });

  final SessaoWhyPhy sessao;
  final String? rotaInterna;
  final int versaoNavegacao;

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

    return AndroidView(
      key: ValueKey<String>('${versaoNavegacao}_$webviewUrl'),
      viewType: 'br.com.whyphy/webview',
      creationParams: <String, Object?>{
        'allowedHost': Uri.parse(webviewUrl).host,
        'initialHeaders': <String, String>{
          'authorization': 'Bearer ${sessao.accessToken}',
          'x-device-id': sessao.deviceId,
          'x-whyphy-app': 'flutter-webview',
        },
        'url': webviewUrl,
      },
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
