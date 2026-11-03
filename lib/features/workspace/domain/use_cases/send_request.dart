import '../entities/workspace_entities.dart';
import '../repositories/request_gateway.dart';
import '../repositories/workspace_repository.dart';

class SendRequest {
  const SendRequest(this.repository, this.gateway);
  final WorkspaceRepository repository;
  final RequestGateway gateway;

  RequestTask<HistoryRecord> call(RequestSpec request) {
    final task = gateway.start(
      request,
      timeout: Duration(seconds: repository.state.snapshot.timeoutSeconds),
    );
    final time = DateTime.now();
    return RequestTask(
      task.cancel,
      task.result.then((response) async {
        final record = HistoryRecord(
          request: request,
          response: response,
          time: time,
        );
        repository.appendHistory(record);
        await repository.flush();
        return record;
      }),
    );
  }
}
