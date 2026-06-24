import 'dart:io';

import 'package:flutter/material.dart';

import '../funcionalidades/autenticacao/tela_login.dart';
import '../funcionalidades/shell/tela_shell_webview_ios.dart';
import '../funcionalidades/shell/tela_shell_webview.dart';
import '../funcionalidades/splash/tela_splash.dart';
import '../nucleo/tema/cores_app.dart';
import '../nucleo/tema/espacamento_app.dart';
import '../nucleo/tema/raios_app.dart';
import '../nucleo/tema/tipografia_app.dart';
import 'dependencias_app.dart';
import 'rotas.dart';

class AplicativoWhyPhy extends StatelessWidget {
  const AplicativoWhyPhy({super.key, this.dependencias});

  final DependenciasApp? dependencias;

  @override
  Widget build(BuildContext context) {
    final DependenciasApp deps = dependencias ?? dependenciasAppPadrao;

    return MaterialApp(
      title: 'WhyPhy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: CoresApp.fundo,
        colorScheme: const ColorScheme.dark(
          primary: CoresApp.primaria,
          secondary: CoresApp.consultas,
          surface: CoresApp.superficie,
          onSurface: CoresApp.textoPrincipal,
        ),
        textTheme: TipografiaApp.textTheme,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: CoresApp.superficieElevada,
          contentPadding: EdgeInsets.symmetric(
            horizontal: EspacamentoApp.medio,
            vertical: EspacamentoApp.pequeno,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(RaiosApp.medio)),
            borderSide: BorderSide(color: CoresApp.borda),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(RaiosApp.medio)),
            borderSide: BorderSide(color: CoresApp.borda),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(RaiosApp.medio)),
            borderSide: BorderSide(color: CoresApp.primaria),
          ),
          labelStyle: TextStyle(color: CoresApp.textoSecundario),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: CoresApp.primaria,
            foregroundColor: CoresApp.textoPrincipal,
            minimumSize: const Size.fromHeight(48),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(RaiosApp.grande)),
            ),
            textStyle: TipografiaApp.textTheme.labelLarge,
          ),
        ),
      ),
      initialRoute: RotasApp.splash,
      routes: <String, WidgetBuilder>{
        RotasApp.splash: (_) =>
            TelaSplash(servicoAutenticacao: deps.servicoAutenticacao),
        RotasApp.login: (_) =>
            TelaLogin(servicoAutenticacao: deps.servicoAutenticacao),
        RotasApp.shell: (_) {
          if (Platform.isIOS) {
            return TelaShellWebviewIOS(
              estadoSessao: deps.estadoSessao,
              servicoAutenticacao: deps.servicoAutenticacao,
            );
          }

          return TelaShellWebview(
            estadoSessao: deps.estadoSessao,
            servicoAutenticacao: deps.servicoAutenticacao,
          );
        },
      },
    );
  }
}
