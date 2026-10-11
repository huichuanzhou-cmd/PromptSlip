# PromptSlip for Linux

**Experimental.** Ubuntu 24.04 x86_64 CI passed GTK3 build, CLI and Xvfb URI drag/close-save checks. Real X11/Wayland desktop and browser acceptance remain unverified. [CI evidence](https://github.com/huichuanzhou-cmd/PromptSlip/actions/runs/38183554014).

PromptSlip is a small GTK 3 editor that exports the current text as an immutable `.md` or `.txt` file when you drag its file card. It keeps a local recoverable draft and does not access the network. GTK's URI-list drag target works with the desktop's native file drag protocol.

## Use a built release package

The Linux tar archive contains `promptslip`, `LICENSE`, this `README.md`, and `dependencies.txt` at the package root. Run `./promptslip` to open the GUI or `printf 'hello\n' | ./promptslip --stdin` to save text from the CLI. A prebuilt package does not need `build.sh`; GTK 3 runtime libraries and a suitable desktop session are still required.

## Build from source

Install the distribution's GTK 3 development package and a C compiler (`gtk+-3.0`, GLib 2.x, and `pkg-config`), then run:

```sh
./build.sh
./build/promptslip
```

No elevated privileges are required. `./install-user.sh` optionally builds into `~/.local/bin` (or `$XDG_BIN_HOME`) and writes a desktop launcher into `$XDG_DATA_HOME/applications` (default `~/.local/share/applications`).

## Command line

```sh
printf 'hello\r\n' | ./build/promptslip --stdin --name prompt
./build/promptslip --clipboard --output-dir "$HOME/Attachments" --txt
```

`--stdin` reads strict UTF-8 bytes and does not initialize GTK or need a display. `--clipboard` requires a desktop session. The flags `--stdin` and `--clipboard` are mutually exclusive. Options are `--output-dir DIR`, `--name NAME`, `--txt`, and `--help`. The default output folder is `${XDG_DATA_HOME:-~/.local/share}/promptslip/files`; the default name is `prompt.md`. A successful command writes one absolute file path to stdout. Each save creates a unique file and never overwrites an existing attachment. Invalid UTF-8 and empty input fail without creating an attachment. The editor draft is stored at `${XDG_DATA_HOME:-~/.local/share}/promptslip/draft.txt`. On first GUI launch, if that draft is absent, PromptSlip safely copies a draft from the historical `pastedrop/draft.txt` or `PasteDrop/draft.txt` location. The old draft and attachments stay in place; migration only copies the draft and never replaces an existing PromptSlip draft. If reading or copying fails, the app reports the path and reason and leaves the old draft untouched.

Names are reduced to a safe filename stem (path separators, controls, and common invalid filename punctuation become `_`; dot-only names fall back to `prompt`). The `.md`/`.txt` extension is selected by the program.

## Acceptance checks

After building, run `sh ./test-cli.sh ./build/promptslip`. This checks exact CRLF/UTF-8 preservation above 1 MiB, unique snapshots, name containment, TXT selection, strict invalid input, empty input, reserved names, and malformed options. With Xvfb, `xdotool`, `timeout`, and GTK 3 development files installed, `sh ./smoke-gui.sh ./build/promptslip` opens the GUI and a test URI-list receiver, drags typed content into it, checks the transferred bytes, closes the app window, and checks draft persistence. This synthetic receiver check does not prove a browser accepted a dragged attachment; confirm the file appears in the target website before sending.
