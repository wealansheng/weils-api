import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SelectOption {
  const SelectOption(this.value, this.label, {this.color});

  final String value;
  final String label;
  final Color? color;
}

/// Opens below a stable trigger instead of aligning the selected menu row.
class AnchoredSelect extends StatefulWidget {
  const AnchoredSelect({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.width,
    this.menuWidth = 180,
    this.height = 32,
    this.monospace = false,
  });

  final String id, label, value;
  final List<SelectOption> options;
  final ValueChanged<String> onChanged;
  final double width, menuWidth, height;
  final bool monospace;

  @override
  State<AnchoredSelect> createState() => _AnchoredSelectState();
}

class _AnchoredSelectState extends State<AnchoredSelect> {
  final _controller = MenuController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.options
        .where((o) => o.value == widget.value)
        .firstOrNull;
    final textStyle = TextStyle(
      fontFamily: widget.monospace ? 'Consolas' : 'Microsoft YaHei',
      fontSize: widget.monospace ? 13 : 12,
      fontWeight: widget.monospace ? FontWeight.w600 : FontWeight.w400,
    );
    return MenuAnchor(
      controller: _controller,
      childFocusNode: _focusNode,
      crossAxisUnconstrained: false,
      alignmentOffset: const Offset(0, 5),
      onOpen: () => setState(() {}),
      onClose: () => setState(() {}),
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomStart,
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(
          AppColors.ink.withValues(alpha: .14),
        ),
        elevation: const WidgetStatePropertyAll(5),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(5)),
        minimumSize: WidgetStatePropertyAll(Size(widget.menuWidth, 0)),
        maximumSize: WidgetStatePropertyAll(Size(widget.menuWidth, 296)),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.line)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
      menuChildren: [
        for (final option in widget.options)
          Semantics(
            selected: option.value == widget.value,
            child: MenuItemButton(
              key: ValueKey('${widget.id}-option-${option.value}'),
              onPressed: () => widget.onChanged(option.value),
              overflowAxis: Axis.vertical,
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(0, 34)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                backgroundColor: WidgetStatePropertyAll(
                  option.value == widget.value
                      ? AppColors.selection
                      : Colors.transparent,
                ),
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.focused) ||
                      states.contains(WidgetState.hovered)) {
                    return AppColors.primary.withValues(alpha: .07);
                  }
                  return Colors.transparent;
                }),
                textStyle: WidgetStatePropertyAll(textStyle),
                foregroundColor: WidgetStatePropertyAll(
                  option.color ?? AppColors.ink,
                ),
                visualDensity: VisualDensity.standard,
              ),
              trailingIcon: Icon(
                Icons.check_rounded,
                size: 15,
                color: option.value == widget.value
                    ? AppColors.primary
                    : Colors.transparent,
              ),
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
      builder: (context, controller, child) => Semantics(
        label: widget.label,
        expanded: controller.isOpen,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: TextButton(
            key: ValueKey('${widget.id}-trigger'),
            focusNode: _focusNode,
            onPressed: widget.options.isEmpty
                ? null
                : () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10),
              ),
              minimumSize: const WidgetStatePropertyAll(Size.zero),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: WidgetStatePropertyAll(
                controller.isOpen ? AppColors.selection : Colors.transparent,
              ),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused) ||
                    states.contains(WidgetState.hovered)) {
                  return AppColors.selection;
                }
                return Colors.transparent;
              }),
              foregroundColor: WidgetStatePropertyAll(
                selected?.color ?? AppColors.ink,
              ),
              textStyle: WidgetStatePropertyAll(textStyle),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected?.label ?? '请选择',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  controller.isOpen ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: controller.isOpen
                      ? AppColors.primary
                      : AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
