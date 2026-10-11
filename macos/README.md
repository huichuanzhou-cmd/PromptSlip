# PromptSlip for macOS

PromptSlip is a small AppKit app and command-line tool. It uses only Apple frameworks and system utilities.

## Use a built release package

The macOS release archive contains a `PromptSlip/` directory with `PromptSlip.app`, a relative `promptslip` symlink to the app executable, `LICENSE`, this `README.md`, and `dependencies.txt`. From that directory, the GUI command is `open PromptSlip.app`; the CLI command is `printf 'Paste text here\n' | ./promptslip --stdin`. A prebuilt package does not need `build.sh`. This is Experimental, without Developer ID signing or notarization; macOS may restrict launch. Do not disable system security controls.

## Build from source

On a Mac with Xcode Command Line Tools installed:

```sh
sh ./build.sh
```

The default build contains universal `x86_64` and `arm64` slices. CI can build one slice with `PROMPTSLIP_ARCHS=x86_64 sh ./build.sh` or `PROMPTSLIP_ARCHS=arm64 sh ./build.sh`; use `PROMPTSLIP_ARCHS=universal` for the default. The app bundle reports version 0.2.0 and targets macOS 11.0 or later.

The output is `build/PromptSlip.app` plus a `build/promptslip` symlink to the app executable. Open the GUI with `open build/PromptSlip.app`. The executable is also usable from a terminal. The default build includes both `arm64` and `x86_64`, and the minimum system version is macOS 11.0:

This is an unsigned local preview; no signing or notarization is configured.

```sh
printf 'Paste text here\n' | ./build/promptslip --stdin
./build/promptslip --clipboard --name prompt --txt
```

CLI snapshots default to `~/Library/Application Support/PromptSlip/files`. Pass `--output-dir DIR` to choose another directory. Each invocation creates a new snapshot and prints its absolute path to stdout. The app's editor draft is stored at `~/Library/Application Support/PromptSlip/draft.txt`. On first launch, if that draft is absent, the app safely copies a draft from the historical `PasteDrop/draft.txt` or `pastedrop/draft.txt` location. It preserves the old file and every old attachment in place; migration only copies the draft and never replaces an existing PromptSlip draft. If the copied legacy draft has invalid UTF-8, PromptSlip preserves a corrupt backup in the new directory and opens a fresh editor that can save; the historical source stays untouched. If reading or copying fails, the app reports the specific path and error and leaves the old draft untouched.

If the saved draft contains invalid UTF-8, PromptSlip moves it to a unique `draft.txt.corrupt-<uuid>` file in the same directory. The original bytes remain available there, and the editor can save a fresh draft. If moving the damaged draft fails, PromptSlip reports the failure and blocks writes so the original is not replaced.

To put the command on your shell path without changing system directories, create a symlink in a user-owned bin directory:

```sh
mkdir -p "$HOME/bin"
ln -sf "/absolute/path/to/PromptSlip/macos/build/promptslip" "$HOME/bin/promptslip"
```

Ensure `$HOME/bin` is on `PATH`, then run `promptslip --help`. The CLI symlink is relative to the app bundle, so the two build outputs can move together.

## Checks

The draft-storage lifecycle test compiles with Foundation and runs two separate test processes against one temporary directory:

```sh
sh ./test-draft.sh
```

It checks damaged-draft preservation, saving edited text, and reloading that text in the second process. This validates shared storage across process lifetimes; it does not automate an AppKit window.

The CLI acceptance check is:

```sh
sh ./acceptance.sh ./build/promptslip
```

This checks strict UTF-8 input, byte-for-byte CRLF and large payload preservation, unique snapshots, `.txt` output, reserved and bounded filenames, invalid/missing option values, empty input, and help output. Manual macOS checks should use Cmd+V/X/C/A/Z/Shift+Cmd+Z, drag the card into a destination, verify latest text and the real file URL, test Cmd+Q draft saving, and confirm an unreadable existing draft is reported and preserved.
