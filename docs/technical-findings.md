# Technical Findings

This file summarizes the confirmed investigation behind the workaround.

## Symptom

World of Tanks freezes when the battle UI needs to show the mouse cursor:

- `Ctrl`
- `Esc`
- in-game tab / tactical UI
- chat / `Enter`

The freeze length depends on hidden mouse movement before the cursor is shown:

- after little/no mouse movement: next cursor show is fast;
- after active hidden mouse movement: next cursor show can freeze for 1-3 seconds;
- repeated cursor shows immediately after the first one are fast.

## Confirmed Blocking Stack

ETW stackwalk during the actual freeze showed:

```text
GUI.MouseCursor.visible=True
-> WorldOfTanks native cursor helper
-> USER32!ShowCursor(TRUE)
-> win32k!NtUserShowCursor
-> zzzShowCursor
-> zzzEndDeferWinEventNotify
-> xxxFlushDeferredWindowEvents
```

The thread was not blocked in Python GUI rendering, mods, network, or overlay code. It was synchronously inside the Windows cursor / Win32k path.

## Producer Path Before The Freeze

Hidden mouse movement produced a large Win32k event/message storm in WoT's own native message pump:

```text
NtUserPeekMessage
-> USER32!PeekMessageW
-> WorldOfTanks!0x1403c4a3d
```

The DirectInput/User32 hidden cursor path also entered WoT's native cursor helper:

```text
dinput8
-> user32
-> WorldOfTanks!0x1403c564d
-> WorldOfTanks!0x142198b0d
```

The WinEvent type was identified as cursor location change:

```text
EVENT_OBJECT_LOCATIONCHANGE
idObject = OBJID_CURSOR (-9)
hwnd = 0
```

## Native Cursor Helper

The WoT/BigWorld helper at `WorldOfTanks!0x142198ae0` behaves like this:

```text
show branch:
  call USER32!ShowCursor(TRUE)
  loop until the return value is >= 0

hide branch:
  call USER32!ShowCursor(FALSE)
  loop until the return value is < 0
```

That is a common-looking pattern, but it becomes dangerous if the hide branch is entered repeatedly while the cursor is already hidden. Each `ShowCursor(FALSE)` decrements the thread-local Win32 cursor display counter.

## Counter Underflow Mechanism

The bug chain:

```text
hidden mouse movement
-> WoT native DirectInput/User32 cursor path
-> repeated hide branch
-> repeated ShowCursor(FALSE)
-> Win32 cursor display counter becomes deeply negative
-> player presses Ctrl/Esc/Tab/chat
-> WoT calls ShowCursor(TRUE) in a loop until the counter is repaired
-> each call enters Win32k cursor/deferred-window-event flush path
-> visible freeze
```

This explains why elapsed time alone is not the true trigger. Active hidden mouse movement is the load source.

## External Counter Repro

A separate repro intentionally called `ShowCursor(FALSE)` on every hidden `WM_MOUSEMOVE`.

Observed output:

```text
manual_show_ControlKey ms=9.713 loops=128 result=-12287
```

The repro capped repair at 128 loops. The result means the counter was roughly around `-12415`. WoT has no such cap in the observed helper, so it may call `ShowCursor(TRUE)` thousands of times.

## Patch

Target:

```text
WorldOfTanks.exe RVA: 0x3c5633
original bytes:       74 09
patched bytes:        74 18
```

Meaning:

```text
WorldOfTanks!0x1403c5631  test al, al
WorldOfTanks!0x1403c5633  je   ...
```

Changing `je +0x09` to `je +0x18` makes the WndProc/DirectInput hide branch skip the native `ShowCursor(FALSE)` helper call.

The show branch remains intact.

## Positive WoT Validation

After applying the patch in memory:

```text
show_count=19
max_visible_ms=2
avg_visible_ms=0.632
max_total_ms=2
max_mouse_count=8612
max_age_ms=32118
```

Strongest confirmation:

```text
age_ms=32118
count=8612
sum_abs_dx=453486
sum_abs_dy=266737
show.cursor.visible=True elapsed_ms=0.000
CursorManager.show.timing elapsed_ms=2.000
```

Before the patch, comparable hidden mouse movement produced freezes in hundreds or thousands of milliseconds. With the patch, cursor show stayed within 0-2 ms.

## Ruled Out For The Confirmed Case

These were not sufficient/root causes for the confirmed freeze:

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
- two-monitor layout by itself.

## Safety Model

The patcher fails closed:

- reads current bytes first;
- applies only if current bytes are exactly `74 09`;
- treats `74 18` as already patched;
- refuses to apply or rollback on any unexpected bytes;
- patches only process memory, not the file on disk.

Restarting WoT removes the patch.
