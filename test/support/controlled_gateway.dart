import 'dart:async';

import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/features/workspace/domain/repositories/request_gateway.dart';

class ControlledGateway implements RequestGateway {
  final result = Completer<ResponseRecord>();
  RequestSpec? sent;
  Duration? timeout;
  int cancellations = 0;
  @override
  RequestTask<ResponseRecord> start(
    RequestSpec request, {
    required Duration timeout,
  }) {
    sent = request;
    this.timeout = timeout;
    return RequestTask(() {
      cancellations++;
      if (!result.isCompleted) result.complete(ResponseRecord(cancelled: true));
    }, result.future);
  }
}
