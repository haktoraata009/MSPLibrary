#Requires -Version 5.1

<#
.SYNOPSIS
    Retrieve the password of the currently connected Wi-Fi network and store it in a secure custom field. Only the English language and Wi-Fi networks using WPA authentication are supported.
.DESCRIPTION
    Retrieve the password of the currently connected Wi-Fi network and store it in a secure custom field. Only the English language and Wi-Fi networks using WPA authentication are supported.

.PARAMETER SecureCustomFieldToStorePassword
    Enter the name of the secure custom field to store the Wi-Fi password.
.PARAMETER EnableLocationServicesTemporarily
    If provided, the script will temporarily enable Location Services if it is disabled. Location Services will be set back to its original settings when the script completes.

.EXAMPLE
    -SecureCustomFieldToStorePassword "WiFiPassword"

    [Info] Retrieving the current Wi-Fi interface on this device.
    [Info] Found the current Wi-Fi network: 'My Wi-Fi'.
    [Info] Found the current Wi-Fi interface alias: 'Wi-Fi'.
    [Info] Found the current Wi-Fi profile: 'My Wi-Fi'.

    [Info] Retrieving the profile details for the current Wi-Fi profile 'My Wi-Fi'.
    [Info] Successfully retrieved the profile details for the current Wi-Fi profile 'My Wi-Fi'.

    [Info] Parsing the profile details to extract the Wi-Fi password.
    [Info] Successfully retrieved the Wi-Fi password for the profile 'My Wi-Fi'.

    [Info] Attempting to set the custom field 'WiFiPassword' with the Wi-Fi password for the 'My Wi-Fi' network.
    [Info] Successfully set the secure custom field 'WiFiPassword'.

.EXAMPLE
    -SecureCustomFieldToStorePassword "WiFiPassword" -EnableLocationServicesTemporarily

    [Info] Attempting to enable Location Services for the system temporarily.
    [Info] Successfully enabled Location Services for the system.

    [Info] Retrieving the current Wi-Fi interface on this device.
    [Info] Found the current Wi-Fi network: 'My Wi-Fi'.
    [Info] Found the current Wi-Fi interface alias: 'Wi-Fi'.
    [Info] Found the current Wi-Fi profile: 'My Wi-Fi'.

    [Info] Retrieving the profile details for the current Wi-Fi profile 'My Wi-Fi'.
    [Info] Successfully retrieved the profile details for the current Wi-Fi profile 'My Wi-Fi'.

    [Info] Parsing the profile details to extract the Wi-Fi password.
    [Info] Successfully retrieved the Wi-Fi password for the profile 'My Wi-Fi'.

    [Info] Attempting to set the custom field 'WiFiPassword' with the Wi-Fi password for the 'My Wi-Fi' network.
    [Info] Successfully set the secure custom field 'WiFiPassword'.

    [Info] Attempting to set Location Services back to its original value 'Deny'.
    [Info] Successfully set Location Services back to its original value.

.NOTES
    Minimum OS Architecture Supported: Windows 10
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$SecureCustomFieldToStorePassword,
    [Parameter()]
    [switch]$EnableLocationServicesTemporarily = [System.Convert]::ToBoolean($env:EnableLocationServicesTemporarily)
)

begin {
    # Check if the operating system build version is less than 10240 (Windows 10 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Import script variable
    if ($env:SecureCustomFieldToStorePassword) { $SecureCustomFieldToStorePassword = $env:SecureCustomFieldToStorePassword }

    # Error if no custom field is provided
    if ([string]::IsNullOrWhiteSpace($SecureCustomFieldToStorePassword)) {
        Write-Host -Object "[Error] You must provide a secure custom field to store the Wi-Fi password."
        exit 1
    }

    # Validate the secure custom field name
    if ($SecureCustomFieldToStorePassword) {
        # Trim the field name to remove leading and trailing whitespace
        $SecureCustomFieldToStorePassword = $SecureCustomFieldToStorePassword.Trim()

        # Validate that the field is not just whitespace
        if ([string]::IsNullOrWhiteSpace($SecureCustomFieldToStorePassword)) {
            Write-Host "[Error] The value for the 'Secure Custom Field To Store Password' parameter contains only spaces. Please provide a valid field name."
            exit 1
        }

        # Validate that the field name contains only alphanumeric characters
        if ($SecureCustomFieldToStorePassword -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'Secure Custom Field To Store Password' value of '$SecureCustomFieldToStorePassword' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid secure custom field name to save the results."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

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

    function Test-IsSystem {
        [CmdletBinding()]
        param ()

        # Get the current Windows identity of the user running the script
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()

        # Check if the current identity's name matches "NT AUTHORITY*"
        # or if the identity represents the SYSTEM account
        return $id.Name -like "NT AUTHORITY*" -or $id.IsSystem
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

    if (!$IsElevated) {
        Write-Host -Object "[Error] The user '$([environment]::UserName)' is not running this script in an elevated session. Please run this script as System or in an elevated session."
        exit 1
    }

    try {
        $IsSystem = Test-IsSystem -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$([environment]::UserName)' is the SYSTEM account."
        exit 1
    }

    # Retrieve the UI culture of the current user
    try {
        $CurrentLanguage = Get-UICulture -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] Unable to determine the current UI culture of the user '$([environment]::UserName)'."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Error if the script is not running in English
    if ($CurrentLanguage.TwoLetterISOLanguageName -ne "en") {
        Write-Host -Object "[Error] The current language of the user '$([environment]::UserName)' is '$($CurrentLanguage.DisplayName)'. This script only supports the English language."
        exit 1
    }

    # Check if Location Services is enabled for the system
    try {
        $LocationServicesRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
        $LocationServices = (Get-ItemProperty -Path $LocationServicesRegistryPath -ErrorAction Stop).Value

        if ($LocationServices -ne "Allow") {
            $LocationServicesIsDisabled = $True
        }
    }
    catch {
        Write-Host -Object "[Error] Unable to determine if Location Services is enabled for the system."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # If not running as SYSTEM, check the per-user Location Services settings
    if (-not $IsSystem) {
        try {
            # Per-user Location Services desktop apps registry key: "Let apps access your location"
            $LocationServicesPerUserRegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
            $LocationServicesPerUser = (Get-ItemProperty $LocationServicesPerUserRegistryPath -ErrorAction Stop).Value

            # Per-user desktop apps registry key: "Let desktop apps access your location"
            $LocationServicesDesktopAppsPerUserRegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged"
            $LocationServicesDesktopAppsPerUser = (Get-ItemProperty $LocationServicesDesktopAppsPerUserRegistryPath -ErrorAction Stop).Value

            if ($LocationServicesPerUser -ne "Allow") {
                $LocationServicesPerUserIsDisabled = $True
            }

            if ($LocationServicesDesktopAppsPerUser -ne "Allow") {
                $LocationServicesDesktopAppsIsDisabled = $True
            }
        }
        catch {
            Write-Host -Object "[Error] Unable to determine if Location Services is enabled for the user '$([environment]::UserName)'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    # Error if Location Services is disabled for the system, unless the temporary flag is set
    if (-not $EnableLocationServicesTemporarily -and $LocationServicesIsDisabled) {
        Write-Host -Object "[Error] Location Services is disabled for the system, but it is required for this script."
        Write-Host -Object "[Error] Please use the 'Enable Location Services Temporarily' parameter to enable it while the script runs."
        exit 1
    }

    # Error if Location Services is disabled for the user, unless running as SYSTEM or the temporary flag is set
    if (-not $IsSystem -and -not $EnableLocationServicesTemporarily -and ($LocationServicesPerUserIsDisabled -or $LocationServicesDesktopAppsIsDisabled)) {
        Write-Host -Object "[Error] Location Services is disabled for the user '$([environment]::UserName)', but it is required for this script."
        Write-Host -Object "[Error] Please use the 'Enable Location Services Temporarily' parameter to enable it while the script runs."
        exit 1
    }

    # Attempt to enable Location Services if the temporary flag is set and Location Services is disabled
    if ($EnableLocationServicesTemporarily -and $LocationServicesIsDisabled) {
        try {
            Write-Host -Object "[Info] Attempting to enable Location Services for the system temporarily."
            Set-ItemProperty -Path $LocationServicesRegistryPath -Name "Value" -Value "Allow" -ErrorAction Stop
            Write-Host -Object "[Info] Successfully enabled Location Services for the system."
            $registryChanged = $True
        }
        catch {
            Write-Host -Object "[Error] Unable to enable Location Services for the system."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    # Attempt to enable per-user Location Services if the temporary flag is set and Location Services is disabled for the user
    if ($EnableLocationServicesTemporarily -and $LocationServicesPerUserIsDisabled) {
        try {
            Write-Host -Object "[Info] Attempting to enable Location Services for the user '$([environment]::UserName)' temporarily."
            Set-ItemProperty -Path $LocationServicesPerUserRegistryPath -Name "Value" -Value "Allow" -ErrorAction Stop
            Write-Host -Object "[Info] Successfully enabled Location Services for the user '$([environment]::UserName)'."
            $registryChanged = $True
        }
        catch {
            Write-Host -Object "[Error] Unable to enable Location Services for the user '$([environment]::UserName)'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    # Attempt to enable desktop app Location Services if the temporary flag is set and Location Services is disabled for desktop apps
    if ($EnableLocationServicesTemporarily -and $LocationServicesDesktopAppsIsDisabled) {
        try {
            Write-Host -Object "[Info] Attempting to enable Location Services for desktop apps for the user '$([environment]::UserName)' temporarily."
            Set-ItemProperty -Path $LocationServicesDesktopAppsPerUserRegistryPath -Name "Value" -Value "Allow" -ErrorAction Stop
            Write-Host -Object "[Info] Successfully enabled Location Services for desktop apps for the user '$([environment]::UserName)'."
            $registryChanged = $True
        }
        catch {
            Write-Host -Object "[Error] Unable to enable Location Services for desktop apps for the user '$([environment]::UserName)'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    if ($registryChanged) { Write-Host "" }

    # Get the current Wi-Fi interface
    try {
        Write-Host -Object "[Info] Retrieving the current Wi-Fi interface on this device."
        $Interfaces = Invoke-LegacyConsoleTool -FilePath "netsh" -Encoding ([System.Text.Encoding]::UTF8) -ArgumentList "wlan show interfaces" -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] Failed to retrieve the Wi-Fi interfaces on this device."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
    }

    # Check the last exit code to make sure the command executed successfully
    if ($LASTEXITCODE -ne 0) {
        Write-Host -Object "[Error] Failed to retrieve the Wi-Fi interfaces on this device."
        Write-Host -Object "[Error] The command 'netsh wlan show interfaces' returned the exit code: $LASTEXITCODE"
        Write-Host -Object "[Error] Command output:`n$Interfaces"
        if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
    }

    if ($ExitCode -ne 1) {
        try {
            # Split the interfaces output into individual interfaces, skipping the irrelevant header and footer lines
            $Interfaces = ($Interfaces | Select-Object -Skip 3 | Select-Object -SkipLast 3 | Out-String) -split "\r\n\r\n"

            # Create a custom object to hold the connected Wi-Fi adapter details
            $CurrentConnectedWiFiAdapters = foreach ($Interface in $Interfaces) {
                # Skip empty interfaces
                if ([string]::IsNullOrWhiteSpace($Interface)) { continue }

                # Split the interface string into lines
                $InterfaceLines = ($Interface -split "`n").Trim()

                # Extract the state of the interface
                $State = (($InterfaceLines | Select-String "^State\s{2,}") -split ":", 2 | Select-Object -Index 1).Trim()

                # Skip disconnected interfaces
                if ($State -eq "disconnected") { continue }

                # Extract the rest of the properties from the interface lines
                $InterfaceName = (($InterfaceLines | Select-String "^Name\s{2,}") -split ":", 2 | Select-Object -Index 1).Trim()
                $SSID = (($InterfaceLines | Select-String "^SSID\s{2,}") -split ":", 2 | Select-Object -Index 1).Trim()
                $AuthenticationType = (($InterfaceLines | Select-String "^Authentication\s{2,}") -split ":", 2 | Select-Object -Index 1).Trim()
                $WiFiProfile = (($InterfaceLines | Select-String "^Profile\s{2,}") -split ":", 2 | Select-Object -Index 1).Trim()

                # Create a custom object for each interface
                [PSCustomObject]@{
                    InterfaceName      = $InterfaceName
                    AuthenticationType = $AuthenticationType
                    State              = "Connected"
                    SSID               = $SSID
                    Profile            = $WiFiProfile
                }
            }
        }
        catch {
            Write-Host "[Error] Error while parsing the Wi-Fi interfaces output."
            Write-Host "[Error] $($_.Exception.Message)"
            if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
        }
    }

    # Get the number of currently connected Wi-Fi adapters
    $WiFiAdapterCount = ($CurrentConnectedWiFiAdapters | Measure-Object).Count

    # Error if multiple active Wi-Fi networks are found
    if ($WiFiAdapterCount -gt 1) {
        Write-Host -Object "[Error] Multiple active Wi-Fi networks found. Please ensure you are connected to only one Wi-Fi network in order to use this script."
        Write-Host -Object "[Error] Found $WiFiAdapterCount active Wi-Fi networks. Please disconnect from all but one and run this script again."
        if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
    }
    elseif ($WiFiAdapterCount -lt 1) {
        Write-Host -Object "[Error] No active Wi-Fi networks found. Please ensure you are connected to a Wi-Fi network."
        if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
    }

    if ($ExitCode -ne 1) {
        $CurrentWiFiSSID = $CurrentConnectedWiFiAdapters | Select-Object -Expand SSID
        $CurrentWiFiAdapterInterfaceAlias = $CurrentConnectedWiFiAdapters | Select-Object -Expand InterfaceName
        $CurrentWiFiAuthenticationType = $CurrentConnectedWiFiAdapters | Select-Object -Expand AuthenticationType
        $CurrentWiFiProfile = $CurrentConnectedWiFiAdapters | Select-Object -Expand Profile

        # Error if the current Wi-Fi SSID is blank
        if ([string]::IsNullOrWhiteSpace($CurrentWifiSSID)) {
            Write-Host -Object "[Error] The SSID for the current Wi-Fi network could not be identified. Please ensure you are connected to a Wi-Fi network."
            if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
        }

        # Error if the current Wi-Fi adapter interface alias is blank
        if ([string]::IsNullOrWhiteSpace($CurrentWiFiAdapterInterfaceAlias)) {
            Write-Host -Object "[Error] The interface alias for the current Wi-Fi network could not be identified. Please ensure you are connected to a Wi-Fi network."
            if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
        }

        # Error if the current Wi-Fi profile is blank
        if ([string]::IsNullOrWhiteSpace($CurrentWiFiProfile)) {
            Write-Host -Object "[Error] The profile for the current Wi-Fi network could not be identified. Please ensure you are connected to a Wi-Fi network."
            if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
        }

        # Error if the current Wi-Fi authentication type is Enterprise, which uses a username and password sent to a server instead of a password/pre-shared key
        if ($CurrentWiFiAuthenticationType -match "Enterprise") {
            Write-Host -Object "[Error] The current Wi-Fi network '$CurrentWiFiSSID' is using an Enterprise authentication type ('$CurrentWiFiAuthenticationType'). This script only supports Wi-Fi networks using personal WPA authentication."
            if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
        }

        # Error if the current Wi-Fi authentication type is WEP, which is an outdated and insecure protocol
        if ($CurrentWiFiAuthenticationType -match "WEP") {
            Write-Host -Object "[Error] The current Wi-Fi network '$CurrentWiFiSSID' is using the insecure WEP authentication type. This script only supports Wi-Fi networks using WPA authentication."
            if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
        }

        # Exit immediately if the current Wi-Fi authentication type is not WPA
        if ($CurrentWiFiAuthenticationType -notmatch "WPA") {
            Write-Host -Object "[Warning] The current Wi-Fi network '$CurrentWiFiSSID' looks like an open network (authentication type: '$CurrentWiFiAuthenticationType'). There is no password to retrieve for open networks."
            if (-not $registryChanged) { exit 0 } else { $SkipParsing = $True }
        }
    }

    if ($ExitCode -ne 1 -and -not $SkipParsing) {
        Write-Host -Object "[Info] Found the current Wi-Fi network: '$CurrentWiFiSSID'."
        Write-Host -Object "[Info] Found the current Wi-Fi interface alias: '$CurrentWiFiAdapterInterfaceAlias'."
        Write-Host -Object "[Info] Found the current Wi-Fi profile: '$CurrentWiFiProfile'.`n"

        # Retrieve the profile details for the current Wi-Fi profile
        try {
            Write-Host -Object "[Info] Retrieving the profile details for the current Wi-Fi profile '$CurrentWiFiProfile'."
            $ProfileDetails = Invoke-LegacyConsoleTool -FilePath "netsh" -ArgumentList "wlan show profile interface=`"$CurrentWiFiAdapterInterfaceAlias`" name=`"$CurrentWiFiProfile`" key=clear" -Encoding ([System.Text.Encoding]::UTF8) -ErrorAction Stop
        }
        catch {
            Write-Host -Object "[Error] Failed to retrieve the profile details for the current Wi-Fi profile '$CurrentWiFiProfile'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
        }

        # Check the last exit code to make sure the command executed successfully
        if ($LASTEXITCODE -ne 0) {
            Write-Host -Object "[Error] Failed to retrieve the profile details for the current Wi-Fi profile '$CurrentWiFiProfile'."
            Write-Host -Object "[Error] The command 'netsh wlan show profile interface=`"$CurrentWiFiAdapterInterfaceAlias`" name=`"$CurrentWiFiProfile`" key=clear' returned the exit code: $LASTEXITCODE"
            Write-Host -Object "[Error] Command output:`n$ProfileDetails"
            if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
        }
        else {
            Write-Host -Object "[Info] Successfully retrieved the profile details for the current Wi-Fi profile '$CurrentWiFiProfile'.`n"
        }
    }

    if ($ExitCode -ne 1 -and -not $SkipParsing) {
        # Extract the Wi-Fi password from the profile details
        try {
            Write-Host -Object "[Info] Parsing the profile details to extract the Wi-Fi password."
            $CurrentWifiPassword = ($ProfileDetails[-11] -split ":", 2 | Select-Object -Index 1).Trim()

            # Error if no password is found
            if ([string]::IsNullOrWhiteSpace($CurrentWifiPassword)) {
                Write-Host -Object "[Error] No Wi-Fi password found for the current profile '$CurrentWiFiProfile'. Please ensure you are connected to a Wi-Fi network with a saved password."
                if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
            }
            else {
                Write-Host -Object "[Info] Successfully retrieved the Wi-Fi password for the profile '$CurrentWiFiProfile'."
            }
        }
        catch {
            Write-Host -Object "[Error] Failed to parse the profile details to extract the Wi-Fi password."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
        }

        Write-Host ""
    }

    if ($ExitCode -ne 1 -and -not $SkipParsing) {
        # Trim the whitespace from the Wi-Fi password
        $CurrentWifiPassword = $CurrentWifiPassword.Trim()

        # Attempt to set the secure custom field with the Wi-Fi password
        try {
            Write-Host -Object "[Info] Attempting to set the custom field '$SecureCustomFieldToStorePassword' with the Wi-Fi password for the '$CurrentWiFiSSID' network."
            Set-NinjaProperty -Name $SecureCustomFieldToStorePassword -Value $CurrentWifiPassword -ErrorAction Stop
            Write-Host -Object "[Info] Successfully set the secure custom field '$SecureCustomFieldToStorePassword'."
        }
        catch {
            Write-Host -Object "[Error] Failed to set the secure custom field '$SecureCustomFieldToStorePassword'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    if ($registryChanged) { Write-Host "" }

    # Attempt to set Location Services back to its original value
    if ($EnableLocationServicesTemporarily -and $LocationServicesIsDisabled) {
        try {
            Write-Host -Object "[Info] Attempting to set Location Services back to its original value '$LocationServices'."
            Set-ItemProperty -Path $LocationServicesRegistryPath -Name "Value" -Value $LocationServices -ErrorAction Stop
            Write-Host -Object "[Info] Successfully set Location Services back to its original value."
        }
        catch {
            Write-Host -Object "[Error] Failed to set '$LocationServicesRegistryPath' back to its original value."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    # Attempt to set the per-user Location Services back to its original value
    if ($EnableLocationServicesTemporarily -and $LocationServicesPerUserIsDisabled) {
        try {
            Write-Host -Object "[Info] Attempting to set Location Services for the user back to its original value '$LocationServicesPerUser'."
            Set-ItemProperty -Path $LocationServicesPerUserRegistryPath -Name "Value" -Value $LocationServicesPerUser -ErrorAction Stop
            Write-Host -Object "[Info] Successfully set Location Services for the user '$([environment]::UserName)' back to its original value."
        }
        catch {
            Write-Host -Object "[Error] Failed to set '$LocationServicesPerUserRegistryPath' for the user '$([environment]::UserName)' back to its original value."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    # Attempt to set the per-user desktop app Location Services back to its original value
    if ($EnableLocationServicesTemporarily -and $LocationServicesDesktopAppsIsDisabled) {
        try {
            Write-Host -Object "[Info] Attempting to set Location Services for desktop apps back to its original value '$LocationServicesDesktopAppsPerUser'."
            Set-ItemProperty -Path $LocationServicesDesktopAppsPerUserRegistryPath -Name "Value" -Value $LocationServicesDesktopAppsPerUser -ErrorAction Stop
            Write-Host -Object "[Info] Successfully set Location Services for desktop apps for the user '$([environment]::UserName)' back to its original value."
        }
        catch {
            Write-Host -Object "[Error] Failed to set '$LocationServicesDesktopAppsPerUserRegistryPath' for the user '$([environment]::UserName)' back to its original value."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    exit $ExitCode
}
end {
    
    
    
}