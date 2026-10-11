# PromptSlip v0.2.0-preview

**Paste. Drag. Done.** Turn long AI prompts into drag-and-drop Markdown or TXT attachments. Lightweight, native, and fully local.

## Downloads

Use [GitHub Releases](https://github.com/huichuanzhou-cmd/PromptSlip/releases) for the Windows portable ZIP, source ZIP, SHA256SUMS.txt and explicitly Experimental macOS Universal / Linux x86_64 builds.

## Verified scope

[All four native CI jobs passed](https://github.com/huichuanzhou-cmd/PromptSlip/actions/runs/38183554014) at source commit `b7159478c010650c96c9dd2def2fdaab9e4e75bb`:

- Windows: GUI/CLI compile, 19 core/GUI/CLI checks, 5 real subprocess groups, package/link/privacy checks. Actual read-only desktop clipboard testing also passed locally.
- macOS Intel and Apple Silicon: Universal arm64/x86_64 build, slice checks, native CLI and corrupted-draft/two-process recovery plus safe legacy migration tests.
- Linux Ubuntu 24.04 x86_64: GTK3 build, CLI and Xvfb URI-list drag/normal-close draft smoke.

This is a pre-release. Renamed-build real desktop/browser drag acceptance remains unverified; Linux Xvfb is a synthetic receiver test, not Wayland/browser acceptance. macOS has no Developer ID signing/notarization; do not disable security controls. Minimum macOS 11 is configured, not runtime-tested. Linux needs GTK3 and system libraries; older distributions are unverified. Windows uses system .NET Framework 4.x and currently has Chinese GUI labels.

## Changes

- Renamed PasteDrop to PromptSlip across native programs, CLI, scripts, assets, metadata and bilingual documentation.
- Preserved old portable Windows data; safely copied legacy Mac/Linux drafts only when the new draft is absent. Old attachments remain untouched.
- Preserved corrupt draft bytes while allowing fresh edits to recover; tested Windows write-denial and retry.
- Fixed CI lipo argument order, GTK smoke quoting and equivalent macOS path handling in the acceptance test; Git shell scripts are executable.
- Kept Markdown default, optional TXT, plaintext local drafts and immutable exports. No API/account/cloud/browser runtime/telemetry added.

The destination must accept files. File attachments do not increase model context or guarantee full ingestion. CLI output is a path, not an upload.

License: [MIT](https://github.com/huichuanzhou-cmd/PromptSlip/blob/main/LICENSE), copyright 2026 huichuanzhou-cmd.
