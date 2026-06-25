import '../funcionalidades/autenticacao/estado_sessao.dart';
import '../funcionalidades/autenticacao/servico_autenticacao.dart';
import '../funcionalidades/autenticacao/servico_autenticacao_mobile.dart';
import '../nucleo/armazenamento/gerenciador_device_id.dart';
import '../nucleo/armazenamento/servico_armazenamento_seguro.dart';
import '../nucleo/arquivos/servico_upload_mobile.dart';
import '../nucleo/arquivos/servico_upload_nativo.dart';
import '../nucleo/notificacoes/servico_push_mobile.dart';
import '../nucleo/rede/cliente_api.dart';
import '../nucleo/rede/cliente_api_http.dart';
import 'configuracao_app.dart';

class DependenciasApp {
  const DependenciasApp({
    required this.configuracao,
    required this.estadoSessao,
    required this.servicoAutenticacao,
    required this.servicoPushMobile,
    required this.servicoUploadMobile,
    required this.servicoUploadNativo,
  });

  factory DependenciasApp.criarPadrao() {
    const ConfiguracaoApp configuracao = ConfiguracaoApp.padrao;
    const ServicoArmazenamentoSeguro armazenamento =
        ServicoArmazenamentoSeguroCanal();
    final ClienteApi clienteApi = ClienteApiHttp();
    final EstadoSessao estadoSessao = EstadoSessao();
    final GerenciadorDeviceId gerenciadorDeviceId = GerenciadorDeviceId(
      armazenamento: armazenamento,
    );
    final ServicoPushMobile servicoPushMobile = ServicoPushMobile(
      armazenamento: armazenamento,
      clienteApi: clienteApi,
      configuracao: configuracao,
    );

    final ServicoAutenticacao servicoAutenticacao = ServicoAutenticacaoMobile(
      armazenamento: armazenamento,
      clienteApi: clienteApi,
      configuracao: configuracao,
      estadoSessao: estadoSessao,
      gerenciadorDeviceId: gerenciadorDeviceId,
      servicoPush: servicoPushMobile,
    );

    return DependenciasApp(
      configuracao: configuracao,
      estadoSessao: estadoSessao,
      servicoAutenticacao: servicoAutenticacao,
      servicoPushMobile: servicoPushMobile,
      servicoUploadMobile: ServicoUploadMobile(
        armazenamento: armazenamento,
        clienteApi: clienteApi,
        configuracao: configuracao,
      ),
      servicoUploadNativo: const ServicoUploadNativoCanal(),
    );
  }

  final ConfiguracaoApp configuracao;
  final EstadoSessao estadoSessao;
  final ServicoAutenticacao servicoAutenticacao;
  final ServicoPushMobile servicoPushMobile;
  final ServicoUploadMobile servicoUploadMobile;
  final ServicoUploadNativo servicoUploadNativo;
}

final DependenciasApp dependenciasAppPadrao = DependenciasApp.criarPadrao();
