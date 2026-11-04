# 开发辅助

## Windows 本地启动

VS Code 可直接点击 `lib/main.dart` 上方的 Run / Debug，或按 F5 选择 `Weils API (Windows)`。`.vscode/launch.json` 用 `templateFor` 将同一配置应用到文件上的运行按钮；启动前任务用 PowerShell 7 (`pwsh`) 准备数据与临时目录，随后 Flutter 调试进程使用相同的本地目录。启动配置只针对 `lib/main.dart`，不覆盖测试文件的运行配置。

当当前进程无法写入系统临时目录，或原数据目录导致“本地保存失败”时，在项目根目录运行：

```powershell
.\tool\run_windows.ps1
```

脚本仅为本次 Flutter 运行设置 `TEMP` / `TMP` 为 `build/dev-temp`，设置 `WEILS_API_DATA_DIR` 为被 Git 忽略的 `.local-data`。首次运行会读取当前数据位置配置，将原工作区及备份复制到 `.local-data`，原目录保留；已有本地副本时不会覆盖。后续使用这个脚本继续同一工作区，不要交替使用不同数据目录启动。退出后恢复调用进程的环境变量。

可用 `-PrepareOnly` 仅准备并检查目录，或追加 `--release` 等 Flutter 参数。此脚本不会修改系统临时目录权限或停止其他应用。调试结束在运行终端按 `q` 退出。

## 存储检查

`integration_test/storage_access_test.dart` 用独立探测文件验证真实 Windows 应用进程能否创建、备份并替换 JSON；不写入已有 `workspace.json`。通过 `--dart-define=STORAGE_TEST_DIR=绝对目录` 指定需要检查的目录，未指定时使用独立临时目录。

## 界面截图

界面截图由 `test/app/workspace_flow_test.dart` 和 `integration_test/windows_flow_test.dart` 生成在 `.impeccable/review/`。

- `home-1440.png`：空白工作区。
- `editor-1440.png` / `editor-1280.png`：界面测试中的演示请求。
- `history-1440.png` / `history-1280.png`：演示历史快照。
- `native-*.png`：实际 Windows 应用中的本地 HTTP 集成测试。

截图中的演示和测试请求不写入正常应用的数据目录，也不作为产品默认内容。
