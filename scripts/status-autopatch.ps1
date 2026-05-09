$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

$taskName = 'WoT Cursor Freeze Fix AutoPatch'
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (!$task) {
    Write-Host "autopatch_task=absent"
    exit 0
}

$info = Get-ScheduledTaskInfo -TaskName $taskName
[pscustomobject]@{
    autopatch_task = 'present'
    state = $task.State
    lastRunTime = $info.LastRunTime
    lastTaskResult = $info.LastTaskResult
    nextRunTime = $info.NextRunTime
    taskPath = $task.TaskPath
    taskName = $task.TaskName
} | Format-List

$log = Join-Path $Script:LogDir 'autopatch.log'
if (Test-Path -LiteralPath $log) {
    Write-Host ''
    Write-Host 'Last autopatch log lines:'
    Get-Content -LiteralPath $log -Tail 10
}
