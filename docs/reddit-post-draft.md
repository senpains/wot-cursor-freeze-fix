# Reddit Post Draft

Title idea:

```text
Possible fix/workaround for WoT freezing when pressing Ctrl/Esc/Tab/chat in battle
```

Post:

```text
I ran into a very specific World of Tanks freeze:

- the game freezes for 1-3 seconds when pressing Ctrl, Esc, in-game Tab, or opening chat;
- repeated presses right after the first one are fast;
- the freeze gets worse if I move the mouse for a while while the cursor is hidden;
- if I do not move the mouse before showing the cursor, the freeze is much smaller or absent.

After ETW tracing and disassembly, the problem in my case was not mods, overlays, VPN, reinstall/cache, WGC, RTSS, NVIDIA App, or polling rate as the root cause.

The actual blocking stack was:

GUI.MouseCursor.visible=True
-> WorldOfTanks native cursor helper
-> USER32!ShowCursor(TRUE)
-> win32k!NtUserShowCursor
-> zzzShowCursor
-> zzzEndDeferWinEventNotify
-> xxxFlushDeferredWindowEvents

The WoT/BigWorld native cursor helper repeatedly calls ShowCursor(FALSE) while the cursor is already hidden. That can drive the Win32 cursor display counter deeply negative. The next Ctrl/Esc/Tab/chat has to repair the counter by calling ShowCursor(TRUE) thousands of times, causing the freeze.

I made a small open-source workaround that patches 2 bytes in memory only:

WorldOfTanks.exe RVA: 0x3c5633
74 09 -> 74 18

It does not modify WorldOfTanks.exe on disk and it refuses to patch if the expected bytes do not match, so it should fail closed on unsupported versions.

Important warning: this is not a normal WoT mod. It is an external in-memory patcher. Use at your own risk. The proper fix should come from Wargaming/BigWorld by making cursor hiding idempotent.

GitHub:
<link here>
```

Short comment reply for people asking "why would this help?":

```text
Because Ctrl/Esc/Tab/chat all share one common operation: showing the system cursor. In my trace the freeze was not in the menu itself. It was inside USER32/Win32k while WoT was repairing a deeply negative ShowCursor counter.
```
