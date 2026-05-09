$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

Ensure-Patcher
Ensure-LogDir

$watcher = Join-Path $PSScriptRoot 'watch-autopatch.ps1'
$taskName = 'WoT Cursor Freeze Fix AutoPatch'

if (!(Test-Path -LiteralPath $watcher)) {
    throw "Watcher script is missing: $watcher"
}

$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watcher`""
$userId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

$action = New-ScheduledTaskAction -Execute $powershell -Argument $arguments -WorkingDirectory $Script:FixRoot
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
$principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 365) -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Auto-applies the in-memory WoT cursor freeze fix after WorldOfTanks.exe starts.' | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-FixLog -FileName 'autopatch.log' -Message "INSTALLED task='$taskName' watcher='$watcher'"

Write-Host "Installed and started scheduled task: $taskName"
Write-Host "Watcher: $watcher"
Write-Host "Log: $(Join-Path $Script:LogDir 'autopatch.log')"
