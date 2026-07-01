import 'package:flutter/material.dart';

abstract final class CoresApp {
  static const Color fundo = Color(0xFF000000);
  static const Color superficie = Color(0xFF09090B);
  static const Color superficieElevada = Color(0xFF18181B);
  static const Color borda = Color(0xFF27272A);
  static const Color textoPrincipal = Color(0xFFFFFFFF);
  static const Color textoSecundario = Color(0xFFA1A1AA);
  static const Color textoSuave = Color(0xFF71717A);

  static const Color primaria = Color.fromARGB(255, 27, 181, 201);
  static const Color treinos = Color(0xFF3B82F6);
  static const Color dieta = Color(0xFF22C55E);
  static const Color consultas = Color(0xFFEC4899);
  static const Color fisioterapia = Color(0xFFFF74BA);
  static const Color aulas = Color(0xFFF97316);
  static const Color evolucao = Color(0xFFF97316);
  static const Color planos = Color(0xFF42F5DA);
  static const Color alunos = Color(0xFFC0C0C0);
  static const Color perfil = Color(0xFFA855F7);
  static const Color suporte = Color(0xFFEAB308);

  // Superfícies padronizadas
  static const Color card = Color(0xFF050506);
  static const Color cardElevado = Color(0xFF0B0B0D);
  static const Color campo = Color(0xFF08080A);
  static const Color bordaSuave = Color(0xFF1F1F23);
  static const Color bordaForte = Color(0xFF3F3F46);

  // Work / treino
  static const Color workPrimaria = treinos;
  static const Color workPrimariaSuave = Color(0x263B82F6);
  static const Color workPrimariaMedia = Color(0x403B82F6);
  static const Color workCampo = Color(0xFF050507);
  static const Color workCard = Color(0xFF060607);

  // Estados da série
  static const Color serieExecucao = Color(0xFFFFA726);
  static const Color serieDescanso = Color(0xFF34D399);
  static const Color serieConcluida = Color(0xFF71717A);

  // Feedbacks gerais
  static const Color sucesso = Color(0xFF34D399);
  static const Color alerta = Color(0xFFFFA726);
  static const Color erro = Color(0xFFEF4444);
}
