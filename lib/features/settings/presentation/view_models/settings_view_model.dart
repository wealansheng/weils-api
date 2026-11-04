import 'package:flutter/foundation.dart';

import 'package:weils_api/core/errors/app_failure.dart';
import 'package:weils_api/core/platform/desktop_window.dart';
import 'package:weils_api/features/workspace/domain/repositories/workspace_repository.dart';
import 'package:weils_api/features/workspace/domain/use_cases/update_workspace_settings.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(
    this.repository,
    this.window,
    this.updateSettings, {
    this.directoryChangeBlocked,
  });
  final WorkspaceRepository repository;
  final DesktopWindow window;
  final UpdateWorkspaceSettings updateSettings;
  final bool Function()? directoryChangeBlocked;
  bool _saving = false, _choosing = false, _pickerFailed = false;
  String? _selectedDirectory;
  AppFailure? _failure;
  bool _disposed = false;
  bool get saving => _saving;
  bool get choosing => _choosing;
  bool get busy => saving || choosing;
  bool get pickerFailed => _pickerFailed;
  AppFailure? get failure => _failure;
  int get sseMaxResponseMb => repository.state.snapshot.sseMaxResponseMb;
  int get timeout => repository.state.snapshot.timeoutSeconds;
  String get directory => _selectedDirectory ?? repository.state.dataDirectory;

  /// 仅在视图模型未释放时通知设置界面刷新。
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 防止重复选择目录，保留用户选择并区分取消与选择器调用失败。
  Future<void> chooseDirectory() async {
    if (busy) return;
    _choosing = true;
    _failure = null;
    _pickerFailed = false;
    _notify();
    try {
      final path = await window.selectDirectory(directory);
      if (path != null && path.isNotEmpty) _selectedDirectory = path;
    } catch (_) {
      _pickerFailed = true;
    } finally {
      _choosing = false;
      _notify();
    }
  }

  /// 提交超时、SSE 上限和可选数据目录，记录保存结果并维护忙碌状态。
  Future<bool> save(int timeout, {int? sseMaxResponseMb}) async {
    if (busy) return false;
    if (_selectedDirectory != null &&
        _selectedDirectory != repository.state.dataDirectory &&
        directoryChangeBlocked?.call() == true) {
      _failure = const AppFailure(FailureCode.busy);
      _notify();
      return false;
    }
    _saving = true;
    _failure = null;
    _pickerFailed = false;
    _notify();
    final result = await updateSettings(
      timeout: timeout,
      sseMaxResponseMb: sseMaxResponseMb,
      directoryPath: _selectedDirectory,
    );
    _failure = result.failure;
    _saving = false;
    _notify();
    return result.succeeded;
  }

  /// 清空请求历史，并返回仓库持久化是否成功。
  Future<bool> clearHistory() async =>
      (await repository.clearHistory()).succeeded;

  /// 标记视图模型已释放，阻止未完成的异步操作继续通知界面。
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
