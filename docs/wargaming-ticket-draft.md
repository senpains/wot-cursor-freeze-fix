# Wargaming Ticket Draft

Subject:

```text
World of Tanks freezes when showing cursor in battle due to repeated ShowCursor(FALSE) counter underflow
```

Body:

```text
Hello.

I investigated a recurring World of Tanks freeze where the client stalls for 1-3 seconds when the battle UI shows the mouse cursor. The visible triggers are Ctrl, Esc, in-game Tab, and opening chat, but the common operation is cursor show.

The freeze length depends on hidden mouse movement:

- little/no hidden mouse movement before pressing Ctrl/Esc: cursor show is fast;
- active hidden mouse movement before pressing Ctrl/Esc: cursor show freezes for up to several seconds;
- repeated Ctrl/Esc immediately after the first one is fast.

ETW stack during the freeze:

GUI.MouseCursor.visible=True
-> WorldOfTanks native cursor helper
-> USER32!ShowCursor(TRUE)
-> win32k!NtUserShowCursor
-> zzzShowCursor
-> zzzEndDeferWinEventNotify
-> xxxFlushDeferredWindowEvents

The hidden mouse path also enters the same WoT native cursor helper from DirectInput/User32:

dinput8
-> user32
-> WorldOfTanks!0x1403c564d
-> WorldOfTanks!0x142198b0d

The helper at WorldOfTanks!0x142198ae0 appears to loop:

- ShowCursor(TRUE) until the return value is non-negative;
- ShowCursor(FALSE) until the return value is negative.

The issue is that the hide path can be entered repeatedly while the cursor is already hidden, driving the Win32 ShowCursor display counter deeply negative. The next cursor show then has to call ShowCursor(TRUE) many times and synchronously flushes Win32k deferred cursor/window events.

I confirmed a local workaround by skipping the repeated hide helper call in the WndProc/DirectInput branch:

WorldOfTanks.exe RVA: 0x3c5633
74 09 -> 74 18

With this in-memory patch, after 32 seconds and 8612 hidden mouse events, cursor show stayed at 0-2 ms. Before the patch, comparable conditions produced freezes in hundreds or thousands of milliseconds.

Please consider making the native cursor hide operation idempotent, or avoid repeatedly calling ShowCursor(FALSE) when the cursor is already hidden.

I can provide additional logs/details if needed.
```
