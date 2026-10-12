# PromptSlip — Lightweight AI Prompt File Transfer

**Paste. Drag. Done.**

Turn long AI prompts into real Markdown or TXT files you can drag into AI chats and coding tools. Paste here once, then attach the file without creating it manually. Markdown (`.md`) is the default; TXT (`.txt`) is optional.

**[Download Windows Preview](https://github.com/huichuanzhou-cmd/PromptSlip/releases)** · [Experimental macOS / Linux builds](https://github.com/huichuanzhou-cmd/PromptSlip/releases) · [简体中文](README.zh-CN.md) · [MIT License](LICENSE)

![Copy a long prompt, paste into PromptSlip, and drag a Markdown file into a browser](https://raw.githubusercontent.com/huichuanzhou-cmd/PromptSlip/main/docs/assets/promptslip-demo.gif)

20-second real capture: 18,070 characters of synthetic text → native Linux app → local Chrome receiver. The complete file and SHA-256 are verified. No private chats; this is not an AI-site compatibility test. [Capture verification](https://github.com/huichuanzhou-cmd/PromptSlip/actions/runs/38232922071).

**30-second start:** unzip the Windows package, open `PromptSlip.exe`, paste your text, then drag the file card into the destination's attachment area. Confirm that the file appears before sending. The current Windows GUI labels are in Simplified Chinese; English CLI help and documentation are provided.

## Why PromptSlip?

AI prompt transfer can involve moving a long brief from one model to another. If pasting into the destination is awkward or limited, use an attachment instead. PromptSlip provides **Clipboard to Markdown** and **drag and drop text file** workflows without a notes vault or manual file creation. ChatGPT, Claude, Kimi and AI coding tools are example destinations, not official integrations or verified compatibility claims.

The destination must accept file uploads. Attachments do not increase a model's context window, and successful upload does not guarantee full-file ingestion. PromptSlip creates the file; it does not upload it or send the message.

## Platform status — v0.2.0-preview

| Platform | Native build / tests | Remaining limits |
| --- | --- | --- |
| Windows | CI passed: GUI/CLI build, 19 core/GUI/CLI checks and 5 subprocess groups. Actual clipboard-to-CLI also passed locally. | Earlier PasteDrop GUI drag success is user-reported. Renamed-build mouse/browser upload acceptance not run. Requires system .NET Framework 4.x. |
| macOS Intel + Apple Silicon | Both native CI hosts passed Universal build, both-slice checks, CLI and draft recovery/migration tests. | **Experimental.** AppKit desktop drag not tested; no Developer ID signing/notarization. Target macOS 11+, tested CI hosts macOS 15. |
| Linux x86_64 | Ubuntu 24.04 CI passed GTK3 build, CLI and Xvfb file-URI drag/close-save smoke. The demo verifies native GTK → Chrome file drag under Xvfb. | **Experimental.** Physical X11/Wayland desktops and AI-site uploads not tested. GTK3/system dynamic libraries required; older distributions unverified. |

[Actual CI run](https://github.com/huichuanzhou-cmd/PromptSlip/actions/runs/38183554014) · [Exact validation scope](docs/VALIDATION.md) · [Machine-readable record](verification.json)

## Use

1. Paste or type the complete text.
2. Review the filename and format; default `.md`, optional `.txt`.
3. Drag the file card to the site's attachment area.
4. Confirm the attachment appears, then send it yourself.

Exports are local snapshots; existing attachments are retained. No account, AI API, network service, browser engine, telemetry or automatic update service is included.

## Command line

```powershell
.\PromptSlip.Cli.exe --clipboard --name prompt
cmd /c "PromptSlip.Cli.exe --stdin < brief.md"
```

```sh
printf 'Project brief\n' | promptslip --stdin --name prompt
promptslip --clipboard --output-dir "$HOME/Attachments" --txt
```

Choose exactly one of `--stdin` and `--clipboard`. Optional flags: `--output-dir DIR`, `--name NAME`, `--txt`; `--help` prints usage. Success prints a new file's absolute path, not an upload. Stdin is strict UTF-8 and preserves line endings. PowerShell 5 text pipelines may change encoding; redirect a UTF-8 file through `cmd /c` or use the explicit clipboard option. Clipboard mode needs a desktop session.

## Local data and older PasteDrop installations

Drafts and attachments are plaintext files on your device. Remove sensitive files yourself when no longer needed.

The Windows portable GUI keeps `数据/` and `文件/` beside the executable. Keep the whole existing portable folder when updating; replacing the EXE does not clear its data. Write errors are shown; text is not silently moved to LocalAppData. The CLI now defaults to `Documents/PromptSlip/files`; old `Documents/PasteDrop` files remain untouched.

macOS and Linux use PromptSlip application-data folders. If the new draft is absent, a legacy PasteDrop draft is copied exclusively without replacing a new draft or changing the old file. Old attachments stay in place. See the [macOS](macos/README.md), [Linux](linux/README.md) and [Windows](docs/windows/README.md) guides for paths and recovery behavior.

## Build and contribute

See [downloads and reproducible build commands](docs/DOWNLOADS.md), [CHANGELOG](CHANGELOG.md) and [release notes](RELEASE_NOTES.md). Product executables use native system UI libraries; Python is only a contributor test/packaging tool. The Windows GUI and CLI are about 19 KB and 11 KB respectively, excluding system .NET. Measurements and limits are in the validation record.
