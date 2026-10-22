#Requires -Version 5.1

<#
.SYNOPSIS
    Retrieves and reports on active Active Directory users based on their last login date.
.DESCRIPTION
    Retrieves and reports on active Active Directory users based on their last login date.
.EXAMPLE
    -MaximumDaysSinceLastLogin 30

    Retrieving Active Directory Users.
    [Alert] Less than 50% of users are considered active.

    Active Users: 2
    Total Users: 14
    Percent Active: 14.29%

    ### Inactive Users ###
    SamAccountName UserPrincipalName mail               LastLogonDate
    -------------- ----------------- ----               -------------
    DefaultAccount                                      Never
    Guest                                               Never
    krbtgt                                              Never
    tuser1         tuser1@test.lan   tuser1@example.com Never
    tuser2         tuser2@test.lan   tuser2@example.com Never
    tuser3         tuser3@test.lan   tuser3@example.com Never
    tuser4         tuser4@test.lan   tuser4@example.com Never
    tuser5         tuser5@test.lan   tuser5@example.com Never
    tuser6         tuser6@test.lan   tuser6@example.com Never
    tuser7         tuser7@test.lan   tuser7@example.com Never
    tuser8         tuser8@test.lan   tuser8@example.com Never
    tuser9         tuser9@test.lan   tuser9@example.com Never

    ### Active Users ###
    SamAccountName UserPrincipalName mail               LastLogonDate
    -------------- ----------------- ----               -------------
    Administrator                                       3/27/2026 11:23 AM
    cheart         cheart@test.lan   cheart@example.com 4/15/2026 3:19 PM

.PARAMETER MaximumDaysSinceLastLogin
    The maximum number of days since a user's last login for them to be considered active. Only users who have logged in within this number of days will be included in the active user count.

.PARAMETER MultilineCustomFieldName
    Optionally provide the name of a multiline custom field to save the report results to.

.PARAMETER WYSIWYGCustomFieldName
    Optionally provide the name of a WYSIWYG custom field to save a summary card and user table to.

.PARAMETER ExcludeDisabledUsers
    When enabled, users who are currently disabled in Active Directory will be excluded from the report.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 2.0
    Release Notes:
        - Renamed $NumberOfDays to $MaximumDaysSinceLastLogin
        - Renamed $CustomFieldName to $MultilineCustomFieldName
        - Added WYSIWYG custom field support
        - Added parameter validation
        - Consolidated Get-ADUser calls
        - Added try/catch error handling
        - Output changed to summary counts
        - Split output between inactive and active
        - Added [Alert]/[Warning] output
        - Multiline field saves summary only
        - Errors use Write-Host
#>

[CmdletBinding()]
param (
    [Parameter()]
    [Int]$MaximumDaysSinceLastLogin,
    [Parameter()]
    [String]$MultilineCustomFieldName = $env:multilineCustomFieldName,
    [Parameter()]
    [String]$WYSIWYGCustomFieldName = $env:wysiwygCustomFieldName,
    [Parameter()]
    [Switch]$ExcludeDisabledUsers = [System.Convert]::ToBoolean($env:excludeDisabledUsersFromReport)
)

begin {
    #region Script form variable mapping
    # Map the maximum days form variable to the parameter if it was provided
    if ($env:maximumDaysSinceLastLogin) {
        # Reject values containing non-numeric characters before attempting conversion
        if ($env:maximumDaysSinceLastLogin -match "[^0-9]") {
            Write-Host -Object "[Error] The maximum number of days you have specified '$env:maximumDaysSinceLastLogin' is invalid. It contains invalid characters."
            Write-Host -Object "[Error] Please specify a positive whole number that is between 1 and 1825 (inclusive)."
            exit 1
        }

        try {
            $MaximumDaysSinceLastLogin = $env:maximumDaysSinceLastLogin
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] The maximum number of days you have specified '$env:maximumDaysSinceLastLogin' is invalid."
            Write-Host -Object "[Error] Please specify a positive whole number that is between 1 and 1825 (inclusive)."
            exit 1
        }
    }
    #endregion

    #region OS version check
    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }
    #endregion

    #region Validation
    # Ensure the required MaximumDaysSinceLastLogin was provided
    if (!$MaximumDaysSinceLastLogin) {
        Write-Host -Object "[Error] You must specify the maximum number of days for a user to be considered active."
        Write-Host -Object "[Error] Please specify a positive whole number that is between 1 and 1825 (inclusive)."
        exit 1
    }

    # Ensure the value falls within the supported range
    if ($MaximumDaysSinceLastLogin -lt 1 -or $MaximumDaysSinceLastLogin -gt 1825) {
        Write-Host -Object "[Error] The maximum number of days you have specified '$MaximumDaysSinceLastLogin' is invalid. It is not within the valid range."
        Write-Host -Object "[Error] Please specify a positive whole number that is between 1 and 1825 (inclusive)."
        exit 1
    }

    # Validate the Multiline custom field name if provided
    if ($MultilineCustomFieldName) {
        # Validate that the field is not just whitespace
        if ([String]::IsNullOrWhiteSpace($MultilineCustomFieldName)) {
            Write-Host -Object "[Error] The 'Multiline Custom Field Name' parameter contains only spaces. Please provide a valid field name or leave it blank."
            exit 1
        }

        # Trim the field name to remove leading and trailing whitespace
        $MultilineCustomFieldName = $MultilineCustomFieldName.Trim()

        # Validate that the field name contains only alphanumeric characters
        if ($MultilineCustomFieldName -match "[^0-9A-Za-z]") {
            Write-Host -Object "[Error] The 'Multiline Custom Field Name' of '$MultilineCustomFieldName' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid multiline custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Validate the WYSIWYG custom field name if provided
    if ($WYSIWYGCustomFieldName) {
        # Validate that the field is not just whitespace
        if ([String]::IsNullOrWhiteSpace($WYSIWYGCustomFieldName)) {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' parameter contains only spaces. Please provide a valid field name or leave it blank."
            exit 1
        }

        # Trim the field name to remove leading and trailing whitespace
        $WYSIWYGCustomFieldName = $WYSIWYGCustomFieldName.Trim()

        # Validate that the field name contains only alphanumeric characters
        if ($WYSIWYGCustomFieldName -match "[^0-9A-Za-z]") {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' of '$WYSIWYGCustomFieldName' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid WYSIWYG custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }
    #endregion

    #region Helper functions
    function Test-IsDomainController {
        [CmdletBinding()]
        param()

        # Determine the method to retrieve the operating system information based on PowerShell version
        $OS = if ($PSVersionTable.PSVersion.Major -lt 3) {
            Get-WmiObject -Class Win32_OperatingSystem
        } else {
            Get-CimInstance -ClassName Win32_OperatingSystem
        }

        # Check if the ProductType is 2, which indicates that the system is a domain controller
        if ($OS.ProductType -eq 2) {
            return $true
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
    #endregion

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    #region Pre-flight checks
    # Attempt to determine if the current session is running with Administrator privileges.
    try {
        $IsElevated = Test-IsElevated -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running this script in an elevated session."
        exit 1
    }

    if (!$IsElevated) {
        Write-Host -Object "[Error] The user '$env:USERNAME' is not running this script in an elevated session. Please run this script as System or in an elevated session."
        exit 1
    }

    # Verify the script is running on a domain controller, which is required to query Active Directory.
    try {
        $IsDomainController = Test-IsDomainController -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the current device is a domain controller."
        exit 1
    }

    if (!$IsDomainController) {
        Write-Host -Object "[Error] This device is not a domain controller. Unable to retrieve the list of active Active Directory users."
        exit 1
    }

    # Verify that the ActiveDirectory PowerShell module is available on this system.
    try {
        $ActiveDirectoryModule = Get-Module -ListAvailable "ActiveDirectory" -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to locate the ActiveDirectory PowerShell module."
        exit 1
    }

    if (!$ActiveDirectoryModule) {
        Write-Host -Object "[Error] The ActiveDirectory PowerShell module was not found on this device. Unable to continue."
        exit 1
    }
    #endregion

    #region Data collection
    Write-Host -Object "Retrieving Active Directory Users."

    $ActiveDirectoryUsers = Get-ADUser -Filter "*" -Properties @("SamAccountName", "UserPrincipalName", "mail", "LastLogonDate", "Enabled")

    # If requested, remove disabled user accounts from the dataset before reporting.
    if ($ExcludeDisabledUsers) {
        Write-Host -Object "Filtering out disabled users."
        $ActiveDirectoryUsers = $ActiveDirectoryUsers | Where-Object { $_.Enabled -eq $True }
    }
    #endregion

    #region Data processing
    # Filter to users who have logged in within the specified number of days.
    try {
        $ActiveUsers = $ActiveDirectoryUsers | Where-Object {
            $_.LastLogonDate -and (New-TimeSpan -Start $_.LastLogonDate -End (Get-Date -ErrorAction Stop) -ErrorAction Stop).Days -le $MaximumDaysSinceLastLogin
        }

        $InactiveUsers = $ActiveDirectoryUsers | Where-Object {
            !$_.LastLogonDate -or ((New-TimeSpan -Start $_.LastLogonDate -End (Get-Date -ErrorAction Stop) -ErrorAction Stop).Days -gt $MaximumDaysSinceLastLogin)
        }
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve the list of active Active Directory Users."
        exit 1
    }

    # Calculate the count of active and total users and derive the percentage that are active.
    try {
        $ActiveUserCount = ($ActiveUsers | Measure-Object -ErrorAction Stop).Count
        $TotalUserCount = ($ActiveDirectoryUsers | Measure-Object -ErrorAction Stop).Count

        # Avoid division by zero when no users are present
        if ($TotalUserCount -eq 0) {
            $PercentActive = 0
        } else {
            $PercentActive = [Math]::Round(($ActiveUserCount / $TotalUserCount * 100), 2)
        }

        # Compute a display-ready string with the percent sign for all output sites
        $PercentDisplay = "$PercentActive%"
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to calculate the active user statistics."
        exit 1
    }
    #endregion

    #region Activity log output
    # Report notable conditions such as no active users or a low active user percentage.
    if ($PercentActive -lt 50) {
        Write-Host -Object "[Alert] Less than 50% of users are considered active."
    }

    if ($ActiveUserCount -lt 1) {
        Write-Host -Object "[Alert] No active users were found."
    }

    if ($TotalUserCount -lt 1) {
        Write-Host -Object "[Warning] No users were detected."
    }

    Write-Host -Object "`nActive Users: $ActiveUserCount"
    Write-Host -Object "Total Users: $TotalUserCount"
    Write-Host -Object "Percent Active: $PercentDisplay"

    # Print a blank separator line before custom field output
    if ($MultilineCustomFieldName -or $WYSIWYGCustomFieldName) { Write-Host -Object "" }
    #endregion

    #region Multiline output
    if ($MultilineCustomFieldName) {
        $CustomFieldValue = New-Object -TypeName System.Collections.Generic.List[String]
        $CustomFieldValue.Add("Active Users: $ActiveUserCount")
        $CustomFieldValue.Add("Total Users: $TotalUserCount")
        $CustomFieldValue.Add("Percent Active: $PercentDisplay")

        try {
            Write-Host -Object "Attempting to set the custom field '$MultilineCustomFieldName'."
            $CustomFieldValue | Set-NinjaProperty -Name $MultilineCustomFieldName -ErrorAction Stop
            Write-Host -Object "Successfully set the custom field."
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to set the custom field '$MultilineCustomFieldName'."
        }
    }
    #endregion

    #region WYSIWYG output
    if ($WYSIWYGCustomFieldName) {
        # Cast $PercentActive to double for numeric comparisons in color and alert logic
        $PercentNumeric = [double]$PercentActive

        # Choose stat card colors based on alert conditions
        $ActiveColor = if ($ActiveUserCount -lt 1) { '#dc3545' } else { '#008001' }
        $TotalColor = if ($TotalUserCount -lt 1) { '#dc3545' } else { '#337ab7' }
        $PercentColor = if ($TotalUserCount -lt 1 -or $ActiveUserCount -lt 1 -or $PercentNumeric -lt 20) {
            '#dc3545'
        } elseif ($PercentNumeric -lt 50) {
            '#FAC905'
        } else {
            '#008001'
        }

        # Build alert info-card HTML based on warning conditions
        $AlertsHTML = ''
        if ($TotalUserCount -lt 1) {
            $AlertsHTML = "
        <div class='info-card error'>
            <i class='info-icon fa-solid fa-circle-exclamation'></i>
            <div class='info-text'>
                <div class='info-title' style='color: #151617;'>No Users Detected</div>
                <div class='info-description' style='white-space: normal; color: #151617;'>No Active Directory users were found on this device.</div>
            </div>
        </div>"
        } elseif ($ActiveUserCount -lt 1) {
            $AlertsHTML = "
        <div class='info-card error'>
            <i class='info-icon fa-solid fa-circle-exclamation'></i>
            <div class='info-text'>
                <div class='info-title' style='color: #151617;'>No Active Users Found</div>
                <div class='info-description' style='white-space: normal; color: #151617;'>No users have logged in within the last $MaximumDaysSinceLastLogin day(s). All $TotalUserCount user(s) are considered inactive.</div>
            </div>
        </div>"
        } elseif ($PercentNumeric -lt 50) {
            $AlertsHTML = "
        <div class='info-card warning'>
            <i class='info-icon fa-solid fa-triangle-exclamation'></i>
            <div class='info-text'>
                <div class='info-title' style='color: #151617;'>Low Active User Percentage</div>
                <div class='info-description' style='white-space: normal; color: #151617;'>Less than 50% ($PercentDisplay) of users have logged in within the last $MaximumDaysSinceLastLogin day(s).</div>
            </div>
        </div>"
        }

        # Build user table rows sorted by SamAccountName, marking inactive rows with the danger class
        $TableRows = New-Object -TypeName System.Collections.Generic.List[String]
        $Now = Get-Date
        foreach ($User in ($ActiveDirectoryUsers | Sort-Object -Property SamAccountName)) {
            # Determine whether the user has logged in within the allowed window
            $IsActive = $User.LastLogonDate -and (New-TimeSpan -Start $User.LastLogonDate -End $Now).Days -le $MaximumDaysSinceLastLogin
            $RowClass = if ($IsActive) { '' } else { " class='danger'" }
            $StatusText = if ($IsActive) { 'Active' } else { 'Inactive' }
            $LastLogin = if ($User.LastLogonDate) { "$($User.LastLogonDate.ToShortDateString()) $($User.LastLogonDate.ToShortTimeString())" } else { 'Never' }
            $EncodedSam = [System.Net.WebUtility]::HtmlEncode($User.SamAccountName)
            $EncodedUPN = [System.Net.WebUtility]::HtmlEncode($User.UserPrincipalName)
            $EncodedMail = [System.Net.WebUtility]::HtmlEncode($User.mail)
            $TableRows.Add("<tr$RowClass><td>$EncodedSam</td><td>$EncodedUPN</td><td>$EncodedMail</td><td>$LastLogin</td><td>$StatusText</td></tr>")
        }

        # Assemble the WYSIWYG value; trim rows from the end if the result exceeds the character limit
        $TruncationWarningHTML = ''
        $WYSIWYGValue = "<div>
<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fas fa-users'></i>&nbsp;&nbsp;Active Directory User Summary</div>
    </div>
    <div class='card-body' style='white-space: nowrap;'>
        $AlertsHTML
        <div class='container' style='padding-left: 0px; margin-left: 0px; padding-right: 0px; margin-right: 0px;'>
            <div class='row' style='white-space: pre-wrap;'>
                <div class='col-sm-4'>
                    <div class='stat-card'>
                        <div class='stat-value' style='color: $ActiveColor;'>$ActiveUserCount</div>
                        <div class='stat-desc'><i class='fa-solid fa-user-check'></i>&nbsp;&nbsp;Active Users</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card'>
                        <div class='stat-value' style='color: $TotalColor;'>$TotalUserCount</div>
                        <div class='stat-desc'><i class='fa-solid fa-users'></i>&nbsp;&nbsp;Total Users</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card'>
                        <div class='stat-value' style='color: $PercentColor;'>$PercentDisplay</div>
                        <div class='stat-desc'><i class='fa-solid fa-percent'></i>&nbsp;&nbsp;Percent Active</div>
                    </div>
                </div>
            </div>
        </div>
        $TruncationWarningHTML
        <div style='white-space: normal;'>
            <table>
                <thead>
                    <tr>
                        <th>Username</th>
                        <th>User Principal Name</th>
                        <th>Email</th>
                        <th>Last Login</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    $([String]::Join([System.Environment]::NewLine, $TableRows))
                </tbody>
            </table>
        </div>
    </div>
</div></div>"

        # Remove the last row and add a truncation warning until the value fits within the character limit
        while ($WYSIWYGValue.Length -gt 199999 -and $TableRows.Count -gt 0) {
            $TableRows.RemoveAt($TableRows.Count - 1)
            $TruncationWarningHTML = "
        <div class='info-card warning'>
            <i class='info-icon fa-solid fa-triangle-exclamation'></i>
            <div class='info-text'>
                <div class='info-title' style='color: #151617;'>Table Truncated</div>
                <div class='info-description' style='white-space: normal; color: #151617;'>The user table has been truncated. Not all users are shown.</div>
            </div>
        </div>"
            $WYSIWYGValue = "<div>
<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fas fa-users'></i>&nbsp;&nbsp;Active Directory User Summary</div>
    </div>
    <div class='card-body' style='white-space: nowrap;'>
        $AlertsHTML
        <div class='container' style='padding-left: 0px; margin-left: 0px; padding-right: 0px; margin-right: 0px;'>
            <div class='row' style='white-space: pre-wrap;'>
                <div class='col-sm-4'>
                    <div class='stat-card'>
                        <div class='stat-value' style='color: $ActiveColor;'>$ActiveUserCount</div>
                        <div class='stat-desc'><i class='fa-solid fa-user-check'></i>&nbsp;&nbsp;Active Users</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card'>
                        <div class='stat-value' style='color: $TotalColor;'>$TotalUserCount</div>
                        <div class='stat-desc'><i class='fa-solid fa-users'></i>&nbsp;&nbsp;Total Users</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card'>
                        <div class='stat-value' style='color: $PercentColor;'>$PercentDisplay</div>
                        <div class='stat-desc'><i class='fa-solid fa-percent'></i>&nbsp;&nbsp;Percent Active</div>
                    </div>
                </div>
            </div>
        </div>
        $TruncationWarningHTML
        <div style='white-space: normal;'>
            <table>
                <thead>
                    <tr>
                        <th>Username</th>
                        <th>User Principal Name</th>
                        <th>Email</th>
                        <th>Last Login</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    $([String]::Join([System.Environment]::NewLine, $TableRows))
                </tbody>
            </table>
        </div>
    </div>
</div></div>"
        }

        try {
            Write-Host -Object "Attempting to set the custom field '$WYSIWYGCustomFieldName'."
            Set-NinjaProperty -Name $WYSIWYGCustomFieldName -Value $WYSIWYGValue -Type 'WYSIWYG' -ErrorAction Stop
            Write-Host -Object "Successfully set the custom field."
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to set the custom field '$WYSIWYGCustomFieldName'."
            $ExitCode = 1
        }
    }
    #endregion

    #region User tables
    # Format LastLogonDate as a localized short date and time, or "Never" if the user has no recorded logon
    $LastLogonDateColumn = @{
        Name       = "LastLogonDate"
        Expression = { if ($_.LastLogonDate) { "$($_.LastLogonDate.ToShortDateString()) $($_.LastLogonDate.ToShortTimeString())" } else { "Never" } }
    }

    Write-Host -Object "`n### Inactive Users ###"
    # Display the inactive users table, or a message if none were found
    if ($InactiveUsers) {
        ($InactiveUsers | Sort-Object SamAccountName |
            Format-Table SamAccountName, UserPrincipalName, mail, $LastLogonDateColumn | Out-String).Trim() | Write-Host
    } else {
        Write-Host -Object "No inactive users were found."
    }

    Write-Host -Object "`n### Active Users ###"
    # Display the active users table, or a message if none were found
    if ($ActiveUsers) {
        ($ActiveUsers | Sort-Object SamAccountName |
            Format-Table SamAccountName, UserPrincipalName, mail, $LastLogonDateColumn | Out-String).Trim() | Write-Host
    } else {
        Write-Host -Object "No Active Directory users were found."
    }
    #endregion

    exit $ExitCode
}
end {
    
    
    
}
