import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class RailDestination {
  const RailDestination(this.icon, this.label);
  final IconData icon;
  final String label;
}

class ActivityRail extends StatelessWidget {
  const ActivityRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
  });
  final List<RailDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Container(
    width: 76,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    decoration: const BoxDecoration(
      color: AppColors.shell,
      border: Border(right: BorderSide(color: AppColors.line)),
    ),
    child: Column(
      children: [
        for (var i = 0; i < destinations.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _RailItem(
            icon: destinations[i].icon,
            label: destinations[i].label,
            selected: i == selectedIndex,
            onTap: () => onSelect(i),
          ),
        ],
      ],
    ),
  );
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
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
}
