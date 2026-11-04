import 'package:flutter/material.dart';

import 'package:weils_api/core/theme/app_theme.dart';
import 'package:weils_api/shared/widgets/input_dialogs.dart';
import 'view_models/library_view_model.dart';

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.historyMode,
    required this.library,
    required this.searchController,
    required this.onSearch,
    required this.child,
  });
  final bool historyMode;
  final LibraryViewModel library;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final Widget child;
  /// 组合接口或历史侧栏的标题、搜索输入和功能列表。
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: AppColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 16, 21),
          child: Text(
            historyMode ? '请求历史' : '接口管理',
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
                    controller: searchController,
                    onChanged: onSearch,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: historyMode ? '搜索历史记录' : '搜索接口',
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
              if (!historyMode) ...[
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
                        library.newRequest();
                      } else {
                        final name = await askName(context, title: '新建文件夹');
                        if (name != null) library.addFolder(name);
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
        Expanded(child: child),
      ],
    ),
  );
}
