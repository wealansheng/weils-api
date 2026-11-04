import 'package:flutter/material.dart';

import 'package:weils_api/core/theme/app_theme.dart';
import '../../domain/entities/request_spec.dart';
import 'view_models/tabs_view_model.dart';
import 'widgets/work_tab.dart';

class WorkspaceTabs extends StatelessWidget {
  const WorkspaceTabs({
    super.key,
    required this.viewModel,
    required this.onClose,
  });
  final TabsViewModel viewModel;
  final ValueChanged<RequestSpec> onClose;
  TabsViewModel get c => viewModel;
  /// 展示可重排的请求标签页，将选中、拖拽和关闭事件传给对应流程。
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: ReorderableListView.builder(
        key: const ValueKey('request-tabs'),
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        onReorderItem: c.reorderDraft,
        proxyDecorator: (child, index, animation) => Material(
          type: MaterialType.transparency,
          child: MouseRegion(cursor: SystemMouseCursors.grabbing, child: child),
        ),
        header: WorkTab(
          label: '概览',
          selected: c.activeId == null,
          onTap: () => c.selectTab(null),
        ),
        itemCount: c.drafts.length,
        itemBuilder: (context, index) {
          final draft = c.drafts[index];
          return WorkTab(
            key: ValueKey('request-tab-${draft.id}'),
            label: draft.name.isEmpty ? '未命名接口' : draft.name,
            selected: c.activeId == draft.id,
            reorderIndex: index,
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
                    onPressed: () => onClose(draft),
                    icon: const Icon(Icons.close, size: 13),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
