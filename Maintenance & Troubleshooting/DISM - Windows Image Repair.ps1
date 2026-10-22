#Requires -Version 5.1

<#
.SYNOPSIS
    Start a Windows image repair utilizing the DISM tool with your specified options.
.DESCRIPTION
    Start a Windows image repair utilizing the DISM tool with your specified options.
.EXAMPLE
    -HealthAction "Restore Health" -ComponentCleanup

    Starting DISM at 'C:\Windows\System32\Dism.exe' with the arguments '/Online /Cleanup-Image /StartComponentCleanup /RestoreHealth /NoRestart'.
    Started the Windows Image Repair process using DISM with the process ID (PID) of '5764'.

    Deployment Image Servicing and Management tool
    Version: 10.0.26100.5074

    Image Version: 10.0.26100.7462

    [==========================100.0%==========================]
    The restore operation completed successfully.
    The operation completed successfully.

.PARAMETER HealthAction
    Check whether the image has been flagged as corrupted, scan it for corruption, or scan and repair the Windows image.

.PARAMETER RepairSource
    Specify the location of a known good version of files that can be used for the repair, such as Windows Update, the WinSxS folder, or a currently mounted ISO.

.PARAMETER MaxTimeout
    The amount of time to wait for the results from your chosen DISM task.

.PARAMETER ComponentCleanup
    Clean up the WinSxS folder by removing older components in the component store that have been replaced by newer versions.

.PARAMETER ForceReboot
    If DISM completes, schedule a reboot 5 minutes after script completion.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$HealthAction,
    [Parameter()]
    [String]$RepairSource,
    [Parameter()]
    [Int]$MaxTimeout = 120,
    [Parameter()]
    [Switch]$ComponentCleanup = [System.Convert]::ToBoolean($env:componentCleanup),
    [Parameter()]
    [Switch]$ForceReboot = [System.Convert]::ToBoolean($env:forceReboot)
)

begin {
    # If script form variables are used, update the command line parameters with their value.
    if ($env:healthAction) { $HealthAction = $env:healthAction }
    if ($env:repairSource) { $RepairSource = $env:repairSource }
    if ($env:multilineCustomFieldName) { $MultilineCustomFieldName = $env:multilineCustomFieldName }
    if ($env:wysiwygCustomFieldName) { $WYSIWYGCustomFieldName = $env:wysiwygCustomFieldName }
    if ($env:maxTimeout) {
        # Validate that the 'maxTimeout' value is not null or whitespace
        if ([String]::IsNullOrWhiteSpace($env:maxTimeout)) {
            Write-Host -Object "[Error] An invalid timeout was provided. It is null or contains only whitespace."
            exit 1
        }

        # Trim any leading or trailing whitespace from the 'maxTimeout' value
        $env:maxTimeout = $env:maxTimeout.Trim()

        # Validate that the 'maxTimeout' value contains only numeric characters
        if ($env:maxTimeout -match "[^0-9]") {
            Write-Host -Object "[Error] An invalid max timeout was provided: '$env:maxTimeout'. It contains invalid characters."
            Write-Host -Object "[Error] Please provide a whole number between 1 and 120 (inclusive)."
            exit 1
        }

        # Attempt to assign the 'maxTimeout' value to the $MaxTimeout variable
        try {
            $MaxTimeout = $env:maxTimeout
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] An invalid timeout was provided: '$env:maxTimeout'. Please provide a whole number between 1 and 120 (inclusive)."
            exit 1
        }
    }

    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Ensure that at least one of the required actions (HealthAction or ComponentCleanup) is specified
    if (!$HealthAction -and !$ComponentCleanup) {
        Write-Host -Object "[Error] You must specify at least a health action or perform a component cleanup."
        exit 1
    }

    # Initialize DISM arguments for online mode
    $DISMArguments = New-Object -TypeName System.Collections.Generic.List[String]
    $DISMArguments.Add("/Online")
    $DISMArguments.Add("/Cleanup-Image")

    # Check for the existence of DISM executable in the default system paths
    if (Test-Path -Path "$env:WinDir\System32\Dism.exe" -PathType "Leaf" -ErrorAction SilentlyContinue) {
        $DISMFilePath = "$env:WinDir\System32\Dism.exe"
    }

    if (Test-Path -Path "C:\Windows\System32\Dism.exe" -PathType "Leaf" -ErrorAction SilentlyContinue) {
        $DISMFilePath = "C:\Windows\System32\Dism.exe"
    }

    # Exit if DISM executable is not found
    if (!$DISMFilePath) {
        Write-Host -Object "[Error] Failed to find Dism.exe at '$env:WinDir\System32\Dism.exe'."
        exit 1
    }

    # Prepare arguments for component cleanup if the option is enabled
    if ($ComponentCleanup) {
        $DISMArguments.Add("/StartComponentCleanup")
    }

    # Warn if a repair source is specified without a health action
    if ($RepairSource -ne "Windows Update" -and !$HealthAction) {
        Write-Host -Object "[Warning] A repair source of '$RepairSource' was given, but no health action was specified. This option will be ignored."
        $RepairSource = $Null
    }

    # Validate and process the health action if specified
    if ($HealthAction) {
        if ([String]::IsNullOrWhiteSpace($HealthAction)) {
            Write-Host -Object "[Error] An invalid action was provided. It was null or contained only whitespace."
            exit 1
        }

        $HealthAction = $HealthAction.Trim()

        switch ($HealthAction) {
            "Check Health" { $DISMArguments.Add("/CheckHealth") }
            "Scan Health" { $DISMArguments.Add("/ScanHealth") }
            "Restore Health" { $DISMArguments.Add("/RestoreHealth") }
            default {
                Write-Host -Object "[Error] An invalid action '$HealthAction' was given."
                Write-Host -Object "[Error] You must specify a valid action such as 'Check Health', 'Scan Health', or 'Restore Health'."
                exit 1
            }
        }
    }

    # Validate and process the repair source if specified
    if ($RepairSource) {
        # Validate that the repair source is not null or whitespace
        if ([String]::IsNullOrWhiteSpace($RepairSource)) {
            Write-Host -Object "[Error] An invalid repair source was provided. It is null or contains only whitespace."
            exit 1
        }

        # Trim any leading or trailing whitespace from the repair source
        $RepairSource = $RepairSource.Trim()

        if ($HealthAction -ne "Restore Health" -and $RepairSource -ne "Windows Update") {
            Write-Host -Object "[Error] The health action '$HealthAction' you specified is incompatible with the '$RepairSource' repair source."
            Write-Host -Object "[Error] Either specify 'Windows Update', or specify 'Restore Health'."
            exit 1
        }

        # Process the repair source based on its value
        switch ($RepairSource) {
            "Windows Update" {
                # No additional arguments needed for Windows Update
            }
            "Local SxS Folder" {
                # Use the local WinSxS folder as the repair source
                $DISMArguments.Add("/Source:`"$env:WinDir\WinSxS`"")
                $DISMArguments.Add("/LimitAccess")
            }
            "Mounted ISO" {
                # Handle the case where a mounted ISO is used as the repair source
                $ISOSource = New-Object -TypeName System.Collections.Generic.List[string]
                try {
                    # Search for mounted CD-ROM/ISO files
                    Write-Host -Object "Searching for mounted CD-ROM/ISO files."
                    $PossibleISOs = Get-Volume -ErrorAction Stop | Where-Object { $_.DriveType -eq "CD-ROM" -and $_.DriveLetter }
                } catch {
                    # Log an error if retrieving mounted volumes fails
                    Write-Host -Object "[Error] $($_.Exception.Message)"
                    Write-Host -Object "[Error] Failed to retrieve a list of the currently mounted volumes."
                    exit 1
                }

                # Exit if no mounted ISO files are found
                if (!$PossibleISOs) {
                    Write-Host -Object "[Error] Unable to find any mounted CD-ROM/ISO files."
                    try {
                        # Display a list of mounted volumes for debugging
                        $ErrorActionPreference = "Stop"
                        Get-Volume | Select-Object DriveLetter, FileSystemLabel, DriveType, OperationalStatus | Sort-Object DriveLetter | Format-Table | Out-String | Write-Host
                    } catch {
                        $ErrorActionPreference = "Continue"
                        Write-Host -Object "[Error] $($_.Exception.Message)"
                        Write-Host -Object "[Error] Failed to retrieve a list of mounted volumes."
                        exit 1
                    }

                    $ErrorActionPreference = "Continue"
                    exit 1
                }

                try {
                    # Retrieve the OS caption to identify the correct Windows image
                    $OSCaption = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).Caption
                    $OSCaption = $OSCaption -replace "Microsoft "
                } catch {
                    # Log an error if gathering the OS caption fails
                    Write-Host -Object "[Error] $($_.Exception.Message)"
                    Write-Host -Object "[Error] Failed to gather the OS Caption. This is needed to identify the correct Windows image."
                    exit 1
                }

                # Validate the mounted ISO and check for required files
                $PossibleISOs | ForEach-Object {
                    Write-Host -Object "Verifying the drive '$($_.DriveLetter)' is valid Windows installation media."

                    # Check for the presence of install.wim or install.esd
                    if (!(Test-Path -Path "$($_.DriveLetter):\sources\install.wim" -ErrorAction SilentlyContinue) -and
                        !(Test-Path -Path "$($_.DriveLetter):\sources\install.esd" -ErrorAction SilentlyContinue)) {
                        Write-Host -Object "[Warning] '$($_.DriveLetter):\sources' does not contain install.wim or install.esd."
                        return
                    }

                    # Check for the presence of setup.exe
                    if (!(Test-Path -Path "$($_.DriveLetter):\setup.exe" -ErrorAction SilentlyContinue)) {
                        Write-Host -Object "[Warning] '$($_.DriveLetter):\setup.exe' was not found."
                        return
                    }

                    # Verify the digital signature of setup.exe
                    try {
                        $FileSignature = Get-AuthenticodeSignature -FilePath "$($_.DriveLetter):\setup.exe" -ErrorAction Stop
                    } catch {
                        Write-Host -Object "[Warning] $($_.Exception.Message)"
                        Write-Host -Object "[Warning] Failed to check the file signature of '$($_.DriveLetter):\setup.exe'."
                        return
                    }

                    # Validate the signature status and issuer
                    if ($FileSignature.Status -ne "Valid") {
                        Write-Host -Object "[Warning] The file signature of '$($_.DriveLetter):\setup.exe' is $($FileSignature.Status)."
                        return
                    }

                    if ($FileSignature.SignerCertificate.IssuerName.Name -notmatch "Microsoft Corporation") {
                        Write-Host -Object "[Warning] The file signature of '$($_.DriveLetter):\setup.exe' has an issuer name of '$($FileSignature.SignerCertificate.IssuerName.Name)'."
                        Write-Host -Object "[Warning] 'Microsoft Corporation' was expected."
                        return
                    }

                    if ($FileSignature.SignerCertificate.Subject -notmatch "Microsoft Corporation") {
                        Write-Host -Object "[Warning] The file signature of '$($_.DriveLetter):\setup.exe' has a subject of '$($FileSignature.SignerCertificate.Subject)'."
                        Write-Host -Object "[Warning] 'Microsoft Corporation' was expected."
                        return
                    }

                    # Add the install.wim or install.esd file as the repair source
                    if (Test-Path -Path "$($_.DriveLetter):\sources\install.wim" -ErrorAction SilentlyContinue) {
                        try {
                            # Retrieve the proper index for the install.wim file
                            Write-Host -Object "Attempting to retrieve the proper index of '$($_.DriveLetter):\sources\install.wim'."
                            $WimInfo = Get-WindowsImage -ImagePath "$($_.DriveLetter):\sources\install.wim" -ErrorAction Stop
                            $WimIndex = $WimInfo | Where-Object { $_.ImageName -eq $OSCaption } | Select-Object -First 1 -ExpandProperty ImageIndex
                        } catch {
                            Write-Host -Object "[Warning] $($_.Exception.Message)"
                            Write-Host -Object "[Warning] Failed to retrieve any index information."
                            return
                        }

                        if (!$WimIndex) {
                            Write-Host -Object "[Warning] Failed to find the proper index for the OS '$OSCaption'."
                            return
                        }

                        $ISOSource.Add("WIM:`"$($_.DriveLetter):\sources\install.wim`":$WimIndex")
                        return
                    }

                    if (Test-Path -Path "$($_.DriveLetter):\sources\install.esd" -ErrorAction SilentlyContinue) {
                        try {
                            # Retrieve the proper index for the install.esd file
                            Write-Host -Object "Attempting to retrieve the proper index of '$($_.DriveLetter):\sources\install.esd'."
                            $WimInfo = Get-WindowsImage -ImagePath "$($_.DriveLetter):\sources\install.esd" -ErrorAction Stop
                            $WimIndex = $WimInfo | Where-Object { $_.ImageName -eq $OSCaption } | Select-Object -First 1 -ExpandProperty ImageIndex
                        } catch {
                            Write-Host -Object "[Warning] $($_.Exception.Message)"
                            Write-Host -Object "[Warning] Failed to retrieve any index information."
                            return
                        }

                        if (!$WimIndex) {
                            Write-Host -Object "[Warning] Failed to find the proper index for the OS '$OSCaption'."
                            return
                        }

                        $ISOSource.Add("ESD:`"$($_.DriveLetter):\sources\install.esd`":$WimIndex")
                    }
                }

                # Ensure only one ISO source is mounted
                if ($ISOSource.Count -gt 1) {
                    Write-Host -Object "[Error] Multiple possible ISO sources found. Please have only one ISO device mounted."
                    exit 1
                }

                # Exit if no valid ISO source is found
                if (!$ISOSource -or $ISOSource.Count -lt 1) {
                    Write-Host -Object "[Error] No valid ISO was found. Please mount a valid installation ISO."
                    exit 1
                }

                # Use the identified ISO source as the repair source
                Write-Host -Object "Using '$($ISOSource[0])' as the repair source.`n"
                $DISMArguments.Add("/Source:$($ISOSource[0])")
                $DISMArguments.Add("/LimitAccess")
            }
            default {
                # Log an error if an invalid repair source is provided
                Write-Host -Object "[Error] An invalid repair source '$RepairSource' was given."
                Write-Host -Object "[Error] You must specify a valid repair source such as 'Windows Update', 'Local SxS Folder', or 'Mounted ISO'."
                exit 1
            }
        }
    }

    if ($MaxTimeout -lt 1 -or $MaxTimeout -gt 120) {
        Write-Host -Object "[Error] An invalid max timeout '$MaxTimeout' was provided. The max timeout must be between 1 and 120 (inclusive)."
        exit 1
    }

    $DISMArguments.Add("/NoRestart")

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
        # Initialize a stopwatch to track the timeout duration
        $DISMStopwatch = New-Object -TypeName System.Diagnostics.Stopwatch -ErrorAction Stop
        $DISMStopwatch.Start()
        $TimeoutInMilliSeconds = $MaxTimeout * 60000
    } catch {
        # Log an error and exit if the stopwatch fails to start
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to start the stopwatch used to keep track of the timeout."
        exit 1
    }

    # Check if a DISM process is already running
    $CurrentlyRunningProcess = Get-Process -Name "DISM" -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $DISMFilePath }
    if ($CurrentlyRunningProcess) {
        Write-Host -Object "[Error] DISM is already running with process ID '$($CurrentlyRunningProcess.Id)'. Please run this script once it has completed."
        exit 1
    }

    # Log the start of the DISM process with the specified arguments
    Write-Host -Object "Starting DISM at '$DISMFilePath' with the arguments '$($DISMArguments -join " ")'."
    try {
        # Create temporary files to store the standard output and error output of the DISM process
        $StandardOutputFile = New-TemporaryFile -ErrorAction Stop
        $StandardErrorFile = New-TemporaryFile -ErrorAction Stop
    } catch {
        # Log an error and exit if temporary files cannot be created
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to create a temporary file to store the DISM process output."
        exit 1
    }

    try {
        # Configure and start the DISM process
        $ProcessArguments = @{
            FilePath               = $DISMFilePath
            ArgumentList           = $DISMArguments
            RedirectStandardOutput = $StandardOutputFile.FullName
            RedirectStandardError  = $StandardErrorFile.FullName
            WindowStyle            = "Hidden"
            PassThru               = $True
        }

        $DISMProcess = Start-Process @ProcessArguments -ErrorAction Stop

        # Log the process ID of the started DISM process
        Write-Host -Object "Started the Windows Image Repair process using DISM with the process ID (PID) of '$($DISMProcess.Id)'."
    } catch {
        # Log an error and attempt to clean up temporary files if the DISM process fails to start
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to start the DISM process."

        try {
            if (Test-Path -Path $StandardOutputFile.FullName -ErrorAction SilentlyContinue) {
                Remove-Item -Path $StandardOutputFile.FullName -ErrorAction Stop
            }
        } catch {
            Write-Host -Object "[Warning] $($_.Exception.Message)"
            Write-Host -Object "[Warning] Failed to remove the temporary file '$($StandardOutputFile.FullName)'."
            Write-Host -Object "[Warning] This file was created to temporarily store the DISM standard output."
        }

        try {
            if (Test-Path -Path $StandardErrorFile.FullName -ErrorAction SilentlyContinue) {
                Remove-Item -Path $StandardErrorFile.FullName -ErrorAction Stop
            }
        } catch {
            Write-Host -Object "[Warning] $($_.Exception.Message)"
            Write-Host -Object "[Warning] Failed to remove the temporary file '$($StandardErrorFile.FullName)'."
            Write-Host -Object "[Warning] This file was created to temporarily store the DISM error output."
        }

        exit 1
    }

    try {
        # Wait for the DISM process to complete or timeout
        $TimeoutRemaining = [math]::Max(0, ($TimeoutInMilliSeconds - $DISMStopwatch.Elapsed.TotalMilliseconds))
        if (!$DISMProcess.WaitForExit($TimeoutRemaining)) {
            Write-Host -Object "[Warning] The timeout of '$MaxTimeout' minutes has been reached."
        }
    } catch {
        # Log an error if waiting for the DISM process fails
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to wait for the DISM process to complete."
        exit 1
    }

    if ($DISMProcess.ExitCode -and $DISMProcess.ExitCode -ne 0) {
        # Log an error if the DISM process exit code indicates failure
        Write-Host -Object "[Error] Exit code '$($DISMProcess.ExitCode)' does not indicate success."
        $ExitCode = 1
    }

    if (Test-Path -Path $StandardOutputFile.FullName -ErrorAction SilentlyContinue) {
        try {
            # Retrieve and process the standard output from the DISM process
            $Output = Get-Content -Path $StandardOutputFile.FullName -Encoding Oem -ErrorAction Stop
            $Header = $Output | Select-Object -First 6 | Where-Object { $_ -notmatch "^\[.*\]" }
            $RestOfOutput = $Output | Select-Object -Skip 6 | Where-Object { $_ -and $_ -notmatch "^\[.*\]" }
            $LastProgressBar = $Output | Where-Object { $_ -match "^\[.*\]" } | Select-Object -Last 1

            $CleanedUpOutput = $Header, $LastProgressBar, $RestOfOutput | Out-String

            Write-Host -Object $CleanedUpOutput
            if ($CleanedUpOutput -match "Error") {
                $ExitCode = 1
            }
        } catch {
            # Log an error if retrieving the standard output fails
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to retrieve the script output from '$($StandardOutputFile.FullName)'."
            $ExitCode = 1
        }
    } else {
        # Log an error if the standard output file does not exist
        Write-Host -Object "[Error] Failed to retrieve the script output from '$($StandardOutputFile.FullName)' as it does not exist."
        $ExitCode = 1
    }

    if ($DISMProcess.HasExited -and (Test-Path -Path $StandardOutputFile.FullName -ErrorAction SilentlyContinue)) {
        try {
            # Remove the standard output file after the DISM process has exited
            Remove-Item -Path $StandardOutputFile.FullName -ErrorAction Stop
        } catch {
            # Log an error if removing the standard output file fails
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to remove '$($StandardOutputFile.FullName)'."
            Write-Host -Object "[Error] This file was created to store the DISM output temporarily."
            $ExitCode = 1
        }
    }

    if (Test-Path -Path $StandardErrorFile.FullName -ErrorAction SilentlyContinue) {
        try {
            # Retrieve and log the error output from the DISM process
            $ErrorContent = Get-Content -Path $StandardErrorFile.FullName -Encoding Oem -ErrorAction Stop

            $ErrorContent | ForEach-Object {
                Write-Host -Object "[Error] $_"
                $ExitCode = 1
            }
        } catch {
            # Log an error if retrieving the error output fails
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to retrieve the script error output from '$($StandardErrorFile.FullName)'."
            $ExitCode = 1
        }
    } else {
        # Log an error if the error output file does not exist
        Write-Host -Object "[Error] Failed to retrieve the script error output from '$($StandardErrorFile.FullName)' as it does not exist."
        $ExitCode = 1
    }

    if ($DISMProcess.HasExited -and (Test-Path -Path $StandardErrorFile.FullName -ErrorAction SilentlyContinue)) {
        try {
            # Remove the error output file after the DISM process has exited
            Remove-Item -Path $StandardErrorFile.FullName -ErrorAction Stop
        } catch {
            # Log an error if removing the error output file fails
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to remove '$($StandardErrorFile.FullName)'."
            Write-Host -Object "[Error] This file was created to store the DISM error output temporarily."
            $ExitCode = 1
        }
    }

    if (!$DISMProcess.HasExited) {
        # Log a warning if the DISM process is still running after the timeout
        Write-Host -Object "`n[Warning] The DISM process is still running with the process id of '$($DISMProcess.Id)'."
        Write-Host -Object "[Warning] DISM should store its logs in the default location (usually $env:WINDIR\Logs\DISM\dism.log)"

        if (Test-Path -Path $StandardOutputFile.FullName -ErrorAction SilentlyContinue) {
            Write-Host -Object "[Warning] An additional standard output log may be found at '$($StandardOutputFile.FullName)'."
        }

        if (Test-Path -Path $StandardErrorFile.FullName -ErrorAction SilentlyContinue) {
            Write-Host -Object "[Warning] An additional error log may be found at '$($StandardErrorFile.FullName)'."
        }

        exit $ExitCode
    }

    # Schedule a reboot if the ForceReboot switch is set
    if ($ForceReboot -and $ExitCode -eq 0 -and $DISMProcess.HasExited) {
        $RebootTime = (Get-Date).AddMinutes(5)
        Write-Host -Object "Scheduling a reboot for $($RebootTime.ToShortDateString()) $($RebootTime.ToShortTimeString())."

        try {
            # Schedule a system reboot
            Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" -ArgumentList "/r /t 300" -Wait -NoNewWindow -ErrorAction Stop
        } catch {
            # Log an error if scheduling the reboot fails
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] An error occurred while scheduling a forced reboot."
            $ExitCode = 1
        }
    }

    exit $ExitCode
}
end {
    
    
    
}