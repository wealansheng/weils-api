# Weils API

面向个人开发者的 Flutter Windows HTTP 调试工具。使用浅色蓝灰界面，提供接口管理、请求历史与本地 Mock 管理。

## 运行与构建

需要 Flutter SDK 和包含 Desktop development with C++ 工作负载的 Visual Studio。

```powershell
flutter pub get
flutter run -d windows
flutter build windows --release
```

发布文件位于 `build/windows/x64/runner/Release/`。分发时需要保留整个目录，包括可执行文件旁的 DLL 和 `data/`，不能只复制 EXE。

生成文件名带版本号的 Windows 发布目录和 ZIP：

```powershell
.\tool\build_release.ps1
```

脚本读取 `pubspec.yaml` 的 `version`，执行 Windows x64 Release 构建，将完整运行文件复制到 `build/releases/weils_api-<版本号>-windows-x64/`，其中 EXE 命名为 `weils_api-<版本号>.exe`，并生成同名 ZIP。例如 `version: 1.0.1+2` 对应 `weils_api-1.0.1+2-windows-x64.zip`。解压后从完整目录启动 EXE；原始 Flutter 构建目录保持不变。重复打包同一版本时使用 `.\tool\build_release.ps1 -Force` 替换已有产物。直接运行 `flutter build windows --release` 仍只生成原始构建目录。

若开发进程遇到系统临时目录拒绝访问或本地数据保存失败，可运行 `.\tool\run_windows.ps1`，使用项目内可写目录并复制现有工作区；原数据保留，不修改系统权限。后续继续使用该脚本打开同一数据副本，细节见 [开发辅助](tool/README.md)。

VS Code 已提供 `Weils API (Windows)` 启动配置，直接点击 `lib/main.dart` 上方的 Run / Debug 或按 F5，会自动准备目录并使用同一数据副本，无需先在终端运行脚本。

## 远程 CI 与合并

推送到 `dev` 后，GitHub Actions 先执行静态分析、单元与界面测试，再执行 Windows 集成测试（含 SSE）。全部通过后自动创建或复用本仓库的 `dev → main` PR，并通过 PR 生成合并提交，保留 `dev` 分支和原有提交历史。

只允许合并本次 CI 验证的提交。运行期间 `dev` 有新提交时等待新一轮 CI；已经合入 `main` 的提交重跑不会重复创建 PR。合并冲突或分支保护要求未满足时，PR 保持开放，合并步骤报告失败。

仓库需在 **Settings → Actions → General → Workflow permissions** 勾选 **Allow GitHub Actions to create and approve pull requests**，并在 **Settings → General → Pull Requests** 启用 **Allow merge commits**。工作流使用内置 `GITHUB_TOKEN`，仅合并任务拥有代码与 PR 写权限；无需额外配置 PAT，也不依赖仓库的 Allow auto-merge 开关。CI 由 `dev` 推送触发，检查通过后立即调用 PR 合并。

## 使用

- 新建 HTTP 接口，编辑名称、所在文件夹、方法和 URL。侧栏加号也可新建文件夹，右键接口或文件夹可以重命名、删除。
- 支持 GET、POST、PUT、PATCH、DELETE、HEAD、OPTIONS；可编辑查询参数、Headers、JSON/文本 Body 和 Bearer Token。
- 下拉菜单固定从控件下方展开，选中项使用浅蓝底和勾号；请求方式、模块、Body 类型与认证方式采用统一样式，支持键盘选择、Esc 和点击外部关闭。
- Headers 中自动生成的属性和值使用灰色，自定义项使用正常颜色。Host、User-Agent、Accept-Encoding 以及适用的 Content-Type、Content-Length、Authorization 会随请求更新；启用的同名自定义项可覆盖默认值，名称不区分大小写。默认项不会被另存为自定义 Header。
- 勾选的参数参与发送；参数表中的同名键覆盖 URL 中原有的同名查询参数，禁用该键会从发送地址移除。
- `Ctrl + S` 保存接口，`Ctrl + Enter` 发送或取消当前请求，`Ctrl + N` 新建接口。
- 在 JSON/原始文本 Body 和 Mock 响应正文编辑器中，`Tab` 在光标处插入两个空格（有选区时替换选中文字），焦点留在编辑器中；`Shift + Tab` 仍可切换到前一个控件。
- 编辑内容自动保留为草稿，发送请求不会自动保存接口定义。关闭标签页或 Windows 窗口时提示保存、放弃或取消。
- 接口标签页可按住标签左右拖拽排序，重启后保留顺序；选中与未选中使用相同字号和字重，关闭按钮独立操作。
- 响应区展示真实状态码、耗时、捕获大小、正文和响应头。支持 JSON 格式化、原文切换与复制。
- 响应 Headers 以“名称 / 值”两列表格展示，固定表头，长内容自动换行，支持文字选择和复制全部响应头；历史快照采用相同样式。
- 历史保留当时的请求和响应，包括失败、超时和取消；编辑并重发创建独立草稿，不改写旧记录。
- 设置中可调整超时（默认 30 秒）、清空历史，并通过 Windows 目录选择器更改数据保存目录；帮助文档内置在应用中。

## SSE 流式请求

在请求地址前的模式菜单中选择 **SSE**，再选择实际的 HTTP 方法并发送。支持 GET、POST 等现有方法，复用 Params、Headers、JSON/文本 Body 和 Bearer Token。默认添加 `Accept: text/event-stream`，启用的同名自定义 Header 可以覆盖它。

响应区实时提供 **事件、拼接 data、原文、Headers** 四种视图，可复制当前视图。事件展示序号、event、id 和 data；拼接视图直接连接各事件的 data，不插入分隔符、不提取模型 JSON 字段。多行 data 保留换行，`[DONE]` 作为普通数据，不自动结束连接。服务器须返回 HTTP 200 和 `Content-Type: text/event-stream`；否则展示实际响应正文和 Headers，便于检查错误信息。

连接建立后持续接收，点击“停止”或按 `Ctrl + Enter` 结束；切换页面不会断开连接，关闭该标签页前须先停止。结束、停止或网络异常后，已收到的内容保留，并生成一条可回看的历史快照；从历史“编辑并重发”保留 SSE 模式。连接断开后需要手动重发，不自动重连或发送 `Last-Event-ID`。

请求超时设置仅限制 SSE 发送至收到响应头的时间，不限制已建立连接的总时长或空闲时间。“设置 → SSE 捕获上限”默认为 **2 MB**，可填写 **1–50 MB** 的整数；达到上限后停止并保留已捕获内容，末尾未完成的事件仅保留原文。修改上限只影响下次发送，普通 HTTP 仍使用 2 MB 上限。事件列表跟随底部追加，向上滚动阅读时暂停跟随；长文本仅预览最近 200,000 个字符，复制可取得完整捕获内容。

## 本地 Mock

在“Mock 管理”中新建接口，填写 GET / POST / PUT / DELETE 与路径（如 `/users/:id`），编辑响应后保存。服务只使用已保存且启用的定义；草稿自动保留，保存失败继续使用旧定义。点击“启动服务”后可通过 `http://127.0.0.1:3000` 调用，端口可调整，重启应用不会自动启动服务。服务仅供本机访问，自动提供 CORS 与 OPTIONS 预检；入站请求不写入“请求历史”。

固定路径段优先于参数段，忽略查询字符串，同方法下不允许重复路径结构。每个接口支持有序响应场景：Header 名称忽略大小写、值精确比较；Body 条件使用 JSON Pointer，如 `/user/id`，期望值填写 JSON，如 `1`、`true`、`"admin"` 或 `null`，缺失字段不等于 null。场景所有条件都满足时命中，无条件默认响应最后匹配，未匹配返回 JSON 404。响应可设置 200–599 状态码、Headers、JSON/文本与 0–300000 毫秒延迟；204/304 不返回正文。响应 Headers 使用字符串到字符串的 JSON 对象；Content-Length、Transfer-Encoding、Connection 和 CORS 控制响应头由服务管理。

末尾通配符 `/*` 适用于任意前缀，例如 `/user/*`、`/xxx/*`、`/a/b/*`，匹配并捕获后续多级路径。响应正文中的 `{{path.*}}` 会替换为捕获内容：路由 `/xxx/*` 收到 `/xxx/a/b`，正文 `{"path":"{{path.*}}"}` 返回 `{"path":"a/b"}`。命名参数 `/users/:id` 可用 `{{path.id}}` 引用，也可与末尾通配符组合。JSON 值和文本正文均支持；JSON 自动转义请求值，捕获内容不会再作为模板执行。保存时检查引用参数是否存在，预览保留占位符，实际请求时才填入。

匹配优先级为固定段、`:参数`、`*`；`*` 须独占最后一个路径段。`/user/*` 可匹配 `/user/`（捕获空字符串），不匹配缺少末尾斜线的 `/user`；`/*` 可匹配根路径 `/`。

字段表可构建常量、随机值、对象与数组模板。点击“应用模板”并确认后替换响应正文，不从任意模板反推字段表。示例：

```json
{
  "users|5-5": [
    {
      "id|+1": 1,
      "name": "@cname",
      "age": "@integer(18, 60)",
      "role": "@pick(['admin', 'user'])"
    }
  ]
}
```

支持 Mock.js 常用子集：字符串重复、数字范围及最多 12 位小数、数字/数组递增、布尔概率、对象属性抽取、数组重复或抽取；占位符为 `@integer`、`@natural`、`@float`、`@boolean`、`@string`、`@name`、`@cname`、`@email`、`@guid`、`@date`、`@time`、`@datetime` 和 `@pick`。完整占位符保留值类型，嵌入字符串则转为文本。`@name`、`@cname` 使用内置小型姓名词库；日期从 2000 年到当前时间随机选择。数组 `|1` 抽取元素，`|1-1` 保留单项数组；递增仅在本次生成中累计。生成预览与真实调用分别生成。普通字符串中的 `@单词` 也会识别为占位符。

模板须为合法 JSON，不执行 JavaScript；函数、正则生成、模板内字段引用和未列出的占位符会报错。深度最多 32 层，数组最多 1000 项，总节点最多 100000，整数范围限制 ±10¹²，请求正文、模板和生成正文均不超过 2 MB，路径替换也受同一大小限制。读取请求正文的空闲超时为 30 秒。没有局域网访问、路径参数以外的请求数据引用或复杂条件组。

## 本地数据

默认目录为 `%APPDATA%\WeilsAPI`，使用 `workspace.json` 保存接口、草稿、Token、历史响应及设置。写入经过排队、临时文件落盘后替换，并保留上一份 `.bak`。损坏的 JSON 会保留为 `.corrupt-*` 文件并提示恢复情况；文件权限错误会显示保存失败，不标记接口已保存。

在“设置 → 本地数据目录 → 更改目录”中选择文件夹，点击“保存设置”后，接口、未保存草稿及历史会复制到新目录并立即切换，原目录保留。取消选择或取消设置不会更改保存位置。新目录已有 `workspace.json` 或相关备份时不会覆盖；复制或设置写入失败时继续使用原目录。所选位置记录在初始数据目录的 `settings.json` 中，重启后自动恢复；新目录不可用时会提示并暂停保存。

开发时可通过环境变量 `WEILS_API_DATA_DIR` 指定独立的初始数据与位置配置目录，该目录中的 `settings.json` 可指向设置中选择的新位置。正常启动是空工作区，不预置演示接口。

普通 HTTP 响应捕获上限为 2 MB，SSE 使用设置中的捕获上限，超出会明确提示截断。长响应的 UI 预览上限为 200,000 字符，复制仍获取完整的已捕获正文。历史不会自动清理，可在设置中手动清空。当前首版不包含表单上传、Basic Auth、账号、团队协作或云同步。

## 验证

```powershell
flutter analyze
flutter test
flutter test integration_test/windows_flow_test.dart -d windows
flutter test integration_test/mock_windows_flow_test.dart -d windows
flutter test integration_test/sse_windows_flow_test.dart -d windows
```

核心测试通过本地 HTTP 服务验证真实请求、编码、认证、超时、取消、响应截断、持久化、草稿恢复和历史隔离。界面测试覆盖 1440×800 / 1280×720、关闭保护、设置及帮助。Windows 集成测试使用临时数据目录验证实际桌面应用的完整流程。

代码采用 Feature-first 轻量分层和 ChangeNotifier / Provider。工作区仓储统一管理不可变数据；页面状态按接口列表、编辑器、标签、历史和设置划分。目录、依赖规则及生命周期见 [ARCHITECTURE.md](ARCHITECTURE.md)。`flutter test` 同时运行分层导入检查和 Provider 生命周期测试。

生成界面评审截图：

```powershell
flutter test --dart-define=CAPTURE_UI=true
flutter test integration_test/windows_flow_test.dart -d windows --dart-define=REVIEW_DIR=D:/wealsCode/weils_api/.impeccable/review
```

设计边界见 `PRODUCT.md`，页面方向见 `.impeccable/surfaces/lib-main-dart.md`。
