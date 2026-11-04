import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/platform/desktop_window.dart';
import '../../features/help/presentation/help_dialog.dart';
import '../../features/settings/presentation/settings_dialog.dart';
import '../../features/settings/presentation/view_models/settings_view_model.dart';
import '../../features/workspace/domain/repositories/workspace_repository.dart';
import '../../features/workspace/domain/use_cases/update_workspace_settings.dart';
import '../../features/workspace/presentation/editor/request_editor.dart';
import '../../features/workspace/presentation/editor/view_models/request_editor_view_model.dart';
import '../../features/workspace/presentation/editor/view_models/request_execution_view_model.dart';
import '../../features/workspace/presentation/history/history_list_panel.dart';
import '../../features/workspace/presentation/history/history_workspace.dart';
import '../../features/workspace/presentation/history/view_models/history_view_model.dart';
import '../../features/workspace/presentation/library/workspace_home.dart';
import '../../features/workspace/presentation/library/curl_import_dialog.dart';
import '../../features/workspace/presentation/library/workspace_sidebar.dart';
import '../../features/workspace/presentation/library/request_library_panel.dart';
import '../../features/workspace/presentation/library/view_models/library_view_model.dart';
import '../../features/workspace/presentation/tabs/workspace_tabs.dart';
import '../../features/workspace/presentation/tabs/view_models/tabs_view_model.dart';
import '../../features/workspace/presentation/formatters/workspace_messages.dart';
import '../../layout/app_shell.dart';
import '../../layout/activity_rail.dart';
import '../../layout/desktop_header.dart';
import '../../layout/desktop_footer.dart';
import '../../shared/widgets/notice_banner.dart';
import '../bootstrap/bootstrap_view_model.dart';
import '../coordinators/close_coordinator.dart';
import 'app_navigation.dart';
import '../../features/mock/domain/repositories/mock_server.dart';
import '../../features/mock/presentation/mock_sidebar.dart';
import '../../features/mock/presentation/mock_workspace.dart';
import '../../features/mock/presentation/view_models/mock_view_model.dart';

/// 负责页面组合与导航，具体功能的展示逻辑由对应页面维护。
class WorkspaceRoot extends StatefulWidget {
  const WorkspaceRoot({super.key, required this.userAgent});
  final String userAgent;

  /// 创建工作区导航、搜索和窗口关闭协调所需的局部状态。
  @override
  State<WorkspaceRoot> createState() => _WorkspaceRootState();
}

class _WorkspaceRootState extends State<WorkspaceRoot> {
  final _search = TextEditingController();
  late final CloseCoordinator _close;
  late final StreamSubscription<void> _closeSubscription;
  WorkspaceRepository get repository => context.read<WorkspaceRepository>();
  RequestExecutionViewModel get execution =>
      context.read<RequestExecutionViewModel>();

  /// 注册原生窗口关闭监听，并连接退出协调器与应用级服务。
  @override
  void initState() {
    super.initState();
    final window = context.read<DesktopWindow>();
    _close = CloseCoordinator(
      context,
      repository,
      execution,
      window,
      context.read<MockServer>(),
    );
    _closeSubscription = window.closeRequests.listen((_) {
      if (mounted) unawaited(_close.closeWindow());
    });
  }

  /// 取消窗口事件订阅并释放搜索输入控制器。
  @override
  void dispose() {
    unawaited(_closeSubscription.cancel());
    _search.dispose();
    super.dispose();
  }

  /// 切换接口管理或历史页面，同时清除搜索条件并恢复历史选中项。
  void _navigate(bool history) {
    _search.clear();
    context.read<LibraryViewModel>().search('');
    context.read<HistoryViewModel>().search('');
    if (history) context.read<HistoryViewModel>().activate();
    context.read<AppNavigation>().select(
      history ? AppDestination.history : AppDestination.workspace,
    );
  }

  /// 根据当前页面新建普通请求或 Mock，并将普通请求切回编辑页面。
  void _newRequest() {
    if (context.read<AppNavigation>().destination == AppDestination.mock) {
      context.read<MockViewModel>().create();
      return;
    }
    repository.newRequest();
    _navigate(false);
  }

  /// 将导入结果作为独立草稿打开，保留已打开接口及其编辑内容。
  Future<void> _importCurl() async {
    final request = await openCurlImportDialog(
      context,
      folderId: repository.state.snapshot.folders.first.id,
    );
    if (!mounted || request == null) return;
    repository.openRequest(request);
    _navigate(false);
  }

  /// 将保存操作转发给当前页面的接口或 Mock 保存流程。
  void _save() {
    if (context.read<AppNavigation>().destination == AppDestination.mock) {
      unawaited(context.read<MockViewModel>().save());
      return;
    }
    final active = repository.state.snapshot.active;
    if (active != null) unawaited(_close.save(active));
  }

  /// 当前标签页正在执行时取消请求，否则尝试发送当前草稿。
  void _sendOrCancel() {
    final active = repository.state.snapshot.active;
    if (active == null) return;
    if (execution.runningId == active.id) {
      execution.cancel();
    } else {
      unawaited(execution.send(active));
    }
  }

  /// 组合桌面布局、功能页面和全局快捷键，并按当前导航与工作区状态刷新。
  @override
  Widget build(BuildContext context) {
    final destination = context.watch<AppNavigation>().destination;
    final historyMode = destination == AppDestination.history;
    final mockMode = destination == AppDestination.mock;
    final activeId = context.select<TabsViewModel, String?>(
      (vm) => vm.activeId,
    );
    final runningId = context.select<RequestExecutionViewModel, String?>(
      (vm) => vm.runningId,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (!historyMode) _save();
        },
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (destination == AppDestination.workspace) _sendOrCancel();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _newRequest,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Consumer<BootstrapViewModel>(
            builder: (context, bootstrap, _) {
              if (!bootstrap.ready) {
                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final library = context.read<LibraryViewModel>();
              final history = context.read<HistoryViewModel>();
              final notice = workspaceNoticeMessage(bootstrap.notice);
              return AppShell(
                key: ValueKey(bootstrap.workspaceRevision),
                header: DesktopHeader(
                  onSettings: () => openSettings(
                    context,
                    () => SettingsViewModel(
                      repository,
                      context.read<DesktopWindow>(),
                      UpdateWorkspaceSettings(repository),
                      directoryChangeBlocked: () {
                        final mock = context.read<MockViewModel>();
                        return execution.running || mock.running || mock.busy;
                      },
                    ),
                  ),
                ),
                rail: ActivityRail(
                  destinations: const [
                    RailDestination(Icons.layers_outlined, '接口管理'),
                    RailDestination(Icons.history_rounded, '请求历史'),
                    RailDestination(Icons.dns_outlined, 'Mock 管理'),
                  ],
                  selectedIndex: destination.index,
                  onSelect: (index) {
                    if (index == 2) {
                      context.read<AppNavigation>().select(AppDestination.mock);
                    } else {
                      _navigate(index == 1);
                    }
                  },
                ),
                sidebar: mockMode
                    ? MockSidebar(viewModel: context.read<MockViewModel>())
                    : WorkspaceSidebar(
                        historyMode: historyMode,
                        onImportCurl: _importCurl,
                        library: library,
                        searchController: _search,
                        onSearch: historyMode ? history.search : library.search,
                        child: historyMode
                            ? HistoryListPanel(viewModel: history)
                            : RequestLibraryPanel(
                                viewModel: library,
                                runningId: runningId,
                              ),
                      ),
                body: mockMode
                    ? MockWorkspace(viewModel: context.read<MockViewModel>())
                    : historyMode
                    ? HistoryWorkspace(
                        viewModel: history,
                        onLeave: () => _navigate(false),
                        onReplay: (record) {
                          history.replaySelected(record);
                          _navigate(false);
                        },
                      )
                    : Column(
                        children: [
                          WorkspaceTabs(
                            viewModel: context.read<TabsViewModel>(),
                            onClose: (draft) => _close.closeDraft(draft),
                          ),
                          Expanded(
                            child: activeId == null
                                ? WorkspaceHome(
                                    onCreate: _newRequest,
                                    onImportCurl: _importCurl,
                                  )
                                : ChangeNotifierProvider(
                                    key: ValueKey(activeId),
                                    create: (_) => RequestEditorViewModel(
                                      repository,
                                      activeId,
                                      widget.userAgent,
                                    ),
                                    child: Builder(
                                      builder: (context) => RequestEditor(
                                        viewModel: context
                                            .read<RequestEditorViewModel>(),
                                        execution: execution,
                                        onSave: _save,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                footer: DesktopFooter(onHelp: () => openHelp(context)),
                notice: notice == null
                    ? null
                    : NoticeBanner(
                        message: notice,
                        onDismiss: bootstrap.storageBlocked
                            ? null
                            : bootstrap.dismissNotice,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}
