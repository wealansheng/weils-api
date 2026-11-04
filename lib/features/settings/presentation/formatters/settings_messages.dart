import 'package:weils_api/core/errors/app_failure.dart';

/// 将设置保存或目录迁移失败转换为对应的中文提示。
String? settingsFailureMessage(AppFailure? failure) => switch (failure?.code) {
  null => null,
  FailureCode.conflict => '所选目录已有工作区数据，请选择其他文件夹。',
  FailureCode.notFound => '所选文件夹不存在，请重新选择。',
  FailureCode.read => '请先恢复本地数据，再更改设置。',
  FailureCode.invalidData => '请填写 1–300 之间的整数',
  _ => '设置未能保存，请检查所选目录的访问权限和磁盘空间。原目录仍在使用。',
};
