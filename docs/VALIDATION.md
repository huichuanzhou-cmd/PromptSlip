# Local validation — historical Windows and cross-platform evidence from 2026-10-11

## Documentation update — 2026-10-12

PromptSlip's renamed Windows GUI/CLI were rebuilt on 2026-10-12. The full 19 checks (8 core, 4 GUI/storage, 7 in-process CLI), 5 real subprocess acceptance groups and actual read-only desktop clipboard test passed. The local empty WinForms probe reported 172 / 124 / 108 ms readiness and approximately 46 MiB working set, including the probe and .NET runtime. It is not a cold-start guarantee. GUI and CLI remain 18,944 and 11,264 bytes, excluding system .NET.

The public repository is configured at [huichuanzhou-cmd/PromptSlip](https://github.com/huichuanzhou-cmd/PromptSlip). Native CI is pending the first source push. macOS/Linux legacy-draft compatibility code and tests are prepared; native execution is not yet claimed. The 2026-10-11 evidence below is historical and does not stand in for a current native CI run.

This is a local readiness record, not a published release or a CI run. See [verification.json](../verification.json) for machine-readable scope. The original source directory was not a Git repository and had no remote; current source files were copied into an isolated staging tree with a baseline hash manifest before editing. No user drafts or generated attachments were copied.

| Platform | Evidence | Limits |
| --- | --- | --- |
| Windows | Native GUI/CLI compiled; 8 core, 4 GUI-storage and 7 in-process CLI checks passed. Common real subprocess acceptance passed, including >1 MB UTF-8 Chinese/Japanese/emoji, CRLF, LF, MD/TXT, unsafe Unicode names and duplicate-option failures. Actual desktop clipboard-to-CLI bytes matched without changing the clipboard. | User reports the earlier Windows build's real drag flow works. This round does not automate native mouse drag or browser upload; FileDrop data objects are checked in isolation. |
| macOS | AppKit, universal/individual architecture build options, corrupted-draft storage fix and two-process lifecycle regression test implemented. Shell syntax checked with Git Bash. | Objective-C compilation, CLI/storage test execution, x86_64/arm64 runtime, AppKit GUI and drag: NOT_RUN. No Mac/Apple SDK. Minimum macOS 11.0 is a configured target, not tested compatibility. Unsigned, not notarized. |
| Linux | GTK3 implementation, common CLI acceptance, Xvfb URI-list receiver/close smoke and build script present; shell syntax checked. | Build, CLI, Xvfb, native X11 and Wayland desktop: NOT_RUN. WSL core/virtual-machine feature installation requires a Windows restart; no distro exists yet. Docker did not start. |

## Windows storage regression

The new regression first failed against the baseline because damaged draft bytes were not preserved. The fix moves an invalid UTF-8 draft to an exclusive unique `.corrupt-*` filename before new edits are saved. The test checks the original bytes, saves new Unicode text and instantiates a new form to verify recovery. An unreadable/unmovable original blocks overwriting and shows an error.

The write-denial test uses an actual Windows ACL on a generated temporary data directory. It proves saving fails, the existing draft bytes stay intact, and the edit stays dirty so saving succeeds after access is restored. DACL restoration is limited to the test folder. GUI fixtures explicitly create native editor handles so text-change notifications match a real editor. Early fixture failures were diagnosed and are not reported as product passes.

The GUI remains portable: data stays beside the executable, storage location is displayed, and no fallback silently relocates text. Save failures reach the status/error dialog; closing after a failed save still requires the existing user's close-without-saving choice. Attachments are retained.

## Commands

```powershell
./build.ps1
./test.ps1
python tests/cli_acceptance.py ./PromptSlip.Cli.exe
./test-clipboard.ps1
./measure-windows.ps1
python package.py --output-dir dist
```

The clipboard check reads existing text once for comparison and calls the native CLI, without replacing clipboard contents. Its temporary attachment is removed and never packaged. No content is printed in its log. An earlier attempt through Windows PowerShell 5 was blocked by that shell's script policy; running the trusted test in the available PowerShell session succeeded without changing execution policy. Empty clipboards return a labeled skip, not PASS.

## Measurements

Windows GUI executable: 18,944 bytes. CLI: 11,264 bytes. Three isolated empty invisible WinForms windows, with real native handles and a message loop, became ready in 230 / 129 / 137 ms. Working sets were 48,500,736 / 48,193,536 / 48,201,728 bytes (about 46 MiB). This includes the test probe and .NET runtime. Executable sizes exclude the system .NET dependency. These are local measurements, not production cold-start guarantees or large-text memory benchmarks. Other-platform sizes/performance are UNKNOWN.

Windows uses system .NET Framework 4.x. macOS links Apple Cocoa/Foundation frameworks. Linux links system GTK3/GLib and their transitive libraries; exact `ldd` output awaits a real build. Python is a developer test/packaging dependency, not a runtime dependency of the GUI or CLI.

## CI and package hygiene

The Xvfb fixture now requests `WM_DELETE_WINDOW` instead of destroying the window with `xdotool windowclose`, whose behavior is documented by [upstream xdotool](https://github.com/jordansissel/xdotool/blob/main/xdotool.pod). It types an additional edit immediately before requesting close to test draft flushing, and starts dragging within the source card before moving to the receiver. These fixture changes still require Linux execution; they are not a GUI PASS.

The workflow is prepared for push, pull_request and manual dispatch, with read-only repository permissions, no stored checkout credentials, and no Release/push jobs. Windows 2022, Ubuntu 24.04 and two Mac native architectures are configured. [Official checkout releases](https://github.com/actions/checkout/releases), [upload-artifact releases](https://github.com/actions/upload-artifact/releases) and [runner labels](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) were verified; this project has not run CI.

The packager checks explicit source/product allowlists, ZIP bytes, executable shell modes, LF shell scripts and every local Markdown link in the actual archives. Windows guides are flattened to the archive root with adjusted license/verification links. Known credential patterns, private user-directory paths and email patterns are screened in allowlisted text; this bounded scan is not a guarantee against every possible secret. Runtime data, caches and debug logs are excluded. SHA256SUMS records final archive hashes.

## Historical publication decision — 2026-10-11

At the time of this validation, the recommendation was **CONDITIONAL GO** for a Windows/source preview after owner confirmation of the README, copyright attribution, and repository identity. It was **NO-GO** for claiming a validated three-platform stable release. Mac/Linux native build/runtime checks had not run, and desktop/browser drag acceptance remained separate from compilation. The final statement that no public repository existed was true only as of 2026-10-11 and has since been superseded: the owner has authorized and created the public repository [huichuanzhou-cmd/PromptSlip](https://github.com/huichuanzhou-cmd/PromptSlip), currently empty. No Release assets or new CI results are recorded here.
