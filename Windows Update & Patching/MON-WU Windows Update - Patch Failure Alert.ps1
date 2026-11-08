#Requires -Version 5.1

<#
.SYNOPSIS
    Writes failed Windows updates to NinjaOne custom fields so a condition can raise a ticket for a human to check.
.DESCRIPTION
    Read-only. Reads the local Windows Update history and finds updates whose most recent install attempt
    failed or was aborted within the look-back window. An update that failed and later installed is not reported.
    Defender definition updates and Microsoft Store app updates are ignored.

    Custom fields the script writes (no script variable needed; names are case sensitive; Automations Read/Write):
      patchFailureStatus   Text        "FAILED: ..." when updates failed, otherwise "OK: ...".
      patchFailureDetail   Multi-line  One line per failed update (date, result, KB, error code, title).

    Ticket: create a condition on custom field patchFailureStatus contains "FAILED".

    NinjaOne script variables (optional):
      daysToCheck      Integer. Look-back window in days. Default 7.
      updatesToIgnore  String. Comma-separated KB numbers or title fragments to ignore, e.g. "KB5007651,Silverlight".
.OUTPUTS
    Activity log text. Exit code 0 = no failures, 1 = failures found, 2 = script error.
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Run as: System
    Version: 2.0
    Release Notes: Simplified to failed updates only. Writes custom fields with the native Ninja-Property-Set commands.
#>

[CmdletBinding()]
param (
    [int]$DaysToCheck = 7,
    [string]$UpdatesToIgnore
)

$StatusField = "patchFailureStatus"   # Text
$DetailField = "patchFailureDetail"   # Multi-line

if ($env:daysToCheck -and $env:daysToCheck -notlike "null") { $DaysToCheck = [int]$env:daysToCheck }
if ($env:updatesToIgnore -and $env:updatesToIgnore -notlike "null") { $UpdatesToIgnore = $env:updatesToIgnore }
if ($DaysToCheck -lt 1) {
    Write-Host "[Error] daysToCheck must be 1 or greater."
    exit 2
}
$IgnoreList = @()
if ($UpdatesToIgnore) { $IgnoreList = $UpdatesToIgnore -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ } }

function Test-IsIgnored {
    param([string]$Title)
    if ($Title -match "^9[A-Z0-9]{11}-") { return $true }   # Microsoft Store apps
    if ($Title -match "Security Intelligence Update|Definition Update for Microsoft Defender|KB2267602") { return $true }
    foreach ($Item in $IgnoreList) { if ($Title -like "*$Item*") { return $true } }
    return $false
}

# Read Windows Update history (includes installs made by NinjaOne patching).
$Since = (Get-Date).AddDays(-$DaysToCheck)
try {
    $Searcher = (New-Object -ComObject "Microsoft.Update.Session").CreateUpdateSearcher()
    $Count = $Searcher.GetTotalHistoryCount()
    $History = @()
    if ($Count -gt 0) { $History = $Searcher.QueryHistory(0, [Math]::Min($Count, 500)) | Where-Object { $_.Operation -eq 1 -and $_.Title } }
}
catch {
    Write-Host "[Error] Unable to read Windows Update history: $($_.Exception.Message)"
    exit 2
}

# Latest attempt per update. ResultCode 4 = failed, 5 = aborted.
$Failed = @($History | Where-Object { -not (Test-IsIgnored -Title $_.Title) } |
    Group-Object -Property { $_.UpdateIdentity.UpdateID } |
    ForEach-Object { $_.Group | Sort-Object -Property Date -Descending | Select-Object -First 1 } |
    Where-Object { $_.ResultCode -in 4, 5 -and $_.Date.ToLocalTime() -ge $Since } |
    Sort-Object -Property Date -Descending)

if ($Failed.Count -gt 0) {
    $KBs = ($Failed | ForEach-Object { if ($_.Title -match "(KB\d{6,8})") { $Matches[1] } else { $_.Title } }) -join ", "
    $Status = "FAILED: $($Failed.Count) update(s) failed in the last $DaysToCheck day(s): $KBs"
    if ($Status.Length -gt 200) { $Status = $Status.Substring(0, 197) + "..." }
    $Detail = ($Failed | ForEach-Object {
            $Result = if ($_.ResultCode -eq 4) { "Failed" } else { "Aborted" }
            "{0} | {1} | 0x{2:X8} | {3}" -f $_.Date.ToLocalTime().ToString("yyyy-MM-dd HH:mm"), $Result, $_.HResult, $_.Title
        }) -join "`n"
}
else {
    $Status = "OK: no failed updates in the last $DaysToCheck day(s)."
    $Detail = $Status
}

Write-Host $Status
if ($Failed.Count -gt 0) { Write-Host $Detail }

Ninja-Property-Set $StatusField $Status
$Detail | Ninja-Property-Set-Piped $DetailField

if ($Failed.Count -gt 0) { exit 1 }
exit 0
