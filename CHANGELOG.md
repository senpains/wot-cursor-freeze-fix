# Changelog

## 0.1.0 - 2026-05-09

- Initial public package of the in-memory World of Tanks cursor-freeze workaround.
- Adds a fail-closed patcher for the verified byte patch:
  - RVA `0x3c5633`
  - original bytes `74 09`
  - patched bytes `74 18`
- Adds manual apply/status/rollback PowerShell scripts.
- Adds optional scheduled-task autopatcher for applying the in-memory patch after WoT starts.
- Adds technical notes and post/ticket drafts.
