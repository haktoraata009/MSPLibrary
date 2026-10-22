#Requires -Version 5.1

<#
.SYNOPSIS
    Repairs Microsoft Office 365 installations supporting Quick Repair and Online Repair modes. Can optionally force close open Office apps and reboot if successful.

    Key Features:
        - Supports "Quick Repair" and "Online Repair" modes
        - Optionally force close open Microsoft Office applications
        - Optionally reboot machine after successful repair
        - Validates system requirements and Office installation type

    Important Warnings:
        - Save work before running; script may force close apps and/or reboot
        - For online repair: Ensure no Microsoft domains are blocked
        - MAINTAIN STABLE INTERNET DURING THE ONLINE REPAIR, ANY INTERRUPTION IN THE INTERNET CONNECTION MAY CAUSE THE REPAIR TO UNINSTALL AND NOT REINSTALL OFFICE.

.DESCRIPTION
    Repairs Microsoft Office 365 installations supporting Quick Repair and Online Repair modes. Can optionally force close open Office apps and reboot if successful.

    Key Features:
        - Supports "Quick Repair" and "Online Repair" modes
        - Optionally force close open Microsoft Office applications
        - Optionally reboot machine after successful repair
        - Validates system requirements and Office installation type

    Important Warnings:
        - Save work before running; script may force close apps and/or reboot
        - For online repair: Ensure no Microsoft domains are blocked
        - MAINTAIN STABLE INTERNET DURING THE ONLINE REPAIR, ANY INTERRUPTION IN THE INTERNET CONNECTION MAY CAUSE THE REPAIR TO UNINSTALL AND NOT REINSTALL OFFICE.

.EXAMPLE
    -RepairMode "Online Repair" -RebootIfSuccessful

    [Info] The script is running as the SYSTEM user.
    [Info] The OS build '19044' is supported.

    *********** Microsoft Office Install ***********
    Version:             16.0.19725.20126
    Install Path:        C:\Program Files\Microsoft Office
    Client Path:         C:\Program Files\Common Files\Microsoft Shared\ClickToRun
    Architecture:        x64
    Culture:             en-us
    ************************************************

    ****** Open Microsoft Office applications ******
    Id ProcessName      Path
    -- -----------      ----
    11004 OfficeClickToRun C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe
    ************************************************

    ############################### Starting Office 365 Repair ###############################
    Repair Mode               >> Online Repair
    Reboot on success         >> True
    Force Close Office Apps   >> False
    Repair Timeout            >> 1 hour(s) and 45 minute(s) and 0 second(s)

    [Info] Started the first part of the online repair process with ID: 7952 (hex: 0x1F10)
    [Info] First part of the online repair process completed in 3 minute(s) and 20 second(s).
    [Info] Inspecting the log file: (C:\Windows\Temp\DESKTOP-CL46S71-20260304-0855.log).
    [Info] Started 2nd part of online repair process with ID: 9604 (hex: 0x2584).
    [Info] The 2nd part of the full repair process completed in 6 minute(s) and 3 second(s).
    [Info] Inspecting the log file: (C:\Windows\Temp\DESKTOP-CL46S71-20260304-0858b.log).
    [Info] The Office 365 repair was successful and returned exit code: 0.
    [Info] The repair process does not require a reboot to complete, but the -RebootIfSuccessful parameter was passed. Scheduling reboot...
    [Info] Scheduled reboot of the current machine in 90 seconds.
    >>> The machine will reboot at 3/4/2026 9:06 AM.

.EXAMPLE
    -RepairMode "Quick Repair" -ForceCloseOfficeApps

    *********** Microsoft Office Install ***********
    Version:             16.0.19725.20126
    Install Path:        C:\Program Files\Microsoft Office
    Client Path:         C:\Program Files\Common Files\Microsoft Shared\ClickToRun
    Architecture:        x64
    Culture:             en-us
    ************************************************

    ****** Open Microsoft Office applications ******
    Id ProcessName      Path
    -- -----------      ----
    4148 EXCEL            C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE
    11004 OfficeClickToRun C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe
    20256 WINWORD          C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE
    ************************************************

    ############################### Starting Office 365 Repair ###############################
    Repair Mode               >> Quick Repair
    Reboot on success         >> False
    Force Close Office Apps   >> True
    Repair Timeout            >> 15 minute(s) and 0 second(s)

    [Info] Started the quick repair process with ID: 5124 (hex: 0x1404)
    [Info] The quick repair process completed in 2 minute(s) and 12 second(s).
    [Info] Inspecting the log file: (C:\Windows\Temp\DESKTOP-CL46S71-20260304-0850.log).
    [Info] The Office 365 repair was successful and returned exit code: 0.

.PARAMETER RepairMode
    The type of Microsoft Office repair to perform. Valid options are "Quick Repair" and "Online Repair".

.PARAMETER ForceCloseOfficeApps
    A switch that indicates whether to force close any open Microsoft Office applications before starting the repair process. If there are open Microsoft Office applications and this switch is not used the repair process may fail.

.PARAMETER RebootIfSuccessful
    A switch that indicates whether to reboot the machine if the repair process completes successfully.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$RepairMode,

    [Parameter()]
    [switch]$ForceCloseOfficeApps = [System.Convert]::ToBoolean($env:forceCloseOfficeApps),

    [Parameter()]
    [switch]$RebootIfSuccessful = [System.Convert]::ToBoolean($env:rebootIfSuccessful)
)

begin {
    #region validating arguments
    if ([string]::IsNullOrWhiteSpace($env:repairMode) -eq $false) {
        $RepairMode = $env:repairMode
    }
    if ($RepairMode -notin @("Quick Repair", "Online Repair")) {
        Write-Host -Object "[Error] -RepairMode argument is not a valid option. User passed '$($RepairMode)', but should be either 'Quick Repair' or 'Online Repair'."
        exit 1
    }
    #endregion

    #region helper functions
    function Format-DynamicBanner {
        [CmdletBinding(DefaultParameterSetName = "NoTitle")]
        param(
            [Parameter(Mandatory = $true, ParameterSetName = "TopLine")]
            [Parameter(Mandatory = $true, ParameterSetName = "BottomLine")]
            [string]$Title,

            [Parameter(Mandatory = $false, ParameterSetName = "NoTitle")]
            [switch]$NoTitle,

            [Parameter(Mandatory = $true)]
            [ValidateRange(1, 100)]
            [int]$Percentage,

            [Parameter(Mandatory = $true)]
            [ValidateLength(1, 1)]
            [string]$Separator,

            [Parameter(Mandatory = $true, ParameterSetName = "TopLine")]
            [switch]$TopLine,

            [Parameter(Mandatory = $true, ParameterSetName = "BottomLine")]
            [switch]$BottomLine,

            [Parameter(ParameterSetName = "BottomLine")]
            [Parameter(ParameterSetName = "TopLine")]
            [ValidateScript({ if (($_ % 2) -ne 0) { throw "-MinSeparatorsForTitle must be an even number" }$true })]
            [int]$MinSeparatorsForTitle = 8
        )
        try {
            # defaults to size of 120 width
            try {
                $totalWindowWidth = $Host.UI.RawUI.WindowSize.Width
            } catch {
                $totalWindowWidth = 120
            }

            # the total width of the banner factoring in the percentage that was passed in
            $bannerWidth = [System.Math]::Floor( ($totalWindowWidth * $Percentage) / 100 )

            # the user only wants a solid line of separators with the percentage entered, no title factored in
            if ($PSCmdlet.ParameterSetName -eq "NoTitle") {
                return ($Separator * $bannerWidth)
            }

            # the title with spaces and the minimum separators
            $titleWithSpaces = " $Title "
            $minTitleWidth = ($titleWithSpaces.Length + $MinSeparatorsForTitle)

            # the title with spaces and the minimum separators is greater than the banner width that it is currently allocated for
            if ( $minTitleWidth -gt $bannerWidth) {

                # the title with spaces and the min separators is bigger than the entire width of the window
                if ( $minTitleWidth -gt $totalWindowWidth ) {

                    if ($PSCmdlet.ParameterSetName -eq "TopLine") {
                        return [String]::Concat(
                            ($Separator * $totalWindowWidth),
                            "`n",
                            $Title,
                            "`n",
                            ($Separator * $totalWindowWidth)
                        )
                    } else {
                        return ($Separator * $totalWindowWidth)
                    }

                } else {
                    # set the banner width to the min space needed for the title with spaces and min separators
                    $bannerWidth = $minTitleWidth
                }

            }

            # gets the number of separators to use subtracting the title with spaces from the banner width that is set
            $remainingWidth = $bannerWidth - $titleWithSpaces.Length
            # num of separators on the left of the title
            $leftPaddingLength = [System.Math]::Floor( ($remainingWidth) / 2 )
            # num of separators on the right of the title
            $rightPaddingLength = $remainingWidth - $leftPaddingLength

            # return the topline result
            if ($PSCmdlet.ParameterSetName -eq "TopLine") {
                return [String]::Concat(
                    ($Separator * $leftPaddingLength),
                    $titleWithSpaces,
                    ($Separator * $rightPaddingLength)
                )
            }
            # return the bottom line result
            else {
                return ($Separator * $bannerWidth)
            }
        } catch {
            # writes basic banner if there was an error above
            if ($PSCmdlet.ParameterSetName -eq "TopLine") {
                return [string]::Concat(
                    ( $Separator * ($MinSeparatorsForTitle / 2) ),
                    " $($Title) ",
                    ( $Separator * ($MinSeparatorsForTitle / 2) )
                )
            } else {
                return [string]::Concat(
                    $Separator * ($MinSeparatorsForTitle + 2 + $Title.Length)
                )
            }
        }
    }
    function Test-ScriptIsRunningAsSystem {
        try {
            $WindowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $scriptIsRunningAsSystem = $WindowsIdentity.IsSystem -or $WindowsIdentity.User -eq "S-1-5-18"
        } catch {
            throw "[Error] There was an error attempting to determine if the script is being ran as the SYSTEM user.`nERROR:($($_.Exception.Message))."
        }

        return $scriptIsRunningAsSystem
    }
    function Test-WindowsBuildVersionIsSupported {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [int]$BuildNumber
        )

        try {
            $isBuildVersionSupported = [System.Environment]::OSVersion.Version.Build -ge $BuildNumber
        } catch {
            throw "[Error] There was an error attempting to determine the windows build version.`nERROR:($($_.Exception.Message))"
        }

        return $isBuildVersionSupported
    }
    #endregion

    #region Script specific functions
    <#
        .DESCRIPTION
        - Gets the Microsoft Office installation type

        .OUTPUTS
        A string representing the installation type of Microsoft Office
            - "Not Installed"
            - "Click-To-Run"
            - "MSI"
            - "Microsoft Store"
    #>
    function Get-O365InstallerType {
        [CmdletBinding()]
        param()
        $errMsgPrefix = "[Error] There was an error attempting to get the Microsoft Office installation type.`n >>> "
        try {
            $installerType = [System.Collections.Generic.List[string]]::new()

            #region Click-To-Run
            $clickToRunRegPath = "Registry::HKLM\SOFTWARE\Microsoft\Office\ClickToRun\"
            if (Test-Path -Path $clickToRunRegPath -ErrorAction SilentlyContinue) {
                $installerType.Add("Click-To-Run")
            }
            #endregion

            #region MSI
            $path = "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            $officeMSI = Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object {
                $_.DisplayName -like "*Microsoft Office*" -and $_.UninstallString -like "*MsiExec.exe*"
            }
            if ($officeMSI) {
                $installerType.Add("MSI")
            }
            #endregion

            #region Microsoft Store
            $microsoftStoreOfficeInstall = Get-AppxPackage -Name "Microsoft.Office.Desktop*" -ErrorAction SilentlyContinue
            if ($microsoftStoreOfficeInstall) {
                $installerType.Add("Microsoft Store")
            }
            #endregion

            # no installer type was found, office not installed
            if ($installerType.Count -eq 0) {
                return "Not Installed"
            }

            # multiple installer types, throw error
            if ($installerType.Count -gt 1) {
                throw "$($errMsgPrefix)Multiple installer types were found for Microsoft Office. Detected installer types: [$($installerType -join ', ')]."
            }

            # return the installer type
            return $installerType[0]
        } catch {
            # expected error
            if ($_.Exception.Message -match "^(\[Error\])(.*)") {
                throw $_.Exception.Message
                # unexpected error
            } else {
                throw "[Error] There was an unexpected error trying to get the Microsoft Office installation information.`nERROR: ($($_.Exception.Message))."
            }
        }
    }

    <#
        .DESCRIPTION
        - Gets the Microsoft Office Click-To-Run installation information from the registry.

        .OUTPUTS
        A PSCustomObject with the following properties:
            - Version: The version of the Microsoft Office installation
            - Architecture: The architecture of the Microsoft Office installation, either "x86" or "x64"
            - InstallPath: The path to the Microsoft Office installation
            - ClientPath: The path to the Microsoft Office client folder
            - Culture: The culture of the Microsoft Office installation
    #>
    function Get-MSOfficeC2RInstall {
        [CmdletBinding()]
        param()
        $errMsgPrefix = "[Error] There was an error attempting to get the Microsoft Office installation information.`n >>> "
        try {
            $C2RPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"

            if ( (Test-Path $C2RPath) -eq $false ) { throw "$($errMsgPrefix)The registry path to the Microsoft Office Click-To-Run configuration: ($($C2RPath)) does not exist." }

            try {
                $C2R_RegKeyProperties = Get-ItemProperty -Path $C2RPath -ErrorAction Stop
            } catch { throw "$($errMsgPrefix)There was an error attempting to get the Click-To-Run registry key object at registry path: ($($C2RPath))." }

            if ($null -eq $C2R_RegKeyProperties) { throw "$($errMsgPrefix)The registry key object for the Microsoft Office Click-To-Run configuration was null." }

            # verify all of the required registry keys exist
            $missingRegKeyNames = [System.Collections.Generic.List[string]]::new()
            if (-not $C2R_RegKeyProperties.PsObject.Properties['VersionToReport']) { $missingRegKeyNames.Add('VersionToReport') }
            if (-not $C2R_RegKeyProperties.PsObject.Properties['Platform']) { $missingRegKeyNames.Add('Platform') }
            if (-not $C2R_RegKeyProperties.PsObject.Properties['InstallationPath']) { $missingRegKeyNames.Add('InstallationPath') }
            if (-not $C2R_RegKeyProperties.PsObject.Properties['ClientFolder']) { $missingRegKeyNames.Add('ClientFolder') }
            if (-not $C2R_RegKeyProperties.PsObject.Properties['ClientCulture']) { $missingRegKeyNames.Add('ClientCulture') }
            if ($missingRegKeyNames.Count -gt 0) {
                throw "$($errMsgPrefix)The Microsoft Office registry key is missing the following registry sub-key(s): [$($missingRegKeyNames -join ', ')]."
            }

            # verify version
            $version = $null
            if ( ([version]::TryParse($C2R_RegKeyProperties.VersionToReport, [ref]$version)) -eq $false ) {
                throw "$($errMsgPrefix)There was an issue parsing the Office version: '$($C2R_RegKeyProperties.VersionToReport)'."
            }

            # verify architecture
            $architecture = $C2R_RegKeyProperties.Platform
            if ($architecture -notin @('x86', 'x64')) {
                throw "$($errMsgPrefix)The Office computer architecture '$($architecture)' was not in the expected [x86, x64]."
            }

            # verify the installation path
            $installPath = $C2R_RegKeyProperties.InstallationPath
            if ( (Test-Path -Path $installPath) -eq $false ) {
                throw "$($errMsgPrefix)The installation path to Microsoft Office ($($installPath)) does not exist."
            }

            # verify the client path
            $clientPath = $C2R_RegKeyProperties.ClientFolder
            if ( (Test-Path -Path $clientPath) -eq $false ) {
                throw "$($errMsgPrefix)The client folder path for Microsoft Office ($($clientPath)) does not exist."
            }

            # get the client culture
            $clientCulture = $C2R_RegKeyProperties.ClientCulture

            # return the version and platform
            return [PSCustomObject]@{
                Version      = $version
                Architecture = $architecture
                InstallPath  = $installPath
                ClientPath   = $clientPath
                Culture      = $clientCulture
            }
        } catch {
            # expected error
            if ($_.Exception.Message -match "^(\[Error\])(.*)") {
                throw $_.Exception.Message
                # unexpected error
            } else {
                throw "[Error] There was an unexpected error trying to get the Microsoft Office Installation information.`nERROR: ($($_.Exception.Message))."
            }
        }
    }

    <#
        .DESCRIPTION
        - Gets all of the currently open Microsoft Office applications that are running on the machine.

        .PARAMETER OfficeInstallPath
        The path to the Microsoft Office installation. ex. C:\Program Files\Microsoft Office

        .PARAMETER OfficeVersion
        The version of the Microsoft Office installation. ex. 16.0.10396.20017

        .OUTPUTS
        An array of PSCustomObjects with the following properties:
            - Id: The process ID of the open Microsoft Office application
            - ProcessName: The name of the process of the open Microsoft Office application
            - Path: The path to the executable of the running application
    #>
    function Get-MSOfficeOpenedApplications {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$OfficeInstallPath,
            [Parameter(Mandatory = $true)]
            [version]$OfficeVersion
        )
        $errMsgPrefix = "[Error] There was an error attempting to get the open Microsoft Office applications.`n >>> "
        try {
            # ex 64bit. C:\Program Files\Microsoft Office\root\Office16
            # ex 32bit. C:\Program Files (x86)\Microsoft Office\root\Office16
            $rootOfficeVersionPath = Join-Path -Path $OfficeInstallPath -ChildPath "root\Office$($OfficeVersion.Major)"

            # microsoft root office path does not exist
            if ( (Test-Path -Path $rootOfficeVersionPath) -eq $false ) { throw "$($errMsgPrefix)The path to the Microsoft Office root ($($rootOfficeVersionPath)) does not exist." }

            # get all of the open microsoft office processes
            try {
                $officeProcesses = Get-Process -ErrorAction Stop |
                    Where-Object {
                        $_.Path -like "$($rootOfficeVersionPath)*" -or
                        $_.ProcessName -in @("WINWORD", "EXCEL", "POWERPNT", "OUTLOOK", "ONENOTE", "MSPUB", "LYNC", "VISIO", "MSACCESS", "FileCoAuth", "OfficeBackgroundTaskHandler", "OfficeClickToRun")
                    } |
                    Select-Object -Property Id, ProcessName, Path
            } catch {
                throw "$($errMsgPrefix)Unable to get the processes that are currently running Microsoft Office applications at path: ($($rootOfficeVersionPath)). ERROR: ($($_.Exception.Message))."
            }

            # returns the list of office processes that are currently open, null if there isn't any
            return $officeProcesses
        } catch {
            # expected error
            if ($_.Exception.Message -match "^(\[Error\])(.*)") {
                throw $_.Exception.Message
                # unexpected error
            } else {
                throw "[Error] There was an unexpected error attempting to get all of the open Microsoft Office applications.`nERROR: ($($_.Exception.Message))."
            }
        }

    }

    <#
        .DESCRIPTION
        - Takes in a process id and gets the corresponding log files from the $env:WINDIR\Temp directory that contain information about that process id
        - Instead of reading all possible logs files in the $env:WINDIR\Temp directory it just gets the most recent 15 log files that match the naming convention for the Office Click-To-Run log files, this is because when a repair process is ran it generates a log file every time it is ran and it can generate multiple log files during the repair process, so this will help to limit the number of log files that we need to read through to find the relevant information about the repair process.

        .PARAMETER ProcessId
        The process id that we will convert to hex and look for in the log files in the temp directory.

        .OUTPUTS
        An array of objects with the following properties:
            - Timestamp: The timestamp of the log entry
            - Process: The process associated with the log entry
            - TID: The thread id associated with the log entry
            - Area: The area of the log entry
            - Category: The category of the log entry
            - EventID: The event id of the log entry
            - Level: The level of the log entry
            - Message: The message of the log entry
            - Correlation: The correlation id of the log entry
    #>
    function Get-LogFileContentForProcessId {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [int]$ProcessId
        )

        # the process id in the log files is stored in hex
        $hexProc1 = '0x{0:X}' -f $ProcessId

        # path to the log files
        $winTempPath = Join-Path -Path $env:WINDIR -ChildPath "Temp"

        # log files naming convention ex. MyHomeDesktop-20260302-0824.log

        # use this if you want to only get the file by yyyy/mm/dd
        # $officeClickToRunLogFileNamePattern = "$(hostname)-$(Get-Date -Format yyyy)$(Get-Date -Format MM)$(Get-Date -Format dd)*.log"

        # use this if you want to only get the file by yyyy/mm
        $officeClickToRunLogFileNamePattern = "$(hostname)-$(Get-Date -Format yyyy)$(Get-Date -Format MM)*.log"

        # get the log file names
        try {
            # the pattern is searched and should return the log file names of the files that contain the process id in hex that we are looking for
            $recentLogFileNames = Select-String -Path "$winTempPath\$officeClickToRunLogFileNamePattern*" -Pattern "($($hexProc1))" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -Unique -ErrorAction Stop | Get-Item -ErrorAction Stop | Sort-Object -Property LastWriteTime -Descending -ErrorAction Stop | Select-Object -First 10 -ExpandProperty FullName -ErrorAction Stop
        } catch {
            throw "There was an error querying the log files in the temp directory at path: ($winTempPath). ERROR: ($($_.Exception.Message))."
        }

        # no log files were returned
        if (-not $recentLogFileNames) {
            throw "There are no log files in the temp directory at path: ($winTempPath) that match the naming convention: ($officeClickToRunLogFileNamePattern)."
        }

        $logFileContent=[System.Collections.Generic.List[Object]]::new()
        $expectedHeader = "Timestamp`tProcess`tTID`tArea`tCategory`tEventID`tLevel`tMessage`tCorrelation"
        foreach($lf in $recentLogFileNames) {

            # grab the header line of the log file
            try {
                $firstLine = Get-Content -Path $lf -TotalCount 1 -ErrorAction Stop
            } catch {
                Write-Host -Object "[Warning] There was an issue reading the first line of log file: $($lf) to determine if the header is in the expected format. ERROR: ($($_.Exception.Message)). Skipping this log file."
                continue
            }

            # skip if header is not what is expected
            if ($null -eq $firstLine -or $firstLine -ne $expectedHeader) {
                Write-Host -Object "[Warning] The log file: $($lf) does not have the expected format header, skipping log file."
                continue
            }

            # import log file, filter
            try {
                $logFile=$null
                $logFile = Import-Csv -Path $lf -Delimiter "`t" -ErrorAction Stop
                # filter to only get the log entries that contain the process id we are looking for
                $logFile = ($logFile | Where-Object { $_.Process -like "*$($hexProc1)*" } )
            } catch {
                Write-Host -Object "[Warning] There was an error attempting to import the log file at path: ($($lf)). ERROR: ($($_.Exception.Message)). Skipping this log file."
                continue
            }

            # the log file did not contain any entries with the process id we are looking for
            if($null -eq $logFile -or $logFile.Count -eq 0) {
                continue
            }

            # add the log file to the total log file content that is returned by this function
            try {
                # adding to the log file content list that is returned
                Write-Host -Object "[Info] Inspecting the log file: ($lf)."
                $logFileContent.AddRange($logFile)
            } catch {
                throw "There was an error adding the log file content from the log file at path: ($($lf)) to the total log file content that is returned by this function. ERROR: ($($_.Exception.Message))."
            }
        }

        # there is no data in the log file content, that means none of the log files contained the process we are looking for
        if($logFileContent.Count -eq 0) {
            Write-Host -Object "[Warning] There are no log file entries that have the process: $($hexProc1)."
        }

        return $logFileContent
    }

    <#
        .DESCRIPTION
        - Invokes the Office 365 repair process using the OfficeClickToRun.exe file.
        - This function will throw an error if
            - there was an issue starting the repair process,
            - the repair process did not finish in the time allocated,
            - the repair process returned an error code.
        - This function will return an object a PSCustomObject containing the following properties:
            - ExitCode: The exit code from the repair process
            - RebootRequired: A boolean indicating if a reboot is required to complete the repair process
            - Message: A message describing the result of the repair process

        .PARAMETER OfficeClientPath
        The path to the Microsoft Office client folder, this is the path that contains the OfficeClickToRun.exe file.

        .PARAMETER OfficeArchitecture
        The architecture of the Microsoft Office installation, either "x86" or "x64".

        .PARAMETER RepairType
        The type of repair to perform, either "QuickRepair" or "FullRepair".

        .PARAMETER ForceAppShutdown
        The value to pass to the repair process for the ForceAppShutdown argument, either "True" or "False".

        .PARAMETER TimeoutSeconds
        The number of seconds to wait for the repair process to complete before timing out and throwing an error.

        .OUTPUTS
        PSCustomObject with the following properties:
            - ExitCode: The exit code from the repair process
            - RebootRequired: A boolean indicating if a reboot is required to complete the repair process
            - Message: A message describing the result of the repair process
    #>
    function Invoke-Office365Repair {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$OfficeClientPath,

            [Parameter(Mandatory = $true)]
            [ValidateSet("x86", "x64")]
            [string]$OfficeArchitecture,

            [Parameter(Mandatory = $true)]
            [ValidateSet("QuickRepair", "FullRepair")]
            [string]$RepairType,

            [Parameter(Mandatory = $true)]
            [ValidateSet("True", "False")]
            [string]$ForceAppShutdown,

            [Parameter(Mandatory = $true)]
            [int]$TimeoutSeconds
        )
        $errMsgPrefix = "[Error] There was an error during the Office 365 repair process.`n >>> "
        try {
            #region pre-repair checks
            $officeClickToRunFilePath = Join-Path -Path $OfficeClientPath -ChildPath "OfficeClickToRun.exe"
            if ( (Test-Path -Path $officeClickToRunFilePath) -eq $false ) {
                throw "$($errMsgPrefix)The repair file at path: ($($officeClickToRunFilePath)) was not found."
            }

            # get already running office repair processes, only 1 repair process can run at a time
            try {
                $runningOfficeRepairs = @(
                    Get-CimInstance Win32_Process -Filter "Name = 'OfficeClickToRun.exe'" -ErrorAction Stop |
                        Where-Object { $_.CommandLine -match '(?i)(scenario\s*=\s*repair|productstoadd\s*=)' } |
                        Select-Object -Property Name, ProcessId, CommandLine, CreationDate
                )
            } catch {
                throw "$($errMsgPrefix)There was an error attempting to query for running Office repair processes. ERROR: ($($_.Exception.Message))."
            }

            if($runningOfficeRepairs.Count -eq 1) {
                throw "$($errMsgPrefix)There is already an Office repair process with ID: $($runningOfficeRepairs.ProcessId) running that started at $($runningOfficeRepairs.CreationDate) with command line: ($($runningOfficeRepairs.CommandLine)). Please wait for the current repair to finish before starting another one."
            }

            if($runningOfficeRepairs.Count -gt 1) {
                $runningOfficeRepairs | Format-Table -AutoSize | Out-String -Stream | Where-Object { $_ -match "\s" }
                throw "$($errMsgPrefix)There are multiple Office repair processes running. Please wait for the current repairs to finish before starting another one."
            }
            #endregion

            #region start the repair and wait to finish
            try {
                $repairArgs = @(
                    "Scenario=Repair",
                    "Platform=$($OfficeArchitecture)",
                    "RepairType=$($RepairType)",
                    "DisplayLevel=False",
                    "ForceAppShutdown=$($ForceAppShutdown)"
                )
                $o365RepairArgs = @{
                    FilePath     = $officeClickToRunFilePath
                    ArgumentList = $repairArgs
                    PassThru     = $true
                    WindowStyle  = "Hidden"
                    ErrorAction  = "Stop"
                }
                $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
                $o365RepairProcess = Start-Process @o365RepairArgs
            } catch {
                throw "$($errMsgPrefix)There was an error starting the O365 repair process.`nERROR: ($($_.Exception.Message))."
            }

            try {
                if($RepairType -eq "QuickRepair") {
                    Write-Host -Object "[Info] Started the quick repair process with ID: $($o365RepairProcess.Id) (hex: 0x$("{0:X}" -f $o365RepairProcess.Id))"
                } else {
                    Write-Host -Object "[Info] Started the first part of the online repair process with ID: $($o365RepairProcess.Id) (hex: 0x$("{0:X}" -f $o365RepairProcess.Id))"
                }

                $o365RepairProcess | Wait-Process -Timeout $TimeoutSeconds -ErrorAction Stop
            } catch {
                $timeSpan = $stopWatch.Elapsed

                if($RepairType -eq "QuickRepair") {
                    throw "$($errMsgPrefix)The quick repair did not finish in the time allocated."
                } else {
                    throw "$($errMsgPrefix)The first part of the online repair did not finish in the time allocated."
                }
            } finally {
                $stopWatch.Stop()
            }

            # get the time elapsed to complete the quick repair or the first part of the full repair
            $timeSpan = $stopWatch.Elapsed
            # subtract the time elapsed from the total timeout seconds to get the remaining seconds for the second part of the full repair if needed
            $TimeoutSeconds -= $timeSpan.TotalSeconds
            # puts the exit code in it's own variable
            $repairProcessExitCode = $o365RepairProcess.ExitCode
            #endregion

            #region quick repair
            ##### Quick Repair #####
            if($RepairType -eq "QuickRepair" -and ( $null -eq $repairProcessExitCode -or $repairProcessExitCode -eq 0 )) {
                # check if the repair returned anything in the exit code
                if($null -eq $repairProcessExitCode) {
                    Write-Host -Object "[Warning] The quick repair process did not return any exit code. Going to check the log file to determine if the quick repair was successful."
                }
                # display the time it took to complete the quick repair
                Write-Host -Object "[Info] The quick repair process completed in $(if($timeSpan.Hours -gt 0){"$($timeSpan.Hours) hour(s) and "})$(if($timeSpan.Minutes -gt 0){"$($timeSpan.Minutes) minute(s) and "})$($timeSpan.Seconds) second(s)."

                # get the log file entry that contains the result of the quick repair process
                try {
                    # we are using the event id 'aqtpj' to signify the finished quick repair process.
                    $quickRepairLogFileResult = (Get-LogFileContentForProcessId -ProcessId $o365RepairProcess.ID | Where-Object { $_.EventID -eq "aqtpj" } | Sort-Object -Property Timestamp -Descending | Select-Object -First 1)
                } catch {
                    if($null -eq $repairProcessExitCode) {
                        throw "$($errMsgPrefix)The quick repair process did not return any exit code and there was an error attempting to get the log file result for the quick repair process. Please view the logs at path: ($($env:windir)\Temp) for more information.`nERROR: ($($_.Exception.Message))."
                    } else {
                        throw "$($errMsgPrefix)The quick repair process returned an exit code of '$($repairProcessExitCode)', but there was an error attempting to get the log file result for the quick repair process to confirm the result. Please view the logs at path: ($($env:windir)\Temp) for more information.`nERROR: ($($_.Exception.Message))."
                    }
                }

                # no log file entry was found for the quick repair process with the expected event id
                if($null -eq $quickRepairLogFileResult) {
                    throw "$($errMsgPrefix)Unable to find the log file entry with event id 'aqtpj' signifying the end of the quick repair process. Please view the logs at path: ($($env:windir)\Temp) for more information."
                }

                # parse the log file result to get the return code
                if( ($null -ne $quickRepairLogFileResult.Message) -and ($quickRepairLogFileResult.Message -match "^Main: returned: (\d+)$") ) {
                    $quickRepairLogFileExitCode = $matches[1]
                } else {
                    throw "$($errMsgPrefix)The log file entry for the quick repair process with EventID 'aqtpj' did not have the expected format for the Message field. Expected format is 'Main: returned: [exit code]', but got: ($($quickRepairLogFileResult.Message)). Please view the logs at path: ($($env:windir)\Temp) for more information."
                }

                # if the exit code from the repair process is different than the exit code found in the log file, use the exit code from the log file.
                if($repairProcessExitCode -ne [int]$quickRepairLogFileExitCode) {
                    Write-Host -Object "[Warning] The exit code received from the quick repair process '$($repairProcessExitCode)' and the exit code found in the log file is different '$($quickRepairLogFileExitCode)'. Using the exit code found in the log file."
                    $repairProcessExitCode = [int]$quickRepairLogFileExitCode
                }
            }
            #endregion
            #region online repair
            ##### Online Repair #####
            elseif($RepairType -eq "FullRepair" -and ($null -eq $repairProcessExitCode -or $repairProcessExitCode -eq 0)) {
                #region online repair - process the results of the first part of the online repair
                if($null -eq $repairProcessExitCode) {
                    Write-Host -Object "[Warning] The first part of the online repair process did not return any exit code."
                }
                Write-Host -Object "[Info] First part of the online repair process completed in $(if($timeSpan.Hours -gt 0){"$($timeSpan.Hours) hour(s) and "})$(if($timeSpan.Minutes -gt 0){"$($timeSpan.Minutes) minute(s) and "})$($timeSpan.Seconds) second(s)."

                # get the log file entry that contains the result of the first part of the online repair process
                try {
                    # we are using the event id 'apr4c' to signify the finished first part of the online repair process.
                    $fullRepairLogFileResultPartOne = (Get-LogFileContentForProcessId -ProcessId $o365RepairProcess.ID | Where-Object { $_.EventID -eq "apr4c" } | Sort-Object -Property Timestamp -Descending | Select-Object -First 1)
                } catch {
                    Write-Host -Object "[Warning] There was an error attempting to get the log file result for the first part of the online repair process. Please view the logs at path: ($($env:windir)\Temp) for more information.`nERROR: ($($_.Exception.Message))."
                }

                # there are no log file entries that matches the entry id and process id
                if($null -eq $fullRepairLogFileResultPartOne) {
                    Write-Host -Object "[Warning] Unable to find the log file entry with event id 'apr4c' signifying the end of the first part of the online repair process. Please view the logs at path: ($($env:windir)\Temp) for more information."
                }
                #endregion

                #region online repair - follow and wait for the second part of the online repair
                $o365RepairProcessPart2=$null
                $secondsToWaitForPart2 = 60
                $countdownTimer = $secondsToWaitForPart2

                # wait until we find an OfficeClickToRun.exe process with the 'productstoadd' argument in the command line. We do this until we find or reach our timeout
                do {
                    Start-Sleep 1
                    $o365RepairProcessPart2 = Get-CimInstance Win32_Process -Filter "Name = 'OfficeClickToRun.exe' AND CommandLine LIKE '%productstoadd=%'" -ErrorAction SilentlyContinue | Where-Object { $_.CreationDate -gt $o365RepairProcess.CreationTime } | Sort-Object -Property CreationDate -Descending
                    $countdownTimer--
                } while($o365RepairProcessPart2 -eq $null -and $countdownTimer -gt 0)

                # start the timer for the second part of the repair process
                $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

                # the second part of the repair process did not start or was not found within the time allocated.
                if($null -eq $o365RepairProcessPart2) {
                    throw "$($errMsgPrefix)The second part of the online repair did not start or was not found within the time allocated: $secondsToWaitForPart2 seconds. This likely means that there was an issue with the first part of the online repair that prevented the second part from starting. This could possibly mean that the first part completely or partially removed the office apps on your computer without installing the new version, which would result in office being in a broken state. Please view the logs at path: ($($env:windir)\Temp) for more information."
                }

                # warn if there is more than 1 process that matches the criteria for the second part of the online repair, and select the most recent one to continue
                if($o365RepairProcessPart2.Count -gt 1) {
                    Write-Host -Object "[Warning] There are multiple process that match the criteria for the second part of the online repair process. Selecting the most recent one to continue. Process IDs: $($o365RepairProcessPart2.ProcessId -join ', ')."
                    $o365RepairProcessPart2 = $o365RepairProcessPart2 | Select-Object -First 1
                    Write-Host -Object "[Warning] Using process with ID: $($o365RepairProcessPart2.ProcessId) for the second part of the online repair process."
                }

                # get the process object for the second part of the online repair, used to call the wait method to wait for the process to finish
                try {
                    $o365RepairProcessPart2 = [System.Diagnostics.Process]::GetProcessById($o365RepairProcessPart2.ProcessId)
                } catch {
                    throw "$($errMsgPrefix)There was an error retrieving the second part of the online repair process by process ID '$($o365RepairProcessPart2.ProcessId)'."
                }

                # unable get the pid in the process object
                if($null -eq $o365RepairProcessPart2) {
                    throw "$($errMsgPrefix)There was an issue retrieving the second part of the online repair process."
                }

                # info the second part of the repair process
                Write-Host -Object "[Info] Started 2nd part of online repair process with ID: $($o365RepairProcessPart2.Id) (hex: 0x$("{0:X}" -f $o365RepairProcessPart2.Id))."

                # call the method to wait for the process to finish with the remaining timeout seconds
                try {
                    # we have to multiple the timeout seconds by 1000 because the WaitForExit method expects milliseconds
                    $finished = $o365RepairProcessPart2.WaitForExit($TimeoutSeconds * 1000)
                } catch {
                    throw "$($errMsgPrefix)There was an error while waiting for the second part of the online repair process to finish. ERROR: ($($_.Exception.Message))."
                }

                # stop the timer and get the time elapsed
                $stopWatch.Stop()
                $timeSpan = $stopWatch.Elapsed

                # throw error if it did not finish in the time allocated
                if($finished -eq $false) {
                    throw "$($errMsgPrefix)The second part of the repair did not finish in the time allocated: $TimeoutSeconds seconds."
                }

                Write-Host -Object "[Info] The 2nd part of the full repair process completed in $(if($timeSpan.Hours -gt 0){"$($timeSpan.Hours) hour(s) and "})$(if($timeSpan.Minutes -gt 0){"$($timeSpan.Minutes) minute(s) and "})$($timeSpan.Seconds) second(s)."
                $repairProcessExitCode = 0
                #endregion

                #region online repair - process the results of the second part of the online repair
                # get the log file result
                try {
                    # we are using the event id 'aqtpj' to signify the finished second part of the online repair process.
                    $fullRepairLogFileResultPartTwo = (Get-LogFileContentForProcessId -ProcessId $o365RepairProcessPart2.Id | Where-Object { $_.EventID -eq "aqtpj" } | Sort-Object -Property Timestamp -Descending | Select-Object -First 1)
                } catch {
                    throw "$($errMsgPrefix)There was an error attempting to get the log file result for the second part of the full repair process.`nERROR: ($($_.Exception.Message))."
                }

                if($null -eq $fullRepairLogFileResultPartTwo) {
                    throw "$($errMsgPrefix)There was no log file entry for the second part of the full repair process with EventID 'aqtpj'. This log entry is expected to be present for a full repair and should contain the return code for the second part of the full repair process. The absence of this log entry likely means that there was an issue during the second part of the full repair process that prevented it from completing successfully, but was still able to exit without returning an error code. Please view the logs at path: ($($env:windir)\Temp) for more information."
                }

                # parse the log file result to get the return code
                if($fullRepairLogFileResultPartTwo.Message -match "^Main: returned: (\d+)$") {
                    $returnCode = $matches[1]
                } else {
                    throw "$($errMsgPrefix)The log file entry for the second part of the full repair process with EventID 'aqtpj' did not have the expected format for the Message field. Expected format is 'Main: returned: [exit code]', but got: ($($fullRepairLogFileResultPartTwo.Message)). Please view the logs at path: ($($env:windir)\Temp) for more information."
                }

                # the return code was null or not found
                if($null -eq $returnCode) {
                    throw "$($errMsgPrefix)The log file entry for the second part of the full repair process with EventID 'aqtpj' did not contain a return code in the expected format. Expected format is 'Main: returned: [exit code]', but got: ($($fullRepairLogFileResultPartTwo.Message)). Please view the logs at path: ($($env:windir)\Temp) for more information."
                }

                # set the exit code to whatever was in the log for the second part of the full repair
                $repairProcessExitCode = [int]$returnCode
                #endregion
            }
            #endregion

            # list of known success codes
            $officeRepairSuccessCodes = @{
                0    = [PSCustomObject]@{ExitCode = 0; RebootRequired = $false; Message = "The operation completed successfully."; }
                3010 = [PSCustomObject]@{ExitCode = 3010; RebootRequired = $true; Message = "The operation was successful, but a system reboot is required to finish."; }
            }

            # the exit code is successful, return the object that matches the code
            $foundSuccessCode = $officeRepairSuccessCodes[$repairProcessExitCode]
            if ($foundSuccessCode) {
                return $foundSuccessCode
            }

            # list of known error codes
            $officeRepairErrorCodes = @{
                # --- Environment & Locking (17xxx) ---
                17100 = [PSCustomObject]@{ExitCode = 17100; Message = "Invalid arguments to the OfficeClickToRun.exe. Make sure all arguments being passed are valid." }
                17001 = [PSCustomObject]@{ExitCode = 17001; Message = "The Click-To-Run service is busy (updating, installing, or another repair is in progress)." }
                17002 = [PSCustomObject]@{ExitCode = 17002; Message = "Network Detection Failed: Unable to reach Microsoft online services (Check Internet/CDN)." }
                17003 = [PSCustomObject]@{ExitCode = 17003; Message = "The Click-To-Run service is disabled or could not be started." }
                17004 = [PSCustomObject]@{ExitCode = 17004; Message = "Insufficient disk space on the system drive to extract or download repair files." }
                17006 = [PSCustomObject]@{ExitCode = 17006; Message = "Conflict: One or multiple Office applications are open and blocking the process. Please close all open Microsoft Office applications and try again or run with the -ForceCloseOfficeApps argument." }
                17007 = [PSCustomObject]@{ExitCode = 17007; Message = "The Office installation source is corrupted or inaccessible." }
                17008 = [PSCustomObject]@{ExitCode = 17008; Message = "The installation or repair was manually cancelled by the user." }

                # --- Network & Downloads (30xxx) ---
                30088 = [PSCustomObject]@{ExitCode = 30088; Message = "Network Error: Could not download required files from the Office CDN." }
                30183 = [PSCustomObject]@{ExitCode = 30183; Message = "Proxy/Firewall Error: Connection blocked (often 403 Forbidden or 407 Auth Required)." }
                30125 = [PSCustomObject]@{ExitCode = 30125; Message = "Connection Timeout: The download took too long or the signal was lost." }
                30174 = [PSCustomObject]@{ExitCode = 30174; Message = "Unable to remove existing Office installation files." }

                # --- Permissions & System Errors ---
                1603  = [PSCustomObject]@{ExitCode = 1603; Message = "Fatal Error: A generic Windows Installer error (usually registry or folder permissions)." }
                5     = [PSCustomObject]@{ExitCode = 5; Message = "Access Denied: The script is not running with elevated (Administrator) privileges." }
                1602  = [PSCustomObject]@{ExitCode = 1602; Message = "The user cancelled the installation." }

                # --- Logic & Corruption ---
                30015 = [PSCustomObject]@{ExitCode = 30015; Message = "Service Failure: The Office Click-To-Run service failed to start or is corrupted." }
                30016 = [PSCustomObject]@{ExitCode = 30016; Message = "The repair engine could not find the specified installation path." }
                30068 = [PSCustomObject]@{ExitCode = 30068; Message = "The background Office service is not responding to the repair request." }
                30029 = [PSCustomObject]@{ExitCode = 30029; Message = "Office update or repair failed due to registry corruption." }
            }

            # The exit code is an error, return the object that matches the code
            $foundErrorCode = $officeRepairErrorCodes[$repairProcessExitCode]
            if ($foundErrorCode) {
                throw "$($errMsgPrefix)The repair failed with error code: $($foundErrorCode.ExitCode). Error Message: ($($foundErrorCode.Message))."
            } else {
                throw "$($errMsgPrefix)The repair failed, unknown error code=$($repairProcessExitCode)."
            }
        } catch {
            # expected error
            if ($_.Exception.Message -match "^(\[Error\])(.*)") {
                throw $_.Exception.Message
                # unexpected error
            } else {
                throw "[Error] There was an unexpected error attempting to invoke the Office 365 repair.`nERROR: ($($_.Exception.Message))."
            }
        }
    }

    <#
        .DESCRIPTION
        Scheduled restart of the local machine. Doesn't return anything, but will throw an error if there was an issue scheduling the restart.

        .PARAMETER RestartInSeconds
        The time in seconds to restart

        .PARAMETER CustomMessage
        Custom message to display to the user signed into the machine when the restart is scheduled.

        .OUTPUTS
        None
    #>
    function Restart-LocalMachine {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [int]$RestartInSeconds,

            [Parameter(Mandatory = $false)]
            [string]$CustomMessage = $null
        )
        $errMsgPrefix = "[Error] There was an error attempting to restart the local machine.`n >>> "
        try {
            # the path to shutdown.exe
            $shutdownPath = Join-Path -Path $env:WINDIR -ChildPath "System32\shutdown.exe"

            # the path to shutdown.exe was not found
            if ( (Test-Path -Path $shutdownPath) -eq $false ) {
                throw "$($errMsgPrefix)The path to shutdown.exe: ($($shutdownPath)) was not found."
            }

            try {
                $shutdownArgs = @(
                    "/r"
                    "/t $($RestartInSeconds)"
                    if ($CustomMessage) { "/c `"$($CustomMessage)`"" }
                )
                $restartLocalMachineArgs = @{
                    FilePath     = $shutdownPath
                    ArgumentList = $shutdownArgs
                    NoNewWindow  = $true
                    Wait         = $true
                    ErrorAction  = "Stop"
                }
                Start-Process @restartLocalMachineArgs
            } catch {
                throw "$($errMsgPrefix)There was an error starting the restart process.`nERROR: ($($_.Exception.Message))."
            }
        } catch {
            # expected error
            if ($_.Exception.Message -match "^(\[Error\])(.*)") {
                throw $_.Exception.Message
            } else {
                throw "[Error] There was an unexpected error attempting to schedule restart for the machine.`nERROR: ($($_.Exception.Message))."
            }
        }
    }
    #endregion
}

process {
    #region System Tests
    Write-Host -Object ""
    try { $scriptIsRunningAsSystem = Test-ScriptIsRunningAsSystem } catch { Write-Host -Object $_.Exception.Message; exit 1 }
    if ($scriptIsRunningAsSystem) {
        Write-Host -Object "[Info] The script is running as the SYSTEM user."
    } else {
        Write-Host -Object "[Error] The script must be running as the SYSTEM user. Exiting..."
        exit 1
    }

    try { $isWindowsVersionSupported = Test-WindowsBuildVersionIsSupported -BuildNumber 10240 } catch { Write-Host -Object $_.Exception.Message; exit 1 }
    if ($isWindowsVersionSupported) {
        Write-Host -Object "[Info] The OS build '$([System.Environment]::OSVersion.Version.Build)' is supported."
    } else {
        Write-Host -Object "[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results."
    }
    Write-Host -Object ""
    #endregion

    #region Get Microsoft Office installation type
    try {
        <#
            - Gets the installation type of Microsoft Office, either "MSI" or "Click-To-Run" or "Microsoft Store"
            - Throws an error if unable to determine the installation type
            - Throws an error if there is more than 1 installation of Microsoft Office detected
        #>
        $OfficeInstaller = Get-O365InstallerType
    } catch {
        Write-Host -Object $_.Exception.Message
        exit 1
    }
    switch ($OfficeInstaller) {
        "Click-To-Run" {}
        "Not Installed" { Write-Host -Object "[Error] Microsoft Office is not installed on this machine."; exit 1 }
        "MSI" { Write-Host -Object "[Error] Microsoft Office is installed using unsupported MSI method."; exit 1 }
        "Microsoft Store" { Write-Host -Object "[Error] Microsoft Office is installed using unsupported Microsoft Store method."; exit 1 }
        default { Write-Host -Object "[Error] Unable to determine the installation type of Microsoft Office. Detected installer type: '$($OfficeInstaller)'."; exit 1 }
    }
    #endregion

    #region Get/Print Microsoft Office Click-To-Run installation information
    try {
        <#
            - Gets a PSCustomObject with the Microsoft Office Click-To-Run installation information
            - Throws an error if there was an issue getting the installation information
        #>
        [PSCustomObject]$msOfficeInfoObject = Get-MSOfficeC2RInstall
        $msOfficeInfo_version = $msOfficeInfoObject.Version
        $msOfficeInfo_architecture = $msOfficeInfoObject.Architecture
        $msOfficeInfo_installPath = $msOfficeInfoObject.InstallPath
        $msOfficeInfo_clientPath = $msOfficeInfoObject.ClientPath
        $msOfficeInfo_culture = $msOfficeInfoObject.Culture
    } catch {
        Write-Host -Object $_.Exception.Message
        exit 1
    }
    Write-Host -Object (Format-DynamicBanner -Title "Microsoft Office Install" -Percentage 40 -Separator "*" -TopLine)
    Write-Host -Object ("Version:".PadRight(20), $msOfficeInfo_version)
    Write-Host -Object ("Install Path:".PadRight(20), $msOfficeInfo_installPath)
    Write-Host -Object ("Client Path:".PadRight(20), $msOfficeInfo_clientPath)
    Write-Host -Object ("Architecture:".PadRight(20), $msOfficeInfo_architecture)
    Write-Host -Object ("Culture:".PadRight(20), $msOfficeInfo_culture)
    Write-Host -Object (Format-DynamicBanner -Title "Microsoft Office Install" -Percentage 40 -Separator "*" -BottomLine)
    Write-Host -Object ""
    #endregion

    #region Get/Print all of the open Microsoft Office applications
    try {
        <#
            - Gets an array of objects with the currently open Microsoft Office applications
            - Throws an error if there was an issue getting the open Microsoft Office applications
            - Can be null if there are no open Microsoft Office applications
        #>
        $msOfficeOpenedApplications = Get-MSOfficeOpenedApplications -OfficeVersion $msOfficeInfo_version -OfficeInstallPath $msOfficeInfo_installPath
    } catch {
        Write-Host -Object $_.Exception.Message
        exit 1
    }
    Write-Host -Object (Format-DynamicBanner -Title "Open Microsoft Office applications" -Percentage 40 -Separator "*" -TopLine)
    if ($msOfficeOpenedApplications) {
        $msOfficeOpenedApplications | Format-Table -AutoSize | Out-String -Stream | Where-Object { $_ -match "\s" }
    } else {
        Write-Host -Object "[Info] There are no Microsoft Office applications that are currently open."
    }
    Write-Host -Object (Format-DynamicBanner -Title "Open Microsoft Office applications" -Percentage 40 -Separator "*" -BottomLine)
    Write-Host -Object ""
    #endregion

    #region invoke the MS Office 365 repair
    # set the timeout in seconds for the respective repair type
    $repairTimeoutInSeconds = switch ($RepairMode) {
        # 15 minutes
        "Quick Repair" { 900 }
        # 1hr 45 minutes
        "Online Repair" { 6300 }

        default { Write-Host -Object "[Error] Unable to set timeout in seconds for the O365 repair, unknown repair type: '$($RepairMode)'."; exit 1 }
    }
    $repairTimeoutTimeSpan = [TimeSpan]::FromSeconds($repairTimeoutInSeconds)
    Write-Host -Object (Format-DynamicBanner -Title "Starting Office 365 Repair" -Percentage 75 -Separator "#" -TopLine)
    Write-Host -Object "  Repair Mode               >> $($RepairMode)"
    Write-Host -Object "  Reboot on success         >> $($RebootIfSuccessful)"
    Write-Host -Object "  Force Close Office Apps   >> $($ForceCloseOfficeApps)"
    Write-Host -Object "  Repair Timeout            >> $(if($repairTimeoutTimeSpan.Hours -gt 0){"$($repairTimeoutTimeSpan.Hours) hour(s) and "})$(if($repairTimeoutTimeSpan.Minutes -gt 0){"$($repairTimeoutTimeSpan.Minutes) minute(s) and "})$($repairTimeoutTimeSpan.Seconds) second(s)"
    Write-Host -Object ""

    try {
        $o365RepairArgs = @{
            OfficeClientPath   = $msOfficeInfo_clientPath
            OfficeArchitecture = $msOfficeInfo_architecture
            RepairType         = switch ($RepairMode) {
                "Quick Repair" { "QuickRepair" }
                "Online Repair" { "FullRepair" }
            }
            ForceAppShutdown   = switch ($ForceCloseOfficeApps) {
                $true { "True" }
                $false { "False" }
            }
            TimeoutSeconds     = $repairTimeoutInSeconds
            ErrorAction        = "Stop"
        }
        <#
            - Invokes the Office 365 repair process using the OfficeClickToRun.exe file.
            - This function will return an object a PSCustomObject containing the following properties:
                - ExitCode: The exit code from the repair process
                - RebootRequired: A boolean indicating if a reboot is required to complete the repair process
                - Message: A message describing the result of the repair process
            - Throws an error if repair failed or if there was any issue with the repair process
        #>
        $repairResultObject = Invoke-Office365Repair @o365RepairArgs
        Write-Host -Object "[Info] The Office 365 repair was successful and returned exit code: $($repairResultObject.ExitCode)."
    } catch {
        Write-Host -Object $_.Exception.Message
        exit 1
    }
    #endregion

    #region Reboot logic
    # user passed in -RebootIfSuccessful
    if ($RebootIfSuccessful) {
        if ($repairResultObject.RebootRequired) {
            # reboot required
            Write-Host -Object "[Info] The repair process requires a reboot to complete. Scheduling reboot..."
        } else {
            # reboot not required
            Write-Host -Object "[Info] The repair process does not require a reboot to complete, but the -RebootIfSuccessful parameter was passed. Scheduling reboot..."
        }

        # schedule the reboot
        try {
            $secondsToRestart = 90
            Restart-LocalMachine -RestartInSeconds $secondsToRestart -CustomMessage "The machine is rebooting in $($secondsToRestart) seconds to complete the Office 365 repair process."
            $rebootScheduleDateTime = (Get-Date).AddSeconds($secondsToRestart)
            Write-Host -Object "[Info] Scheduled reboot of the current machine in $($secondsToRestart) seconds.`n >>> The machine will reboot at $($rebootScheduleDateTime.ToShortDateString()) $($rebootScheduleDateTime.ToShortTimeString())."
        } catch {
            Write-Host -Object $_.Exception.Message
            exit 1
        }

    } else {
        # The repair process was successful but requires a reboot to complete, but the -RebootIfSuccessful parameter was not passed
        if ($repairResultObject.RebootRequired) {
            Write-Host -Object "[Error] The repair process requires a reboot to complete. The -RebootIfSuccessful parameter was not passed. Please reboot the machine to complete the repair process."
            exit 1
        }
    }
    #endregion

    exit 0
}

end {
    
    
    
}