import 'package:flutter/material.dart';

import 'package:weils_api/core/theme/app_theme.dart';

/// 打开内置使用说明，介绍接口请求、SSE、历史与 Mock 等功能。
Future<void> openHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    title: const Text(
      '帮助文档',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
    content: SizedBox(
      width: 570,
      height: 410,
      child: ListView(
        children: const [
          _HelpItem(
            '新建与组织接口',
            '点击“新建 HTTP 接口”或侧栏加号创建请求。加号菜单也可新建文件夹；右键接口或文件夹可重命名、删除。搜索支持接口名称和 URL。',
          ),
          _HelpItem(
            '编辑与发送',
            '选择 HTTP 方法，填写完整的 http:// 或 https:// 地址。Params 和 Headers 使用启用勾选框；Params 中同名字段会覆盖地址里的查询参数。Body 支持 JSON 与原始文本，认证支持 Bearer Token。',
          ),
          _HelpItem(
            '保存与草稿',
            'Ctrl + S 保存当前接口。未保存内容会保留为本地草稿；关闭标签页或退出应用时，可以保存、放弃修改或取消关闭。发送请求不会自动保存接口定义。',
          ),
          _HelpItem(
            '查看响应',
            'Ctrl + Enter 发送当前请求，再次操作可取消。下方显示真实状态码、耗时、大小、正文和响应头。JSON 可格式化，非 JSON 保留原文。普通 HTTP 响应捕获上限为 2 MB，超出时明确提示截断。',
          ),
          _HelpItem(
            'SSE 流式接口',
            '在请求地址前将 HTTP 切换为 SSE，再选择实际 HTTP 方法并发送，支持 POST JSON、参数和 Bearer Token。默认补充 Accept: text/event-stream，自定义同名 Header 可覆盖。响应提供事件、拼接 data、原文和 Headers，可复制当前视图。连接建立后持续接收，点击停止或按 Ctrl + Enter 结束，已收内容保留到历史，断线不自动重连。设置中可调整捕获上限（默认 2 MB，范围 1–50 MB），达到后自动停止；请求超时仅限制收到响应头前的等待。拼接 data 不提取模型 JSON 字段，[DONE] 按普通数据展示。',
          ),
          _HelpItem(
            '从历史继续调试',
            '每次发送都会记录请求与结果，包括失败和取消。历史记录先以只读快照打开；点击“编辑并重发”生成独立草稿，原记录保持不变。',
          ),
          _HelpItem(
            '本地 Mock 服务',
            '在“Mock 管理”中新建 GET、POST、PUT 或 DELETE 接口，路径支持 /users/:id 和任意前缀的末尾通配符（如 /xxx/*、/a/b/*）。响应正文用 {{path.*}} 取得通配部分，用 {{path.id}} 取得命名参数。编辑响应场景、状态码、Headers 与延迟，保存后启用配置。服务仅监听 127.0.0.1，默认端口 3000，重启应用后需手动启动；端口占用时可更换。入站调用不会写入请求历史。',
          ),
          _HelpItem(
            'Mock 条件与模板',
            '场景按顺序匹配 Header 和 JSON Body 等值条件，所有条件须同时满足；无条件场景作为最后的默认响应。Body 字段用 JSON Pointer（例如 /user/id），条件值填写 JSON，如 1 或 "admin"。响应支持字段表生成模板和 Mock.js 常用语法，可在响应正文中打开“模板语法”查看支持范围。生成预览与每次请求相互独立。',
          ),
          _HelpItem(
            '本地使用',
            '接口、草稿、认证信息与请求历史存放在本机数据目录。设置中可以调整超时或清空历史。关闭应用不会自动清空历史。',
          ),
        ],
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('知道了'),
      ),
    ],
  ),
);

class _HelpItem extends StatelessWidget {
  const _HelpItem(this.title, this.text);
  final String title, text;
  /// 展示一条帮助主题及对应操作说明。
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.muted,
            height: 1.9,
          ),
        ),
      ],
    ),
  );
}
