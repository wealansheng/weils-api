import '../../../../core/utils/identity.dart';
import 'request_spec.dart';
import 'response_record.dart';

class HistoryRecord {
  HistoryRecord({
    String? id,
    required this.request,
    required this.response,
    DateTime? time,
  }) : id = id ?? newId(),
       time = time ?? DateTime.now();
  final String id;
  final RequestSpec request;
  final ResponseRecord response;
  final DateTime time;
}
