# WoT Cursor Freeze Fix
# README полностью написан GPT, как и сам фикс. Готовьтесь немного почитать нейрослоп =)

Локальный workaround для World of Tanks, который убирает фриз при первом показе курсора в бою: `Ctrl`, `Esc`, внутриигровой `Tab`, чат/`Enter` и похожие действия.

## Кратко

У некоторых игроков WoT может фризить на 1-3 секунды, когда игра впервые за долгое время показывает курсор в бою. Чем дольше до этого двигать мышкой со скрытым курсором, тем сильнее следующий фриз.

Этот фикс:

- патчит **память уже запущенного процесса** `WorldOfTanks.exe`;
- не изменяет `WorldOfTanks.exe` на диске;
- не устанавливает файлы в `res_mods`;
- не меняет настройки Windows, драйверов, оверлеев или игры;
- автоматически откатывается при перезапуске WoT, потому что живет только в памяти процесса;
- отказывается патчить, если байты в игре не совпадают с проверенной версией.

Проверенный патч:

```text
WorldOfTanks.exe RVA: 0x3c5633
original bytes:       74 09
patched bytes:        74 18
```

## Важное предупреждение

Это **не обычный WoT mod** и не `.wotmod` для папки `mods`/`res_mods`.

Это внешний runtime patcher: он открывает процесс `WorldOfTanks.exe` и меняет 2 байта в памяти процесса. По смыслу патч узкий и технически направлен только на баг с системным курсором, но любой memory patcher может быть чувствительной темой для античита и правил игры.

Используйте на свой риск. Лучший финальный вариант - чтобы Wargaming исправили этот баг в клиенте.

## Для кого этот фикс

Фикс имеет смысл пробовать, если симптомы совпадают:

- фриз появляется именно при показе курсора в бою;
- триггеры похожие: `Ctrl`, `Esc`, внутриигровой `Tab`, чат/`Enter`;
- после первого фриза повторное нажатие почти сразу работает быстро;
- если минуту активно двигать мышкой со скрытым курсором, следующий показ курсора фризит сильнее;
- если минуту почти не двигать мышкой, следующий показ курсора почти не фризит.

Фикс не предназначен для сетевых лагов, просадок FPS от графики, статтеров от загрузки ресурсов, проблем с модами или зависаний при alt-tab вне этого сценария.

## Быстрая установка

1. Скачайте release zip или склонируйте репозиторий.
2. Распакуйте папку куда угодно, например:

```text
C:\Tools\wot-cursor-freeze-fix
```

3. Запустите WoT.
4. Откройте PowerShell в папке фикса.
5. Выполните:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply.ps1
```

Ожидаемый успешный вывод:

```text
target=WorldOfTanks.exe pid=... base=0x... rva=0x3C5633 address=0x... current=74 09
status=patched
patched hide branch: je +0x09 -> je +0x18
```

Проверить статус:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\status.ps1
```

Ожидаемый статус после применения:

```text
current=74 18
status=patched
```

## Автоматическое применение при запуске WoT

Так как патч живет только в памяти процесса, после перезапуска игры его нужно применять снова. Для удобства есть автопатчер через Windows Scheduled Task.

Установить автопатчер:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-autopatch.ps1
```

Что он делает:

- создает задачу Windows Scheduler `WoT Cursor Freeze Fix AutoPatch`;
- задача стартует при входе пользователя в Windows;
- в фоне запускается `scripts\watch-autopatch.ps1`;
- watcher раз в 2 секунды проверяет, появился ли `WorldOfTanks.exe`;
- если игра запущена и байты оригинальные `74 09`, применяется патч;
- если уже `74 18`, ничего не делает;
- если байты неожиданные, пишет в лог и **не патчит**.

Проверить автопатчер:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\status-autopatch.ps1
```

Удалить автопатчер:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall-autopatch.ps1
```

Важно: удаление автопатчера не меняет уже запущенную игру. Чтобы убрать патч из текущего процесса WoT, выполните rollback или просто перезапустите игру.

## Ручной откат

Если WoT запущен и нужно вернуть оригинальные байты без перезапуска:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\rollback.ps1
```

Ожидаемый вывод:

```text
current=74 18
status=original
rolled back hide branch patch
```

Самый простой откат - закрыть и заново открыть WoT. Патч не записывается на диск, поэтому исчезает вместе с процессом.

## Совместимость с версиями WoT

Текущий релиз подтвержден на клиенте WoT, который был исследован 2026-05-09. В этой версии нужная инструкция находится по RVA `0x3c5633` и имеет байты `74 09`.

После обновления WoT возможны варианты:

- код не изменился: патчер продолжит работать;
- код сдвинулся или изменился: патчер увидит неожиданные байты и откажется писать;
- Wargaming исправили баг: патч может стать не нужен;
- Wargaming переписали этот участок: нужен новый анализ и новая версия патчера.

Это сделано специально. Лучше получить `status=unknown`, чем записать байты в случайное место.

Если вы получили `status=unknown`, не пытайтесь форсировать патч. Создайте issue и приложите:

- полный вывод `scripts\status.ps1`;
- регион и версию клиента WoT;
- дату обновления клиента;
- путь к `WorldOfTanks.exe`;
- Windows version/build;
- описание симптомов.

## Как это работает простыми словами

В Windows есть старый API `ShowCursor`. У него есть счетчик видимости курсора:

- `ShowCursor(FALSE)` уменьшает счетчик;
- `ShowCursor(TRUE)` увеличивает счетчик;
- курсор считается видимым, когда счетчик стал `>= 0`;
- курсор считается скрытым, когда счетчик `< 0`.

Нормальный код не должен бесконечно вызывать `ShowCursor(FALSE)`, если курсор уже скрыт. Иначе счетчик может уйти глубоко в минус.

В исследованной версии WoT/BigWorld есть native cursor helper, который делает примерно так:

```text
show:
  call ShowCursor(TRUE) until counter >= 0

hide:
  call ShowCursor(FALSE) until counter < 0
```

Проблема в том, что скрытое движение мыши в бою может повторно заходить в hide-ветку, когда курсор уже скрыт. Из-за этого счетчик `ShowCursor` уходит глубоко в минус.

Потом игрок нажимает `Ctrl`, `Esc`, открывает чат или другое окно. WoT должен показать курсор и начинает чинить счетчик через много вызовов `ShowCursor(TRUE)`. Во время этих вызовов поток игры синхронно попадает в Windows `win32k` путь курсора и deferred window events:

```text
NtUserShowCursor
-> zzzShowCursor
-> zzzEndDeferWinEventNotify
-> xxxFlushDeferredWindowEvents
```

Это и выглядит как фриз.

Патч меняет один conditional jump так, чтобы WoT пропускал лишний native hide call в WndProc/DirectInput ветке. Показ курсора остается рабочим, но движение мыши со скрытым курсором больше не загоняет счетчик в огромный минус.

## Что именно патчится

Проверенный участок:

```text
WorldOfTanks!0x1403c5631  test al, al
WorldOfTanks!0x1403c5633  je   ...
```

Оригинально:

```text
74 09
```

После патча:

```text
74 18
```

Смысл:

- оригинальный `je +0x09` вел в ветку, которая все равно вызывала native cursor helper для hide;
- новый `je +0x18` перепрыгивает через этот hide-вызов;
- show-ветка с `dl=1` не отключается.

## Доказательства из диагностики

В реальном WoT фриз на `GUI.MouseCursor.visible=True` шел по стеку:

```text
GUI.MouseCursor.visible=True
-> WorldOfTanks native cursor helper
-> USER32!ShowCursor(TRUE)
-> win32k!NtUserShowCursor
-> zzzShowCursor
-> zzzEndDeferWinEventNotify
-> xxxFlushDeferredWindowEvents
```

Скрытое движение мыши входило в тот же native cursor helper из DirectInput/User32 пути:

```text
dinput8
-> user32
-> WorldOfTanks!0x1403c564d
-> WorldOfTanks!0x142198b0d
```

Отдельный repro с повторным `ShowCursor(FALSE)` на hidden mouse move показал глубокий underflow счетчика:

```text
manual_show_ControlKey ms=9.713 loops=128 result=-12287
```

То есть счетчик был примерно около `-12415`. В WoT нет такого лимита на 128 итераций, поэтому клиент мог делать тысячи `ShowCursor(TRUE)` вызовов подряд.

После применения патча проверка в WoT показала:

```text
show_count=19
max_visible_ms=2
avg_visible_ms=0.632
max_total_ms=2
max_mouse_count=8612
max_age_ms=32118
```

Самый важный тест: после 32 секунд и 8612 событий скрытой мыши показ курсора занял 0-2 мс. До патча похожие условия давали сотни или тысячи миллисекунд.

Больше технических деталей лежит в [docs/technical-findings.md](docs/technical-findings.md).

## Сборка из исходников

Если вы не хотите использовать готовый `bin\WotCursorHideCallPatch.exe`, соберите его сами:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

Скрипт ищет `csc.exe` из .NET Framework:

```text
%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
```

На выходе будет:

```text
bin\WotCursorHideCallPatch.exe
```

SHA256 готового бинарника из этого пакета указан в `CHECKSUMS.sha256`.

## Структура проекта

```text
wot-cursor-freeze-fix\
  README.md
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

Запустите WoT и повторите команду.

### `status=unknown`

Версия клиента не совпала с проверенной сигнатурой или Wargaming изменили код. Патчер правильно отказался писать. Не форсируйте патч.

### `OpenProcess failed: 5`

Обычно это означает проблему с правами. Запускайте патчер из того же пользователя и с тем же уровнем прав, что и WoT. Если WoT запущен от администратора, PowerShell тоже должен быть запущен от администратора.

### PowerShell запрещает запуск скриптов

Используйте запуск с bypass для конкретной команды:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply.ps1
```

### После перезапуска игры патч пропал

Это нормально. Патч живет только в памяти процесса. Установите автопатчер через `scripts\install-autopatch.ps1` или применяйте вручную после запуска WoT.

### Антивирус ругается

Патчер использует `OpenProcess`, `ReadProcessMemory`, `VirtualProtectEx` и `WriteProcessMemory`. Это нормальная техника для этого workaround, но такие API могут выглядеть подозрительно для защитного ПО. Исходник открыт в `src\WotCursorHideCallPatch.cs`.

## Что не является причиной этого конкретного бага

В ходе диагностики для подтвержденного случая были исключены как достаточная/root cause причина:

- моды WoT;
- reinstall/cache;
- VPN/network;
- WGC;
- RTSS/MSI Afterburner;
- NVIDIA App как достаточная причина;
- OBS/Discord overlay как достаточная причина;
- HAGS;
- polling rate мыши как root cause;
- Windows cursor crosshair setting;
- Windows cursor deadzone/jumping setting;
- двухмониторная конфигурация сама по себе.

Некоторые из этих факторов могут менять тайминги или окружение, но подтвержденный механизм был ниже: повторный WoT/BigWorld native hide call загонял Win32 `ShowCursor` counter в underflow.

## FAQ

### Это мод?

Нет. Это внешний memory patcher. Он не устанавливается в `mods` или `res_mods`.

### Он меняет файлы игры?

Нет. Он меняет 2 байта только в памяти запущенного процесса `WorldOfTanks.exe`.

### Он будет работать на любой версии WoT?

Не гарантировано. Патчер безопасно откажется работать, если байты по проверенному RVA не совпадают.

### Почему у большинства игроков нет этого бага?

Нужна комбинация конкретного WoT native cursor path и состояния Windows/input/win32k, при которой повторные скрытия курсора становятся дорогими при следующем показе. У многих игроков счетчик не уходит глубоко в минус или Windows path не накапливает такой объем работы.

### Почему `Ctrl`, `Esc`, `Tab` и чат фризят одинаково?

Потому что общий тяжелый шаг у них один: игра показывает системный курсор. Конкретное окно не было root cause.

### Какой правильный upstream fix?

WoT/BigWorld должен сделать скрытие курсора идемпотентным: не вызывать `ShowCursor(FALSE)` повторно, если курсор уже скрыт, или не доводить Win32 cursor display counter до глубокого отрицательного значения.

## Для issue

Если фикс не применился или не помог, приложите:

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
