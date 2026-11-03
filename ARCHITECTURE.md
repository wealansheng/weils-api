# 代码架构

本项目采用 Feature-first 轻量分层，使用 ChangeNotifier / Provider 管理展示状态。目录按职责拆分，不要求每个功能都建立三层，也不为简单操作增加用例包装。

## 目录与依赖

```text
lib/
  main.dart                          Flutter 初始化、runApp
  app.dart                           MaterialApp、应用根生命周期
  app/
    bootstrap/                       生产依赖创建、启动状态
    dependencies/                    Provider 注册、依赖所有权
    navigation/                      桌面导航状态、具体页面组合
    coordinators/                    保存、关闭标签、窗口退出流程
  core/
    errors/                          失败类型、操作结果
    network/                         HTTP 传输、取消、超时与捕获上限
    storage/                         原子文件写入
    platform/                        桌面窗口、目录选择、运行环境
    theme/                           主题与通用样式
    utils/                           标识、集合比较、JSON 文本格式化
  features/
    workspace/
      domain/
        entities/                    不可变实体、工作区快照
        repositories/                工作区仓储、请求网关接口
        use_cases/                   发送并记录、历史重发、设置更新
      data/
        models/                      workspace.json v1 编解码
        data_sources/                本地文件、恢复、目录迁移
        repositories/                工作区仓储、HTTP 请求网关实现
      presentation/
        library/                     文件夹、接口列表、搜索
        editor/                      请求编辑、执行状态、响应展示
        history/                     历史列表与只读快照
        tabs/                        标签选择、排序
        formatters/                  工作区中文提示、方法颜色
        view_models/                 仓储投影监听基类
    settings/presentation/           设置对话框、临时选项与保存状态
    help/presentation/               内置帮助
    mock/
      domain/                        不可变路由/场景、JSON Pointer 匹配、JSON 模板生成及服务接口
      data/                          Mock JSON 编解码、仅回环地址的 HttpServer 实现
      presentation/                  独立列表、场景编辑、字段表与预览、服务运行状态
  shared/widgets/                    不引用业务实体的复用 UI
  layout/                            内容插槽、导航栏、桌面尺寸与分栏
```

依赖方向为 `presentation → domain ← data`；领域层仅复用纯 Dart 的 `core/errors`、`core/utils`。它不引用 Flutter、Provider、文件系统、网络实现或展示层。`core` 不反向引用业务，`shared` 和 `layout` 不引用 feature。具体数据实现只在应用组装处创建。

`test/architecture_test.dart` 扫描生产代码导入，约束这些边界，并限制 ViewModel 相互引用。Windows 导航保留本地状态切换，没有引入路由库。

## 数据所有权

`WorkspaceRepository` 是接口定义、草稿、文件夹、历史和持久化设置的唯一变更入口。`LocalWorkspaceRepository` 保管当前 `WorkspaceState`，发出只读状态流，提供明确的编辑、保存、排序、删除等命令。

领域实体的字段为 final，集合复制后以不可修改形式暴露。编辑使用 `copyWith` 和 `updateDraft`；UI 不直接修改集合或实体，也没有通用 `changed()` 入口。已保存定义、编辑草稿、发送快照可安全共享不可变对象，之后编辑会生成新对象。

`WorkspaceJson` 只在数据边界编码、解码。不为 UI 再建立一份模型。现有 `workspace.json` 与 `settings.json` 继续使用 v1 格式、原字段与原有数据目录规则，不需要迁移。旧历史中的错误文本保留原值；新传输错误在序列化边界转换为兼容的旧字段。

工作区仓储负责 400 ms 草稿写入防抖、保存失败回滚和目录切换期间的协调。数据源串行化文件操作；`AtomicJsonFile` 负责临时文件落盘、备份与替换。迁移先写入空目标目录，再提交位置指针，源目录保留，失败回滚目标文件。设置保存期间产生的新编辑通过后续排队保存写入已提交的新目录。

## 展示状态与生命周期

| 状态 | 所有者与生命周期 |
| --- | --- |
| 仓储、请求网关、桌面平台服务 | `AppDependencies` 创建并释放；Provider 以 value 注入 |
| 正在执行的请求与各标签响应缓存 | 应用级 `RequestExecutionViewModel`，随依赖一起释放，切换页面不取消 |
| 导航、列表、历史选择、标签状态 | 应用 Provider 创建并释放，对应模块独立 ViewModel |
| 当前请求编辑状态 | 按请求 ID 创建的 `RequestEditorViewModel`，切换标签或页面时释放，草稿仍由仓储持有 |
| 设置选择目录、忙碌与失败状态 | 设置对话框内的 Provider；关闭时释放，保存前的选择不修改仓储 |
| 文本控制器、焦点、折叠、滚动与布局尺寸 | 对应 Widget 局部状态，由 Widget 释放 |

`RepositoryViewModel` 只监听本模块需要的数据投影。未变化的快照集合保留引用，历史追加不会触发编辑器或接口列表刷新。Widget 使用局部 ListenableBuilder、Consumer 或 select 更新。ViewModel 不相互调用；共享数据通过仓储状态流同步。

外部注入的 `AppDependencies` 由调用方释放，默认生产依赖由 `WeilsApp` 释放。执行状态先取消请求并解除订阅，再释放平台服务与仓储。各页面 ViewModel 取消自身订阅，避免页面切换后继续通知已销毁的 ChangeNotifier。

## 流程与错误

- `SendRequest` 捕获发送时的不可变请求，调用网关，追加历史并等待持久化。超时、取消和 HTTP 错误均保留历史；发送不保存接口定义。
- `ReplayHistory` 创建新 ID 的编辑草稿，并处理原文件夹已不存在的情况，不修改历史。
- `UpdateWorkspaceSettings` 提供设置更新用例入口；需要锁住工作区写入的事务由仓储实现协调。
- `CloseCoordinator` 处理弹窗、保存、取消请求、失败重试和实际关闭窗口。领域层不接触 BuildContext。
- `IoHttpTransport` 只提供通用 HTTP 能力；默认请求头、Bearer 与业务映射属于 workspace。MethodChannel 只出现在 `core/platform`。
- 基础设施错误转换为 `AppFailure` / `Outcome`；工作区和设置展示层分别映射中文提示。数据恢复仍保留损坏文件并明确提示，读失败时暂停保存。

## Mock 扩展

Mock 定义、草稿、当前编辑 ID 和端口设置统一放在 `WorkspaceSnapshot`，所有修改仍通过 `WorkspaceRepository`。v1 JSON 增加可选的 `mocks`、`mockDrafts`、`mockActiveId`、`mockPort`，缺失时为空与 3000；草稿保留尚未解析成功的 Header JSON 文本。原子写入、恢复及目录迁移统一复用原工作区数据源。

Mock 保存、删除与端口变更采用串行事务，写入成功后才发布新的已保存定义；普通 flush 等待事务，再捕获最新快照。保存期间新增编辑仍保留为草稿，失败不会让服务看到未落盘配置。退出的保存/放弃流程同时处理两类草稿。

`AppDependencies` 创建并释放 `MockServer` 和应用级 `MockViewModel`。服务运行状态不持久化，页面切换不影响监听；正常退出先停止服务，依赖释放也会强制停止并取消延迟计时器。每个入站请求在读取正文前捕获已保存定义，不进入 `SendRequest` 或历史流程。

路由/场景匹配与模板生成在纯 Dart 领域层，`IoMockServer` 在数据层使用 `dart:io`。生成器可以注入随机源和时钟，并逐分支检查未被随机选中的模板内容。展示层不引用数据实现，导航组装在 app 层，已有架构测试继续约束导入方向。

## 修改与验证

新增功能先确定状态和数据的所有者。工作区内的简单编辑直接增加仓储命令；需要协调多个步骤时再提取用例。仅当前功能使用的组件留在本 feature；不含业务引用且已有跨功能用途的组件才放进 shared。不要把业务规则放进 layout 或 core。

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter test integration_test/windows_flow_test.dart -d windows --no-pub
flutter build windows --release --no-pub
```

原有 46 项测试已迁移到新仓储与应用依赖上，位于 `test/features/workspace/workspace_repository_test.dart` 与 `test/app/workspace_flow_test.dart`。新增测试覆盖导入边界、不可变集合、完整 v1 固定样本往返、局部通知、Provider 释放及跨页面请求。测试组合辅助代码只放在 `test/support`，生产代码没有旧 Controller 或兼容门面。
