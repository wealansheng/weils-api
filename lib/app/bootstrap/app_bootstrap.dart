import 'dart:io';

import '../../core/network/http_transport.dart';
import '../../core/platform/desktop_window.dart';
import '../../core/platform/runtime_info.dart';
import '../../features/workspace/data/data_sources/local_workspace_source.dart';
import '../../features/workspace/data/repositories/http_request_gateway.dart';
import '../../features/workspace/data/repositories/local_workspace_repository.dart';
import '../dependencies/app_dependencies.dart';

/// 创建生产环境依赖，连接本地工作区、网络传输和桌面窗口服务。
AppDependencies createProductionDependencies() => AppDependencies(
  workspace: LocalWorkspaceRepository(
    LocalWorkspaceSource(
      directory: Directory(
        appDataDirectory('WeilsAPI', overrideVariable: 'WEILS_API_DATA_DIR'),
      ),
    ),
  ),
  gateway: HttpRequestGateway(IoHttpTransport()),
  window: MethodChannelDesktopWindow(),
);
