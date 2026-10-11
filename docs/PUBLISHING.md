# Publication details

This note records the public listing and release state. The GitHub repository is public at [huichuanzhou-cmd/PromptSlip](https://github.com/huichuanzhou-cmd/PromptSlip), on `main`; it was created empty. Its [Releases page](https://github.com/huichuanzhou-cmd/PromptSlip/releases) currently has no published assets. A public repository does not mean a binary release or a source upload has happened.

## Repository listing

**Description**

> Turn long AI prompts into drag-and-drop Markdown or TXT attachments. Lightweight, native, and fully local.

**Topics**

`clipboard`, `drag-and-drop`, `markdown`, `ai-tools`, `developer-tools`, `productivity`, `prompt-engineering`

The product name is **PromptSlip** and the tagline is **Paste. Drag. Done.** The copyright attribution in `LICENSE` is `huichuanzhou-cmd`, as authorized by the owner. The license is MIT.

## Release status and claims

- Keep the version label at `0.2.0-preview`; do not present it as a stable release.
- Use the GitHub Releases page as the download entry point, but link to individual assets only after confirming they exist.
- Preserve the separate Windows portable GUI data at `数据/` and `文件/` beside the app. The CLI uses `Documents/PromptSlip/files`; an updated default does not move or delete older `PasteDrop` data.
- Keep macOS and Linux marked Experimental / Preview until native build and runtime acceptance are recorded. Current checks may change; refer to dated [validation](VALIDATION.md), not an undated assertion.
- Do not claim browser upload success without a real browser check that the attachment appears at the destination. Upload does not prove complete model ingestion.
- Do not add fabricated product screenshots. No screenshot is included because no genuine capture is available.
- macOS distribution needs appropriate signing and notarization before recommending normal end-user launch. Do not tell users to disable system security controls.
- Linux release notes must state the GTK 3 dynamic-library requirement and that X11/Wayland have not been verified.

## Validation and packaging

Before publishing a release asset, build the actual archive, inspect its contents and links, and record checks corresponding to the claims in the release notes. The independent Windows package flattens the bilingual Windows guides into its root; their packaged links must resolve to root-level `LICENSE` and `verification.json`. Local validation and a configured CI workflow are not evidence that a GitHub Actions run passed. Local renamed Windows build/tests passed on 2026-10-12; native CI remains pending the first source push.

Historical name-search findings are summarized in [NAMING.md](NAMING.md); that bounded check was not legal review or trademark clearance.
