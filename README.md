# Weils API

面向个人开发者的 Flutter Windows HTTP 调试工具。使用浅色蓝灰界面，主要导航仅保留接口管理与请求历史。

## 运行与构建

需要 Flutter SDK 和包含 Desktop development with C++ 工作负载的 Visual Studio。

```powershell
flutter pub get
flutter run -d windows
flutter build windows --release
```

发布文件位于 `build/windows/x64/runner/Release/`。分发时需要保留整个目录，包括可执行文件旁的 DLL 和 `data/`，不能只复制 EXE。

## 使用

- 新建 HTTP 接口，编辑名称、所在文件夹、方法和 URL。侧栏加号也可新建文件夹，右键接口或文件夹可以重命名、删除。
- 支持 GET、POST、PUT、PATCH、DELETE、HEAD、OPTIONS；可编辑查询参数、Headers、JSON/文本 Body 和 Bearer Token。
- 下拉菜单固定从控件下方展开，选中项使用浅蓝底和勾号；请求方式、模块、Body 类型与认证方式采用统一样式，支持键盘选择、Esc 和点击外部关闭。
- Headers 中自动生成的属性和值使用灰色，自定义项使用正常颜色。Host、User-Agent、Accept-Encoding 以及适用的 Content-Type、Content-Length、Authorization 会随请求更新；启用的同名自定义项可覆盖默认值，名称不区分大小写。默认项不会被另存为自定义 Header。
- 勾选的参数参与发送；参数表中的同名键覆盖 URL 中原有的同名查询参数，禁用该键会从发送地址移除。
- `Ctrl + S` 保存接口，`Ctrl + Enter` 发送或取消当前请求，`Ctrl + N` 新建接口。
- 在 JSON/原始文本 Body 编辑器中，`Tab` 在光标处插入两个空格（有选区时替换选中文字），焦点留在编辑器中；`Shift + Tab` 仍可切换到前一个控件。
- 编辑内容自动保留为草稿，发送请求不会自动保存接口定义。关闭标签页或 Windows 窗口时提示保存、放弃或取消。
- 接口标签页可按住标签左右拖拽排序，重启后保留顺序；选中与未选中使用相同字号和字重，关闭按钮独立操作。
- 响应区展示真实状态码、耗时、捕获大小、正文和响应头。支持 JSON 格式化、原文切换与复制。
- 响应 Headers 以“名称 / 值”两列表格展示，固定表头，长内容自动换行，支持文字选择和复制全部响应头；历史快照采用相同样式。
- 历史保留当时的请求和响应，包括失败、超时和取消；编辑并重发创建独立草稿，不改写旧记录。
- 设置中可调整超时（默认 30 秒）、清空历史，并通过 Windows 目录选择器更改数据保存目录；帮助文档内置在应用中。

## 本地数据

默认目录为 `%APPDATA%\WeilsAPI`，使用 `workspace.json` 保存接口、草稿、Token、历史响应及设置。写入经过排队、临时文件落盘后替换，并保留上一份 `.bak`。损坏的 JSON 会保留为 `.corrupt-*` 文件并提示恢复情况；文件权限错误会显示保存失败，不标记接口已保存。

在“设置 → 本地数据目录 → 更改目录”中选择文件夹，点击“保存设置”后，接口、未保存草稿及历史会复制到新目录并立即切换，原目录保留。取消选择或取消设置不会更改保存位置。新目录已有 `workspace.json` 或相关备份时不会覆盖；复制或设置写入失败时继续使用原目录。所选位置记录在初始数据目录的 `settings.json` 中，重启后自动恢复；新目录不可用时会提示并暂停保存。

开发时可通过环境变量 `WEILS_API_DATA_DIR` 指定独立的初始数据与位置配置目录，该目录中的 `settings.json` 可指向设置中选择的新位置。正常启动是空工作区，不预置演示接口。

响应捕获上限为 2 MB，超出会明确提示截断。长响应的 UI 预览上限为 200,000 字符，复制仍获取完整的已捕获正文。历史不会自动清理，可在设置中手动清空。当前首版不包含表单上传、Basic Auth、账号、团队协作或云同步。

## 验证

```powershell
flutter analyze
flutter test
flutter test integration_test/windows_flow_test.dart -d windows
```

核心测试通过本地 HTTP 服务验证真实请求、编码、认证、超时、取消、响应截断、持久化、草稿恢复和历史隔离。界面测试覆盖 1440×800 / 1280×720、关闭保护、设置及帮助。Windows 集成测试使用临时数据目录验证实际桌面应用的完整流程。

代码采用 Feature-first 轻量分层和 ChangeNotifier / Provider。工作区仓储统一管理不可变数据；页面状态按接口列表、编辑器、标签、历史和设置划分。目录、依赖规则及生命周期见 [ARCHITECTURE.md](ARCHITECTURE.md)。`flutter test` 同时运行分层导入检查和 Provider 生命周期测试。

生成界面评审截图：

```powershell
flutter test --dart-define=CAPTURE_UI=true
flutter test integration_test/windows_flow_test.dart -d windows --dart-define=REVIEW_DIR=D:/wealsCode/weils_api/.impeccable/review
```

设计边界见 `PRODUCT.md`，页面方向见 `.impeccable/surfaces/lib-main-dart.md`。
