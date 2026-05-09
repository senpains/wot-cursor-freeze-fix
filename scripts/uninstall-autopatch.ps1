$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

Ensure-LogDir

$taskName = 'WoT Cursor Freeze Fix AutoPatch'
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-FixLog -FileName 'autopatch.log' -Message "UNINSTALLED task='$taskName'"
    Write-Host "Uninstalled scheduled task: $taskName"
} else {
    Write-Host "Scheduled task not found: $taskName"
}

Write-Host "Note: uninstalling autopatch does not modify an already-running WoT process."
Write-Host "To remove the in-memory patch from a running game, run scripts\rollback.ps1 or restart WoT."
