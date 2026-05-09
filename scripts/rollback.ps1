$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

Ensure-Patcher
Ensure-LogDir

$log = Join-Path $Script:LogDir 'patch.log'
$output = & $Script:PatcherPath rollback 2>&1
$exitCode = $LASTEXITCODE
$output | Tee-Object -FilePath $log -Append
exit $exitCode
