# PromptSlip for Windows

**粘贴。拖出。完成。** 在本地将 AI 提示词和需求说明变成真实文件附件。

[English](README.md) · [许可证](../../LICENSE) · [验证记录](../../verification.json)

## 便携程序

解压 Windows 发行包并运行 `PromptSlip.exe`。粘贴或输入文本，检查文件名和内容，再把文件卡片拖到网站的附件区域。默认格式为 Markdown（`.md`）；网站不接受 Markdown 时可选 `.txt`。发送前请确认目标页面显示了该附件。

目前图形界面为简体中文，CLI 和英文指南均已提供。目标平台必须接受文件上传；文件附件不会扩大模型的上下文窗口。

Windows GUI 会把草稿和附件存放在 `PromptSlip.exe` 旁边的 `数据/` 和 `文件/` 目录中。这是便携式存储。如果程序目录只读，PromptSlip 会报告写入错误，不会静默改存到 LocalAppData。请将整个便携目录移至当前 Windows 账户可写的位置，再从那里运行。

GUI 和 CLI 使用不同的默认目录。除非指定 `--output-dir`，CLI 会将导出文件写入 `Documents/PromptSlip/files`。

## 命令行

发行包包含 `PromptSlip.Cli.exe`。请选择一个输入来源：

```powershell
.\PromptSlip.Cli.exe --clipboard --name prompt
.\PromptSlip.Cli.exe --clipboard --output-dir 'D:\Attachments' --txt
cmd /c "PromptSlip.Cli.exe --stdin < brief.md"
```

只有明确传入 `--clipboard` 时，程序才读取一次桌面文本剪贴板。`--stdin` 读取 UTF-8 字节并保留换行。PowerShell 5 文本管道可能使用由本机设置决定的编码；通过 `cmd /c` 重定向 UTF-8 文件可以保留文件字节。可选参数为 `--output-dir DIR`、`--name NAME` 和 `--txt`；用 `--help` 查看用法。成功后 stdout 会输出所创建文件的绝对路径；该路径不代表文件已上传。

## 限制与本地数据

草稿和附件以明文保存在本设备。请保护 Windows 账户，并在不再需要文件时自行删除。PromptSlip 无需账号或 API，不会连接网络服务，也不会发送消息。目标网站可能因自身限制拒收附件；上传成功也不保证 AI 服务读完全文。关键指令请保留在提示词正文中，需要时要求服务确认已读取附件。

## 验证状态与包内文件

验证记录区分用户报告的拖放成功（`USER_REPORTED`）和本轮自动化结果。Windows 核心、GUI 存储、真实 stdin 进程管道及真实桌面剪贴板到 CLI 测试通过；本轮未自动操作原生鼠标拖放或浏览器上传。确切范围见 [verification.json](../../verification.json)。

便携 ZIP 根目录包含 `PromptSlip.exe`、`PromptSlip.Cli.exe`、英文 `README.md`、中文 `README.zh-CN.md`、`LICENSE` 和 `verification.json`。说明离线可读，不依赖源码中的其他平台目录。

无效 UTF-8 草稿会先保留为唯一 `.corrupt-*` 备份，再允许新编辑保存。原文件无法读取或备份时会显示错误并阻止覆盖。已经导出的附件不会自动删除。

许可证：[MIT](../../LICENSE)。
