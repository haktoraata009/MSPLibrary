#Requires -Version 4

<#
.SYNOPSIS
    List all local accounts on the machine and optionally save the results to a WYSIWYG custom field.
.DESCRIPTION
    List all local accounts on the machine and optionally save the results to a WYSIWYG custom field.

.EXAMPLE
    (No Parameters)

    [Warning] This script will only display local accounts. It will not display Active Directory accounts.
    [Info] Retrieving a list of local users.
    [Info] Parsing the username list.
    [Info] Retrieving additional information on individual user accounts.

    Username      FullName Enabled PasswordLastSet       LastLogon
    --------      -------- ------- ---------------       ---------
    Administrator             True 8/4/2025 12:12:02 PM  11/14/2025 5:07:36 PM
    User          User        True 10/27/2025 3:57:53 PM Never
    tuser1        tuser1      True 11/14/2025 4:49:22 PM 11/14/2025 4:57:59 PM

.EXAMPLE
    -IncludeDisabledUsers -WysiwygCustomField "LocalUsers"

    [Warning] This script will only display local accounts. It will not display Active Directory accounts.
    [Info] Retrieving a list of local users.
    [Info] Parsing the username list.
    [Info] Retrieving additional information on individual user accounts.

    Username           FullName Enabled PasswordLastSet       LastLogon
    --------           -------- ------- ---------------       ---------
    Administrator                  True 8/4/2025 12:12:02 PM  11/14/2025 5:07:36 PM
    DefaultAccount                False 11/14/2025 5:22:39 PM Never
    Guest                         False 11/14/2025 5:22:40 PM Never
    User               User        True 10/27/2025 3:57:53 PM Never
    tuser1             tuser1      True 11/14/2025 4:49:22 PM 11/14/2025 4:57:59 PM
    WDAGUtilityAccount            False 8/4/2025 2:10:39 PM   Never

    [Info] Attempting to set the custom field 'LocalUsers'.
    [Info] Successfully set the custom field 'LocalUsers'!

.PARAMETER -IncludeDisabledUsers
    Include disabled user accounts in the results.
.PARAMETER -WysiwygCustomField "ReplaceMeWithAnyWysiwygCustomField"
    Optionally specify the name of a WYSIWYG custom field to store the results in.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2012 R2
    Version: 1.3
    Release Notes: Fixed issue with domain and local accounts with the same name causing the local account to always report as disabled.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [Switch]$IncludeDisabledUsers = [System.Convert]::ToBoolean($env:includeDisabledUsers),
    [Parameter()]
    [String]$WysiwygCustomField
)

begin {
    # Check if the operating system build version is less than 9600 (Windows 10 or Windows Server 2012 R2 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 9600) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2012 R2 (9600)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # If script form variables are used, replace the command line parameters with their value.
    if ($env:wysiwygCustomFieldName) { $WysiwygCustomField = $env:wysiwygCustomFieldName }

    # Validate the WYSIWYG custom field
    if ($WysiwygCustomField) {
        # Skip writing to the WYSIWYG custom field if it is empty or whitespace
        if ([string]::IsNullOrWhiteSpace($WysiwygCustomField)) {
            Write-Host -Object "[Error] The value for 'WYSIWYG Custom Field Name' only contains spaces. Please provide a valid WYSIWYG custom field name or leave it blank."
            Write-Host -Object "[Error] Writing to the WYSIWYG custom field will be skipped."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            $WysiwygCustomField = $null
            $ExitCode = 1
            Write-Host -Object ""
        }
        else {
            # Trim the WYSIWYG Custom Field Name to remove leading and trailing whitespace
            $WysiwygCustomField = $WysiwygCustomField.Trim()

            # Skip writing to the WYSIWYG custom field if it contains invalid characters
            if ($WysiwygCustomField -match "[^0-9A-Z]") {
                Write-Host -Object "[Error] The value for 'WYSIWYG Custom Field Name' contains invalid characters. Please provide a valid WYSIWYG custom field name."
                Write-Host -Object "[Error] Writing to the WYSIWYG custom field will be skipped."
                Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
                $WysiwygCustomField = $null
                $ExitCode = 1
                Write-Host -Object ""
            }
        }
    }

    function Test-IsDomainController {
        # Determine the method to retrieve the operating system information based on PowerShell version
        try {
            $OS = if ($PSVersionTable.PSVersion.Major -lt 3) {
                Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
            } else {
                Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            }
        } catch {
            Write-Host -Object "[Error] Unable to validate whether or not this device is a domain controller."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        # Check if the ProductType is "2", which indicates that the system is a domain controller
        if ($OS.ProductType -eq "2") {
            return $true
        }
    }

    function Test-IsDomainJoined {
        # Check the PowerShell version to determine the appropriate cmdlet to use
        try {
            if ($PSVersionTable.PSVersion.Major -lt 3) {
                return $(Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
            } else {
                return $(Get-CimInstance -Class Win32_ComputerSystem).PartOfDomain
            }
        } catch {
            Write-Host -Object "[Error] Unable to validate whether or not this device is a part of a domain."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    function Test-IsEntraJoined {
        # Check if the operating system version is Windows 10 or higher
        if ([environment]::OSVersion.Version.Major -ge 10) {
            # Run the dsregcmd.exe tool to check Entra join status and look for "AzureAdJoined : YES"
            $dsreg = dsregcmd.exe /status | Select-String "AzureAdJoined : YES"
        }

        # If the search found the "AzureAdJoined : YES" string, return True, otherwise return False
        if ($dsreg) { return $True } else { return $False }
    }

    # If running on a domain controller, display an error message and exit
    if (Test-IsDomainController) {
        Write-Host -Object "[Error] This script is not compatible with domain controllers."
        exit 1
    }

    # If running on a domain joined machine, warn that only local accounts will be displayed.
    if (Test-IsDomainJoined) {
        Write-Host -Object "[Warning] This script will only display local accounts. It will not display Active Directory accounts."
    }

    # If running on an Entra joined machine, warn that only local accounts will be displayed.
    if (Test-IsEntraJoined) {
        Write-Host -Object "[Warning] This script will only display local accounts. It will not display Microsoft Entra accounts."
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
        Write-Host -Object "[Error] The user '$env:USERNAME' is not running this script in an elevated session. Please run this script as System or in an elevated session."
        exit 1
    }

    # Define paths for standard output and error logs, with random names to avoid conflicts
    $StandardOutLog = "$env:TEMP\$(Get-Random)_stdout.log"
    $StandardErrLog = "$env:TEMP\$(Get-Random)_stderr.log"

    # Define the arguments for the "net user" command to list all users
    $NetUserArguments = @(
        "user"
    )

    # Configure the process start parameters for the "net.exe" command
    $ProcessArguments = @{
        FilePath               = "$env:SystemRoot\System32\net.exe"
        ArgumentList           = $NetUserArguments
        RedirectStandardOutput = $StandardOutLog
        RedirectStandardError  = $StandardErrLog
        PassThru               = $True
        NoNewWindow            = $True
        Wait                   = $True
    }

    # Inform the user that the script is retrieving the list of local users
    Write-Host -Object "[Info] Retrieving a list of local users."

    # Try to start the "net.exe" process and catch any errors
    try {
        $NetUserProcess = Start-Process @ProcessArguments -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] Failed to start net.exe"
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Check if the exit code indicates success (0 or 1)
    if ($NetUserProcess.ExitCode -ne 0 -and $NetUserProcess.ExitCode -ne 1) {
        Write-Host -Object "[Warning] Exit code of $($NetUserProcess.ExitCode) does not indicate success."
    }

    # Check if the standard error log exists, indicating an error occurred
    if (Test-Path -Path $StandardErrLog -ErrorAction SilentlyContinue) {

        # Attempt to read the error log
        try {
            $ErrorLog = Get-Content -Path $StandardErrLog -ErrorAction Stop
        }
        catch {
            # If reading the log fails, display an error and exit
            Write-Host -Object "[Error] Failed to open error log at '$StandardErrLog'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        # Remove the error log file after reading
        try {
            Remove-Item -Path $StandardErrLog -ErrorAction Stop
        }
        catch {
            # If removing the log file fails, display an error
            Write-Host -Object "[Error] Failed to remove standard error log at '$StandardErrLog'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    # If there is any content in the error log, display it and exit
    if ($ErrorLog) {
        Write-Host -Object "[Error] An error has occurred while retrieving a list of local users."
        $ErrorLog | ForEach-Object {
            Write-Host -Object "[Error] $_"
        }
        exit 1
    }

    # Check if the standard output log exists, which contains the user list
    if (!(Test-Path -Path $StandardOutLog -ErrorAction SilentlyContinue)) {
        Write-Host -Object "[Error] No net user output detected."
        exit 1
    }

    # Try to read the standard output log for user data
    try {
        $NetUserOutput = Get-Content -Path $StandardOutLog -ErrorAction Stop
    }
    catch {
        # If reading the log fails, display an error and exit
        Write-Host -Object "[Error] Failed to open output log at '$StandardOutLog'."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Try to remove the standard output log after reading
    try {
        Remove-Item -Path $StandardOutLog -ErrorAction Stop
    }
    catch {
        # If removing the log file fails, display an error
        Write-Host -Object "[Error] Failed to remove standard output log at '$StandardOutLog'."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        $ExitCode = 1
    }

    # Inform the user that the username list is being parsed
    Write-Host -Object "[Info] Parsing the username list."

    # Skip the first 4 lines of the output
    $NetUserOutput = $NetUserOutput | Select-Object -Skip 4

    # Select all but the last two lines of the output and remove lines without any content
    $NetUserOutput = $NetUserOutput | Select-Object -First ($NetUserOutput.Count - 2) | Where-Object { $_ }

    # Split the usernames by 4 or more spaces and trim whitespace
    $Usernames = $NetUserOutput -split '\s{4,}' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

    # Create a list to hold user account information
    $LocalUserAccounts = New-Object System.Collections.Generic.List[object]

    # Inform the user that additional information is being retrieved for each account
    Write-Host -Object "[Info] Retrieving additional information on individual user accounts."

    # For each username in the list, retrieve more details
    foreach ($CurrentUser in $Usernames) {
        $CurrentUserWithQuotes = "`"$CurrentUser`""
        $StandardOutLog = "$env:TEMP\$(Get-Random)_stdout.log"
        $StandardErrLog = "$env:TEMP\$(Get-Random)_stderr.log"

        # Define the arguments for the "net user" command for a specific user
        $NetUserArguments = @(
            "user"
            $CurrentUserWithQuotes
        )

        # Configure the process start parameters for the "net.exe" command
        $ProcessArguments = @{
            FilePath               = "$env:SystemRoot\System32\net.exe"
            ArgumentList           = $NetUserArguments
            RedirectStandardOutput = $StandardOutLog
            RedirectStandardError  = $StandardErrLog
            PassThru               = $True
            NoNewWindow            = $True
            Wait                   = $True
        }

        # Try to start the "net.exe" process for the current user
        try {
            $NetUserProcess = Start-Process @ProcessArguments -ErrorAction Stop
        }
        catch {
            # If the process fails, display an error and return to the next iteration
            Write-Host -Object "[Error] Failed to start net.exe for user '$CurrentUser'"
            Write-Host -Object "[Error] $($_.Exception.Message)"
            return
        }

        # Check if the exit code of the net.exe process indicates failure
        if ($NetUserProcess.ExitCode -ne 0) {
            Write-Host -Object "[Warning] Exit code of $($NetUserProcess.ExitCode) does not indicate success."
        }

        # Check if the standard error log exists, indicating an error occurred
        if (Test-Path -Path $StandardErrLog -ErrorAction SilentlyContinue) {
            try {
                $ErrorLog = Get-Content -Path $StandardErrLog -Encoding Oem -ErrorAction Stop
            }
            catch {
                # If reading the log fails, display an error and set the exit code to 1
                Write-Host -Object "[Error] Failed to open error log at '$StandardErrLog'."
                Write-Host -Object "[Error] $($_.Exception.Message)"
                $ExitCode = 1
            }

            # Remove the error log file after reading
            try {
                Remove-Item -Path $StandardErrLog -ErrorAction Stop
            }
            catch {
                # If removing the log file fails, display an error and set the exit code to 1
                Write-Host -Object "[Error] Failed to remove standard error log at '$StandardErrLog'."
                Write-Host -Object "[Error] $($_.Exception.Message)"
                $ExitCode = 1
            }
        }

        # If there is any content in the error log, display it and set the exit code to 1
        if ($ErrorLog) {
            Write-Host -Object "[Error] An error has occurred while retrieving information for user '$CurrentUser'."
            $ErrorLog | ForEach-Object {
                Write-Host -Object "[Error] $_"
            }
            $ExitCode = 1
        }

        # Check if the standard output log exists, which contains the user details
        if (!(Test-Path -Path $StandardOutLog -ErrorAction SilentlyContinue)) {
            Write-Host -Object "[Error] No net user output detected for user '$CurrentUser'."
            return
        }

        # Try to read the standard output log for user details
        try {
            $NetUserOutput = Get-Content -Path $StandardOutLog -Encoding Oem -ErrorAction Stop
        }
        catch {
            # If reading the log fails, display an error and return
            Write-Host -Object "[Error] Failed to open output log at '$StandardOutLog' for user '$CurrentUser'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            return
        }

        # Try to remove the standard output log after reading
        try {
            Remove-Item -Path $StandardOutLog -ErrorAction Stop
        }
        catch {
            # If removing the log file fails, display an error and set the exit code to 1
            Write-Host -Object "[Error] Failed to remove standard output log at '$StandardOutLog'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }

        # If the output log is empty, display an error and return
        if ([string]::IsNullOrWhiteSpace($NetUserOutput)) {
            Write-Host -Object "[Error] No output detected for user '$CurrentUser'."
            $ExitCode = 1
            return
        }

        # Extract relevant information from the output log for each user account
        $LastSet = "$(($NetUserOutput[8]) -split '\s{4,}' | Select-Object -Skip 1)".Trim()
        $Expired = "$(($NetUserOutput[9]) -split '\s{4,}' | Select-Object -Skip 1)".Trim()
        $Changeable = "$(($NetUserOutput[10]) -split '\s{4,}' | Select-Object -Skip 1)".Trim()
        $LastLogon = "$(($NetUserOutput[18]) -split '\s{4,}' | Select-Object -Skip 1)".Trim()

        # Attempt to retrieve the local user's properties
        $LocalUserProperties = $null
        try {
            $LocalUserProperties = Get-CimInstance -Class Win32_UserAccount -Filter "LocalAccount=$True and Name='$CurrentUser'" -ErrorAction Stop
        }
        catch {
            # If retrieving local user properties fails, display an error and set the exit code to 1
            Write-Host -Object "[Error] Failed to retrieve local user properties for '$CurrentUser'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }

        # Try to add user account details to the list of local user accounts
        try {
            $ErrorActionPreference = "Stop"
            $LocalUserAccounts.Add(
                [PSCustomObject]@{
                    Username              = $CurrentUser
                    FullName              = "$(($NetUserOutput[1]) -split '\s{4,}' | Select-Object -Skip 1)".Trim()
                    Comment               = "$(($NetUserOutput[2]) -split '\s{4,}' | Select-Object -Skip 1)".Trim()
                    Enabled               = (!$LocalUserProperties.Disabled)
                    AccountExpires        = "$(($NetUserOutput[6]) -split '\s{4,}' | Select-Object -Skip 1)".Trim()
                    PasswordLastSet       = try { Get-Date -Date $LastSet } catch { "$LastSet" };
                    PasswordExpires       = try { Get-Date -Date $Expired } catch { "$Expired" };
                    PasswordChangeable    = try { Get-Date -Date $Changeable } catch { "$Changeable" };
                    PasswordRequired      = $LocalUserProperties.PasswordRequired
                    UserMayChangePassword = $LocalUserProperties.PasswordChangeable
                    WorkstationsAllowed   = "$(($NetUserOutput[14]) -split '\s{4,}' | Select-Object -Skip 1)".Trim()
                    LogonScript           = "$(($NetUserOutput[15]) -split '\s{4,}' | Select-Object -Skip 1)".Trim()
                    UserProfile           = "$(($NetUserOutput[16]) -split '\s{4,}' | Select-Object -Skip 1)".Trim()
                    LastLogon             = try { Get-Date -Date $LastLogon } catch { "$LastLogon" };
                    LogonHoursAllowed     = "$(($NetUserOutput[20]) -split '\s{4,}' | Select-Object -Skip 1)".Trim()
                }
            )
            $ErrorActionPreference = "Continue"
        }
        catch {
            # If adding the account details fails, display an error and set the exit code to 1
            Write-Host -Object "[Error] Failed to parse information about user '$CurrentUser'"
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1

            # Silently continue and add a basic object with just the username to the list
            $ErrorActionPreference = "SilentlyContinue"
            $LocalUserAccounts.Add(
                [PSCustomObject]@{
                    Username = $CurrentUser
                }
            )
            $ErrorActionPreference = "Continue"
        }
    }

    # If Include Disabled Users is not specified, filter out disabled accounts
    # Only include enabled accounts or those where the Enabled property is null (if the property was not retrieved)
    if (!$IncludeDisabledUsers) {
        $LocalUserAccounts = $LocalUserAccounts | Where-Object { $_.Enabled -eq $true -or $_.Enabled -eq $null }
    }

    # Display the final list of users in a table format
    Write-Host -Object ""
    ($LocalUserAccounts | Sort-Object -Property Username | Format-Table -Property Username, FullName, Enabled, PasswordLastSet, LastLogon -AutoSize | Out-String).Trim() | Write-Host
    Write-Host -Object ""

    # If a custom field is specified, try to set it
    if ($WysiwygCustomField) {
        try {
            Write-Host -Object "[Info] Attempting to set the custom field '$WysiwygCustomField'."

            # Generate HTML content from the user accounts and format the output
            $CustomFieldValue = $LocalUserAccounts | Sort-Object -Property Username | Select-Object -Property Username, @{ Name = "Full Name" ; Expression = { $_.FullName } }, Enabled, @{ Name = "Password Last Set" ; Expression = { $_.PasswordLastSet } }, @{ Name = "Last Logon" ; Expression = { $_.LastLogon } } | ConvertTo-Html -Fragment
            $CustomFieldValue = "<div class='card flex-grow-1'>
                            <div class='card-title-box'>
                                <div class='card-title'><i class='fa-solid fa-users'></i>&nbsp;&nbsp;Local Users</div>
                            </div>
                            <div class='card-body' style='white-space: nowrap;'>
                                $CustomFieldValue
                            </div>
                        </div>"

            # Set the custom field using the generated HTML
            Set-NinjaProperty -Name $WysiwygCustomField -Value $CustomFieldValue -ErrorAction Stop
            Write-Host -Object "[Info] Successfully set the custom field '$WysiwygCustomField'!"
        }
        catch {
            # If setting the custom field fails, display an error and exit
            Write-Host -Object "[Error] Failed to set the custom field '$WysiwygCustomField'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    # Exit with the appropriate exit code
    exit $ExitCode
}
end {
    
    
    
}