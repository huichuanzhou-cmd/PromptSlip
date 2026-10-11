# PromptSlip — Lightweight AI Prompt File Transfer

**Paste. Drag. Done.**

Turn a long AI prompt into a Markdown (`.md`) or TXT (`.txt`) attachment: paste it into PromptSlip, review the file, then drag it into a destination that accepts attachments. This is a lightweight, fully local way to move text between your clipboard and an AI chat or coding tool. It does not upload or send anything for you.

**30-second start:** download the Windows portable package from [GitHub Releases](https://github.com/huichuanzhou-cmd/PromptSlip/releases) when an asset is available, unzip it, run `PromptSlip.exe`, paste your text, then drag the file card to the destination's attachment area. Markdown is the default; choose TXT when needed. The public repository is new and currently has no published release assets, so there is no ready-to-download package yet. [Browse the repository](https://github.com/huichuanzhou-cmd/PromptSlip).

The Windows GUI currently uses Simplified Chinese labels; the CLI and English documentation are available. PromptSlip needs no account, API, network service, or browser runtime. ChatGPT, Claude, Kimi, and AI coding tools are examples of possible destinations, not tested compatibility claims. The destination must accept file uploads, and attaching a file does not increase a model's context window. Check that the destination shows the attachment before sending; ask the service to confirm it read the full file when completeness matters.

[简体中文](README.zh-CN.md) · [Releases](https://github.com/huichuanzhou-cmd/PromptSlip/releases) · [Downloads and build instructions](docs/DOWNLOADS.md) · [Windows guide](docs/windows/README.md) · [MIT License](LICENSE) · [Verification record](verification.json)

## Platform status

| Platform | Status | What is known |
| --- | --- | --- |
| Windows | Local build and tests passed; Preview | Renamed GUI/CLI compiled on 2026-10-12; 19 core/GUI/CLI checks, 5 subprocess groups and an actual read-only clipboard check passed. Earlier PasteDrop drag success is user-reported; renamed-build native mouse/browser upload testing is not run. |
| macOS | Experimental / Preview | AppKit source and build scripts are present. Native compilation and runtime checks are `NOT_RUN` unless a later dated validation record says otherwise. The preview is unsigned and not notarized. |
| Linux | Experimental / Preview | GTK 3 source and build scripts are present. Native compilation and runtime checks are `NOT_RUN` unless a later dated validation record says otherwise. GTK 3 runtime libraries are required; X11 and Wayland behavior is unverified. |

## Use

1. Paste or type the complete text and review it.
2. Choose a filename; Markdown (`.md`) is the default, and TXT (`.txt`) is optional.
3. Drag the file card to the destination site's attachment area.
4. Confirm the attachment appears there, then send it yourself.

Each export is a local file snapshot. Earlier exports remain on disk; PromptSlip does not automatically send messages or clean up files.

## Command line

The CLI requires exactly one input option: `--stdin` or `--clipboard`. Optional flags are `--output-dir DIR`, `--name NAME`, and `--txt`; `--help` prints usage. `--clipboard` explicitly reads the desktop text clipboard once. Success prints the new file's absolute path to stdout. That path is not an upload.

Windows PowerShell:

```powershell
.\PromptSlip.Cli.exe --clipboard --name prompt
.\PromptSlip.Cli.exe --clipboard --output-dir 'D:\Attachments' --txt
```

macOS / Linux:

```sh
printf 'Project brief\n' | promptslip --stdin --name prompt
promptslip --clipboard --output-dir "$HOME/Attachments"
```

`--stdin` reads UTF-8 bytes and preserves line endings. PowerShell 5 text pipelines may encode text according to local settings; for byte-preserving input, redirect a UTF-8 file with `cmd /c "PromptSlip.Cli.exe --stdin < brief.md"` or use the explicit clipboard option.

The Windows CLI default is `Documents/PromptSlip/files`. The Windows GUI uses the application folder instead (see the [Windows guide](docs/windows/README.md)). The macOS and Linux CLI defaults are documented in their source guides; those platforms remain unverified previews.

## Local data and privacy

Text drafts and exported attachments are saved as plaintext on your device. Anyone or any software with access to those files may read them. Choose a suitable local folder, protect your device account, and remove sensitive files yourself when no longer needed. PromptSlip does not send content over the network.

On Windows, the portable GUI stores `数据/` and `文件/` beside the program. If that location is read-only, PromptSlip reports the write error; it does not silently move data to LocalAppData. Move the portable folder to a user-writable location and run it there. The CLI uses its separate Documents default unless `--output-dir` is supplied. Existing Windows portable data stays with that folder; changing the CLI default does not move or delete older `PasteDrop` data.

## Build and verify from source

See [Downloads and build instructions](docs/DOWNLOADS.md) for source access and platform notes. Windows contributors can run `./build.ps1`, `./test.ps1`, and `python tests/cli_acceptance.py ./PromptSlip.Cli.exe` from this directory. These checks cover the implementation described by their scripts; they do not substitute for testing a real browser on each target platform.

The macOS build requires a Mac and Apple Command Line Tools. The Linux build requires a C compiler and GTK 3 development files; running the app also requires GTK 3 dynamic libraries. Do not disable macOS security controls to launch an unsigned build; wait for a properly signed and notarized release or build and inspect the source yourself.

The repository also contains [macOS source notes](macos/README.md) and [Linux source notes](linux/README.md). They are for building from the source tree; do not expect those folders in the independent Windows portable package.

## Project and release status

The public repository is [github.com/huichuanzhou-cmd/PromptSlip](https://github.com/huichuanzhou-cmd/PromptSlip). Its [Releases page](https://github.com/huichuanzhou-cmd/PromptSlip/releases) is the download entry point, but no release assets are published yet. Do not treat this source checkout or a local build as a downloadable release.

PromptSlip is distributed under the [MIT License](LICENSE), with copyright attribution to `huichuanzhou-cmd`. See [publication notes](docs/PUBLISHING.md) for the repository listing details and [release notes](RELEASE_NOTES.md) for this preview's scope.
