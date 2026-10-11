# Changelog

## 0.2.0-preview — 2026-10-12

- Finalized the product and public repository name as **PromptSlip** and updated the bilingual product introduction to “Lightweight AI Prompt File Transfer.”
- Added the public repository and Releases page as the download entry point; no release assets are published yet.
- Clarified the 30-second Windows GUI flow, Markdown default and optional TXT output, local-only operation, and the boundary between creating an attachment and uploading it.
- Recorded storage compatibility: existing Windows portable `数据/` and `文件/` remain beside the app, while the Windows CLI default is `Documents/PromptSlip/files`; changing that CLI default does not move or delete older `PasteDrop` data.
- Kept legacy-draft safety and compatibility checks explicitly scoped by platform; macOS/Linux follow-up work still needs its own implementation evidence and native CI result.
- Kept browser/service compatibility as an untested usage scenario, and preserved macOS/Linux preview and verification limits.
- Updated historical naming, validation, download, and publication notes to distinguish prior evidence from the current documentation update. CI and newly built Windows binaries are not claimed as passing in this change.

## 0.2.0-preview — 2026-10-11

Release-readiness work for the native Windows, macOS, and Linux preview.

- Added bilingual English/Chinese product documentation and separate Windows guides.
- Clarified that the core flow creates a local `.md` attachment by default, with `.txt` available, and does not upload or send it.
- Recorded Windows GUI portable storage and the distinct CLI default path.
- Marked macOS and Linux Experimental / Preview because compilation and runtime checks were `NOT_RUN` at that time.
- Documented local plaintext storage, platform dependencies, build commands, and verification limits.
- Preserved corrupted Windows/macOS drafts in unique backups so new edits can be saved without discarding the old bytes; Mac execution was pending.
- Added Windows actual ACL write-denial/retry coverage and a read-only actual clipboard test.
- Made duplicate CLI options fail consistently; updated common subprocess acceptance.
- Prepared standalone bilingual Windows ZIP links, source/package allowlists and SHA-256 output.
- Prepared push/PR/manual CI, separate Intel/arm64 Mac hosts, universal-slice checks and GTK Xvfb checks. CI was `NOT_RUN` in the recorded local validation.

Version remains 0.2.0. The historical asset suffix changed from `native-preview` to `preview`. No GitHub Release was published as of the 2026-10-11 validation record.
