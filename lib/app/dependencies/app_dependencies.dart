import '../../core/platform/desktop_window.dart';
import '../../core/platform/runtime_info.dart';
import '../../features/workspace/domain/entities/response_record.dart';
import '../../features/workspace/domain/repositories/workspace_repository.dart';
import '../../features/workspace/domain/repositories/request_gateway.dart';
import '../../features/workspace/domain/use_cases/send_request.dart';
import '../../features/workspace/presentation/editor/view_models/request_execution_view_model.dart';
import '../../features/mock/data/io_mock_server.dart';
import '../../features/mock/domain/repositories/mock_server.dart';
import '../../features/mock/presentation/view_models/mock_view_model.dart';

/// Injectable composition boundary; tests never need the user's data directory.
class AppDependencies {
  AppDependencies({
    required this.workspace,
    required this.gateway,
    required this.window,
    String? userAgent,
    Map<String, ResponseRecord> initialResponses = const {},
    MockServer? mockServer,
  }) : userAgent = userAgent ?? defaultUserAgent,
       execution = RequestExecutionViewModel(
         workspace,
         SendRequest(workspace, gateway),
         initialResponses: initialResponses,
       ) {
    this.mockServer = mockServer ?? IoMockServer();
    mocking = MockViewModel(workspace, this.mockServer);
  }
  final WorkspaceRepository workspace;
  final RequestGateway gateway;
  final DesktopWindow window;
  final String userAgent;
  final RequestExecutionViewModel execution;
  late final MockServer mockServer;
  late final MockViewModel mocking;
  bool _disposed = false;
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    execution.dispose();
    mocking.dispose();
    mockServer.dispose();
    window.dispose();
    workspace.dispose();
  }
}
