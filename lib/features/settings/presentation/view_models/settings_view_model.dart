import 'package:flutter/foundation.dart';

import 'package:weils_api/core/errors/app_failure.dart';
import 'package:weils_api/core/platform/desktop_window.dart';
import 'package:weils_api/features/workspace/domain/repositories/workspace_repository.dart';
import 'package:weils_api/features/workspace/domain/use_cases/update_workspace_settings.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this.repository, this.window, this.updateSettings);
  final WorkspaceRepository repository;
  final DesktopWindow window;
  final UpdateWorkspaceSettings updateSettings;
  bool _saving = false, _choosing = false, _pickerFailed = false;
  String? _selectedDirectory;
  AppFailure? _failure;
  bool _disposed = false;
  bool get saving => _saving;
  bool get choosing => _choosing;
  bool get busy => saving || choosing;
  bool get pickerFailed => _pickerFailed;
  AppFailure? get failure => _failure;
  int get timeout => repository.state.snapshot.timeoutSeconds;
  String get directory => _selectedDirectory ?? repository.state.dataDirectory;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

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

  Future<bool> save(int timeout) async {
    if (busy) return false;
    _saving = true;
    _failure = null;
    _pickerFailed = false;
    _notify();
    final result = await updateSettings(
      timeout: timeout,
      directoryPath: _selectedDirectory,
    );
    _failure = result.failure;
    _saving = false;
    _notify();
    return result.succeeded;
  }

  Future<bool> clearHistory() async =>
      (await repository.clearHistory()).succeeded;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
