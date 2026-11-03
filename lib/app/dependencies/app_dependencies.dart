import '../../core/platform/desktop_window.dart';
import '../../core/platform/runtime_info.dart';
import '../../features/workspace/domain/entities/response_record.dart';
import '../../features/workspace/domain/repositories/workspace_repository.dart';
import '../../features/workspace/domain/repositories/request_gateway.dart';
import '../../features/workspace/domain/use_cases/send_request.dart';
import '../../features/workspace/presentation/editor/view_models/request_execution_view_model.dart';

/// Injectable composition boundary; tests never need the user's data directory.
class AppDependencies {
  AppDependencies({
    required this.workspace,
    required this.gateway,
    required this.window,
    String? userAgent,
    Map<String, ResponseRecord> initialResponses = const {},
  }) : userAgent = userAgent ?? defaultUserAgent,
       execution = RequestExecutionViewModel(
         workspace,
         SendRequest(workspace, gateway),
         initialResponses: initialResponses,
       );
  final WorkspaceRepository workspace;
  final RequestGateway gateway;
  final DesktopWindow window;
  final String userAgent;
  final RequestExecutionViewModel execution;
  bool _disposed = false;
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    execution.dispose();
    window.dispose();
    workspace.dispose();
  }
}
