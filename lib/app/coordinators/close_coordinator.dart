import 'package:flutter/material.dart';

import '../../core/platform/desktop_window.dart';
import '../../features/workspace/domain/entities/workspace_entities.dart';
import '../../features/workspace/domain/repositories/workspace_repository.dart';
import '../../features/workspace/presentation/editor/view_models/request_execution_view_model.dart';
import '../../shared/widgets/input_dialogs.dart';
import '../../features/mock/domain/repositories/mock_server.dart';

/// 协调关闭与退出流程；交互提示由此处处理，持久化仍通过仓库执行。
class CloseCoordinator {
  CloseCoordinator(
    this.context,
    this.repository,
    this.execution,
    this.window, [
    this.mockServer,
  ]);
  final BuildContext context;
  final WorkspaceRepository repository;
  final RequestExecutionViewModel execution;
  final DesktopWindow window;
  final MockServer? mockServer;
  bool _closing = false;
  WorkspaceSnapshot get snapshot => repository.state.snapshot;
  /// 保存指定草稿，并将仓库结果转换为关闭流程使用的成功标记。
  Future<bool> _saveDraft(RequestSpec draft) async =>
      (await repository.saveDraft(draft.id)).succeeded;
  /// 将工作区写入磁盘；退出时可仅在落盘快照中排除未保存草稿。
  Future<bool> _flush({bool discardDirtyDrafts = false}) async =>
      (await repository.flush(discardDirtyDrafts: discardDirtyDrafts))
          .succeeded;
  /// 在当前页面显示短暂的操作结果提示。
  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
  );
  /// 保存当前接口，仅在保存成功且页面仍有效时提示用户。
  Future<void> save(RequestSpec draft) async {
    if (await _saveDraft(draft) && context.mounted) _toast('接口已保存');
  }

  /// 询问未保存修改的处理方式，区分关闭单个标签页与退出整个应用。
  Future<String?> _dirtyChoice({bool window = false}) => showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        '保存未完成的修改？',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 370,
        child: Text(
          window
              ? '有 ${snapshot.drafts.where(snapshot.isDirty).length + snapshot.mockDrafts.where(snapshot.isMockDirty).length} 个接口（含 Mock）尚未保存。退出前可以保存接口，或放弃这些修改。'
              : '当前接口有未保存的修改。关闭后，放弃的内容将无法恢复。',
          style: const TextStyle(fontSize: 13, height: 1.8),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'cancel'),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'discard'),
          child: const Text('放弃修改'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'save'),
          child: Text(window ? '全部保存' : '保存'),
        ),
      ],
    ),
  );
  /// 关闭草稿前处理未保存修改；运行中的请求须先停止，保存失败则保留标签页。
  Future<void> closeDraft(RequestSpec draft) async {
    if (execution.runningId == draft.id) {
      _toast(draft.protocol == 'sse' ? '请先停止当前请求，再关闭标签页' : '请先取消当前请求，再关闭标签页');
      return;
    }
    if (snapshot.isDirty(draft)) {
      final choice = await _dirtyChoice();
      if (choice == 'cancel' || choice == null) return;
      if (choice == 'save' && !await _saveDraft(draft)) return;
    }
    repository.closeDraft(draft.id);
    await _flush();
  }

  /// 协调退出确认、请求取消、草稿保存和资源关闭，避免重复触发退出流程。
  Future<void> closeWindow() async {
    if (_closing || !context.mounted) return;
    _closing = true;
    try {
      if (!repository.state.ready) {
        await window.close();
        return;
      }
      if (execution.running &&
          !await confirmAction(
            context,
            title: '退出 Weils API？',
            detail: '当前请求仍在进行，退出将取消这次请求。',
            action: '继续退出',
          )) {
        return;
      }
      if (!context.mounted) return;
      final choice = snapshot.hasDirtyDrafts
          ? await _dirtyChoice(window: true)
          : 'save';
      if (choice == null || choice == 'cancel') return;
      await execution.stop();
      /// 根据退出选择保存接口或排除未保存草稿；失败时保留内存编辑，供重试或取消退出。
      Future<bool> persistForExit() async {
        if (choice == 'save') {
          for (final draft
              in snapshot.drafts.where(snapshot.isDirty).toList()) {
            if (!await _saveDraft(draft)) return false;
          }
          for (final draft
              in snapshot.mockDrafts.where(snapshot.isMockDirty).toList()) {
            final result = await repository.saveMock(draft.id);
            if (!result.succeeded) {
              if (context.mounted && result.failure?.cause != null) {
                _toast(result.failure!.cause.toString());
              }
              return false;
            }
          }
        }
        // 仅从落盘快照排除放弃的草稿；保存失败并取消退出时，内存编辑仍保留。
        return _flush(discardDirtyDrafts: choice == 'discard');
      }

      while (!await persistForExit()) {
        if (!context.mounted) return;
        final recovery = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              '本地数据未能保存',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            content: SizedBox(
              width: 400,
              child: Text(
                repository.state.storageBlocked
                    ? '原数据文件无法读取，已暂停写入以保留原文件。请取消退出并检查文件权限或修复数据后重启；也可以不保存当前工作区，直接退出。'
                    : '请检查磁盘空间和数据目录权限，然后重试。取消退出会保留当前编辑内容；不保存退出可能丢失尚未写入磁盘的内容。',
                style: const TextStyle(fontSize: 13, height: 1.8),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('取消退出'),
              ),
              if (!repository.state.storageBlocked)
                TextButton(
                  onPressed: () => Navigator.pop(context, 'retry'),
                  child: const Text('重试保存'),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'exit'),
                child: const Text('不保存并退出'),
              ),
            ],
          ),
        );
        if (recovery == 'exit') break;
        if (recovery != 'retry') return;
      }
      await mockServer?.stop();
      await window.close();
    } finally {
      _closing = false;
    }
  }
}
