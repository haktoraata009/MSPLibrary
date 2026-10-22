#Requires -Version 5.1

<#
.SYNOPSIS
    Generates a report of the current Active Directory environment and optionally saves the information to a WYSIWYG custom field.
.DESCRIPTION
    Generates a report of the current Active Directory environment and optionally saves the information to a WYSIWYG custom field.
.EXAMPLE
    -SummaryWYSIWYG "activeDirectoryReportOverallSummary" -EnabledUsersWYSIWYG "activeDirectoryReportEnabledUsers"
    -DisabledUsersWYSIWYG "activeDirectoryReportDisabledUsers" -GroupMembershipWYSIWYG "activeDirectoryReportGroupMembership"

    Verifying the Active Directory PowerShell module is imported.
    Retrieving the Active Directory domain information and settings.
    Retrieving all the current Active Directory groups.
    Retrieving all the current Active Directory users.

    ### Active Directory Summary ###
    Enabled Users Inactive Users Disabled Users
    ------------- -------------- --------------
               11              9              2

    ## Account Information ##
    [Alert] The Center for Internet Security recommends a lockout threshold of 5 or fewer, but not 0.
    Total Users                : 13
    Lockout Threshold          : Not Set
    Lockout Duration           : 30 minutes
    Lockout Observation Window : 30 minutes

    ## Password Information ##
    [Alert] The Center for Internet Security recommends a minimum password length of 14 or more characters.
    [Alert] The Center for Internet Security recommends enabling password complexity.
    Minimum Password Age    : 1 day(s)
    Maximum Password Age    : 42 day(s)
    Minimum Password Length : 7 Character(s)
    Password Complexity     : Disabled
    Password History Count  : 24 passwords remembered

    ## Active Directory Groups Detected ##
    Security Groups Distribution Lists Builtin Groups Empty Groups
    --------------- ------------------ -------------- ------------
                  8                  0              6           33

    Generating summary report HTML.
    Attempting to set the custom field 'activeDirectoryReportOverallSummary'.
    Success!
    Generating enabled users report HTML.
    Attempting to set the custom field 'activeDirectoryReportEnabledUsers'.
    Success!
    Generating disabled users report HTML.
    Attempting to set the custom field 'activeDirectoryReportDisabledUsers'.
    Success!
    Generating group membership report HTML.
    Attempting to set the custom field 'activeDirectoryReportGroupMembership'.
    Success!

.PARAMETER InactivityDaysLimit
    Defines the number of days since a user's last sign-in to consider their account as inactive.

.PARAMETER SummaryWYSIWYG
    Optionally specify the name of a custom field to save a summary of the current Active Directory environment.

.PARAMETER EnabledUsersWYSIWYG
    Optionally specify the name of a custom field to save a report of the current enabled users in Active Directory.

.PARAMETER DisabledUsersWYSIWYG
    Optionally specify the name of a custom field to save a report of the current disabled users in Active Directory.

.PARAMETER GroupMembershipWYSIWYG
    Optionally specify the name of a custom field to save a report of the current Active Directory group membership.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 2.0
    Release Notes: Enhanced for inclusion in the template library. Improved data validation, added detailed output, improved html reports, and made custom fields optional. Included alert messages for items that do not align with CIS Level 1 recommendations.
#>

[CmdletBinding()]
param (
    [Parameter()]
    $InactivityDaysLimit = 30,
    [Parameter()]
    [String]$SummaryWYSIWYG,
    [Parameter()]
    [String]$EnabledUsersWYSIWYG,
    [Parameter()]
    [String]$DisabledUsersWYSIWYG,
    [Parameter()]
    [String]$GroupMembershipWYSIWYG
)

begin {
    # If script form variables are used, replace the command line parameters with their values.
    if ($env:inactivityDaysLimit) { $InactivityDaysLimit = $env:inactivityDaysLimit }
    if ($env:domainSummaryWysiwygCustomFieldName) { $SummaryWYSIWYG = $env:domainSummaryWysiwygCustomFieldName }
    if ($env:enabledUsersWysiwygCustomFieldName) { $EnabledUsersWYSIWYG = $env:enabledUsersWysiwygCustomFieldName }
    if ($env:disabledUsersWysiwygCustomFieldName) { $DisabledUsersWYSIWYG = $env:disabledUsersWysiwygCustomFieldName }
    if ($env:groupMembershipWysiwygCustomFieldName) { $GroupMembershipWYSIWYG = $env:groupMembershipWysiwygCustomFieldName }

    #region Input Validation

    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Validate that the inactivity days limit is not null or empty
    if ([String]::IsNullOrWhiteSpace($InactivityDaysLimit)) {
        Write-Host -Object "[Error] The 'Days Until Considered Inactive' value is blank. Please enter a number between 1 and 365 (inclusive)."
        exit 1
    }

    # Trim any whitespace from the inactivity days limit if it's a string
    if ($InactivityDaysLimit -is [String]) {
        $InactivityDaysLimit = $InactivityDaysLimit.Trim()
    }

    # Ensure the inactivity days limit contains only numeric characters
    if ($InactivityDaysLimit -match "[^0-9]") {
        Write-Host -Object "[Error] The 'Days Until Considered Inactive' value of '$InactivityDaysLimit' is invalid."
        Write-Host -Object "[Error] It contains invalid characters. Please enter a number between 1 and 365 (inclusive)."
        exit 1
    }

    # Attempt to convert the inactivity days limit to an integer
    try {
        [int]$InactivityDaysLimit = $InactivityDaysLimit
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] The 'Days Until Considered Inactive' value of '$InactivityDaysLimit' is invalid."
        Write-Host -Object "[Error] It contains invalid characters. Please enter a number between 1 and 365 (inclusive)."
        exit 1
    }

    # Ensure the inactivity days limit is within the valid range
    if ($InactivityDaysLimit -lt 1 -or $InactivityDaysLimit -gt 365) {
        Write-Host -Object "[Error] The 'Days Until Considered Inactive' value of '$InactivityDaysLimit' is invalid."
        Write-Host -Object "[Error] Please enter a number between 1 and 365 (inclusive)."
        exit 1
    }

    # Validate the summary WYSIWYG custom field if provided
    if ($SummaryWYSIWYG) {
        if ([String]::IsNullOrWhiteSpace($SummaryWYSIWYG)) {
            Write-Host -Object "[Error] You must provide a valid WYSIWYG custom field to save the summary to."
            exit 1
        }

        $SummaryWYSIWYG = $SummaryWYSIWYG.Trim()

        # Ensure the summary custom field name contains only alphanumeric characters
        if ($SummaryWYSIWYG -match "[^0-9A-Z]") {
            Write-Host "[Error] The summary custom field name provided '$SummaryWYSIWYG' is invalid. It contains non-alphanumeric characters."
            Write-Host "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Validate the enabled users WYSIWYG custom field if provided
    if ($EnabledUsersWYSIWYG) {
        if ([String]::IsNullOrWhiteSpace($EnabledUsersWYSIWYG)) {
            Write-Host -Object "[Error] You must provide a valid WYSIWYG custom field to save the enabled users report to."
            exit 1
        }

        $EnabledUsersWYSIWYG = $EnabledUsersWYSIWYG.Trim()

        # Ensure the enabled users custom field name contains only alphanumeric characters
        if ($EnabledUsersWYSIWYG -match "[^0-9A-Z]") {
            Write-Host "[Error] The enabled users custom field name provided '$EnabledUsersWYSIWYG' is invalid. It contains non-alphanumeric characters."
            Write-Host "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Validate the disabled users WYSIWYG custom field if provided
    if ($DisabledUsersWYSIWYG) {
        if ([String]::IsNullOrWhiteSpace($DisabledUsersWYSIWYG)) {
            Write-Host -Object "[Error] You must provide a valid WYSIWYG custom field to save the disabled users report to."
            exit 1
        }

        $DisabledUsersWYSIWYG = $DisabledUsersWYSIWYG.Trim()

        # Ensure the disabled users custom field name contains only alphanumeric characters
        if ($DisabledUsersWYSIWYG -match "[^0-9A-Z]") {
            Write-Host "[Error] The disabled users custom field name provided '$DisabledUsersWYSIWYG' is invalid. It contains non-alphanumeric characters."
            Write-Host "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Validate the group membership WYSIWYG custom field if provided
    if ($GroupMembershipWYSIWYG) {
        if ([String]::IsNullOrWhiteSpace($GroupMembershipWYSIWYG)) {
            Write-Host -Object "[Error] You must provide a valid WYSIWYG custom field to save the group membership report to."
            exit 1
        }

        $GroupMembershipWYSIWYG = $GroupMembershipWYSIWYG.Trim()

        # Ensure the group membership custom field name contains only alphanumeric characters
        if ($GroupMembershipWYSIWYG -match "[^0-9A-Z]") {
            Write-Host "[Error] The group membership custom field name provided '$GroupMembershipWYSIWYG' is invalid. It contains non-alphanumeric characters."
            Write-Host "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Import the System.Web assembly if required for HTML generation
    if ($SummaryWYSIWYG -or $GroupMembershipWYSIWYG) {
        try {
            Add-Type -AssemblyName System.Web -ErrorAction Stop
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to import the required assembly (System.Web) to properly construct the HTML report for the summary or group membership."
            exit 1
        }
    }

    #region Helper Functions
    function Test-IsDomainController {
        [CmdletBinding()]
        param()

        # Determine the method to retrieve the operating system information based on PowerShell version
        $OS = if ($PSVersionTable.PSVersion.Major -lt 3) {
            Get-WmiObject -Class Win32_OperatingSystem
        } else {
            Get-CimInstance -ClassName Win32_OperatingSystem
        }

        # Check if the ProductType is "2", which indicates that the system is a domain controller
        if ($OS.ProductType -eq "2") {
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

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    #region Environment Validation

    # Attempt to determine if the current session is running with Administrator privileges.
    try {
        $IsElevated = Test-IsElevated -ErrorAction Stop
    } catch {
        # Log an error if unable to determine elevation status
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running this script in an elevated session."
        exit 1
    }

    # Exit if the script is not running in an elevated session
    if (!$IsElevated) {
        Write-Host -Object "[Error] The user '$env:USERNAME' is not running this script in an elevated session. Please run this script as System or in an elevated session."
        exit 1
    }

    # Check if the current device is a domain controller
    try {
        $IsDomainController = Test-IsDomainController -ErrorAction Stop
    } catch {
        # Log an error if unable to determine if the device is a domain controller
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if this device is a domain controller."
        exit 1
    }

    # Exit if the script is not running on a domain controller
    if (!$IsDomainController) {
        Write-Host -Object "[Error] This script must be run on a domain controller. The current device is not a domain controller."
        exit 1
    }

    # Ensure the Active Directory PowerShell module is imported
    try {
        Write-Host -Object "Verifying the Active Directory PowerShell module is imported."

        if (!(Get-Command -Module "ActiveDirectory" -ListImported -ErrorAction Stop)) {
            Write-Host -Object "Importing the Active Directory PowerShell module."
            Import-Module -Name "ActiveDirectory" -ErrorAction Stop
        }
    } catch {
        # Log an error if the Active Directory module cannot be imported
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to ensure the Active Directory module is imported into the current session."
        Write-Host -Object "[Error] Please ensure RSAT is currently installed."
        exit 1
    }

    #region Domain Settings
    $Now = Get-Date

    # Retrieve the Active Directory domain information
    Write-Host -Object "Retrieving the Active Directory domain information and settings."
    try {
        $Domain = Get-ADDomain -ErrorAction "Stop"
    } catch {
        # Log an error if unable to fetch the domain information
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to fetch the current Active Directory domain."
        exit 1
    }

    # Retrieve the distinguished name of the Domain Admin group
    try {
        $DomainAdminGroupDN = (Get-ADGroup -Identity "$($Domain.DomainSID)-512" -ErrorAction Stop).DistinguishedName
    } catch {
        # Log an error if unable to retrieve the Domain Admin group
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve the Domain Admin group."
        exit 1
    }

    # Retrieve the domain's password policy
    try {
        $PasswordPolicy = Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop

        # Extract and format password policy details
        $AccountLockoutThreshold = if ($PasswordPolicy.LockoutThreshold -gt 0) { "$($PasswordPolicy.LockoutThreshold) invalid attempts" } else { "Not Set" }
        $AccountLockoutDuration = if ($PasswordPolicy.LockoutDuration.TotalSeconds -ne 0) { "$($PasswordPolicy.LockoutDuration.TotalMinutes) minutes" } else { "Not Set" }
        $AccountAttemptWindow = if ($PasswordPolicy.LockoutObservationWindow.TotalSeconds -ne 0) { "$($PasswordPolicy.LockoutObservationWindow.TotalMinutes) minutes" } else { "Not Set" }

        $MinPasswordAge = if ($PasswordPolicy.MinPasswordAge.TotalSeconds -gt 0) { "$($PasswordPolicy.MinPasswordAge.Days) day(s)" } else { "0 days (can be changed immediately)" }
        $MaxPasswordAge = if ($PasswordPolicy.MaxPasswordAge.TotalSeconds -gt 0) { "$($PasswordPolicy.MaxPasswordAge.Days) day(s)" } else { "Never Expires" }
        $MinPasswordLength = "$($PasswordPolicy.MinPasswordLength) Character(s)"
        $PasswordComplexity = if ($PasswordPolicy.ComplexityEnabled) { "Enabled" } else { "Disabled" }
        $PasswordHistory = "$($PasswordPolicy.PasswordHistoryCount) passwords remembered"
    } catch {
        # Log an error if unable to retrieve the password policy
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve the domain's password policy."
        exit 1
    }

    #region Domain Groups
    try {
        Write-Host -Object "Retrieving all the current Active Directory groups."

        # Define groups to exclude from processing
        $GroupsToExclude = @(
            "$($Domain.DomainSID)-516" # Domain Controllers group
            "$($Domain.DomainSID)-515" # Domain Computers group
        )

        # Define specific users and groups to include in processing
        $UsersAndGroupsToInclude = @(
            "$($Domain.DomainSID)-513" # Domain Users group
            "S-1-5-4"                 # Interactive group
            "S-1-5-9"                 # Enterprise Domain Controllers group
            "S-1-5-11"                # Authenticated Users group
            "S-1-5-17"                # Anonymous Logon group
        )

        # Define local SID groups for special handling
        $LocalSIDGroups = @(
            "S-1-5-4"  # Interactive group
            "S-1-5-9"  # Enterprise Domain Controllers group
            "S-1-5-11" # Authenticated Users group
        )

        # Retrieve all Active Directory groups excluding the ones in $GroupsToExclude
        $ADGroups = Get-ADGroup -Filter * -Properties "DistinguishedName", "GroupCategory", "DisplayName", "ObjectClass", "SamAccountName", "SID" -ErrorAction Stop | Where-Object { $GroupsToExclude -notcontains $_.SID.Value }

        # Initialize a list to store processed groups
        $ProcessedADGroups = New-Object System.Collections.Generic.List[object]

        # Process each group
        $ADGroups | Sort-Object -Property "SamAccountName" | ForEach-Object {
            $Group = $_
            $Members = New-Object System.Collections.Generic.List[object]

            # Attempt to retrieve group members recursively
            try {
                Get-ADGroupMember -Identity $Group -Recursive -ErrorAction Stop | Get-ADUser -Properties "SamAccountName", "DisplayName", "ObjectClass" -ErrorAction Stop | ForEach-Object {
                    $Members.Add($_)
                }
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Could not retrieve the complete group membership of '$($Group.SamAccountName)'."
                $ExitCode = 1
            }

            # Handle specific users and groups that might be skipped
            try {
                $UsersAndGroupsFound = Get-ADGroupMember -Identity $Group -ErrorAction Stop | Where-Object { $UsersAndGroupsToInclude -contains $_.SID.Value }

                # Add group members
                $UsersAndGroupsFound | Where-Object { $_.objectClass -eq "group" } | Get-ADGroup -Properties "SamAccountName", "DisplayName", "ObjectClass" -ErrorAction Stop | ForEach-Object {
                    $Members.Add($_)
                }

                # Add non-group members
                $UsersAndGroupsFound | Where-Object { $_.objectClass -ne "group" } | ForEach-Object {
                    if ($LocalSIDGroups -contains $_.SID.Value) {
                        $_ | Add-Member -MemberType NoteProperty -Name "LocalObjectClass" -Value "group" -Force -ErrorAction Stop | Out-Null
                    }

                    $Members.Add($_)
                }
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Could not retrieve the complete group membership of '$($Group.SamAccountName)'."
                $ExitCode = 1
            }

            # Handle primary group membership
            try {
                Get-ADUser -Filter "primaryGroupID -eq '$($Group.SID.Value)'" -ErrorAction Stop | Get-ADGroup -Properties "SamAccountName", "DisplayName", "ObjectClass" -ErrorAction Stop | ForEach-Object {
                    $Members.Add($_)
                }
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to retrieve the membership of the primary group ID '$($Group.SID.Value)'."
                $ExitCode = 1
            }

            # Add the processed group and its members to the list
            try {
                $Group | Add-Member -MemberType NoteProperty -Name "Membership" -Value ($Members | Sort-Object -Property { if ([string]::IsNullOrWhiteSpace($_.DisplayName)) { $_.SamAccountName } else { $_.DisplayName } } -Unique) -Force -ErrorAction Stop
                $ProcessedADGroups.Add($Group)
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to process the group '$($Group.SamAccountName)'."
                $ExitCode = 1
            }
        }
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to gather all the current Active Directory groups."
        exit 1
    }

    #region Domain Users
    try {
        # Retrieve all Active Directory users with specified properties
        Write-Host -Object "Retrieving all the current Active Directory users."
        $ADUsers = Get-ADUser -Filter * -Properties SamAccountName, DisplayName, Mail, `
            LastLogonTimestamp, Enabled, PasswordNeverExpires, PasswordNotRequired, `
            SmartcardLogonRequired, MemberOf, PasswordLastSet -ErrorAction Stop
    } catch {
        # Log an error and exit if unable to retrieve users
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve all of the current Active Directory users."
        exit 1
    }

    # Initialize a list to store processed user data
    $ProcessedADUsers = New-Object System.Collections.Generic.List[object]

    # Process each user and calculate additional properties
    $ADUsers | Sort-Object -Property SamAccountName | ForEach-Object {
        try {
            # Calculate the last login date and days since last login
            if ($_.LastLogonTimestamp) {
                $LastLogin = [DateTime]::FromFileTime($_.LastLogonTimestamp)
                $DaysSinceLastLogin = ($Now - $LastLogin).Days
            } else {
                $LastLogin = "Never"
                $DaysSinceLastLogin = "Never"
            }
        } catch {
            # Log an error if unable to calculate login information
            Write-Host -Object "[Error] Failed to calculate the last login information for the user '$($_.SamAccountName)'."
            $ExitCode = 1

            $LastLogin = "Never"
            $DaysSinceLastLogin = "Never"
        }

        # Add the processed user data to the list
        $ProcessedADUsers.Add(
            [PSCustomObject]@{
                Username                   = $_.SamAccountName
                "Display Name"             = if (!$_.DisplayName) { "N/A" } else { $_.DisplayName }
                Enabled                    = $_.Enabled
                Email                      = if (!$_.Mail) { "N/A" } else { $_.Mail }
                "Is Domain Admin"          = $_.MemberOf -contains $DomainAdminGroupDN
                "Last Login"               = $LastLogin
                "Days Since Last Login"    = $DaysSinceLastLogin
                "Password Never Expires"   = $_.PasswordNeverExpires
                "No Password Required"     = $_.PasswordNotRequired
                "Password Last Set"        = if ($_.PasswordLastSet) { $_.PasswordLastSet } else { "Never" }
                "Smartcard Logon Required" = $_.SmartCardLogonRequired
            }
        )
    }

    # Calculate user statistics
    $TotalUsersCount = ($ProcessedADUsers | Measure-Object).Count
    $EnabledUsers = $ProcessedADUsers | Where-Object { $_.Enabled }
    $EnabledUsersCount = ($EnabledUsers | Measure-Object).Count
    $InactiveUsers = $ProcessedADUsers | Where-Object { $_.Enabled -and ($_."Days Since Last Login" -eq "Never" -or $_."Days Since Last Login" -ge $InactivityDaysLimit) }
    $InactiveUsersCount = ($InactiveUsers | Measure-Object).Count
    $DisabledUsers = $ProcessedADUsers | Where-Object { !$_.Enabled }
    $DisabledUsersCount = ($DisabledUsers | Measure-Object).Count

    Write-Host -Object "`n### Active Directory Summary ###"
    ([PSCustomObject]@{
        "Enabled Users"  = $EnabledUsersCount
        "Inactive Users" = $InactiveUsersCount
        "Disabled Users" = $DisabledUsersCount
    } | Format-Table | Out-String).Trim() | Write-Host

    Write-Host -Object "`n## Account Information ##"
    if ($PasswordPolicy.LockoutThreshold -eq 0 -or $PasswordPolicy.LockoutThreshold -gt 5) {
        Write-Host -Object "[Alert] The Center for Internet Security recommends a lockout threshold of 5 or fewer, but not 0."
    }
    if ($PasswordPolicy.LockoutDuration.TotalMinutes -lt 15) {
        Write-Host -Object "[Alert] The Center for Internet Security recommends a lockout duration of 15 minutes or greater."
    }
    if ($PasswordPolicy.LockoutObservationWindow.TotalMinutes -lt 15) {
        Write-Host -Object "[Alert] The Center for Internet Security recommends a lockout observation window of 15 minutes or greater."
    }
    ([PSCustomObject]@{
        "Total Users"                = $TotalUsersCount
        "Lockout Threshold"          = $AccountLockoutThreshold
        "Lockout Duration"           = $AccountLockoutDuration
        "Lockout Observation Window" = $AccountAttemptWindow
    } | Format-List | Out-String).Trim() | Write-Host

    Write-Host -Object "`n## Password Information ##"
    if ($PasswordPolicy.MinPasswordAge.TotalDays -lt 1) {
        Write-Host -Object "[Alert] The Center for Internet Security recommends a minimum password age of 1 or more day(s)."
    }
    if ($PasswordPolicy.MaxPasswordAge.TotalSeconds -eq 0 -or $PasswordPolicy.MaxPasswordAge.TotalDays -gt 365) {
        Write-Host -Object "[Alert] The Center for Internet Security recommends a maximum password age of 365 or fewer days, but not 0."
    }
    if ($PasswordPolicy.MinPasswordLength -lt 14) {
        Write-Host -Object "[Alert] The Center for Internet Security recommends a minimum password length of 14 or more characters."
    }
    if (!$PasswordPolicy.ComplexityEnabled) {
        Write-Host -Object "[Alert] The Center for Internet Security recommends enabling password complexity."
    }
    if ($PasswordPolicy.PasswordHistoryCount -lt 24) {
        Write-Host -Object "[Alert] The Center for Internet Security recommends a password history of 24 or more passwords remembered."
    }
    ([PSCustomObject]@{
        "Minimum Password Age"    = $MinPasswordAge
        "Maximum Password Age"    = $MaxPasswordAge
        "Minimum Password Length" = $MinPasswordLength
        "Password Complexity"     = $PasswordComplexity
        "Password History Count"  = $PasswordHistory
    } | Format-List | Out-String).Trim() | Write-Host

    Write-Host -Object "`n## Active Directory Groups Detected ##"
    $SecurityGroups = $ProcessedADGroups | Where-Object { $_.GroupCategory -eq "Security" -and $_.Membership -and $_.DistinguishedName -notmatch "$([Regex]::Escape("CN=Builtin,$($Domain.DistinguishedName)"))$" }
    $DistributionList = $ProcessedADGroups | Where-Object { $_.GroupCategory -eq "Distribution" -and $_.Membership -and $_.DistinguishedName -notmatch "$([Regex]::Escape("CN=Builtin,$($Domain.DistinguishedName)"))$" }
    $BuiltIn = $ProcessedADGroups | Where-Object { $_.Membership -and $_.DistinguishedName -match "$([Regex]::Escape("CN=Builtin,$($Domain.DistinguishedName)"))$" }
    $EmptyGroups = $ProcessedADGroups | Where-Object { !$_.Membership }

    $SecurityGroupsCount = $SecurityGroups | Measure-Object | Select-Object -ExpandProperty Count
    $DistributionListCount = $DistributionList | Measure-Object | Select-Object -ExpandProperty Count
    $BuiltInCount = $BuiltIn | Measure-Object | Select-Object -ExpandProperty Count
    $EmptyGroupsCount = $EmptyGroups | Measure-Object | Select-Object -ExpandProperty Count

    ([PSCustomObject]@{
        "Security Groups"    = $SecurityGroupsCount
        "Distribution Lists"    = $DistributionListCount
        "Builtin Groups" = $BuiltInCount
        "Empty Groups"     = $EmptyGroupsCount
    } | Format-Table | Out-String).Trim() | Write-Host
    Write-Host -Object ""

    #Region Summary HTML
    if ($SummaryWYSIWYG) {
        Write-Host -Object "Generating summary report HTML."

        # Calculate percentages for enabled, inactive, and disabled users
        if ($EnabledUsersCount -eq 0) { $EnabledPercentage = 0 }
        if ($EnabledUsersCount -gt 0) {
            $EnabledPercentage = [math]::Round((($EnabledUsersCount - $InactiveUsersCount) / $TotalUsersCount * 100), 2)
        }

        if ($InactiveUsersCount -eq 0) { $InactivePercentage = 0 }
        if ($InactiveUsersCount -gt 0) {
            $InactivePercentage = [math]::Round(($InactiveUsersCount / $TotalUsersCount * 100), 2)
        }

        if ($DisabledUsersCount -eq 0) { $DisabledPercentage = 0 }
        if ($DisabledUsersCount -gt 0) {
            $DisabledPercentage = [math]::Round(($DisabledUsersCount / $TotalUsersCount * 100), 2)
        }

        # Generate the HTML content for the summary report
        $SummaryWYSIWYGCustomFieldValue = "<div>
    <div class='card flex-grow-1'>
        <div class='card-title-box'>
            <div class='card-title'><i class='fa-solid fa-globe'></i>&nbsp;&nbsp;$([System.Web.HttpUtility]::HtmlEncode($Domain.Forest))</div>
        </div>
        <div class='card-body container-fluid' style='white-space: nowrap'>
            <div class='row'>
                <div class='p-3 linechart'>
                    <div style='width: $EnabledPercentage%; background-color: #198754;'></div>
                    <div style='width: $InactivePercentage%; background-color: #ffc107;'></div>
                    <div style='width: $DisabledPercentage%; background-color: #dc3545;'></div>
                </div>
            </div>
            <div class='row'>
                <div class='col'>
                    <div class='stat-card' style='border-color: #198754;'>
                        <div class='stat-value'
                            style='color: #198754; margin-bottom: 0px; font-size: 4.5rem; height: 30%;'>$EnabledUsersCount
                        </div>
                    </div>
                    <div class='stat-desc' style='text-align: center;'>Enabled Users</div>
                </div>
                <div class='col'>
                    <div class='stat-card' style='border-color: #ffc107;'>
                        <div class='stat-value'
                            style='color: #ffc107; margin-bottom: 0px; font-size: 4.5rem; height: 30%;'>$InactiveUsersCount
                        </div>
                    </div>
                    <div class='stat-desc' style='text-align: center;'>Inactive Users</div>
                </div>
                <div class='col'>
                    <div class='stat-card' style='border-color: #dc3545;'>
                        <div class='stat-value'
                            style='color: #dc3545; margin-bottom: 0px; font-size: 4.5rem; height: 30%;'>$DisabledUsersCount
                        </div>
                    </div>
                    <div class='stat-desc' style='text-align: center;'>Disabled Users</div>
                </div>
            </div>
            <div class='row'>
                <div class='col d-flex align-items-center justify-content-center'>
                    <i class='fa-regular fa-circle-user' style='font-size: 8rem;'></i>
                </div>
                <div class='col'>
                    <p>Total Users: $TotalUsersCount</p>
                    <p>Lockout Threshold: $AccountLockoutThreshold</p>
                    <p>Lockout Duration: $AccountLockoutDuration</p>
                    <p>Lockout Observation Window: $AccountAttemptWindow</p>
                </div>
                <div class='col d-flex align-items-center justify-content-center'>
                    <i class='fa-solid fa-key' style='font-size: 8rem;'></i>
                </div>
                <div class='col'>
                    <p>Minimum Password Age: $MinPasswordAge</p>
                    <p>Maximum Password Age: $MaxPasswordAge</p>
                    <p>Minimum Password Length: $MinPasswordLength</p>
                    <p>Password Complexity: $PasswordComplexity</p>
                    <p>Password History Count: $PasswordHistory</p>
                </div>
            </div>
        </div>
    </div>
</div>"

        # Add warnings for non-compliance with CIS benchmarks
        $WarningIcon = "<i class='fa-solid fa-triangle-exclamation' style='color: #FAC905'></i>"
        $CISBenchmarkLink = "https://www.cisecurity.org/cis-benchmarks"

        if ($PasswordPolicy.LockoutThreshold -eq 0 -or $PasswordPolicy.LockoutThreshold -gt 5) {
            $TooltipMessage = "The Center for Internet Security recommends a threshold of 5 or fewer, but not 0."

            $SummaryWYSIWYGCustomFieldValue = $SummaryWYSIWYGCustomFieldValue -replace "Lockout Threshold:", `
                "<a href='$CISBenchmarkLink' target='_blank' title='$TooltipMessage'>$WarningIcon</a>&nbsp;&nbsp;Lockout Threshold:"
        }

        if ($PasswordPolicy.LockoutDuration.TotalMinutes -lt 15) {
            $TooltipMessage = "The Center for Internet Security recommends a duration of 15 minutes or greater."

            $SummaryWYSIWYGCustomFieldValue = $SummaryWYSIWYGCustomFieldValue -replace "Lockout Duration:", `
                "<a href='$CISBenchmarkLink' target='_blank' title='$TooltipMessage'>$WarningIcon</a>&nbsp;&nbsp;Lockout Duration:"
        }

        if ($PasswordPolicy.LockoutObservationWindow.TotalMinutes -lt 15) {
            $TooltipMessage = "The Center for Internet Security recommends an observation window of 15 minutes or greater."

            $SummaryWYSIWYGCustomFieldValue = $SummaryWYSIWYGCustomFieldValue -replace "Lockout Observation Window:", `
                "<a href='$CISBenchmarkLink' target='_blank' title='$TooltipMessage'>$WarningIcon</a>&nbsp;&nbsp;Lockout Observation Window:"
        }

        if ($PasswordPolicy.MinPasswordAge.TotalDays -lt 1) {
            $TooltipMessage = "The Center for Internet Security recommends a minimum password age of 1 or more day(s)."

            $SummaryWYSIWYGCustomFieldValue = $SummaryWYSIWYGCustomFieldValue -replace "Minimum Password Age:", `
                "<a href='$CISBenchmarkLink' target='_blank' title='$TooltipMessage'>$WarningIcon</a>&nbsp;&nbsp;Minimum Password Age:"
        }

        if ($PasswordPolicy.MaxPasswordAge.TotalSeconds -eq 0 -or $PasswordPolicy.MaxPasswordAge.TotalDays -gt 365) {
            $TooltipMessage = "The Center for Internet Security recommends a maximum password age of 365 or fewer days, but not 0."

            $SummaryWYSIWYGCustomFieldValue = $SummaryWYSIWYGCustomFieldValue -replace "Maximum Password Age:", `
                "<a href='$CISBenchmarkLink' target='_blank' title='$TooltipMessage'>$WarningIcon</a>&nbsp;&nbsp;Maximum Password Age:"
        }

        if ($PasswordPolicy.MinPasswordLength -lt 14) {
            $TooltipMessage = "The Center for Internet Security recommends a minimum password length of 14 or more characters."

            $SummaryWYSIWYGCustomFieldValue = $SummaryWYSIWYGCustomFieldValue -replace "Minimum Password Length:", `
                "<a href='$CISBenchmarkLink' target='_blank' title='$TooltipMessage'>$WarningIcon</a>&nbsp;&nbsp;Minimum Password Length:"
        }

        if (!$PasswordPolicy.ComplexityEnabled) {
            $TooltipMessage = "The Center for Internet Security recommends enabling password complexity."

            $SummaryWYSIWYGCustomFieldValue = $SummaryWYSIWYGCustomFieldValue -replace "Password Complexity:", `
                "<a href='$CISBenchmarkLink' target='_blank' title='$TooltipMessage'>$WarningIcon</a>&nbsp;&nbsp;Password Complexity:"
        }

        if ($PasswordPolicy.PasswordHistoryCount -lt 24) {
            $TooltipMessage = "The Center for Internet Security recommends a password history of 24 or more passwords remembered."

            $SummaryWYSIWYGCustomFieldValue = $SummaryWYSIWYGCustomFieldValue -replace "Password History Count:", `
                "<a href='$CISBenchmarkLink' target='_blank' title='$TooltipMessage'>$WarningIcon</a>&nbsp;&nbsp;Password History Count:"
        }

        # Attempt to set the custom field with the generated HTML content
        try {
            Write-Host -Object "Attempting to set the custom field '$SummaryWYSIWYG'."
            $SummaryWYSIWYGCustomFieldValue | Set-NinjaProperty -Name $SummaryWYSIWYG -ErrorAction Stop
            Write-Host -Object "Success!"
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to set the custom field '$SummaryWYSIWYG'."
            $ExitCode = 1
        }
    }

    #region Enabled Users HTML
    if ($EnabledUsersWYSIWYG) {
        Write-Host -Object "Generating enabled users report HTML."

        try {
            # Create an HTML table for enabled users with specific properties and formatting
            $EnabledUsersHTMLTable = $EnabledUsers | Select-Object -Property Username, "Display Name", "Email", `
            @{ Name = "Is Domain Admin"; Expression = { ";|DomainAdmin|;$($_."Is Domain Admin")" } }, `
            @{ Name = "Last Login"; Expression = {
                    if ($_."Last Login" -eq "Never") {
                        ";|LastLogin|;$($_."Last Login")"
                    } else {
                        ";|LastLogin|;$($_."Last Login".ToShortDateString()) $($_."Last Login".ToShortTimeString())"
                    }
                }
            }, @{ Name = "Days Since Last Login"; Expression = { ";|DaysSinceLastLogin|;$($_."Days Since Last Login")" } }, `
            @{ Name = "Password Never Expires"; Expression = { ";|PasswordNeverExpires|;$($_."Password Never Expires")" } }, `
            @{ Name = "No Password Required"; Expression = { ";|NoPasswordRequired|;$($_."No Password Required")" } }, `
            @{ Name = "Password Last Set"; Expression = {
                    ";|PasswordLastSet|;$($_."Password Last Set".ToShortDateString()) $($_."Password Last Set".ToShortTimeString())" }
            }, @{ Name = "Smartcard Logon Required"; Expression = { ";|SmartCardLogonRequired|;$($_."Smartcard Logon Required")" } } |
                ConvertTo-Html -Fragment -ErrorAction Stop
        } catch {
            # Log an error if the HTML table creation fails
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to create the required HTML table."
            $ExitCode = 1
            $DoNotAttemptToSetEnabledUsersField = $True
        }

        # Replace placeholders in the HTML table with appropriate icons or text
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace ";\|DomainAdmin\|;False", "<i class='fa-solid fa-xmark'></i>"
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace ";\|DomainAdmin\|;True", "<i class='fa-solid fa-check' style='color: #D53948;'></i>"

        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace ";\|LastLogin\|;Never", "<i class='fa-solid fa-triangle-exclamation' style='color: #FAC905'></i>&nbsp;&nbsp;Never"
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace ";\|DaysSinceLastLogin\|;Never", "<i class='fa-solid fa-triangle-exclamation' style='color: #FAC905'></i>&nbsp;&nbsp;Never"

        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace ";\|PasswordNeverExpires\|;False", "<i class='fa-solid fa-xmark'></i>"
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace ";\|PasswordNeverExpires\|;True", "<i class='fa-solid fa-check' style='color: #D53948;'></i>"

        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace ";\|NoPasswordRequired\|;False", "<i class='fa-solid fa-xmark'></i>"
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace ";\|NoPasswordRequired\|;True", "<i class='fa-solid fa-check' style='color: #D53948;'></i>"

        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace ";\|SmartCardLogonRequired\|;False", "<i class='fa-solid fa-xmark'></i>"
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace ";\|SmartCardLogonRequired\|;True", "<i class='fa-solid fa-check'></i>"

        # Identify stale users and users who need to update their passwords
        $StaleUsers = $InactiveUsers | Where-Object { $_."Days Since Last Login" -ge $InactivityDaysLimit }
        $PasswordCutoff = $Now.AddDays(-365)
        $UsersThatNeedToUpdatePassword = $EnabledUsers | Where-Object { $_."Password Last Set" -lt $PasswordCutoff }

        # Process each line in the HTML table to add warnings or highlights
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable | ForEach-Object {
            if ($_ -notmatch '<td>|<tr>') { return $_ }

            $NewLine = $_

            # Highlight stale users
            foreach ($StaleUser in $StaleUsers) {
                if ($NewLine -match "<td>$([Regex]::Escape($StaleUser.Username))</td>") {
                    $NewLine = $NewLine -replace ";\|LastLogin\|;", "<i class='fa-solid fa-triangle-exclamation' style='color: #FAC905'></i>&nbsp;&nbsp;"
                    $NewLine = $NewLine -replace ";\|DaysSinceLastLogin\|;", "<i class='fa-solid fa-triangle-exclamation' style='color: #FAC905'></i>&nbsp;&nbsp;"
                }
            }

            # Highlight users who need to update their passwords
            foreach ($User in $UsersThatNeedToUpdatePassword) {
                if ($NewLine -match "<td>$([Regex]::Escape($User.Username))</td>") {
                    $TooltipMessage = "The Center for Internet Security recommends a maximum password age of 365 or fewer days, but not 0."
                    $WarningIcon = "<i class='fa-solid fa-triangle-exclamation' style='color: #FAC905'></i>"
                    $CISBenchmarkLink = "https://www.cisecurity.org/cis-benchmarks"

                    $NewLine = $NewLine -replace ";\|PasswordLastSet\|;", "<a href='$CISBenchmarkLink' target='_blank' title='$TooltipMessage'>$WarningIcon</a>&nbsp;&nbsp;"
                }
            }

            # Add warning or danger classes based on the content
            if ($NewLine -match "color: #FAC905" -and $NewLine -notmatch "color: #D53948") {
                $NewLine = $NewLine -replace "<tr>", "<tr class='warning'>"
            }

            if ($NewLine -match "color: #D53948") {
                $NewLine = $NewLine -replace "<tr>", "<tr class='danger'>"
            }

            return $NewLine
        }

        # Remove unused placeholders from the HTML table
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace ";\|PasswordLastSet\|;"
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace ";\|LastLogin\|;"
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace ";\|DaysSinceLastLogin\|;"

        # Add formatting to table headers
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace "<th>", "<th><b>"
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace "</th>", "</b></th>"

        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace "<th><b>Is Domain Admin", "<th style='width: 6rem'><b>Is Domain Admin"
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace "<th><b>Last Login", "<th style='width: 12rem'><b>Last Login"
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace "<th><b>Password Never Expires", "<th style='width: 6rem'><b>Password Never Expires"
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace "<th><b>No Password Required", "<th style='width: 6rem'><b>No Password Required"
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace "<th><b>Password Last Set", "<th style='width: 12rem'><b>Password Last Set"
        $EnabledUsersHTMLTable = $EnabledUsersHTMLTable -replace "<th><b>Smartcard Logon Required", "<th style='width: 6rem'><b>Smartcard Logon Required"

        # Wrap the HTML table in a container for display
        $EnabledUsersWYSIWYGCustomFieldValue = "<div>
    <div class='card flex-grow-1'>
        <div class='card-title-box'>
            <div class='card-title'><i class='fa-solid fa-user-check'></i>&nbsp;&nbsp;Enabled Users</div>
        </div>
        <div class='card-body container-fluid' style='white-space: nowrap'>
            $EnabledUsersHTMLTable
        </div>
    </div>
</div>"

        #region HTML Character Limit
        # Calculate the total number of characters in the HTML content
        $HTMLCharacters = $EnabledUsersWYSIWYGCustomFieldValue.Length
        if ($HTMLCharacters -ge 190000) {
            # Log a warning if the character limit is exceeded
            Write-Host -Object "The current character count is '$HTMLCharacters'."
            Write-Host -Object "[Warning] The character limit of 190,000 has been reached! Trimming the output until the character limit is satisfied."

            $i = 0
            [array]$EnabledUsersHTMLTable = $EnabledUsersHTMLTable
            $TrimStart = Get-Date
            do {
                # Calculate the number of rows to remove in each batch
                $ExceededAmount = $HTMLCharacters - 190000
                if ($ExceededAmount -le 0) {
                    $BatchSize = 1
                } else {
                    $BatchSize = [math]::Ceiling($ExceededAmount / 500)
                }

                # Reverse the HTML table array to start removing rows from the end
                [array]::Reverse($EnabledUsersHTMLTable)

                # Remove rows from the HTML table until the character count is reduced
                for ($BatchNumber = 0; $BatchNumber -lt $BatchSize; $BatchNumber++) {
                    if ($EnabledUsersHTMLTable[$i] -match '<tr><td>' -or $EnabledUsersHTMLTable[$i] -match '<tr class=') {
                        $EnabledUsersHTMLTable[$i] = $null
                    }
                    $i++
                }

                # Reverse the array back to its original order
                [array]::Reverse($EnabledUsersHTMLTable)

                # Reconstruct the HTML content with a truncation warning
                $EnabledUsersWYSIWYGCustomFieldValue = "<div>
        <div class='card flex-grow-1'>
        <div class='card-title-box'>
            <div class='card-title'><i class='fa-solid fa-user-check'></i>&nbsp;&nbsp;Enabled Users</div>
        </div>
        <div class='card-body container-fluid' style='white-space: nowrap'>
            <div class='info-card error'>
            <i class='info-icon fa-solid fa-circle-exclamation'></i>
            <div class='info-text'>
            <div class='info-title'>This table has been truncated.</div>
            <div class='info-description' style='white-space: normal;'>Users have been removed from this table to comply with the 190,000-character limit.</div>
            </div>
            </div>
            $EnabledUsersHTMLTable
        </div>
        </div>
        </div>"

                # Recalculate the character count after trimming
                $HTMLCharacters = $EnabledUsersWYSIWYGCustomFieldValue.Length
                $ElapsedTime = (Get-Date) - $TrimStart
            } while ($HTMLCharacters -ge 190000 -and $ElapsedTime.TotalMinutes -le 5)

            # Log an error if the trimming process exceeds the timeout limit
            if ($ElapsedTime.TotalMinutes -gt 5) {
                Write-Host -Object "The current character count is '$HTMLCharacters'."
                Write-Host -Object "[Error] The 5-minute timeout has been reached. Unable to trim the output to comply with the 190,000-character limit."
                $ExitCode = 1
                $DoNotAttemptToSetEnabledUsersField = $True
            }
        }

        try {
            # Attempt to set the custom field if trimming was successful
            if (!$DoNotAttemptToSetEnabledUsersField) {
                Write-Host -Object "Attempting to set the custom field '$EnabledUsersWYSIWYG'."
                $EnabledUsersWYSIWYGCustomFieldValue | Set-NinjaProperty -Name $EnabledUsersWYSIWYG -ErrorAction Stop
                Write-Host -Object "Success!"
            }
        } catch {
            # Log an error if setting the custom field fails
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to set the custom field '$EnabledUsersWYSIWYG'."
            $ExitCode = 1
        }
    }

    #region Disabled Users HTML
    if ($DisabledUsersWYSIWYG) {
        # Check if the custom field for disabled users is provided
        Write-Host -Object "Generating disabled users report HTML."

        try {
            # Create an HTML table for disabled users with specific properties and formatting
            $DisabledUsersHTMLTable = $DisabledUsers | Select-Object -Property Username, "Display Name", "Email", `
            @{ Name = "Is Domain Admin"; Expression = { ";|DomainAdmin|;$($_."Is Domain Admin")" } }, `
            @{ Name = "Last Login"; Expression = { if ($_."Last Login" -ne "Never") { "$($_."Last Login".ToShortDateString()) $($_."Last Login".ToShortTimeString())" } else { "Never" } } }, `
            @{ Name = "Days Since Last Login"; Expression = { "$($_."Days Since Last Login")" } }, `
            @{ Name = "Password Never Expires"; Expression = { ";|PasswordNeverExpires|;$($_."Password Never Expires")" } }, `
            @{ Name = "No Password Required"; Expression = { ";|NoPasswordRequired|;$($_."No Password Required")" } }, `
            @{ Name = "Password Last Set"; Expression = { if ($_."Password Last Set" -ne "Never") { "$($_."Password Last Set".ToShortDateString()) $($_."Password Last Set".ToShortTimeString())" } else { "Never" } } }, `
            @{ Name = "Smartcard Logon Required"; Expression = { ";|SmartCardLogonRequired|;$($_."Smartcard Logon Required")" } } |
                ConvertTo-Html -Fragment -ErrorAction Stop
        } catch {
            # Log an error if the HTML table creation fails
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to create the required HTML table."
            $ExitCode = 1
            $DoNotAttemptToSetDisabledUsersField = $True
        }

        # Replace placeholders in the HTML table with appropriate icons or text
        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace ";\|DomainAdmin\|;False", "<i class='fa-solid fa-xmark'></i>"
        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace ";\|DomainAdmin\|;True", "<i class='fa-solid fa-check' style='color: #D53948;'></i>"

        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace ";\|PasswordNeverExpires\|;False", "<i class='fa-solid fa-xmark'></i>"
        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace ";\|PasswordNeverExpires\|;True", "<i class='fa-solid fa-check' style='color: #D53948;'></i>"

        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace ";\|NoPasswordRequired\|;False", "<i class='fa-solid fa-xmark'></i>"
        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace ";\|NoPasswordRequired\|;True", "<i class='fa-solid fa-check' style='color: #D53948;'></i>"

        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace ";\|SmartCardLogonRequired\|;False", "<i class='fa-solid fa-xmark'></i>"
        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace ";\|SmartCardLogonRequired\|;True", "<i class='fa-solid fa-check'></i>"

        # Add warning or danger classes based on the content
        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable | ForEach-Object {
            if ($_ -notmatch '<td>|<tr>') { return $_ }

            $NewLine = $_

            if ($NewLine -match "color: #FAC905" -and $NewLine -notmatch "color: #D53948") {
                $NewLine = $NewLine -replace "<tr>", "<tr class='warning'>"
            }

            if ($NewLine -match "color: #D53948") {
                $NewLine = $NewLine -replace "<tr>", "<tr class='danger'>"
            }

            return $NewLine
        }

        # Add formatting to table headers
        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace "<th>", "<th><b>"
        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace "</th>", "</b></th>"

        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace "<th><b>Is Domain Admin", "<th style='width: 6rem'><b>Is Domain Admin"
        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace "<th><b>Last Login", "<th style='width: 12rem'><b>Last Login"
        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace "<th><b>Password Never Expires", "<th style='width: 6rem'><b>Password Never Expires"
        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace "<th><b>No Password Required", "<th style='width: 6rem'><b>No Password Required"
        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace "<th><b>Password Last Set", "<th style='width: 12rem'><b>Password Last Set"
        $DisabledUsersHTMLTable = $DisabledUsersHTMLTable -replace "<th><b>Smartcard Logon Required", "<th style='width: 6rem'><b>Smartcard Logon Required"

        # Wrap the HTML table in a container for display
        $DisabledUsersWYSIWYGCustomFieldValue = "<div>
    <div class='card flex-grow-1'>
        <div class='card-title-box'>
            <div class='card-title'><i class='fa-solid fa-user-slash'></i>&nbsp;&nbsp;Disabled Users</div>
        </div>
        <div class='card-body container-fluid' style='white-space: nowrap'>
            $DisabledUsersHTMLTable
        </div>
    </div>
</div>"

        # Check if the HTML content exceeds the character limit
        $HTMLCharacters = $DisabledUsersWYSIWYGCustomFieldValue.Length
        if ($HTMLCharacters -ge 190000) {
            Write-Host -Object "The current character count is '$HTMLCharacters'."
            Write-Host -Object "[Warning] The character limit of 190,000 has been reached! Trimming the output until the character limit is satisfied."

            $i = 0
            [array]$DisabledUsersHTMLTable = $DisabledUsersHTMLTable
            $TrimStart = Get-Date
            do {
                # Calculate the batch size for trimming
                $ExceededAmount = $HTMLCharacters - 190000
                if ($ExceededAmount -le 0) {
                    $BatchSize = 1
                } else {
                    $BatchSize = [math]::Ceiling($ExceededAmount / 500)
                }

                # Reverse the HTML table array to start removing rows from the end
                [array]::Reverse($DisabledUsersHTMLTable)

                # Remove rows from the HTML table until the character count is reduced
                for ($BatchNumber = 0 ; $BatchNumber -lt $BatchSize ; $BatchNumber++) {
                    if ($DisabledUsersHTMLTable[$i] -match '<tr><td>' -or $DisabledUsersHTMLTable[$i] -match '<tr class=') {
                        $DisabledUsersHTMLTable[$i] = $null
                    }
                    $i++
                }

                # Reverse the array back to its original order
                [array]::Reverse($DisabledUsersHTMLTable)

                # Reconstruct the HTML content with a truncation warning
                $DisabledUsersWYSIWYGCustomFieldValue = "<div>
    <div class='card flex-grow-1'>
        <div class='card-title-box'>
            <div class='card-title'><i class='fa-solid fa-user-slash'></i>&nbsp;&nbsp;Disabled Users</div>
        </div>
        <div class='card-body container-fluid' style='white-space: nowrap'>
            <div class='info-card error'>
                <i class='info-icon fa-solid fa-circle-exclamation'></i>
                <div class='info-text'>
                    <div class='info-title'>This table has been truncated.</div>
                    <div class='info-description' style='white-space: normal;'>Users have been removed from this table to comply with the 190,000-character limit.</div>
                </div>
            </div>
            $DisabledUsersHTMLTable
        </div>
    </div>
</div>"

                # Recalculate the character count after trimming
                $HTMLCharacters = $DisabledUsersWYSIWYGCustomFieldValue.Length
                $ElapsedTime = (Get-Date) - $TrimStart
            } while ($HTMLCharacters -ge 190000 -and $ElapsedTime.TotalMinutes -le 5)

            # Log an error if the trimming process exceeds the timeout limit
            if ($ElapsedTime.TotalMinutes -gt 5) {
                Write-Host -Object "The current character count is '$HTMLCharacters'."
                Write-Host -Object "[Error] The 5-minute timeout has been reached. Unable to trim the output to comply with the 190,000-character limit."
                $ExitCode = 1
                $DoNotAttemptToSetDisabledUsersField = $True
            }
        }

        try {
            # Attempt to set the custom field if trimming was successful
            if (!$DoNotAttemptToSetDisabledUsersField) {
                Write-Host -Object "Attempting to set the custom field '$DisabledUsersWYSIWYG'."
                $DisabledUsersWYSIWYGCustomFieldValue | Set-NinjaProperty -Name $DisabledUsersWYSIWYG -ErrorAction Stop
                Write-Host -Object "Success!"
            }
        } catch {
            # Log an error if setting the custom field fails
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to set the custom field '$DisabledUsersWYSIWYG'."
            $ExitCode = 1
        }
    }

    #region Group Member HTML
    if ($GroupMembershipWYSIWYG) {
        Write-Host -Object "Generating group membership report HTML."

        # Process the AD groups and encode HTML entities for specific properties
        $ProcessedADGroups = $ProcessedADGroups | Select-Object @{ Name = "SamAccountName"; Expression = { [System.Web.HttpUtility]::HtmlEncode($_.SamAccountName) } }, `
        @{ Name = "Name"; Expression = { [System.Web.HttpUtility]::HtmlEncode($_.Name) } }, @{ Name = "DisplayName"; Expression = { [System.Web.HttpUtility]::HtmlEncode($_.DisplayName) } }, `
            DistinguishedName, GroupCategory, GroupScope, ObjectClass, ObjectGUID, SID, @{ Name = "Membership"; Expression = {
                $_.Membership | Select-Object -Property @{ Name = "SamAccountName"; Expression = { [System.Web.HttpUtility]::HtmlEncode($_.SamAccountName) } },
                @{ Name = "DisplayName"; Expression = { [System.Web.HttpUtility]::HtmlEncode($_.DisplayName) } }, SID, ObjectClass, Enabled
            }
        }

        # Separate groups into categories: Security, Distribution, Built-in, and Empty groups
        $SecurityGroups = [System.Collections.Generic.List[object]]::new()
        $ProcessedADGroups | Where-Object { $_.GroupCategory -eq "Security" -and $_.Membership -and $_.DistinguishedName -notmatch "$([Regex]::Escape("CN=Builtin,$($Domain.DistinguishedName)"))$" } | ForEach-Object {
            $SecurityGroups.Add($_)
        }

        $DistributionList = [System.Collections.Generic.List[object]]::new()
        $ProcessedADGroups | Where-Object { $_.GroupCategory -eq "Distribution" -and $_.Membership -and $_.DistinguishedName -notmatch "$([Regex]::Escape("CN=Builtin,$($Domain.DistinguishedName)"))$" } | ForEach-Object {
            $DistributionList.Add($_)
        }

        $BuiltIn = [System.Collections.Generic.List[object]]::new()
        $ProcessedADGroups | Where-Object { $_.Membership -and $_.DistinguishedName -match "$([Regex]::Escape("CN=Builtin,$($Domain.DistinguishedName)"))$" } | ForEach-Object {
            $BuiltIn.Add($_)
        }

        $EmptyGroups = [System.Collections.Generic.List[object]]::new()
        $ProcessedADGroups | Where-Object { !$_.Membership } | ForEach-Object {
            $EmptyGroups.Add($_)
        }

        # Generate HTML for Security Groups
        $SecurityGroupsHTML = New-Object System.Collections.Generic.List[String]
        foreach ($Group in $SecurityGroups) {
            $GroupMembershipCount = $Group.Membership | Measure-Object | Select-Object -ExpandProperty Count

            $SecurityGroupsHTML.Add("<div class='container-fluid mb-2'>")
            $SecurityGroupsHTML.Add("<h3 style='margin-bottom: 0px;'>$($Group.SamAccountName) - $GroupMembershipCount</h3>")

            $SecurityGroupsHTML.Add("<div class='d-flex flex-wrap gap-2'>")
            $Group.Membership | ForEach-Object {
                $SecurityGroupsHTML.Add("<span class='badge p-2'>")
                if ($_.ObjectClass -eq "group" -or $_.LocalObjectClass -eq "group") {
                    $icon = "<i class='fa-solid fa-user-group me-2'></i>"
                } elseif (!$_.Enabled -and $UsersAndGroupsToInclude -notcontains $_.Sid) {
                    $icon = "<a title='This account is currently disabled.'><i class='fa-solid fa-triangle-exclamation me-2' style='color: #ffc107;'></i></a>"
                } else {
                    $icon = "<i class='fas fa-user me-2'></i>"
                }

                if ($_.DisplayName) {
                    $SecurityGroupsHTML.Add("$icon$($_.DisplayName)</span>")
                } else {
                    $SecurityGroupsHTML.Add("$icon$($_.SamAccountName)</span>")
                }
            }
            $SecurityGroupsHTML.Add("</div>")
            $SecurityGroupsHTML.Add("</div>")
        }

        # Generate HTML for Distribution Lists
        $DistributionListHTML = New-Object System.Collections.Generic.List[String]
        foreach ($Group in $DistributionList) {
            $GroupMembershipCount = $Group.Membership | Measure-Object | Select-Object -ExpandProperty Count

            $DistributionListHTML.Add("<div class='container-fluid mb-2'>")
            $DistributionListHTML.Add("<h3 style='margin-bottom: 0px;'>$($Group.SamAccountName) - $GroupMembershipCount</h3>")

            $DistributionListHTML.Add("<div class='d-flex flex-wrap gap-2'>")
            $Group.Membership | ForEach-Object {
                $DistributionListHTML.Add("<span class='badge p-2'>")
                if ($_.ObjectClass -eq "group" -or $_.LocalObjectClass -eq "group") {
                    $icon = "<i class='fa-solid fa-user-group me-2'></i>"
                } elseif (!$_.Enabled -and $UsersAndGroupsToInclude -notcontains $_.Sid) {
                    $icon = "<a title='This account is currently disabled.'><i class='fa-solid fa-triangle-exclamation me-2' style='color: #ffc107;'></i></a>"
                } else {
                    $icon = "<i class='fas fa-user me-2'></i>"
                }

                if ($_.DisplayName) {
                    $DistributionListHTML.Add("$icon$($_.DisplayName)</span>")
                } else {
                    $DistributionListHTML.Add("$icon$($_.SamAccountName)</span>")
                }
            }
            $DistributionListHTML.Add("</div>")
            $DistributionListHTML.Add("</div>")
        }

        # Generate HTML for Built-in Groups
        $BuiltInHTML = New-Object System.Collections.Generic.List[String]
        foreach ($Group in $BuiltIn) {
            $GroupMembershipCount = $Group.Membership | Measure-Object | Select-Object -ExpandProperty Count

            $BuiltInHTML.Add("<div class='container-fluid mb-2'>")
            $BuiltInHTML.Add("<h3 style='margin-bottom: 0px;'>$($Group.SamAccountName) - $GroupMembershipCount</h3>")

            $BuiltInHTML.Add("<div class='d-flex flex-wrap gap-2'>")
            $Group.Membership | ForEach-Object {
                $BuiltInHTML.Add("<span class='badge p-2'>")
                if ($_.ObjectClass -eq "group" -or $_.LocalObjectClass -eq "group") {
                    $icon = "<i class='fa-solid fa-user-group me-2'></i>"
                } elseif (!$_.Enabled -and $UsersAndGroupsToInclude -notcontains $_.Sid) {
                    $icon = "<a title='This account is currently disabled.'><i class='fa-solid fa-triangle-exclamation me-2' style='color: #ffc107;'></i></a>"
                } else {
                    $icon = "<i class='fas fa-user me-2'></i>"
                }

                if ($_.DisplayName) {
                    $BuiltInHTML.Add("$icon$($_.DisplayName)</span>")
                } else {
                    $BuiltInHTML.Add("$icon$($_.SamAccountName)</span>")
                }
            }
            $BuiltInHTML.Add("</div>")
            $BuiltInHTML.Add("</div>")
        }

        # Generate HTML for Empty Groups
        $EmptyGroupHTML = New-Object System.Collections.Generic.List[String]
        foreach ($Group in $EmptyGroups) {
            $EmptyGroupHTML.Add("<span class='badge p-2'>")
            $EmptyGroupHTML.Add("<i class='fa-solid fa-user-group me-2'></i>$($Group.SamAccountName)</span>")
        }

        # Handle cases where no groups are found for each category
        if ($SecurityGroupsHTML.Count -lt 1) {
            $SecurityGroupsHTML = "<div class='info-card warning'>
                <i class='info-icon fa-solid fa-triangle-exclamation'></i>
                <div class='info-text'>
                    <div class='info-title'>No Security Groups with Members Found.</div>
                    <div class='info-description' style='white-space: normal;'>You may want to verify this information.</div>
                </div>
            </div>"
        } else {
            $SecurityGroupsHTML = $SecurityGroupsHTML | Out-String
        }

        if ($DistributionListHTML.Count -lt 1) {
            $DistributionListHTML = "<div class='info-card warning'>
                <i class='info-icon fa-solid fa-triangle-exclamation'></i>
                <div class='info-text'>
                    <div class='info-title'>No Distribution Lists with Members Found.</div>
                    <div class='info-description' style='white-space: normal;'>You may want to verify this information.</div>
                </div>
            </div>"
        } else {
            $DistributionListHTML = $DistributionListHTML | Out-String
        }

        if ($BuiltInHTML.Count -lt 1) {
            $BuiltInHTML = "<div class='info-card warning'>
                <i class='info-icon fa-solid fa-triangle-exclamation'></i>
                <div class='info-text'>
                    <div class='info-title'>No Builtin Groups with Members Found.</div>
                    <div class='info-description' style='white-space: normal;'>You may want to verify this information.</div>
                </div>
            </div>"
        } else {
            $BuiltInHTML = $BuiltInHTML | Out-String
        }

        if ($EmptyGroups.Count -lt 1) {
            $EmptyGroupHTML = "<div class='info-card warning'>
                <i class='info-icon fa-solid fa-triangle-exclamation'></i>
                <div class='info-text'>
                    <div class='info-title'>No Groups Without Members Found.</div>
                    <div class='info-description' style='white-space: normal;'>You may want to verify this information.</div>
                </div>
            </div>"
        } else {
            $EmptyGroupHTML = $EmptyGroupHTML | Out-String
        }

        # Combine all group categories into the final HTML structure
        $GroupMembershipWYSIWYGCustomFieldValue = "<div>
    <div class='card flex-grow-1'>
        <div class='card-title-box'>
            <div class='card-title'><i class='fa-solid fa-user-group'></i>&nbsp;&nbsp;Active Directory Group Membership
            </div>
        </div>
        <div class='card-body container-fluid' style='white-space: nowrap'>
            <div class='info-card'>
                <i class='info-icon fa-solid fa-circle-info'></i>
                <div class='info-text'>
                    <div class='info-title'>How This Report Is Generated</div>
                    <div class='info-description' style='white-space: normal;'>This report is created by a script that
                        scans Active Directory to
                        provide a complete list of groups and their members. Please note that groups are automatically
                        expanded where a group is in a group. Domain Controllers and Domain Computer groups are
                        excluded. Computers won't display. Groups without direct user members are collected and shown at
                        the end.
                    </div>
                </div>
            </div>
            <h2><i class='fa-solid fa-user-shield'></i>&nbsp;&nbsp;Security Groups</h2>
            $SecurityGroupsHTML
            <h2><i class='fa-solid fa-envelopes-bulk'></i>&nbsp;&nbsp;Distribution Lists</h2>
            $DistributionListHTML
            <h2><i class='fa-solid fa-users-gear'></i>&nbsp;&nbsp;Built-in Group Membership</h2>
            <div class='info-card'>
                <i class='info-icon fa-solid fa-circle-info'></i>
                <div class='info-text'>
                    <div class='info-title'>About Utility &amp; System Groups</div>
                    <div class='info-description' style='white-space: normal;'>This section lists groups used by
                        Windows to manage permissions (e.g., 'Remote Desktop Users'). They often appear empty
                        because their members are not standard user accounts, but special system principals or
                        accounts granted rights automatically by the OS.
                    </div>
                </div>
            </div>
            $BuiltInHTML
            <h2><i class='fa-solid fa-folder-open'></i>&nbsp;&nbsp;Empty Groups</h2>
            <div class='d-flex flex-wrap gap-2 mt-2'>
                $EmptyGroupHTML
            </div>
        </div>
    </div>
</div>"

        #region HTML Character Limit
        # Check if the HTML content exceeds the 190,000-character limit
        $HTMLCharacters = $GroupMembershipWYSIWYGCustomFieldValue.Length
        if ($HTMLCharacters -ge 190000) {
            Write-Host -Object "The current character count is '$HTMLCharacters'."
            Write-Host -Object "[Warning] The character limit of 190,000 has been reached! Trimming the output until the character limit is satisfied."

            $TrimStart = Get-Date
            $SkipOtherGroups = $False
            do {
                # Recalculate the character count and determine how much to trim
                $HTMLCharacters = $GroupMembershipWYSIWYGCustomFieldValue.Length
                $ExceededAmount = $HTMLCharacters - 190000

                # Trim Empty Groups first
                if ($EmptyGroups.Count -gt 0) {
                    # Determine the batch size for trimming
                    $BatchSize = if ($ExceededAmount -le 0) { 1 } else { [math]::Ceiling($ExceededAmount / 200) }

                    # Remove groups from the end of the list
                    for ($BatchNumber = 0; $BatchNumber -lt $BatchSize -and $EmptyGroups.Count -gt 0; $BatchNumber++) {
                        $EmptyGroups.RemoveAt($EmptyGroups.Count - 1)
                    }

                    # Rebuild the Empty Groups HTML after trimming
                    $EmptyGroups.TrimExcess()
                    $EmptyGroupHTML = New-Object System.Collections.Generic.List[String]
                    $EmptyGroupHTML.Add("<div class='info-card error'>
    <i class='info-icon fa-solid fa-circle-exclamation'></i>
    <div class='info-text'>
        <div class='info-title'>This section has been truncated.</div>
        <div class='info-description' style='white-space: normal;'>Entire groups were removed to comply with the 190,000-character limit.</div>
    </div>
</div>")
                    foreach ($Group in $EmptyGroups) {
                        $EmptyGroupHTML.Add("<span class='badge p-2'>")
                        $EmptyGroupHTML.Add("<i class='fa-solid fa-user-group me-2'></i>$($Group.SamAccountName)</span>")
                    }
                    $EmptyGroupHTML = $EmptyGroupHTML | Out-String
                    $SkipOtherGroups = $True
                }

                # Trim Security Groups if Empty Groups are exhausted
                if ($EmptyGroups.Count -lt 1 -and ($SecurityGroups | Where-Object { $_.Sid -eq "$($Domain.DomainSID)-513" }) -and !$SkipOtherGroups) {
                    $SecurityGroups.Remove(($SecurityGroups | Where-Object { $_.Sid -eq "$($Domain.DomainSID)-513" })) | Out-Null

                    # Rebuild the Security Groups HTML after trimming
                    $SecurityGroupsHTML = New-Object System.Collections.Generic.List[String]
                    $SecurityGroupsHTML.Add("<div class='info-card error'>
    <i class='info-icon fa-solid fa-circle-exclamation'></i>
    <div class='info-text'>
        <div class='info-title'>This section has been truncated.</div>
        <div class='info-description' style='white-space: normal;'>Entire groups were removed to comply with the 190,000-character limit.</div>
    </div>
</div>")
                    foreach ($Group in $SecurityGroups) {
                        $GroupMembershipCount = $Group.Membership | Measure-Object | Select-Object -ExpandProperty Count
                        $SecurityGroupsHTML.Add("<div class='container-fluid mb-2'>")
                        $SecurityGroupsHTML.Add("<h3 style='margin-bottom: 0px;'>$($Group.SamAccountName) - $GroupMembershipCount</h3>")
                        $SecurityGroupsHTML.Add("<div class='d-flex flex-wrap gap-2'>")
                        $Group.Membership | ForEach-Object {
                            $SecurityGroupsHTML.Add("<span class='badge p-2'>")
                            if ($_.ObjectClass -eq "group" -or $_.LocalObjectClass -eq "group") {
                                $icon = "<i class='fa-solid fa-user-group me-2'></i>"
                            } elseif (!$_.Enabled -and $UsersAndGroupsToInclude -notcontains $_.Sid) {
                                $icon = "<a title='This account is currently disabled.'><i class='fa-solid fa-triangle-exclamation me-2' style='color: #ffc107;'></i></a>"
                            } else {
                                $icon = "<i class='fas fa-user me-2'></i>"
                            }
                            if ($_.DisplayName) {
                                $SecurityGroupsHTML.Add("$icon$($_.DisplayName)</span>")
                            } else {
                                $SecurityGroupsHTML.Add("$icon$($_.SamAccountName)</span>")
                            }
                        }
                        $SecurityGroupsHTML.Add("</div>")
                        $SecurityGroupsHTML.Add("</div>")
                    }
                    $SecurityGroupsHTML = $SecurityGroupsHTML | Out-String
                    $SkipOtherGroups = $True
                }

                # Trim Built-in Groups if Security Groups are exhausted
                if ($EmptyGroups.Count -lt 1 -and $BuiltIn.Count -gt 0 -and !$SkipOtherGroups) {
                    $BatchSize = if ($ExceededAmount -le 0) { 1 } else { [math]::Ceiling($ExceededAmount / 200) }
                    for ($BatchNumber = 0; $BatchNumber -lt $BatchSize -and $BuiltIn.Count -gt 0; $BatchNumber++) {
                        $BuiltIn.RemoveAt($BuiltIn.Count - 1)
                    }
                    $BuiltIn.TrimExcess()

                    # Rebuild the Built-in Groups HTML after trimming
                    $BuiltInHTML = New-Object System.Collections.Generic.List[String]
                    $BuiltInHTML.Add("<br><div class='info-card error'>
    <i class='info-icon fa-solid fa-circle-exclamation'></i>
    <div class='info-text'>
        <div class='info-title'>This section has been truncated.</div>
        <div class='info-description' style='white-space: normal;'>Entire groups were removed to comply with the 190,000-character limit.</div>
    </div>
</div>")

                    foreach ($Group in $BuiltIn) {
                        $GroupMembershipCount = $Group.Membership | Measure-Object | Select-Object -ExpandProperty Count
                        $BuiltInHTML.Add("<div class='container-fluid mb-2'>")
                        $BuiltInHTML.Add("<h3 style='margin-bottom: 0px;'>$($Group.SamAccountName) - $GroupMembershipCount</h3>")
                        $BuiltInHTML.Add("<div class='d-flex flex-wrap gap-2'>")
                        $Group.Membership | ForEach-Object {
                            $BuiltInHTML.Add("<span class='badge p-2'>")
                            if ($_.ObjectClass -eq "group" -or $_.LocalObjectClass -eq "group") {
                                $icon = "<i class='fa-solid fa-user-group me-2'></i>"
                            } elseif (!$_.Enabled -and $UsersAndGroupsToInclude -notcontains $_.Sid) {
                                $icon = "<a title='This account is currently disabled.'><i class='fa-solid fa-triangle-exclamation me-2' style='color: #ffc107;'></i></a>"
                            } else {
                                $icon = "<i class='fas fa-user me-2'></i>"
                            }
                            if ($_.DisplayName) {
                                $BuiltInHTML.Add("$icon$($_.DisplayName)</span>")
                            } else {
                                $BuiltInHTML.Add("$icon$($_.SamAccountName)</span>")
                            }
                        }
                        $BuiltInHTML.Add("</div>")
                        $BuiltInHTML.Add("</div>")
                    }
                    $BuiltInHTML = $BuiltInHTML | Out-String
                    $SkipOtherGroups = $True
                }

                # Trim Distribution Lists if Built-in Groups are exhausted
                if ($EmptyGroups.Count -lt 1 -and $BuiltIn.Count -lt 1 -and $DistributionList.Count -gt 0 -and !$SkipOtherGroups) {
                    $BatchSize = if ($ExceededAmount -le 0) { 1 } else { [math]::Ceiling($ExceededAmount / 1000) }
                    for ($BatchNumber = 0; $BatchNumber -lt $BatchSize -and $DistributionList.Count -gt 0; $BatchNumber++) {
                        $DistributionList.RemoveAt($DistributionList.Count - 1)
                    }
                    $DistributionList.TrimExcess()

                    # Rebuild the Distribution Lists HTML after trimming
                    $DistributionListHTML = New-Object System.Collections.Generic.List[String]
                    $DistributionListHTML.Add("<div class='info-card error'>
    <i class='info-icon fa-solid fa-circle-exclamation'></i>
    <div class='info-text'>
        <div class='info-title'>This section has been truncated.</div>
        <div class='info-description' style='white-space: normal;'>Entire groups were removed to comply with the 190,000-character limit.</div>
    </div>
</div>")
                    foreach ($Group in $DistributionList) {
                        $GroupMembershipCount = $Group.Membership | Measure-Object | Select-Object -ExpandProperty Count
                        $DistributionListHTML.Add("<div class='container-fluid mb-2'>")
                        $DistributionListHTML.Add("<h3 style='margin-bottom: 0px;'>$($Group.SamAccountName) - $GroupMembershipCount</h3>")
                        $DistributionListHTML.Add("<div class='d-flex flex-wrap gap-2'>")
                        $Group.Membership | ForEach-Object {
                            $DistributionListHTML.Add("<span class='badge p-2'>")
                            if ($_.ObjectClass -eq "group" -or $_.LocalObjectClass -eq "group") {
                                $icon = "<i class='fa-solid fa-user-group me-2'></i>"
                            } elseif (!$_.Enabled -and $UsersAndGroupsToInclude -notcontains $_.Sid) {
                                $icon = "<a title='This account is currently disabled.'><i class='fa-solid fa-triangle-exclamation me-2' style='color: #ffc107;'></i></a>"
                            } else {
                                $icon = "<i class='fas fa-user me-2'></i>"
                            }
                            if ($_.DisplayName) {
                                $DistributionListHTML.Add("$icon$($_.DisplayName)</span>")
                            } else {
                                $DistributionListHTML.Add("$icon$($_.SamAccountName)</span>")
                            }
                        }
                        $DistributionListHTML.Add("</div>")
                        $DistributionListHTML.Add("</div>")
                    }
                    $DistributionListHTML = $DistributionListHTML | Out-String
                    $SkipOtherGroups = $True
                }

                # Trim Security Groups if all other groups are exhausted
                if ($EmptyGroups.Count -lt 1 -and $BuiltIn.Count -lt 1 -and $DistributionList.Count -lt 1 -and $SecurityGroups.Count -gt 0 -and !$SkipOtherGroups) {
                    $BatchSize = if ($ExceededAmount -le 0) { 1 } else { [math]::Ceiling($ExceededAmount / 1000) }
                    for ($BatchNumber = 0; $BatchNumber -lt $BatchSize -and $SecurityGroups.Count -gt 0; $BatchNumber++) {
                        $SecurityGroups.RemoveAt($SecurityGroups.Count - 1)
                    }
                    $SecurityGroups.TrimExcess()

                    # Rebuild the Security Groups HTML after trimming
                    $SecurityGroupsHTML = New-Object System.Collections.Generic.List[String]
                    $SecurityGroupsHTML.Add("<div class='info-card error'>
    <i class='info-icon fa-solid fa-circle-exclamation'></i>
    <div class='info-text'>
        <div class='info-title'>This section has been truncated.</div>
        <div class='info-description' style='white-space: normal;'>Entire groups were removed to comply with the 190,000-character limit.</div>
    </div>
</div>")
                    foreach ($Group in $SecurityGroups) {
                        $GroupMembershipCount = $Group.Membership | Measure-Object | Select-Object -ExpandProperty Count
                        $SecurityGroupsHTML.Add("<div class='container-fluid mb-2'>")
                        $SecurityGroupsHTML.Add("<h3 style='margin-bottom: 0px;'>$($Group.SamAccountName) - $GroupMembershipCount</h3>")
                        $SecurityGroupsHTML.Add("<div class='d-flex flex-wrap gap-2'>")
                        $Group.Membership | ForEach-Object {
                            $SecurityGroupsHTML.Add("<span class='badge p-2'>")
                            if ($_.ObjectClass -eq "group" -or $_.LocalObjectClass -eq "group") {
                                $icon = "<i class='fa-solid fa-user-group me-2'></i>"
                            } elseif (!$_.Enabled -and $UsersAndGroupsToInclude -notcontains $_.Sid) {
                                $icon = "<a title='This account is currently disabled.'><i class='fa-solid fa-triangle-exclamation me-2' style='color: #ffc107;'></i></a>"
                            } else {
                                $icon = "<i class='fas fa-user me-2'></i>"
                            }
                            if ($_.DisplayName) {
                                $SecurityGroupsHTML.Add("$icon$($_.DisplayName)</span>")
                            } else {
                                $SecurityGroupsHTML.Add("$icon$($_.SamAccountName)</span>")
                            }
                        }
                        $SecurityGroupsHTML.Add("</div>")
                        $SecurityGroupsHTML.Add("</div>")
                    }
                    $SecurityGroupsHTML = $SecurityGroupsHTML | Out-String
                    $SkipOtherGroups = $True
                }

                # Rebuild the final HTML content after trimming
                $GroupMembershipWYSIWYGCustomFieldValue = "<div>
    <div class='card flex-grow-1'>
        <div class='card-title-box'>
            <div class='card-title'><i class='fa-solid fa-user-group'></i>&nbsp;&nbsp;Active Directory Group Membership</div>
        </div>
        <div class='card-body container-fluid' style='white-space: nowrap'>
            <div class='info-card'>
                <i class='info-icon fa-solid fa-circle-info'></i>
                <div class='info-text'>
                    <div class='info-title'>How This Report Is Generated</div>
                    <div class='info-description' style='white-space: normal;'>This report is created by a script that
                        scans Active Directory to
                        provide a complete list of groups and their members. Please note that groups are automatically
                        expanded where a group is in a group. Domain Controllers and Domain Computer groups are
                        excluded. Computers won't display. Groups without direct user members are collected and shown at
                        the end.
                    </div>
                </div>
            </div>
            <h2><i class='fa-solid fa-user-shield'></i>&nbsp;&nbsp;Security Groups</h2>
            $SecurityGroupsHTML
            <h2><i class='fa-solid fa-envelopes-bulk'></i>&nbsp;&nbsp;Distribution Lists</h2>
            $DistributionListHTML
            <h2><i class='fa-solid fa-users-gear'></i>&nbsp;&nbsp;Builtin Group Membership</h2>
            <div class='info-card'>
                <i class='info-icon fa-solid fa-circle-info'></i>
                <div class='info-text'>
                    <div class='info-title'>About Utility &amp; System Groups</div>
                    <div class='info-description' style='white-space: normal;'>This section lists groups used by
                        Windows to manage permissions (e.g., 'Remote Desktop Users'). They often appear empty
                        because their members are not standard user accounts, but special system principals or
                        accounts granted rights automatically by the OS.
                    </div>
                </div>
            </div>
            $BuiltInHTML
            <h2><i class='fa-solid fa-folder-open'></i>&nbsp;&nbsp;Empty Groups</h2>
            <div class='d-flex flex-wrap gap-2 mt-2'>
                $EmptyGroupHTML
            </div>
        </div>
    </div>
</div>"

                # Recalculate the character count and elapsed time
                $HTMLCharacters = $GroupMembershipWYSIWYGCustomFieldValue.Length
                $ElapsedTime = (Get-Date) - $TrimStart
                $SkipOtherGroups = $False
            } while ($HTMLCharacters -ge 190000 -and $ElapsedTime.TotalMinutes -le 5)
        }

        # Log an error if the trimming process exceeds the timeout limit
        if ($ElapsedTime.TotalMinutes -gt 5) {
            Write-Host -Object "The current character count is '$HTMLCharacters'."
            Write-Host -Object "[Error] The 5-minute timeout has been reached. Unable to trim the output to comply with the 190,000-character limit."
            $ExitCode = 1
            $DoNotAttemptToSetGroupMembershipField = $True
        }

        # Attempt to set the custom field with the trimmed HTML content
        try {
            if (!$DoNotAttemptToSetGroupMembershipField) {
                Write-Host -Object "Attempting to set the custom field '$GroupMembershipWYSIWYG'."
                $GroupMembershipWYSIWYGCustomFieldValue | Set-NinjaProperty -Name $GroupMembershipWYSIWYG -ErrorAction Stop
                Write-Host -Object "Success!"
            }
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to set the custom field '$GroupMembershipWYSIWYG'."
            $ExitCode = 1
        }
    }

    exit $ExitCode
}
end {
    
    
    
}