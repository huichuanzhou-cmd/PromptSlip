# PromptSlip 0.2.0-preview

**Paste. Drag. Done.** Turn long AI prompts into drag-and-drop Markdown or TXT attachments. PromptSlip runs locally and needs no account, API, or browser runtime. It creates a file on your device; you choose whether and where to attach or send it.

## Quick start

On Windows, run `PromptSlip.exe`, paste and review your text, then drag the file card to a destination that accepts attachments. Markdown (`.md`) is the default; TXT (`.txt`) is optional. The GUI currently uses Simplified Chinese labels. ChatGPT, Claude, Kimi, and AI coding tools are example scenarios, not tested integrations.

The public repository is [github.com/huichuanzhou-cmd/PromptSlip](https://github.com/huichuanzhou-cmd/PromptSlip). The [Releases page](https://github.com/huichuanzhou-cmd/PromptSlip/releases) is the download entry point; it currently has no published package assets.

## Preview status

- **Windows:** The renamed GUI/CLI compiled on 2026-10-12 and passed 19 core/GUI/CLI checks, 5 real subprocess groups and an actual read-only clipboard test. Earlier PasteDrop drag success is user-reported; native mouse/browser upload testing of the renamed build is not run. See [verification.json](verification.json).
- **macOS:** Experimental / Preview. AppKit source is present. Native build and runtime checks are `NOT_RUN` unless a later dated validation record says otherwise. The preview is unsigned and not notarized.
- **Linux:** Experimental / Preview. GTK 3 source is present. Native build and runtime checks are `NOT_RUN` unless a later dated validation record says otherwise. GTK 3 runtime libraries are required; X11 and Wayland behavior is unverified.

An attachment does not expand a model's context window, and a successful upload would not prove that the service read the full file. Keep critical instructions in the prompt itself and request confirmation when completeness matters.

## Local storage and compatibility

Drafts and attachments are plaintext files stored locally. The Windows GUI keeps `数据/` and `文件/` beside the portable app; a read-only location produces a visible error and is not silently redirected to LocalAppData. The CLI default is `Documents/PromptSlip/files`, separate from the GUI folder. Existing Windows portable data remains in its current folder, and changing the CLI default does not move or delete older `PasteDrop` data.

## Build and verification

See [docs/DOWNLOADS.md](docs/DOWNLOADS.md) for source builds and platform requirements. The validation record preserves the scope and date of earlier checks. The local renamed Windows build passed the checks above. Native CI is pending the first source push; no CI PASS is claimed yet.

License: [MIT](LICENSE). See [CHANGELOG.md](CHANGELOG.md) for the project history.
