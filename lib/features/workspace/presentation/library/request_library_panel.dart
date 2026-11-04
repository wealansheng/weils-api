import 'package:flutter/material.dart';

import 'package:weils_api/core/theme/app_theme.dart';
import 'package:weils_api/shared/widgets/empty_message.dart';
import 'package:weils_api/shared/widgets/input_dialogs.dart';
import '../../domain/entities/workspace_entities.dart';
import '../formatters/method_style.dart';
import 'view_models/library_view_model.dart';

class RequestLibraryPanel extends StatefulWidget {
  const RequestLibraryPanel({
    super.key,
    required this.viewModel,
    this.runningId,
  });
  final LibraryViewModel viewModel;
  final String? runningId;
  /// 创建接口目录树的展开与菜单交互状态。
  @override
  State<RequestLibraryPanel> createState() => _RequestLibraryPanelState();
}

class _RequestLibraryPanelState extends State<RequestLibraryPanel> {
  final _collapsed = <String>{};
  LibraryViewModel get c => widget.viewModel;
  /// 使用接口库的搜索规则判断请求是否可见。
  bool _matches(RequestSpec r) => c.matches(r);
  /// 显示目录或接口操作的结果提示。
  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
  );
  /// 监听接口库状态，展示目录树与搜索结果。
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: c, builder: (context, _) => _tree());
  /// 构建目录及其请求列表，结合展开状态和搜索条件决定可见项。
  Widget _tree() {
    final query = c.query;
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

  /// 构建接口列表行，连接打开、选中及右键菜单操作。
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
  /// 在触发位置显示上下文菜单，并返回用户选择的操作。
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
  /// 处理目录的新建、重命名和删除菜单，删除前检查运行中请求并确认。
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
      if (widget.runningId != null &&
          c.folderContainsDraft(folder.id, widget.runningId!)) {
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

  /// 处理接口的重命名与删除菜单，删除前检查执行状态并确认。
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
      if (widget.runningId == request.id) {
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
}
