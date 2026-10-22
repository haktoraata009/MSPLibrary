#Requires -Version 5.1

<#
.SYNOPSIS
    Analyzes or optimizes volumes (HDDs, SSDs, and mount points) using the appropriate method per drive type. Targets specific drive letters or all fixed local volumes. When analyzing, an [Alert] will be produced if optimization is recommended. Optionally saves results to custom fields.
.DESCRIPTION
    Analyzes or optimizes volumes (HDDs, SSDs, and mount points) using the appropriate method per drive type. Targets specific drive letters or all fixed local volumes. When analyzing, an [Alert] will be produced if optimization is recommended. Optionally saves results to custom fields.

.EXAMPLE
    -Action "Analyze" -PerformActionOnAllVolumes

    [Alert] Optimization is recommended for one or more drives.

    ### Drive C | Type: SSD | Analysis ###

    Optimization Recommended       : True
    Volume Size                    : 931.51 GB
    Free Space                     : 122.38 GB (13%)
    Fragmented Folders             : 47
    Fragmented Files               : 1842
    Average Fragments Per File     : 1.17
    Percentage of Files Fragmented : 9%
    Largest Free Extent            : 42.23 GB
    MFT Percent In Use             : 61%
    MFT Record Count               : 214673
    Total MFT Fragments            : 1

    ### Mount Point D:\MountPoint\ | Type: SSD | Analysis ###

    Optimization Recommended       : False
    Volume Size                    : 465.76 GB
    Free Space                     : 230.12 GB (49%)
    Fragmented Folders             : 6
    Fragmented Files               : 198
    Average Fragments Per File     : 1.02
    Percentage of Files Fragmented : 1%
    Largest Free Extent            : 201.45 GB
    MFT Percent In Use             : 27%
    MFT Record Count               : 86231
    Total MFT Fragments            : 1

.EXAMPLE
    -Action "Optimize" -DriveLettersOrMountPoints "C:,D:\MountPoint\"

    ### Drive C | Type: SSD | Optimization ###

    Optimizing 'C'...
    Optimization of drive 'C' completed successfully.

                                     Before -> After
    Optimization Recommended       : True -> False
    Volume Size                    : 931.51 GB -> 931.51 GB
    Free Space                     : 122.38 GB (13%) -> 122.49 GB (13%)
    Fragmented Folders             : 47 -> 0
    Fragmented Files               : 1842 -> 0
    Average Fragments Per File     : 1.17 -> 1.00
    Percentage of Files Fragmented : 9% -> 0%
    Largest Free Extent            : 42.23 GB -> 120.15 GB
    MFT Percent In Use             : 61% -> 61%
    MFT Record Count               : 214673 -> 214673
    Total MFT Fragments            : 1 -> 1

    ### Mount Point D:\MountPoint\ | Type: SSD | Optimization ###

    Optimizing 'D:\MountPoint\'...
    Optimization of mount point 'D:\MountPoint\' completed successfully.

                                     Before -> After
    Optimization Recommended       : False -> False
    Volume Size                    : 465.76 GB -> 465.76 GB
    Free Space                     : 230.12 GB (49%) -> 230.12 GB (49%)
    Fragmented Folders             : 6 -> 0
    Fragmented Files               : 198 -> 0
    Average Fragments Per File     : 1.02 -> 1.00
    Percentage of Files Fragmented : 1% -> 0%
    Largest Free Extent            : 201.45 GB -> 228.91 GB
    MFT Percent In Use             : 27% -> 27%
    MFT Record Count               : 86231 -> 86231
    Total MFT Fragments            : 1 -> 1

.PARAMETER Action
    The action to perform on the target volumes. Accepted values are 'Analyze' and 'Optimize'.
.PARAMETER PerformActionOnAllVolumes
    If selected, perform the chosen action on all fixed local volumes, including both drive-letter
    volumes and mount points. Cannot be combined with 'Drive Letters or Mount Points'.
.PARAMETER DriveLettersOrMountPoints
    A comma-separated list of drive letters or mount point paths to target (e.g., 'C:, D:\MountPoint\').
    Cannot be combined with 'Perform Action On All Volumes'.
.PARAMETER MultilineCustomFieldName
    The name of a multiline custom field to save the plain-text report to.
.PARAMETER WysiwygCustomFieldName
    The name of a WYSIWYG custom field to save a fragmentation bar chart to.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [switch]$PerformActionOnAllVolumes = [System.Convert]::ToBoolean($env:performActionOnAllVolumes),
    [Parameter()]
    [string]$DriveLettersOrMountPoints,
    [Parameter()]
    [string]$MultilineCustomFieldName,
    [Parameter()]
    [string]$WysiwygCustomFieldName
)
begin {
    Write-Host -Object ""

    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    if ($env:action) {$Action = $env:action}
    if ($env:driveLettersOrMountPoints) {$DriveLettersOrMountPoints = $env:driveLettersOrMountPoints}
    if ($env:multilineCustomFieldName) {$MultilineCustomFieldName = $env:multilineCustomFieldName}
    if ($env:wysiwygCustomFieldName) {$WysiwygCustomFieldName = $env:wysiwygCustomFieldName}

    #region Input validation
    # If no action was provided, error out
    if (-not $Action) {
        Write-Host -Object "[Error] No action specified. Please provide an action of 'Analyze' or 'Optimize'."
        exit 1
    }

    # Validate the Action parameter
    # Error if the Action parameter contains only whitespace characters
    if ([string]::IsNullOrWhiteSpace($Action)) {
        Write-Host -Object "[Error] The 'Action' parameter contains only spaces. Please provide 'Analyze' or 'Optimize'."
        exit 1
    }

    # Trim whitespace from the action
    $Action = $Action.Trim()

    # Error if the Action value is not one of the accepted options
    if ($Action -notin @("Analyze", "Optimize")) {
        Write-Host -Object "[Error] The 'Action' value '$Action' is invalid. Please provide 'Analyze' or 'Optimize'."
        exit 1
    }

    # Error if 'Perform Action On All Volumes' and 'Drive Letters or Mount Points' are both specified
    if ($PerformActionOnAllVolumes -and $DriveLettersOrMountPoints) {
        Write-Host -Object "[Error] 'Perform Action On All Volumes' and 'Drive Letters or Mount Points' cannot be used together. Please select one or the other."
        exit 1
    }

    # If neither 'Perform Action On All Volumes' nor 'Drive Letters or Mount Points' were specified, default to analyzing the system drive
    if (-not $PerformActionOnAllVolumes -and -not $DriveLettersOrMountPoints) {
        Write-Host -Object "[Warning] No target volumes specified. Defaulting to analyzing the system drive '$env:SystemDrive'.`n"
        $DriveLettersOrMountPoints = $env:SystemDrive
    }

    # Validate the 'Drive Letters or Mount Points' parameter if provided
    if ($DriveLettersOrMountPoints) {
        # Initialize a list to store normalized drive letters and mount point paths
        $NormalizedPaths = New-Object System.Collections.Generic.List[string]

        # Error if the parameter contains only whitespace characters
        if ([string]::IsNullOrWhiteSpace($DriveLettersOrMountPoints)) {
            Write-Host -Object "[Error] The 'Drive Letters or Mount Points' parameter contains only spaces. Please provide valid drive letters or mount points."
            exit 1
        }

        # Trim the whitespace around the entire string
        $DriveLettersOrMountPoints = $DriveLettersOrMountPoints.Trim()

        # Split on commas and remove empty entries
        $DriveEntries = $DriveLettersOrMountPoints -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }

        # Error if no valid entries are found after parsing
        if (($DriveEntries | Measure-Object).Count -eq 0) {
            Write-Host -Object "[Error] The 'Drive Letters or Mount Points' parameter is empty after parsing. Please provide at least one drive letter or mount point."
            exit 1
        }

        # Verify each path exists before normalizing and adding it to the list
        foreach ($Entry in $DriveEntries) {
            # Check if the entry matches a drive letter format (will match "C", "C:", or "C:\")
            if ($Entry -match "^[A-Za-z]:?\\?$") {
                # Normalize to "X:\" format
                $NormalizedPath = "$([char]::ToUpper($Entry[0])):\"

                # Verify the drive exists on this system
                if (-not (Test-Path -Path $NormalizedPath -PathType Container -ErrorAction SilentlyContinue)) {
                    Write-Host -Object "[Warning] The drive '$NormalizedPath' was not found on this system."
                    $AddNewLine = $True
                    continue
                }

                # Skip duplicates and warn the user
                if ($NormalizedPaths.Contains($NormalizedPath)) {
                    Write-Host -Object "[Warning] The drive '$NormalizedPath' was specified more than once and will only be processed once."
                    $AddNewLine = $True
                }
                else {
                    $NormalizedPaths.Add($NormalizedPath)
                }
            }
            elseif (Test-Path -Path $Entry -PathType Container -ErrorAction SilentlyContinue) {
                # Remove any extra backslashes and ensure it ends with a single backslash
                $NormalizedPath = $Entry.TrimEnd('\') + '\'

                # Skip duplicates and warn the user
                if ($NormalizedPaths.Contains($NormalizedPath)) {
                    Write-Host -Object "[Warning] The mount point '$NormalizedPath' was specified more than once and will only be processed once."
                    $AddNewLine = $True
                }
                else {
                    $NormalizedPaths.Add($NormalizedPath)
                }
            }
            else {
                Write-Host -Object "[Warning] '$Entry' is not a valid drive letter or existing mount point path."
                $AddNewLine = $True
            }
        }

        if ($AddNewLine) {
            Write-Host -Object ""
            $AddNewLine = $False
        }

        # Error if no valid paths were found after parsing and validation
        if ($NormalizedPaths.Count -eq 0) {
            Write-Host -Object "[Error] No valid drive letters or mount points were found to process. Please provide at least one valid path."
            exit 1
        }
    }

    # Validate the multiline custom field name if provided
    if ($MultilineCustomFieldName) {
        # Error if the parameter contains only whitespace characters
        if ([string]::IsNullOrWhiteSpace($MultilineCustomFieldName)) {
            Write-Host -Object "[Error] The 'Multiline Custom Field Name' parameter contains only spaces. Please provide a valid field name or leave it blank."
            exit 1
        }

        # Trim whitespace from the custom field name
        $MultilineCustomFieldName = $MultilineCustomFieldName.Trim()

        # Validate that the field name contains only alphanumeric characters
        if ($MultilineCustomFieldName -match "[^0-9A-Za-z]") {
            Write-Host -Object "[Error] The 'Multiline Custom Field Name' of '$MultilineCustomFieldName' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid custom field name containing only letters and numbers, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Validate the WYSIWYG custom field name if provided
    if ($WysiwygCustomFieldName) {
        # Error if the parameter contains only whitespace characters
        if ([string]::IsNullOrWhiteSpace($WysiwygCustomFieldName)) {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' parameter contains only spaces. Please provide a valid field name or leave it blank."
            exit 1
        }

        # Trim whitespace from the custom field name
        $WysiwygCustomFieldName = $WysiwygCustomFieldName.Trim()

        # Validate that the field name contains only alphanumeric characters
        if ($WysiwygCustomFieldName -match "[^0-9A-Za-z]") {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' of '$WysiwygCustomFieldName' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid custom field name containing only letters and numbers, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }
    #endregion

    #region Helper functions
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
        # Reference: https://learn.microsoft.com/dotnet/api/system.security.principal.windowsbuiltinrole
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]'544')
    }

    # Function for converting CIM defrag analysis results into a user-friendly object
    function ConvertTo-AnalysisReport {
        [CmdletBinding()]
        param (
            [Parameter()]
            [PSObject]$CimResult
        )

        # The CIM result contains a DefragAnalysis property with detailed fragmentation data
        $Analysis = $CimResult.DefragAnalysis

        # If there is no defrag analysis data, return $null
        if (-not $Analysis) { return $null }

        # Return a custom object with formatted properties
        [PSCustomObject]@{
            "Optimization Recommended"       = $CimResult.DefragRecommended
            "Volume Size"                    = "$([math]::Round($Analysis.VolumeSize / 1GB, 2)) GB"
            "Free Space"                     = "$([math]::Round($Analysis.FreeSpace / 1GB, 2)) GB ($($Analysis.FreeSpacePercent)%)"
            "Fragmented Folders"             = $Analysis.FragmentedFolders
            "Fragmented Files"               = $Analysis.TotalFragmentedFiles
            "Average Fragments Per File"     = $Analysis.AverageFragmentsPerFile
            "Percentage of Files Fragmented" = "$($Analysis.FilePercentFragmentation)%"
            "Largest Free Extent"            = "$([math]::Round($Analysis.LargestFreeSpaceExtent / 1GB, 2)) GB"
            "MFT Percent In Use"             = "$($Analysis.MFTPercentInUse)%"
            "MFT Record Count"               = $Analysis.MFTRecordCount
            "Total MFT Fragments"            = $Analysis.TotalMFTFragments
        }
    }

    # Function to retrieve the Win32_Volume corresponding to a given drive letter or mount point path
    function Get-VolumeByPath {
        [CmdletBinding()]
        param (
            [Parameter()]
            [String]$TargetPath
        )

        # If the target path is a drive letter, query Win32_Volume by DriveLetter for efficiency
        # Otherwise, query all volumes and filter by Name
        if ($TargetPath -match "^[A-Za-z]:\\$") {
            $Volume = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = '$([char]::ToUpper($TargetPath[0])):'" -ErrorAction Stop
        }
        else {
            $Volume = Get-CimInstance -ClassName Win32_Volume -ErrorAction Stop | Where-Object { $_.Name -eq $TargetPath }
        }

        if (-not $Volume) {
            throw "No Win32_Volume found for path '$TargetPath'."
        }

        $Volume
    }

    # Function to retrieve the physical media type (HDD, SSD, etc.) for a given drive letter or mount point path
    function Get-VolumeMediaType {
        [CmdletBinding()]
        param (
            [Parameter()]
            [String]$TargetPath
        )

        try {
            # Find the partition that has an AccessPath matching the target path (drive letter or mount point)
            $Partition = Get-Partition -ErrorAction Stop | Where-Object { $_.AccessPaths -contains $TargetPath } | Select-Object -First 1
            if (-not $Partition) { return "Unknown" }

            # Find the disk associated with this partition
            $Disk = $Partition | Get-Disk -ErrorAction Stop
            if (-not $Disk) { return "Unknown" }

            # Find the physical disk associated with this disk
            $PhysicalDisk = $Disk | Get-PhysicalDisk -ErrorAction Stop | Select-Object -First 1

            # If no physical disk is found, assume this is a virtual disk
            if (-not $PhysicalDisk) { return "Virtual Disk" }

            # Return the physical disk's media type (HDD, SSD, etc.)
            return $PhysicalDisk.MediaType
        }
        catch {
            return "Unknown"
        }
    }
    #endregion

    if (-not $ExitCode) {
        $ExitCode = 0
    }
}
process {
    # Attempt to determine if the current session is running with Administrator privileges
    try {
        $IsElevated = Test-IsElevated -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running this script in an elevated session."
        exit 1
    }

    if (-not $IsElevated) {
        Write-Host -Object "[Error] The user '$env:USERNAME' is not running this script in an elevated session. Please run this script as System or in an elevated session."
        exit 1
    }

    #region Drive discovery
    # Initialize a list of target path strings to process
    $TargetPaths = New-Object System.Collections.Generic.List[string]

    # If paths were normalized from the 'Drive Letters or Mount Points' parameter, add those to the target paths list
    # Otherwise, 'Perform Action On All Volumes' was specified, so retrieve all local fixed volumes and add those
    if ($NormalizedPaths.Count -gt 0) {
        # Copy the validated paths provided by the user into the target paths list
        $TargetPaths.AddRange($NormalizedPaths)
    }
    else {
        # Retrieve all fixed local volumes, both drive-letter volumes and mount points
        try {
            $Volumes = Get-CimInstance -ClassName Win32_Volume -ErrorAction Stop |
                Where-Object { $_.DriveType -eq 3 -and $_.Name -match '^[A-Za-z]:\\' } |
                Sort-Object -Property Name |
                Select-Object -ExpandProperty Name
        }
        catch {
            Write-Host -Object "[Error] Failed to retrieve the list of volumes on this system."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        # Add each retrieved volume path to the target paths list
        # These will be in the format "C:\" for drive-letter volumes and "D:\MountPoint\" for mount points
        foreach ($Volume in $Volumes) {
            $TargetPaths.Add($Volume)
        }
    }

    # Error if no target paths were found to process
    if ($TargetPaths.Count -eq 0) {
        Write-Host -Object "[Error] No fixed local volumes were found to process."
        exit 1
    }
    #endregion

    # Determine whether to analyze or optimize based on the Action parameter
    $AnalyzeOnly = $Action -ne "Optimize"

    #region Generate report objects for each drive
    # Initialize a new list to hold analysis reports for each drive
    $DriveAnalysisResults = New-Object System.Collections.Generic.List[PSObject]

    # Flag that will be set to $true if any analyzed drive needs optimization
    $AnyOptimizationRecommended = $false

    # Loop through each target path and collect analysis data for it
    foreach ($TargetPath in $TargetPaths) {
        try {
            # Retrieve the media type for this drive to include in the report
            $MediaType = Get-VolumeMediaType -TargetPath $TargetPath -ErrorAction Stop

            # Resolve the target path to its Win32_Volume for defrag analysis
            $CimVolume = Get-VolumeByPath -TargetPath $TargetPath -ErrorAction Stop

            # Retrieve a defrag analysis report for this volume
            $CimResult = Invoke-CimMethod -InputObject $CimVolume -MethodName "DefragAnalysis" -ErrorAction Stop

            # Convert the raw CIM result into a more user-friendly report object
            $FormattedReport = ConvertTo-AnalysisReport -CimResult $CimResult -ErrorAction Stop

            # Add the analysis results object for this drive to the collection
            $DriveAnalysisResults.Add(
                [PSCustomObject]@{
                    TargetPath              = $TargetPath
                    Report                  = $FormattedReport
                    OptimizationRecommended = $CimResult.DefragRecommended
                    MediaType               = $MediaType
                    Error                   = $null
                    AfterReport             = $null
                    OptimizationResult      = $null
                    OptimizationError       = $null
                    PostAnalysisError       = $null
                }
            )
        }
        catch {
            # Add an object with error information for this drive to the collection
            $DriveAnalysisResults.Add(
                [PSCustomObject]@{
                    TargetPath              = $TargetPath
                    Report                  = $null
                    OptimizationRecommended = $false
                    MediaType               = $MediaType
                    Error                   = $_.Exception.Message
                    AfterReport             = $null
                    OptimizationResult      = $null
                    OptimizationError       = $null
                    PostAnalysisError       = $null
                }
            )
        }
    }

    # If any drive's analysis report indicates that optimization is recommended, set the flag to alert the user
    if ($DriveAnalysisResults.OptimizationRecommended -contains $true) {
        $AnyOptimizationRecommended = $true
    }
    #endregion

    #region Activity log output
    # Alert if optimization is recommended on any drive during analysis mode
    if ($AnalyzeOnly -and $AnyOptimizationRecommended) {
        Write-Host -Object "[Alert] Optimization is recommended for one or more drives."
        Write-Host -Object ""
    }

    # Loop through each drive's analysis results to perform the requested action and display results
    foreach ($DriveResult in $DriveAnalysisResults) {
        $TargetPath = $DriveResult.TargetPath

        # Determine the volume type label
        $VolumeTypeLabel = if ($TargetPath -match "^[A-Za-z]:\\$") { "Drive" } else { "Mount Point" }

        # For display, drop the trailing backslash and colon from a drive
        $DisplayPath = if ($TargetPath -match "^[A-Za-z]:\\$") { $TargetPath.TrimEnd(':\') } else { $TargetPath }

        # Determine the operation label based on the action being performed
        $DriveOperationLabel = if ($AnalyzeOnly) { "Analysis" } else { "Optimization" }

        Write-Host -Object "### $VolumeTypeLabel $DisplayPath | Type: $($DriveResult.MediaType) | $DriveOperationLabel ###"
        Write-Host -Object ""

        #region Analyze only output
        # If 'Analyze' is the action, display the analysis report for this drive or any errors that occurred during analysis
        if ($AnalyzeOnly) {
            # If the pre-run analysis failed for this drive, report the error
            if ($DriveResult.Error) {
                Write-Host -Object "[Error] Failed to run $($DriveOperationLabel.ToLower()) on $($VolumeTypeLabel.ToLower()) '$DisplayPath'."
                Write-Host -Object "[Error] $($DriveResult.Error)"
                $ExitCode = 1
            }
            # If there is a report object for this drive, display it
            elseif ($DriveResult.Report) {
                $FormattedAnalysis = ($DriveResult.Report | Format-List | Out-String).Trim()
                Write-Host -Object $FormattedAnalysis
            }
            # If no analysis data was returned, warn the user
            else {
                Write-Host -Object "[Warning] No analysis data was returned for $($VolumeTypeLabel.ToLower()) '$DisplayPath'."
                Write-Host -Object "[Warning] This $($VolumeTypeLabel.ToLower()) may not support fragmentation analysis."
            }
        }
        #endregion

        #region Optimize drives
        if (-not $AnalyzeOnly) {
            # Use the pre-optimization analysis report as the "before" snapshot for comparison
            $BeforeReport = $DriveResult.Report

            # If the pre-optimization analysis failed, warn the user but continue with the operation
            if ($DriveResult.Error) {
                Write-Host -Object "[Warning] Could not retrieve pre-optimization analysis for $($VolumeTypeLabel.ToLower()) '$DisplayPath'."
                Write-Host -Object "[Warning] $($DriveResult.Error)"
            }
            # If no pre-optimization report was returned, note it before proceeding
            elseif (-not $BeforeReport) {
                Write-Host -Object "[Warning] No analysis data was returned for $($VolumeTypeLabel.ToLower()) '$DisplayPath' before optimization."
            }

            # Run the appropriate optimization operation on this volume
            try {
                Write-Host -Object "Optimizing '$DisplayPath'..."

                # If the target path is a drive letter, we can optimize by drive letter
                # Otherwise, we need to retrieve the associated Win32_Volume to get the device ID
                if ($TargetPath -match "^[A-Za-z]:\\$") {
                    Optimize-Volume -DriveLetter $TargetPath[0] -ErrorAction Stop
                }
                else {
                    # Retrieve the Win32_Volume associated with the mount point to get its device ID
                    $MountVolume = Get-VolumeByPath -TargetPath $TargetPath -ErrorAction Stop

                    # The Path parameter requires the device ID for mount points
                    Optimize-Volume -Path $MountVolume.DeviceID -ErrorAction Stop
                }

                Write-Host -Object "Optimization of $($VolumeTypeLabel.ToLower()) '$DisplayPath' completed successfully."
                $DriveResult.OptimizationResult = $true

                Write-Host -Object ""

                # Generate the post-optimization analysis report for this drive
                $AfterReport = $null
                try {
                    # Resolve the target path to its Win32_Volume
                    $CimVolume = Get-VolumeByPath -TargetPath $TargetPath -ErrorAction Stop

                    # Retrieve an analysis report for this volume after optimization
                    $AfterCimResult = Invoke-CimMethod -InputObject $CimVolume -MethodName "DefragAnalysis" -ErrorAction Stop

                    # Convert the raw CIM result into a more user-friendly report object
                    $AfterReport = ConvertTo-AnalysisReport -CimResult $AfterCimResult -ErrorAction Stop
                    $DriveResult.AfterReport = $AfterReport

                    if (-not $AfterReport) {
                        Write-Host -Object "[Error] No analysis data was returned for $($VolumeTypeLabel.ToLower()) '$DisplayPath' after optimization."
                        $ExitCode = 1
                    }
                }
                catch {
                    Write-Host -Object "[Error] Could not retrieve post-optimization analysis for $($VolumeTypeLabel.ToLower()) '$DisplayPath'."
                    Write-Host -Object "[Error] $($_.Exception.Message)"
                    $DriveResult.PostAnalysisError = $_.Exception.Message
                    $ExitCode = 1
                }

                # Display before/after values with arrows when both reports are available
                if ($BeforeReport -and $AfterReport) {
                    # Calculate the longest property name to align the colon " : " separator, matching Format-List behavior
                    $MaxNameLength = ($BeforeReport.PSObject.Properties.Name | Measure-Object -Property Length -Maximum).Maximum

                    # Build one comparison line per property in the before report: "Property Name : before -> after"
                    $ComparisonLines = New-Object System.Collections.Generic.List[string]
                    foreach ($Property in $BeforeReport.PSObject.Properties) {
                        # Get the value for this property
                        $BeforeValue = $Property.Value

                        # Retrieve the value after optimization for the same property name from the after report
                        $AfterValue = $AfterReport.PSObject.Properties[$Property.Name].Value

                        # Add the comparison line for this property to the list
                        $ComparisonLines.Add("$($Property.Name.PadRight($MaxNameLength)) : $BeforeValue -> $AfterValue")
                    }

                    # "Before -> After" is 15 chars
                    # The " : " separator makes it 18 chars total
                    # so pad the text left MaxNameLength + 18 to align it with the values in the comparison lines
                    $HeaderText = ("Before -> After").PadLeft($MaxNameLength + 18)

                    # Insert the header text at the top of the comparison lines list
                    $ComparisonLines.Insert(0, "$HeaderText")

                    Write-Host -Object ($ComparisonLines -join "`n")
                }
                elseif ($AfterReport) {
                    # Only the post-optimization snapshot is available
                    Write-Host -Object ($AfterReport | Format-List | Out-String).Trim()
                }
                elseif ($BeforeReport) {
                    # Only the pre-optimization snapshot is available (post-optimization analysis failed)
                    Write-Host -Object "[Warning] Post-optimization analysis was unavailable. Showing pre-optimization snapshot only."
                    Write-Host -Object ($BeforeReport | Format-List | Out-String).Trim()
                }
            }
            catch {
                Write-Host -Object "[Error] Failed to run $($DriveOperationLabel.ToLower()) on $($VolumeTypeLabel.ToLower()) '$DisplayPath'."
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object ""
                $DriveResult.OptimizationResult = $false
                $DriveResult.OptimizationError = $_.Exception.Message
                $ExitCode = 1
            }
        }
        #endregion

        Write-Host -Object ""
    }
    #endregion

    #region Multiline custom field
    # If a multiline custom field name was provided, build and save the report
    if ($MultilineCustomFieldName) {
        $ReportLines = New-Object System.Collections.Generic.List[string]

        # Add an alert header if optimization was recommended on any drive during analysis mode
        if ($AnalyzeOnly -and $AnyOptimizationRecommended) {
            $ReportLines.Add("[Alert] Optimization is recommended for one or more drives.")
            $ReportLines.Add("")
        }

        # Build the multiline report from stored drive results
        foreach ($DriveResult in $DriveAnalysisResults) {
            $TargetPath = $DriveResult.TargetPath

            # Determine the labeling for the output
            $VolumeTypeLabel = if ($TargetPath -match "^[A-Za-z]:\\$") { "Drive" } else { "Mount Point" }
            $DisplayPath = if ($TargetPath -match "^[A-Za-z]:\\$") { $TargetPath.TrimEnd(':\') } else { $TargetPath }
            $DriveOperationLabel = if ($AnalyzeOnly) { "Analysis" } else { "Optimization" }

            $ReportLines.Add("### $VolumeTypeLabel $DisplayPath | Type: $($DriveResult.MediaType) | $DriveOperationLabel ###")
            $ReportLines.Add("")

            # Format the report lines for analyze or optimize mode
            if ($AnalyzeOnly) {
                # If the pre-run analysis failed for this drive, report the error
                if ($DriveResult.Error) {
                    $ReportLines.Add("[Error] Failed to run $($DriveOperationLabel.ToLower()) on $($VolumeTypeLabel.ToLower()) '$DisplayPath'.")
                    $ReportLines.Add("[Error] $($DriveResult.Error)")
                }
                # If there is a report object for this drive, add it to the report
                elseif ($DriveResult.Report) {
                    $ReportLines.Add(($DriveResult.Report | Format-List | Out-String).Trim())
                }
                # If no analysis data was returned, add a warning
                else {
                    $ReportLines.Add("[Warning] No analysis data was returned for $($VolumeTypeLabel.ToLower()) '$DisplayPath'.")
                    $ReportLines.Add("[Warning] This $($VolumeTypeLabel.ToLower()) may not support fragmentation analysis.")
                }
            }
            else {
                # If the pre-run analysis failed, warn the user but continue building the report
                if ($DriveResult.Error) {
                    $ReportLines.Add("[Warning] Could not retrieve pre-optimization analysis for $($VolumeTypeLabel.ToLower()) '$DisplayPath'.")
                    $ReportLines.Add("[Warning] $($DriveResult.Error)")
                    $ReportLines.Add("")
                }
                # If no pre-optimization report was returned, note it in the report
                elseif (-not $DriveResult.Report) {
                    $ReportLines.Add("[Warning] No analysis data was returned for $($VolumeTypeLabel.ToLower()) '$DisplayPath' before optimization.")
                    $ReportLines.Add("")
                }

                # If the optimization operation failed, report the error
                if ($DriveResult.OptimizationResult -ne $true) {
                    $ReportLines.Add("[Error] Failed to run $($DriveOperationLabel.ToLower()) on $($VolumeTypeLabel.ToLower()) '$DisplayPath'.")
                    $ReportLines.Add("[Error] $($DriveResult.OptimizationError)")
                }
                else {
                    # If the post-optimization analysis failed, report the error
                    if ($DriveResult.PostAnalysisError) {
                        $ReportLines.Add("[Error] Could not retrieve post-optimization analysis for $($VolumeTypeLabel.ToLower()) '$DisplayPath'.")
                        $ReportLines.Add("[Error] $($DriveResult.PostAnalysisError)")
                    }
                    # If no post-optimization report was returned, report the error
                    elseif (-not $DriveResult.AfterReport) {
                        $ReportLines.Add("[Error] No analysis data was returned for $($VolumeTypeLabel.ToLower()) '$DisplayPath' after optimization.")
                    }

                    # Load the stored before/after snapshots and build the comparison output
                    $BeforeReport = $DriveResult.Report
                    $AfterReport = $DriveResult.AfterReport

                    # Before/after comparison data is available for both snapshots
                    if ($BeforeReport -and $AfterReport) {
                        # Calculate the longest property name to align the colon separator, matching Format-List behavior
                        $MaxNameLength = ($BeforeReport.PSObject.Properties.Name | Measure-Object -Property Length -Maximum).Maximum

                        # Initialize a list to hold the before/after comparison lines for this drive
                        $ComparisonLines = New-Object System.Collections.Generic.List[string]

                        # "Before -> After" is 15 chars
                        # The " : " separator makes it 18 chars total
                        # so pad the text left MaxNameLength + 18 to align it with the values
                        $ComparisonLines.Add(("Before -> After").PadLeft($MaxNameLength + 18))
                        foreach ($Property in $BeforeReport.PSObject.Properties) {
                            $AfterValue = $AfterReport.PSObject.Properties[$Property.Name].Value
                            $ComparisonLines.Add("$($Property.Name.PadRight($MaxNameLength)) : $($Property.Value) -> $AfterValue")
                        }

                        # Add the before/after comparison lines to the report
                        $ReportLines.Add($ComparisonLines -join "`n")
                    }
                    # Only the post-optimization snapshot is available
                    elseif ($AfterReport) {
                        $ReportLines.Add(($AfterReport | Format-List | Out-String).Trim())
                    }
                    # Only the pre-optimization snapshot is available (post-optimization analysis failed)
                    elseif ($BeforeReport) {
                        $ReportLines.Add("[Warning] Post-optimization analysis was unavailable. Showing pre-optimization snapshot only.")
                        $ReportLines.Add(($BeforeReport | Format-List | Out-String).Trim())
                    }
                }
            }
            $ReportLines.Add("")
        }

        # Join all lines into a single string with newlines to save to the custom field
        $ReportContent = $ReportLines -join "`n"

        try {
            Write-Host -Object "Attempting to save the results to the custom field '$MultilineCustomFieldName'."
            Set-NinjaProperty -Name $MultilineCustomFieldName -Value $ReportContent -ErrorAction Stop
            Write-Host -Object "Successfully set the custom field '$MultilineCustomFieldName'."
        }
        catch {
            Write-Host -Object "[Error] Failed to set the custom field '$MultilineCustomFieldName'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }

        Write-Host -Object ""
    }
    #endregion

    #region WYSIWYG custom field
    # If a WYSIWYG custom field name was provided, build and save a fragmentation bar chart
    if ($WysiwygCustomFieldName) {
        # Define the colors for the bar chart segments and legend
        $FragmentedColor = '#e05252'
        $CleanColor = '#4caf50'

        # Initialize a list to hold the HTML parts of the report
        $HtmlParts = New-Object System.Collections.Generic.List[string]

        # Loop through each drive's analysis results to build a card for each drive
        foreach ($DriveResult in $DriveAnalysisResults) {
            $TargetPath = $DriveResult.TargetPath

            # Determine the labeling for the WYSIWYG output
            $VolumeTypeLabel = if ($TargetPath -match "^[A-Za-z]:\\$") { "Drive" } else { "Mount Point" }
            $DisplayPath = if ($TargetPath -match "^[A-Za-z]:\\$") { $TargetPath.TrimEnd(':\') } else { $TargetPath }
            $DriveOperationLabel = if ($AnalyzeOnly) { "Analysis" } else { "Optimization" }

            # Initialize a list to hold the parts of this drive's card
            $CardParts = New-Object System.Collections.Generic.List[string]

            # Start the card with a title containing the drive/mount point and operation type
            $CardParts.Add("<div class='card' style='margin-right: 30px; margin-bottom: 30px;'>
            <div class='card-title-box' style='justify-content: center;'>
                <div class='card-title' style='white-space: normal;'>
                    <i class='fa-solid fa-hdd' style='margin-right: 8px;'></i>
                    $VolumeTypeLabel $DisplayPath | Type: $($DriveResult.MediaType) | $DriveOperationLabel
                </div>
            </div>
            <div class='card-body'>")

            # Build the card body for analyze or optimize mode
            if ($AnalyzeOnly) {
                # Add bar chart and table if analysis data is available; otherwise show an error card
                if ($DriveResult.Report) {
                    # Strip the percent sign to get a plain integer
                    $FragmentedPercentage = [int]($DriveResult.Report.'Percentage of Files Fragmented'.TrimEnd('%'))
                    $CleanPercentage = 100 - $FragmentedPercentage

                    # Add a horizontal bar chart representing the clean/fragmented percentages
                    $CardParts.Add("<div class='p-3 linechart'>
                        <div style='width: $CleanPercentage%; background-color: $CleanColor;'></div>
                        <div style='width: $FragmentedPercentage%; background-color: $FragmentedColor;'></div>
                    </div>")

                    # Add the color legend for the bar chart with percentage values
                    $CardParts.Add("<ul class='unstyled p-3' style='display: flex; justify-content: space-between;'>
                        <li style='display: inline-flex; align-items: center; margin-right: 6px;'>
                            <span class='chart-key' style='background-color: $CleanColor;'></span>
                            <span>Clean ($CleanPercentage%)</span>
                        </li>
                        <li style='display: inline-flex; align-items: center;'>
                            <span class='chart-key' style='background-color: $FragmentedColor;'></span>
                            <span>Fragmented ($FragmentedPercentage%)</span>
                        </li>
                    </ul>")

                    # Add a table of all fragmentation properties and values below the bar chart
                    $CardParts.Add("<table class='table table-striped p-3'><tbody>")
                    foreach ($Property in $DriveResult.Report.PSObject.Properties) {
                        # Highlight the "Optimization Recommended" property in red with the danger class if it is $true to draw attention to it
                        if ($Property.Name -eq "Optimization Recommended" -and $Property.Value -eq $true) {
                            $CardParts.Add("<tr class='danger'><td><strong>$($Property.Name)</strong></td><td>$($Property.Value)</td></tr>")
                        }
                        else {
                            $CardParts.Add("<tr><td><strong>$($Property.Name)</strong></td><td>$($Property.Value)</td></tr>")
                        }
                    }

                    # Close the table tags after adding all properties
                    $CardParts.Add("</tbody></table>")
                }
                else {
                    # If there is no report, display an error card indicating that fragmentation data is unavailable for this drive
                    $CardParts.Add("<div class='info-card error'>
                    <i class='info-icon fa-solid fa-circle-exclamation'></i>
                        <div class='info-text'>
                            <div class='info-title'>Data Unavailable</div>
                            <div class='info-description'>Unable to retrieve fragmentation data for this $($VolumeTypeLabel.ToLower()).</div>
                        </div>
                    </div>")
                }
            }
            else {
                # Use the stored pre- and post-optimization analysis reports for the before/after comparison
                $BeforeReport = $DriveResult.Report
                $AfterReport = $DriveResult.AfterReport

                if ($BeforeReport) {
                    # Strip the percent sign to get a plain integer usable as a CSS width value
                    $BeforeFrag = [int]($BeforeReport.'Percentage of Files Fragmented'.TrimEnd('%'))
                    $BeforeClean = 100 - $BeforeFrag

                    # Add a horizontal bar chart representing the clean/fragmented percentages before optimization
                    $CardParts.Add("<p style='margin-bottom: 0;'>Before ($BeforeFrag% fragmented)</p>")
                    $CardParts.Add("<div class='p-3 linechart'>
                        <div style='width: $BeforeClean%; background-color: $CleanColor;'></div>
                        <div style='width: $BeforeFrag%; background-color: $FragmentedColor;'></div>
                    </div>")
                }

                if ($AfterReport) {
                    # Strip the percent sign to get a plain integer usable as a CSS width value
                    $AfterFrag = [int]($AfterReport.'Percentage of Files Fragmented'.TrimEnd('%'))
                    $AfterClean = 100 - $AfterFrag

                    # Add a horizontal bar chart representing the clean/fragmented percentages after optimization
                    $CardParts.Add("<p style='margin-bottom: 0;'>After ($AfterFrag% fragmented)</p>")
                    $CardParts.Add("<div class='p-3 linechart'>
                        <div style='width: $AfterClean%; background-color: $CleanColor;'></div>
                        <div style='width: $AfterFrag%; background-color: $FragmentedColor;'></div>
                    </div>")
                }

                if ($BeforeReport -or $AfterReport) {
                    # Add the shared color legend below the bar charts
                    $CardParts.Add("<ul class='unstyled p-3' style='display: flex; justify-content: space-between;'>
                    <li style='display: inline-flex; align-items: center;'>
                        <span class='chart-key' style='background-color: $CleanColor; margin-right: 6px;'></span>
                        <span>Clean</span>
                    </li>
                    <li style='display: inline-flex; align-items: center;'>
                        <span class='chart-key' style='background-color: $FragmentedColor; margin-right: 6px;'></span>
                        <span>Fragmented</span>
                    </li>
                    </ul>")

                    # Create a table of all report properties with before/after comparison
                    $SourceReport = if ($BeforeReport) { $BeforeReport } else { $AfterReport }
                    $CardParts.Add("<table class='table table-striped p-3'><tbody>")

                    # Loop through each property in the report and add a table row with before/after values
                    # or just the available value if one report is missing
                    foreach ($Property in $SourceReport.PSObject.Properties) {
                        $PropName = $Property.Name
                        $BeforeValue = if ($BeforeReport) { $BeforeReport.PSObject.Properties[$PropName].Value } else { $null }
                        $AfterValue = if ($AfterReport) { $AfterReport.PSObject.Properties[$PropName].Value } else { $null }

                        # If this is the Optimization Recommended property, apply success/danger classes based on before/after values
                        $RowClass = ""
                        if ($PropName -eq "Optimization Recommended") {
                            if ($BeforeValue -eq $true -and $AfterValue -eq $false) { $RowClass = " class='success'" }
                            elseif ($BeforeValue -eq $true) { $RowClass = " class='danger'" }
                        }

                        # Determine the cell value based on which reports are available
                        # "before -> after" when both are available, otherwise just the available value
                        $ValueCell = if ($BeforeReport -and $AfterReport) {
                            "$BeforeValue &rarr; $AfterValue"
                        }
                        elseif ($BeforeReport) {
                            "$BeforeValue"
                        }
                        else {
                            "$AfterValue"
                        }

                        # Add the table row for this property with the determined value and class
                        $CardParts.Add("<tr$RowClass><td><strong>$PropName</strong></td><td>$ValueCell</td></tr>")
                    }

                    # Close the table tags after adding all properties
                    $CardParts.Add("</tbody></table>")
                }
                elseif ($DriveResult.OptimizationResult -ne $true) {
                    # If the optimization operation failed and there are no reports, display an error card indicating that the optimization failed for this drive
                    $CardParts.Add("<div class='info-card error'>
                    <i class='info-icon fa-solid fa-circle-exclamation'></i>
                        <div class='info-text'>
                            <div class='info-title'>Optimization Failed</div>
                            <div class='info-description'>The $($VolumeTypeLabel.ToLower()) could not be optimized.</div>
                        </div>
                    </div>")
                }
                else {
                    # If the optimization operation succeeded but no data is available, display an info card indicating that fragmentation data could not be retrieved
                    $CardParts.Add("<div class='info-card'>
                    <i class='info-icon fa-solid fa-circle-info'></i>
                        <div class='info-text'>
                            <div class='info-title'>Data Unavailable</div>
                            <div class='info-description'>Fragmentation data could not be retrieved after optimization.</div>
                        </div>
                    </div>")
                }
            }

            # Close the card body and card div tags after adding all content for this drive
            $CardParts.Add("</div></div>")

            # Add the completed card for this drive to the overall HTML parts list
            $HtmlParts.Add($CardParts -join "")
        }

        # Join all drive cards into a single HTML string to save to the WYSIWYG custom field
        $WysiwygContent = $HtmlParts -join ""

        try {
            Write-Host -Object "Attempting to save the fragmentation chart to the custom field '$WysiwygCustomFieldName'."
            $WysiwygContent | Set-NinjaProperty -Name $WysiwygCustomFieldName -ErrorAction Stop
            Write-Host -Object "Successfully set the custom field '$WysiwygCustomFieldName'."
        }
        catch {
            Write-Host -Object "[Error] Failed to set the custom field '$WysiwygCustomFieldName'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }
    #endregion

    exit $ExitCode
}
end {
    
    
    
}
