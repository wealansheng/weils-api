import '../entities/workspace_entities.dart';
import '../repositories/request_gateway.dart';
import '../repositories/workspace_repository.dart';

class SendRequest {
  const SendRequest(this.repository, this.gateway);
  final WorkspaceRepository repository;
  final RequestGateway gateway;

  /// 固定发送时的设置并启动请求，将更新流向上传递；最终只追加一条历史并等待落盘。
  RequestTask<HistoryRecord> call(RequestSpec request) {
    final task = gateway.start(
      request,
      timeout: Duration(seconds: repository.state.snapshot.timeoutSeconds),
      sseMaxResponseMb: repository.state.snapshot.sseMaxResponseMb,
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
      updates: task.updates,
    );
  }
}
