import 'package:weils_api/core/errors/app_failure.dart';

/// 将设置保存或目录迁移失败转换为对应的中文提示。
String? settingsFailureMessage(AppFailure? failure) => switch (failure?.code) {
  null => null,
  FailureCode.conflict => '所选目录的工作区无法加载，请检查 workspace.json 及备份文件。',
  FailureCode.busy => '请先停止当前请求和 Mock 服务，并等待保存完成后再切换目录。',
  FailureCode.notFound => '所选文件夹不存在，请重新选择。',
  FailureCode.read =>
    failure!.cause == null
        ? '请先恢复本地数据，再更改设置。'
        : '无法读取所选目录的 workspace.json，请检查文件是否存在及访问权限。原工作区仍在使用。',
  FailureCode.invalidData =>
    failure!.cause == null
        ? '设置值无效，请检查超时和 SSE 捕获上限。'
        : '所选目录的 workspace.json 数据无效，原工作区仍在使用。',
  _ => '设置未能保存，请检查所选目录的访问权限和磁盘空间。原目录仍在使用。',
};
