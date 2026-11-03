import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ApiMark extends StatelessWidget {
  const ApiMark({super.key, this.size = 26});
  final double size;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '{',
        style: TextStyle(
          fontFamily: 'Consolas',
          fontSize: size * 1.5,
          color: AppColors.primary,
          height: 1,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Text(
          'API',
          style: TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: size * .64,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
      Text(
        '}',
        style: TextStyle(
          fontFamily: 'Consolas',
          fontSize: size * 1.5,
          color: AppColors.primary,
          height: 1,
        ),
      ),
    ],
  );
}
