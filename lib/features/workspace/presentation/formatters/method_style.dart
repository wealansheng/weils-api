import 'package:flutter/material.dart';

import 'package:weils_api/core/theme/app_theme.dart';

/// 按 HTTP 方法返回统一标识颜色，用于列表与编辑器。
Color methodColor(String method) => switch (method) {
  'GET' => AppColors.green,
  'POST' => AppColors.amber,
  'DELETE' => AppColors.red,
  _ => AppColors.primary,
};
