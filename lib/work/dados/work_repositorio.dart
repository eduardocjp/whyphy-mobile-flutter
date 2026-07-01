import '../../nucleo/armazenamento/servico_armazenamento_seguro.dart';
import '../../nucleo/rede/json_api.dart';
import '../models/work_modelos.dart';
import 'work_api.dart';

class WorkRepositorio {
  const WorkRepositorio({required this.armazenamento, required this.workApi});

  final ServicoArmazenamentoSeguro armazenamento;
  final WorkApi workApi;

  Future<BootstrapWorkMobile> carregarBootstrap() {
    return workApi.carregarBootstrap();
  }

  Future<SessaoWorkPayload> obterSessao() {
    return workApi.obterSessao();
  }

  Future<void> salvarCheckpoint(SnapshotSessaoWork snapshot) async {
    await armazenamento.salvar(
      chave: ChavesArmazenamentoSeguro.workSessaoAtiva,
      valor: codificarObjetoJson(snapshot.toJson()),
    );

    await workApi.salvarSessao(snapshot);
  }

  Future<SnapshotSessaoWork?> carregarCheckpointLocal() async {
    final String? salvo = await armazenamento.ler(
      ChavesArmazenamentoSeguro.workSessaoAtiva,
    );

    if (salvo == null || salvo.trim().isEmpty) {
      return null;
    }

    try {
      return SnapshotSessaoWork.fromJson(decodificarObjetoJson(salvo));
    } on FormatException {
      await limparCheckpointLocal();
      return null;
    }
  }

  Future<void> limparCheckpoint() async {
    await limparCheckpointLocal();
    await workApi.limparSessao();
  }

  Future<void> limparCheckpointLocal() async {
    await armazenamento.remover(ChavesArmazenamentoSeguro.workSessaoAtiva);
  }

  Future<TaxaKcalWork> obterTaxaKcal({
    required String workoutId,
    required String kind,
    String? exerciseId,
  }) {
    return workApi.obterTaxaKcal(
      exerciseId: exerciseId,
      kind: kind,
      workoutId: workoutId,
    );
  }

  Future<ResultadoConclusaoWork> concluir(ConclusaoWorkInput input) async {
    try {
      final ResultadoConclusaoWork resultado = await workApi.concluir(input);

      if (resultado.success) {
        await armazenamento.remover(
          ChavesArmazenamentoSeguro.workConclusaoPendente,
        );
        await limparCheckpoint();
      }

      return resultado;
    } catch (_) {
      await armazenamento.salvar(
        chave: ChavesArmazenamentoSeguro.workConclusaoPendente,
        valor: codificarObjetoJson(input.toJson()),
      );
      rethrow;
    }
  }

  Future<ResultadoConclusaoWork?> reenviarConclusaoPendente() async {
    final String? salvo = await armazenamento.ler(
      ChavesArmazenamentoSeguro.workConclusaoPendente,
    );

    if (salvo == null || salvo.trim().isEmpty) {
      return null;
    }

    final ConclusaoWorkInput input = ConclusaoWorkInput.fromJson(
      decodificarObjetoJson(salvo),
    );

    return concluir(input);
  }
}
