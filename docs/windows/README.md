# PromptSlip for Windows

**Paste. Drag. Done.** A local way to turn AI prompts and briefs into real file attachments.

[简体中文](README.zh-CN.md) · [License](../../LICENSE) · [Verification record](../../verification.json)

## Portable app

Unzip the Windows package and run `PromptSlip.exe`. Paste or type text, review the filename and content, then drag the file card into a site's attachment area. Markdown (`.md`) is the default; choose `.txt` if the site does not accept Markdown. Confirm that the destination shows the attachment before sending.

The current GUI labels are in Simplified Chinese; this English guide and the CLI are available. The destination must accept file uploads. Attachments do not increase the model's context window.

The Windows GUI stores draft and attachment data in `数据/` and `文件/` beside `PromptSlip.exe`. This is portable storage. If the program folder is read-only, PromptSlip reports the write error. It does not silently move data to LocalAppData. Move the entire portable folder to a location writable by your Windows account, then run the app there.

The GUI and CLI use different default folders. The CLI writes exported files to `Documents/PromptSlip/files` unless `--output-dir` is supplied.

## Command line

The package includes `PromptSlip.Cli.exe`. Choose one input source:

```powershell
.\PromptSlip.Cli.exe --clipboard --name prompt
.\PromptSlip.Cli.exe --clipboard --output-dir 'D:\Attachments' --txt
cmd /c "PromptSlip.Cli.exe --stdin < brief.md"
```

`--clipboard` explicitly reads the desktop text clipboard once. `--stdin` reads UTF-8 bytes and preserves line endings. PowerShell 5 text pipelines may use an encoding determined by local settings; redirecting a UTF-8 file through `cmd /c` preserves the file bytes. Optional arguments are `--output-dir DIR`, `--name NAME`, and `--txt`; use `--help` for usage. Success prints the created file's absolute path to stdout. That path is not an upload.

## Limits and local data

Drafts and attachments are stored as plaintext on this device. Protect the Windows account and remove files yourself when they are no longer needed. PromptSlip has no account or API, does not contact a network service, and does not send messages. A destination site may reject an attachment due to its limits. Successful upload does not guarantee the AI service read the complete file; keep critical instructions in the prompt and request confirmation when needed.

## Verification and package contents

The verification record distinguishes user-reported drag success (`USER_REPORTED`) from automated results. Windows core, GUI storage, subprocess stdin and actual desktop clipboard-to-CLI checks passed locally; native mouse drag and browser upload were not automated in this round. Read [verification.json](../../verification.json) for exact scope.

The portable ZIP contains `PromptSlip.exe`, `PromptSlip.Cli.exe`, English `README.md`, Chinese `README.zh-CN.md`, `LICENSE` and `verification.json`, all at its root. Its guides work offline and do not link to source-only platform folders.

Invalid UTF-8 drafts are preserved in a uniquely named `.corrupt-*` backup before saving new edits. If the original cannot be read or backed up, the error is shown and it is protected from overwrite. Earlier attachments are not automatically removed.

License: [MIT](../../LICENSE).
