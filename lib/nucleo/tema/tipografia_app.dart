import 'package:flutter/material.dart';

import 'cores_app.dart';

abstract final class TipografiaApp {
  static const String fonteBase = 'Inter';

  static const TextTheme textTheme = TextTheme(
    headlineLarge: TextStyle(
      color: CoresApp.textoPrincipal,
      fontFamily: fonteBase,
      fontSize: 34,
      fontWeight: FontWeight.w800,
      height: 1.08,
    ),
    headlineMedium: TextStyle(
      color: CoresApp.textoPrincipal,
      fontFamily: fonteBase,
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.12,
    ),
    titleLarge: TextStyle(
      color: CoresApp.textoPrincipal,
      fontFamily: fonteBase,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.18,
    ),
    bodyLarge: TextStyle(
      color: CoresApp.textoPrincipal,
      fontFamily: fonteBase,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.35,
    ),
    bodyMedium: TextStyle(
      color: CoresApp.textoSecundario,
      fontFamily: fonteBase,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      color: CoresApp.textoPrincipal,
      fontFamily: fonteBase,
      fontSize: 15,
      fontWeight: FontWeight.w800,
      height: 1.2,
    ),
    labelMedium: TextStyle(
      color: CoresApp.textoSecundario,
      fontFamily: fonteBase,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 0,
    ),
  );

  // Padrões usados nas telas escuras do app
  static const TextStyle eyebrow = TextStyle(
    color: CoresApp.workPrimaria,
    fontFamily: fonteBase,
    fontSize: 9,
    fontWeight: FontWeight.w900,
    height: 1.1,
    letterSpacing: 3,
  );

  static const TextStyle tituloCardCompacto = TextStyle(
    color: CoresApp.textoPrincipal,
    fontFamily: fonteBase,
    fontSize: 19,
    fontWeight: FontWeight.w900,
    height: 1.05,
    letterSpacing: -0.4,
  );

  static const TextStyle tituloCard = TextStyle(
    color: CoresApp.textoPrincipal,
    fontFamily: fonteBase,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    height: 1.05,
    letterSpacing: -0.5,
  );

  static const TextStyle metricaLabel = TextStyle(
    color: CoresApp.textoSuave,
    fontFamily: fonteBase,
    fontSize: 7,
    fontWeight: FontWeight.w900,
    height: 1.1,
    letterSpacing: 1.2,
  );

  static const TextStyle metricaValor = TextStyle(
    color: CoresApp.textoPrincipal,
    fontFamily: fonteBase,
    fontSize: 13,
    fontWeight: FontWeight.w900,
    height: 1,
  );

  static const TextStyle botaoCompacto = TextStyle(
    color: CoresApp.workPrimaria,
    fontFamily: fonteBase,
    fontSize: 10,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: 1.5,
  );

  static const TextStyle botaoInferior = TextStyle(
    fontFamily: fonteBase,
    fontSize: 12,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: 2.4,
  );

  static const TextStyle serieTitulo = TextStyle(
    color: CoresApp.textoPrincipal,
    fontFamily: fonteBase,
    fontSize: 12,
    fontWeight: FontWeight.w900,
    height: 1.1,
  );

  static const TextStyle campoSerieValor = TextStyle(
    color: CoresApp.textoPrincipal,
    fontFamily: fonteBase,
    fontSize: 13,
    fontWeight: FontWeight.w900,
    height: 1,
  );

  static const TextStyle campoSeriePrefixo = TextStyle(
    color: CoresApp.textoSuave,
    fontFamily: fonteBase,
    fontSize: 9,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: 0.8,
  );
}
