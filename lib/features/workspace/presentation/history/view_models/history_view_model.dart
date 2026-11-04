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
  /// 进入历史页面时保留有效选中项，否则默认选择最新记录。
  void activate() {
    final next = selectedHistory?.id ?? value.firstOrNull?.id;
    if (_selectedId == next) return;
    _selectedId = next;
    notifyListeners();
  }

  /// 规范化历史搜索文本并通知列表刷新。
  void search(String query) {
    _query = query.trim().toLowerCase();
    notifyListeners();
  }

  /// 按名称和 URL 进行不区分大小写的历史请求筛选。
  bool matches(RequestSpec r) =>
      '${r.name} ${r.url}'.toLowerCase().contains(query);
  /// 更新当前选中的历史记录并通知详情刷新。
  void selectHistory(HistoryRecord record) {
    _selectedId = record.id;
    notifyListeners();
  }

  /// 将指定历史交给重发用例，打开保留原请求配置的新草稿。
  RequestSpec replaySelected(HistoryRecord record) => replay(record);
}
