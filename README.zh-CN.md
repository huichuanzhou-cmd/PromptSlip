# PromptSlip — 轻量 AI 提示词文件传递

**Paste. Drag. Done. 粘贴。拖出。完成。**

把长 AI 提示词变成真实的 Markdown 或 TXT 文件，直接拖入 AI 聊天或编程工具。粘贴一次就能生成附件，无需手动创建文件。默认 Markdown（`.md`），TXT（`.txt`）可选。

**[下载 Windows 预览版](https://github.com/huichuanzhou-cmd/PromptSlip/releases)** · [实验性 macOS／Linux 构建](https://github.com/huichuanzhou-cmd/PromptSlip/releases) · [English](README.md) · [MIT 许可证](LICENSE)

**30 秒上手：** 解压 Windows 包，打开 `PromptSlip.exe`，粘贴文本，把文件卡片拖到目标页面的附件区域，确认附件出现后发送。Windows 图形界面目前为简体中文，同时提供英文 CLI 帮助和文档。

## 为什么使用 PromptSlip？

在不同 AI 之间传递长提示词、需求或交接说明时，目标输入框可能不方便直接粘贴。PromptSlip 提供剪贴板转 Markdown、拖出真实文本文件的最短流程，无需笔记仓库或手工创建文件。ChatGPT、Claude、Kimi 和 AI 编程工具只是可能的使用场景，并非官方集成或已验证兼容性。

目标平台必须接受文件上传。附件不会扩大模型上下文；上传成功也不保证模型读完全文。PromptSlip 只创建本地文件，不替你上传或发送消息。

## 平台状态 — v0.2.0-preview

| 平台 | 原生构建与测试 | 尚未验证的范围 |
| --- | --- | --- |
| Windows | CI 通过 GUI／CLI 编译、19 项 core／GUI／CLI 及 5 组子进程测试；本地实际剪贴板到 CLI 也通过。 | 旧 PasteDrop 拖放成功为用户报告；更名后真实鼠标／网页上传尚未验收。依赖系统 .NET Framework 4.x。 |
| macOS Intel／Apple Silicon | 两台原生 CI 均通过 Universal 构建、双切片、CLI、草稿恢复及迁移测试。 | **实验性。** AppKit 桌面拖放未测；无 Developer ID 签名／公证。最低 11+ 为构建目标，CI 实际系统为 macOS 15。 |
| Linux x86_64 | Ubuntu 24.04 CI 通过 GTK3 编译、CLI、Xvfb 文件 URI 拖放和关闭保存。 | **实验性。** 真实 X11／Wayland 桌面及浏览器尚未验收。需要 GTK3／系统动态库；旧发行版未验证。 |

[真实 CI](https://github.com/huichuanzhou-cmd/PromptSlip/actions/runs/38183554014) · [完整验证范围](docs/VALIDATION.md) · [机器可读记录](verification.json)

## 使用方法

1. 粘贴或输入完整文本。
2. 检查文件名与格式；默认 `.md`，可选 `.txt`。
3. 把文件卡片拖到目标页面的附件区域。
4. 确认附件出现，再自行发送。

导出结果为本地快照，已有附件保留。不含账号系统、AI API、网络服务、浏览器内核、遥测或自动更新服务。

## 命令行

```powershell
.\PromptSlip.Cli.exe --clipboard --name prompt
cmd /c "PromptSlip.Cli.exe --stdin < brief.md"
```

```sh
printf 'Project brief\n' | promptslip --stdin --name prompt
promptslip --clipboard --output-dir "$HOME/Attachments" --txt
```

`--stdin` 与 `--clipboard` 必须且只能选一项。可选参数：`--output-dir DIR`、`--name NAME`、`--txt`；`--help` 显示帮助。成功仅输出新文件的绝对路径，不代表上传。stdin 为严格 UTF-8，保留换行；PowerShell 5 文本管道可能改变编码，可用 `cmd /c` 重定向 UTF-8 文件或明确使用剪贴板选项。剪贴板模式需要桌面会话。

## 本地数据与旧 PasteDrop 兼容

草稿和附件以明文保存在设备上，不再需要的敏感文件请自行删除。

Windows 便携 GUI 继续在 EXE 旁使用 `数据/`、`文件/`。更新时保留整个原便携目录；替换 EXE 不会清空数据。写入失败会报错，不静默改存 LocalAppData。CLI 新默认路径为 `Documents/PromptSlip/files`，旧 `Documents/PasteDrop` 文件保持原样。

macOS／Linux 使用 PromptSlip 应用数据目录。新草稿不存在时，旧 PasteDrop 草稿以独占方式复制；已有新稿优先，旧文件不改动。旧附件不移动、不删除。详细路径和恢复说明见 [macOS](macos/README.md)、[Linux](linux/README.md)及 [Windows](docs/windows/README.zh-CN.md)指南。

## 构建与贡献

见[下载与可复现构建命令](docs/DOWNLOADS.md)、[CHANGELOG](CHANGELOG.md)和 [Release Notes](RELEASE_NOTES.md)。产品使用原生系统 UI；Python 仅用于开发测试和打包。Windows GUI／CLI 约 19 KB／11 KB，不包含系统 .NET；实测数据与限制见验证记录。
