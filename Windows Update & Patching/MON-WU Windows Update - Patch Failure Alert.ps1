#Requires -Version 5.1

<#
.SYNOPSIS
    Alerts when Windows updates have failed to install, a reboot to finish patching is overdue, or no update has installed successfully for too long.
.DESCRIPTION
    Read-only check designed for NinjaOne. Reads the local Windows Update history (the same history NinjaOne patching writes to)
    and the WindowsUpdateClient event log, then reports:
      - Updates whose most recent install attempt failed or was aborted within the look-back window
        (an update that failed and later installed successfully is not reported).
      - A pending reboot left over from patching once the device has been up longer than the allowed number of days.
      - No successful update install within the allowed number of days.
    Exits with code 1 when any of these are found, so it can drive a NinjaOne condition or alert.
    Makes no changes to the device. No downloads, no services touched, no reboots.

    NinjaOne script variables (all optional):
      daysToCheck                 Integer. Look-back window for failures. Default 7.
      pendingRebootAlertDays      Integer. Alert when a patch reboot is pending and uptime exceeds this. 0 disables. Default 7.
      daysWithoutSuccessfulUpdate Integer. Alert when no update installed successfully in this many days. 0 disables. Default 35.
      ignoreDefenderDefinitions   Checkbox. Ignore Defender security intelligence (definition) updates. Default true.
      ignoreStoreApps             Checkbox. Ignore Microsoft Store app updates (e.g. 9WZDNCRFJBMP-Microsoft.WindowsStore). Default true.
      ignoreStoreApps             Checkbox. Ignore Microsoft Store app updates (e.g. 9WZDNCRFJBMP-Microsoft.WindowsStore). Default true.
      updatesToIgnore             String. Comma-separated KB numbers or title fragments to ignore, e.g. "KB5007651,Silverlight".
      statusCustomFieldName       Text custom field to receive a one-line status, e.g. "patchFailureStatus".
      multilineCustomFieldName    Multi-line custom field to receive the detail, e.g. "patchFailureDetail".
.EXAMPLE
    -DaysToCheck 14 -StatusCustomFieldName "patchFailureStatus"

    [Alert] 1 failed update(s) in the last 14 day(s); reboot pending 9 day(s).
.PARAMETER DaysToCheck
    Number of days of history to check for failed installs.
.PARAMETER PendingRebootAlertDays
    Alert when a patch-related reboot is pending and the device has been up longer than this many days. 0 disables.
.PARAMETER DaysWithoutSuccessfulUpdate
    Alert when no update has installed successfully within this many days. 0 disables.
.PARAMETER IgnoreDefenderDefinitions
    Ignore Microsoft Defender security intelligence (definition) updates, which fail and retry often.
.PARAMETER IgnoreStoreApps
    Ignore Microsoft Store app updates, which are not Windows patches.
.PARAMETER UpdatesToIgnore
    Comma-separated KB numbers or title fragments to ignore.
.PARAMETER StatusCustomFieldName
    Name of a text custom field to store a one-line status.
.PARAMETER MultilineCustomFieldName
    Name of a multi-line custom field to store the detail.
.OUTPUTS
    Activity log text. Exit code 0 = healthy, 1 = alert, 2 = script error.
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Run as: System
    Version: 1.0
    Release Notes: Initial release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [int]$DaysToCheck = 7,
    [Parameter()]
    [int]$PendingRebootAlertDays = 7,
    [Parameter()]
    [int]$DaysWithoutSuccessfulUpdate = 35,
    [Parameter()]
    [switch]$IgnoreDefenderDefinitions = [System.Convert]::ToBoolean($(if ($env:ignoreDefenderDefinitions) { $env:ignoreDefenderDefinitions } else { "true" })),
    [Parameter()]
    [switch]$IgnoreStoreApps = [System.Convert]::ToBoolean($(if ($env:ignoreStoreApps) { $env:ignoreStoreApps } else { "true" })),
    [Parameter()]
    [string]$UpdatesToIgnore,
    [Parameter()]
    [string]$StatusCustomFieldName,
    [Parameter()]
    [string]$MultilineCustomFieldName
)

begin {
    # NinjaOne passes script variables as environment variables; they override the parameter defaults.
    if ($env:daysToCheck -and $env:daysToCheck -notlike "null") { $DaysToCheck = [int]$env:daysToCheck }
    if ($env:pendingRebootAlertDays -and $env:pendingRebootAlertDays -notlike "null") { $PendingRebootAlertDays = [int]$env:pendingRebootAlertDays }
    if ($env:daysWithoutSuccessfulUpdate -and $env:daysWithoutSuccessfulUpdate -notlike "null") { $DaysWithoutSuccessfulUpdate = [int]$env:daysWithoutSuccessfulUpdate }
    if ($env:updatesToIgnore -and $env:updatesToIgnore -notlike "null") { $UpdatesToIgnore = $env:updatesToIgnore }
    if ($env:statusCustomFieldName -and $env:statusCustomFieldName -notlike "null") { $StatusCustomFieldName = $env:statusCustomFieldName }
    if ($env:multilineCustomFieldName -and $env:multilineCustomFieldName -notlike "null") { $MultilineCustomFieldName = $env:multilineCustomFieldName }

    if ($DaysToCheck -lt 1) {
        Write-Host "[Error] daysToCheck must be 1 or greater."
        exit 2
    }
    if ($PendingRebootAlertDays -lt 0 -or $DaysWithoutSuccessfulUpdate -lt 0) {
        Write-Host "[Error] pendingRebootAlertDays and daysWithoutSuccessfulUpdate must be 0 (disabled) or greater."
        exit 2
    }

    $IgnoreList = @()
    if ($UpdatesToIgnore) {
        $IgnoreList = $UpdatesToIgnore -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    function Test-IsIgnored {
        param([string]$Title)
        if ($IgnoreStoreApps -and $Title -match "^9[A-Z0-9]{11}-") { return $true }
        if ($IgnoreDefenderDefinitions -and $Title -match "Security Intelligence Update|Definition Update for Microsoft Defender|KB2267602") { return $true }
        foreach ($Item in $IgnoreList) {
            if ($Title -like "*$Item*") { return $true }
        }
        return $false
    }

    function Get-KBNumber {
        param([string]$Title)
        if ($Title -match "(KB\d{6,8})") { return $Matches[1] }
        return ""
    }

    function Test-PatchRebootPending {
        $Keys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
        )
        foreach ($Key in $Keys) {
            if (Test-Path -Path $Key) { return $true }
        }
        return $false
    }

    function Set-NinjaField {
        param([string]$Name, [string]$Value)
        if (-not $Name) { return }
        try {
            if (Get-Command -Name "Ninja-Property-Set" -ErrorAction SilentlyContinue) {
                Ninja-Property-Set -Name $Name -Value $Value
            }
            else {
                Write-Host "[Warn] Ninja-Property-Set not found; custom field '$Name' was not updated."
            }
        }
        catch {
            Write-Host "[Warn] Unable to update custom field '$Name': $($_.Exception.Message)"
        }
    }
}

process {
    $Since = (Get-Date).AddDays(-$DaysToCheck)
    $Detail = New-Object System.Collections.Generic.List[string]
    $Failed = @()

    # 1. Windows Update history (covers installs made by NinjaOne, Windows Update and WSUS through the WUA API).
    $History = @()
    try {
        $Session = New-Object -ComObject "Microsoft.Update.Session"
        $Searcher = $Session.CreateUpdateSearcher()
        $Count = $Searcher.GetTotalHistoryCount()
        if ($Count -gt 0) {
            # Cap the query; recent entries come first and older history is not needed.
            $History = $Searcher.QueryHistory(0, [Math]::Min($Count, 500)) | Where-Object { $_.Operation -eq 1 -and $_.Title }
        }
    }
    catch {
        Write-Host "[Warn] Unable to read Windows Update history: $($_.Exception.Message)"
    }

    # ResultCode: 1 in progress, 2 succeeded, 3 succeeded with errors, 4 failed, 5 aborted.
    # Last success counts only updates that are not ignored, so daily Defender or Store updates do not hide stalled patching.
    $LastSuccess = $History | Where-Object { $_.ResultCode -in 2, 3 -and -not (Test-IsIgnored -Title $_.Title) } | Sort-Object -Property Date -Descending | Select-Object -First 1

    $Latest = $History | Where-Object { -not (Test-IsIgnored -Title $_.Title) } |
        Group-Object -Property { $_.UpdateIdentity.UpdateID } |
        ForEach-Object { $_.Group | Sort-Object -Property Date -Descending | Select-Object -First 1 }

    $Failed = @($Latest | Where-Object { $_.ResultCode -in 4, 5 -and $_.Date.ToLocalTime() -ge $Since } | ForEach-Object {
            [PSCustomObject]@{
                Date   = $_.Date.ToLocalTime()
                KB     = Get-KBNumber -Title $_.Title
                Title  = $_.Title
                Result = if ($_.ResultCode -eq 4) { "Failed" } else { "Aborted" }
                HResult = "0x{0:X8}" -f $_.HResult
            }
        })

    # 2. Event log fallback: WindowsUpdateClient event 20 (installation failure) for anything missing from history.
    try {
        $Events = Get-WinEvent -FilterHashtable @{ LogName = "System"; ProviderName = "Microsoft-Windows-WindowsUpdateClient"; Id = 20; StartTime = $Since } -ErrorAction Stop
        foreach ($WinEvent in $Events) {
            $Title = ($WinEvent.Properties | Where-Object { $_.Value -is [string] -and $_.Value -match "\S{3,}" -and $_.Value -notmatch "^0x" } | Select-Object -Last 1).Value
            if (-not $Title) { $Title = "Unknown update" }
            if (Test-IsIgnored -Title $Title) { continue }
            $KB = Get-KBNumber -Title $Title
            $InstalledLater = $History | Where-Object { $_.ResultCode -in 2, 3 -and $_.Date.ToLocalTime() -gt $WinEvent.TimeCreated -and (($KB -and $_.Title -like "*$KB*") -or $_.Title -eq $Title) }
            $AlreadyListed = $Failed | Where-Object { ($KB -and $_.KB -eq $KB) -or $_.Title -eq $Title }
            if (-not $InstalledLater -and -not $AlreadyListed) {
                $Failed += [PSCustomObject]@{
                    Date    = $WinEvent.TimeCreated
                    KB      = $KB
                    Title   = $Title
                    Result  = "Failed (event 20)"
                    HResult = ""
                }
            }
        }
    }
    catch {
        # No matching events throws "No events were found"; anything else is worth a note.
        if ($_.Exception.Message -notmatch "No events were found") {
            Write-Host "[Warn] Unable to read the WindowsUpdateClient event log: $($_.Exception.Message)"
        }
    }

    # 3. Pending patch reboot vs uptime.
    $RebootPending = Test-PatchRebootPending
    $UptimeDays = 0
    try {
        $LastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime
        $UptimeDays = [Math]::Floor(((Get-Date) - $LastBoot).TotalDays)
    }
    catch {
        Write-Host "[Warn] Unable to read last boot time: $($_.Exception.Message)"
    }
    $RebootOverdue = $PendingRebootAlertDays -gt 0 -and $RebootPending -and $UptimeDays -gt $PendingRebootAlertDays

    # 4. Time since last successful install.
    $DaysSinceSuccess = $null
    if ($LastSuccess) { $DaysSinceSuccess = [Math]::Floor(((Get-Date) - $LastSuccess.Date.ToLocalTime()).TotalDays) }
    $Stale = $DaysWithoutSuccessfulUpdate -gt 0 -and ($null -eq $DaysSinceSuccess -or $DaysSinceSuccess -gt $DaysWithoutSuccessfulUpdate)

    # Build output.
    $Problems = @()
    if ($Failed.Count -gt 0) { $Problems += "$($Failed.Count) failed update(s) in the last $DaysToCheck day(s)" }
    if ($RebootOverdue) { $Problems += "reboot pending, uptime $UptimeDays day(s)" }
    if ($Stale) {
        if ($null -eq $DaysSinceSuccess) { $Problems += "no successful update found in history" }
        else { $Problems += "no successful update in $DaysSinceSuccess day(s)" }
    }

    if ($Problems.Count -gt 0) {
        $Status = "[Alert] " + ($Problems -join "; ") + "."
    }
    else {
        $Status = "[OK] No failed updates in the last $DaysToCheck day(s)."
    }

    $Detail.Add($Status)
    if ($LastSuccess) { $Detail.Add("Last successful install: $($LastSuccess.Date.ToLocalTime().ToString('yyyy-MM-dd HH:mm')) - $($LastSuccess.Title)") }
    $Detail.Add("Reboot pending: $RebootPending. Uptime: $UptimeDays day(s).")
    foreach ($Item in ($Failed | Sort-Object -Property Date -Descending)) {
        $Detail.Add("$($Item.Date.ToString('yyyy-MM-dd HH:mm')) | $($Item.Result) | $($Item.KB) | $($Item.HResult) | $($Item.Title)")
    }

    $Detail | ForEach-Object { Write-Host $_ }

    Set-NinjaField -Name $StatusCustomFieldName -Value $Status
    Set-NinjaField -Name $MultilineCustomFieldName -Value ($Detail -join "`n")

    if ($Problems.Count -gt 0) { exit 1 }
    exit 0
}

end {
}
