import '../entities/request_spec.dart';
import '../entities/response_record.dart';

class RequestTask<T> {
  const RequestTask(
    this.cancel,
    this.result, {
    this.updates = const Stream.empty(),
  });
  final void Function() cancel;
  final Future<T> result;
  final Stream<ResponseRecord> updates;
}

abstract interface class RequestGateway {
  /// 启动可取消请求并固定本次超时与 SSE 上限，通过更新流提供实时响应。
  RequestTask<ResponseRecord> start(
    RequestSpec request, {
    required Duration timeout,
    int sseMaxResponseMb = 2,
  });
}
