# Validation — 2026-10-12

This record distinguishes actual native CI, local tests and unverified desktop behavior. [Passing CI run](https://github.com/huichuanzhou-cmd/PromptSlip/actions/runs/38183554014), source commit `b7159478c010650c96c9dd2def2fdaab9e4e75bb`. All four jobs passed; the workflow retains push/PR/manual triggers and read-only repository permissions, and does not create Releases.

| Scope | Actual result | Remaining limits |
| --- | --- | --- |
| Windows native build/tests | PASS: GUI/CLI build; 8 core, 4 GUI/storage, 7 CLI checks; 5 subprocess groups; package checks. | WinForms/FileDrop tests are isolated. Renamed-build mouse/browser upload NOT_RUN; earlier PasteDrop drag success USER_REPORTED. |
| macOS Intel + arm64 | PASS on both native hosts: Universal build and slices, platform/common CLI, corrupt-draft two-process recovery and legacy migration tests. | AppKit window/desktop drag NOT_RUN. Configured minimum 11.0; actual hosts macOS 15. No Developer ID signing/notarization. |
| Linux Ubuntu 24.04 x86_64 | PASS: GTK3 build, platform/common CLI, Xvfb legacy-draft copy + latest-text URI drag + normal-close pending-edit save. | Synthetic X11 receiver only. Real X11/Wayland desktop and browser uploads NOT_RUN. |
| Actual desktop clipboard | PASS locally on Windows: exact native CLI bytes, clipboard unchanged, temporary attachment removed, no content logged. | Mac/Linux actual clipboard NOT_RUN. |

## Coverage and fixes

The suites cover >1 MB UTF-8 Chinese/Japanese/emoji, CRLF/LF, MD/TXT, safe bounded filenames, no overwrite of earlier exports, invalid/empty inputs and duplicate flags. Windows tests check actual ACL write denial, preserving old draft bytes and retry after rights restoration. Mac tests preserve damaged source/backup bytes, save edited text and reload in a separate process; legacy migration prefers existing new drafts and leaves old data untouched. Linux smoke checks safe legacy draft copy, selected replacement text, File URI transfer and closing before the pending edit autosaves.

Initial CI failures were diagnosed from actual logs: the lipo command parsed the input filename as an architecture; GTK smoke had a single quote inside its outer single-quoted program; common Mac acceptance compared /var and /private/var lexically. These were fixed without removing error exits or containment assertions. The final native CI above passed.

## Size and local performance

Local Windows GUI: 18,944 bytes; CLI: 11,264 bytes, excluding system .NET Framework 4.x. Three empty invisible WinForms handles/message-loop probes became ready in 172 / 124 / 108 ms; working sets 48,349,184 / 48,001,024 / 47,955,968 bytes (about 46 MiB). These include the test probe and .NET. They are not cold-start guarantees or long-prompt memory benchmarks. Other-platform startup/memory: UNKNOWN.

macOS links system Cocoa/Foundation. Linux links GTK3/GLib and system dynamic libraries; actual dependency lists are inside native packages. Python is a contributor test/packaging dependency only.

## Package and privacy checks

Explicit source/product allowlists, archive bytes/integrity, local Markdown links and shell modes/LF are checked. Staged Git files are restricted to the source allowlist. Common credentials/private keys/private directory paths/emails are screened; this is a bounded check, not a complete security proof. No personal prompts, drafts, runtime data or caches enter source history or packages. LICENSE keeps 2026 huichuanzhou-cmd.

Native Actions artifact digests and embedded SHA-256 are checked on download. Mac package membership, safe CLI symlink and both CPU slices; Linux tar membership, ELF architecture, executable mode and GTK dependency records are checked before publication. Final archive SHA-256 values accompany the release.

See [verification.json](../verification.json) for machine-readable scope and [build instructions](DOWNLOADS.md) to rerun checks. macOS/Linux remain Experimental despite passing native CI; compilation is not desktop drag acceptance.
