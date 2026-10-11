# PromptSlip — 轻量 AI 提示词文件传递

**粘贴。拖出。完成。**

把较长的 AI 提示词变成 Markdown（`.md`）或 TXT（`.txt`）附件：粘贴到 PromptSlip，检查文件，再将它拖入支持附件的目标页面。这是一种轻量、完全本地的方式，可在剪贴板与 AI 聊天或编程工具之间传递文本。PromptSlip 不会替你上传或发送内容。

**30 秒上手：** 等 Windows 便携包发布后，从 [GitHub Releases](https://github.com/huichuanzhou-cmd/PromptSlip/releases) 下载并解压，运行 `PromptSlip.exe`，粘贴文本，再把文件卡片拖到目标页面的附件区域。默认格式为 Markdown；需要时可选 TXT。公开仓库刚创建，目前尚无已发布的发行包，因此暂时没有可直接下载的程序。[查看仓库](https://github.com/huichuanzhou-cmd/PromptSlip)。

Windows 图形界面当前使用简体中文；CLI 和英文文档已提供。PromptSlip 无需账号、API、网络服务或浏览器运行时。ChatGPT、Claude、Kimi 和 AI 编程工具只是可能的使用场景，并非已经测试过兼容性。目标页面必须支持文件上传；附件不会扩大模型的上下文窗口。发送前请确认目标页面显示了附件；需要确认完整性时，可要求服务确认已读取全文。

[English](README.md) · [发行版](https://github.com/huichuanzhou-cmd/PromptSlip/releases) · [下载与构建说明](docs/DOWNLOADS.md) · [Windows 指南](docs/windows/README.zh-CN.md) · [MIT 许可证](LICENSE) · [验证记录](verification.json)

## 平台状态

| 平台 | 状态 | 已知情况 |
| --- | --- | --- |
| Windows | 本地构建与测试通过；预览版 | 2026-10-12 更名后 GUI／CLI 编译、19 项 core／GUI／CLI、5 组真实子进程和实际只读剪贴板测试通过。旧 PasteDrop 拖放成功为用户报告；本构建尚未进行真实鼠标／浏览器上传验收。 |
| macOS | 实验性预览版 | 已有 AppKit 源码和构建脚本。除非之后带日期的验证记录另有说明，原生编译和运行均为 `NOT_RUN`。预览版未签名、未公证。 |
| Linux | 实验性预览版 | 已有 GTK 3 源码和构建脚本。除非之后带日期的验证记录另有说明，原生编译和运行均为 `NOT_RUN`。运行需要 GTK 3 动态库；X11 与 Wayland 行为尚未验证。 |

## 使用方法

1. 粘贴或输入完整文本并检查内容。
2. 选择文件名；默认 Markdown（`.md`），也可选 TXT（`.txt`）。
3. 将文件卡片拖到目标网站的附件区域。
4. 确认目标页面显示附件后，再自行发送。

每次导出都会生成本地文件快照。旧文件会保留；PromptSlip 不会自动发送消息或清理文件。

## 命令行

CLI 必须且只能指定一个输入选项：`--stdin` 或 `--clipboard`。可选参数为 `--output-dir DIR`、`--name NAME` 和 `--txt`；`--help` 显示用法。只有明确传入 `--clipboard` 时，程序才会读取一次桌面文本剪贴板。成功后 stdout 只输出新文件的绝对路径；该路径不代表已经上传。

Windows PowerShell：

```powershell
.\PromptSlip.Cli.exe --clipboard --name prompt
.\PromptSlip.Cli.exe --clipboard --output-dir 'D:\Attachments' --txt
```

macOS / Linux：

```sh
printf 'Project brief\n' | promptslip --stdin --name prompt
promptslip --clipboard --output-dir "$HOME/Attachments"
```

`--stdin` 读取 UTF-8 字节并保留换行。PowerShell 5 文本管道的编码可能受本机设置影响；要保留原始字节，可用 `cmd /c "PromptSlip.Cli.exe --stdin < brief.md"` 重定向 UTF-8 文件，或明确使用剪贴板选项。

Windows CLI 默认写入 `Documents/PromptSlip/files`；Windows GUI 则写入程序所在目录（见 [Windows 指南](docs/windows/README.zh-CN.md)）。macOS 与 Linux CLI 的默认路径见各自的源码说明；这两个平台仍是未验证的预览版。

## 本地数据与隐私

文本草稿和导出的附件以明文保存在本机。能够访问这些文件的人或软件也能读取其内容。请选用合适的本地目录、保护设备账户，并在敏感文件不再需要时自行删除。PromptSlip 不会通过网络发送文本。

Windows 便携 GUI 会将 `数据/` 和 `文件/` 保存在程序旁。如果当前位置只读，PromptSlip 会报告写入错误；它不会静默改存到 LocalAppData。请将整个便携目录移到当前用户可写的位置后再运行。CLI 默认使用独立的 Documents 目录，除非指定 `--output-dir`。Windows 现有便携数据仍保留在原目录；CLI 默认路径调整不会移动或删除旧的 `PasteDrop` 数据。

## 从源码构建和验证

目前的源码获取方式和平台说明见[下载与构建说明](docs/DOWNLOADS.md)。Windows 开发者可在本目录运行 `./build.ps1`、`./test.ps1` 和 `python tests/cli_acceptance.py ./PromptSlip.Cli.exe`。这些检查只覆盖相应脚本列出的范围，不能替代在各平台上使用真实浏览器验收。

macOS 构建需要 Mac 和 Apple Command Line Tools。Linux 构建需要 C 编译器和 GTK 3 开发文件；运行还需要 GTK 3 动态库。不要为了运行未签名程序而关闭 macOS 安全控制；请等待正确签名并公证的版本，或自行构建并检查源码。

仓库还包含 [macOS 源码说明](macos/README.md)和 [Linux 源码说明](linux/README.md)。这些说明用于从源码树构建；独立的 Windows 便携包不应包含这些目录。

## 项目与发布状态

公开仓库为 [github.com/huichuanzhou-cmd/PromptSlip](https://github.com/huichuanzhou-cmd/PromptSlip)。[Releases 页面](https://github.com/huichuanzhou-cmd/PromptSlip/releases)是下载入口，但目前尚未发布发行包。不要把本地源码副本或构建结果当作可下载的正式包。

PromptSlip 使用 [MIT 许可证](LICENSE)，版权署名为 `huichuanzhou-cmd`。仓库介绍和主题见[发布说明](docs/PUBLISHING.md)，本预览版范围见[发行说明](RELEASE_NOTES.md)。
