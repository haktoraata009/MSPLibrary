#Requires -Version 5.1

<#
.SYNOPSIS
    Enable or disable user logon and logoff auditing. This affects event logging for user logons and logoffs in the Security event log.

    Logon Success Event IDs: 4624, 4648, 4675
    Logon Failure Event IDs: 4625
    Logoff Success Event IDs: 4634, 4647
.DESCRIPTION
    Enable or disable user logon and logoff auditing. This affects event logging for user logons and logoffs in the Security event log.

    Logon Success Event IDs: 4624, 4648, 4675
    Logon Failure Event IDs: 4625
    Logoff Success Event IDs: 4634, 4647

.PARAMETER -AuditLogonAction "Enable"
    Choose whether to enable or disable the auditing of user logons. This will enable or disable success and failure events for user logons.
.PARAMETER -AuditLogoffAction "Enable"
    Choose whether to enable or disable the auditing of user logoffs. This will enable or disable success events for user logoffs.

.EXAMPLE
    -AuditLogonAction "Enable" -AuditLogoffAction "Enable"

    [Info] Enabling user logon auditing.
    The command was successfully executed.
    [Info] Successfully enabled user logon auditing.

    [Info] Enabling user logoff auditing.
    The command was successfully executed.
    [Info] Successfully enabled user logoff auditing.

    ### Previous auditing settings: ###

    LogonAuditing LogoffAuditing
    ------------- --------------
    Disabled      Disabled

    ### Current auditing settings: ###

    LogonAuditing LogoffAuditing
    ------------- --------------
    Enabled       Enabled

.EXAMPLE
    -AuditLogonAction "Enable" -AuditLogoffAction "Disable"

    [Info] User logon auditing is already enabled.

    [Info] Disabling user logoff auditing.
    The command was successfully executed.
    [Info] Successfully disabled user logoff auditing.

    ### Previous auditing settings: ###

    LogonAuditing LogoffAuditing
    ------------- --------------
    Enabled       Enabled

    ### Current auditing settings: ###

    LogonAuditing LogoffAuditing
    ------------- --------------
    Enabled       Disabled

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$AuditLogonAction,
    [Parameter()]
    [string]$AuditLogoffAction
)

begin {
    Write-Host ""

    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Import script variables
    if ($env:AuditLogonAction) { $AuditLogonAction = $env:AuditLogonAction }
    if ($env:AuditLogoffAction) { $AuditLogoffAction = $env:AuditLogoffAction }

    # Validate audit logon action
    if ($AuditLogonAction) {
        $AuditLogonAction = $AuditLogonAction.Trim()

        if ([string]::IsNullOrWhiteSpace($AuditLogonAction)) {
            Write-Host -Object "[Error] The 'Audit Logon Action' parameter is empty. Please provide either 'Enable' or 'Disable' or leave it blank."
            exit 1
        }

        if ($AuditLogonAction -notin @("Enable", "Disable")) {
            Write-Host -Object "[Error] '$AuditLogonAction' is an invalid value for 'Audit Logon Action'. Please provide either 'Enable' or 'Disable' or leave it blank."
            exit 1
        }
    }

    # Validate audit logoff action
    if ($AuditLogoffAction) {
        $AuditLogoffAction = $AuditLogoffAction.Trim()

        if ([string]::IsNullOrWhiteSpace($AuditLogoffAction)) {
            Write-Host -Object "[Error] The 'Audit Logoff Action' parameter is empty. Please provide either 'Enable' or 'Disable' or leave it blank."
            exit 1
        }

        if ($AuditLogoffAction -notin @("Enable", "Disable")) {
            Write-Host -Object "[Error] '$AuditLogoffAction' is an invalid value for 'Audit Logoff Action'. Please provide either 'Enable' or 'Disable' or leave it blank."
            exit 1
        }
    }

    # Error if neither option is provided
    if (-not ($AuditLogonAction -or $AuditLogoffAction)) {
        Write-Host -Object "[Error] At least one of 'Audit Logon Action' or 'Audit Logoff Action' must be provided. Please provide 'Enable' or 'Disable' for at least one of these parameters."
        exit 1
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

    # Function to invoke legacy console tools with proper handling of encoding
    function Invoke-LegacyConsoleTool {
        [CmdletBinding()]
        param(
            [Parameter()]
            [String]$FilePath,
            [Parameter()]
            [String[]]$ArgumentList,
            [Parameter()]
            [Int]$Timeout = 30,
            [Parameter()]
            [System.Text.Encoding]$Encoding
        )

        # Validate that the file path is not null or empty
        if ([String]::IsNullOrWhiteSpace($FilePath)) {
            throw (New-Object System.ArgumentNullException("You must provide a file path to the legacy tool you are trying to use."))
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
                        $null = $StdOutBuffer.Clear()
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
                        $null = $StdErrBuffer.Clear()
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
                    $null = $StdOutBuffer.Clear()
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
                    $null = $StdErrBuffer.Clear()
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
            default {$LogonAuditingStatus = "Unknown ($_)" }
        }

        # The setting for logoff auditing is stored at index 24 of the audit policy registry key
        switch ($AuditPolicy[24]) {
            0 { $LogoffAuditingStatus = "Disabled"}
            2 { $LogoffAuditingStatus = "Enabled (Failure only)" }
            {$_ -in @(1, 3 )} { $LogoffAuditingStatus = "Enabled" }
            default {$LogoffAuditingStatus = "Unknown ($_)" }
        }

        # Return a custom object with the logon and logoff auditing statuses
        return [PSCustomObject]@{
            LogonAuditing = $LogonAuditingStatus
            LogoffAuditing = $LogoffAuditingStatus
        }
    }

    # Function to test if the current session is elevated
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
        Write-Host -Object "[Error] The user '$env:Username' is not running this script in an elevated session. Please run this script as System or in an elevated session."
        exit 1
    }

    # Error if not running as SYSTEM
    if (-not (Test-IsSystem)) {
        Write-Host -Object "[Error] This script must be run as the SYSTEM account."
        exit 1
    }

    # Retrieve the starting audit policy from the registry
    try {
        $StartingAuditPolicy = Get-LogonLogoffAuditingStatus -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] Unable to retrieve the audit policy from the registry. Ensure that the script is run with sufficient permissions."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Initialize the starting and current audit policies for logon and logoff
    $StartingLogonAuditPolicy, $CurrentLogonAuditPolicy = $StartingAuditPolicy.LogonAuditing
    $StartingLogoffAuditPolicy, $CurrentLogoffAuditPolicy = $StartingAuditPolicy.LogoffAuditing

    # Initialize ChangesMade variable
    $ChangesMade = $false

    # Define the GUIDs for the logon and logoff subcategories
    $LogonGuid = "{0CCE9215-69AE-11D9-BED3-505054503030}"
    $LogoffGuid = "{0CCE9216-69AE-11D9-BED3-505054503030}"

    switch ($AuditLogonAction) {
        # If chosen, enable logon auditing
        "Enable" {
            # Check if logon auditing is already enabled
            if ($StartingLogonAuditPolicy -eq "Enabled") {
                Write-Host -Object "[Info] User logon auditing is already enabled."
            }
            else {
                Write-Host -Object "[Info] Enabling user logon auditing."
                try {
                    Invoke-LegacyConsoleTool -FilePath "$env:WinDir\System32\auditpol.exe" -ArgumentList "/set", "/subcategory:$LogonGuid", "/success:enable", "/failure:enable" -ErrorAction Stop
                    Write-Host -Object "[Info] Successfully enabled user logon auditing."
                    $ChangesMade = $true
                }
                catch {
                    Write-Host "[Error] Failed to enable user logon auditing."
                    Write-Host "[Error] $($_.Exception.Message)"
                    $ExitCode = 1
                }
            }
            Write-Host ""
        }
        # If chosen, disable logon auditing
        "Disable" {
            # Check if logon auditing is already disabled
            if ($StartingLogonAuditPolicy -eq "Disabled") {
                Write-Host -Object "[Info] User logon auditing is already disabled."
            }
            else {
                Write-Host -Object "[Info] Disabling user logon auditing."
                try {
                    Invoke-LegacyConsoleTool -FilePath "$env:WinDir\System32\auditpol.exe" -ArgumentList "/set", "/subcategory:$LogonGuid", "/success:disable", "/failure:disable" -ErrorAction Stop
                    Write-Host -Object "[Info] Successfully disabled user logon auditing."
                    $ChangesMade = $true
                }
                catch {
                    Write-Host "[Error] Failed to disable user logon auditing."
                    Write-Host "[Error] $($_.Exception.Message)"
                    $ExitCode = 1
                }
            }
            Write-Host ""
        }
    }

    switch ($AuditLogoffAction) {
        # If chosen, enable logoff auditing
        "Enable" {
            # Check if logoff auditing is already enabled
            if ($StartingLogoffAuditPolicy -eq "Enabled") {
                Write-Host -Object "[Info] User logoff auditing is already enabled."
            }
            else {
                Write-Host -Object "[Info] Enabling user logoff auditing."
                try {
                    Invoke-LegacyConsoleTool -FilePath "$env:WinDir\System32\auditpol.exe" -ArgumentList "/set", "/subcategory:$LogoffGuid", "/success:enable", "/failure:disable" -ErrorAction Stop
                    Write-Host -Object "[Info] Successfully enabled user logoff auditing."
                    $ChangesMade = $true
                }
                catch {
                    Write-Host "[Error] Failed to enable user logoff auditing."
                    Write-Host "[Error] $($_.Exception.Message)"
                    $ExitCode = 1
                }
            }
            Write-Host ""
        }
        # If chosen, disable logoff auditing
        "Disable" {
            # Check if logoff auditing is already disabled
            if ($StartingLogoffAuditPolicy -eq "Disabled") {
                Write-Host -Object "[Info] User logoff auditing is already disabled."
            }
            else {
                Write-Host -Object "[Info] Disabling user logoff auditing."
                try {
                    Invoke-LegacyConsoleTool -FilePath "$env:WinDir\System32\auditpol.exe" -ArgumentList "/set", "/subcategory:$LogoffGuid", "/success:disable", "/failure:disable" -ErrorAction Stop
                    Write-Host -Object "[Info] Successfully disabled user logoff auditing."
                    $ChangesMade = $true
                }
                catch {
                    Write-Host "[Error] Failed to disable user logoff auditing."
                    Write-Host "[Error] $($_.Exception.Message)"
                    $ExitCode = 1
                }
            }
            Write-Host ""
        }
    }

    # Output the previous auditing settings if changes were made
    if ($ChangesMade) {
        Write-Host -Object "### Previous auditing settings: ###`n"
        ([PSCustomObject]@{
            LogonAuditing = $StartingLogonAuditPolicy
            LogoffAuditing = $StartingLogoffAuditPolicy
        } | Format-Table -AutoSize | Out-String).Trim() | Write-Host
        Write-Host ""
    }

    # Retrieve the current audit policy from the registry
    try {
        $CurrentAuditPolicy = Get-LogonLogoffAuditingStatus -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] Unable to retrieve the audit policy from the registry after modification. Changes made: $changesMade."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Update the current logon and logoff auditing policies with the current values
    $CurrentLogonAuditPolicy = $CurrentAuditPolicy.LogonAuditing
    $CurrentLogoffAuditPolicy = $CurrentAuditPolicy.LogoffAuditing

    # Output the current auditing settings
    Write-Host -Object "### Current auditing settings: ###`n"
    ([PSCustomObject]@{
        LogonAuditing = $CurrentLogonAuditPolicy
        LogoffAuditing = $CurrentLogoffAuditPolicy
    } | Format-Table -AutoSize | Out-String).Trim() | Write-Host

    exit $ExitCode
}
end {
    
    
    
}