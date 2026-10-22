#Requires -Version 5.1

<#
.SYNOPSIS
    Audit and alert on brute force logon attempts.
.DESCRIPTION
    Audit and alert on brute force logon attempts.

.PARAMETER AlertMethod
    Choose how to trigger the alert: 'Per User' to trigger the alert when any single user exceeds the failed attempts limit, or
                                     'Cumulative' to trigger the alert when the total number of failed attempts across all users exceeds the limit.
.PARAMETER InTheLastXHours
    Enter the number of hours back in time to look through in the event log. Value must be between 1 and 24 (inclusive).
.PARAMETER FailedAttemptsLimit
    Enter the number of failed logon attempts that will trigger the alert. Value must be between 1 and 100 (inclusive).
.PARAMETER MultilineCustomFieldName
    Enter the name of a multiline custom field to populate with the results.
.PARAMETER WYSIWYGCustomFieldName
    Enter the name of a WYSIWYG custom field to populate with the results.

.EXAMPLE
    -AlertMethod "Per User" -InTheLastXHours 24 -FailedAttemptsLimit 10

    [Info] No brute force attempts that meet or exceed the per user limit of 10 failed login attempts have been detected in the last 24 hour(s).

.EXAMPLE
    -AlertMethod "Per User" -InTheLastXHours 24 -FailedAttemptsLimit 1 -MultilineCustomFieldName "BruteForceAttemptsList" -WYSIWYGCustomFieldName "BruteForceAttempts"

    [Alert] Script results at 23/10/2025 4:31:28 p. m. detected 5 account(s) with 1 or more failed logon attempts in the past 24 hour(s).

    *** Brute force attempts in the last 24 hour(s): ***

    Account               FailedAttempts LogonType         SourceIPAddress
    -------               -------------- ---------         ---------------
    Administrator                      3 Interactive       127.0.0.1
    tuser2                             3 Interactive       127.0.0.1
    tuser2                             3 RemoteInteractive 0.0.0.0
    Administrator                      2 RemoteInteractive 0.0.0.0
    tuser1                             2 Interactive       127.0.0.1
    tuser1                             2 RemoteInteractive 0.0.0.0
    alwkemfalwekmfaawefae              1 Interactive       127.0.0.1
    awefae                             1 Interactive       127.0.0.1

    [Info] Attempting to set the 'BruteForceAttemptsList' multiline custom field.
    [Info] Successfully set the 'BruteForceAttemptsList' multiline custom field.

    [Info] Attempting to set the 'BruteForceAttempts' WYSIWYG custom field.
    [Info] Successfully set the 'BruteForceAttempts' WYSIWYG custom field.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 2.0
    Release Notes: Brought up to current standards, renamed script and parameters, added alert method parameter,
                   added multiline and WYSIWYG custom field support, improved support for non-English languages,
                   improved error handling and input validation.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$AlertMethod = "Per User",
    [Parameter()]
    $InTheLastXHours = 1,
    [Parameter()]
    $FailedAttemptsLimit = 8,
    [Parameter()]
    [string]$MultilineCustomFieldName,
    [Parameter()]
    [string]$WYSIWYGCustomFieldName
)

begin {
    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Import script variables
    if ($env:AlertMethod) { $AlertMethod = $env:AlertMethod }
    if ($env:InTheLastXHours) { $InTheLastXHours = $env:InTheLastXHours }
    if ($env:FailedAttemptsLimit) { $FailedAttemptsLimit = $env:FailedAttemptsLimit }
    if ($env:MultilineCustomFieldName) { $MultilineCustomFieldName = $env:MultilineCustomFieldName }
    if ($env:WYSIWYGCustomFieldName) { $WYSIWYGCustomFieldName = $env:WYSIWYGCustomFieldName }

    # Validate the 'Alert Method' parameter
    if ($AlertMethod -notin @("Per User", "Cumulative")) {
        Write-Host -Object "[Error] The 'Alert Method' value of '$AlertMethod' is invalid. Please choose either 'Per User' or 'Cumulative'."
        exit 1
    }

    # Validate the 'In The Last X Hours' parameter is a valid integer
    try {
        $InTheLastXHours = [int]$InTheLastXHours
    }
    catch {
        Write-Host -Object "[Error] The provided value for 'In The Last X Hours' is not a valid integer. Please enter a value between 1 and 24 (inclusive)."
        exit 1
    }

    # Validate the 'In The Last X Hours' parameter is between 1 and 24
    if ($InTheLastXHours -lt 1 -or $InTheLastXHours -gt 24) {
        Write-Host -Object "[Error] The 'In The Last X Hours' value of '$InTheLastXHours' is out of range. Please enter a value between 1 and 24 (inclusive)."
        exit 1
    }

    # Validate the 'Failed Attempts Limit' parameter is a valid integer
    try {
        $FailedAttemptsLimit = [int]$FailedAttemptsLimit
    }
    catch {
        Write-Host -Object "[Error] The provided value for 'Failed Attempts Limit' is not a valid integer. Please enter a value between 1 and 100 (inclusive)."
        exit 1
    }

    # Validate the 'Failed Attempts Limit' parameter is between 1 and 100
    if ($FailedAttemptsLimit -lt 1 -or $FailedAttemptsLimit -gt 100) {
        Write-Host -Object "[Error] The 'Failed Attempts Limit' value of '$FailedAttemptsLimit' is out of range. Please enter a value between 1 and 100 (inclusive)."
        exit 1
    }

    # Validate the multiline custom field name if provided
    if ($MultilineCustomFieldName) {
        # Trim the field name to remove leading and trailing whitespace
        $MultilineCustomFieldName = $MultilineCustomFieldName.Trim()

        # Validate that the field is not just whitespace
        if ([string]::IsNullOrWhiteSpace($MultilineCustomFieldName)) {
            Write-Host "[Error] The 'Multiline Custom Field Name' parameter contains only spaces. Please provide a valid field name or leave it blank."
            exit 1
        }

        # Validate that the field name contains only alphanumeric characters
        if ($MultilineCustomFieldName -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'Multiline Custom Field Name' of '$MultilineCustomFieldName' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid Multiline custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Validate the WYSIWYG custom field name if provided
    if ($WYSIWYGCustomFieldName) {
        # Trim the field name to remove leading and trailing whitespace
        $WYSIWYGCustomFieldName = $WYSIWYGCustomFieldName.Trim()

        # Validate that the field is not just whitespace
        if ([string]::IsNullOrWhiteSpace($WYSIWYGCustomFieldName)) {
            Write-Host "[Error] The 'WYSIWYG Custom Field Name' parameter contains only spaces. Please provide a valid field name or leave it blank."
            exit 1
        }

        # Validate that the field name contains only alphanumeric characters
        if ($WYSIWYGCustomFieldName -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' of '$WYSIWYGCustomFieldName' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid WYSIWYG custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    function Test-IsSystem {
        [CmdletBinding()]
        param ()

        # Get the current Windows identity of the user running the script
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()

        # Check if the current identity's name matches "NT AUTHORITY*"
        # or if the identity represents the SYSTEM account
        return $id.Name -like "NT AUTHORITY*" -or $id.IsSystem
    }

    # Function to retrieve logon/logoff auditing status from the registry
    function Get-LogonLogoffAuditingStatus {
        # Retrieve the audit policy settings from the registry
        try {
            $AuditPolicy = (Get-ItemProperty -Path "HKLM:\Security\Policy\PolAdtEv\" -Name "(default)" -ErrorAction Stop)."(default)"
        }
        catch {
            throw $_
        }

        # The setting for logon auditing is stored at index 22 of the audit policy registry key
        switch ($AuditPolicy[22]) {
            0 { $LogonAuditingStatus = "Disabled" }
            1 { $LogonAuditingStatus = "Enabled (Success only)" }
            2 { $LogonAuditingStatus = "Enabled (Failure only)" }
            3 { $LogonAuditingStatus = "Enabled" }
            default { $LogonAuditingStatus = "Unknown ($_)" }
        }

        # The setting for logoff auditing is stored at index 24 of the audit policy registry key
        switch ($AuditPolicy[24]) {
            0 { $LogoffAuditingStatus = "Disabled" }
            2 { $LogoffAuditingStatus = "Enabled (Failure only)" }
            { $_ -in @(1, 3 ) } { $LogoffAuditingStatus = "Enabled" }
            default { $LogoffAuditingStatus = "Unknown ($_)" }
        }

        # Return a custom object with the logon and logoff auditing statuses
        return [PSCustomObject]@{
            LogonAuditing  = $LogonAuditingStatus
            LogoffAuditing = $LogoffAuditingStatus
        }
    }

    function Test-IsElevated {
        [CmdletBinding()]
        param ()

        # Get the current Windows identity of the user running the script
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()

        # Create a WindowsPrincipal object based on the current identity
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)

        # Check if the current user is in the Administrator role
        # The function returns $True if the user has administrative privileges, $False otherwise
        # 544 is the value for the Built In Administrators role
        # Reference: https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsbuiltinrole
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]'544')
    }

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    # Attempt to determine if the current session is running with Administrator privileges.
    try {
        $IsElevated = Test-IsElevated -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$([environment]::UserName)' is running this script in an elevated session."
        exit 1
    }

    # Error if not running in an elevated session
    if (!$IsElevated) {
        Write-Host -Object "[Error] The user '$([environment]::UserName)' is not running this script in an elevated session. Please run this script as System or in an elevated session."
        exit 1
    }

    # Attempt to determine if the current session is running as the SYSTEM account.
    try {
        $IsSystem = Test-IsSystem -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$([environment]::UserName)' is the SYSTEM account."
        exit 1
    }

    # Error if not running as SYSTEM
    if (-not $IsSystem) {
        Write-Host -Object "[Error] The user '$([environment]::UserName)' is not the SYSTEM account. Please run this script as System."
        exit 1
    }

    # Retrieve the audit policy from the registry
    try {
        $AuditPolicy = Get-LogonLogoffAuditingStatus -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] Unable to retrieve the audit policy from the registry. Ensure that the script is run with sufficient permissions."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Error if logon failure auditing is not enabled
    if ($AuditPolicy.LogonAuditing -notmatch "Enabled (Failure only)|^Enabled$") {
        Write-Host "[Error] Logon failure auditing is not enabled. Current setting: $($AuditPolicy.LogonAuditing)"
        Write-Host "[Error] Please enable logon failure auditing using the 'Enable or Disable User Logon/Logoff Auditing' script in the Template Library to track failed logon attempts."
        exit 1
    }

    # Calculate the start time for querying the event log
    try {
        $StartTime = (Get-Date -ErrorAction Stop).AddHours(-$InTheLastXHours)
    }
    catch {
        Write-Host "[Error] Failed to calculate the start time for querying the event log."
        Write-Host "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Get failed logon attempts within the specified time frame
    try {
        $FailedLogonEvents = Get-WinEvent -FilterHashtable @{LogName = "Security"; ID = 4625; StartTime = $StartTime } -ErrorAction Stop
    }
    catch {
        if ($_.FullyQualifiedErrorId -match "NoMatchingEventsFound") {
            Write-Host "[Info] No failed logons found in the past $InTheLastXHours hour(s).`n"
        }
        else {
            Write-Host "[Error] Failed to query the Security event log."
            Write-Host "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    # Parse the event log data to extract relevant information
    if ($FailedLogonEvents) {
        try {
            $ParsedEventObjects = $FailedLogonEvents | ForEach-Object {
                $Account = $_.Properties[5].Value
                [int]$LogonType = $_.Properties[10].Value
                $SourceNetworkAddress = $_.Properties[19].Value

                $LogonTypeLabel = switch ($LogonType) {
                    2 { "Interactive" }
                    3 { "Network" }
                    7 { "Unlock" }
                    10 { "RemoteInteractive" }
                    default { return } # If the logon type is not one of the specified types, skip this entry
                }

                [PSCustomObject]@{
                    Account              = $Account
                    LogonType            = $LogonTypeLabel
                    SourceNetworkAddress = $SourceNetworkAddress
                }
            }
        }
        catch {
            Write-Host "[Error] Failed to parse the event log data."
            Write-Host "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    # Create a custom object for each combination of user account, logon type, and source IP address, along with the count of failed attempts
    if ($ParsedEventObjects) {
        $FailedLogonEventsPerUserAccount = $ParsedEventObjects | Group-Object -Property Account, SourceNetworkAddress, LogonType | ForEach-Object {
            $EventAccount = $_.Values[0]
            $EventSourceNetworkAddress = $_.Values[1]
            $EventLogonType = $_.Values[2]
            $AttemptCount = $_.Group | Measure-Object | Select-Object -ExpandProperty Count

            [PSCustomObject]@{
                Account         = $EventAccount
                FailedAttempts  = $AttemptCount
                LogonType       = $EventLogonType
                SourceIPAddress = $EventSourceNetworkAddress
            }
        }

        # Sort the results
        $FailedLogonEventsPerUserAccount = $FailedLogonEventsPerUserAccount | Sort-Object -Property @{Expression = { $_.FailedAttempts }; Descending = $True }, Account, LogonType
    }

    # Determine if any brute force attempts occurred based on the alert method
    switch ($AlertMethod) {
        "Per User" {
            $BruteForceAttempts = $FailedLogonEventsPerUserAccount | Where-Object { $_.FailedAttempts -ge $FailedAttemptsLimit }
        }
        "Cumulative" {
            $FailedAttemptsCumulativeCount = ($FailedLogonEventsPerUserAccount | Measure-Object -Property FailedAttempts -Sum).Sum
            if ($FailedAttemptsCumulativeCount -ge $FailedAttemptsLimit) {
                $BruteForceAttempts = $FailedLogonEventsPerUserAccount
            }
        }
    }

    # If any brute force attempts are found, alert and output the list of brute force attempts
    if ($BruteForceAttempts) {
        # Output the alert message based on the alert method
        switch ($AlertMethod) {
            "Per User" {
                Write-Host "[Alert] Script results at $(Get-Date -Format G) detected $(($BruteForceAttempts | Select-Object -Property Account -Unique | Measure-Object).Count) account(s) with $FailedAttemptsLimit or more failed logon attempts in the past $InTheLastXHours hour(s).`n"
            }
            "Cumulative" {
                Write-Host "[Alert] Script results at $(Get-Date -Format G) detected $FailedAttemptsCumulativeCount total failed logon attempts across all users, which exceeds the limit of $FailedAttemptsLimit, in the past $InTheLastXHours hour(s).`n"
            }
        }
        Write-Host "*** Brute force attempts in the last $InTheLastXHours hour(s): ***`n"
        ($BruteForceAttempts | Out-String).Trim() | Write-Host
    }
    else {
        Write-Host "[Info] No brute force attempts that meet or exceed the $($AlertMethod.ToLower()) limit of $FailedAttemptsLimit failed login attempts have been detected in the last $InTheLastXHours hour(s)."
    }

    # If provided, populate the multiline custom field
    if ($MultilineCustomFieldName) {
        Write-Host ""
        if ($BruteForceAttempts) {
            # Initialize a list to hold the multiline text
            $MultilineText = New-Object System.Collections.Generic.List[string]

            # Add the alert message based on the alert method
            switch ($AlertMethod) {
                "Per User" {
                    $MultilineText.Add("[Alert] Script results at $(Get-Date -Format G) detected $(($BruteForceAttempts | Select-Object -Property Account -Unique | Measure-Object).Count) account(s) with $FailedAttemptsLimit or more failed logon attempts in the past $InTheLastXHours hour(s).`n`n")
                }
                "Cumulative" {
                    $MultilineText.Add("[Alert] Script results at $(Get-Date -Format G) detected $FailedAttemptsCumulativeCount total failed logon attempts across all users, which exceeds the limit of $FailedAttemptsLimit, in the past $InTheLastXHours hour(s).`n`n")
                }
            }

            # Add the list of brute force attempts
            $MultilineText.Add(($BruteForceAttempts | Format-List | Out-String).Trim())
        }
        else {
            $MultilineText = "No brute force attempts that meet or exceed the $($AlertMethod.ToLower()) limit of $FailedAttemptsLimit failed login attempts have been detected in the last $InTheLastXHours hour(s)"
        }

        try {
            Write-Host "[Info] Attempting to set the '$MultilineCustomFieldName' multiline custom field."
            Set-NinjaProperty -Name $MultilineCustomFieldName -Value $MultilineText -ErrorAction Stop
            Write-Host "[Info] Successfully set the '$MultilineCustomFieldName' multiline custom field."
        }
        catch {
            Write-Host -Object "[Error] Failed to set the multiline custom field '$MultilineCustomFieldName'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    # If provided, populate the WYSIWYG custom field
    if ($WYSIWYGCustomFieldName) {
        Write-Host ""
        if ($BruteForceAttempts) {
            # Convert the logon events to an HTML table
            $HtmlTable = ($BruteForceAttempts | ConvertTo-Html -Fragment | Out-String).Trim()

            # Bold the table headers for better visibility
            $HtmlTable = $HtmlTable -replace "<th>", "<th><strong>" -replace "</th>", "</strong></th>"

            # Create the alert message based on the alert method
            switch ($AlertMethod) {
                "Per User" {
                    $WYSIWYGAlertMessage = "Script results at $(Get-Date -Format G) detected $(($BruteForceAttempts | Select-Object -Property Account -Unique | Measure-Object).Count) account(s) with $FailedAttemptsLimit or more failed logon attempts in the past $InTheLastXHours hour(s).`n`n"
                }
                "Cumulative" {
                    $WYSIWYGAlertMessage = "Script results at $(Get-Date -Format G) detected $FailedAttemptsCumulativeCount total failed logon attempts across all users, which exceeds the limit of $FailedAttemptsLimit, in the past $InTheLastXHours hour(s).`n`n"
                }
            }

            # Wrap the table in a card layout
            $HtmlTable = "<div class='card flex-grow-1'>
                            <div class='card-title-box'>
                                <div class='card-title'><i class='fa-solid fa-user-xmark'></i>&nbsp;&nbsp;Brute Force Attempts</div>
                            </div>
                            <div class='card-body' style='white-space: nowrap;'>
                                $HtmlTable
                            </div>
                        </div>"

            # Add an alert message above the table
            $HtmlTable = $HtmlTable -replace "^", "<p style='font-size:1em'><i class='fa-solid fa-circle-exclamation' style='color: #ff0000;'></i>  $WYSIWYGAlertMessage</p>`n"
        }
        else {
            $HtmlTable = "<p>No brute force attempts that meet or exceed the $($AlertMethod.ToLower()) limit of $FailedAttemptsLimit failed login attempts have been detected in the last $InTheLastXHours hour(s).</p>"
        }

        try {
            Write-Host "[Info] Attempting to set the '$WYSIWYGCustomFieldName' WYSIWYG custom field."
            Set-NinjaProperty -Name $WYSIWYGCustomFieldName -Value $HtmlTable -ErrorAction Stop
            Write-Host "[Info] Successfully set the '$WYSIWYGCustomFieldName' WYSIWYG custom field."
        }
        catch {
            Write-Host -Object "[Error] Failed to set the WYSIWYG custom field '$WYSIWYGCustomFieldName'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    exit $ExitCode
}
end {
    
    
    
}