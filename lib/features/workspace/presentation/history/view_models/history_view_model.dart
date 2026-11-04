import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/features/workspace/domain/repositories/workspace_repository.dart';
import 'package:weils_api/features/workspace/domain/use_cases/replay_history.dart';
import '../../view_models/repository_view_model.dart';

class HistoryViewModel extends RepositoryViewModel<List<HistoryRecord>> {
  HistoryViewModel(WorkspaceRepository repository, this.replay)
    : super(repository, (s) => s.snapshot.history);
  final ReplayHistory replay;
  String? _selectedId;
  String _query = '';
  List<HistoryRecord> get history => value;
  String get query => _query;
  String? get selectedHistoryId => selectedHistory?.id;
  HistoryRecord? get selectedHistory =>
      value.where((h) => h.id == _selectedId).firstOrNull;
  void activate() {
    final next = selectedHistory?.id ?? value.firstOrNull?.id;
    if (_selectedId == next) return;
    _selectedId = next;
    notifyListeners();
  }

  void search(String query) {
    _query = query.trim().toLowerCase();
    notifyListeners();
  }

  bool matches(RequestSpec r) =>
      '${r.name} ${r.url}'.toLowerCase().contains(query);
  void selectHistory(HistoryRecord record) {
    _selectedId = record.id;
    notifyListeners();
  }

  RequestSpec replaySelected(HistoryRecord record) => replay(record);
}
