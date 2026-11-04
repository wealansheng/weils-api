import 'package:flutter/material.dart';

import 'package:weils_api/core/theme/app_theme.dart';

class WorkTab extends StatelessWidget {
  const WorkTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.reorderIndex,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  final int? reorderIndex;
  /// 构建支持选中、关闭和拖拽的请求标签页。
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 3, top: 7),
    child: Material(
      color: selected ? AppColors.selection : Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (reorderIndex == null)
              _label()
            else
              ReorderableDragStartListener(
                index: reorderIndex!,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: _label(),
                ),
              ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 15),
                child: Center(child: trailing!),
              ),
          ],
        ),
      ),
    ),
  );

  /// 以固定最大宽度展示标签名称，使用省略号和选中颜色适配有限空间。
  Widget _label() => Padding(
    padding: EdgeInsets.only(left: 15, right: trailing == null ? 15 : 8),
    child: Align(
      widthFactor: 1,
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Microsoft YaHei',
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.muted,
          ),
        ),
      ),
    ),
  );
}
