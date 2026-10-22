#Requires -Version 5.1

<#
.SYNOPSIS
    Monitors the database services, free space of the drive where the databases reside, and the disk latency of a SQL server.
.DESCRIPTION
    Monitors the database services, free space of the drive where the databases reside, and the disk latency of a SQL server.

    Will not detect LocalDB uses of SQL Express

.PARAMETER -DiskSpaceThreshold 10
    Specifies the minimum percentage of free disk space allowed on the drive where the databases reside. If the free space percentage falls below this threshold, an alert will be triggered. Valid values are 1-99.
.PARAMETER -DiskLatencyThreshold 50
    Specifies the maximum latency in milliseconds allowed on the drive where the databases reside. If the disk latency increases beyond this threshold, an alert will be triggered. Valid values are integers greater than 0.
.PARAMETER -RequireAgentService
    If this is selected, the script will trigger an alert if the SQL Agent service is not running.

.EXAMPLE
    -DiskSpaceThreshold 99 -DiskLatencyThreshold 1 -RequireAgentService

    [Info] Retrieving SQL Server service information...
    [Info] Finished retrieving SQL Server service information.

    [Info] Checking database 'NEWINSTANCE'

    [Alert] [NEWINSTANCE] The Database Agent Service is not running.

    [Info] Checking Log drive G...
    [Alert] [NEWINSTANCE] Log drive G is under the free space threshold (99%) at 2%

    [Info] Retrieving disk performance counters for Log drive G...
    [Info] Finished retrieving disk performance counters for Log drive G.

    [Alert] [NEWINSTANCE] The '\\SQLSERVER\logicaldisk(g:)\disk reads/sec' counter for Log drive G: is over the disk latency threshold (1 ms) at 1.8.

    [Alert] [NEWINSTANCE] The '\\SQLSERVER\logicaldisk(g:)\disk writes/sec' counter for Log drive G: is over the disk latency threshold (1 ms) at 58.34.

    Counter                                        Drive  CookedValue
    -------                                        -----  -----------
    \\SQLSERVER\logicaldisk(g:)\disk reads/sec     G:             1.8
    \\SQLSERVER\logicaldisk(g:)\disk writes/sec    G:           58.34

    [Info] Finished checking drive G.

    [Info] Checking Database drive L...
    [Alert] [NEWINSTANCE] Database drive L is under the free space threshold (99%) at 89%

    [Info] Retrieving disk performance counters for Database drive L...
    [Info] Finished retrieving disk performance counters for Database drive L.

    [Info] Finished checking drive L.

    [Info] Checking database 'MSSQLSERVER'

    [Alert] [MSSQLSERVER] The Database Agent Service is not running.

    [Info] Checking Database drive C...
    [Alert] [MSSQLSERVER] Database drive C is under the free space threshold (99%) at 37%

    [Info] Retrieving disk performance counters for Database drive C...
    [Info] Finished retrieving disk performance counters for Database drive C.

    [Alert] [MSSQLSERVER] The '\\SQLSERVER\logicaldisk(c:)\disk reads/sec' counter for Database drive C: is over the disk latency threshold (1 ms) at 4.8.

    [Alert] [MSSQLSERVER] The '\\SQLSERVER\logicaldisk(c:)\disk writes/sec' counter for Database drive C: is over the disk latency threshold (1 ms) at 2.2.

    Counter                                        Drive  CookedValue
    -------                                        -----  -----------
    \\SQLSERVER\logicaldisk(c:)\disk reads/sec     C:             4.8
    \\SQLSERVER\logicaldisk(c:)\disk writes/sec    C:             2.2

    [Info] Finished checking drive C.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 2.0
    Release Notes: Script now uses [Alert] instead of exit code 1 as an alert mechanism. Added support for logs stored on separate drives than their databases. Updated to support all languages.
#>

[CmdletBinding()]
param (
    [Parameter()]
    $DiskSpaceThreshold = 10,
    [Parameter()]
    $DiskLatencyThreshold = 50,
    [switch]$RequireAgentService = [System.Convert]::ToBoolean($env:requireAgentService)
)

begin {
    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Import script variables
    if ($env:diskFreeSpaceThreshold) { $DiskSpaceThreshold = $env:diskFreeSpaceThreshold }
    if ($env:diskLatencyThreshold) { $diskLatencyThreshold = $env:diskLatencyThreshold }

    # Verify that the disk space and disk latency thresholds are valid integers
    try {
        $DiskSpaceThreshold = [int]$DiskSpaceThreshold
    }
    catch {
        Write-Host -Object "[Error] The disk free space threshold must be a valid integer value. '$DiskSpaceThreshold' is not a valid integer."
        exit 1
    }

    try {
        $DiskLatencyThreshold = [int]$DiskLatencyThreshold
    }
    catch {
        Write-Host -Object "[Error] The disk latency threshold must be a valid integer value. '$DiskLatencyThreshold' is not a valid integer."
        exit 1
    }

    # Validate the disk space threshold
    if ($DiskSpaceThreshold -lt 1 -or $DiskSpaceThreshold -gt 99) {
        Write-Host -Object "[Error] The disk free space threshold must be a value that is greater than 0 and less than 100. '$DiskSpaceThreshold' is not a valid percentage."
        exit 1
    }

    # Validate the disk latency threshold
    if ($DiskLatencyThreshold -lt 1) {
        Write-Host -Object "[Error] The disk latency threshold must be a positive integer greater than 0. '$DiskLatencyThreshold' is not a valid value."
        exit 1
    }

    # Function to retrieve the default database and log locations for a SQL Server instance
    function Get-DefaultDBLocation {
        [CmdletBinding()]
        param (
            [Parameter()]
            [string]$InstanceName
        )

        # Validate the instance name
        if ([string]::IsNullOrWhiteSpace($InstanceName)) {
            throw [System.ArgumentException]::New("The instance name cannot be null or empty.")
        }

        # Get the SQL Server instance ID from the registry based on the instance name
        try {
            $InstanceID = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL" -Name $InstanceName -ErrorAction Stop).$InstanceName
        }
        catch {
            throw $_
        }

        # Create the registry path for the SQL Server instance
        $InstanceRegistryPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$InstanceID\MSSQLServer"

        # Get the database and log paths from the instance registry path if they exist
        $DatabasePath = (Get-ItemProperty -Path "$InstanceRegistryPath" -ErrorAction SilentlyContinue).DefaultData
        $DatabaseLogPath = (Get-ItemProperty -Path "$InstanceRegistryPath" -ErrorAction SilentlyContinue).DefaultLog

        # If the data or log paths are not found, try to retrieve them from the Setup registry path instead
        if ([string]::IsNullOrWhiteSpace($DatabasePath)) {
            $InstanceRegistryPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\" + $InstanceID + "\Setup"
            $DatabasePath = (Get-ItemProperty -Path "$InstanceRegistryPath" -Name SQLDataRoot -ErrorAction SilentlyContinue).SQLDataRoot + "\Data\"
        }

        if ([string]::IsNullOrWhiteSpace($DatabaseLogPath)) {
            $InstanceRegistryPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\" + $InstanceID + "\Setup"
            $DatabaseLogPath = (Get-ItemProperty -Path "$InstanceRegistryPath" -Name SQLDataRoot -ErrorAction SilentlyContinue).SQLDataRoot + "\Data\"
        }

        # If the paths are still not found, throw an error
        if ([string]::IsNullOrWhiteSpace($DatabasePath) -or [string]::IsNullOrWhiteSpace($DatabaseLogPath)) {
            throw [System.Data.ObjectNotFoundException]::New("The database or log path for the SQL Server instance '$InstanceName' could not be found.")
        }

        [PSCustomObject]@{
            Data = $DatabasePath
            Log  = $DatabaseLogPath
        }
    }

    # Function to retrieve the localized names of performance counters
    function Get-PerformanceCounterLocalizedName {
        [CmdletBinding()]
        param (
            [Parameter()]
            [string]$CounterID
        )

        # Validate counter ID
        if ([string]::IsNullOrWhiteSpace($CounterID)) {
            throw [System.ArgumentException]::New("The counter ID cannot be null or empty.")
        }

        # Define the registry path for the performance counters in the current language
        $regPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Perflib\CurrentLanguage"

        # Check if the registry path exists
        if (-not (Test-Path $regPath)) {
            throw [System.Management.Automation.ItemNotFoundException]::New("The registry path '$regPath' does not exist. This may indicate that the system is not configured for performance counters.")
        }

        # Retrieve the list of counters from the registry. This returns a list of counter IDs and their corresponding names
        try {
            $Counters = (Get-ItemProperty $regPath -Name Counter -ErrorAction Stop).Counter
        }
        catch {
            throw $_
        }

        # Get the index of the specified counter ID from the list of counters
        try {
            $IndexOfCounterID = $Counters.IndexOf($CounterID)
        }
        catch {
            throw $_
        }

        # If -1 is returned for the index, the counter ID could not be found
        if ($IndexOfCounterID -eq -1) {
            throw [System.Management.Automation.ItemNotFoundException]::New("The counter ID '$CounterID' could not be found.")
        }

        # The localized counter name is one index after the counter ID's index
        $CounterName = $Counters[$IndexOfCounterID + 1]

        return $CounterName
    }

    # Function to get the free space percentage of a specific drive
    function Get-DiskFreeSpacePercentage {
        [CmdletBinding()]
        param (
            [Parameter()]
            [string]$Drive
        )

        # Remove the colon from the drive letter if it exists
        $Drive = $Drive -replace ":"

        # Validate the drive letter
        if ($Drive.Length -ne 1 -or $Drive -notmatch '^[A-Z]$') {
            throw [System.ArgumentException]::New("The drive letter '$Drive' is not valid. It must be a single uppercase letter (A-Z).")
        }

        # Get the total size of the drive
        try {
            $TotalSize = Get-Partition -DriveLetter $Drive -ErrorAction Stop | Select-Object -ExpandProperty Size
        }
        catch {
            throw $_
        }

        # Get the free space of the drive
        try {
            $FreeSpace = Get-PSDrive -Name $Drive -ErrorAction Stop | Select-Object -ExpandProperty Free
        }
        catch {
            throw $_
        }

        # Return the free space as a percentage
        return $FreeSpace / $TotalSize * 100
    }

    # Function to check if the current session is running with elevated permissions (Administrator privileges)
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
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running with Administrator privileges."
        exit 1
    }

    if (!$IsElevated) {
        Write-Host -Object "[Error] Access Denied: The user '$env:Username' does not have administrator privileges, or the script is not running with elevated permissions."
        exit 1
    }

    # Retrieve SQL Server service information
    try {
        Write-Host "[Info] Retrieving SQL Server service information..."
        $AllSQLServices = Get-Service -DisplayName "*SQL Server*" -ErrorAction Stop
        Write-Host "[Info] Finished retrieving SQL Server service information.`n"
    }
    catch {
        Write-Host "[Error] Error retrieving SQL Server service information. Ensure that the SQL Server services are installed and running."
        Write-Host "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Error if there are no SQL services
    if ($null -eq $AllSQLServices) {
        Write-Host "[Error] No SQL Server services found. Ensure that SQL Server is installed and running."
        exit 1
    }

    $SqlDbServices = $AllSQLServices | Where-Object { $_.DisplayName -like "SQL Server (*" } | Select-Object -ExpandProperty DisplayName
    $SqlDbNames = $SqlDbServices | ForEach-Object {
        "$_" -split '\(' -replace '\)' | Select-Object -Last 1
    }

    # Get all MS SQL database instances
    $Databases = $SqlDbNames | ForEach-Object {
        $DbName = $_

        # Retrieve the database locations for the current database instance
        try {
            $DbLocations = Get-DefaultDBLocation -InstanceName $DbName -ErrorAction Stop
        }
        catch {
            Write-Host "[Error] Error retrieving default database locations for '$DbName'."
            Write-Host "[Error] $($_.Exception.Message)"
            $ExitCode = 1
            return
        }

        [PSCustomObject]@{
            Name            = $DbName
            DatabaseService = $AllSQLServices | Where-Object { $_.DisplayName -like "SQL Server ($DbName)" }
            AgentService    = $AllSQLServices | Where-Object { $_.DisplayName -like "*Agent *$DbName*" }
            DataPath        = $DbLocations.Data
            LogPath         = $DbLocations.Log
        }
    }

    # Initialize values
    $RequiredServicesRunning = $True
    $DiskLatencyBelowThreshold = $True
    $DiskFreeSpaceAboveThreshold = $True

    # Retrieve the disk performance counter localized names before looping through the databases
    # These IDs and names will not change based on the DB so they can be retrieved before the loop

    $LogicalDiskCounterIDs = @(
        208 # Avg. Disk sec/Read
        210 # Avg. Disk sec/Write
        214 # Disk Reads/sec
        216 # Disk Writes/sec
    )

    # LogicalDisk performance category ID
    $LogicalDiskID = 236

    # Get the localized counter names using the counter IDs defined above
    $LogicalDiskCounterLocalizedNames = $LogicalDiskCounterIDs | ForEach-Object {
        try {
            $CounterID = $_
            Get-PerformanceCounterLocalizedName -CounterID $CounterID -ErrorAction Stop
        }
        catch {
            Write-Host "[Error] Error retrieving the localized counter name for '$CounterID'."
            Write-Host "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    # Loop through each database to check services, disk free space, and disk latency
    $Databases | ForEach-Object {
        $Database = $_
        $DatabaseService = $Database.DatabaseService
        $AgentService = $Database.AgentService
        $DatabaseName = $Database.Name

        # Initialize a list for the drive letters
        $DriveList = [System.Collections.Generic.List[object]]::new()

        # Split the database and log paths to get the drive letters
        $DatabaseDrive = $Database.DataPath -split ':\\' | Select-Object -First 1
        $LogDrive = $Database.LogPath -split ':\\' | Select-Object -First 1

        # If the drives are the same, add the database drive only once
        # Otherwise, add both
        if ($DatabaseDrive -eq $LogDrive) {
            $DriveList.Add([PSCustomObject]@{
                    DriveLetter = $DatabaseDrive
                    Type        = "Database and Log"
                })
        }
        else {
            $DriveList.Add([PSCustomObject]@{
                    DriveLetter = $DatabaseDrive
                    Type        = "Database"
                })
            $DriveList.Add([PSCustomObject]@{
                    DriveLetter = $LogDrive
                    Type        = "Log"
                })
        }

        # Sort the DriveList alphabetically by drive letter
        $DriveList = $DriveList | Sort-Object -Property DriveLetter

        Write-Host "[Info] Checking database '$DatabaseName'`n"

        # Check service status
        if ($DatabaseService.Status -notlike "Running") {
            Write-Host "[Alert] [$DatabaseName] The Database Service is not running.`n"
            $RequiredServicesRunning = $false
        }

        if ($AgentService.Status -notlike "Running" -and $RequireAgentService) {
            Write-Host -Object "[Alert] [$DatabaseName] The Database Agent Service is not running.`n"
            $RequiredServicesRunning = $false
        }

        # Get the localized name of the Logical Disk performance category from the counter ID
        # This is used later to construct the full names of the disk performance counters
        try {
            $LogicalDiskCategoryLocalizedName = Get-PerformanceCounterLocalizedName -CounterID $LogicalDiskID
        }
        catch {
            Write-Host "[Error] Error retrieving the localized name for the Logical Disk performance category."
            Write-Host "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }

        # Check the free space and disk latency of each disk
        $DriveList | ForEach-Object {
            $Drive = $_.DriveLetter
            $DriveWithColon = $_.DriveLetter + ":"
            $Type = $_.Type

            Write-Host "[Info] Checking $Type drive $DriveWithColon...`n"
            try {
                $FreeSpace = Get-DiskFreeSpacePercentage -Drive $Drive -ErrorAction Stop
            }
            catch {
                Write-Host "[Error] Error while calculating the free disk space for '$DatabaseName' on drive $DriveWithColon."
                Write-Host "[Error] $($_.Exception.Message)"
                $ExitCode = 1
            }

            if ($FreeSpace -lt $DiskSpaceThreshold) {
                Write-Host "[Alert] [$DatabaseName] $Type drive $DriveWithColon is under the free space threshold ($DiskSpaceThreshold%) at $([System.Math]::Round($FreeSpace, 0))%`n"
                $DiskFreeSpaceAboveThreshold = $False
            }

            # Add the current drive to the Logical Disk category localized name
            $LogicalDiskCategoryLocalizedNameWithDrive = $LogicalDiskCategoryLocalizedName + "($Drive*)"

            # Construct the full names of each counter using the Logical Disk category localized name and the counter localized name
            $DiskCountersToRetrieve = $LogicalDiskCounterLocalizedNames | ForEach-Object {
                "\$LogicalDiskCategoryLocalizedNameWithDrive\$_"
            }

            # Get the current drive's counter data
            try {
                Write-Host "[Info] Retrieving disk performance counters for $Type drive $DriveWithColon..."
                $CounterData = Get-Counter -Counter $DiskCountersToRetrieve -MaxSamples 1 -SampleInterval 10 -ErrorAction Stop | Select-Object -ExpandProperty CounterSamples
                Write-Host "[Info] Finished retrieving disk performance counters for $Type drive $DriveWithColon.`n"
            }
            catch {
                Write-Host "[Error] Failed to retrieve disk performance counters for $Type drive $DriveWithColon."
                Write-Host "[Error] $($_.Exception.Message)`n"
                $ExitCode = 1
                return
            }

            # Continue to the next drive if no counter data is available
            if ($null -eq $CounterData) {
                Write-Host "[Error] No counter data is available for '$DatabaseName' on $Type drive $DriveWithColon.`n"
                $ExitCode = 1
                return
            }

            # Check if any of the disk latency counters exceed the threshold and alert
            $HighCounters = $CounterData | Where-Object { $_.CookedValue -gt $diskLatencyThreshold } | Select-Object -Property @{n="Counter";e={$_.Path}}, @{n="Drive";e={$_.InstanceName.ToUpper()}}, @{n="CookedValue";e={[System.Math]::Round($_.CookedValue, 2)}}
            if ($HighCounters) {
                $HighCounters | ForEach-Object {
                    Write-Host "[Alert] [$DatabaseName] The '$($_.Counter)' counter for $Type drive $($_.Drive) is over the disk latency threshold ($diskLatencyThreshold ms) at $($_.CookedValue).`n"
                }
                Write-Host "$(($HighCounters | Out-String).Trim())`n"
                $DiskLatencyBelowThreshold = $False
            }
            Write-Host "[Info] Finished checking drive $DriveWithColon.`n"
        }
    }

    if ($RequiredServicesRunning) {
        Write-Host "[Info] All required SQL Server services are running."
    }

    if ($DiskLatencyBelowThreshold) {
        Write-Host "[Info] All SQL Server disk latencies are below the threshold of $diskLatencyThreshold ms."
    }

    if ($DiskFreeSpaceAboveThreshold) {
        Write-Host "[Info] All SQL Server disks are above the their free space thresholds of $diskSpaceThreshold%."
    }

    exit $ExitCode
}
end {
    
    
    
}
