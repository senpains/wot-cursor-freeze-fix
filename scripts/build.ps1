$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

$src = Join-Path $Script:FixRoot 'src\WotCursorHideCallPatch.cs'
$outDir = Join-Path $Script:FixRoot 'bin'
$out = Join-Path $outDir 'WotCursorHideCallPatch.exe'

if (!(Test-Path -LiteralPath $src)) {
    throw "Source file is missing: $src"
}

$candidates = @(
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
)

$cscFromPath = Get-Command csc.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($cscFromPath) {
    $candidates += $cscFromPath.Source
}

$csc = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (!$csc) {
    throw "Could not find csc.exe. Install .NET Framework Developer Pack / Build Tools, or use a release zip with bin\WotCursorHideCallPatch.exe."
}

New-Item -ItemType Directory -Path $outDir -Force | Out-Null

& $csc /nologo /optimize+ /platform:x64 /target:exe /out:$out $src
if ($LASTEXITCODE -ne 0) {
    throw "csc.exe failed with exit code $LASTEXITCODE"
}

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $out
Write-Host "Built: $out"
Write-Host "SHA256: $($hash.Hash)"
