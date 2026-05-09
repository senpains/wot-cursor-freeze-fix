# WoT Cursor Freeze Fix

Language: [English](README.md) | [Russian](README.ru.md)

> README fully written by GPT, just like the fix itself. Prepare to read a bit of AI slop =)

An in-memory workaround for a World of Tanks battle freeze that happens when the game shows the cursor: `Ctrl`, `Esc`, in-game `Tab`, chat/`Enter`, and similar UI actions.

## Short Version

Some WoT clients can freeze for 1-3 seconds when the battle UI shows the mouse cursor after it has been hidden for a while. The more you move the mouse while the cursor is hidden, the longer the next cursor-show freeze can become.

This fix:

- patches the memory of an already running `WorldOfTanks.exe` process;
- does not modify `WorldOfTanks.exe` on disk;
- does not install anything into `res_mods`;
- does not change Windows, driver, overlay, or game settings;
- disappears automatically when WoT exits, because it exists only in process memory;
- refuses to patch if the target bytes do not match the verified client build.

Verified patch:

```text
WorldOfTanks.exe RVA: 0x3c5633
original bytes:       74 09
patched bytes:        74 18
```

## Important Warning

This is **not a normal WoT mod** and it is not a `.wotmod` package for the `mods` or `res_mods` folders.

This is an external runtime patcher. It opens `WorldOfTanks.exe` and changes 2 bytes in the running process memory. The patch is narrow and targets only the cursor bug described here, but any memory patcher can be sensitive from an anticheat / game-rules point of view.

Use it at your own risk. The proper final fix should come from Wargaming.

## Who This Is For

This workaround is worth trying if your symptoms match this pattern:

- the freeze happens specifically when the battle UI shows the cursor;
- the triggers are `Ctrl`, `Esc`, in-game `Tab`, chat/`Enter`, or similar cursor-show actions;
- pressing the same key again immediately after the first freeze is fast;
- if you actively move the mouse for a minute while the cursor is hidden, the next cursor show freezes harder;
- if you barely move the mouse for a minute, the next cursor show is fast or almost fast.

This is not meant to fix network lag, graphics FPS drops, asset-loading stutter, mod issues, or unrelated alt-tab hangs.

## Quick Install

1. Download a release zip or clone the repository.
2. Extract it anywhere, for example:

```text
C:\Tools\wot-cursor-freeze-fix
```

3. Start WoT.
4. Open PowerShell in the fix folder.
5. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply.ps1
```

Expected successful output:

```text
target=WorldOfTanks.exe pid=... base=0x... rva=0x3C5633 address=0x... current=74 09
status=patched
patched hide branch: je +0x09 -> je +0x18
```

Check status:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\status.ps1
```

Expected status after applying:

```text
current=74 18
status=patched
```

## Automatic Apply On WoT Start

Because the patch lives only in process memory, it must be applied again after every WoT restart. For convenience, this package includes an optional Windows Scheduled Task based autopatcher.

Install the autopatcher:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-autopatch.ps1
```

What it does:

- creates a Windows Scheduler task named `WoT Cursor Freeze Fix AutoPatch`;
- starts at user logon;
- runs `scripts\watch-autopatch.ps1` in the background;
- checks every 2 seconds whether `WorldOfTanks.exe` is running;
- applies the patch if the game is running and the bytes are original `74 09`;
- does nothing if the bytes are already patched `74 18`;
- logs and refuses to patch if the bytes are unexpected.

Check autopatcher status:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\status-autopatch.ps1
```

Uninstall the autopatcher:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall-autopatch.ps1
```

Important: uninstalling the autopatcher does not change an already running WoT process. To remove the patch from the current game process, run rollback or restart WoT.

## Manual Rollback

If WoT is running and you want to restore the original bytes without restarting the game:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\rollback.ps1
```

Expected output:

```text
current=74 18
status=original
rolled back hide branch patch
```

The simplest rollback is closing WoT and starting it again. The patch is never written to the game file on disk.

## Version Compatibility

This release was confirmed on the WoT client build investigated on 2026-05-09. In that build, the target instruction is at RVA `0x3c5633` and the original bytes are `74 09`.

After a WoT update, several things can happen:

- the code did not change: the patcher should still work;
- the code moved or changed: the patcher should detect unexpected bytes and refuse to write;
- Wargaming fixed the bug: this workaround may no longer be needed;
- Wargaming rewrote this area: a new analysis and patcher update would be required.

This fail-closed behavior is intentional. Getting `status=unknown` is much better than writing bytes into the wrong place.

If you get `status=unknown`, do not force the patch. Open an issue and include:

- full output of `scripts\status.ps1`;
- WoT region and client version;
- date of the latest client update;
- path to `WorldOfTanks.exe`;
- Windows version/build;
- symptom description.

## How It Works In Plain English

Windows has an old API called `ShowCursor`. It uses a cursor display counter:

- `ShowCursor(FALSE)` decrements the counter;
- `ShowCursor(TRUE)` increments the counter;
- the cursor is visible when the counter is `>= 0`;
- the cursor is hidden when the counter is `< 0`.

Code should not keep calling `ShowCursor(FALSE)` when the cursor is already hidden. If it does, the counter can go deeply negative.

In the investigated WoT/BigWorld client, the native cursor helper behaves roughly like this:

```text
show:
  call ShowCursor(TRUE) until counter >= 0

hide:
  call ShowCursor(FALSE) until counter < 0
```

The problem is that hidden mouse movement in battle can repeatedly enter the hide branch while the cursor is already hidden. This drives the `ShowCursor` counter deeply negative.

Then the player presses `Ctrl`, `Esc`, opens chat, or opens another UI. WoT needs to show the cursor and starts repairing the counter through many `ShowCursor(TRUE)` calls. During those calls, the game thread synchronously enters the Windows `win32k` cursor / deferred-window-event path:

```text
NtUserShowCursor
-> zzzShowCursor
-> zzzEndDeferWinEventNotify
-> xxxFlushDeferredWindowEvents
```

That synchronous Windows work is the visible freeze.

The patch changes one conditional jump so WoT skips the repeated native hide call in the WndProc/DirectInput branch. Cursor showing still works, but hidden mouse movement no longer pushes the Win32 `ShowCursor` counter into a huge negative value.

## What Exactly Is Patched

Verified area:

```text
WorldOfTanks!0x1403c5631  test al, al
WorldOfTanks!0x1403c5633  je   ...
```

Original bytes:

```text
74 09
```

Patched bytes:

```text
74 18
```

Meaning:

- the original `je +0x09` still reached a branch that called the native cursor helper for hide;
- the new `je +0x18` jumps over that hide call;
- the show path with `dl=1` is left intact.

## Evidence

During the real WoT freeze, ETW showed this blocking stack:

```text
GUI.MouseCursor.visible=True
-> WorldOfTanks native cursor helper
-> USER32!ShowCursor(TRUE)
-> win32k!NtUserShowCursor
-> zzzShowCursor
-> zzzEndDeferWinEventNotify
-> xxxFlushDeferredWindowEvents
```

Hidden mouse movement entered the same native cursor helper from the DirectInput/User32 path:

```text
dinput8
-> user32
-> WorldOfTanks!0x1403c564d
-> WorldOfTanks!0x142198b0d
```

A separate repro that intentionally called `ShowCursor(FALSE)` on every hidden mouse move proved deep counter underflow:

```text
manual_show_ControlKey ms=9.713 loops=128 result=-12287
```

The repro capped repair at 128 loops. That result means the counter was roughly around `-12415`. The observed WoT helper had no such 128-loop cap, so it could run thousands of `ShowCursor(TRUE)` calls.

After applying the patch in WoT:

```text
show_count=19
max_visible_ms=2
avg_visible_ms=0.632
max_total_ms=2
max_mouse_count=8612
max_age_ms=32118
```

The strongest validation: after 32 seconds and 8612 hidden mouse events, cursor show stayed within 0-2 ms. Before the patch, comparable conditions produced freezes in hundreds or thousands of milliseconds.

More details are in [docs/technical-findings.md](docs/technical-findings.md).

## Building From Source

If you do not want to use the prebuilt `bin\WotCursorHideCallPatch.exe`, build it yourself:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

The script looks for `csc.exe` from .NET Framework:

```text
%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
```

Output:

```text
bin\WotCursorHideCallPatch.exe
```

The SHA256 of the included binary is listed in `CHECKSUMS.sha256`.

## Project Layout

```text
wot-cursor-freeze-fix\
  README.md
  README.ru.md
  CHANGELOG.md
  CHECKSUMS.sha256
  RELEASE_CHECKLIST.md
  VERSION.txt
  src\
    WotCursorHideCallPatch.cs
  bin\
    WotCursorHideCallPatch.exe
  scripts\
    build.ps1
    apply.ps1
    rollback.ps1
    status.ps1
    install-autopatch.ps1
    uninstall-autopatch.ps1
    status-autopatch.ps1
    watch-autopatch.ps1
  docs\
    technical-findings.md
    reddit-post-draft.md
    wargaming-ticket-draft.md
  logs\
    .gitkeep
```

## Troubleshooting

### `WorldOfTanks.exe is not running`

Start WoT and run the command again.

### `status=unknown`

The client version does not match the verified byte signature, or Wargaming changed the code. The patcher correctly refused to write. Do not force the patch.

### `OpenProcess failed: 5`

This usually means a permission mismatch. Run the patcher as the same user and with the same privilege level as WoT. If WoT is running as administrator, PowerShell must also be running as administrator.

### PowerShell blocks script execution

Use `-ExecutionPolicy Bypass` for this command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply.ps1
```

### The patch disappears after restarting the game

That is expected. The patch exists only in process memory. Install the autopatcher with `scripts\install-autopatch.ps1` or apply it manually after starting WoT.

### Antivirus warning

The patcher uses `OpenProcess`, `ReadProcessMemory`, `VirtualProtectEx`, and `WriteProcessMemory`. That is expected for this workaround, but these APIs may look suspicious to security tools. The source code is in `src\WotCursorHideCallPatch.cs`.

## What Was Not The Root Cause In The Confirmed Case

For the confirmed case, the evidence did not point to these as sufficient/root causes:

- WoT mods;
- reinstall/cache;
- VPN/network;
- WGC;
- RTSS/MSI Afterburner;
- NVIDIA App as sufficient/root;
- OBS/Discord overlay as sufficient/root;
- HAGS;
- mouse polling rate as root cause;
- Windows cursor crosshair setting;
- Windows cursor deadzone/jumping setting;
- dual-monitor layout by itself.

Some of these can affect timing or environment, but the confirmed mechanism was lower level: a repeated WoT/BigWorld native hide call drove the Win32 `ShowCursor` counter into underflow.

## FAQ

### Is this a mod?

No. It is an external memory patcher. It does not install into `mods` or `res_mods`.

### Does it modify game files?

No. It changes 2 bytes only in the memory of the running `WorldOfTanks.exe` process.

### Will it work on every WoT version?

No guarantee. The patcher safely refuses to run if the bytes at the verified RVA do not match.

### Why do most players not have this bug?

The bug appears to require a specific combination of WoT's native cursor path and Windows/input/win32k state. Many players either do not enter this bad path or do not accumulate enough cursor-counter debt for the next cursor show to become visibly expensive.

### Why do `Ctrl`, `Esc`, `Tab`, and chat freeze in the same way?

Because their shared expensive step is showing the system cursor. The specific UI window was not the root cause.

### What should the upstream fix be?

WoT/BigWorld should make cursor hiding idempotent: avoid repeated `ShowCursor(FALSE)` calls when the cursor is already hidden, or otherwise avoid driving the Win32 cursor display counter deeply negative.

## Issue Template

If the fix does not apply or does not help, please include:

```text
1. Output of scripts\status.ps1
2. Output of scripts\apply.ps1
3. WoT region/client version
4. Windows version/build
5. Mouse model and polling rate
6. Does the freeze depend on hidden mouse movement before pressing Ctrl/Esc?
7. Does restarting WoT temporarily remove the issue?
8. Any anticheat/antivirus warning text, if present
```
