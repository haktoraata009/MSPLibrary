#Requires -Version 5.1

<#
.SYNOPSIS
    Collects system performance data (CPU, memory, disk, and network). The results can optionally be saved to a WYSIWYG custom field.
.DESCRIPTION
    Collects system performance data (CPU, memory, disk, and network). The results can optionally be saved to a WYSIWYG custom field.
.EXAMPLE
    -DaysSinceLastReboot "7" -DurationToPerformTests "5" -NumberOfEvents "5" -WysiwygCustomField "WYSIWYG" -DisplayUserMessage

    Checking for currently logged-in users.
    Sending message to all users.
    Sending message to session Console, display time 150
    Async message sent to session Console
    Sending message to session 31C5CE94259D4006A9E4#0, display time 150
    Async message sent to session 31C5CE94259D4006A9E4#0
    ExitCode: 0
    [Alert] This computer was last started on 5/22/2025 at 3:22 AM which was 1.36 days ago.

    Collecting event logs.
    Searching for performance counter localizations.
    Collecting performance metrics for 5 minutes.
    [Warning] The data in one of the performance counter samples is not valid. View the Status property for each PerformanceCounterSample object to make sure it contains valid data.
    [Warning] The data in one of the performance counter samples is not valid. View the Status property for each PerformanceCounterSample object to make sure it contains valid data.
    [Warning] The data in one of the performance counter samples is not valid. View the Status property for each PerformanceCounterSample object to make sure it contains valid data.
    [Warning] The data in one of the performance counter samples is not valid. View the Status property for each PerformanceCounterSample object to make sure it contains valid data.
    [Warning] The data in one of the performance counter samples is not valid. View the Status property for each PerformanceCounterSample object to make sure it contains valid data.

    ### 12th Gen Intel(R) Core(TM) i9-12900H 2.918 GHz ###
    CPU Average % CPU Minimum % CPU Maximum %
    ------------- ------------- -------------
    3.43%         1.85%         6.14%

    ### Memory Usage ###
    Total Memory Installed: 4 GB
    RAM Average % RAM Minimum % RAM Maximum %
    ------------- ------------- -------------
    70.35%        70.28%        70.39%

    ### Top 5 CPU Processes ###
    Process Name  Average CPU % Used Minimum CPU % Used Maximum CPU % Used
    ------------  ------------------ ------------------ ------------------
    ninjarmmagent 0.22%              0.13%              0.36%
    conhost       0.16%              0.05%              0.34%
    msmpeng       0.14%              0.08%              0.21%
    svchost       0.13%              0.05%              0.23%
    services      0.03%              0%                 0.08%

    ### Top 5 RAM Processes ###
    Process Name Average RAM % Used Minimum RAM % Used Maximum RAM % Used
    ------------ ------------------ ------------------ ------------------
    svchost      4.41%              4.39%              4.42%
    msmpeng      2.94%              2.83%              3.17%
    explorer     1.38%              1.37%              1.38%
    powershell   1.33%              1.33%              1.33%
    dwm          0.64%              0.64%              0.65%

    ### Network Usage ###
    NetworkAdapter          : microsoft hyper-v network adapter
    MacAddress              : 00-17-FB-00-00-02
    Type                    : Wired
    Average Sent & Received : 0 Mbps
    Minimum Sent & Received : 0 Mbps
    Maximum Sent & Received : 0.01 Mbps

    ### Disk Usage ###
    DriveLetter  : C
    FreeSpace    : 19.43 GB (39.28%)
    TotalSpace   : 49.47 GB
    PhysicalDisk : Msft Virtual Disk
    MediaType    : Unspecified
    Average IOPS : 3.45 IOPS
    Minimum IOPS : 2.62 IOPS
    Maximum IOPS : 5.95 IOPS

    ### Top 5 IO Processes (Network & Disk Combined) ###
    Process Name          Average IO Used Minimum IO Used Maximum IO Used
    ------------          --------------- --------------- ---------------
    svchost               0.2432 Mbps     0.2194 Mbps     0.266 Mbps
    ninjarmmagent         0.0793 Mbps     0.0514 Mbps     0.1508 Mbps
    system                0.0319 Mbps     0.0172 Mbps     0.0417 Mbps
    mpdefendercoreservice 0.007 Mbps      0 Mbps          0.0349 Mbps
    registry              0.0026 Mbps     0 Mbps          0.0062 Mbps

    Retrieving WinSAT assessment data.
    More info: https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-8.1-and-8/hh825488(v=win.10)
    [Error] WinSAT assessment data is not available on this computer. Is this computer a virtual machine?

    Attempting to set Custom Field 'WYSIWYG'.
    Successfully set Custom Field 'WYSIWYG'!

    Checking for currently logged-in users.

    Sending message to all users.
    Sending message to session Console, display time 3600
    Async message sent to session Console
    Sending message to session 31C5CE94259D4006A9E4#0, display time 3600
    Async message sent to session 31C5CE94259D4006A9E4#0
    ExitCode: 0

    ### Last 5 errors in Application, Security, Setup and System Log. ###
    LogName      : System
    ProviderName : Microsoft-Windows-TPM-WMI
    Id           : 1796
    TimeCreated  : 5/23/2025 8:50:09 AM
    Message      : The Secure Boot update failed to update a Secure Boot variable with error Secure Boot is not enabled on
                this machine.. For more information, please see https://go.microsoft.com/fwlink/?linkid=2169931
    ...

.PARAMETER DisplayUserMessage
    Display a message to the end-user informing them that you are collecting performance metrics and that they should not restart the computer.

.PARAMETER DaysSinceLastReboot
    Specify the number of days by which the system should have been rebooted.

.PARAMETER DurationToPerformTests
    The duration (in minutes) for which the performance tests should be executed.

.PARAMETER NumberOfEvents
    The number of error events to retrieve from the Application, Security, Setup, and System event logs.

.PARAMETER WysiwygCustomField
    Optionally specify the name of a WYSIWYG custom field to store the formatted performance data.

.PARAMETER PerformInternetSpeedTest
    Determines whether to perform an internet speed test as part of the system performance assessment.
    This test uses M-Lab’s MSAK server under their Acceptable Use Policy. By proceeding, you consent to public collection of network data, including your IP.

.PARAMETER RandomSleepForSpeedTest
    Sleep for a random duration between 0 and 60 minutes before running the Speedtest.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.2
    Release Notes: Added Internet Speed Test and multi-cpu support
#>

[CmdletBinding()]
param (
    [Parameter()]
    $DaysSinceLastReboot,
    [Parameter()]
    $DurationToPerformTests = 5,
    [Parameter()]
    $NumberOfEvents,
    [Parameter()]
    [String]$WysiwygCustomField,
    [Parameter()]
    [Switch]$DisplayUserMessage = [System.Convert]::ToBoolean($env:displayUserMessage),
    [Parameter()]
    [Switch]$PerformInternetSpeedTest = [System.Convert]::ToBoolean($env:performInternetSpeedTest),
    [Parameter()]
    [Switch]$RandomSleepForSpeedTest = [System.Convert]::ToBoolean($env:randomSleepForSpeedTest),
    [Parameter()]
    [String]$CongestionAlgorithm = "bbr",
    [Parameter()]
    [Int]$NumberOfStreams = 3,
    [Parameter()]
    [long]$TestDurationInMilliseconds = 10000,
    [Parameter()]
    [long]$TestSize = 0
)

begin {
    # If script form variables are used, replace command line parameters with their values.
    if ($env:daysSinceLastReboot) { $DaysSinceLastReboot = $env:daysSinceLastReboot }
    if ($env:durationToPerformTests) { $DurationToPerformTests = $env:durationToPerformTests }
    if ($env:numberOfEvents) { $NumberOfEvents = $env:numberOfEvents }
    if ($env:wysiwygCustomFieldName) { $WysiwygCustomField = $env:wysiwygCustomFieldName }

    #region Input validation

    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected."
        Write-Host -Object "[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393).`n"
    }

    # Ensure the value does not contain invalid characters.
    if ($DaysSinceLastReboot -and $DaysSinceLastReboot -match "[^0-9]") {
        Write-Host -Object "[Error] The 'Days Since Last Reboot' value of '$DaysSinceLastReboot' is invalid. It contains invalid characters."
        Write-Host -Object "[Error] Please provide a positive whole number that is greater than or equal to 0 and less than '$([int]::MaxValue)'."
        exit 1
    }

    # Validate the 'Days Since Last Reboot' input.
    if ($DaysSinceLastReboot) {
        try {
            # Attempt to cast the value to a number.
            [int]$DaysSinceLastReboot = $DaysSinceLastReboot
        } catch {
            # If the conversion fails, display an error message and exit the script.
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] The 'Days Since Last Reboot' value of '$DaysSinceLastReboot' is invalid."
            Write-Host -Object "[Error] Please provide a positive whole number that is greater than or equal to 0 and less than '$([int]::MaxValue)'."
            exit 1
        }
    }

    # Ensure the value is non-negative (greater than or equal to 0).
    if ($DaysSinceLastReboot -and $DaysSinceLastReboot -lt 0) {
        Write-Host -Object "[Error] The 'Days Since Last Reboot' value of '$DaysSinceLastReboot' is invalid. It is less than 0."
        Write-Host -Object "[Error] Please provide a positive whole number that is greater than or equal to 0 and less than '$([int]::MaxValue)'."
        exit 1
    }

    # Ensure the value is less than the maximum allowed value.
    if ($DaysSinceLastReboot -and $DaysSinceLastReboot -ge [int]::MaxValue) {
        Write-Host -Object "[Error] The 'Days Since Last Reboot' value of '$DaysSinceLastReboot' is invalid. It is greater than or equal to '$([int]::MaxValue)'."
        Write-Host -Object "[Error] Please provide a positive whole number that is greater than or equal to 0 and less than '$([int]::MaxValue)'."
        exit 1
    }

    # Validate the 'Duration To Perform Tests' input.
    if ([string]::IsNullOrWhiteSpace($DurationToPerformTests)) {
        Write-Host -Object "[Error] Please provide the duration for which you would like to perform the tests using the 'Duration To Perform Tests' box."
        exit 1
    }

    # Ensure the value does not contain invalid characters.
    if ($DurationToPerformTests -match "[^0-9]") {
        Write-Host -Object "[Error] The 'Duration To Perform Tests' value of '$DurationToPerformTests' is invalid. It contains invalid characters."
        Write-Host -Object "[Error] Please provide a positive whole number that's greater than 0 and less than or equal to 60."
        exit 1
    }

    # Validate the 'Duration to Perform Tests input' input.
    if (![string]::IsNullOrWhiteSpace($DurationToPerformTests)) {
        try {
            # Attempt to cast the value to a number.
            [int]$DurationToPerformTests = $DurationToPerformTests
        } catch {
            # If the conversion fails, display an error message and exit the script.
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] The 'Duration to Perform Tests' value of '$DurationToPerformTests' is invalid."
            Write-Host -Object "[Error] Please provide a positive whole number that is greater than 0 and less than or equal to 60."
            exit 1
        }
    }

    # Ensure the duration is between 1 and 60.
    if ($DurationToPerformTests -lt 1 -or $DurationToPerformTests -gt 60) {
        Write-Host -Object "[Error] The 'Duration To Perform Tests' value of '$DurationToPerformTests' is invalid. It is less than 1 or greater than 60."
        Write-Host -Object "[Error] Please provide a positive whole number that's greater than 0 and less than or equal to 60."
        exit 1
    }

    # Ensure the value does not contain invalid characters.
    if ($NumberOfEvents -and $NumberOfEvents -match "[^0-9]") {
        Write-Host -Object "[Error] The 'Number of Events' value of '$NumberOfEvents' is invalid. It contains invalid characters."
        Write-Host -Object "[Error] Please provide a positive whole number that is greater than or equal to 0 and less than '$([int]::MaxValue)'."
        exit 1
    }

    # Validate the 'Number of Events' input.
    if ($NumberOfEvents) {
        try {
            # Attempt to cast the value to a number.
            [int]$NumberOfEvents = $NumberOfEvents
        } catch {
            # If the conversion fails, display an error message and exit the script.
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] The 'Number of Events' value of '$NumberOfEvents' is invalid."
            Write-Host -Object "[Error] Please provide a positive whole number that is greater than or equal to 0 and less than '$([int]::MaxValue)'."
            exit 1
        }
    }

    # Ensure the value is non-negative (greater than or equal to 0).
    if ($NumberOfEvents -and $NumberOfEvents -lt 0) {
        Write-Host -Object "[Error] The 'Number of Events' value of '$NumberOfEvents' is invalid. It is less than 0."
        Write-Host -Object "[Error] Please provide a positive whole number that is greater than or equal to 0 and less than '$([int]::MaxValue)'."
        exit 1
    }

    # Ensure the value is less than the maximum allowed value.
    if ($NumberOfEvents -and $NumberOfEvents -ge [int]::MaxValue) {
        Write-Host -Object "[Error] The 'Number of Events' value of '$NumberOfEvents' is invalid. It is greater than or equal to '$([int]::MaxValue)'."
        Write-Host -Object "[Error] Please provide a positive whole number that is greater than or equal to 0 and less than '$([int]::MaxValue)'."
        exit 1
    }

    if (!$PerformInternetSpeedTest -and $RandomSleepForSpeedTest) {
        Write-Host -Object "[Error] 'Random Sleep For Speed Test' requires 'Perform Internet Speed Test' to be enabled."
        exit 1
    }

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

    function Get-TestURLs {
        [CmdletBinding()]
        param(
            [Parameter()]
            [String]$Type,
            [Parameter()]
            [String]$MLabsThroughputAPI = 'https://locate.measurementlab.net/v2/nearest/msak/throughput1',
            [Parameter()]
            [String]$MLabsLatencyAPI = 'https://locate.measurementlab.net/v2/nearest/msak/latency1'
        )

        $ValidTypes = "Throughput", "Latency"
        if ($ValidTypes -notcontains $Type) {
            throw [System.NotSupportedException]::New("'$Type' is not a valid type. Only 'Throughput' and 'Latency' test urls can be retrieved.")
        }

        # Notify user that the script is requesting the closest speed test server
        Write-Host -Object "Requesting the nearest $Type test server and authentication information for the next test."

        # Suppress progress output for web requests
        $PreviousProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        # Attempt to retrieve the nearest test server with up to 3 retries
        $ServerRequestAttempts = 1
        $MaxAttempts = 3
        while ($ServerRequestAttempts -le $MaxAttempts) {
            $SleepTime = Get-Random -Minimum 3 -Maximum 15
            Start-Sleep -Seconds $SleepTime

            if ($ServerRequestAttempts -ne 1) { Write-Host -Object "" }
            Write-Host -Object "### Request Attempt $ServerRequestAttempts ###"

            # Define the web request parameters
            $ServerRequestArgs = @{
                MaximumRedirection = 10
                UseBasicParsing    = $true
                Method             = "Get"
                TimeOut            = 30
            }

            switch ($Type) {
                "Throughput" { $ServerRequestArgs.URI = $MLabsThroughputAPI }
                "Latency" { $ServerRequestArgs.URI = $MLabsLatencyAPI }
            }

            try {
                $ErrorActionPreference = "Stop"

                $MLabsServerRequest = Invoke-WebRequest @ServerRequestArgs
                $MLabsNearestServers = $MLabsServerRequest.Content | ConvertFrom-Json

            } catch {
                # Handle request errors and warn the user
                Write-Host -Object "[Warning] $($_.Exception.Message)"
                Write-Host -Object "[Warning] Failed to retrieve the nearest speed test server location."
            } finally {
                $ErrorActionPreference = "Continue"
            }

            # If the server list was successfully retrieved, exit the retry loop
            if ($MLabsNearestServers) {
                Write-Host -Object "Response received."
                $ServerRequestAttempts = $MaxAttempts
            }

            $ServerRequestAttempts++
        }

        # Restore the original progress preference setting
        $ProgressPreference = $PreviousProgressPreference

        # Exit if no servers were retrieved
        if (!$MLabsNearestServers) {
            Write-Host -Object "[Error] Failed to retrieve the nearest Measurement Labs test server."
            exit 1
        }

        # Attempt to extract download and upload test URLs from the response
        Write-Host -Object "Attempting to parse the access information from the response."

        switch ($Type) {
            "Throughput" {
                $DownloadKey = "wss:///throughput/v1/download"
                $UploadKey = "wss:///throughput/v1/upload"

                $ThroughputServerHostname = $MLabsNearestServers.results.hostname[0]
                $DownloadTestURL = $MLabsNearestServers.results.urls[0]."$DownloadKey"
                $UploadTestURL = $MLabsNearestServers.results.urls[0]."$UploadKey"

                if (!$DownloadTestURL -or !$UploadTestURL -or !$ThroughputServerHostname) {
                    Write-Host -Object "[Error] Failed to retrieve the throughput test URL's from the server response."
                    Write-Host -Object "`n### Throughput Server Response ###"
                    $MLabsNearestServers.Content | Write-Host
                    exit 1
                }
            }
            "Latency" {
                $LatencyAuthKey = "https:///latency/v1/authorize"
                $LatencyResultKey = "https:///latency/v1/result"

                $LatencyAuthUrl = $MLabsNearestServers.results.urls[0]."$LatencyAuthKey"
                $LatencyResultUrl = $MLabsNearestServers.results.urls[0]."$LatencyResultKey"
                $LatencyServerHostname = $MLabsNearestServers.results.hostname[0]

                if (!$LatencyAuthUrl -or !$LatencyResultUrl -or !$LatencyServerHostname) {
                    Write-Host -Object "[Error] Failed to retrieve the latency test URL's from the server response."
                    Write-Host -Object "`n### Latency Server Response ###"
                    $MLabsNearestServers.Content | Write-Host
                    exit 1
                }
            }
        }

        switch ($Type) {
            "Throughput" {
                [PSCustomObject]@{
                    ThroughputServerHostname = $ThroughputServerHostname
                    DownloadTestURL          = $DownloadTestURL
                    UploadTestURL            = $UploadTestURL
                }
            }
            "Latency" {
                [PSCustomObject]@{
                    LatencyServerHostname = $LatencyServerHostname
                    LatencyAuthURL        = $LatencyAuthUrl
                    LatencyResultUrl      = $LatencyResultUrl
                }
            }
        }
    }

    # Generates an RFC 9562 compatible UUID (not the same as New-GUID)
    function New-UUIDv7 {
        # Get the current Unix timestamp in milliseconds (PowerShell 5.1 compatible)
        $UnixTimestampMs = [math]::Floor((New-Object System.DateTimeOffset (Get-Date)).ToUnixTimeMilliseconds())

        # Convert the timestamp to hexadecimal (48 bits)
        $TimeHex = "{0:X8}{1:X4}" -f ($UnixTimestampMs -shr 16), ($UnixTimestampMs -band 0xFFFF)

        # Generate 6 random bytes (48 bits) using a cryptographic RNG
        $RandomBytes = New-Object byte[] 6
        $Rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        $Rng.GetBytes($RandomBytes)
        $RandomBits = ($RandomBytes | ForEach-Object { "{0:X2}" -f $_ }) -join ""

        # Ensure the version bit is set to '7' (UUIDv7)
        $VersionHex = "7" + $RandomBits.Substring(0, 3)  # Version 7 (UUIDv7)

        # Generate the variant (RFC 9562 requires MSB 10xx)
        $VariantByte = [byte]($RandomBytes[3] -band 0x3F -bor 0x80) # Ensures 10xx (RFC 9562-compliant)
        $VariantHex = "{0:X2}" -f $VariantByte

        # Construct the final UUIDv7 format: 8-4-4-4-12
        $UUIDv7 = -join @(
            $TimeHex.Substring(0, 8), # First 8 hex chars (32 bits)
            "-",
            $TimeHex.Substring(8, 4), # Next 4 hex chars (16 bits)
            "-",
            $VersionHex, # 4 hex chars, including version "7"
            "-",
            $VariantHex, # 4 hex chars, including variant
            "-",
            $RandomBits.Substring(6)   # Last 12 hex chars (48 bits)
        )

        return $UUIDv7
    }

    function Test-IsServer {
        [CmdletBinding()]
        param()

        # Determine the method to retrieve the operating system information based on PowerShell version
        $OS = if ($PSVersionTable.PSVersion.Major -lt 3) {
            Get-WmiObject -Class Win32_OperatingSystem
        } else {
            Get-CimInstance -ClassName Win32_OperatingSystem
        }

        # Check if the ProductType is "2", which indicates that the system is a domain controller or is a server
        if (($OS.ProductType -eq "2" -or $OS.ProductType -eq "3") -and $OS.OperatingSystemSku -ne "175") {
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
        # 544 is the value for the Built-In Administrators role
        # Reference: https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsbuiltinrole
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]'544')
    }

    #endregion

    if (!$ExitCode) {
        $ExitCode = 0
    }

    $StartedDateTime = Get-Date
}
process {
    #region Environment Validation

    # Attempt to determine if the current session is running with Administrator privileges.
    try {
        $IsElevated = Test-IsElevated -ErrorAction Stop
    } catch {
        # Log an error if unable to determine admin privileges
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running with Administrator privileges."
        exit 1
    }

    # Exit if the script is not running with Administrator privileges
    if (!($IsElevated)) {
        Write-Host -Object "[Error] Access Denied: The user '$env:Username' does not have administrator privileges, or the script is not running with elevated permissions."
        exit 1
    }

    # Check if the script is running on a server.
    try {
        $IsServer = Test-IsServer -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] Unable to identify device type."
        Write-Host -Object "[Error] $($_.Exception.Message)`n"
        $ExitCode = 1
    }

    if ($IsServer -and $DisplayUserMessage) {
        # Attempt to check if the RDS role is installed.
        try {
            # Retrieve the RDS role feature and check if it is installed.
            $RDSRole = Get-WindowsFeature -Name "RDS-RD-Server" -ErrorAction Stop | Where-Object { $_.Installed }
        } catch {
            # If an error occurs during the check, output an error message and exit the script.
            Write-Host -Object "[Error] Unable to check if the RDS role is installed."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        # If the RDS role is installed, output an error message and exit the script.
        if ($RDSRole) {
            Write-Host -Object "[Error] This script doesn't support sending a message on RDS servers because the message would show for all logged-in users, potentially creating a source of confusion."
            exit 1
        }
    }

    #endregion
    #region Process Lock File

    # Check if the lock file exists to prevent multiple instances of the script from running.
    # If it exists, read the process ID from the lock file and check if the process is still running.
    if (Test-Path -Path "$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt" -ErrorAction SilentlyContinue) {
        try {
            Write-Host -Object "Process lock file found at '$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt'. Checking if the process is still running."

            # Retrieve the process ID from the lock file.
            $OtherScript = Get-Content -Path "$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt" -ErrorAction Stop

            # Check if the process ID exists, indicating the script is already running.
            if (Get-Process -Id $OtherScript -ErrorAction SilentlyContinue) {
                Write-Host -Object "[Error] This script is already running in another process with the process id (PID) '$OtherScript'."
                exit 1
            }
        } catch {
            # If there is an error accessing the lock file, display an error message and exit.
            Write-Host -Object "[Error] Unable to access the lock file at '$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    # Attempt to write the current process ID to the lock file, preventing multiple instances of the script from running.
    try {
        [System.Diagnostics.Process]::GetCurrentProcess().Id | Out-File -FilePath "$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt" -Force -ErrorAction Stop
    } catch {
        # If the lock file cannot be created, display an error message and exit.
        Write-Host -Object "[Error] Failed to create lock file at '$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt'."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    #endregion
    #region Display Message
    $TotalMessageTime = $($DurationToPerformTests * 60 / 2)
    $TotalCollectionTime = $DurationToPerformTests

    if ($DisplayUserMessage) {
        try {
            Write-Host -Object "Checking for currently logged-in users."
            $QuserOutput = Invoke-LegacyConsoleTool -FilePath "$env:WINDIR\System32\quser.exe" -ErrorVariable "QUserErrors" -ErrorAction SilentlyContinue
            if ($QUserErrors) {
                $QUserErrors | ForEach-Object { Write-Host -Object "[Warning] $($_.Exception.Message)" }
                $QUserErrors = $Null
            }

            $i = 0
            $CurrentlyLoggedInUsers = $QuserOutput | Where-Object { $_.Trim() } | ForEach-Object {
                # Skip the first line (header) and process only the data lines
                if ($i -ne 0 -and $_.Length -ge 65) {
                    # Extract the relevant columns using fixed-width positions
                    [PSCustomObject]@{
                        Username    = ($_.Substring(0, 21).Trim() -replace '^>')
                        SessionName = $_.Substring(21, 21).Trim()
                        ID          = $_.Substring(40, 5).Trim()
                        State       = $_.Substring(45, 10).Trim()
                        IdleTime    = $_.Substring(55, 10).Trim()
                        LogonTime   = $_.Substring(65).Trim()
                    }
                }

                $i++
            }
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Unable to check for currently logged-in users."
            exit 1
        }
    }

    if ($DisplayUserMessage -and $CurrentlyLoggedInUsers) {
        $CurrentlyLoggedInUsers = $Null

        # Define arguments for the 'msg.exe' command to display a system message to the user.
        $MSGArguments = @(
            "*"
            "/TIME:$TotalMessageTime"
            "/V"
            "System performance metrics are currently being collected. Collection should complete in approximately $TotalCollectionTime minutes and the results will be sent to your IT Administrator. Please do not restart the computer until this collection has completed."
        )

        # Attempt to display the system message to all users.
        try {
            Write-Host -Object "Sending message to all users."

            # Start the 'msg.exe' process with the arguments defined above.
            Invoke-LegacyConsoleTool -FilePath "$env:WINDIR\System32\msg.exe" -ArgumentList $MSGArguments -ErrorAction Stop
        } catch {
            # If the 'msg.exe' process fails to start, output an error message and exit with a failure code.
            Write-Host -Object "[Error] Failed to send message to all users."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        # Output the exit code of the 'msg.exe' process.
        Write-Host -Object "ExitCode: $LASTEXITCODE"

        # If the exit code is non-zero (indicating an error occurred), display an error message.
        if ($LASTEXITCODE -ne 0) {
            Write-Host -Object "[Error] ExitCode does not indicate success."
            exit 1
        }
    }

    #endregion
    #region Last Reboot

    # Get the last reboot time of the system.
    try {
        $LastStartTime = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop | Select-Object -ExpandProperty LastBootUpTime
    } catch {
        Write-Host -Object "[Error] Failed to get last start up time."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        $ExitCode = 1
    }

    # If the 'DaysSinceLastReboot' parameter is set, calculate the time difference since the last reboot.
    if ($DaysSinceLastReboot -ge 0) {
        $TimeDifference = New-TimeSpan -Start $LastStartTime -End (Get-Date)

        # If the time since the last reboot exceeds the limit, display an alert to the user.
        if ($TimeDifference.TotalDays -gt $DaysSinceLastReboot) {
            Write-Host -Object "[Alert] This computer was last started on $($LastStartTime.ToShortDateString()) at $($LastStartTime.ToShortTimeString()) which was $([math]::Round($TimeDifference.TotalDays,2)) days ago."
            $ExceededLastStartupLimit = $True
        }
    }

    #endregion
    #region Event Log

    # Initialize an empty list to store event logs.
    $EventLogs = New-Object System.Collections.Generic.List[object]

    # Define XML queries for Application, Security, Setup, and System event logs that have error level events (Level=2).
    [xml]$ApplicationXML = @"
<QueryList>
  <Query Id="0" Path="Application">
    <Select Path="Application">*[System[(Level=2)]]</Select>
  </Query>
</QueryList>
"@

    [xml]$SecurityLogs = @"
<QueryList>
  <Query Id="0" Path="Application">
    <Select Path="Security">*[System[(Level=2)]]</Select>
  </Query>
</QueryList>
"@

    [xml]$SetupLogs = @"
<QueryList>
  <Query Id="0" Path="Application">
    <Select Path="Setup">*[System[(Level=2)]]</Select>
  </Query>
</QueryList>
"@

    [xml]$SystemLogs = @"
<QueryList>
  <Query Id="0" Path="Application">
    <Select Path="System">*[System[(Level=2)]]</Select>
  </Query>
</QueryList>
"@

    # If the 'NumberOfEvents' parameter is set, collect the specified number of error logs from each log category.
    if ($NumberOfEvents) {
        Write-Host -Object "`nCollecting event logs."

        # Collect logs from each category and store them in the EventLogs list.
        Get-WinEvent -MaxEvents $NumberOfEvents -FilterXml $ApplicationXML -ErrorAction SilentlyContinue -ErrorVariable EventLogErrors | ForEach-Object { $EventLogs.Add($_) }
        Get-WinEvent -MaxEvents $NumberOfEvents -FilterXml $SecurityLogs -ErrorAction SilentlyContinue -ErrorVariable EventLogErrors | ForEach-Object { $EventLogs.Add($_) }
        Get-WinEvent -MaxEvents $NumberOfEvents -FilterXml $SetupLogs -ErrorAction SilentlyContinue -ErrorVariable EventLogErrors | ForEach-Object { $EventLogs.Add($_) }
        Get-WinEvent -MaxEvents $NumberOfEvents -FilterXml $SystemLogs -ErrorAction SilentlyContinue -ErrorVariable EventLogErrors | ForEach-Object { $EventLogs.Add($_) }

        # If any errors occurred during log collection, display warnings with the error details.
        if ($EventLogErrors) {
            $EventLogErrors | ForEach-Object {
                Write-Host -Object "[Warning] $($_.Exception.Message)"
            }
        }

        # If no error logs were found, display a warning message.
        if ($EventLogs.Count -eq 0) {
            Write-Host -Object "[Warning] No error events were found in the event log."
        } else {
            $EventLogs = $EventLogs | Select-Object LogName, ProviderName, Id, TimeCreated, Message | Sort-Object -Property TimeCreated -Descending
        }
    }

    #endregion
    #region Performance Counters

    # Display a message to the user indicating the start of the search for performance counter localizations.
    Write-Host -Object "Searching for performance counter localizations."

    # Attempt to retrieve the "Counter" property from the CurrentLanguage registry key, which contains the localized performance counter names.
    # If the retrieval fails, catch the error, display an error message, and exit the script.
    try {
        $CurrentLanguageKey = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib\CurrentLanguage" -Name "Counter" -ErrorAction Stop | Select-Object -ExpandProperty Counter
    } catch {
        Write-Host -Object "[Error] Failed to retrieve performance counter localizations."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Initialize an empty hash table to store the performance counter localizations.
    $LocalizationCounterTable = @{}

    # Loop through the array of performance counters in the registry.
    # The counter array consists of alternating key-value pairs (even indexes are keys, odd indexes are values),
    # so this loop increments by 2 to match each key with its corresponding value.
    for ($i = 0; $i -lt $CurrentLanguageKey.Length; $i += 2) {
        $LocalizationCounterTable[$CurrentLanguageKey[$i]] = $CurrentLanguageKey[$i + 1]
    }

    # Define the paths for various performance counters using the localized counter names from the hash table.
    # These paths are dynamically created by retrieving the localized names for each counter ID.
    $OverallProcessCounterPath = "\$($LocalizationCounterTable['238'])(*)\$($LocalizationCounterTable['6'])"
    $OverallMemoryCounterPath = "\$($LocalizationCounterTable['4'])\$($LocalizationCounterTable['1406'])"
    $ProcessorCounterPath = "\$($LocalizationCounterTable['230'])(*)\$($LocalizationCounterTable['142'])"
    $MemoryCounterPath = "\$($LocalizationCounterTable['230'])(*)\$($LocalizationCounterTable['1478'])"
    $IOUsageCounterPath = "\$($LocalizationCounterTable['230'])(*)\$($LocalizationCounterTable['1424'])"
    $DiskUsageCounterPath = "\$($LocalizationCounterTable['234'])(*)\$($LocalizationCounterTable['212'])"
    $NetworkUsageCounterPath = "\$($LocalizationCounterTable['510'])(*)\$($LocalizationCounterTable['388'])"

    # Notify the user that performance metrics are being collected for the specified duration.
    Write-Host -Object "Collecting performance metrics for $DurationToPerformTests minutes."

    # Collect performance metrics (CPU, memory, disk, and network usage) at a 60-second interval for the specified duration.
    $PerformanceMetrics = Get-Counter -MaxSamples $DurationToPerformTests -SampleInterval 60 -Counter $OverallProcessCounterPath, $OverallMemoryCounterPath,
    $ProcessorCounterPath, $MemoryCounterPath, $IOUsageCounterPath, $DiskUsageCounterPath, $NetworkUsageCounterPath -ErrorAction SilentlyContinue -ErrorVariable PerformanceMetricErrors

    # Extract performance metrics for CPU, memory, I/O, disk, and network usage from the collected data.
    $OverallProcessorUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match "$([Regex]::Escape($($LocalizationCounterTable['6'])))$" }
    $OverallMemoryUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match "$([Regex]::Escape($($LocalizationCounterTable['1406'])))$" }
    $ProcessorUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match "$([Regex]::Escape($($LocalizationCounterTable['142'])))$" }
    $MemoryUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match "$([Regex]::Escape($($LocalizationCounterTable['1478'])))$" }
    $IOUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match "$([Regex]::Escape($($LocalizationCounterTable['1424'])))$" }
    $DiskUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match "$([Regex]::Escape($($LocalizationCounterTable['212'])))$" }
    $NetworkUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match "$([Regex]::Escape($($LocalizationCounterTable['388'])))$" }

    # If there were errors during the collection of performance metrics, display a warning message for each error.
    if ($PerformanceMetricErrors) {
        $PerformanceMetricErrors | ForEach-Object {
            Write-Host -Object "[Warning] $($_.Exception.Message)"
        }
    }

    # Ensure that performance metrics for CPU, memory, I/O, disk, and network usage were successfully retrieved.
    # If any of the metrics are missing, display an error message and exit the script.
    if (!$OverallProcessorUsage -or !$OverallMemoryUsage -or !$ProcessorUsage -or !$MemoryUsage -or !$IOUsage -or !$DiskUsage -or !$NetworkUsage) {
        Write-Host -Object "[Error] Failed to retrieve performance metrics."
        exit 1
    }

    #endregion
    #region CPU Information

    # Retrieve CPU information such as name and clock speed (in GHz).
    try {
        $DetectedCPUs = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
        $CPUCount = ($DetectedCPUs | Measure-Object).Count

        if ($CPUCount -lt 1) {
            $CPU = "No CPU detected"
            Write-Host -Object "[Error] Failed to detect the cpu."
            $ExitCode = 1
        }

        if ($CPUCount -eq 1) {
            $CPU = "$($DetectedCPUs | Select-Object -ExpandProperty Name) $((Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -ExpandProperty MaxClockSpeed)/1000) GHz"
        }

        if ($CPUCount -gt 1) {
            $CPU = "Multiple CPUs Present ($CPUCount)"
        }

        # Retrieve the total amount of installed physical memory (RAM) in bytes and convert it to GB.
        $TotalMemoryBytes = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop | Measure-Object -Property Capacity -Sum | Select-Object -ExpandProperty Sum
        $TotalMemoryGB = "$($TotalMemoryBytes/1GB) GB"
    } catch {
        Write-Host -Object "[Error] Unable to get CPU or Memory details."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        $ExitCode = 1
    }

    # Display the CPU information.
    Write-Host -Object "`n### $CPU ###"

    # Filter and sort the relevant CPU performance metrics for the "_total" instance (overall system usage).
    $RelevantMetrics = $OverallProcessorUsage | Where-Object { $_.InstanceName -eq "_total" } | Sort-Object CookedValue

    # Calculate average, minimum, and maximum CPU usage.
    $CPUPerformance = [PSCustomObject]@{
        Avg = [math]::Round((($RelevantMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests), 2)
        Min = [math]::Round(($RelevantMetrics | Select-Object -ExpandProperty CookedValue -First 1), 2)
        Max = [math]::Round(($RelevantMetrics | Select-Object -ExpandProperty CookedValue -Last 1), 2)
    }

    # Format the CPU performance metrics for display.
    $FormattedCPUPerformance = [PSCustomObject]@{
        "CPU Average %" = "$($CPUPerformance.Avg)%"
        "CPU Minimum %" = "$($CPUPerformance.Min)%"
        "CPU Maximum %" = "$($CPUPerformance.Max)%"
    }

    # Display the formatted CPU performance metrics.
    ($FormattedCPUPerformance | Format-Table -AutoSize | Out-String).Trim() | Write-Host

    #endregion
    #region Memory Information

    # Display memory usage header.
    Write-Host -Object "`n### Memory Usage ###"
    Write-Host -Object "Total Memory Installed: $TotalMemoryGB"

    # Filter and sort the relevant memory usage metrics.
    $RelevantMetrics = $OverallMemoryUsage | Sort-Object CookedValue

    # Calculate average, minimum, and maximum memory usage.
    $MemoryPerformance = [PSCustomObject]@{
        Avg = [math]::Round((($RelevantMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests), 2)
        Min = [math]::Round(($RelevantMetrics | Select-Object -ExpandProperty CookedValue -First 1), 2)
        Max = [math]::Round(($RelevantMetrics | Select-Object -ExpandProperty CookedValue -Last 1), 2)
    }

    # Format the memory performance metrics for display.
    $OverallMemoryMetrics = [PSCustomObject]@{
        "RAM Average %" = "$($MemoryPerformance.Avg)%"
        "RAM Minimum %" = "$($MemoryPerformance.Min)%"
        "RAM Maximum %" = "$($MemoryPerformance.Max)%"
    }

    # Display the formatted memory performance metrics.
    ($OverallMemoryMetrics | Format-Table -AutoSize | Out-String).Trim() | Write-Host

    #endregion
    #region Top 5 CPU Processes

    # Display the header for the top 5 CPU processes.
    Write-Host "`n### Top 5 CPU Processes ###"

    # Get a unique list of all process names excluding the "_total" instance.
    $AllProcessNames = $ProcessorUsage | Where-Object { $_.InstanceName -ne "_total" } | Sort-Object InstanceName -Unique | Select-Object -ExpandProperty InstanceName

    # Initialize an empty list to store process metrics.
    $Processes = New-Object -TypeName System.Collections.Generic.List[object]

    # Loop through each process name to calculate the CPU usage (min, max, avg) for each process.
    foreach ($ProcessName in $AllProcessNames) {
        $RelevantMetrics = $ProcessorUsage | Where-Object { $_.InstanceName -eq $ProcessName }

        # Group metrics by timestamp and calculate the total CPU usage for each timestamp.
        $GroupedMetrics = $RelevantMetrics | Group-Object Timestamp | Select-Object @{Name = "InstanceName"; Expression = { $ProcessName } }, @{Name = "CookedValue"; Expression = { $_.Group | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum } } | Sort-Object CookedValue

        # Add the CPU usage metrics (min, max, avg) for each process to the list.
        $Processes.Add(
            [PSCustomObject]@{
                "InstanceName" = $ProcessName
                "Min"          = $GroupedMetrics | Select-Object -ExpandProperty CookedValue -First 1
                "Max"          = $GroupedMetrics | Select-Object -ExpandProperty CookedValue -Last 1
                "Avg"          = ($GroupedMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests
            }
        )
    }

    # Sort the processes by average CPU usage in descending order and select the top 5.
    $Top5CPUProcesses = $Processes | Sort-Object "Avg" -Descending | Select-Object -First 5

    # Format the top 5 CPU processes for display.
    $FormattedProcesses = $Top5CPUProcesses | ForEach-Object {
        [PSCustomObject]@{
            "Process Name"       = $_.InstanceName
            "Average CPU % Used" = "$([math]::Round($_.Avg, 2))%"
            "Minimum CPU % Used" = "$([math]::Round($_.Min, 2))%"
            "Maximum CPU % Used" = "$([math]::Round($_.Max, 2))%"
        }
    }

    # Display the formatted CPU process usage metrics.
    ($FormattedProcesses | Format-Table -AutoSize | Out-String).Trim() | Write-Host

    #endregion
    #region Top 5 RAM Processes

    # Display the header for the top 5 RAM processes.
    Write-Host -Object "`n### Top 5 RAM Processes ###"

    # Get a unique list of process names that are not "_total" or "memory compression".
    $AllMemoryProcessNames = $MemoryUsage | Where-Object { $_.InstanceName -ne "_total" -and $_.InstanceName -ne "memory compression" } | Sort-Object InstanceName -Unique | Select-Object -ExpandProperty InstanceName

    # Initialize an empty list to store memory process metrics.
    $MemoryProcesses = New-Object -TypeName System.Collections.Generic.List[object]

    # Loop through each process to calculate the memory usage (min, max, avg) for each process.
    foreach ($ProcessName in $AllMemoryProcessNames) {
        $RelevantMetrics = $MemoryUsage | Where-Object { $_.InstanceName -eq $ProcessName }

        # Group metrics by timestamp and calculate the total memory usage for each timestamp.
        $GroupedMetrics = $RelevantMetrics | Group-Object Timestamp | Select-Object @{Name = "InstanceName"; Expression = { $ProcessName } }, @{Name = "CookedValue"; Expression = { $_.Group | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum } } | Sort-Object CookedValue

        # Add the memory usage metrics (min, max, avg) for each process to the list.
        $MemoryProcesses.Add(
            [PSCustomObject]@{
                "InstanceName" = $ProcessName
                "Min"          = $GroupedMetrics | Select-Object -ExpandProperty CookedValue -First 1
                "Max"          = $GroupedMetrics | Select-Object -ExpandProperty CookedValue -Last 1
                "Avg"          = ($GroupedMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests
            }
        )
    }

    # Sort the processes by average memory usage in descending order and select the top 5.
    $Top5RAMProcesses = $MemoryProcesses | Sort-Object "Avg" -Descending | Select-Object -First 5 | ForEach-Object {
        if (!$TotalMemoryBytes) {
            return
        }

        [PSCustomObject]@{
            "InstanceName" = $_.InstanceName
            "Min"          = $_.Min / $TotalMemoryBytes * 100
            "Max"          = $_.Max / $TotalMemoryBytes * 100
            "Avg"          = $_.Avg / $TotalMemoryBytes * 100
        }
    }

    # Format the top 5 RAM processes for display.
    $FormattedMemoryProcesses = $Top5RAMProcesses | ForEach-Object {
        if (!$TotalMemoryBytes) {
            return
        }

        [PSCustomObject]@{
            "Process Name"       = $_.InstanceName
            "Average RAM % Used" = "$([math]::Round($_.Avg, 2))%"
            "Minimum RAM % Used" = "$([math]::Round($_.Min, 2))%"
            "Maximum RAM % Used" = "$([math]::Round($_.Max, 2))%"
        }
    }

    # Display the formatted memory process usage metrics.
    ($FormattedMemoryProcesses | Format-Table -AutoSize | Out-String).Trim() | Write-Host

    #endregion
    #region Network Usage

    # Display the header for network usage.
    Write-Host -Object "`n### Network Usage ###"

    # Get a unique list of network interfaces and initialize an empty list for storing network metrics.
    $NetworkInterfaces = $NetworkUsage | Sort-Object InstanceName -Unique | Select-Object -ExpandProperty InstanceName
    $NetworkInterfaceUsage = New-Object -TypeName System.Collections.Generic.List[object]

    # Loop through each network interface to calculate the network usage (min, max, avg) for each interface.
    foreach ($NetworkInterface in $NetworkInterfaces) {
        $RelevantMetrics = $NetworkUsage | Where-Object { $_.InstanceName -eq $NetworkInterface } | Sort-Object CookedValue

        try {
            # Correct the network interface name if necessary to match the system's adapter description.
            if (!(Get-NetAdapter -ErrorAction Stop | Where-Object { $_.InterfaceDescription -eq $NetworkInterface })) {
                $NetworkInterface = $NetworkInterface -replace '\[', '(' -replace '\]', ')'
            }

            # Retrieve the network adapter details and determine if it's wired, Wi-Fi, or another type.
            $NetAdapter = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.InterfaceDescription -eq $NetworkInterface } | Select-Object -First 1
            if (!$NetAdapter.MacAddress) {
                continue
            }

            switch -Wildcard ($NetAdapter.MediaType) {
                "802.3" { $AdapterType = "Wired" }
                "*802.11" { $AdapterType = "Wi-Fi" }
                default { $AdapterType = "Other" }
            }
        } catch {
            Write-Host -Object "[Error] Failed to get details on the network interface '$NetworkInterface'."
            Write-Host -Object "[Error] $($_.Exception.Message)`n"
            $ExitCode = 1
            continue
        }

        # Add the network adapter usage metrics to the list.
        $NetworkInterfaceUsage.Add(
            [PSCustomObject]@{
                "NetworkAdapter" = $NetworkInterface
                "MacAddress"     = $NetAdapter.MacAddress
                "Type"           = $AdapterType
                "Min"            = $RelevantMetrics | Select-Object -ExpandProperty CookedValue -First 1
                "Max"            = $RelevantMetrics | Select-Object -ExpandProperty CookedValue -Last 1
                "Avg"            = ($RelevantMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests
            }
        )
    }

    # Format the network usage metrics for display.
    $FormattedNetworkUsage = $NetworkInterfaceUsage | Sort-Object "Avg" -Descending | ForEach-Object {
        [PSCustomObject]@{
            "NetworkAdapter"          = $_.NetworkAdapter
            "MacAddress"              = $_.MacAddress
            "Type"                    = $_.Type
            "Average Sent & Received" = "$([math]::Round(($_.Avg / 1MB * 8), 2)) Mbps"
            "Minimum Sent & Received" = "$([math]::Round(($_.Min / 1MB * 8), 2)) Mbps"
            "Maximum Sent & Received" = "$([math]::Round(($_.Max / 1MB * 8), 2)) Mbps"
        }
    }

    # Display the formatted network usage metrics.
    ($FormattedNetworkUsage | Format-List | Out-String).Trim() | Write-Host

    #endregion
    #region Disk Usage

    # Display the header for disk usage.
    Write-Host -Object "`n### Disk Usage ###"

    # Get a unique list of relevant disks and initialize an empty list for storing disk metrics.
    $RelevantDisks = $DiskUsage | Where-Object { $_.InstanceName -ne "_total" } | Sort-Object InstanceName -Unique | Select-Object -ExpandProperty InstanceName
    $DiskMetrics = New-Object -TypeName System.Collections.Generic.List[object]

    try {
        $AllDiskNumbers = Get-Partition -ErrorAction Stop | Select-Object -ExpandProperty DiskNumber -Unique
    } catch {
        Write-Host -Object "[Error] Unable to retrieve disk numbers."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        $ExitCode = 1
    }

    # Loop through each disk to calculate the disk usage (min, max, avg) for each disk.
    foreach ($RelevantDisk in $RelevantDisks) {
        $RelevantMetrics = $DiskUsage | Where-Object { $_.InstanceName -eq $RelevantDisk } | Sort-Object CookedValue

        # Parse the disk number and drive letter from the instance name.
        $DiskNumber = $RelevantDisk -split '\s' | Where-Object { $_ -match "^[0-9]$" }
        $DriveLetters = ($RelevantDisk -split '\s' | Where-Object { $_ -match "^[A-z]:$" }) -replace ':'

        # Retrieve the physical disk based on the provided DiskNumber.
        $PhysicalDisk = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DeviceId -eq $DiskNumber }

        # Check if the disk number is part of the list of all disk numbers.
        if ($AllDiskNumbers -and $AllDiskNumbers -notcontains $DiskNumber) {

            # If the physical disk has a FriendlyName (meaning it was found), warn that no partitions were found on this disk.
            if ($PhysicalDisk.FriendlyName) {
                Write-Host -Object "[Warning] No partitions found on disk '$($PhysicalDisk.FriendlyName)'."
            } else {
                # If the physical disk has no FriendlyName, display a warning message using the DiskNumber.
                Write-Host -Object "[Warning] No partitions found on disk '$DiskNumber'."
            }

            Write-Host -Object ""

            # Continue to the next iteration in the loop, skipping the remaining code for this disk number.
            continue
        }

        # Attempt to retrieve the partitions for the specified disk number.
        try {
            $Partitions = Get-Partition -DiskNumber $DiskNumber -ErrorAction Stop
        } catch {
            # If an error occurs while getting the partitions, display an error message.
            Write-Host -Object "[Error] Accessing Partitions on disk '$DiskNumber'"

            # Display the exception message from the caught error.
            Write-Host -Object "[Error] $($_.Exception.Message)`n"

            # Set the exit code to indicate an error occurred.
            $ExitCode = 1

            # Continue to the next iteration in the loop, skipping further actions for this disk number.
            continue
        }

        # Retrieve partition information and add the disk usage metrics to the list.
        foreach ($DriveLetter in $DriveLetters) {
            $Partitions | Where-Object { $_.DriveLetter -eq $DriveLetter } | ForEach-Object {
                try {
                    $FreeSpace = Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -eq $DriveLetter } | Select-Object -ExpandProperty SizeRemaining
                    $TotalSize = Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -eq $DriveLetter } | Select-Object -ExpandProperty Size
                } catch {
                    Write-Host -Object "[Error] Unable to determine the total size or free space of drive '$DriveLetter'."
                    Write-Host -Object "[Error] $($_.Exception.Message)`n"
                    $ExitCode = 1
                    continue
                }

                $FreeSpaceGB = [math]::Round(($FreeSpace / 1GB), 2)
                $FreeSpacePercent = [math]::Round(($FreeSpace / $TotalSize * 100), 2)
                $TotalSpaceGB = [math]::Round(($TotalSize / 1GB), 2)

                # Add the disk metrics to the list.
                $DiskMetrics.Add(
                    [PSCustomObject]@{
                        "DriveLetter"      = $_.DriveLetter
                        "FreeSpaceGB"      = $FreeSpaceGB
                        "FreeSpacePercent" = $FreeSpacePercent
                        "TotalSpace"       = "$TotalSpaceGB GB"
                        "PhysicalDisk"     = $PhysicalDisk | Select-Object -ExpandProperty FriendlyName
                        "MediaType"        = $PhysicalDisk | Select-Object -ExpandProperty MediaType
                        "Min"              = $RelevantMetrics | Select-Object -ExpandProperty CookedValue -First 1
                        "Max"              = $RelevantMetrics | Select-Object -ExpandProperty CookedValue -Last 1
                        "Avg"              = ($RelevantMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests
                    }
                )
            }
        }
    }

    # Add the disk metrics to the list.
    $FormattedDiskMetrics = $DiskMetrics | Sort-Object "Avg" -Descending | ForEach-Object {
        [PSCustomObject]@{
            "DriveLetter"  = $_.DriveLetter
            "FreeSpace"    = "$($_.FreeSpaceGB) GB ($($_.FreeSpacePercent)%)"
            "TotalSpace"   = $_.TotalSpace
            "PhysicalDisk" = $_.PhysicalDisk
            "MediaType"    = $_.MediaType
            "Average IOPS" = "$([math]::Round(($_.Avg), 2)) IOPS"
            "Minimum IOPS" = "$([math]::Round(($_.Min), 2)) IOPS"
            "Maximum IOPS" = "$([math]::Round(($_.Max), 2)) IOPS"
        }
    }

    # Display the formatted disk usage metrics.
    ($FormattedDiskMetrics | Format-List | Out-String).Trim() | Write-Host

    #endregion
    #region IO Processes

    # Display the header for top 5 I/O processes (network and disk combined).
    Write-Host -Object "`n### Top 5 IO Processes (Network & Disk Combined) ###"

    # Get a unique list of I/O process names excluding the "_total" instance.
    $AllIOProcessNames = $IOUsage | Where-Object { $_.InstanceName -ne "_total" } | Sort-Object InstanceName -Unique | Select-Object -ExpandProperty InstanceName
    $IOProcesses = New-Object -TypeName System.Collections.Generic.List[object]

    # Loop through each process to calculate the I/O usage (min, max, avg) for each process.
    foreach ($ProcessName in $AllIOProcessNames) {
        $RelevantMetrics = $IOUsage | Where-Object { $_.InstanceName -eq $ProcessName }

        # Group metrics by timestamp and calculate the total I/O usage for each timestamp.
        $GroupedMetrics = $RelevantMetrics | Group-Object Timestamp | Select-Object @{Name = "InstanceName"; Expression = { $ProcessName } }, @{Name = "CookedValue"; Expression = { $_.Group | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum } } | Sort-Object CookedValue

        # Add the I/O usage metrics to the list.
        $IOProcesses.Add(
            [PSCustomObject]@{
                "InstanceName" = $ProcessName
                "Min"          = $GroupedMetrics | Select-Object -ExpandProperty CookedValue -First 1
                "Max"          = $GroupedMetrics | Select-Object -ExpandProperty CookedValue -Last 1
                "Avg"          = ($GroupedMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests
            }
        )
    }

    # Sort the I/O processes by average I/O usage and select the top 5.
    $Top5IOProcesses = $IOProcesses | Sort-Object "Avg" -Descending | Select-Object -First 5

    # Format the top 5 I/O processes for display.
    $FormattedIOProcesses = $Top5IOProcesses | ForEach-Object {
        [PSCustomObject]@{
            "Process Name"    = $_.InstanceName
            "Average IO Used" = "$([math]::Round(($_.Avg / 1MB * 8), 4)) Mbps"
            "Minimum IO Used" = "$([math]::Round(($_.Min / 1MB * 8), 4)) Mbps"
            "Maximum IO Used" = "$([math]::Round(($_.Max / 1MB * 8), 4)) Mbps"
        }
    }

    # Display the formatted I/O process usage metrics.
    ($FormattedIOProcesses | Format-Table -AutoSize | Out-String).Trim() | Write-Host

    #endregion
    #region WinSat Assessment

    # Inform the user that WinSAT assessments are running.
    Write-Host -Object "`nRetrieving WinSAT assessment data."
    Write-Host -Object "More info: https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-8.1-and-8/hh825488(v=win.10)"

    # Retrieve the WinSAT assessment scores.
    try {
        $WinSatScores = Get-CimInstance -ClassName Win32_WinSAT -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] Unable to retrieve WinSat assessment results."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        $ExitCode = 1
    }

    # Handle the different possible states of the WinSAT assessment.
    switch ($WinSatScores.WinSATAssessmentState) {
        0 { Write-Host -Object "[Error] WinSAT assessment data is not available on this computer. Is this computer a virtual machine?" ; $ExitCode = 1 }
        1 { Write-Host -Object "Successfully retrieved assessment data." }
        2 { Write-Host -Object "[Warning] The WinSAT assessment data does not match the current computer configuration." }
        3 { Write-Host -Object "[Error] WinSAT assessment data is not available on this computer. Is this computer a virtual machine?" ; $ExitCode = 1 }
        4 { Write-Host -Object "[Error] The WinSAT assessment data is not valid!" ; $ExitCode = 1 }
        default {
            Write-Host -Object "[Error] WinSAT assessment data is not available on this computer. Is this computer a virtual machine?" ; $ExitCode = 1
        }
    }

    # If the WinSAT assessment state is valid, display the assessment scores.
    $ValidAssessmentStates = "1", "2"
    if ($ValidAssessmentStates -contains $WinSatScores.WinSATAssessmentState) {
        Write-Host -Object "`n### WinSAT Scores ###"
        ($WinSatScores | Format-Table -Property CPUScore, D3DScore, DiskScore, GraphicsScore, MemoryScore | Out-String).Trim() | Write-Host
    }

    #endregion
    #region Speed Test
    if ($PerformInternetSpeedTest) {
        Write-Host -Object "`n=============================================================================="
        Write-Host -Object "This test is provided by Measurement Lab (M-Lab) and is subject to their"
        Write-Host -Object "Acceptable Use Policy. By proceeding, you consent to the collection of network"
        Write-Host -Object "performance data, including your IP address, which will be publicly available"
        Write-Host -Object "to support open internet research. For details, please review M-Lab's"
        Write-Host -Object "Acceptable Use Policy at https://www.measurementlab.net/aup/."
        Write-Host -Object "==============================================================================`n"

        # Generates an RFC 9562 compatible UUID (not the same as New-GUID)
        $TestUUID = New-UUIDv7

        # Introduce a random delay between 0 to 60 minutes in 2-minute increments
        $MaximumDelay = 60
        $TimeChunks = 2
        $Parts = ($MaximumDelay / $TimeChunks) + 1
        $RandomNumber = Get-Random -Minimum 0 -Maximum $Parts
        $Minutes = $RandomNumber * $TimeChunks

        #region - Sleep Before Test

        # If $RandomSleepForSpeedTest is enabled, pause execution for the calculated delay
        if ($RandomSleepForSpeedTest) {
            Write-Host -Object "Waiting for $Minutes minutes before performing the Speedtest as requested.`n"
            Start-Sleep -Seconds $($Minutes * 60)
        }

        #endregion
        #region - Retrieve Test URL

        # Retrieve the nearest servers test url
        try {
            Write-Host -Object ""
            $ThroughputTestInfo = Get-TestURLs -Type "throughput" -ErrorAction Stop

            $ThroughputServerHostname = $ThroughputTestInfo | Select-Object -ExpandProperty "ThroughputServerHostname"
            $DownloadTestURL = $ThroughputTestInfo | Select-Object -ExpandProperty "DownloadTestURL"
            $UploadTestURL = $ThroughputTestInfo | Select-Object -ExpandProperty "UploadTestURL"
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to retrieve the url for the download test."
            exit 1
        }

        #endregion
        #region - Network adapter

        # Retrieve the network adapter being used for the speed test
        Write-Host -Object "`nRetrieving the network adapter to be used for the test."
        try {
            # Perform a test connection to the speed test server to determine the interface
            $TestPing = Test-NetConnection -ComputerName $ThroughputServerHostname -ErrorAction Stop

            # If an interface alias is found, get its corresponding network adapter
            if ($TestPing.InterfaceAlias) {
                $Adapter = Get-NetAdapter -Name $TestPing.InterfaceAlias -ErrorAction Stop

                # Determine the adapter type (wired, Wi-Fi, or other)
                $AdapterType = switch -Wildcard ($Adapter.MediaType) {
                    "802.3" { "Wired" }
                    "*802.11" { "Wi-Fi" }
                    Default {
                        "Other"
                    }
                }

                # Format the adapter information as a string
                $AdapterString = "$($Adapter.Name) - $AdapterType"
            }

            # If the adapter was not successfully retrieved, throw an error
            if (!$Adapter) {
                throw [System.Net.NetworkInformation.NetworkInformationException]::New("Unable to retrieve the network adapter.")
            }
        } catch {
            # Handle errors related to network adapter retrieval
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to retrieve the network adapter to be used for the test."
            $ExitCode = 1
        }

        #endregion
        #region - Download Speed Test

        # Inform the user that the script is connecting to the download speed test server.
        $DownloadTestURL = $DownloadTestURL -replace '\?access_token=', "?cc=$CongestionAlgorithm&streams=$NumberOfStreams&duration=$TestDurationInMilliseconds&delay=0&bytes=$TestSize&client_session_id=$TestUUID&access_token="
        Write-Host -Object "`nConnecting to the download speed test server at '$($DownloadTestURL -replace 'token=[^&]*','token=*****')'."

        # Create a separate job for each download stream to improve performance.
        $DownloadJobs = for ($i = 0; $i -lt $NumberOfStreams; $i++) {
            Start-Job -ArgumentList $DownloadTestURL, $i -ScriptBlock {
                param(
                    $DownloadTestURL,
                    $DownloadStreamNumber
                )

                Write-Host -Object "[Download Test Stream $($DownloadStreamNumber + 1)]"

                # Function to create a WebSocket connection
                function Create-WebSocket {
                    [CmdletBinding()]
                    param (
                        [Parameter()]
                        [System.Uri]$URL,
                        [Parameter()]
                        $CancelToken
                    )

                    try {
                        # Initialize a new WebSocket client
                        $Socket = New-Object System.Net.WebSockets.ClientWebSocket

                        # Set WebSocket options
                        $Socket.Options.AddSubProtocol('net.measurementlab.throughput.v1')
                        $Socket.Options.SetBuffer(64KB, 64KB)

                        # Attempt to connect to the WebSocket server
                        $Socket.ConnectAsync($URL, $CancelToken.Token).Wait()
                    } catch [AggregateException] {
                        # Unwrap and display the actual exception
                        foreach ($innerException in $_.Exception.InnerExceptions) {
                            Write-Host "[Error] $($innerException.Message)"
                            if ($innerException.InnerException) {
                                Write-Host "[Error][Inner Exception] $($innerException.InnerException.Message)"
                            }
                        }

                        # Rethrow the error if connection fails
                        throw $_
                    } catch {
                        # Rethrow the error if connection fails
                        throw $_
                    }

                    # Return the WebSocket object
                    return $Socket
                }

                # Function to remove/close a WebSocket connection
                function Remove-WebSocket {
                    [CmdletBinding()]
                    param (
                        [Parameter()]
                        [String]$SocketName,
                        [Parameter()]
                        $Socket
                    )

                    try {
                        # Ensure the socket exists and is in an open or close-received state before closing
                        if ($Socket -and ($Socket -eq [System.Net.WebSockets.WebSocketState]::Open -or $Socket -eq [System.Net.WebSockets.WebSocketState]::CloseReceived)) {
                            $Socket.CloseAsync(
                                [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,
                                "Closing connection",
                                [Threading.CancellationToken]::None
                            ).Wait()
                        }
                    } catch {
                        # Handle errors during WebSocket closure
                        Write-Host -Object "[Error] $($_.Exception.Message)"
                        Write-Host -Object "[Error] Failed to close the websocket '$Socket'."

                        throw $_
                    } finally {
                        # Ensure the socket is properly disposed of after closure
                        if ($Socket) {
                            $Socket.Dispose()
                        }
                    }
                }

                try {
                    # Create a cancellation token to allow for graceful cancellation of WebSocket operations.
                    $CancelToken = New-Object System.Threading.CancellationTokenSource

                    # Create a WebSocket connection to the download server.
                    $DownloadSocket = Create-WebSocket -URL $DownloadTestURL -CancelToken $CancelToken -ErrorAction Stop
                } catch [AggregateException] {
                    # If an error occurs, attempt to remove/close the WebSocket before exiting.
                    Remove-WebSocket -SocketName "Download WebSocket" -Socket $DownloadSocket -ErrorAction SilentlyContinue

                    exit 1
                } catch {
                    # If an error occurs, attempt to remove/close the WebSocket before exiting.
                    Remove-WebSocket -SocketName "Download WebSocket" -Socket $DownloadSocket -ErrorAction SilentlyContinue

                    # Display error messages and exit the script.
                    Write-Host -Object "[Error] $($_.Exception.Message)"
                    Write-Host -Object "[Error] Failed to connect to the download server for the speed test."
                    exit 1
                }

                # Notify user that the download speed test is starting.
                Write-Host -Object "Starting the download speed test."

                # Define buffer size for receiving data.
                $BufferSize = 64KB
                $Buffer = New-Object 'byte[]' $BufferSize
                $TotalBytesReceived = 0

                # Start a stopwatch to measure elapsed time for the test.
                $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                # Ensure the WebSocket connection is open before proceeding.
                if ($DownloadSocket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                    Write-Host -Object "[Error] The WebSocket required for the download speed test is in an invalid state '$($DownloadSocket.State)'."
                    exit 1
                }

                # Set error handling to stop execution upon encountering an error.
                $ErrorActionPreference = "Stop"

                # Begin receiving data in a loop while the WebSocket remains open.
                do {
                    try {
                        # Define a buffer for receiving messages.
                        $ReceiveBuffer = [System.ArraySegment[byte]]($Buffer)

                        # Receive data asynchronously through the WebSocket.
                        $ReceiveResult = $DownloadSocket.ReceiveAsync($ReceiveBuffer, $CancelToken.Token).Result

                        # Handle different message types from the WebSocket.
                        switch ($ReceiveResult.MessageType) {
                            # If a close message is received, break the loop.
                            { $_ -eq [System.Net.WebSockets.WebSocketMessageType]::Close } {
                                break
                            }
                            # If binary data is received, increment the total received byte count.
                            { $_ -eq [System.Net.WebSockets.WebSocketMessageType]::Binary } {
                                $TotalBytesReceived += $ReceiveResult.Count
                            }
                            # If text data is received, convert it from JSON and store it.
                            { $_ -eq [System.Net.WebSockets.WebSocketMessageType]::Text } {
                                $MessageText = [System.Text.Encoding]::UTF8.GetString($Buffer, 0, $ReceiveResult.Count)
                                $MessageText
                            }
                        }

                        # Stop the test if it exceeds 120 seconds.
                        if ($Stopwatch.Elapsed.TotalSeconds -ge 120) {
                            Write-Host -Object "[Error] The download speed test timed out."
                            exit 1
                        }
                    }
                    # Handle aggregate exceptions (multiple errors occurring simultaneously).
                    catch [AggregateException] {
                        foreach ($innerException in $_.Exception.InnerExceptions) {
                            Write-Host -Object "[Warning] $($innerException.Message)"

                            if ($innerException.InnerException) {
                                Write-Host -Object "[Warning][Inner Exception] $($innerException.InnerException.Message)"
                            }
                        }

                        # Attempt to reconnect the download WebSocket after an error.
                        Write-Host -Object "Attempting to reconnect the download test WebSocket."
                        Remove-WebSocket -SocketName "Download WebSocket" -Socket $DownloadSocket -ErrorAction SilentlyContinue

                        try {
                            $CancelToken = New-Object System.Threading.CancellationTokenSource
                            $DownloadSocket = Create-WebSocket -URL $DownloadTestURL -CancelToken $CancelToken -ErrorAction Stop
                        } catch {
                            Write-Host -Object "[Error] $($_.Exception.Message)"
                            Write-Host -Object "[Error] Failed to reconnect the download test websocket."
                            exit 1
                        }

                        # Reset the received byte count.
                        $TotalBytesReceived = 0
                    }
                    # Handle general exceptions and attempt a reconnect.
                    catch {
                        Write-Host -Object "[Warning] $($_.Exception.Message)"

                        Write-Host -Object "Attempting to reconnect the download test WebSocket."
                        Remove-WebSocket -SocketName "Download WebSocket" -Socket $DownloadSocket -ErrorAction SilentlyContinue

                        try {
                            $CancelToken = New-Object System.Threading.CancellationTokenSource
                            $DownloadSocket = Create-WebSocket -URL $DownloadTestURL -CancelToken $CancelToken -ErrorAction Stop
                        } catch {
                            Write-Host -Object "[Error] $($_.Exception.Message)"
                            Write-Host -Object "[Error] Failed to reconnect the download test websocket."
                            exit 1
                        }

                        # Reset the received byte count.
                        $TotalBytesReceived = 0
                    }
                } while ($DownloadSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open)

                # Restore the default error handling behavior.
                $ErrorActionPreference = "Continue"

                # Stop the stopwatch as the test has completed.
                $Stopwatch.Stop()
                $TotalSeconds = [math]::Round($Stopwatch.Elapsed.TotalSeconds, 2)
                Write-Host -Object "Download test completed in $TotalSeconds seconds. Total bytes received: $TotalBytesReceived"

                # Attempt to close and remove the WebSocket connection.
                try {
                    Remove-WebSocket -SocketName "Download WebSocket" -Socket $DownloadSocket -ErrorAction Stop
                } catch {
                    Write-Host -Object "[Error] $($_.Exception.Message)"
                    Write-Host -Object "[Error] Failed to close the WebSocket used for the download speed test."
                    $ExitCode = 1
                }
            }
        }

        #endregion
        #region - Parse Results

        # Wait for all background download jobs to complete before proceeding
        $DownloadJobs | Wait-Job | Out-Null

        # Initialize lists to store received messages, UUIDs, and bytes received
        $DownloadTestReceivedMessages = New-Object System.Collections.Generic.List[object]
        $DownloadJobReceivedMessages = New-Object System.Collections.Generic.List[object]

        # Process results from each download job
        for ($i = 0; $i -lt $NumberOfStreams; $i++) {
            # Retrieve job results and convert from JSON format
            $DownloadJobReceivedMessages = $DownloadJobs[$i] | Receive-Job -ErrorAction SilentlyContinue -ErrorVariable "DownloadJobErrors" | ConvertFrom-Json

            # Extract the unique identifier (UUID) from the received messages
            $UUID = $DownloadJobReceivedMessages | Where-Object { $_.UUID } | Select-Object -ExpandProperty "UUID"

            # Loop through all received messages and ensure each one has a UUID
            $DownloadJobReceivedMessages | ForEach-Object {
                if (!($_.UUID)) {
                    # If a message does not have a UUID, assign it the extracted UUID
                    $_ | Add-Member -MemberType NoteProperty -Name "UUID" -Value $UUID
                }

                # Store the processed message
                $DownloadTestReceivedMessages.Add($_)
            }
        }

        # Check if any errors occurred while retrieving job results
        $DownloadJobFailures = $DownloadJobs | Get-Job | Where-Object { $_.State -ne "Completed" }

        # Attempt to remove all download jobs forcefully to clean up resources.
        try {
            $DownloadJobs | Remove-Job -Force -ErrorAction Stop
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to remove background task(s) used to test the download speed."
            $ExitCode = 1
        }

        # Check if any errors occurred during the download test.
        if ($DownloadJobFailures -or $DownloadJobErrors) {
            Write-Host -Object "[Error] Errors were encountered while testing the download speed."

            # If specific errors were captured, print them to the console.
            if ($DownloadJobErrors) {
                $DownloadJobErrors | ForEach-Object { Write-Host -Object "[Error] $($_.Exception.Message)" }
            }

            $ExitCode = 1
        }

        # Group the received messages by UUID, as each download test instance should have a unique identifier.
        $GroupedTests = $DownloadTestReceivedMessages | Group-Object -Property UUID

        # Extract the last received message from each download test, which likely contains the final statistics.
        $LastMessageOfEachDownloadTest = $GroupedTests | ForEach-Object {
            $_.Group | Sort-Object ElapsedTime | Select-Object -Last 1
        }

        # Validate that at least some bytes were received and elapsed time exists
        if (!$LastMessageOfEachDownloadTest.Network.BytesSent -or !$DownloadTestReceivedMessages.ElapsedTime) {
            Write-Host -Object "[Error] Failed to retrieve the elapsed time or the bytes received. Unable to calculate the download speed."
            $ExitCode = 1
        }

        # Retrieve the number of bytes received and elapsed time from the last message.
        $DownloadElapsedTime = $DownloadTestReceivedMessages.ElapsedTime | Sort-Object | Select-Object -Last 1
        try {
            $BytesReceivedForTest = $LastMessageOfEachDownloadTest.Network.BytesSent | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to calculate the total bytes received."
            $ExitCode = 1
        }

        # Calculate the download speed in Mbps (megabits per second).
        $DownloadSpeedMbps = [math]::Round((($BytesReceivedForTest * 8) / $DownloadElapsedTime), 2)

        #endregion
        #region - Upload Speed Test

        # Notify the user that the script is connecting to the upload speed test server.
        $UploadTestURL = $UploadTestURL -replace '\?access_token=', "?cc=$CongestionAlgorithm&streams=$NumberOfStreams&duration=$TestDurationInMilliseconds&delay=0&bytes=$TestSize&client_session_id=$TestUUID&access_token="
        Write-Host -Object "`nConnecting to the upload speed test server at '$($UploadTestURL -replace 'token=[^&]*','token=*****')'."

        # Create a separate job for each upload stream to improve performance.
        $UploadJobs = for ($i = 0; $i -lt $NumberOfStreams; $i++) {
            Start-Job -ArgumentList $UploadTestURL, $i -ScriptBlock {
                param(
                    $UploadTestURL,
                    $UploadStreamNumber
                )

                Write-Host -Object "[Upload Test Stream $($UploadStreamNumber + 1)]"

                # Function to create a WebSocket connection
                function Create-WebSocket {
                    [CmdletBinding()]
                    param (
                        [Parameter()]
                        [System.Uri]$URL,
                        [Parameter()]
                        $CancelToken
                    )

                    try {
                        # Initialize a new WebSocket client
                        $Socket = New-Object System.Net.WebSockets.ClientWebSocket

                        # Set WebSocket options
                        $Socket.Options.AddSubProtocol('net.measurementlab.throughput.v1')
                        $Socket.Options.SetBuffer(64KB, 64KB)

                        # Attempt to connect to the WebSocket server
                        $Socket.ConnectAsync($URL, $CancelToken.Token).Wait()
                    } catch [AggregateException] {
                        # Unwrap and display the actual exception
                        foreach ($innerException in $_.Exception.InnerExceptions) {
                            Write-Host "[Error] $($innerException.Message)"
                            if ($innerException.InnerException) {
                                Write-Host "[Error][Inner Exception] $($innerException.InnerException.Message)"
                            }
                        }

                        # Rethrow the error if connection fails
                        throw $_
                    } catch {
                        # Rethrow the error if connection fails
                        throw $_
                    }

                    # Return the WebSocket object
                    return $Socket
                }

                # Function to remove/close a WebSocket connection
                function Remove-WebSocket {
                    [CmdletBinding()]
                    param (
                        [Parameter()]
                        [String]$SocketName,
                        [Parameter()]
                        $Socket
                    )

                    try {
                        # Ensure the socket exists and is in an open or close-received state before closing
                        if ($Socket -and ($Socket -eq [System.Net.WebSockets.WebSocketState]::Open -or $Socket -eq [System.Net.WebSockets.WebSocketState]::CloseReceived)) {
                            $Socket.CloseAsync(
                                [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,
                                "Closing connection",
                                [Threading.CancellationToken]::None
                            ).Wait()
                        }
                    } catch {
                        # Handle errors during WebSocket closure
                        Write-Host -Object "[Error] $($_.Exception.Message)"
                        Write-Host -Object "[Error] Failed to close the websocket '$Socket'."

                        throw $_
                    } finally {
                        # Ensure the socket is properly disposed of after closure
                        if ($Socket) {
                            $Socket.Dispose()
                        }
                    }
                }

                try {
                    # Create a cancellation token source to allow for cancellation of the upload test.
                    $CancelToken = New-Object System.Threading.CancellationTokenSource

                    # Establish a WebSocket connection to the upload server
                    $UploadSocket = Create-WebSocket -URL $UploadTestURL -CancelToken $CancelToken -ErrorAction Stop
                } catch [AggregateException] {
                    # If the connection fails, attempt to remove/close the WebSocket.
                    Remove-WebSocket -SocketName "Upload WebSocket" -Socket $UploadSocket -ErrorAction SilentlyContinue

                    exit 1
                } catch {
                    # If the connection fails, attempt to remove/close the WebSocket.
                    Remove-WebSocket -SocketName "Upload WebSocket" -Socket $UploadSocket -ErrorAction SilentlyContinue

                    # Output an error message and exit the script.
                    Write-Host -Object "[Error] $($_.Exception.Message)"
                    Write-Host -Object "[Error] Failed to connect to the upload server for the speed test."
                    exit 1
                }

                # Notify the user that the upload speed test is beginning.
                Write-Host -Object "Performing the upload speed test."

                # Define the buffer size for data transmission.
                $BufferSize = 64KB
                $Buffer = New-Object 'byte[]' $BufferSize

                # Create a random byte generator and fill the buffer with random data.
                $Random = New-Object System.Random
                $Random.NextBytes($Buffer)

                # Initialize a counter for the total bytes sent.
                $TotalBytesSent = 0

                # Start a stopwatch to measure the elapsed time for the test.
                $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                # Ensure the WebSocket connection is open before proceeding with the test.
                if ($UploadSocket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                    Write-Host -Object "[Error] The WebSocket required for the upload speed test is in an invalid state '$($UploadSocket.State)'."
                    exit 1
                }

                # Set error handling preference to stop execution on encountering an error.
                $ErrorActionPreference = "Stop"

                # Begin sending data in a loop while the WebSocket remains open.
                do {
                    try {
                        # Create buffer objects for sending and receiving data.
                        $SendBuffer = [System.ArraySegment[byte]]($Buffer)
                        $ReceiveBuffer = [System.ArraySegment[byte]]($Buffer)

                        # Receive a response from the server after sending data.
                        if (!$ReceiveTask -and $UploadSocket.State -ne [System.Net.WebSockets.WebSocketState]::CloseReceived) {
                            $ReceiveTask = $UploadSocket.ReceiveAsync($ReceiveBuffer, [System.Threading.CancellationToken]::None)
                        }

                        # If a receive task exists and has completed, process the received data.
                        if ($ReceiveTask -and $ReceiveTask.Wait(0)) {
                            # Extract the received message.
                            $ReceiveResult = $ReceiveTask.Result

                            # If the message type is text, decode and store it.
                            if ($ReceiveResult.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Text) {
                                $MessageText = [System.Text.Encoding]::UTF8.GetString($Buffer, 0, $ReceiveResult.Count)
                                if ($MessageText) {
                                    $MessageText
                                }
                            }

                            # Reset the receive task after processing.
                            $ReceiveTask = $Null
                        }

                        # Send the buffered data as a binary message.
                        $UploadSocket.SendAsync($SendBuffer, [System.Net.WebSockets.WebSocketMessageType]::Binary, $true, $CancelToken.Token).Wait()

                        # Receive a response from the server after sending data.
                        if (!$ReceiveTask -and $UploadSocket.State -ne [System.Net.WebSockets.WebSocketState]::CloseReceived) {
                            $ReceiveTask = $UploadSocket.ReceiveAsync($ReceiveBuffer, [System.Threading.CancellationToken]::None)
                        }

                        if ($ReceiveTask -and $ReceiveTask.Wait(0)) {
                            # Extract the actual receive result
                            $ReceiveResult = $ReceiveTask.Result

                            if ($ReceiveResult.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Text) {
                                $MessageText = [System.Text.Encoding]::UTF8.GetString($Buffer, 0, $ReceiveResult.Count)
                                if ($MessageText) {
                                    $MessageText
                                }
                            }

                            $ReceiveTask = $Null
                        }

                        # Keep track of the total number of bytes sent.
                        $TotalBytesSent += $BufferSize

                        # Stop the test if it runs for longer than 120 seconds.
                        if ($Stopwatch.Elapsed.TotalSeconds -ge 120) {
                            Write-Host -Object "[Error] The upload speed test timed out."
                            exit 1
                        }
                    }
                    # Handle aggregate exceptions (multiple errors occurring simultaneously).
                    catch [AggregateException] {
                        foreach ($innerException in $_.Exception.InnerExceptions) {
                            Write-Host -Object "[Warning] $($innerException.Message)"
                            if ($innerException.InnerException) {
                                Write-Host -Object "[Warning][Inner Exception] $($innerException.InnerException.Message)"
                            }
                        }

                        # Attempt to reconnect the upload WebSocket after an error.
                        Write-Host -Object "Attempting to reconnect the upload test WebSocket."
                        Remove-WebSocket -SocketName "Upload WebSocket" -Socket $UploadSocket -ErrorAction Stop

                        try {
                            $CancelToken = New-Object System.Threading.CancellationTokenSource
                            $UploadSocket = Create-WebSocket -URL $UploadTestURL -CancelToken $CancelToken -ErrorAction Stop
                        } catch {
                            Write-Host -Object "[Error] $($_.Exception.Message)"
                            Write-Host -Object "[Error] Failed to reconnect the upload test websocket."
                            exit 1
                        }

                        # Reset the total bytes sent count.
                        $TotalBytesSent = 0
                    }
                    # Handle general exceptions and attempt a reconnect.
                    catch {
                        Write-Host -Object "[Warning] $($_.Exception.Message)"

                        Write-Host -Object "Attempting to reconnect the upload test WebSocket."
                        Remove-WebSocket -SocketName "Upload WebSocket" -Socket $UploadSocket -ErrorAction Stop

                        try {
                            $CancelToken = New-Object System.Threading.CancellationTokenSource
                            $UploadSocket = Create-WebSocket -URL $UploadTestURL -CancelToken $CancelToken -ErrorAction Stop
                        } catch {
                            Write-Host -Object "[Error] $($_.Exception.Message)"
                            Write-Host -Object "[Error] Failed to reconnect the upload test websocket."
                            exit 1
                        }

                        # Reset the total bytes sent count.
                        $TotalBytesSent = 0
                    }
                } while ($UploadSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open)

                # Restore the default error handling behavior.
                $ErrorActionPreference = "Continue"

                # Stop the stopwatch as the test has completed.
                $Stopwatch.Stop()
                $TotalSeconds = [math]::Round($Stopwatch.Elapsed.TotalSeconds, 2)
                Write-Host -Object "Upload test completed in $TotalSeconds seconds. Total bytes sent: $TotalBytesSent"

                # Attempt to close and remove the WebSocket connection.
                try {
                    Remove-WebSocket -SocketName "Upload WebSocket" -Socket $UploadSocket -ErrorAction Stop
                } catch {
                    Write-Host -Object "[Error] $($_.Exception.Message)"
                    Write-Host -Object "[Error] Failed to close the WebSocket used for the upload speed test."
                    $ExitCode = 1
                }
            }
        }

        #endregion
        #region - Parse Results

        # Wait for all upload jobs to complete before processing their results
        $UploadJobs | Wait-Job | Out-Null

        # Initialize lists to store received messages, UUIDs, and bytes sent
        $UploadTestReceivedMessages = New-Object System.Collections.Generic.List[object]
        $UploadJobReceivedMessages = New-Object System.Collections.Generic.List[object]

        # Process results from each upload job
        for ($i = 0; $i -lt $NumberOfStreams; $i++) {
            # Retrieve job results and convert from JSON format
            $UploadJobReceivedMessages = $UploadJobs[$i] | Receive-Job -ErrorAction SilentlyContinue -ErrorVariable "UploadJobErrors" | ConvertFrom-Json

            # Extract the unique identifier (UUID) from the received messages
            $UUID = $UploadJobReceivedMessages | Where-Object { $_.UUID } | Select-Object -ExpandProperty "UUID"

            # Loop through all received messages and ensure each one has a UUID
            $UploadJobReceivedMessages | ForEach-Object {
                if (!($_.UUID)) {
                    # If a message does not have a UUID, assign it the extracted UUID
                    $_ | Add-Member -MemberType NoteProperty -Name "UUID" -Value $UUID
                }

                # Store the processed message
                $UploadTestReceivedMessages.Add($_)
            }
        }

        # Check if any errors occurred while retrieving job results
        $UploadJobFailures = $UploadJobs | Get-Job | Where-Object { $_.State -ne "Completed" }

        # Attempt to remove all background upload jobs forcefully
        try {
            $UploadJobs | Remove-Job -Force -ErrorAction Stop
        } catch {
            # If an error occurs while removing jobs, display an error message
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to remove background task(s) used to test the upload speed."

            # Set an exit code indicating failure
            $ExitCode = 1
        }

        # Check if any upload jobs encountered errors or did not complete successfully
        if ($UploadJobFailures -or $UploadJobErrors) {
            Write-Host -Object "[Error] Errors were encountered while testing the upload speed."

            # If specific job errors exist, display them
            if ($UploadJobErrors) {
                $UploadJobErrors | ForEach-Object { Write-Host -Object "[Error] $($_.Exception.Message)" }
            }

            # Exit the script due to failure in upload speed test jobs
            $ExitCode = 1
        }

        # Group all received upload test messages by UUID
        $GroupedTests = $UploadTestReceivedMessages | Group-Object -Property UUID

        # Extract the last received message (most recent result) from each upload test group
        $LastMessageOfEachUploadTest = $GroupedTests | ForEach-Object {
            $_.Group | Sort-Object ElapsedTime | Select-Object -Last 1
        }

        # Validate that at least some bytes were sent and elapsed time exists
        if (!$LastMessageOfEachUploadTest.Network.BytesReceived -or !$UploadTestReceivedMessages.ElapsedTime) {
            Write-Host -Object "[Error] Failed to retrieve the elapsed time or the bytes received. Unable to calculate the upload speed."
            $ExitCode = 1
        }

        # Retrieve the number of bytes sent and elapsed time from the last message.
        $UploadElapsedTime = $UploadTestReceivedMessages.ElapsedTime | Sort-Object | Select-Object -Last 1
        try {
            $BytesSentForTest = $LastMessageOfEachUploadTest.Network.BytesReceived | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to calculate the total bytes sent."
            $ExitCode = 1
        }

        # Calculate the upload speed in Mbps (megabits per second).
        $UploadSpeedMbps = [math]::Round((($BytesSentForTest * 8) / $UploadElapsedTime), 2)

        #endregion
        #region - Latency Test

        # Retrieve the nearest servers test url
        try {
            Write-Host -Object ""
            $LatencyTestInfo = Get-TestURLs -Type "latency" -ErrorAction Stop

            $LatencyServerHostname = $LatencyTestInfo | Select-Object -ExpandProperty "LatencyServerHostname"
            $LatencyAuthURL = $LatencyTestInfo | Select-Object -ExpandProperty "LatencyAuthURL"
            $LatencyResultUrl = $LatencyTestInfo | Select-Object -ExpandProperty "LatencyResultUrl"
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to retrieve the url for the latency test."
            exit 1
        }

        # Notify the user that network latency measurement is starting
        Write-Host -Object "`nConnecting to the network latency server at $LatencyServerHostname"
        try {
            $PreviousProgressPreference = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'

            $ErrorActionPreference = "Stop"

            # Define arguments for HTTP request to the latency authentication server
            $ServerRequestArgs = @{
                MaximumRedirection = 10
                UseBasicParsing    = $true
                Method             = "Get"
                TimeOut            = 30
            }

            # Send a request to retrieve test details from the authentication server
            $TestRequest = Invoke-WebRequest @ServerRequestArgs -Uri $LatencyAuthUrl
            $TestDetails = $TestRequest.Content

            # Initialize a UDP client for sending and receiving latency test packets
            $UdpClient = New-Object System.Net.Sockets.UdpClient
            $UdpClient.Connect($LatencyServerHostname, 1053)

            # Convert the test details into a byte array and send a kickoff packet
            $KickoffBytes = [System.Text.Encoding]::UTF8.GetBytes($TestDetails)
            $UdpClient.Send($KickoffBytes, $KickoffBytes.Length) | Out-Null
            Write-Host "Kickoff packet sent"

            # Set the duration for the latency test (45 seconds)
            $EndTime = (Get-Date).AddSeconds(45)

            Write-Host "Performing network latency test."
            $ReceivedMessages = New-Object System.Collections.Generic.List[string]

            # Continuously listen for incoming UDP packets until the time limit is reached
            while ((Get-Date) -lt $EndTime) {
                if ($UdpClient.Available -gt 0) {
                    # Define an endpoint to store sender's details
                    $RemoteEndPoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 1053)

                    # Receive the incoming UDP packet and decode its content
                    $ReceivedBytes = $UdpClient.Receive([ref]$RemoteEndPoint)
                    $ReceivedData = [System.Text.Encoding]::UTF8.GetString($ReceivedBytes)

                    # Store received message if it contains valid data
                    if ($ReceivedData) {
                        $ReceivedMessages.Add($ReceivedData)
                    }

                    # Echo back the received packet to the sender for validation
                    if ($ReceivedBytes) {
                        $UdpClient.Send($ReceivedBytes, $ReceivedBytes.Length) | Out-Null
                    }
                }
            }

            # Close the UDP client after completing the test
            $UdpClient.Close()
        } catch {
            # Handle errors that occur during latency testing
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to determine the network latency."
            $ExitCode = 1
        } finally {
            $ErrorActionPreference = "Continue"
        }

        try {
            $ErrorActionPreference = "Stop"

            # Notify user that latency results are being retrieved
            Write-Host -Object "Retrieving latency results from $($LatencyResultUrl -replace 'token=[^&]*','token=*****')"

            # Request latency test results from the result server
            $LatencyServerResultResponse = Invoke-WebRequest @ServerRequestArgs -Uri $LatencyResultUrl
            $LatencyTestResults = $LatencyServerResultResponse.Content | ConvertFrom-Json

            # Validate that test results contain valid JSON data
            if (!$LatencyTestResults) {
                throw [System.NullReferenceException]::New("No JSON response from the result server was detected.")
            }

            Write-Host -Object "Determining the minimum, maximum and average latency from test results."

            # Extract Round Trip Time (RTT) measurements from the test results
            $RoundTrips = $LatencyTestResults.RoundTrips | Select-Object -ExpandProperty RTT | Where-Object { $_ }

            # Ensure RTT values are available for further calculations
            if (!$RoundTrips) {
                throw [System.NullReferenceException]::New("No Round Trip Measurements were included in the results.")
            }

            # Compute minimum, maximum, and average Round Trip Time (RTT)
            $MinRTT = $RoundTrips | Measure-Object -Minimum -ErrorAction Stop | Select-Object -ExpandProperty Minimum -ErrorAction Stop
            $MaxRTT = $RoundTrips | Measure-Object -Maximum -ErrorAction Stop | Select-Object -ExpandProperty Maximum -ErrorAction Stop
            $AvgRTT = $RoundTrips | Measure-Object -Average -ErrorAction Stop | Select-Object -ExpandProperty Average -ErrorAction Stop


            # Convert RTT values from microseconds to milliseconds and round to three decimal places.
            $MinLatency = [math]::Round(($MinRTT / 1000), 3)
            $MaxLatency = [math]::Round(($MaxRTT / 1000), 3)
            $AvgLatency = [math]::Round(($AvgRTT / 1000), 3)

            # Compute the standard deviation of RTT values to determine network jitter.
            $RTTStandardDeviation = [math]::Sqrt(($RoundTrips | ForEach-Object { [Math]::Pow(($_ - $AvgRTT), 2) } | Measure-Object -Sum).Sum / ($RoundTrips.Count - 1))
            $Jitter = [math]::Round(($RTTStandardDeviation / 1000), 3)
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to determine the network latency."
            $ExitCode = 1
        } finally {
            $ErrorActionPreference = "Continue"
        }

        #endregion
        #region Speed Test Results
        try {
            $ErrorActionPreference = "Stop"

            # Create a formatted result object to store test results.
            $FormattedResult = [PSCustomObject]@{
                DownloadTestId = $DownloadJobReceivedMessages.UUID[0]
                UploadTestId   = $UploadJobReceivedMessages.UUID[0]
                Date           = Get-Date
                Server         = $ThroughputServerHostname
                Down           = "$DownloadSpeedMbps Mbps"
                Up             = "$UploadSpeedMbps Mbps"
                Interface      = $AdapterString
                MacAddress     = $($Adapter.MacAddress -replace "-", ":")
                Jitter         = "$Jitter ms"
                Latency        = "$AvgLatency ms"
                Low            = "$MinLatency ms"
                High           = "$MaxLatency ms"
            }
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to format the results into a human readable format."
            $ExitCode = 1
        } finally {
            $ErrorActionPreference = "Continue"
        }

        # Display the Speed Test results in the activity feed
        Write-Host -Object "`n### Speed Test Results ###"
        ($FormattedResult | Format-List -Property @{Name = "Date"; Expression = { "$($_.Date.ToShortDateString()) $($_.Date.ToShortTimeString())" } },
        Server, Down, Up, Interface, @{Name = "MAC Address"; Expression = { $_.MacAddress } }, Jitter, Latency, Low, High | Out-String).Trim() | Write-Host
    }
    #endregion

    # If the WYSIWYG custom field is given, proceed to set and format the custom field.
    if ($WysiwygCustomField) {
        try {
            # Inform the user that the custom field is being set.
            Write-Host "`nAttempting to set Custom Field '$WysiwygCustomField'."

            #endregion
            #region HTML Creation
            $CompletedDateTime = Get-Date

            # Initialize the custom field value as a list of strings.
            $CustomFieldValue = New-Object System.Collections.Generic.List[String]
            $CustomFieldValue.Add("<div>")

            # Convert the formatted CPU processes table to HTML and add custom formatting.
            $CPUProcessMetricTable = $FormattedProcesses | ConvertTo-Html -Fragment
            $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"
            $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<table>", "<table><caption style='border-top: 1px; border-left: 1px; border-right: 1px; border-style: solid; border-color: #CAD0D6'><b>Top 5 CPU Processes</b></caption>"
            $CPUProcessMetricTable = $CPUProcessMetricTable -replace "Average CPU % Used", "<i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average CPU % Used"
            $CPUProcessMetricTable = $CPUProcessMetricTable -replace "Minimum CPU % Used", "<i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum CPU % Used"
            $CPUProcessMetricTable = $CPUProcessMetricTable -replace "Maximum CPU % Used", "<i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum CPU % Used"

            # Highlight rows in the CPU table based on CPU usage thresholds (warnings and danger levels).
            $Top5CPUProcesses | ForEach-Object {
                if ($_.Avg -ge 20 -and $_.Avg -lt 50) { $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }
                if ($_.Min -ge 20 -and $_.Min -lt 50) { $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }
                if ($_.Max -ge 20 -and $_.Max -lt 50) { $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }

                if ($_.Avg -ge 50) { $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
                if ($_.Min -ge 50) { $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
                if ($_.Max -ge 50) { $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
            }

            # Convert the formatted RAM processes table to HTML and add custom formatting.
            $RAMProcessMetricTable = $FormattedMemoryProcesses | ConvertTo-Html -Fragment
            $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"
            $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<table>", "<table><caption style='border-top: 1px; border-left: 1px; border-right: 1px; border-style: solid; border-color: #CAD0D6'><b>Top 5 RAM Processes</b></caption>"
            $RAMProcessMetricTable = $RAMProcessMetricTable -replace "Average RAM % Used", "<i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average RAM % Used"
            $RAMProcessMetricTable = $RAMProcessMetricTable -replace "Minimum RAM % Used", "<i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum RAM % Used"
            $RAMProcessMetricTable = $RAMProcessMetricTable -replace "Maximum RAM % Used", "<i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum RAM % Used"

            # Highlight rows in the RAM table based on RAM usage thresholds (warnings and danger levels).
            $Top5RAMProcesses | ForEach-Object {
                if ($_.Avg -ge 10 -and $_.Avg -lt 30) { $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }
                if ($_.Min -ge 10 -and $_.Min -lt 30) { $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }
                if ($_.Max -ge 10 -and $_.Max -lt 30) { $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }

                if ($_.Avg -ge 30) { $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
                if ($_.Min -ge 30) { $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
                if ($_.Max -ge 30) { $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
            }

            # Convert the formatted I/O processes table to HTML and add custom formatting.
            $IOProcessesMetricTable = $FormattedIOProcesses | ConvertTo-Html -Fragment
            $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"
            $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<table>", "<table><caption style='border-top: 1px; border-left: 1px; border-right: 1px; border-style: solid; border-color: #CAD0D6'><b>Top 5 IO Processes (Network & Disk Combined)</b></caption>"
            $IOProcessesMetricTable = $IOProcessesMetricTable -replace "Average IO Used", "<i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average IO Used"
            $IOProcessesMetricTable = $IOProcessesMetricTable -replace "Minimum IO Used", "<i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum IO Used"
            $IOProcessesMetricTable = $IOProcessesMetricTable -replace "Maximum IO Used", "<i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum IO Used"

            # Highlight rows in the I/O table based on I/O usage thresholds (warnings and danger levels).
            $Top5IOProcesses | ForEach-Object {
                if ($_.Avg -ge 1250000 -and $_.Avg -lt 12500000) { $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }
                if ($_.Min -ge 1250000 -and $_.Min -lt 12500000) { $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }
                if ($_.Max -ge 1250000 -and $_.Max -lt 12500000) { $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }

                if ($_.Avg -ge 12500000) { $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
                if ($_.Min -ge 12500000) { $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
                if ($_.Max -ge 12500000) { $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
            }

            # Convert the formatted network usage table to HTML and add custom formatting.
            $NetworkUsageMetricTable = $FormattedNetworkUsage | ConvertTo-Html -Fragment
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<table>", "<table><caption style='border-top: 1px; border-left: 1px; border-right: 1px; border-style: solid; border-color: #CAD0D6'><b>Network Usage</b></caption>"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "Average Sent & Received", "<i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average Sent & Received"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "Minimum Sent & Received", "<i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum Sent & Received"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "Maximum Sent & Received", "<i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum Sent & Received"

            # Add network type icons for wired, Wi-Fi, and other network interfaces.
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<th><b>Type</b></th>", "<th><b><i class='fa-solid fa-network-wired'></i>&nbsp;&nbsp;Type</b></th>"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<td>Wired</td>", "<td><i class='fa-solid fa-ethernet'></i>&nbsp;&nbsp;Wired</td>"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<td>Wi-Fi</td>", "<td><i class='fa-solid fa-wifi'></i>&nbsp;&nbsp;Wi-Fi</td>"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<td>Other</td>", "<td><i class='fa-solid fa-circle-question'></i>&nbsp;&nbsp;Other</td>"

            # Highlight network interfaces based on network usage thresholds and interface types.
            $NetworkInterfaceUsage | ForEach-Object {
                if ($_.Avg -ge 1250000 -and $_.Avg -lt 12500000) { $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='warning'><td>$($_.NetworkAdapter)" }
                if ($_.Min -ge 1250000 -and $_.Min -lt 12500000) { $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='warning'><td>$($_.NetworkAdapter)" }
                if ($_.Max -ge 1250000 -and $_.Max -lt 12500000) { $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='warning'><td>$($_.NetworkAdapter)" }

                if ($_.Avg -ge 12500000) { $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='danger'><td>$($_.NetworkAdapter)" }
                if ($_.Min -ge 12500000) { $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='danger'><td>$($_.NetworkAdapter)" }
                if ($_.Max -ge 12500000) { $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='danger'><td>$($_.NetworkAdapter)" }

                # Highlight Wi-Fi or "Other" types as warnings.
                if ($_.Type -eq "Wi-Fi" -or $_.Type -eq "Other") {
                    $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='warning'><td>$($_.NetworkAdapter)"
                }
            }

            # Convert the formatted disk usage table to HTML and add custom formatting.
            $DiskMetricTable = $FormattedDiskMetrics | ConvertTo-Html -Fragment
            $DiskMetricTable = $DiskMetricTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"
            $DiskMetricTable = $DiskMetricTable -replace "<table>", "<table><caption style='border-top: 1px; border-left: 1px; border-right: 1px; border-style: solid; border-color: #CAD0D6'><b>Disk Usage</b></caption>"
            $DiskMetricTable = $DiskMetricTable -replace "Average IOPS", "<i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average IOPS"
            $DiskMetricTable = $DiskMetricTable -replace "Minimum IOPS", "<i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum IOPS"
            $DiskMetricTable = $DiskMetricTable -replace "Maximum IOPS", "<i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum IOPS"

            # Highlight rows in the disk usage table based on drive type and available space thresholds.
            $DiskMetrics | ForEach-Object {
                if ($_.MediaType -ne "SSD" -and $_.MediaType -ne "Unspecified") {
                    $DiskMetricTable = $DiskMetricTable -replace "<tr><td>$($_.DriveLetter)", "<tr class='danger'><td>$($_.DriveLetter)"
                }

                if ($_.FreeSpaceGB -lt 100) {
                    $DiskMetricTable = $DiskMetricTable -replace "<tr><td>$($_.DriveLetter)", "<tr class='warning'><td>$($_.DriveLetter)"
                }

                if ($_.FreeSpaceGB -lt 10) {
                    $DiskMetricTable = $DiskMetricTable -replace "<tr class='warning'><td>$($_.DriveLetter)", "<tr class='danger'><td>$($_.DriveLetter)"
                }
            }

            # Handle WinSAT assessment data if it's valid and add the WinSAT scores to the table.
            $ValidAssessmentStates = "1", "2"
            if ($ValidAssessmentStates -contains $WinSatScores.WinSATAssessmentState) {
                $WinSATMetricTable = $WinSatScores | Select-Object -Property CPUScore, D3DScore, DiskScore, GraphicsScore, MemoryScore | ConvertTo-Html -Fragment
                $WinSATMetricTable = $WinSATMetricTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"
                $WinSATMetricTable = $WinSATMetricTable -replace "<table>", "<br><table><caption style='border-top: 1px; border-left: 1px; border-right: 1px; border-style: solid; border-color: #CAD0D6'><b>WinSAT Scores</b></caption>"

                # Highlight rows in the WinSAT table based on score thresholds.
                if ($WinSatScores.CPUScore -lt 7 -or $WinSatScores.D3DScore -lt 7 -or $WinSatScores.DiskScore -lt 7 -or $WinSatScores.GraphicsScore -lt 7 -or $WinSatScores.MemoryScore -lt 7) {
                    $WinSATMetricTable = $WinSATMetricTable -replace "<tr><td>", "<tr class='warning'><td>"
                }

                if ($WinSatScores.CPUScore -lt 4 -or $WinSatScores.D3DScore -lt 4 -or $WinSatScores.DiskScore -lt 4 -or $WinSatScores.GraphicsScore -lt 4 -or $WinSatScores.MemoryScore -lt 4) {
                    $WinSATMetricTable = $WinSATMetricTable -replace "<tr class='warning'><td>", "<tr class='danger'><td>"
                }
            } else {
                # If WinSAT data is not available, display a message.
                $WinSATMetricTable = "<p style='margin-top: 0px'>The WinSAT assessment data is either invalid or not available for this computer.</p>"
            }

            if ($PerformInternetSpeedTest) {
                $SpeedTestCard = "<br><div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-gauge-high'></i>&nbsp;&nbsp;Speedtest Results</div>
        <div class='card-link-box'>
            <a href='https://www.measurementlab.net/' target='_blank' class='card-link' rel='nofollow noopener noreferrer'>
                <i class='fas fa-arrow-up-right-from-square' style='color: #337ab7;'></i>
            </a>
        </div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        <div class='container' style='padding-left: 0px'>
            <div class='row'>
                <div class='col-sm'>
                    <p class='card-text'><b>Date</b><br>$($FormattedResult.Date.ToShortDateString()) $($FormattedResult.Date.ToShortTimeString())</p>
                </div>
                <div class='col-md'>
                    <p class='card-text' style='white-space: nowrap;'><b>Speedtest Server</b><br>$($FormattedResult.Server)</p>
                </div>
                <div class='col-md'>
                    <p class='card-text' style='white-space: nowrap;'><b>$($FormattedResult.Interface)</b><br><i class='fa-solid fa-ethernet'></i>&nbsp;&nbsp;$($FormattedResult.MacAddress)</p>
                </div>
            </div>
        </div>
        <div class='container my-4' style='width: 70em'>
            <div class='row' style='padding-left: 0px'>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' style='color: #008001; white-space: nowrap;'>$($FormattedResult.Down)</div>
                        <div class='stat-desc'><i class='fa-solid fa-circle-down'></i>&nbsp;&nbsp;Download</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' style='color: #008001; white-space: nowrap;'>$($FormattedResult.Up)</div>
                        <div class='stat-desc'><i class='fa-solid fa-circle-up'></i>&nbsp;&nbsp;Upload</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' style='color: #008001; white-space: nowrap;'>$($FormattedResult.Jitter)</div>
                        <div class='stat-desc'><i class='fa-solid fa-chart-line'></i>&nbsp;&nbsp;Jitter</div>
                    </div>
                </div>
            </div>
            <div class='row' style='padding-left: 0px'>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' style='color: #008001; white-space: nowrap;'>$($FormattedResult.Latency)</div>
                        <div class='stat-desc'><i class='fa-solid fa-server'></i>&nbsp;&nbsp;Latency</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' style='color: #008001; white-space: nowrap;'>$($FormattedResult.High)</div>
                        <div class='stat-desc'><i class='fa-solid fa-chevron-up'></i>&nbsp;&nbsp;High</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' style='color: #008001; white-space: nowrap;'>$($FormattedResult.Low)</div>
                        <div class='stat-desc'><i class='fa-solid fa-chevron-down'></i>&nbsp;&nbsp;Low</div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>"
                # Adjust the icon based on the adapter type (Wired, Wi-Fi, or Other)
                switch ($AdapterType) {
                    "Wi-Fi" {
                        $SpeedTestCard = $SpeedTestCard -replace 'fa-solid fa-ethernet', 'fa-solid fa-wifi'
                    }
                    "Other" {
                        $SpeedTestCard = $SpeedTestCard -replace 'fa-solid fa-ethernet', 'fa-solid fa-circle-question'
                    }
                }
            }

            # Create the HTML content for the performance metrics section.
            $HTMLCard = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-gauge-high'></i>&nbsp;&nbsp;System Performance Metrics</div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        <div class='container' style='padding-left: 0px'>
            <div class='row'>
                <div class='col-sm'>
                    <p class='card-text'><b>Start Date and Time</b><br>$($StartedDateTime.ToShortDateString()) $($StartedDateTime.ToShortTimeString())</p>
                </div>
                <div class='col-sm'>
                    <p class='card-text'><b>Completed Date and Time</b><br>$($CompletedDateTime.ToShortDateString()) $($CompletedDateTime.ToShortTimeString())</p>
                </div>
            </div>
        </div>
        <p id='lastStartup' class='card-text'><b>Last Startup Time</b><br>$($LastStartTime.ToShortDateString()) $($LastStartTime.ToShortTimeString())</p>
        <div class='container my-4' style='padding-left: 0px; margin-left: 0px; padding-right: 0px; margin-right: 0px;'>
            <div class='row' style='padding-left: 0px'>
                <p><b>$CPU</b></p>
            </div>
            <div class='row' style='padding-left: 0px'>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' id='cpuOverallAvg' style='color: #008001;'>$($FormattedCPUPerformance."CPU Average %")</div>
                        <div class='stat-desc'><i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average CPU % Used</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' id='cpuOverallMin' style='color: #008001;'>$($FormattedCPUPerformance."CPU Minimum %")</div>
                        <div class='stat-desc'><i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum CPU % Used</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' id='cpuOverallMax' style='color: #008001;'>$($FormattedCPUPerformance."CPU Maximum %")</div>
                        <div class='stat-desc'><i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum CPU % Used</div>
                    </div>
                </div>
            </div>
            <div class='row' style='padding-left: 0px'>
                <p><b>Total Memory: $TotalMemoryGB</b></p>
            </div>
            <div class='row' style='padding-left: 0px'>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' id='ramOverallAvg' style='color: #008001;'>$($OverallMemoryMetrics."RAM Average %")</div>
                        <div class='stat-desc'><i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average RAM % Used</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' id='ramOverallMin' style='color: #008001;'>$($OverallMemoryMetrics."RAM Minimum %")</div>
                        <div class='stat-desc'><i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum RAM % Used</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' id='ramOverallMax' style='color: #008001;'>$($OverallMemoryMetrics."RAM Maximum %")</div>
                        <div class='stat-desc'><i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum RAM % Used</div>
                    </div>
                </div>
            </div>
        </div>
        $CPUProcessMetricTable
        <br>
        $RAMProcessMetricTable
        <br>
        $NetworkUsageMetricTable
        <br>
        $DiskMetricTable
        <br>
        $IOProcessesMetricTable
        $(if($ValidAssessmentStates -notcontains $WinSatScores.WinSATAssessmentState) {"<p style='margin-bottom: 0px'><b>WinSAT Scores</b></p>"})
        $WinSATMetricTable
    </div>
</div>
$SpeedTestCard"
            # Modify the last startup time section based on whether the startup limit was exceeded or not.
            if ($ExceededLastStartupLimit) {
                $HTMLCard = $HTMLCard -replace "id='lastStartup' class='card-text'><b>Last Startup Time</b><br>$($LastStartTime.ToShortDateString()) $($LastStartTime.ToShortTimeString())", "id='lastStartup' class='card-text'><b>Last Startup Time</b><br>$($LastStartTime.ToShortDateString()) $($LastStartTime.ToShortTimeString())&nbsp;&nbsp;<i class='fa-solid fa-circle-exclamation' style='color: #D53948;'></i>"
            } elseif ($DaysSinceLastReboot -ge 0) {
                $HTMLCard = $HTMLCard -replace "id='lastStartup' class='card-text'><b>Last Startup Time</b><br>$($LastStartTime.ToShortDateString()) $($LastStartTime.ToShortTimeString())", "id='lastStartup' class='card-text'><b>Last Startup Time</b><br>$($LastStartTime.ToShortDateString()) $($LastStartTime.ToShortTimeString())&nbsp;&nbsp;<i class='fa-solid fa-circle-check' style='color: #008001;'></i>"
            }

            # Highlight CPU performance metrics based on threshold values (color coding).
            if ($CPUPerformance.Avg -ge 60 -and $CPUPerformance.Avg -lt 90) { $HTMLCard = $HTMLCard -replace "id='cpuOverallAvg' style='color: #008001;'", "id='cpuOverallAvg' style='color: #FAC905;'" }
            if ($CPUPerformance.Min -ge 60 -and $CPUPerformance.Min -lt 90) { $HTMLCard = $HTMLCard -replace "id='cpuOverallMin' style='color: #008001;'", "id='cpuOverallMin' style='color: #FAC905;'" }
            if ($CPUPerformance.Max -ge 60 -and $CPUPerformance.Max -lt 90) { $HTMLCard = $HTMLCard -replace "id='cpuOverallMax' style='color: #008001;'", "id='cpuOverallMax' style='color: #FAC905;'" }

            if ($CPUPerformance.Avg -ge 90) { $HTMLCard = $HTMLCard -replace "id='cpuOverallAvg' style='color: #008001;'", "id='cpuOverallAvg' style='color: #D53948;'" }
            if ($CPUPerformance.Min -ge 90) { $HTMLCard = $HTMLCard -replace "id='cpuOverallMin' style='color: #008001;'", "id='cpuOverallMin' style='color: #D53948;'" }
            if ($CPUPerformance.Max -ge 90) { $HTMLCard = $HTMLCard -replace "id='cpuOverallMax' style='color: #008001;'", "id='cpuOverallMax' style='color: #D53948;'" }

            # Highlight RAM performance metrics based on threshold values (color coding).
            if ($MemoryPerformance.Avg -ge 60 -and $MemoryPerformance.Avg -lt 90) { $HTMLCard = $HTMLCard -replace "id='ramOverallAvg' style='color: #008001;'", "id='ramOverallAvg' style='color: #FAC905;'" }
            if ($MemoryPerformance.Min -ge 60 -and $MemoryPerformance.Min -lt 90) { $HTMLCard = $HTMLCard -replace "id='ramOverallMin' style='color: #008001;'", "id='ramOverallMin' style='color: #FAC905;'" }
            if ($MemoryPerformance.Max -ge 60 -and $MemoryPerformance.Max -lt 90) { $HTMLCard = $HTMLCard -replace "id='ramOverallMax' style='color: #008001;'", "id='ramOverallMax' style='color: #FAC905;'" }

            if ($MemoryPerformance.Avg -ge 90) { $HTMLCard = $HTMLCard -replace "id='ramOverallAvg' style='color: #008001;'", "id='ramOverallAvg' style='color: #D53948;'" }
            if ($MemoryPerformance.Min -ge 90) { $HTMLCard = $HTMLCard -replace "id='ramOverallMin' style='color: #008001;'", "id='ramOverallMin' style='color: #D53948;'" }
            if ($MemoryPerformance.Max -ge 90) { $HTMLCard = $HTMLCard -replace "id='ramOverallMax' style='color: #008001;'", "id='ramOverallMax' style='color: #D53948;'" }

            # Add the created HTML card to the custom field.
            $CustomFieldValue.Add($HTMLCard)

            # Check if there are any event logs to display.
            if ($NumberOfEvents -gt 0 -and $EventLogs.Count -gt 0) {
                # Convert the event logs into an HTML fragment for displaying in the output.
                $EventLogTableMetrics = $EventLogs | ConvertTo-Html -Fragment

                # Apply custom styles to the HTML table headers.
                $EventLogTableMetrics = $EventLogTableMetrics -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"

                # Set specific column widths for better presentation.
                $EventLogTableMetrics = $EventLogTableMetrics -replace "<th><b>LogName", "<th style='width: 100px'><b>Log Name"
                $EventLogTableMetrics = $EventLogTableMetrics -replace "<th><b>ProviderName", "<th style='width: 250px'><b>Provider Name"
                $EventLogTableMetrics = $EventLogTableMetrics -replace "<th><b>Id", "<th style='width: 75px'><b>Id"
                $EventLogTableMetrics = $EventLogTableMetrics -replace "<th><b>TimeCreated", "<th style='width: 175px'><b>Time Created"
            } elseif ($NumberOfEvents -gt 0) {
                # If no events were found, display a message instead of the table.
                $EventLogTableMetrics = "<p style='margin-top: 0px'>No error events were found in the event log.</p>"
            }

            # If event logs exist, create a card to display them.
            if ($NumberOfEvents -gt 0) {
                # Create the HTML structure for the event log card.
                $EventLogCard = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-book'></i>&nbsp;&nbsp;Recent Error Events</div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        $EventLogTableMetrics
    </div>
</div>"
                # Add the event log card to the custom field value.
                $CustomFieldValue.Add($EventLogCard)
            }

            #endregion
            #region HTML Character Limit

            # Check if the HTML content exceeds the character limit (45,000 characters).
            $HTMLCharacters = ($CustomFieldValue | Out-String).Length
            if ($HTMLCharacters -ge 190000) {
                Write-Host -Object "The current character count is '$HTMLCharacters'."
                Write-Host -Object "[Warning] The character limit of 190,000 has been reached! Trimming the output until the character limit is satisfied."

                # Truncate the output if it exceeds the limit.
                $i = 0
                [array]$NewEventLogTable = $EventLogTableMetrics
                $TrimStart = Get-Date
                do {
                    # Recreate the custom field output
                    $CustomFieldValue = New-Object System.Collections.Generic.List[string]
                    $CustomFieldValue.Add("<div>")

                    if (!$NumberOfEvents -or !$NumberOfEvents -gt 0 -or !$EventLogs.Count -gt 0) {
                        Write-Host -Object "[Error] No events to trim."
                        exit 1
                    }

                    # Add the main performance metrics card to the custom field.
                    $CustomFieldValue.Add($HTMLCard)

                    # Calculate the batch size for trimming
                    $ExceededAmount = $HTMLCharacters - 190000
                    if ($ExceededAmount -le 0) {
                        $BatchSize = 1
                    } else {
                        $BatchSize = [math]::Ceiling($ExceededAmount / 500)
                    }

                    # Reverse the event log array so that the last entry is at the top.
                    [array]::Reverse($NewEventLogTable)

                    # Remove excess event log entries
                    for ($BatchNumber = 0 ; $BatchNumber -lt $BatchSize ; $BatchNumber++) {
                        # Delete rows until the character count is reduced.
                        if ($NewEventLogTable[$i] -match '<tr><td>' -or $NewEventLogTable[$i] -match '<tr class=') {
                            $NewEventLogTable[$i] = $null
                        }
                        $i++
                    }

                    # Reverse the array back to its original order.
                    [array]::Reverse($NewEventLogTable)

                    # Rebuild the event log card with the truncated log.
                    $EventLogCard = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-book'></i>&nbsp;&nbsp;Recent Error Events</div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        $NewEventLogTable
    </div>
</div>"

                    # Add a truncation notice and the truncated event log card.
                    $CustomFieldValue.Add("<h1>This information has been truncated to fit within the character limit of 190,000.</h1>")
                    $CustomFieldValue.Add($EventLogCard)

                    # Check the character count again; repeat if still too long.
                    $HTMLCharacters = ($CustomFieldValue | Out-String).Length
                    $ElapsedTime = (Get-Date) - $TrimStart
                    if ($ElapsedTime.TotalMinutes -ge 5) {
                        Write-Host -Object "The current character count is '$HTMLCharacters'."
                        throw "5 minute timeout reached. Unable to trim the output to comply with the character limit."
                    }
                }while ($HTMLCharacters -ge 190000)
            }

            $CustomFieldValue.Add("</div>")

            # Set the custom field with the finalized HTML content.
            Set-NinjaProperty -Name $WysiwygCustomField -Value $CustomFieldValue -Type "WYSIWYG" -ErrorAction Stop
            Write-Host "Successfully set Custom Field '$WysiwygCustomField'!"
        } catch {
            Write-Host "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    #region Process Lock File

    # Try to remove the lock file to ensure no other instance of the script is running.
    try {
        Remove-Item -Path "$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt" -Force -ErrorAction Stop
    } catch {
        # If the removal of the lock file fails, catch the exception and display error messages.
        Write-Host -Object "[Error] Failed to remove lock file at '$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt'."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        $ExitCode = 1
    }

    #endregion
    #region Display Message

    if ($DisplayUserMessage) {
        try {
            Write-Host -Object "`nChecking for currently logged-in users."
            $QuserOutput = Invoke-LegacyConsoleTool -FilePath "$env:WINDIR\System32\quser.exe" -ErrorVariable "QUserErrors" -ErrorAction SilentlyContinue
            if ($QUserErrors) {
                $QUserErrors | ForEach-Object { Write-Host -Object "[Warning] $($_.Exception.Message)" }
                $QUserErrors = $Null
            }

            $i = 0
            $CurrentlyLoggedInUsers = $QuserOutput | Where-Object { $_.Trim() } | ForEach-Object {
                # Skip the first line (header) and process only the data lines
                if ($i -ne 0 -and $_.Length -ge 65) {
                    # Extract the relevant columns using fixed-width positions
                    [PSCustomObject]@{
                        Username    = ($_.Substring(0, 21).Trim() -replace '^>')
                        SessionName = $_.Substring(21, 21).Trim()
                        ID          = $_.Substring(40, 5).Trim()
                        State       = $_.Substring(45, 10).Trim()
                        IdleTime    = $_.Substring(55, 10).Trim()
                        LogonTime   = $_.Substring(65).Trim()
                    }
                }

                $i++
            }
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Unable to check for currently logged-in users."
            $ExitCode = 1
        }
    }

    if ($DisplayUserMessage -and $CurrentlyLoggedInUsers) {
        $CurrentlyLoggedInUsers = $null

        # Arguments for sending a message to notify the user that performance metrics have been recorded.
        $MSGArguments = @(
            "*"
            "/TIME:3600"
            "/V"
            "Performance metrics have been recorded and forwarded to your IT Administrator."
        )

        # Display an empty line for better readability in the output.
        Write-Host -Object ""

        # Start the process of sending a message to the users using msg.exe.
        try {
            Write-Host -Object "Sending message to all users."

            # Start the 'msg.exe' process with the provided arguments and capture stdout and stderr into log files.
            Invoke-LegacyConsoleTool -FilePath "$env:WINDIR\System32\msg.exe" -ArgumentList $MSGArguments -ErrorAction Stop
        } catch {
            # If the process fails to start, output an error message and exit the script with an error code.
            Write-Host -Object "[Error] Failed to send message to all users."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }

        # Output the exit code of the msg.exe process.
        Write-Host -Object "ExitCode: $LASTEXITCODE"

        # If the exit code is non-zero (indicating an error), display an error message.
        if ($LASTEXITCODE -ne 0) {
            Write-Host -Object "[Error] ExitCode does not indicate success."
            $ExitCode = 1
        }
    }

    #endregion
    #region Display Events

    # If the $NumberOfEvents variable has a value, proceed to display the event logs.
    if ($NumberOfEvents) {
        # Display a message indicating the number of errors retrieved from the event logs.
        Write-Host -Object "`n### Last $NumberOfEvents errors in Application, Security, Setup and System Log. ###"

        # Format and display the collected event logs in a list format.
        ($EventLogs | Format-List | Out-String).Trim() | Write-Host
    }

    #endregion

    exit $ExitCode
}
end {
    
    
    
}