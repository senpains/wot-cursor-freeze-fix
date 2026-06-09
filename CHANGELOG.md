# Changelog

## 0.2.0 - 2026-06-10

- Added support for WoT `2.3.0.1476 #2555989`.
- Added a second verified patch target:
  - RVA `0x3c5663`
  - original bytes `74 09`
  - patched bytes `74 18`
- Kept the previous WoT `2.2.1.x` target at RVA `0x3c5633`.
- Updated the patcher to choose the matching known target by reading process bytes and to fail closed if no known target matches.
- Added `tools/find-patch-candidate.ps1` for future update analysis.

## 0.1.0 - 2026-05-09

- Initial public package of the in-memory World of Tanks cursor-freeze workaround.
- Adds a fail-closed patcher for the verified byte patch:
  - RVA `0x3c5633`
  - original bytes `74 09`
  - patched bytes `74 18`
- Adds manual apply/status/rollback PowerShell scripts.
- Adds optional scheduled-task autopatcher for applying the in-memory patch after WoT starts.
- Adds technical notes and post/ticket drafts.
