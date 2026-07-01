abstract final class RotasApiMobile {
  static const String login = '/api/mobile/auth/login';
  static const String sessao = '/api/mobile/auth/session';
  static const String webview = '/api/mobile/auth/webview';
  static const String logout = '/api/mobile/auth/logout';

  static const String uploadPerfil = '/api/mobile/upload/profile';
  static const String uploadRefeicao = '/api/mobile/upload/meal';
  static const String uploadFisico = '/api/mobile/upload/physical';
  static const String uploadExame = '/api/mobile/upload/exam';

  static const String pushDevice = '/api/mobile/push/device';

  static const String work = '/api/mobile/work';
  static const String workSessao = '/api/mobile/work/session';
  static const String workKcalRate = '/api/mobile/work/kcal-rate';
  static const String workConcluir = '/api/mobile/work/complete';
}
