import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

Color methodColor(String method) => switch (method) {
  'GET' => AppColors.green,
  'POST' => AppColors.amber,
  'DELETE' => AppColors.red,
  _ => AppColors.primary,
};
