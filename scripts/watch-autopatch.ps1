$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '_common.ps1')

$pollSeconds = 2
$logFile = 'autopatch.log'

function Invoke-Patcher {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mode,

        [Parameter(Mandatory = $true)]
        [int]$ProcessId
    )

    $output = & $Script:PatcherPath $Mode --pid $ProcessId 2>&1
    return @{
        ExitCode = $LASTEXITCODE
        Text = ($output -join ' | ')
    }
}

Write-FixLog -FileName $logFile -Message "START watcher pid=$PID patcher=$Script:PatcherPath"

$seen = @{}

while ($true) {
    try {
        if (!(Test-Path -LiteralPath $Script:PatcherPath)) {
            Write-FixLog -FileName $logFile -Message "ERROR patcher_missing path=$Script:PatcherPath"
            Start-Sleep -Seconds 30
            continue
        }

        $processes = @(Get-Process -Name WorldOfTanks -ErrorAction SilentlyContinue)
        if ($processes.Count -eq 0) {
            $seen.Clear()
            Start-Sleep -Seconds $pollSeconds
            continue
        }

        foreach ($proc in $processes) {
            $pidText = [string]$proc.Id
            if ($seen.ContainsKey($pidText) -and $seen[$pidText] -eq 'patched') {
                continue
            }

            $status = Invoke-Patcher -Mode 'status' -ProcessId $proc.Id
            if ($status.Text -match 'status=patched') {
                $seen[$pidText] = 'patched'
                Write-FixLog -FileName $logFile -Message "ALREADY_PATCHED pid=$($proc.Id) $($status.Text)"
                continue
            }

            if ($status.Text -notmatch 'status=original') {
                $seen[$pidText] = 'unknown'
                Write-FixLog -FileName $logFile -Message "STATUS_NOT_ORIGINAL pid=$($proc.Id) exit=$($status.ExitCode) output=$($status.Text)"
                continue
            }

            $apply = Invoke-Patcher -Mode 'apply' -ProcessId $proc.Id
            if ($apply.ExitCode -eq 0 -and $apply.Text -match 'patched hide branch|already patched|status=patched') {
                $seen[$pidText] = 'patched'
                Write-FixLog -FileName $logFile -Message "PATCHED pid=$($proc.Id) $($apply.Text)"
            } else {
                $seen[$pidText] = 'apply_failed'
                Write-FixLog -FileName $logFile -Message "APPLY_FAILED pid=$($proc.Id) exit=$($apply.ExitCode) output=$($apply.Text)"
            }
        }
    } catch {
        Write-FixLog -FileName $logFile -Message "EXCEPTION $($_.Exception.GetType().FullName): $($_.Exception.Message)"
    }

    Start-Sleep -Seconds $pollSeconds
}
