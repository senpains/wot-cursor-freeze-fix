param(
    [string]$ExePath = (Join-Path (Split-Path -Parent $PSScriptRoot) '..\win64\WorldOfTanks.exe')
)

$ErrorActionPreference = 'Stop'

$ExePath = [IO.Path]::GetFullPath($ExePath)
$bytes = [IO.File]::ReadAllBytes($ExePath)

function Read-U16([int]$Offset) { [BitConverter]::ToUInt16($bytes, $Offset) }
function Read-U32([int]$Offset) { [BitConverter]::ToUInt32($bytes, $Offset) }
function Read-I32([int]$Offset) { [BitConverter]::ToInt32($bytes, $Offset) }
function Read-U64([int]$Offset) { [BitConverter]::ToUInt64($bytes, $Offset) }
function Read-AsciiZ([int]$Offset) {
    $end = $Offset
    while ($end -lt $bytes.Length -and $bytes[$end] -ne 0) { $end++ }
    [Text.Encoding]::ASCII.GetString($bytes, $Offset, $end - $Offset)
}

$peOffset = Read-U32 0x3C
$sectionCount = Read-U16 ($peOffset + 6)
$optionalHeaderSize = Read-U16 ($peOffset + 20)
$optionalHeader = $peOffset + 24
$magic = Read-U16 $optionalHeader
$dataDirectory = if ($magic -eq 0x20b) { $optionalHeader + 112 } else { $optionalHeader + 96 }
$importDirectoryRva = Read-U32 ($dataDirectory + 8)
$sectionTable = $optionalHeader + $optionalHeaderSize

$sections = @()
for ($i = 0; $i -lt $sectionCount; $i++) {
    $offset = $sectionTable + $i * 40
    $name = [Text.Encoding]::ASCII.GetString($bytes, $offset, 8).Trim([char]0)
    $sections += [pscustomobject]@{
        Name = $name
        VirtualAddress = Read-U32 ($offset + 12)
        VirtualSize = Read-U32 ($offset + 8)
        RawSize = Read-U32 ($offset + 16)
        RawPointer = Read-U32 ($offset + 20)
    }
}

function Convert-RvaToOffset([uint32]$Rva) {
    foreach ($section in $sections) {
        $size = [Math]::Max($section.VirtualSize, $section.RawSize)
        if ($Rva -ge $section.VirtualAddress -and $Rva -lt ($section.VirtualAddress + $size)) {
            return [int]($section.RawPointer + ($Rva - $section.VirtualAddress))
        }
    }
    return $null
}

function Convert-OffsetToRva([int]$Offset) {
    foreach ($section in $sections) {
        if ($Offset -ge $section.RawPointer -and $Offset -lt ($section.RawPointer + $section.RawSize)) {
            return [uint32]($section.VirtualAddress + ($Offset - $section.RawPointer))
        }
    }
    return $null
}

function Find-Pattern([byte[]]$Bytes, [object[]]$Pattern) {
    $hits = New-Object System.Collections.Generic.List[int]
    $patternLength = $Pattern.Count
    for ($i = 0; $i -le $Bytes.Length - $patternLength; $i++) {
        $ok = $true
        for ($j = 0; $j -lt $patternLength; $j++) {
            $expected = $Pattern[$j]
            if ($null -ne $expected -and $Bytes[$i + $j] -ne [byte]$expected) {
                $ok = $false
                break
            }
        }
        if ($ok) { $hits.Add($i) }
    }
    $hits
}

$importOffset = Convert-RvaToOffset $importDirectoryRva
$iatNames = @{}
for ($descriptor = $importOffset; ; $descriptor += 20) {
    $originalFirstThunk = Read-U32 $descriptor
    $nameRva = Read-U32 ($descriptor + 12)
    $firstThunk = Read-U32 ($descriptor + 16)
    if ($originalFirstThunk -eq 0 -and $nameRva -eq 0 -and $firstThunk -eq 0) { break }

    $dll = Read-AsciiZ (Convert-RvaToOffset $nameRva)
    $lookupThunk = if ($originalFirstThunk -ne 0) { $originalFirstThunk } else { $firstThunk }
    $index = 0
    while ($true) {
        $lookupOffset = Convert-RvaToOffset ([uint32]($lookupThunk + $index * 8))
        $value = Read-U64 $lookupOffset
        if ($value -eq 0) { break }

        $slotRva = [uint32]($firstThunk + $index * 8)
        if (($value -band 0x8000000000000000) -eq 0) {
            $name = Read-AsciiZ ((Convert-RvaToOffset ([uint32]$value)) + 2)
            $iatNames[$slotRva] = "$dll!$name"
        } else {
            $iatNames[$slotRva] = "$dll!ordinal_$($value -band 0xffff)"
        }
        $index++
    }
}

$patterns = @(
    @{
        Name = 'ShowCursor show-loop'
        Pattern = @(0xB9,0x01,0x00,0x00,0x00,0xFF,0x15,$null,$null,$null,$null,0x85,0xC0,0x78,$null)
    },
    @{
        Name = 'ShowCursor hide-loop'
        Pattern = @(0x33,0xC9,0xFF,0x15,$null,$null,$null,$null,0x85,0xC0,0x79,$null)
    }
)

$hits = @()
foreach ($entry in $patterns) {
    foreach ($offset in (Find-Pattern -Bytes $bytes -Pattern $entry.Pattern)) {
        $callOffset = if ($bytes[$offset] -eq 0xFF) {
            $offset
        } elseif ($bytes[$offset + 5] -eq 0xFF) {
            $offset + 5
        } elseif ($bytes[$offset + 2] -eq 0xFF) {
            $offset + 2
        } else {
            $null
        }

        $callRva = Convert-OffsetToRva $callOffset
        $disp = Read-I32 ($callOffset + 2)
        $targetRva = [uint32]($callRva + 6 + $disp)
        $rva = Convert-OffsetToRva $offset
        $hits += [pscustomobject]@{
            Kind = $entry.Name
            FileOffset = ('0x{0:X}' -f $offset)
            RVA = ('0x{0:X}' -f $rva)
            CallRVA = ('0x{0:X}' -f $callRva)
            IatRVA = ('0x{0:X}' -f $targetRva)
            Import = $iatNames[$targetRva]
        }
    }
}

$hits | Sort-Object RVA | Format-Table -AutoSize
