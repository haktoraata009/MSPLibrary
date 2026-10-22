#Requires -Version 5.1

<#
.SYNOPSIS
    Make changes to the default domain password policy (if run on a Domain Controller) or the local password security policy (if run on a non-domain joined machine).
.DESCRIPTION
    Make changes to the default domain password policy (if run on a Domain Controller) or the local password security policy (if run on a non-domain joined machine).
.EXAMPLE
    -MinPassLength "14" -PassComplexityAction "Enable"

    Verifying the Active Directory PowerShell module is imported.

    This machine is joined to the domain and is a domain controller. The default domain password policy will be configured.
    Retrieving the current password policy.
    The minimum password length is already set to '14'.
    The password complexity is already set to 'Enable'.

    [Alert] The current password policy already has all of your requested changes. No update needed.

.PARAMETER NumberOfPassToRemember
    This security setting determines the number of unique new passwords that have to be associated with a user account before an old password can be
    reused. The value must be between 0 and 24 passwords.

.PARAMETER MaxPassAge
    This security setting determines the period of time (in days) that a password can be used before the system requires the user to change it. You
    can set passwords to expire after a number of days between 1 and 999, or you can specify that passwords never expire by setting the number of days
    to 0.

.PARAMETER MinPassAge
    This security setting determines the period of time (in days) that a password must be used before the user can change it. You can set a value
    between 1 and 998 days, or you can allow changes immediately by setting the number of days to 0.

.PARAMETER MinPassLength
    This security setting determines the least number of characters that a password for a user account may contain. Values less than 8 are not permitted.

.PARAMETER PassComplexityAction
    This security setting determines whether passwords must meet the standard Windows complexity requirements.
    https://learn.microsoft.com/previous-versions/windows/it-pro/windows-10/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements

.PARAMETER LockoutDurationInMinutes
    This security setting determines the number of minutes a locked-out account remains locked out before automatically becoming unlocked. The
    available range is from 0 minutes through 99,999 minutes. If you set the account lockout duration to 0, the account will be locked out until an
    administrator explicitly unlocks it.

.PARAMETER MaxLoginAttempts
    This security setting determines the number of failed logon attempts that causes a user account to be locked out. A locked-out account cannot be
    used until it is reset by an administrator or until the lockout duration for the account has expired. You can set a value between 0 and 999 failed
    logon attempts. If you set the value to 0, the account will never be locked out.

.PARAMETER ResetLockoutAfterMinutes
    This security setting determines the number of minutes that must elapse after a failed logon attempt before the failed logon attempt counter is
    reset to 0 bad logon attempts. The available range is 1 minute to 99,999 minutes.

.PARAMETER InitiateGpupdateIfNecessary
    If the default domain password policy was edited a gpupdate will be necessary to apply the changes immediately. Otherwise your changes will take
    effect on the next refresh.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 2.0
    Release Notes: Improved input and environment validation, made output more verbose, added gpupdate option so changes can be immediate, added CIS
    recommendations based on the CIS benchmarks for password policies.
#>

[CmdletBinding()]
param (
    [Parameter()]
    $NumberOfPassToRemember,
    [Parameter()]
    $MaxPassAge,
    [Parameter()]
    $MinPassAge,
    [Parameter()]
    $MinPassLength,
    [Parameter()]
    [String]$PassComplexityAction,
    [Parameter()]
    $LockoutDurationInMinutes,
    [Parameter()]
    $MaxLoginAttempts,
    [Parameter()]
    $ResetLockoutAfterMinutes,
    [Parameter()]
    $InitiateGpupdateIfNecessary = [System.Convert]::ToBoolean($env:initiateGpupdateIfNecessary)
)

begin {
    # If script form variables are used, replace the command line parameters with their value.
    if ($env:numberOfPasswordsToRemember) { $NumberOfPassToRemember = $env:numberOfPasswordsToRemember }
    if ($env:maximumPasswordAge) { $MaxPassAge = $env:maximumPasswordAge }
    if ($env:minimumPasswordAge) { $MinPassAge = $env:minimumPasswordAge }
    if ($env:minimumPasswordLength) { $MinPassLength = $env:minimumPasswordLength }
    if ($env:passwordComplexityAction) { $PassComplexityAction = $env:passwordComplexityAction }
    if ($env:lockoutDurationInMinutes) { $LockoutDurationInMinutes = $env:lockoutDurationInMinutes }
    if ($env:maximumLoginAttempts) { $MaxLoginAttempts = $env:maximumLoginAttempts }
    if ($env:resetLockoutAfterMinutes) { $ResetLockoutAfterMinutes = $env:resetLockoutAfterMinutes }

    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    #region Validate Input

    # Validate the "Number of Passwords to Remember" parameter
    if ($NumberOfPassToRemember) {
        # Check if the value is null or whitespace
        if ([String]::IsNullOrWhiteSpace($NumberOfPassToRemember)) {
            Write-Host -Object "[Error] The number of passwords to remember value provided is just whitespace. You must provide a value or leave it blank."
            exit 1
        }

        # Trim the value if it is a string
        if ($NumberOfPassToRemember -is [String]) {
            $NumberOfPassToRemember = $NumberOfPassToRemember.Trim()
        }

        # Ensure the value contains only numeric characters
        if ($NumberOfPassToRemember -match "[^0-9]") {
            Write-Host -Object "[Error] The number of passwords to remember value '$NumberOfPassToRemember' contains invalid characters."
            Write-Host -Object "[Error] Only numeric characters are accepted."
            exit 1
        }

        # Attempt to convert the value to an integer
        try {
            [int]$NumberOfPassToRemember = $NumberOfPassToRemember
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to convert the number of passwords to remember value '$NumberOfPassToRemember' into an integer."
            Write-Host -Object "[Error] Please specify a number that is between 0 and 24 (inclusive)."
            exit 1
        }

        # Ensure the value is within the valid range
        if ($NumberOfPassToRemember -lt 0 -or $NumberOfPassToRemember -gt 24) {
            Write-Host -Object "[Error] The number of passwords to remember value '$NumberOfPassToRemember' provided is invalid."
            Write-Host -Object "[Error] Please specify a number that is between 0 and 24 (inclusive)."
            exit 1
        }

        # Warn if the value is less than the recommended value
        if ($NumberOfPassToRemember -lt 24) {
            Write-Host -Object "[Warning] You are setting the number of passwords to remember to '$NumberOfPassToRemember'."
            Write-Host -Object "[Warning] The Center for Internet Security (CIS) recommends setting this value to 24."
        }
    }

    # Validate the "Maximum Password Age" parameter
    if ($MaxPassAge) {
        # Check if the value is null or whitespace
        if ([String]::IsNullOrWhiteSpace($MaxPassAge)) {
            Write-Host -Object "[Error] The maximum password age provided is just whitespace. You must provide a value or leave it blank."
            exit 1
        }

        # Trim the value if it is a string
        if ($MaxPassAge -is [String]) {
            $MaxPassAge = $MaxPassAge.Trim()
        }

        # Ensure the value contains only numeric characters
        if ($MaxPassAge -match "[^0-9]") {
            Write-Host -Object "[Error] The maximum password age '$MaxPassAge' contains invalid characters. Only numeric characters are accepted."
            exit 1
        }

        # Attempt to convert the value to an integer
        try {
            [int]$MaxPassAge = $MaxPassAge
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to convert the maximum password age '$MaxPassAge' into an integer."
            Write-Host -Object "[Error] Please specify a number that is between 0 and 999 (inclusive)."
            exit 1
        }

        # Ensure the value is within the valid range
        if ($MaxPassAge -lt 0 -or $MaxPassAge -gt 999) {
            Write-Host -Object "[Error] The maximum password age '$MaxPassAge' provided is invalid."
            Write-Host -Object "[Error] Please specify a number that is between 0 and 999 (inclusive)."
            exit 1
        }

        # Warn if the value is greater than the recommended value or set to unlimited
        if ($MaxPassAge -gt 365 -or $MaxPassAge -eq 0) {
            Write-Host -Object "[Warning] You are setting the maximum password age to '$MaxPassAge'."
            Write-Host -Object "[Warning] The Center for Internet Security (CIS) recommends setting this value to 365 or fewer days, but not 0."
        }
    }

    # Validate the "Minimum Password Age" parameter
    if ($MinPassAge) {
        # Check if the value is null or whitespace
        if ([String]::IsNullOrWhiteSpace($MinPassAge)) {
            Write-Host -Object "[Error] The minimum password age provided is just whitespace. You must provide a value or leave it blank."
            exit 1
        }

        # Trim the value if it is a string
        if ($MinPassAge -is [String]) {
            $MinPassAge = $MinPassAge.Trim()
        }

        # Ensure the value contains only numeric characters
        if ($MinPassAge -match "[^0-9]") {
            Write-Host -Object "[Error] The minimum password age provided '$MinPassAge' contains invalid characters."
            Write-Host -Object "[Error] Only numeric characters are accepted."
            exit 1
        }

        # Attempt to convert the value to an integer
        try {
            [int]$MinPassAge = $MinPassAge
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to convert the minimum password age '$MinPassAge' into an integer."
            Write-Host -Object "[Error] Please specify a number that is between 0 and 998 (inclusive)."
            exit 1
        }

        # Ensure the value is within the valid range
        if ($MinPassAge -lt 0 -or $MinPassAge -gt 998) {
            Write-Host -Object "[Error] The minimum password age '$MinPassAge' provided is invalid."
            Write-Host -Object "[Error] Please specify a number that is between 0 and 998 (inclusive)."
            exit 1
        }

        # Warn if the value is set to 0
        if ($MinPassAge -eq 0) {
            Write-Host -Object "[Warning] You are setting the minimum password age to '$MinPassAge'."
            Write-Host -Object "[Warning] The Center for Internet Security (CIS) recommends setting this value to 1 or more days."
        }
    }

    # Validate the "Minimum Password Length" parameter
    if ($MinPassLength) {
        # Check if the value is null or whitespace
        if ([String]::IsNullOrWhiteSpace($MinPassLength)) {
            Write-Host -Object "[Error] The minimum password length provided is just whitespace. You must provide a value or leave it blank."
            exit 1
        }

        # Trim the value if it is a string
        if ($MinPassLength -is [String]) {
            $MinPassLength = $MinPassLength.Trim()
        }

        # Ensure the value contains only numeric characters
        if ($MinPassLength -match "[^0-9]") {
            Write-Host -Object "[Error] The minimum password length provided '$MinPassLength' contains invalid characters."
            Write-Host -Object "[Error] Only numeric characters are accepted."
            exit 1
        }

        # Attempt to convert the value to an integer
        try {
            [int]$MinPassLength = $MinPassLength
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to convert the minimum password length '$MinPassLength' into an integer."
            Write-Host -Object "[Error] Please specify a number that is less than 128 and greater than or equal to 8."
            exit 1
        }

        # Ensure the value is within the valid range
        if ($MinPassLength -lt 8 -or $MinPassLength -ge 128) {
            Write-Host -Object "[Error] The minimum password length '$MinPassLength' provided is invalid."
            Write-Host -Object "[Error] Please specify a number that is less than 128 and greater than or equal to 8."
            exit 1
        }

        # Warn if the value is less than the recommended value
        if ($MinPassLength -lt 14) {
            Write-Host -Object "[Warning] You are setting the minimum password length to '$MinPassLength'."
            Write-Host -Object "[Warning] The Center for Internet Security (CIS) recommends setting this value to 14 or more characters."
        }

        # Warn if the value is greater than 14 and may require additional configuration
        if ($MinPassLength -gt 14) {
            Write-Host -Object "[Warning] You are setting the minimum length to be above 14."
            Write-Host -Object "[Warning] This restriction may be less effective if 'Relax minimum password length limits' is not set to enabled."
            Write-Host -Object "[Warning] 'Relax minimum password length limits' has to be manually configured either with group policy or by editing the local security policy."
            Write-Host -Object "[Warning] https://support.microsoft.com/topic/minimum-password-length-auditing-and-enforcement-on-certain-versions-of-windows-5ef7fecf-3325-f56b-cc10-4fd565aacc59"
        }
    }

    # Validate the "Password Complexity Action" parameter
    if ($PassComplexityAction) {
        # Check if the value is null or whitespace
        if ([String]::IsNullOrWhiteSpace($PassComplexityAction)) {
            Write-Host -Object "[Error] The password complexity action provided is just whitespace. You must provide a value or leave it blank."
            exit 1
        }

        # Trim the value and define valid options
        $PassComplexityAction = $PassComplexityAction.Trim()
        $ValidComplexityActions = "Enable", "Disable"

        # Ensure the value is one of the valid options
        if ($ValidComplexityActions -notcontains $PassComplexityAction) {
            Write-Host -Object "[Error] An invalid password complexity action '$PassComplexityAction' was provided."
            Write-Host -Object "[Error] Please specify either 'Enable' or 'Disable'."
            exit 1
        }

        # Warn if disabling password complexity
        if ($PassComplexityAction -eq "Disable") {
            Write-Host -Object "[Warning] You are disabling password complexity."
            Write-Host -Object "[Warning] The Center for Internet Security (CIS) recommends setting this value to enabled."
        }

        # Set the complexity flag based on the action
        switch ($PassComplexityAction) {
            "Enable" { $PassComplexity = $True }
            "Disable" { $PassComplexity = $False }
        }
    }

    # Validate the "Lockout Duration in Minutes" parameter
    if ($LockoutDurationInMinutes) {
        # Check if the value is null or whitespace
        if ([String]::IsNullOrWhiteSpace($LockoutDurationInMinutes)) {
            Write-Host -Object "[Error] The lockout duration provided is just whitespace. You must provide a value or leave it blank."
            exit 1
        }

        # Trim the value if it is a string
        if ($LockoutDurationInMinutes -is [String]) {
            $LockoutDurationInMinutes = $LockoutDurationInMinutes.Trim()
        }

        # Ensure the value contains only numeric characters
        if ($LockoutDurationInMinutes -match "[^0-9]") {
            Write-Host -Object "[Error] The lockout duration provided '$LockoutDurationInMinutes' contains invalid characters."
            Write-Host -Object "[Error] Only numeric characters are accepted."
            exit 1
        }

        # Attempt to convert the value to an integer
        try {
            [int]$LockoutDurationInMinutes = $LockoutDurationInMinutes
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to convert the lockout duration of '$LockoutDurationInMinutes' into an integer."
            Write-Host -Object "[Error] Please specify a number that is between 0 and 99,999 minutes (inclusive)."
            exit 1
        }

        # Ensure the value is within the valid range
        if ($LockoutDurationInMinutes -lt 0 -or $LockoutDurationInMinutes -ge 100000) {
            Write-Host -Object "[Error] The lockout duration '$LockoutDurationInMinutes' provided is invalid."
            Write-Host -Object "[Error] Please specify a number that is between 0 and 99,999 minutes (inclusive)."
            exit 1
        }

        # Warn if the value is less than the recommended value
        if ($LockoutDurationInMinutes -lt 15 -and $LockoutDurationInMinutes -ne 0) {
            Write-Host -Object "[Warning] You are setting a lockout duration of '$LockoutDurationInMinutes'."
            Write-Host -Object "[Warning] The Center for Internet Security (CIS) recommends setting this value to 15 or more minutes."
        }
    }

    # Validate the "Maximum Login Attempts" parameter
    if ($MaxLoginAttempts) {
        # Check if the value is null or whitespace
        if ([String]::IsNullOrWhiteSpace($MaxLoginAttempts)) {
            Write-Host -Object "[Error] The maximum login attempts value provided is just whitespace. You must provide a value or leave it blank."
            exit 1
        }

        # Trim the value if it is a string
        if ($MaxLoginAttempts -is [String]) {
            $MaxLoginAttempts = $MaxLoginAttempts.Trim()
        }

        # Ensure the value contains only numeric characters
        if ($MaxLoginAttempts -match "[^0-9]") {
            Write-Host -Object "[Error] The maximum login attempts value '$MaxLoginAttempts' contains invalid characters."
            Write-Host -Object "[Error] Only numeric characters are accepted."
            exit 1
        }

        # Attempt to convert the value to an integer
        try {
            [int]$MaxLoginAttempts = $MaxLoginAttempts
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to convert the maximum login attempts value '$MaxLoginAttempts' into an integer."
            Write-Host -Object "[Error] Please specify a number that is between 0 and 999 (inclusive)"
            exit 1
        }

        # Ensure the value is within the valid range
        if ($MaxLoginAttempts -lt 0 -or $MaxLoginAttempts -gt 999) {
            Write-Host -Object "[Error] The maximum login attempts value '$MaxLoginAttempts' provided is invalid."
            Write-Host -Object "[Error] Please specify a number that is between 0 and 999 (inclusive)."
            exit 1
        }

        # Warn if the value is greater than the recommended value or set to unlimited
        if ($MaxLoginAttempts -gt 5 -or $MaxLoginAttempts -eq 0) {
            Write-Host -Object "[Warning] You are setting the maximum login attempts to '$MaxLoginAttempts'."
            Write-Host -Object "[Warning] The Center for Internet Security (CIS) recommends setting this value to 5 or fewer but not 0."
        }
    }

    # Validate the "Reset Lockout After Minutes" parameter
    if ($ResetLockoutAfterMinutes) {
        # Check if the value is null or whitespace
        if ([String]::IsNullOrWhiteSpace($ResetLockoutAfterMinutes)) {
            Write-Host -Object "[Error] The reset lockout time value provided is just whitespace. You must provide a value or leave it blank."
            exit 1
        }

        # Trim the value if it is a string
        if ($ResetLockoutAfterMinutes -is [String]) {
            $ResetLockoutAfterMinutes = $ResetLockoutAfterMinutes.Trim()
        }

        # Ensure the value contains only numeric characters
        if ($ResetLockoutAfterMinutes -match "[^0-9]") {
            Write-Host -Object "[Error] The reset lockout time value '$ResetLockoutAfterMinutes' contains invalid characters."
            Write-Host -Object "[Error] Only numeric characters are accepted."
            exit 1
        }

        # Attempt to convert the value to an integer
        try {
            [int]$ResetLockoutAfterMinutes = $ResetLockoutAfterMinutes
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to convert the reset lockout time value '$ResetLockoutAfterMinutes' into an integer."
            Write-Host -Object "[Error] Please specify a number that is between 1 and 99,999 (inclusive)."
            exit 1
        }

        # Ensure the value is within the valid range
        if ($ResetLockoutAfterMinutes -lt 1 -or $ResetLockoutAfterMinutes -gt 99999) {
            Write-Host -Object "[Error] The reset lockout time value '$ResetLockoutAfterMinutes' provided is invalid."
            Write-Host -Object "[Error] Please specify a number that is between 1 and 99,999 (inclusive)."
            exit 1
        }

        # Warn if the value is less than the recommended value
        if ($ResetLockoutAfterMinutes -lt 15) {
            Write-Host -Object "[Warning] You are setting the lockout time value to '$ResetLockoutAfterMinutes' minutes."
            Write-Host -Object "[Warning] The Center for Internet Security (CIS) recommends setting this value to 15 or more minutes."
        }
    }

    # Check if no parameters were provided for password or account policy changes
    if ([String]::IsNullOrEmpty($NumberOfPassToRemember) -and [String]::IsNullOrEmpty($MaxPassAge) -and [String]::IsNullOrEmpty($MinPassAge) -and
        [String]::IsNullOrEmpty($MinPassLength) -and [String]::IsNullOrEmpty($PassComplexityAction) -and
        [String]::IsNullOrEmpty($LockoutDurationInMinutes) -and [String]::IsNullOrEmpty($MaxLoginAttempts) -and
        [String]::IsNullOrEmpty($ResetLockoutAfterMinutes)) {
        Write-Host -Object "[Error] No action was specified. You must specify a desired password or account policy item to change."
        exit 1
    }

    #region Check for Conflicts

    # Ensure the lockout duration is greater than or equal to the reset lockout time
    if ($LockoutDurationInMinutes -and ($ResetLockoutAfterMinutes -or $ResetLockoutAfterMinutes -eq 0) -and $LockoutDurationInMinutes -lt
        $ResetLockoutAfterMinutes) {
        Write-Host -Object "[Error] The lockout duration specified as '$LockoutDurationInMinutes' minutes is less than the specified reset lockout time of '$ResetLockoutAfterMinutes' minutes."
        Write-Host -Object "[Error] The lockout duration must be greater than or equal to the 'Reset Lockout After Minutes' value."
        Write-Host -Object "[Error] Unless the lockout duration is set to '0' for 'Until administrator unlocks it'."
        exit 1
    }

    # Ensure the minimum password age is less than the maximum password age
    if ($MaxPassAge -and $MinPassAge -and $MaxPassAge -le $MinPassAge) {
        Write-Host -Object "[Error] The specified minimum password age '$MinPassAge' is greater than or equal to the specified maximum password age '$MaxPassAge'."
        Write-Host -Object "[Error] The minimum password age must be less than the maximum password age."
        Write-Host -Object "[Error] Unless the maximum password age is set to '0' for no expiration or the minimum is set to '0' to allow password changes at any time."
        exit 1
    }

    # Ensure that if max login attempts are unlimited, no lockout duration or reset lockout time is specified
    if ($MaxLoginAttempts -eq 0 -and ($ResetLockoutAfterMinutes -or $LockoutDurationInMinutes -or $LockoutDurationInMinutes -eq 0)) {
        Write-Host -Object "[Error] You set the max login attempts to unlimited ($MaxLoginAttempts), but you also specified a lockout duration or reset lockout time."
        Write-Host -Object "[Error] You must specify a maximum number of attempts to set the reset lockout after value and lockout duration."
        exit 1
    }

    #endregion

    #endregion

    #region Helper Functions
    function Invoke-LegacyConsoleTool {
        [CmdletBinding()]
        param(
            [Parameter()]
            [String]$FilePath,
            [Parameter()]
            [String[]]$ArgumentList,
            [Parameter()]
            [String]$WorkingDirectory,
            [Parameter()]
            [Int]$Timeout = 30,
            [Parameter()]
            [System.Text.Encoding]$Encoding
        )

        # Validate that the file path is not null or empty
        if ([String]::IsNullOrEmpty($FilePath) -or $FilePath -match "^\s+$") {
            throw (New-Object System.ArgumentNullException("You must provide a file path to the legacy tool you are trying to use."))
        }

        if ($WorkingDirectory) {
            # Validate that the working directory is not empty
            if ([String]::IsNullOrWhiteSpace($WorkingDirectory)) {
                throw (New-Object System.ArgumentNullException("The working directory you provided is just whitespace."))
            }

            $WorkingDirectory = $WorkingDirectory.Trim()

            # Check if the working directory exists at the specified path
            if (!(Test-Path -Path $WorkingDirectory -PathType Container -ErrorAction SilentlyContinue)) {
                throw (New-Object System.IO.FileNotFoundException("Unable to find '$WorkingDirectory'."))
            }
        }

        # Validate that a timeout value is provided
        if (!$Timeout) {
            throw (New-Object System.ArgumentNullException("You must provide a timeout value."))
        }

        # Check if the file path is not rooted and does not exist in the current directory
        if (!([System.IO.Path]::IsPathRooted($FilePath)) -and !(Test-Path -Path $FilePath -PathType Leaf -ErrorAction SilentlyContinue)) {
            # Retrieve the system PATH environment variable and split it into directories
            $EnvPaths = [System.Environment]::GetEnvironmentVariable("PATH").Split(";")
            # Retrieve the PATHEXT environment variable to get executable file extensions
            $PathExts = [System.Environment]::GetEnvironmentVariable("PATHEXT").Split(";")

            $ResolvedPath = $null
            # Iterate through each directory in the PATH environment variable
            foreach ($Directory in $EnvPaths) {
                # Check for each possible file extension in PATHEXT
                foreach ($FileExtension in $PathExts) {
                    # Construct the potential file path
                    $PotentialMatch = Join-Path $Directory ($FilePath + $FileExtension)
                    # If the file exists, set it as the resolved path
                    if (Test-Path $PotentialMatch -PathType Leaf) {
                        $ResolvedPath = $PotentialMatch
                        break
                    }
                }
                # Exit the loop if a resolved path is found
                if ($ResolvedPath) { break }
            }

            # If a resolved path is found, update the FilePath variable
            if ($ResolvedPath) {
                $FilePath = $ResolvedPath
            }
        }

        # Check if the file exists at the specified path
        if (!(Test-Path -Path $FilePath -PathType Leaf -ErrorAction SilentlyContinue)) {
            throw (New-Object System.IO.FileNotFoundException("Unable to find '$FilePath'."))
        }

        # Ensure the timeout value is at least 30 seconds
        if ($Timeout -lt 30) {
            throw (New-Object System.ArgumentOutOfRangeException("You must provide a timeout value that is greater than or equal to 30 seconds."))
        }

        # Initialize a ProcessStartInfo object to configure the process
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = $FilePath

        # Combine arguments into a single string if provided
        if ($ArgumentList) {
            $ProcessInfo.Arguments = $ArgumentList -join " "
        }

        # Configure the process to run without a shell, without a new window, and with redirected I/O
        $ProcessInfo.UseShellExecute = $False
        $ProcessInfo.CreateNoWindow = $True
        $ProcessInfo.RedirectStandardInput = $True
        $ProcessInfo.RedirectStandardOutput = $True
        $ProcessInfo.RedirectStandardError = $True

        if ($WorkingDirectory) {
            $ProcessInfo.WorkingDirectory = $WorkingDirectory
        }

        # Set the encoding for standard output and error streams
        if (!$Encoding) {
            try {
                # Dynamically load the method to get the OEM code page if not already loaded
                if (-not ([System.Management.Automation.PSTypeName]'NativeMethods.Win32').Type) {
                    $Definition = '[DllImport("kernel32.dll")]' + "`n" + 'public static extern uint GetOEMCP();'
                    Add-Type -MemberDefinition $Definition -Name "Win32" -Namespace "NativeMethods" -ErrorAction Stop
                }

                # Retrieve the OEM code page and set the encoding
                [int]$OemCodePage = [NativeMethods.Win32]::GetOEMCP()
                $Encoding = [System.Text.Encoding]::GetEncoding($OemCodePage)
            } catch {
                throw $_
            }
        }
        $ProcessInfo.StandardOutputEncoding = $Encoding
        $ProcessInfo.StandardErrorEncoding = $Encoding

        # Create a new process object and attach the ProcessStartInfo configuration
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessInfo

        # Add properties to store standard output and error streams
        $Process | Add-Member -MemberType NoteProperty -Name StdOut -Value (New-Object System.Collections.Generic.List[string]) -Force | Out-Null
        $Process | Add-Member -MemberType NoteProperty -Name StdErr -Value (New-Object System.Collections.Generic.List[string]) -Force | Out-Null

        # Start the process
        $Process.Start() | Out-Null

        $ProcessTimeout = 0
        $TimeoutInMilliseconds = $Timeout * 1000

        # Initialize string builders to collect output
        $StdOutBuffer = New-Object System.Text.StringBuilder
        $StdErrBuffer = New-Object System.Text.StringBuilder

        # Monitor the process execution and read output/error streams
        while (!$Process.HasExited -and $ProcessTimeout -lt $TimeoutInMilliseconds ) {
            # Read standard output to prevent buffer overflow
            while (!$Process.StandardOutput.EndOfStream -and $Process.StandardOutput.Peek() -ne -1) {
                $Char = $Process.StandardOutput.Read()
                if ($Char -ne -1) {
                    $ActualCharacter = [char]$Char
                    if ($ActualCharacter -eq "`n") {
                        # Add the completed line to the StdOut collection
                        $Process.StdOut.Add($StdOutBuffer.ToString())
                        $StdOutBuffer.Length = 0
                    } elseif ($ActualCharacter -ne "`r") {
                        # Append characters to the buffer, excluding carriage returns
                        $null = $StdOutBuffer.Append($ActualCharacter)
                    }
                }
            }

            # Read standard error to prevent buffer overflow
            while (!$Process.StandardError.EndOfStream -and $Process.StandardError.Peek() -ne -1) {
                $Char = $Process.StandardError.Read()
                if ($Char -ne -1) {
                    $ActualCharacter = [char]$Char
                    if ($ActualCharacter -eq "`n") {
                        # Add the completed line to the StdErr collection
                        $Process.StdErr.Add($StdErrBuffer.ToString())
                        $StdErrBuffer.Length = 0
                    } elseif ($ActualCharacter -ne "`r") {
                        # Append characters to the buffer, excluding carriage returns
                        $null = $StdErrBuffer.Append($ActualCharacter)
                    }
                }
            }

            # Sleep briefly before polling again to avoid excessive CPU usage
            Start-Sleep -Milliseconds 100
            $ProcessTimeout = $ProcessTimeout + 10
        }

        # Add final buffered content to StdOut and StdErr properties
        if ($StdOutBuffer.Length -gt 0) {
            $Process.StdOut.Add($StdOutBuffer.ToString())
        }

        if ($StdErrBuffer.Length -gt 0) {
            $Process.StdErr.Add($StdErrBuffer.ToString())
        }

        try {
            # Handle timeout scenarios
            if ($ProcessTimeout -ge 300000) {
                throw (New-Object System.ServiceProcess.TimeoutException("The process has timed out."))
            }

            # Wait for the process to exit within the remaining timeout period
            $TimeoutRemaining = 300000 - $ProcessTimeout
            if (!$Process.WaitForExit($TimeoutRemaining)) {
                throw (New-Object System.ServiceProcess.TimeoutException("The process has timed out."))
            }
        } catch {
            # Set the global exit code and dispose of the process
            if ($Process.ExitCode) {
                $GLOBAL:LASTEXITCODE = $Process.ExitCode
            } else {
                $GLOBAL:LASTEXITCODE = 1
            }

            # Dispose of the process to release resources
            if ($Process) {
                $Process.Dispose()
            }

            throw $_
        }

        # Final read of output and error streams to ensure all data is captured
        while (!$Process.StandardOutput.EndOfStream) {
            $Char = $Process.StandardOutput.Read()
            if ($Char -ne -1) {
                $ActualCharacter = [char]$Char
                if ($ActualCharacter -eq "`n") {
                    # Add the completed line to the StdOut collection
                    $Process.StdOut.Add($StdOutBuffer.ToString())
                    $StdOutBuffer.Length = 0
                } elseif ($ActualCharacter -ne "`r") {
                    # Append characters to the buffer, excluding carriage returns
                    $null = $StdOutBuffer.Append($ActualCharacter)
                }
            }
        }

        while (!$Process.StandardError.EndOfStream) {
            $Char = $Process.StandardError.Read()
            if ($Char -ne -1) {
                $ActualCharacter = [char]$Char
                if ($ActualCharacter -eq "`n") {
                    # Add the completed line to the StdErr collection
                    $Process.StdErr.Add($StdErrBuffer.ToString())
                    $StdErrBuffer.Length = 0
                } elseif ($ActualCharacter -ne "`r") {
                    # Append characters to the buffer, excluding carriage returns
                    $null = $StdErrBuffer.Append($ActualCharacter)
                }
            }
        }

        if ($Process.StdErr.Count -gt 0) {
            # Set the global exit code
            if ($Process.ExitCode -or $Process.ExitCode -eq 0) {
                $GLOBAL:LASTEXITCODE = $Process.ExitCode
            }

            # Dispose of the process
            if ($Process) {
                $Process.Dispose()
            }

            # Log errors from the standard error stream
            $Process.StdErr | Write-Error -Category "FromStdErr"
        }

        # Return the standard output if available
        if ($Process.StdOut.Count -gt 0) {
            $Process.StdOut
        }

        # Set the global exit code
        if ($Process.ExitCode -or $Process.ExitCode -eq 0) {
            $GLOBAL:LASTEXITCODE = $Process.ExitCode
        }

        # Dispose of the process
        if ($Process) {
            $Process.Dispose()
        }
    }

    function Test-IsDomainJoined {
        [CmdletBinding()]
        param()

        # Check the PowerShell version to determine the appropriate cmdlet to use
        if ($PSVersionTable.PSVersion.Major -lt 3) {
            return $(Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
        } else {
            return $(Get-CimInstance -Class Win32_ComputerSystem).PartOfDomain
        }
    }

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

    #endregion

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    #region Validate Environment

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

    try {
        # Check if the machine is joined to a domain
        $IsDomainJoined = Test-IsDomainJoined -ErrorAction Stop
    } catch {
        # Log an error if unable to determine domain membership
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the machine $env:COMPUTERNAME is joined to a domain."
        exit 1
    }

    if ($IsDomainJoined) {
        try {
            # Check if the machine is a domain controller
            $IsDomainController = Test-IsDomainController -ErrorAction Stop
        } catch {
            # Log an error if unable to determine if the machine is a domain controller
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Unable to determine if the machine $env:COMPUTERNAME is a domain controller."
            exit 1
        }

        if (!$IsDomainController) {
            # Exit if the machine is domain-joined but not a domain controller
            Write-Host -Object "[Error] This device is joined to a domain but is not the domain controller."
            Write-Host -Object "[Error] This script only supports running on the Domain Controller or on non-domain joined machines."
            exit 1
        }

        # Ensure the Active Directory PowerShell module is imported
        try {
            Write-Host -Object "Verifying the Active Directory PowerShell module is imported."

            # Import the module if not already imported
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
    }

    #endregion

    #region Set Domain Policy
    # Check if the machine is domain-joined and is a domain controller
    if ($IsDomainJoined -and $IsDomainController) {
        Write-Host -Object "`nThis machine is joined to the domain and is a domain controller. The default domain password policy will be configured."

        #region Retrieve Policy
        try {
            # Retrieve the current default domain password policy
            Write-Host -Object "Retrieving the current password policy."
            $CurrentPolicy = Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop
        } catch {
            # Log an error if unable to retrieve the policy
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to retrieve the current default domain password policy."
            exit 1
        }
        #endregion

        #region Check for Conflicts

        # Ensure the lockout duration is greater than or equal to the reset lockout time
        if ($LockoutDurationInMinutes -and !($ResetLockoutAfterMinutes -or $ResetLockoutAfterMinutes -eq 0) -and $LockoutDurationInMinutes -lt
            $CurrentPolicy.LockoutObservationWindow.TotalMinutes) {
            Write-Host -Object "[Error] The lockout duration specified as '$LockoutDurationInMinutes' minutes is less than the current reset lockout time of '$($CurrentPolicy.LockoutObservationWindow.TotalMinutes)' minutes."
            Write-Host -Object "[Error] The lockout duration must be greater than or equal to the 'Reset Lockout After Minutes' value."
            Write-Host -Object "[Error] Unless the lockout duration is set to '0' for 'Until administrator unlocks it'."
            exit 1
        }

        # Ensure the current lockout duration is valid compared to the reset lockout time
        if (!($LockoutDurationInMinutes -or $LockoutDurationInMinutes -eq 0) -and ($ResetLockoutAfterMinutes -or $ResetLockoutAfterMinutes -eq 0) -and
            $CurrentPolicy.LockoutDuration.TotalMinutes -ne "0" -and $CurrentPolicy.LockoutDuration.TotalMinutes -lt $ResetLockoutAfterMinutes) {
            Write-Host -Object "[Error] The current lockout duration of '$($CurrentPolicy.LockoutDuration.TotalMinutes)' minutes is less than the reset lockout time specified as '$ResetLockoutAfterMinutes' minutes."
            Write-Host -Object "[Error] The lockout duration must be greater than or equal to the 'Reset Lockout After Minutes' value."
            Write-Host -Object "[Error] Unless the lockout duration is set to '0' for 'Until administrator unlocks it'."
            exit 1
        }

        # Ensure max login attempts are specified if lockout duration or reset lockout time is set
        if ($CurrentPolicy.LockoutThreshold -eq 0 -and !$MaxLoginAttempts -and ($ResetLockoutAfterMinutes -or $LockoutDurationInMinutes -or
                $LockoutDurationInMinutes -eq 0)) {
            Write-Host -Object "[Error] The max login attempts are currently set to unlimited ($($CurrentPolicy.LockoutThreshold)), but you also specified a lockout duration or reset lockout time."
            Write-Host -Object "[Error] You must specify a maximum number of attempts to set the reset lockout after value and lockout duration."
            exit 1
        }

        # Ensure the minimum password age is less than the maximum password age
        if (($MaxPassAge) -and !($MinPassAge -or $MinPassAge -eq 0) -and $MaxPassAge -le $CurrentPolicy.MinPasswordAge.TotalDays) {
            Write-Host -Object "[Error] The current minimum password age '$($CurrentPolicy.MinPasswordAge.TotalDays)' is greater than or equal to the specified maximum password age '$MaxPassAge'."
            Write-Host -Object "[Error] The minimum password age must be less than the maximum password age."
            Write-Host -Object "[Error] Unless the maximum password age is set to '0' for no expiration or the minimum is set to '0' to allow password changes at any time."
            exit 1
        }

        # Ensure the specified minimum password age is valid compared to the current maximum password age
        if (!($MaxPassAge -or $MaxPassAge -eq 0) -and ($MinPassAge) -and $CurrentPolicy.MaxPasswordAge.TotalDays -le $MinPassAge) {
            Write-Host -Object "[Error] The specified minimum password age '$MinPassAge' is greater than or equal to the current maximum password age '$($CurrentPolicy.MaxPasswordAge.TotalDays)'."
            Write-Host -Object "[Error] The minimum password age must be less than the maximum password age."
            Write-Host -Object "[Error] Unless the maximum password age is set to '0' for no expiration or the minimum is set to '0' to allow password changes at any time."
            exit 1
        }

        #endregion

        #region Apply changes
        # Initialize a hashtable to store the modifications to the password policy
        $PasswordPolicyModifications = @{}
        $PasswordPolicyModifications["Identity"] = $CurrentPolicy.DistinguishedName

        # Check and modify the "Number of Passwords to Remember" if necessary
        if (($NumberOfPassToRemember -or $NumberOfPassToRemember -eq 0) -and $NumberOfPassToRemember -eq $CurrentPolicy.PasswordHistoryCount) {
            Write-Host -Object "The number of passwords to remember is already set to '$NumberOfPassToRemember'."
        } elseif ($NumberOfPassToRemember -or $NumberOfPassToRemember -eq 0) {
            Write-Host -Object "Modifying the number of passwords to remember from '$($CurrentPolicy.PasswordHistoryCount)' to '$NumberOfPassToRemember'."
            $PasswordPolicyModifications["PasswordHistoryCount"] = $NumberOfPassToRemember
        }

        # Check and modify the "Maximum Password Age" if necessary
        if (($MaxPassAge -or $MaxPassAge -eq 0) -and $MaxPassAge -eq $CurrentPolicy.MaxPasswordAge.TotalDays) {
            Write-Host -Object "The maximum password age is already set to '$MaxPassAge'."
        } elseif ($MaxPassAge -or $MaxPassAge -eq 0) {
            Write-Host -Object "Modifying the maximum password age from '$($CurrentPolicy.MaxPasswordAge.TotalDays)' to '$MaxPassAge'."
            $PasswordPolicyModifications["MaxPasswordAge"] = New-TimeSpan -Days $MaxPassAge
        }

        # Check and modify the "Minimum Password Age" if necessary
        if (($MinPassAge -or $MinPassAge -eq 0) -and $MinPassAge -eq $CurrentPolicy.MinPasswordAge.TotalDays) {
            Write-Host -Object "The minimum password age is already set to '$MinPassAge'."
        } elseif ($MinPassAge -or $MinPassAge -eq 0) {
            Write-Host -Object "Modifying the minimum password age from '$($CurrentPolicy.MinPasswordAge.TotalDays)' to '$MinPassAge'."
            $PasswordPolicyModifications["MinPasswordAge"] = New-TimeSpan -Days $MinPassAge
        }

        # Check and modify the "Minimum Password Length" if necessary
        if (($MinPassLength -or $MinPassLength -eq 0) -and $MinPassLength -eq $CurrentPolicy.MinPasswordLength) {
            Write-Host -Object "The minimum password length is already set to '$MinPassLength'."
        } elseif ($MinPassLength -or $MinPassLength -eq 0) {
            Write-Host -Object "Modifying the minimum password length from '$($CurrentPolicy.MinPasswordLength)' to '$MinPassLength'."
            $PasswordPolicyModifications["MinPasswordLength"] = $MinPassLength
        }

        # Check and modify the "Password Complexity" if necessary
        if ($PassComplexityAction -and $CurrentPolicy.ComplexityEnabled -eq $PassComplexity) {
            Write-Host -Object "The password complexity is already set to '$($PassComplexityAction)'."
        } elseif ($PassComplexityAction) {
            Write-Host -Object "Modifying the password complexity value from '$($CurrentPolicy.ComplexityEnabled)' to '$PassComplexity'."
            $PasswordPolicyModifications["ComplexityEnabled"] = $PassComplexity
        }

        # Check and modify the "Lockout Duration" if necessary
        if (($LockoutDurationInMinutes -or $LockoutDurationInMinutes -eq 0) -and $LockoutDurationInMinutes -eq $CurrentPolicy.LockoutDuration.TotalMinutes) {
            Write-Host -Object "The lockout duration is already set to '$LockoutDurationInMinutes' minutes."
        } elseif ($LockoutDurationInMinutes -or $LockoutDurationInMinutes -eq 0) {
            Write-Host -Object "Modifying the lockout duration from '$($CurrentPolicy.LockoutDuration.TotalMinutes)' to '$LockoutDurationInMinutes' minutes."
            $PasswordPolicyModifications["LockoutDuration"] = New-TimeSpan -Minutes $LockoutDurationInMinutes
        }

        # Check and modify the "Maximum Login Attempts" if necessary
        if (($MaxLoginAttempts -or $MaxLoginAttempts -eq 0) -and $MaxLoginAttempts -eq $CurrentPolicy.LockoutThreshold) {
            Write-Host -Object "The maximum login attempts are already set to '$MaxLoginAttempts'."
        } elseif ($MaxLoginAttempts -or $MaxLoginAttempts -eq 0) {
            Write-Host -Object "Modifying the maximum login attempts from '$($CurrentPolicy.LockoutThreshold)' to '$MaxLoginAttempts'."
            $PasswordPolicyModifications["LockoutThreshold"] = $MaxLoginAttempts
        }

        # Check and modify the "Reset Lockout After Minutes" if necessary
        if (($ResetLockoutAfterMinutes -or $ResetLockoutAfterMinutes -eq 0) -and $ResetLockoutAfterMinutes -eq $CurrentPolicy.LockoutObservationWindow.TotalMinutes) {
            Write-Host -Object "The reset lockout time is already set to '$ResetLockoutAfterMinutes'."
        } elseif ($ResetLockoutAfterMinutes -or $ResetLockoutAfterMinutes -eq 0) {
            Write-Host -Object "Modifying the reset lockout time value from '$($CurrentPolicy.LockoutObservationWindow.TotalMinutes)' to '$ResetLockoutAfterMinutes'."
            $PasswordPolicyModifications["LockoutObservationWindow"] = New-TimeSpan -Minutes $ResetLockoutAfterMinutes
        }

        # Exit if no changes are needed
        if ($PasswordPolicyModifications.Count -le 1) {
            Write-Host -Object "`n[Alert] The current password policy already has all of your requested changes. No update needed."
            exit $ExitCode
        }

        # Apply the changes to the default domain policy
        try {
            Write-Host -Object "`nApplying the requested password policy changes to the default domain policy."
            Set-ADDefaultDomainPasswordPolicy @PasswordPolicyModifications -ErrorAction Stop
            Write-Host -Object "Successfully applied the update."
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to update the current password policy."
            exit 1
        }

        # Handle group policy update if necessary
        if (!$InitiateGpupdateIfNecessary) {
            Write-Host -Object "`n[Warning] 'Initiate gpupdate If Necessary' was not selected. These changes will take effect on the next group policy refresh."
        }

        if ($InitiateGpupdateIfNecessary) {
            try {
                Write-Host -Object "`nInitiating a gpupdate to make the changes take immediate effect."
                Invoke-LegacyConsoleTool -FilePath "$env:SystemRoot\System32\gpupdate.exe" -ArgumentList "/wait:120" -ErrorAction Stop

                if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                    throw "Exit code does not indicate success."
                }

                Write-Host -Object "Successfully updated group policy."
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to update group policy."
                exit 1
            }
        }

        # Exit with the appropriate exit code
        exit $ExitCode
        #endregion
    }
    #endregion

    #region Set Local Policy
    if (!$IsDomainJoined) {
        Write-Host -Object "`nThis machine is not joined to a domain. The local security policy will be configured."

        # Convert special values for maximum password age and lockout duration to their local security policy equivalents
        if ($MaxPassAge -eq 0) {
            Write-Host -Object "[Warning] Converting the maximum password age to -1, as that is how 0 is represented in the local security policy."
            $MaxPassAge = -1
        }

        if ($LockoutDurationInMinutes -eq 0) {
            Write-Host -Object "[Warning] Converting the lockout duration to -1, as that is how 0 is represented in the local security policy."
            $LockoutDurationInMinutes = -1
        }

        try {
            # Retrieve the current security policy and export it to a temporary file
            Write-Host -Object "Retrieving the current security policy."
            $LocalPolicyFile = New-TemporaryFile -ErrorAction Stop
            Invoke-LegacyConsoleTool -FilePath "$env:SystemRoot\System32\SecEdit.exe" -ArgumentList "/export /cfg `"$($LocalPolicyFile.FullName)`" /areas SECURITYPOLICY" -ErrorAction Stop
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                throw "Exit code does not indicate success."
            }
            Write-Host -Object ""

            # Read the content of the exported security policy file
            $CurrentPasswordPolicy = Get-Content -Path $LocalPolicyFile.FullName -ErrorAction Stop
        } catch {
            # Handle errors during the retrieval of the current security policy
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to retrieve the current security policy. Unable to continue."
            exit 1
        }

        try {
            #region - Retrieve Policy
            $ErrorActionPreference = "Stop"
            Write-Host -Object "Parsing the current security policy."

            # Parse the current password policy values from the exported file
            if (![string]::IsNullOrWhiteSpace(($CurrentPasswordPolicy | Where-Object { $_ -match "^PasswordHistorySize" }))) {
                [int]$CurrentPassHistory = ($CurrentPasswordPolicy | Where-Object { $_ -match "^PasswordHistorySize" }) -replace "[^0-9-]"
            } elseif ($NumberOfPassToRemember -or $NumberOfPassToRemember -eq 0) {
                # Add a default entry for PasswordHistorySize if it doesn't exist
                $IndexOfSystemAccess = $CurrentPasswordPolicy.IndexOf("[System Access]")
                $CurrentPasswordPolicy = $CurrentPasswordPolicy[0..$IndexOfSystemAccess] +
                "PasswordHistorySize =" + $CurrentPasswordPolicy[($IndexOfSystemAccess + 1)..($CurrentPasswordPolicy.Length - 1)]
            }

            if (![string]::IsNullOrWhiteSpace(($CurrentPasswordPolicy | Where-Object { $_ -match "^MaximumPasswordAge" }))) {
                [int]$CurrentMaxPassAge = ($CurrentPasswordPolicy | Where-Object { $_ -match "^MaximumPasswordAge" }) -replace "[^0-9-]"
            } elseif ($MaxPassAge -or $MaxPassAge -eq 0) {
                # Add a default entry for MaximumPasswordAge if it doesn't exist
                $IndexOfSystemAccess = $CurrentPasswordPolicy.IndexOf("[System Access]")
                $CurrentPasswordPolicy = $CurrentPasswordPolicy[0..$IndexOfSystemAccess] + "MaximumPasswordAge =" +
                $CurrentPasswordPolicy[($IndexOfSystemAccess + 1)..($CurrentPasswordPolicy.Length - 1)]
            }

            if (![string]::IsNullOrWhiteSpace(($CurrentPasswordPolicy | Where-Object { $_ -match "^MinimumPasswordAge" }))) {
                [int]$CurrentMinPassAge = ($CurrentPasswordPolicy | Where-Object { $_ -match "^MinimumPasswordAge" }) -replace "[^0-9-]"
            } elseif ($MinPassAge -or $MinPassAge -eq 0) {
                # Add a default entry for MinimumPasswordAge if it doesn't exist
                $IndexOfSystemAccess = $CurrentPasswordPolicy.IndexOf("[System Access]")
                $CurrentPasswordPolicy = $CurrentPasswordPolicy[0..$IndexOfSystemAccess] + "MinimumPasswordAge =" +
                $CurrentPasswordPolicy[($IndexOfSystemAccess + 1)..($CurrentPasswordPolicy.Length - 1)]
            }

            if (![string]::IsNullOrWhiteSpace(($CurrentPasswordPolicy | Where-Object { $_ -match "^MinimumPasswordLength" }))) {
                [int]$CurrentMinPassLength = ($CurrentPasswordPolicy | Where-Object { $_ -match "^MinimumPasswordLength" }) -replace "[^0-9-]"
            } elseif ($MinPassLength -or $MinPassLength -eq 0) {
                # Add a default entry for MinimumPasswordLength if it doesn't exist
                $IndexOfSystemAccess = $CurrentPasswordPolicy.IndexOf("[System Access]")
                $CurrentPasswordPolicy = $CurrentPasswordPolicy[0..$IndexOfSystemAccess] + "MinimumPasswordLength =" +
                $CurrentPasswordPolicy[($IndexOfSystemAccess + 1)..($CurrentPasswordPolicy.Length - 1)]
            }

            if (![string]::IsNullOrWhiteSpace(($CurrentPasswordPolicy | Where-Object { $_ -match "^PasswordComplexity" }))) {
                [boolean]$CurrentPasswordComplexity = [int](($CurrentPasswordPolicy | Where-Object { $_ -match "^PasswordComplexity" }) -replace "[^0-9-]")
            } elseif ($PassComplexityAction) {
                # Add a default entry for PasswordComplexity if it doesn't exist
                $IndexOfSystemAccess = $CurrentPasswordPolicy.IndexOf("[System Access]")
                $CurrentPasswordPolicy = $CurrentPasswordPolicy[0..$IndexOfSystemAccess] + "PasswordComplexity =" +
                $CurrentPasswordPolicy[($IndexOfSystemAccess + 1)..($CurrentPasswordPolicy.Length - 1)]
            }

            if (![string]::IsNullOrWhiteSpace(($CurrentPasswordPolicy | Where-Object { $_ -match "^LockoutDuration" }))) {
                [int]$CurrentLockoutDurationInMinutes = ($CurrentPasswordPolicy | Where-Object { $_ -match "^LockoutDuration" }) -replace "[^0-9-]"
            } elseif ($LockoutDurationInMinutes -or $LockoutDurationInMinutes -eq 0) {
                # Add a default entry for LockoutDuration if it doesn't exist
                $IndexOfSystemAccess = $CurrentPasswordPolicy.IndexOf("[System Access]")
                $CurrentPasswordPolicy = $CurrentPasswordPolicy[0..$IndexOfSystemAccess] + "LockoutDuration =" +
                $CurrentPasswordPolicy[($IndexOfSystemAccess + 1)..($CurrentPasswordPolicy.Length - 1)]
            }

            if (![string]::IsNullOrWhiteSpace(($CurrentPasswordPolicy | Where-Object { $_ -match "^LockoutBadCount" }))) {
                [int]$CurrentMaxLoginAttempts = ($CurrentPasswordPolicy | Where-Object { $_ -match "^LockoutBadCount" }) -replace "[^0-9-]"
            } elseif ($MaxLoginAttempts -or $MaxLoginAttempts -eq 0) {
                # Add a default entry for LockoutBadCount if it doesn't exist
                $IndexOfSystemAccess = $CurrentPasswordPolicy.IndexOf("[System Access]")
                $CurrentPasswordPolicy = $CurrentPasswordPolicy[0..$IndexOfSystemAccess] + "LockoutBadCount =" +
                $CurrentPasswordPolicy[($IndexOfSystemAccess + 1)..($CurrentPasswordPolicy.Length - 1)]
            }

            if (![string]::IsNullOrWhiteSpace(($CurrentPasswordPolicy | Where-Object { $_ -match "^ResetLockoutCount" }))) {
                [int]$CurrentResetLockoutAfterMinutes = ($CurrentPasswordPolicy | Where-Object { $_ -match "^ResetLockoutCount" }) -replace "[^0-9-]"
            } elseif ($ResetLockoutAfterMinutes -or $ResetLockoutAfterMinutes -eq 0) {
                # Add a default entry for ResetLockoutCount if it doesn't exist
                $IndexOfSystemAccess = $CurrentPasswordPolicy.IndexOf("[System Access]")
                $CurrentPasswordPolicy = $CurrentPasswordPolicy[0..$IndexOfSystemAccess] + "ResetLockoutCount =" +
                $CurrentPasswordPolicy[($IndexOfSystemAccess + 1)..($CurrentPasswordPolicy.Length - 1)]
            }
        } catch {
            # Handle errors during the parsing of the current security policy
            $ErrorActionPreference = "Continue"
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to parse the current security policy. Unable to continue."
            exit 1
        }

        $ErrorActionPreference = "Continue"

        #endregion

        #region Check for Conflicts

        # Ensure the lockout duration is greater than or equal to the reset lockout time
        if ($LockoutDurationInMinutes -and $LockoutDurationInMinutes -ne "-1" -and !($ResetLockoutAfterMinutes -or $ResetLockoutAfterMinutes -eq 0) -and
            $CurrentResetLockoutAfterMinutes -and $LockoutDurationInMinutes -lt $CurrentResetLockoutAfterMinutes) {
            Write-Host -Object "[Error] The lockout duration specified '$LockoutDurationInMinutes' minutes is less than the current reset lockout time of '$($CurrentResetLockoutAfterMinutes)' minutes."
            Write-Host -Object "[Error] The lockout duration must be greater than or equal to the 'Reset Lockout After Minutes' value."
            Write-Host -Object "[Error] Unless the lockout duration is set to '0' for 'Until administrator unlocks it'."
            exit 1
        }

        # Ensure the current lockout duration is valid compared to the reset lockout time
        if (!$LockoutDurationInMinutes -and ($ResetLockoutAfterMinutes -or $ResetLockoutAfterMinutes -eq 0) -and
            $CurrentLockoutDurationInMinutes -and $CurrentLockoutDurationInMinutes -ne "-1" -and $CurrentLockoutDurationInMinutes -lt $ResetLockoutAfterMinutes) {
            Write-Host -Object "[Error] The current lockout duration of '$CurrentLockoutDurationInMinutes' minutes is less than the reset lockout time specified of '$ResetLockoutAfterMinutes' minutes."
            Write-Host -Object "[Error] The lockout duration must be greater than or equal to the 'Reset Lockout After Minutes' value."
            Write-Host -Object "[Error] Unless the lockout duration is set to '0' for 'Until administrator unlocks it'."
            exit 1
        }

        # Ensure max login attempts are specified if lockout duration or reset lockout time is set
        if (($CurrentMaxLoginAttempts -eq 0 -or !$CurrentMaxLoginAttempts) -and !$MaxLoginAttempts -and ($ResetLockoutAfterMinutes -or $LockoutDurationInMinutes)) {
            Write-Host -Object "[Error] The max login attempts are currently set to unlimited, but you also specified a lockout duration or reset lockout time."
            Write-Host -Object "[Error] You must specify a maximum number of attempts to set the reset lockout after value and lockout duration."
            exit 1
        }

        # Ensure the minimum password age is less than the maximum password age
        if (($MaxPassAge) -and !($MinPassAge -or $MinPassAge -eq 0) -and $CurrentMinPassAge -and $MaxPassAge -ne "-1" -and $MaxPassAge -le $CurrentMinPassAge) {
            Write-Host -Object "[Error] The current minimum password age '$CurrentMinPassAge' is greater than or equal to the specified maximum password age '$MaxPassAge'."
            Write-Host -Object "[Error] The minimum password age must be less than the maximum password age."
            Write-Host -Object "[Error] Unless the maximum password age is set to '0' for no expiration or the minimum is set to '0' to allow password changes at any time."
            exit 1
        }

        # Ensure the specified minimum password age is valid compared to the current maximum password age
        if (!($MaxPassAge -or $MaxPassAge -eq 0) -and ($MinPassAge) -and $CurrentMaxPassAge -and $CurrentMaxPassAge -ne "-1" -and $CurrentMaxPassAge -le $MinPassAge) {
            Write-Host -Object "[Error] The specified minimum password age '$MinPassAge' is greater than or equal to the current maximum password age '$CurrentMaxPassAge'."
            Write-Host -Object "[Error] The minimum password age must be less than the maximum password age."
            Write-Host -Object "[Error] Unless the maximum password age is set to '0' for no expiration or the minimum is set to '0' to allow password changes at any time."
            exit 1
        }

        #endregion

        #region - Apply Changes
        # Check and update the "Number of Passwords to Remember" setting
        Write-Host -Object "Creating a configuration file with your requested password policy changes."
        if (($NumberOfPassToRemember -or $NumberOfPassToRemember -eq 0) -and $CurrentPassHistory -eq $NumberOfPassToRemember) {
            Write-Host -Object "The number of passwords to remember is already set to '$NumberOfPassToRemember'."
        } elseif ($NumberOfPassToRemember -or $NumberOfPassToRemember -eq 0) {
            Write-Host -Object "Modifying the number of passwords to remember from '$CurrentPassHistory' to '$NumberOfPassToRemember'."

            $CurrentPasswordPolicy = $CurrentPasswordPolicy -replace '^PasswordHistorySize.*', "PasswordHistorySize = $NumberOfPassToRemember"
            $NeedToUpdateSecPolicy = $True
        }

        # Check and update the "Maximum Password Age" setting
        if (($MaxPassAge -or $MaxPassAge -eq 0) -and $CurrentMaxPassAge -eq $MaxPassAge) {
            Write-Host -Object "The maximum password age is already set to '$MaxPassAge'."
        } elseif ($MaxPassAge -or $MaxPassAge -eq 0) {
            Write-Host -Object "Modifying the maximum password age from '$CurrentMaxPassAge' to '$MaxPassAge'."

            $CurrentPasswordPolicy = $CurrentPasswordPolicy -replace '^MaximumPasswordAge.*', "MaximumPasswordAge = $MaxPassAge"
            $NeedToUpdateSecPolicy = $True
        }

        # Check and update the "Minimum Password Age" setting
        if (($MinPassAge -or $MinPassAge -eq 0) -and $CurrentMinPassAge -eq $MinPassAge) {
            Write-Host -Object "The minimum password age is already set to '$MinPassAge'."
        } elseif ($MinPassAge -or $MinPassAge -eq 0) {
            Write-Host -Object "Modifying the minimum password age from '$CurrentMinPassAge' to '$MinPassAge'."

            $CurrentPasswordPolicy = $CurrentPasswordPolicy -replace '^MinimumPasswordAge.*', "MinimumPasswordAge = $MinPassAge"
            $NeedToUpdateSecPolicy = $True
        }

        # Check and update the "Minimum Password Length" setting
        if (($MinPassLength -or $MinPassLength -eq 0) -and $CurrentMinPassLength -eq $MinPassLength) {
            Write-Host -Object "The minimum password length is already set to '$MinPassLength'."
        } elseif ($MinPassLength -or $MinPassLength -eq 0) {
            Write-Host -Object "Modifying the minimum password length from '$CurrentMinPassLength' to '$MinPassLength'."

            $CurrentPasswordPolicy = $CurrentPasswordPolicy -replace '^MinimumPasswordLength.*', "MinimumPasswordLength = $MinPassLength"
            $NeedToUpdateSecPolicy = $True
        }

        # Check and update the "Password Complexity" setting
        if ($PassComplexityAction -and ![String]::IsNullOrEmpty($CurrentPasswordPolicy) -and $CurrentPasswordComplexity -eq $PassComplexity) {
            Write-Host -Object "The password complexity is already set to '$($PassComplexityAction)'."
        } elseif ($PassComplexityAction) {
            Write-Host -Object "Modifying the password complexity value from '$CurrentPasswordComplexity' to '$PassComplexity'."

            $CurrentPasswordPolicy = $CurrentPasswordPolicy -replace '^PasswordComplexity.*', "PasswordComplexity = $([int]$PassComplexity)"
            $NeedToUpdateSecPolicy = $True
        }

        # Check and update the "Lockout Duration" setting
        if (($LockoutDurationInMinutes -or $LockoutDurationInMinutes -eq 0) -and $CurrentLockoutDurationInMinutes -eq $LockoutDurationInMinutes) {
            Write-Host -Object "The account lockout duration is already set to '$LockoutDurationInMinutes'."
        } elseif ($LockoutDurationInMinutes -or $LockoutDurationInMinutes -eq 0) {
            Write-Host -Object "Modifying the account lockout duration from '$CurrentLockoutDurationInMinutes' minutes to '$LockoutDurationInMinutes' minutes."

            $CurrentPasswordPolicy = $CurrentPasswordPolicy -replace '^LockoutDuration.*', "LockoutDuration = $LockoutDurationInMinutes"
            $NeedToUpdateSecPolicy = $True
        }

        # Check and update the "Maximum Login Attempts" setting
        if (($MaxLoginAttempts -or $MaxLoginAttempts -eq 0) -and $CurrentMaxLoginAttempts -eq $MaxLoginAttempts) {
            Write-Host -Object "The maximum login attempts are already set to '$MaxLoginAttempts'."
        } elseif ($MaxLoginAttempts -or $MaxLoginAttempts -eq 0) {
            Write-Host -Object "Modifying the maximum login attempts from '$CurrentMaxLoginAttempts' to '$MaxLoginAttempts'."

            $CurrentPasswordPolicy = $CurrentPasswordPolicy -replace '^LockoutBadCount.*', "LockoutBadCount = $MaxLoginAttempts"
            $NeedToUpdateSecPolicy = $True
        }

        # Check and update the "Reset Lockout After Minutes" setting
        if (($ResetLockoutAfterMinutes -or $ResetLockoutAfterMinutes -eq 0) -and $CurrentResetLockoutAfterMinutes -eq $ResetLockoutAfterMinutes) {
            Write-Host -Object "The reset lockout time value is already set to '$ResetLockoutAfterMinutes' minutes."
        } elseif ($ResetLockoutAfterMinutes -or $ResetLockoutAfterMinutes -eq 0) {
            Write-Host -Object "Modifying the reset lockout time value from '$CurrentResetLockoutAfterMinutes' to '$ResetLockoutAfterMinutes' minutes."

            $CurrentPasswordPolicy = $CurrentPasswordPolicy -replace '^ResetLockoutCount.*', "ResetLockoutCount = $ResetLockoutAfterMinutes"
            $NeedToUpdateSecPolicy = $True
        }

        # Exit if no updates are required
        if (!$NeedToUpdateSecPolicy) {
            Write-Host -Object "`n[Alert] The current password policy already has all of your requested changes. No update needed."
            exit $ExitCode
        }

        try {
            # Save the updated security policy configuration to the temporary file
            $CurrentPasswordPolicy | Out-File -FilePath $LocalPolicyFile.FullName -Force -ErrorAction Stop
        } catch {
            # Log an error if the configuration file cannot be saved
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to save the updated configuration file."
            exit 1
        }

        try {
            # Validate the new configuration file using SecEdit.exe
            Write-Host -Object "Verifying the new configuration file."
            $Verification = Invoke-LegacyConsoleTool -FilePath "$env:SystemRoot\System32\SecEdit.exe" -ArgumentList "/validate `"$($LocalPolicyFile.FullName)`"" -ErrorAction Stop
            Write-Host -Object $Verification

            # Check if the validation process returned a non-zero exit code
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                throw "Exit code does not indicate success."
            }

            Write-Host -Object "Verification complete."
        } catch {
            # Log an error if the configuration file fails validation
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] The new configuration file is not compatible with SecEdit.exe."
            exit 1
        }

        try {
            # Apply the updated configuration file to the local security policy
            Write-Host -Object "`nApplying the updated configuration file to the security policy."

            try {
                # Create a temporary file to store the log for the security policy update
                $SecurityLog = New-TemporaryFile -ErrorAction Stop
            } catch {
                # Log an error if the temporary log file cannot be created
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to create the log file for the security policy update."
            }

            # Verify that the temporary log file was successfully created
            if (!(Test-Path -Path $SecurityLog.FullName -ErrorAction SilentlyContinue)) {
                Write-Host -Object "[Error] Unable to find the log file created for the security policy update."
                exit 1
            }

            # Define the arguments for the SecEdit.exe command to apply the updated security policy
            $SecurityPolicyArguments = @(
                "/configure"
                "/db"
                "`"$env:SystemRoot\security\local.sdb`""
                "/cfg"
                "`"$($LocalPolicyFile.FullName)`""
                "/log"
                "`"$($SecurityLog.FullName)`""
                "/overwrite"
                "/quiet"
            )

            # Invoke SecEdit.exe with the specified arguments to apply the security policy changes
            Invoke-LegacyConsoleTool -FilePath "$env:SystemRoot\System32\SecEdit.exe" -ArgumentList $SecurityPolicyArguments -ErrorAction Stop

            try {
                # Retrieve and display the contents of the log file generated by SecEdit.exe
                Get-Content -Path $SecurityLog.FullName -Encoding Oem -ErrorAction Stop | Where-Object { $_ }
            } catch {
                # Log an error if the log file contents cannot be retrieved
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to retrieve the log file contents."
                exit 1
            }

            # Check if the temporary log file exists and attempt to remove it
            if (Test-Path -Path $SecurityLog.FullName -ErrorAction SilentlyContinue) {
                try {
                    Remove-Item -Path $SecurityLog.FullName -ErrorAction Stop
                } catch {
                    # Log a warning if the log file could not be removed
                    Write-Host -Object "[Warning] $($_.Exception.Message)"
                    Write-Host -Object "[Warning] Failed to remove '$($SecurityLog.FullName)'."
                }
            }

            # Check if the application process returned a non-zero exit code
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                throw "Exit code does not indicate success."
            }

            Write-Host -Object "Successfully applied the update."
        } catch {
            # Log an error if the security policy update fails
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to update the security policy."
            exit 1
        }

        #endregion

        # Check if the temporary local policy file exists
        if (Test-Path -Path $($LocalPolicyFile.FullName) -PathType Leaf -ErrorAction SilentlyContinue) {
            try {
                # Attempt to remove the temporary file
                Remove-Item -Path $($LocalPolicyFile.FullName) -ErrorAction Stop
            } catch {
                # Log a warning if the file could not be removed
                Write-Host -Object "[Warning] $($_.Exception.Message)"
                Write-Host -Object "[Warning] Failed to remove '$($LocalPolicyFile.FullName)'."
            }
        }

        # Notify the user that updating group policy is not required for non-domain joined machines
        if ($InitiateGpupdateIfNecessary) {
            Write-Host -Object "`nUpdating group policy is not necessary for non-domain joined computers."
        }

        # Exit the script with the current exit code
        exit $ExitCode
    }
    #endregion

    exit $ExitCode
}
end {
    
    
    
}