import '../entities/request_spec.dart';
import '../entities/response_record.dart';

class RequestTask<T> {
  const RequestTask(this.cancel, this.result);
  final void Function() cancel;
  final Future<T> result;
}

abstract interface class RequestGateway {
  RequestTask<ResponseRecord> start(
    RequestSpec request, {
    required Duration timeout,
  });
}
