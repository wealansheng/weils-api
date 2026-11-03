import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/workspace_controller.dart';
import 'common.dart';
import 'dialogs.dart';
import 'history_detail.dart';
import 'request_editor.dart';
import 'theme.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  static const _window = MethodChannel('weils/window');
  final _search = TextEditingController();
  final _collapsed = <String>{};
  bool _closing = false;
  WorkspaceController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    _window.setMethodCallHandler((call) async {
      if (call.method == 'closeRequested') await _closeWindow();
    });
  }

  @override
  void dispose() {
    _window.setMethodCallHandler(null);
    _search.dispose();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
  );
  Future<void> _save(RequestSpec draft) async {
    if (await c.save(draft) && mounted) _toast('接口已保存');
  }

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
              ? '有 ${c.drafts.where(c.isDirty).length} 个接口尚未保存。退出前可以保存接口，或放弃这些修改。'
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
  Future<void> _closeDraft(RequestSpec draft) async {
    if (c.runningId == draft.id) {
      _toast('请先取消当前请求，再关闭标签页');
      return;
    }
    if (c.isDirty(draft)) {
      final choice = await _dirtyChoice();
      if (choice == 'cancel' || choice == null) return;
      if (choice == 'save' && !await c.save(draft)) return;
    }
    c.closeDraft(draft.id);
    await c.flush();
  }

  Future<void> _closeWindow() async {
    if (_closing || !mounted) return;
    _closing = true;
    try {
      if (!c.ready) {
        await _window.invokeMethod<void>('close');
        return;
      }
      if (c.running &&
          !await confirmAction(
            context,
            title: '退出 Weils API？',
            detail: '当前请求仍在进行，退出将取消这次请求。',
            action: '继续退出',
          )) {
        return;
      }
      if (!mounted) return;
      final choice = c.hasDirtyDrafts
          ? await _dirtyChoice(window: true)
          : 'save';
      if (choice == null || choice == 'cancel') return;
      await c.stop();
      Future<bool> persistForExit() async {
        if (choice == 'save') {
          for (final draft in c.drafts.where(c.isDirty).toList()) {
            if (!await c.save(draft)) return false;
          }
        }
        // Apply discard to the persisted snapshot only. If persistence fails
        // and the user cancels exit, their live edits remain available.
        return c.flush(discardDirtyDrafts: choice == 'discard');
      }

      while (!await persistForExit()) {
        if (!mounted) return;
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
                c.storageBlocked
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
              if (!c.storageBlocked)
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
      await _window.invokeMethod<void>('close');
    } finally {
      _closing = false;
    }
  }

  void _navigate(bool history) {
    _search.clear();
    if (history) {
      c.showHistory();
    } else {
      c.historyMode = false;
      c.changed();
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
        if (!c.historyMode && c.active != null) _save(c.active!);
      },
      const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
        if (!c.historyMode && c.active != null) {
          if (c.runningId == c.activeId) {
            c.cancel();
          } else {
            c.send(c.active!);
          }
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
        c.newRequest();
      },
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: c,
          builder: (context, _) => c.ready
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final width = math.max(constraints.maxWidth, 1000.0),
                        height = math.max(constraints.maxHeight, 600.0);
                    final content = SizedBox(
                      width: width,
                      height: height,
                      child: Column(
                        children: [
                          _header(),
                          if (c.notice != null)
                            Container(
                              color: const Color(0xFFFFF6E6),
                              padding: const EdgeInsets.fromLTRB(16, 7, 8, 7),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: AppColors.amber,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      c.notice!,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  if (!c.storageBlocked)
                                    IconButton(
                                      tooltip: '关闭提示',
                                      onPressed: () {
                                        c.notice = null;
                                        c.changed();
                                      },
                                      icon: const Icon(Icons.close, size: 15),
                                    ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _rail(),
                                SizedBox(
                                  width: width >= 1400 ? 270 : 250,
                                  child: _sidebar(),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Expanded(child: _workspace()),
                                      _footer(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                    if (width == constraints.maxWidth &&
                        height == constraints.maxHeight) {
                      return content;
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(child: content),
                    );
                  },
                )
              : const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
        ),
      ),
    ),
  );

  Widget _header() => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: const BoxDecoration(
      color: AppColors.shell,
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        const ApiMark(size: 19),
        const SizedBox(width: 12),
        const Text(
          'Weils API',
          style: TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          width: 1,
          height: 17,
          margin: const EdgeInsets.symmetric(horizontal: 21),
          color: AppColors.line,
        ),
        const Text(
          '本地工作区',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => openSettings(context, c),
          icon: const Icon(Icons.settings_outlined, size: 18),
          style: TextButton.styleFrom(foregroundColor: AppColors.ink),
          label: const Text('设置'),
        ),
      ],
    ),
  );
  Widget _rail() => Container(
    width: 76,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    decoration: const BoxDecoration(
      color: AppColors.shell,
      border: Border(right: BorderSide(color: AppColors.line)),
    ),
    child: Column(
      children: [
        _navItem(
          Icons.layers_outlined,
          '接口管理',
          !c.historyMode,
          () => _navigate(false),
        ),
        const SizedBox(height: 12),
        _navItem(
          Icons.history_rounded,
          '请求历史',
          c.historyMode,
          () => _navigate(true),
        ),
      ],
    ),
  );
  Widget _navItem(
    IconData icon,
    String label,
    bool selected,
    VoidCallback onTap,
  ) => Material(
    color: selected ? AppColors.selection : Colors.transparent,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 67,
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 23,
              color: selected ? AppColors.primary : AppColors.muted,
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? AppColors.primary : AppColors.muted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _sidebar() => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: AppColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 16, 21),
          child: Text(
            c.historyMode ? '请求历史' : '接口管理',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: c.historyMode ? '搜索历史记录' : '搜索接口',
                      prefixIcon: const Icon(Icons.search, size: 17),
                      prefixIconConstraints: const BoxConstraints(minWidth: 32),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 9,
                        horizontal: 8,
                      ),
                    ),
                  ),
                ),
              ),
              if (!c.historyMode) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: PopupMenuButton<String>(
                    tooltip: '新建接口或文件夹',
                    padding: EdgeInsets.zero,
                    position: PopupMenuPosition.under,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 21),
                    onSelected: (value) async {
                      if (value == 'request') {
                        c.newRequest();
                      } else {
                        final name = await askName(context, title: '新建文件夹');
                        if (name != null) c.addFolder(name);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'request',
                        child: Text('新建 HTTP 接口'),
                      ),
                      PopupMenuItem(value: 'folder', child: Text('新建文件夹')),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(child: c.historyMode ? _historyList() : _requestTree()),
      ],
    ),
  );
  bool _matches(RequestSpec r) => '${r.name} ${r.url}'.toLowerCase().contains(
    _search.text.trim().toLowerCase(),
  );
  Widget _requestTree() {
    final query = _search.text.trim().toLowerCase();
    final visible = c.folders
        .where(
          (f) =>
              query.isEmpty ||
              f.name.toLowerCase().contains(query) ||
              c.requests.any((r) => r.folderId == f.id && _matches(r)),
        )
        .toList();
    if (visible.isEmpty) {
      return const EmptyMessage(
        icon: Icons.search_off,
        title: '没有匹配的接口',
        subtitle: '试试其他名称或 URL',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final folder = visible[index];
        final open = query.isNotEmpty || !_collapsed.contains(folder.id);
        final children = c.requests
            .where(
              (r) =>
                  r.folderId == folder.id &&
                  (folder.name.toLowerCase().contains(query) || _matches(r)),
            )
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onSecondaryTapDown: (details) =>
                  _folderMenu(folder, details.globalPosition),
              child: InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: () => setState(() {
                  if (open) {
                    _collapsed.add(folder.id);
                  } else {
                    _collapsed.remove(folder.id);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        open
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 16,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.folder_outlined,
                        size: 17,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          folder.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (open) ...[
              for (final request in children) _requestRow(request),
              if (query.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(23, 5, 6, 12),
                  child: InkWell(
                    onTap: () => c.newRequest(folderId: folder.id),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      height: 31,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 14, color: AppColors.muted),
                          SizedBox(width: 7),
                          Text(
                            '新建接口',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _requestRow(RequestSpec request) => Padding(
    padding: const EdgeInsets.only(left: 23, bottom: 3),
    child: GestureDetector(
      onSecondaryTapDown: (details) =>
          _requestMenu(request, details.globalPosition),
      child: Material(
        color: c.activeId == request.id
            ? AppColors.selection
            : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: () => c.open(request),
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 43,
                  child: Text(
                    request.method,
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: methodColor(request.method),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    request.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Future<String?> _contextMenu(
    Offset position,
    List<PopupMenuEntry<String>> items,
  ) => showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    ),
    items: items,
  );
  Future<void> _folderMenu(Folder folder, Offset position) async {
    final action = await _contextMenu(position, const [
      PopupMenuItem(value: 'new', child: Text('新建接口')),
      PopupMenuItem(value: 'rename', child: Text('重命名')),
      PopupMenuItem(value: 'delete', child: Text('删除文件夹')),
    ]);
    if (!mounted) return;
    if (action == 'new') c.newRequest(folderId: folder.id);
    if (action == 'rename') {
      final name = await askName(
        context,
        title: '重命名文件夹',
        initial: folder.name,
      );
      if (name != null) c.renameFolder(folder, name);
      return;
    }
    if (action == 'delete') {
      if (c.running &&
          c.drafts.any((r) => r.id == c.runningId && r.folderId == folder.id)) {
        _toast('请先取消文件夹中的请求');
        return;
      }
      if (await confirmAction(
        context,
        title: '删除“${folder.name}”？',
        detail: '文件夹中的接口与草稿也会删除，请求历史会保留。此操作无法撤销。',
      )) {
        c.deleteFolder(folder);
      }
    }
  }

  Future<void> _requestMenu(RequestSpec request, Offset position) async {
    final action = await _contextMenu(position, const [
      PopupMenuItem(value: 'rename', child: Text('重命名')),
      PopupMenuItem(value: 'delete', child: Text('删除接口')),
    ]);
    if (!mounted) return;
    if (action == 'rename') {
      final name = await askName(
        context,
        title: '重命名接口',
        initial: request.name,
      );
      if (name != null) c.renameRequest(request, name);
      return;
    }
    if (action == 'delete') {
      if (c.runningId == request.id) {
        _toast('请先取消当前请求');
        return;
      }
      if (await confirmAction(
        context,
        title: '删除“${request.name}”？',
        detail: '接口及其未保存修改会被删除，请求历史会保留。',
      )) {
        c.deleteRequest(request.id);
      }
    }
  }

  Widget _historyList() {
    final records = c.history.where((h) => _matches(h.request)).toList();
    if (records.isEmpty) {
      return EmptyMessage(
        icon: c.history.isEmpty ? Icons.history_rounded : Icons.search_off,
        title: c.history.isEmpty ? '还没有请求历史' : '没有匹配的记录',
        subtitle: c.history.isEmpty ? '发送一次请求后会自动记录' : '试试其他名称或 URL',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final h = records[index];
        final showDate =
            index == 0 ||
            dateLabel(records[index - 1].time) != dateLabel(h.time);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 9),
                child: Text(
                  dateLabel(h.time),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            Material(
              color: c.selectedHistoryId == h.id
                  ? AppColors.selection
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => c.selectHistory(h),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            h.request.method,
                            style: TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 10,
                              color: methodColor(h.request.method),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              h.request.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        h.request.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Text(
                            clockLabel(h.time),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            h.response.statusCode?.toString() ??
                                (h.response.cancelled ? '已取消' : '失败'),
                            style: TextStyle(
                              fontSize: 10,
                              color: h.response.success
                                  ? AppColors.green
                                  : h.response.cancelled
                                  ? AppColors.muted
                                  : AppColors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _workspace() {
    if (c.historyMode) {
      final record = c.selectedHistory;
      return record == null
          ? EmptyMessage(
              icon: Icons.history_rounded,
              title: '从历史中继续调试',
              subtitle: '选中一条记录查看请求与响应快照，或先发送一个请求。',
              action: TextButton(
                onPressed: () => _navigate(false),
                child: const Text('前往接口管理'),
              ),
            )
          : HistoryDetail(
              key: ValueKey(record.id),
              record: record,
              onReplay: () {
                c.replay(record);
                _search.clear();
              },
            );
    }
    return Column(
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              WorkTab(
                label: '概览',
                selected: c.activeId == null,
                onTap: () => c.selectTab(null),
              ),
              for (final draft in c.drafts)
                WorkTab(
                  label: draft.name.isEmpty ? '未命名接口' : draft.name,
                  selected: c.activeId == draft.id,
                  onTap: () => c.selectTab(draft.id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.isDirty(draft))
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      SizedBox(
                        width: 21,
                        height: 25,
                        child: IconButton(
                          tooltip: '关闭标签页',
                          padding: EdgeInsets.zero,
                          onPressed: () => _closeDraft(draft),
                          icon: const Icon(Icons.close, size: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: c.active == null
              ? _home()
              : RequestEditor(
                  key: ValueKey(c.active!.id),
                  controller: c,
                  request: c.active!,
                  onSave: () => _save(c.active!),
                ),
        ),
      ],
    );
  }

  Widget _home() => Center(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ApiMark(size: 42),
          const SizedBox(height: 27),
          const Text(
            '从一个接口开始',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '创建你的第一个接口，开始调试',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 31),
          SizedBox(
            height: 39,
            child: FilledButton.icon(
              key: const ValueKey('create-request'),
              onPressed: () => c.newRequest(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建 HTTP 接口'),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _footer() => Container(
    height: 33,
    padding: const EdgeInsets.only(right: 15),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: () => openHelp(context),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            minimumSize: const Size(0, 28),
          ),
          icon: const Icon(Icons.menu_book_outlined, size: 16),
          label: const Text('帮助文档', style: TextStyle(fontSize: 11)),
        ),
      ],
    ),
  );
}
