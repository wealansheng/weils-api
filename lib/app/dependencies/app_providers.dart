import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../core/platform/desktop_window.dart';
import '../../features/workspace/domain/repositories/workspace_repository.dart';
import '../../features/workspace/domain/repositories/request_gateway.dart';
import '../../features/workspace/domain/use_cases/replay_history.dart';
import '../../features/workspace/presentation/editor/view_models/request_execution_view_model.dart';
import '../../features/workspace/presentation/library/view_models/library_view_model.dart';
import '../../features/workspace/presentation/history/view_models/history_view_model.dart';
import '../../features/workspace/presentation/tabs/view_models/tabs_view_model.dart';
import '../bootstrap/bootstrap_view_model.dart';
import '../navigation/app_navigation.dart';
import 'app_dependencies.dart';
import '../../features/mock/domain/repositories/mock_server.dart';
import '../../features/mock/presentation/view_models/mock_view_model.dart';

List<SingleChildWidget> appProviders(AppDependencies dependencies) => [
  Provider<MockServer>.value(value: dependencies.mockServer),
  ChangeNotifierProvider<MockViewModel>.value(value: dependencies.mocking),
  Provider<WorkspaceRepository>.value(value: dependencies.workspace),
  Provider<RequestGateway>.value(value: dependencies.gateway),
  Provider<DesktopWindow>.value(value: dependencies.window),
  ChangeNotifierProvider<RequestExecutionViewModel>.value(
    value: dependencies.execution,
  ),
  ChangeNotifierProvider(create: (_) => AppNavigation()),
  ChangeNotifierProvider(
    create: (_) => BootstrapViewModel(dependencies.workspace),
  ),
  ChangeNotifierProvider(
    create: (_) => LibraryViewModel(dependencies.workspace),
  ),
  ChangeNotifierProvider(
    create: (_) => HistoryViewModel(
      dependencies.workspace,
      ReplayHistory(dependencies.workspace),
    ),
  ),
  ChangeNotifierProvider(create: (_) => TabsViewModel(dependencies.workspace)),
];
