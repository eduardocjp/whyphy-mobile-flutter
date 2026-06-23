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
}
