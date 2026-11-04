import 'package:weils_api/core/errors/app_failure.dart';

import '../entities/workspace_entities.dart';

import 'package:weils_api/features/mock/domain/entities/mock_definition.dart';

abstract interface class WorkspaceRepository {
  WorkspaceState get state;
  Stream<WorkspaceState> get changes;
  /// 初始化工作区，加载持久化内容并发布就绪或读取失败状态。
  Future<void> initialize();
  /// 创建并打开请求草稿，可指定所属目录。
  RequestSpec newRequest({String? folderId});
  /// 打开并选中指定请求，复用已存在的同标识草稿。
  void openRequest(RequestSpec request);
  /// 通过不可变更新函数编辑草稿，保留请求标识。
  void updateDraft(String id, RequestSpec Function(RequestSpec) update);
  /// 选择当前请求标签页，空值表示清空选中项。
  void selectTab(String? id);
  /// 调整草稿标签页的显示顺序。
  void reorderDraft(int oldIndex, int newIndex);
  /// 移除指定草稿标签页，调用方负责未保存修改与运行状态的确认。
  void closeDraft(String id);
  /// 将指定草稿保存为接口，并返回持久化结果。
  Future<Outcome<void>> saveDraft(String id);
  /// 创建接口目录并返回新目录。
  Folder addFolder(String name);
  /// 按标识重命名接口目录。
  void renameFolder(String id, String name);
  /// 按标识重命名接口，并同步其编辑草稿。
  void renameRequest(String id, String name);
  /// 删除指定接口及其打开的草稿。
  void deleteRequest(String id);
  /// 删除目录及其关联接口与草稿。
  void deleteFolder(String id);
  /// 添加一次已结束请求的历史记录。
  void appendHistory(HistoryRecord record);
  /// 清空全部请求历史，并返回持久化结果。
  Future<Outcome<void>> clearHistory();
  /// 保存超时、SSE 捕获上限以及可选数据目录，返回写入或迁移结果。
  Future<Outcome<void>> updateSettings({
    required int timeout,
    int? sseMaxResponseMb,
    String? directoryPath,
  });
  /// 立即持久化当前工作区，退出时可仅在落盘快照中排除未保存草稿。
  Future<Outcome<void>> flush({bool discardDirtyDrafts = false});
  /// 清除当前工作区通知。
  void dismissNotice();
  /// 创建并选中新的 Mock 编辑草稿。
  MockDefinition newMock();
  /// 打开并选中指定 Mock 的编辑草稿。
  void selectMock(String id);
  /// 通过不可变更新函数编辑 Mock 草稿，保留实体标识。
  void updateMockDraft(
    String id,
    MockDefinition Function(MockDefinition) update,
  );
  /// 校验并保存 Mock 草稿，成功后供服务使用。
  Future<Outcome<void>> saveMock(String id);
  /// 删除指定 Mock 及其编辑草稿，并返回保存结果。
  Future<Outcome<void>> deleteMock(String id);
  /// 校验并持久化 Mock 服务端口。
  Future<Outcome<void>> setMockPort(int port);
  /// 释放自动保存计时器与仓库状态流等资源。
  void dispose();
}
