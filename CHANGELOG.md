# Changelog

## 0.2.0-preview — 2026-10-12

- Renamed PasteDrop to PromptSlip, including native GUI/CLI, metadata, scripts, archive names and bilingual documentation.
- Preserved Windows portable data and added safe legacy-draft compatibility on macOS/Linux without deleting old files or replacing new drafts.
- Passed native Windows, macOS Intel, macOS Apple Silicon and Linux CI; Linux Xvfb file drag/close-save also passed. Desktop/browser acceptance remains a separate unverified scope.
- Fixed lipo argument ordering, GTK smoke quoting and macOS /var path-alias handling in the test fixture; retained containment checks and executable shell modes.
- Prepared Windows/source preview assets, explicitly Experimental macOS/Linux assets and SHA-256 checksums.

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
