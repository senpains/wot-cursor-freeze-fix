$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

Ensure-Patcher
& $Script:PatcherPath status
exit $LASTEXITCODE
