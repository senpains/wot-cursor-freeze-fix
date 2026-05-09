$ErrorActionPreference = 'Stop'

$Script:FixRoot = Split-Path -Parent $PSScriptRoot
$Script:PatcherPath = Join-Path $Script:FixRoot 'bin\WotCursorHideCallPatch.exe'
$Script:LogDir = Join-Path $Script:FixRoot 'logs'

function Ensure-LogDir {
    if (!(Test-Path -LiteralPath $Script:LogDir)) {
        New-Item -ItemType Directory -Path $Script:LogDir -Force | Out-Null
    }
}

function Ensure-Patcher {
    if (!(Test-Path -LiteralPath $Script:PatcherPath)) {
        throw "Patch executable is missing: $Script:PatcherPath. Run scripts\build.ps1 or download a release with bin\WotCursorHideCallPatch.exe."
    }
}

function Write-FixLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    try {
        Ensure-LogDir
        $path = Join-Path $Script:LogDir $FileName
        Add-Content -LiteralPath $path -Value ("{0:yyyy-MM-dd HH:mm:ss.fff} {1}" -f (Get-Date), $Message)
    } catch {
    }
}
