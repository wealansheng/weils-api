import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SectionTabs extends StatelessWidget {
  const SectionTabs({
    super.key,
    required this.tabs,
    required this.value,
    required this.onChanged,
    this.trailing,
  });
  final List<String> tabs;
  final String value;
  final ValueChanged<String> onChanged;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        for (final tab in tabs)
          InkWell(
            onTap: () => onChanged(tab),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: value == tab
                        ? AppColors.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  fontSize: 13,
                  color: value == tab ? AppColors.primary : AppColors.muted,
                  fontWeight: value == tab ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    ),
  );
}
