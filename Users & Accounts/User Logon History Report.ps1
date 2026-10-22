#Requires -Version 5.1

<#
.SYNOPSIS
    Generate a report of user session start (logon) and stop (logoff) events.
.DESCRIPTION
    Generate a report of user session start (logon) and stop (logoff) events.

.PARAMETER UsersToReportOn
    Enter a list of users to report on, separated by commas. If you fill this out, only users in this list will be reported on. If you leave this blank, the script will report on all users.
.PARAMETER ExcludeUsersFromReport
    Enter a list of users to exclude from the report, separated by commas.
.PARAMETER RetrieveExcludedUsersFromCustomField
    Enter the name of a custom field that has a list of users to exclude from the report. The script will retrieve the list of users from this custom field and exclude them from the report.
.PARAMETER InTheLastXDays
    By default, the script will report back as far as possible. To report on only the past x days, specify the number of days here. Note the 'Max Records To Return' parameter may prevent the script from returning all of the events in the specified time frame.
.PARAMETER MaxRecordsToReturn
    Specify the number of records to return here. Note that changing this parameter may cause the data to be truncated due to character limits within Ninja.
.PARAMETER MultilineCustomFieldName
    Enter the name of a multiline custom field to save the results to. If you leave this blank, the results will not be saved to a multiline custom field.
.PARAMETER WYSIWYGCustomFieldName
    Enter the name of a WYSIWYG custom field to save the results to. If you leave this blank, the results will not be saved to a WYSIWYG custom field.

.EXAMPLE
    -MaxRecordsToReturn 10

    [Info] Found 131 logon history events.

    [Info] More than 10 record(s) found, trimming the list to the maximum number of records specified.

    Time                 Username      Event          ID
    ----                 --------      -----          --
    8/5/2025 12:39:57 PM Administrator SessionStart 4624
    8/5/2025 4:35:04 PM  tuser1        FailedLogon  4625
    8/5/2025 4:35:07 PM  tuser1        FailedLogon  4625
    8/5/2025 4:35:09 PM  tuser1        FailedLogon  4625
    8/5/2025 4:35:12 PM  Administrator FailedLogon  4625
    8/5/2025 4:35:14 PM  Administrator SessionStart 4624
    8/5/2025 4:35:14 PM  Administrator SessionStop  4634
    8/5/2025 4:36:04 PM  tuser2        SessionStart 4624
    8/5/2025 4:37:14 PM  tuser4        SessionStart 4624
    8/6/2025 8:56:04 AM  tuser4        SessionStart 4624

.EXAMPLE
    -UserToReportOn "tuser1" -MultilineCustomFieldName "Multiline" -WYSIWYGCustomFieldName "WYSIWYG"

    [Info] Only the following users will be included in the report: 'tuser1'

    [Info] Found 10 logon history events.

    [Info] Attempting to set the multiline custom field 'Multiline'.
    [Info] Successfully set the multiline custom field.

    [Info] Attempting to set the WYSIWYG custom field 'WYSIWYG'.
    [Info] Successfully set the WYSIWYG custom field.

    Time                 Username Event          ID
    ----                 -------- -----          --
    8/4/2025 3:11:39 PM  tuser1   FailedLogon  4625
    8/4/2025 3:12:07 PM  tuser1   SessionStart 4624
    8/4/2025 3:28:54 PM  tuser1   FailedLogon  4625
    8/4/2025 3:29:03 PM  tuser1   FailedLogon  4625
    8/5/2025 12:39:44 PM tuser1   FailedLogon  4625
    8/5/2025 12:39:49 PM tuser1   FailedLogon  4625
    8/5/2025 12:39:51 PM tuser1   FailedLogon  4625
    8/5/2025 4:35:04 PM  tuser1   FailedLogon  4625
    8/5/2025 4:35:07 PM  tuser1   FailedLogon  4625
    8/5/2025 4:35:09 PM  tuser1   FailedLogon  4625

.EXAMPLE
    -MaxRecordsToReturn 10 -ExcludeUsersFromReport "tuser1"

    [Info] The following users will be excluded from the report: 'tuser1'

    [Info] Found 121 logon history events.

    [Info] More than 10 record(s) found, trimming the list to the maximum number of records specified.

    Time                 Username      Event          ID
    ----                 --------      -----          --
    8/4/2025 3:29:11 PM  Administrator SessionStart 4624
    8/4/2025 3:29:13 PM  Administrator SessionStop  4634
    8/4/2025 3:29:34 PM  Administrator SessionStart 4624
    8/5/2025 12:39:57 PM Administrator SessionStart 4624
    8/5/2025 4:35:12 PM  Administrator FailedLogon  4625
    8/5/2025 4:35:14 PM  Administrator SessionStart 4624
    8/5/2025 4:35:14 PM  Administrator SessionStop  4634
    8/5/2025 4:36:04 PM  tuser2        SessionStart 4624
    8/5/2025 4:37:14 PM  tuser4        SessionStart 4624
    8/6/2025 8:56:04 AM  tuser4        SessionStart 4624

.EXAMPLE
    -InTheLastXDays 1

    [Info] Found 13 logon history events.

    Time                 Username      Event          ID
    ----                 --------      -----          --
    8/5/2025 12:39:44 PM tuser1        FailedLogon  4625
    8/5/2025 12:39:49 PM tuser1        FailedLogon  4625
    8/5/2025 12:39:51 PM tuser1        FailedLogon  4625
    8/5/2025 12:39:57 PM Administrator SessionStart 4624
    8/5/2025 4:35:04 PM  tuser1        FailedLogon  4625
    8/5/2025 4:35:07 PM  tuser1        FailedLogon  4625
    8/5/2025 4:35:09 PM  tuser1        FailedLogon  4625
    8/5/2025 4:35:12 PM  Administrator FailedLogon  4625
    8/5/2025 4:35:14 PM  Administrator SessionStart 4624
    8/5/2025 4:35:14 PM  Administrator SessionStop  4634
    8/5/2025 4:36:04 PM  tuser2        SessionStart 4624
    8/5/2025 4:37:14 PM  tuser4        SessionStart 4624
    8/6/2025 8:56:04 AM  tuser4        SessionStart 4624

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 2.0
    Release Notes: Brought up to standards. Added support for multiline and WYSIWYG custom fields. Added 'Max Records to Return' parameter.
                   Added 'Exclude Users From Report' and 'Retrieve Excluded Users From Custom Field' parameters.
                   'Users To Report On' parameter now allows for multiple usernames, separated by commas.
                   Improved input validation, error handling, and multi-language support.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$UsersToReportOn,
    [Parameter()]
    [string]$ExcludeUsersFromReport,
    [Parameter()]
    [string]$RetrieveExcludedUsersFromCustomField,
    [Parameter()]
    $InTheLastXDays,
    [Parameter()]
    $MaxRecordsToReturn,
    [Parameter()]
    [string]$MultilineCustomFieldName,
    [Parameter()]
    [string]$WYSIWYGCustomFieldName
)

begin {
    # Import script variables
    if ($env:UsersToReportOn) { $UsersToReportOn = $env:UsersToReportOn }
    if ($env:ExcludeUsersFromReport) { $ExcludeUsersFromReport = $env:ExcludeUsersFromReport }
    if ($env:RetrieveExcludedUsersFromCustomField) { $RetrieveExcludedUsersFromCustomField = $env:RetrieveExcludedUsersFromCustomField }
    if ($env:inTheLastXDays) { $InTheLastXDays = $env:inTheLastXDays }
    if ($env:maxRecordsToReturn) { $MaxRecordsToReturn = $env:maxRecordsToReturn }
    if ($env:multilineCustomFieldName) { $MultilineCustomFieldName = $env:multilineCustomFieldName }
    if ($env:wysiwygCustomFieldName) { $WYSIWYGCustomFieldName = $env:wysiwygCustomFieldName }

    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Validate the user to report on parameter
    if ($UsersToReportOn) {
        $UsersToReportOn = $UsersToReportOn.Trim()

        # Error if the UsersToReportOn value is empty or only whitespace
        if ([string]::IsNullOrWhiteSpace($UsersToReportOn)) {
            Write-Host -Object "[Error] The 'Users To Report On' value is empty."
            Write-Host -Object "[Error] Please provide a list of valid user names to report on separated by commas, or leave it blank."
            exit 1
        }

        # Initialize a list of users to report on
        $IncludeTheseUsersOnly = [System.Collections.Generic.List[string]]::new()

        # Split the string by commas to get individual usernames
        $UsersToReportOnArray = $UsersToReportOn -split ","

        # Add each user to the list of users to report on, trimming whitespace
        foreach ($User in $UsersToReportOnArray) {
            $IncludeTheseUsersOnly.Add($User.Trim())
        }

        Write-Host -Object "[Info] Only the following users will be included in the report: $($IncludeTheseUsersOnly -join "', '" -replace "^", "'" -replace "$", "'")`n"
    }

    if ($ExcludeUsersFromReport -or $RetrieveExcludedUsersFromCustomField) {
        # Initialize a list of users to exclude from the report
        $UsersToExclude = [System.Collections.Generic.List[string]]::new()

        # Validate the 'Exclude Users From Report' parameter and add the users to the exclusion list
        if ($ExcludeUsersFromReport) {
            $ExcludeUsersFromReport = $ExcludeUsersFromReport.Trim()

            if ([string]::IsNullOrWhiteSpace($ExcludeUsersFromReport)) {
                Write-Host -Object "[Error] The 'Exclude Users From Report' value is empty."
                Write-Host -Object "[Error] Please provide a valid list of user names separated by commas to exclude from the report, or leave it blank."
                exit 1
            }

            # Split the string by commas into an array
            $ExcludeUsersFromReportArray = $ExcludeUsersFromReport -split ","

            # Add each user to the exclusion list, trimming whitespace
            foreach ($User in $ExcludeUsersFromReportArray) {
                $UsersToExclude.Add($User.Trim())
            }
        }

        # Validate the 'Retrieve Excluded Users From Custom Field' parameter and add the users to the exclusion list
        if ($RetrieveExcludedUsersFromCustomField) {
            $RetrieveExcludedUsersFromCustomField = $RetrieveExcludedUsersFromCustomField.Trim()

            # Error if the custom field value is empty or only whitespace
            if ([string]::IsNullOrWhiteSpace($RetrieveExcludedUsersFromCustomField)) {
                Write-Host -Object "[Error] The 'Retrieve Excluded Users From Custom Field' value is empty."
                Write-Host -Object "[Error] Please provide a valid custom field name to retrieve excluded users from, or leave it blank to not retrieve excluded users from a custom field."
                Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
                exit 1
            }

            # Error if the custom field name contains invalid characters
            if ($RetrieveExcludedUsersFromCustomField -match "[^0-9A-Z]") {
                Write-Host -Object "[Error] The 'Retrieve Excluded Users From Custom Field Custom Field Name' of '$RetrieveExcludedUsersFromCustomField' contains invalid characters."
                Write-Host -Object "[Error] Please provide a valid custom field name to retrieve excluded users from, or leave it blank."
                Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
                exit 1
            }

            # Attempt to retrieve the excluded users from the specified custom field
            try {
                Write-Host -Object "[Info] Attempting to retrieve excluded users from the custom field '$RetrieveExcludedUsersFromCustomField'."
                $ExcludedUsersFromCustomField = Get-NinjaProperty -Name $RetrieveExcludedUsersFromCustomField -ErrorAction Stop
                Write-Host -Object "[Info] Successfully retrieved excluded users from the custom field '$RetrieveExcludedUsersFromCustomField'.`n"

                if ($ExcludedUsersFromCustomField) {
                    # Split the string by commas into an array
                    $ExcludedUsersFromCustomField = $ExcludedUsersFromCustomField -split ","

                    # Add each user to the exclusions list, trimming whitespace
                    foreach ($User in $ExcludedUsersFromCustomField) {
                        $UsersToExclude.Add($User.Trim())
                    }
                }
            }
            catch {
                Write-Host -Object "[Error] Failed to retrieve excluded users from the custom field '$RetrieveExcludedUsersFromCustomField'."
                Write-Host -Object "[Error] $($_.Exception.Message)"
                exit 1
            }
        }

        # Error if a user that is excluded is also included
        if ($IncludeTheseUsersOnly) {
            $DuplicateUsers = $IncludeTheseUsersOnly | Where-Object { $UsersToExclude -contains $_ }
            if ($DuplicateUsers) {
                Write-Host -Object "[Error] The following users are both included and excluded from the report: $($DuplicateUsers -join "', '" -replace "^", "'" -replace "$", "'")"
                Write-Host -Object "[Error] Please make sure that the users included in the 'Users To Report On' parameter are not also excluded."
                exit 1
            }
        }

        Write-Host -Object "[Info] The following users will be excluded from the report: $($UsersToExclude -join "', '" -replace "^", "'" -replace "$", "'")`n"
    }

    # Validate the 'In The Last X Days' value
    if ($InTheLastXDays) {
        # Error if the value cannot be converted to an integer
        try {
            $InTheLastXDays = [int]$InTheLastXDays
        }
        catch {
            Write-Host "[Error] Failed to convert the 'In The Last X Days' value '$InTheLastXDays' to an integer. Please provide a valid integer value greater than 0 and less than or equal to 2147483647."
            Write-Host "[Error] $($_.Exception.Message)"
            exit 1
        }

        # Error if the value is less than 1
        if ($InTheLastXDays -lt 1) {
            Write-Host -Object "[Error] The 'In The Last X Days' must be greater than or equal to 1."
            Write-Host -Object "[Error] Please provide a valid integer value for 'In The Last X Days'."
            exit 1
        }

        # Calculate the maximum number of days we can go back in time
        $MaxValueOfInLastXDays = (Get-Date) - [datetime]::MinValue

        # Error if the value would result in an invalid date
        if ($InTheLastXDays -gt $MaxValueOfInLastXDays.Days) {
            Write-Host -Object "[Error] The 'In The Last X Days' value of '$InTheLastXDays' is too large and would result in an invalid date filter."
            Write-Host -Object "[Error] Please provide a valid integer value for 'In The Last X Days' that is greater than 0 and less than or equal to $($MaxValueOfInLastXDays.Days)."
            exit 1
        }
    }

    # Validate the 'Max Records To Return' value
    if ($MaxRecordsToReturn) {
        # Error if the 'Max Records To Return' value cannot be converted to an integer
        try {
            $MaxRecordsToReturn = [int]$MaxRecordsToReturn
        }
        catch {
            Write-Host "[Error] Failed to convert the 'Max Records to Return' value '$MaxRecordsToReturn' to an integer. Please provide a valid integer value greater than 0 and less than or equal to 2147483647."
            Write-Host "[Error] $($_.Exception.Message)"
            exit 1
        }

        # Error if the 'Max Records To Return' value is less than 1
        if ($MaxRecordsToReturn -lt 1) {
            Write-Host -Object "[Error] The 'Max Records to Return' must be greater than or equal to 1."
            Write-Host -Object "[Error] Please provide a valid integer value for 'Max Records to Return'."
            exit 1
        }
    }

    # Validate the 'Multiline Custom Field Name'
    if ($MultilineCustomFieldName) {
        $MultilineCustomFieldName = $MultilineCustomFieldName.Trim()

        # Error if the custom field name is empty
        if ([string]::IsNullOrWhiteSpace($MultilineCustomFieldName)) {
            Write-Host -Object "[Error] The 'Multiline Custom Field Name' is empty."
            Write-Host -Object "[Error] Please provide a valid multiline custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }

        # Error if the custom field name contains invalid characters
        if ($MultilineCustomFieldName -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'Multiline Custom Field Name' of '$MultilineCustomFieldName' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid multiline custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Validate the 'WYSIWYG Custom Field Name'
    if ($WYSIWYGCustomFieldName) {
        $WYSIWYGCustomFieldName = $WYSIWYGCustomFieldName.Trim()

        # Error if the custom field name is empty
        if ([string]::IsNullOrWhiteSpace($WYSIWYGCustomFieldName)) {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' is empty."
            Write-Host -Object "[Error] Please provide a valid WYSIWYG custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }

        # Error if the custom field name contains invalid characters
        if ($WYSIWYGCustomFieldName -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' of '$WYSIWYGCustomFieldName' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid WYSIWYG custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Function to test if the script is running as the SYSTEM account
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
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running this script in an elevated session."
        exit 1
    }

    if (!$IsElevated) {
        Write-Host -Object "[Error] The user '$env:USERNAME' is not running this script in an elevated session. Please run this script as System."
        exit 1
    }

    # Error if not running as SYSTEM
    if (-not (Test-IsSystem)) {
        Write-Host -Object "[Error] This script must be run as the SYSTEM account."
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

    # Warn if logon and logoff auditing is not enabled
    if ($AuditPolicy.LogonAuditing -ne "Enabled" -or $AuditPolicy.LogoffAuditing -ne "Enabled") {
        Write-Host -Object "[Warning] Logon and/or logoff auditing is not fully enabled on this system."
        Write-Host -Object "[Warning] Please enable logon and logoff auditing using the 'Enable or Disable User Logon/Logoff Auditing' script in the Template Library to accurately track new events."
        Write-Host -Object "[Warning] Logon Status: $($AuditPolicy.LogonAuditing), Logoff Status: $($AuditPolicy.LogoffAuditing)"
    }

    # Define an array of system account SIDs that will be filtered out of the results
    $SystemUserSIDs = @(
        "S-1-5-18"  # SYSTEM
        "S-1-5-19"  # LOCAL SERVICE
        "S-1-5-20"  # NETWORK SERVICE
    )

    # Initialize a hashtable filter for the desired events
    $FilterHashtable = @{
        LogName = "Security"
        Id      = 4634, 4624, 4625
    }

    # If 'In The Last X Days' was specified, then add a StartTime to the filter hashtable
    if ($InTheLastXDays) {
        try {
            $StartTimeFilter = (Get-Date -ErrorAction Stop).AddDays(-$InTheLastXDays)
        }
        catch {
            Write-Host "[Error] Failed to create a start time filter with the 'In The Last X Days' value '$InTheLastXDays'."
            Write-Host "[Error] Please enter a valid integer value greater than 0 and less than or equal to $($MaxValueOfInLastXDays.Days)."
            Write-Host "[Error] $($_.Exception.Message)"
            exit 1
        }

        $FilterHashtable.Add("StartTime", $StartTimeFilter)
    }

    # Initialize the list of events to return
    $LogonHistoryEvents = New-Object System.Collections.Generic.List[PSCustomObject]

    # Retrieve events matching the criteria from the event logs
    try {
        $MatchingEvents = Get-WinEvent -FilterHashtable $FilterHashtable -ErrorAction Stop
    }
    catch {
        # Get-WinEvent will throw an exception if no events are found, we do not want to exit the script in this case
        if (-not ($_.FullyQualifiedErrorId -match "NoMatchingEventsFound")) {
            Write-Host -Object "[Error] Error retrieving events from the event logs."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    # Process each event to populate the events list
    foreach ($Event in $MatchingEvents) {
        # The username in the events are in different places in the Properties array
        if ($Event.Id -eq 4634) {
            $EventUserSID = $Event.Properties[0].Value
            $EventUser = $Event.Properties[1].Value
        }
        else {
            $EventUserSID = $Event.Properties[4].Value
            $EventUser = $Event.Properties[5].Value
        }

        # Skip the event if the user is a system user (SYSTEM, NETWORK SERVICE, LOCAL SERVICE)
        if ($EventUserSID -in $SystemUserSIDs) {
            continue
        }

        # Skip the event if the user is in the exclusion list
        if ($EventUser -in $UsersToExclude) {
            continue
        }

        # Skip the event if the user is a Desktop Window Manager or User Mode Framework Drive account, or computer account logons
        if ($EventUser -like "DWM-*" -or $EventUser -like "UMFD-*" -or $EventUser -like "*$") {
            continue
        }

        # Skip the event if the 'Users To Report On' parameter was specified and the event user does not match the specified users
        if ($UsersToReportOn -and $EventUser -notin $IncludeTheseUsersOnly) {
            continue
        }

        # Create a custom logon event object with the relevant properties
        $LogonEventObject = [PSCustomObject]@{
            Time     = $Event.TimeCreated
            Username = $EventUser
            Event    = if ($Event.Id -eq 4634) { "SessionStop" } elseif ($Event.ID -eq 4625) { "FailedLogon" } else { "SessionStart" }
            ID       = $Event.ID
        }

        # Add the logon event object to the list of logon history events
        $LogonHistoryEvents.Add($LogonEventObject)

        # Nullify the variables to prepare for the next run
        $LogonEventObject = $null
        $EventUser = $null
        $EventUserSID = $null
    }

    # Sort the logon history events by time so newer events are at the top
    $LogonHistoryEvents = $LogonHistoryEvents | Sort-Object -Property Time -Descending

    # Count the number of logon history events found
    $LogonHistoryEventsCount = ($LogonHistoryEvents | Measure-Object).Count

    if ($LogonHistoryEventsCount -eq 0) {
        Write-Host "[Info] No logon history events found for the specified criteria.`n"
    }
    else {
        Write-Host "[Info] Found $LogonHistoryEventsCount logon history events.`n"

        # If a maximum number of records was given and the number of records exceeds the maximum, trim the list to the maximum number of records
        if ($MaxRecordsToReturn -and $LogonHistoryEventsCount -gt $MaxRecordsToReturn) {
            Write-Host "[Info] More than $MaxRecordsToReturn record(s) found, trimming the list to the maximum number of records specified.`n"
            $LogonHistoryEvents = $LogonHistoryEvents | Select-Object -First $MaxRecordsToReturn
            $LogonHistoryEventsCount = ($LogonHistoryEvents | Measure-Object).Count
        }
    }

    # Set the multiline custom field if specified
    if ($MultilineCustomFieldName) {
        # If there are still events to display, format the logon history events into a multiline string
        if ($LogonHistoryEventsCount -gt 0) {
            $CustomFieldValue = foreach ($Event in $LogonHistoryEvents) {
                "Time: $($Event.Time), User: $($Event.Username), Event: $($Event.Event), ID: $($Event.ID)"
            }

            # Define the character limit for multiline custom fields
            $multilineCharacterThreshold = 9500

            # Convert the multiline string to a single string with line breaks
            $CustomFieldValue = $CustomFieldValue | Out-String

            # Measure the total character count of the formatted string
            $Characters = $CustomFieldValue | Measure-Object -Character | Select-Object -ExpandProperty Characters

            # Check if the value would exceed the multiline custom field character limit and truncate if so
            if ($Characters -ge $multilineCharacterThreshold) {
                Write-Host "[Warning] 10,000 Character Limit for Multiline fields has been reached! Trimming output until the character limit is satisfied..."

                # Add note to the top of the multiline field that the list has been truncated
                $CustomFieldValue = $CustomFieldValue -replace "^", "This info has been truncated to accommodate the 10,000 character limit.`n`n"

                # Regex to extract rows from the multiline field
                $rowRegex = "Time.+ID: \d+"

                while ($Characters -ge $multilineCharacterThreshold) {
                    # Create a collection of rows in the table
                    $rows = [regex]::Matches($CustomFieldValue, $rowRegex)

                    # Get the value of the last row
                    $lastRowValue = $rows | Select-Object -Last 1 -ExpandProperty Value

                    # Remove the last row from the table
                    $CustomFieldValue = $CustomFieldValue -replace [regex]::Escape($lastRowValue)

                    # Check that we now comply with the character limit, if not restart the loop
                    $Characters = $CustomFieldValue | Measure-Object -Character | Select-Object -ExpandProperty Characters
                }
            }
        }
        else {
            $CustomFieldValue = "No results found."
        }

        # Attempt to set the multiline custom field
        try {
            Write-Host "[Info] Attempting to set the multiline custom field '$MultilineCustomFieldName'."
            Set-NinjaProperty -Name $MultilineCustomFieldName -Value $CustomFieldValue -ErrorAction Stop
            Write-Host "[Info] Successfully set the multiline custom field."
        }
        catch {
            Write-Host "[Error] Failed to set the multiline custom field '$MultilineCustomFieldName'."
            Write-Host "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
        Write-Host ""
    }

    # Set the WYSIWYG custom field if specified
    if ($WYSIWYGCustomFieldName) {
        # If there are still events to display, format the logon history events into an HTML table
        if ($LogonHistoryEventsCount -gt 0) {
            # Convert the logon history events to an HTML table
            $HtmlTable = $LogonHistoryEvents | ConvertTo-Html -Fragment

            # Format the HTML table
            $HtmlTable = "<div class='card flex-grow-1'>
                            <div class='card-title-box'>
                                <div class='card-title'><i class='fa-solid fa-users'></i>&nbsp;&nbsp;User Logon History</div>
                            </div>
                            <div class='card-body' style='white-space: nowrap;'>
                                $HtmlTable
                            </div>
                        </div>"

            # Define the character limit threshold for WYSIWYG fields
            $wysiwygCharacterThreshold = 44500

            # Check that the output complies with the hard character limits
            $Characters = $HtmlTable | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters

            # If output exceeds the WYSIWYG character limit, truncate the output
            if ($Characters -ge $wysiwygCharacterThreshold) {
                Write-Host "[Warning] 45,000 Character Limit for WYSIWYG fields has been reached! Trimming output until the character limit is satisfied..."

                # Add notice about truncation to the top of the table
                $HtmlTable = $HtmlTable -replace "<table>", "<p>This info has been truncated to accommodate the 45,000 character limit.</p><table>"

                # Regex expression to match tables in the HTML
                $rowRegex = '<tr>.*?</tr>'

                while ($Characters -ge $wysiwygCharacterThreshold) {
                    # Create a collection of rows in the table
                    $rows = [regex]::Matches($HtmlTable, $rowRegex)

                    # Get the value of the last row
                    $lastRowValue = $rows | Select-Object -Last 1 -ExpandProperty Value

                    # Remove the last row from the table
                    $HtmlTable = $HtmlTable -replace [regex]::Escape($lastRowValue)

                    # Check that we now comply with the character limit, if not restart the loop
                    $Characters = $HtmlTable | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
                }
            }
        }
        else {
            $HtmlTable = "<p>No results found.</p>"
        }

        # Attempt to set the WYSIWYG field
        try {
            Write-Host "[Info] Attempting to set the WYSIWYG custom field '$WYSIWYGCustomFieldName'."
            Set-NinjaProperty -Name $WYSIWYGCustomFieldName -Value $HtmlTable -ErrorAction Stop
            Write-Host "[Info] Successfully set the WYSIWYG custom field."
        }
        catch {
            Write-Host "[Error] Failed to set the WYSIWYG custom field '$WYSIWYGCustomFieldName'."
            Write-Host "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
        Write-Host ""
    }

    # If there are still events to display, output the events to the activity feed
    if ($LogonHistoryEventsCount -gt 0) {
        # Define the character threshold for the activity feed output
        # This needs to be lower than the 10k limit to account for other output in this script
        $ActivityFeedCharacterThreshold = 9500

        # Measure the number of characters in the logon history events output
        $ActivityFeedCharacters = $LogonHistoryEvents | Format-Table -AutoSize | Out-String | Measure-Object -Character | Select-Object -ExpandProperty Characters

        # Truncate the activity feed output if it exceeds the character limit
        # Otherwise, output the logon history events to the activity feed
        if ($ActivityFeedCharacters -gt $ActivityFeedCharacterThreshold) {
            Write-Host -Object "[Warning] Activity feed output exceeds the 10,000 character limit. Trimming output until the character limit is satisfied...`n"

            # Create a copy of the logon history events to truncate
            $TruncatedActivityFeedOutput = $LogonHistoryEvents.PSObject.Copy()

            # Loop until the character count is under the threshold
            while ($ActivityFeedCharacters -gt $ActivityFeedCharacterThreshold) {
                # Calculate how far over the limit we are
                $ExceededAmount = $ActivityFeedCharacters - $ActivityFeedCharacterThreshold

                # Determine how many records to skip based on the exceeded amount
                if ($ExceededAmount -le 0) {
                    $SkipAmount = 1
                }
                else {
                    $SkipAmount = [math]::Ceiling($ExceededAmount / 100)
                }

                # Remove the determined amount of records from the end of the truncated object
                $TruncatedActivityFeedOutput = $TruncatedActivityFeedOutput | Select-Object -SkipLast $SkipAmount

                # Update the character count
                $ActivityFeedCharacters = $TruncatedActivityFeedOutput | Format-Table -AutoSize | Out-String | Measure-Object -Character | Select-Object -ExpandProperty Characters
            }

            Write-Host -Object "[Warning] The truncated output is showing only the most recent $($TruncatedActivityFeedOutput.Count) record(s).`n"

            # Output the truncated results to the activity feed
            ($TruncatedActivityFeedOutput | Format-Table -AutoSize | Out-String).Trim() | Write-Host
        }
        else {
            ($LogonHistoryEvents | Format-Table -AutoSize | Out-String).Trim() | Write-Host
        }
    }

    exit $ExitCode
}
end {
    
    
    
}