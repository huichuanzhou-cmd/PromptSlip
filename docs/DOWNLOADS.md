# Downloads and source builds

## Download availability

The public repository is [huichuanzhou-cmd/PromptSlip](https://github.com/huichuanzhou-cmd/PromptSlip). The [Releases page](https://github.com/huichuanzhou-cmd/PromptSlip/releases) is the download entry point, but it currently has no published release assets. The repository was created separately from this staging checkout and is currently empty; source code and local builds are not downloadable from it yet. Do not treat a local executable as a public release.

For now, obtain the source tree from the person or workspace that provided this project. No public source archive or binary package is available yet. Add direct asset links only after checking an actual published Release and its assets.

## Windows portable build

On Windows with the .NET Framework 4.x compiler available, open PowerShell in the PromptSlip source root and run:

```powershell
./build.ps1
```

This produces `PromptSlip.exe` (GUI) and `PromptSlip.Cli.exe` (CLI). To run the recorded local checks:

```powershell
./test.ps1
python tests/cli_acceptance.py ./PromptSlip.Cli.exe
./test-clipboard.ps1  # explicit read-only clipboard test; skips if no text
./measure-windows.ps1
python package.py --output-dir dist
```

The app is portable. Keep the executable, its language guides, `LICENSE`, and `verification.json` together in the Windows package. The package script flattens the bilingual Windows guides into the archive root and adjusts their relative links to `LICENSE` and `verification.json`; the source-tree links in those guides are intentionally relative to `docs/windows/`. It also checks archive contents, offline links and SHA-256 checksums. See [the independent Windows guide](windows/README.md).

The GUI writes `数据/` and `文件/` next to `PromptSlip.exe`. Put the portable folder in a user-writable location. A read-only program folder results in a visible write error and no silent LocalAppData migration. The CLI has a separate default at `Documents/PromptSlip/files`; this does not migrate or delete older `PasteDrop` data.

## macOS preview build

The source includes an AppKit implementation and build script. Native Mac compilation and runtime checks are `NOT_RUN` unless a later dated validation record says otherwise. On a Mac with Apple Command Line Tools, the source build command is:

```sh
sh macos/build.sh
sh macos/acceptance.sh
sh macos/test-draft.sh
python3 tests/cli_acceptance.py macos/build/promptslip
```

The app targets macOS 11 or newer and the build script requests Intel and Apple Silicon slices. The preview is unsigned and not notarized. Do not disable macOS security controls to launch it. Wait for a signed and notarized release, or build and inspect the source yourself.

## Linux preview build

The source includes a GTK 3 implementation. Native Linux compilation and runtime checks are `NOT_RUN` unless a later dated validation record says otherwise. A C compiler, `pkg-config`, GTK 3 development files, and GTK 3 runtime libraries are required. The available source commands are:

```sh
sh linux/build.sh
sh linux/test-cli.sh
python3 tests/cli_acceptance.py linux/build/promptslip
sh linux/smoke-gui.sh
```

The GTK runtime requires system dynamic libraries. X11 and Wayland behavior has not been verified. The Xvfb-based smoke script, where available, is a synthetic receiver check and not browser acceptance.

## What verification means

See [`../verification.json`](../verification.json) for the dated outcomes and their limits. Windows isolated tests are not a real-browser upload test. macOS and Linux source presence and shell syntax checks do not establish that either platform builds or runs. Browser upload, attachment limits, and whether a model reads the entire file remain dependent on the destination service. The latest documentation-only update does not claim that CI or newly built binaries have passed.
