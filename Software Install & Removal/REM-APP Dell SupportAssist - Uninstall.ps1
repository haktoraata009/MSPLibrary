#Requires -Version 5.1

<#
.SYNOPSIS
    Removes Dell Support Assist applications from the system. If ran without parameters, it will report on the Dell Support Assist applications on the system.
.DESCRIPTION
    Removes all Dell Support Assist applications from the system. Runs with no script variables: it force-closes SupportAssist processes and removes every supported SupportAssist application by default.

.EXAMPLE
    (No Parameters)

    [Info] Found 4 Dell SupportAssist application(s):

    DisplayName                                           UninstallType
    -----------                                           -------------
    Dell SupportAssist for Business                       MSI
    Dell SupportAssist OS Recovery Plugin for Dell Update MSI
    Dell SupportAssist OS Recovery Plugin for Dell Update EXE
    DellInc.DellSupportAssistforPCs                       Appx

    [Info] Attempting to uninstall 'Dell SupportAssist for Business' using msiexec.
    [Info] Successfully uninstalled 'Dell SupportAssist for Business'.

    [Info] Attempting to uninstall 'Dell SupportAssist OS Recovery Plugin for Dell Update' using msiexec.
    [Info] Successfully uninstalled 'Dell SupportAssist OS Recovery Plugin for Dell Update'.

    [Info] Attempting to uninstall 'Dell SupportAssist OS Recovery Plugin for Dell Update' using the uninstall string '"C:\ProgramData\Package Cache\{d0ab664c-e704-4396-b9bc-ad1a7327731f}\DellUpdateSupportAssistPlugin.exe" /uninstall /quiet'.
    [Info] Successfully uninstalled 'Dell SupportAssist OS Recovery Plugin for Dell Update'.

    [Info] Attempting to uninstall 'DellInc.DellSupportAssistforPCs' using Remove-AppxPackage.
    [Info] Successfully uninstalled 'DellInc.DellSupportAssistforPCs'.

    [Warning] Additional SupportAssist applications found. This script does not support the removal of these applications.
    [Warning] Please use the 'Uninstall A Windows Application' script from the Template Library to uninstall these, or uninstall them manually.

    DisplayName          : Dell SupportAssist Example Additional Application
    UninstallString      : MsiExec.exe /I{AAAAAAAA-5F5F-4755-8613-66BB841FEB08}

.EXAMPLE
    -ForceCloseBeforeUninstall -RemoveDellSupportAssistForBusiness

    [Info] Found 4 Dell SupportAssist application(s):

    DisplayName                                           UninstallType
    -----------                                           -------------
    Dell SupportAssist for Business                       MSI
    Dell SupportAssist OS Recovery Plugin for Dell Update MSI
    Dell SupportAssist OS Recovery Plugin for Dell Update EXE
    DellInc.DellSupportAssistforPCs                       Appx

    [Info] Stopping open processes for 'Dell SupportAssist for Business'.
    [Info] Successfully stopped the process 'SupportAssistAgent'.
    [Info] Successfully stopped the process 'SupportAssistAppWire'.
    [Info] Successfully stopped the process 'SupportAssistClientUI'.
    [Info] Successfully stopped the process 'SupportAssistHardwareDiags'.

    [Info] Attempting to uninstall 'Dell SupportAssist for Business' using msiexec.
    [Info] Successfully uninstalled 'Dell SupportAssist for Business'.

    [Warning] Additional SupportAssist applications found. This script does not support the removal of these applications.
    [Warning] Please use the 'Uninstall A Windows Application' script from the Template Library to uninstall these, or uninstall them manually.

    DisplayName          : Dell SupportAssist Example Additional Application
    UninstallString      : MsiExec.exe /I{AAAAAAAA-5F5F-4755-8613-66BB841FEB08}

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 2.0
    Release Notes: Brought up to standards, added options for force closing processes and removing specific applications.
#>

[CmdletBinding()]
param (
    # Defaults remove everything with no script variables. Pass -RemoveAll:$false
    # plus a specific -Remove* switch to remove one application only.
    [Parameter()]
    [switch]$ForceCloseBeforeUninstall = $true,
    [Parameter()]
    [switch]$RemoveAll = $true,
    [Parameter()]
    [switch]$RemoveDellSupportAssistForBusiness,
    [Parameter()]
    [switch]$RemoveDellSupportAssistForHome,
    [Parameter()]
    [switch]$RemoveDellSupportAssistAppxPackages,
    [Parameter()]
    [switch]$RemoveDellSupportAssistOSRecoveryPlugin,
    [Parameter()]
    [switch]$RemoveDellUpdateSupportAssistUpdatePlugin
)

begin {
    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    function Find-InstallKey {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromPipeline = $True)]
            [String]$DisplayName,
            [Parameter()]
            [Switch]$UninstallString,
            [Parameter()]
            [String]$UserBaseKey
        )
        process {
            # Initialize an empty list to hold installation objects
            $InstallList = New-Object System.Collections.Generic.List[Object]

            # If no user base key is specified, search in the default system-wide uninstall paths
            if (!$UserBaseKey) {
                # Search for programs in 32-bit and 64-bit locations. Then add them to the list if they match the display name
                $Result = Get-ChildItem -Path "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" }
                if ($Result) {
                    foreach ($Item in $Result) {
                        $InstallList.Add($Item)
                    }
                }

                $Result = Get-ChildItem -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" }
                if ($Result) {
                    foreach ($Item in $Result) {
                        $InstallList.Add($Item)
                    }
                }
            } else {
                # If a user base key is specified, search in the user-specified 64-bit and 32-bit paths.
                $Result = Get-ChildItem -Path "$UserBaseKey\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" }
                if ($Result) {
                    foreach ($Item in $Result) {
                        $InstallList.Add($Item)
                    }
                }

                $Result = Get-ChildItem -Path "$UserBaseKey\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" }
                if ($Result) {
                    foreach ($Item in $Result) {
                        $InstallList.Add($Item)
                    }
                }
            }

            # If the UninstallString switch is specified, return only the uninstall strings; otherwise, return the full installation objects.
            if ($UninstallString) {
                $InstallList | Select-Object -ExpandProperty UninstallString -ErrorAction SilentlyContinue
            } else {
                $InstallList
            }
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

    # Warn the user if 'Remove All' was selected along with individual applications
    if ($RemoveAll -and ($RemoveDellSupportAssistForBusiness -or $RemoveDellSupportAssistForHome -or $RemoveDellSupportAssistOSRecoveryPlugin -or $RemoveDellUpdateSupportAssistUpdatePlugin)) {
        Write-Host "[Warning] 'Remove All' was selected. Ignoring individual application selections."
    }

    # Define the list of Dell SupportAssist application names to search for
    $SupportedDellSupportAssistNames = @(
        "Dell SupportAssist"
        "Dell SupportAssist OS Recovery Plugin for Dell Update"
        "Dell Update - SupportAssist Update Plugin"
        "Dell SupportAssist for Home"
        "Dell SupportAssist for Business"
    )

    # Search for the Dell SupportAssist applications
    try {
        $FoundDellApplications = Find-InstallKey -DisplayName "SupportAssist" -ErrorAction Stop
    }
    catch {
        Write-Host "[Error] Failed to find Dell SupportAssist applications."
        Write-Host "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Sort the Dell applications by DisplayName
    $FoundDellApplications = $FoundDellApplications | Sort-Object -Property DisplayName

    # Initialize a list to hold Dell applications that can be removed
    $DellApplicationsThatCanBeRemoved = New-Object System.Collections.Generic.List[object]

    # If any of the detected SupportAssist applications match the supported names, add them to the list of applications that can be removed
    foreach ($App in $FoundDellApplications) {
        if ($App.DisplayName -in $SupportedDellSupportAssistNames) {
            $DellApplicationsThatCanBeRemoved.Add($App)
        }
    }

    # Add extra metadata to each detected application
    foreach ($App in $DellApplicationsThatCanBeRemoved) {
        # Determine the uninstall type
        switch -regex ($App.UninstallString) {
            "msiexec.exe" {
                $UninstallType = "MSI"
                break
            }
            "\.exe" {
                $UninstallType = "EXE"
                break
            }
            default {
                $UninstallType = "Unknown"
            }
        }

        # Add the UninstallType property to the application object
        $App | Add-Member -MemberType NoteProperty -Name "UninstallType" -Value $UninstallType -Force

        # Determine the associated folders and services for each application
        switch ($App.DisplayName) {
            { $_ -in @("Dell SupportAssist OS Recovery Plugin for Dell Update", "Dell Update - SupportAssist Update Plugin") } {
                $AssociatedFolders = @(
                    "$env:ProgramFiles\Dell\SARemediation"
                    "${env:ProgramFiles(x86)}\Dell\SARemediation"
                )

                # Add the associated folders to the application object
                $App | Add-Member -MemberType NoteProperty -Name "AssociatedFolders" -Value $AssociatedFolders -Force
                break
            }
            "Dell SupportAssist" {
                # Check the registry to determine if this is the Home or Business version
                try {
                    $Source = Get-ItemProperty -Path 'HKLM:\SOFTWARE\DELL\SupportAssistAgent' -ErrorAction Stop | Select-Object -ExpandProperty Source
                }
                catch {
                    Write-Host "[Error] Unable to determine if the device has Dell SupportAssist for Home or Business. The script will assume it is the Home version."
                    Write-Host "[Error] $($_.Exception.Message)"
                    $ExitCode = 1
                }

                # If the source is "DellBusiness", set the display name and associated folders accordingly
                if ($Source -eq "DellBusiness") {
                    $App.DisplayName = "Dell SupportAssist for Business"

                    # The associated folders are different for the business version of Dell SupportAssist
                    $AssociatedFolders = @(
                        "$env:ProgramFiles\Dell\SupportAssistAgent"
                        "${env:ProgramFiles(x86)}\Dell\SupportAssistAgent"
                        "$env:ProgramFiles\Dell\DellDataVault"
                        "${env:ProgramFiles(x86)}\Dell\DellDataVault"
                        "$env:ProgramFiles\Dell\Dell Insights"
                        "${env:ProgramFiles(x86)}\Dell\Dell Insights"
                        "$env:ProgramFiles\Dell\Dell Remediation"
                        "${env:ProgramFiles(x86)}\Dell\Dell Remediation"
                    )
                }
                else {
                    $App.DisplayName = "Dell SupportAssist for Home"

                    $AssociatedFolders = @(
                        "$env:ProgramFiles\Dell\SupportAssistAgent"
                        "${env:ProgramFiles(x86)}\Dell\SupportAssistAgent"
                        "$env:ProgramFiles\Dell\DellDataVault"
                        "${env:ProgramFiles(x86)}\Dell\DellDataVault"
                    )
                }

                $AssociatedServices = @("SupportAssistAgent")

                $AssociatedProcesses = @(
                    "SupportAssistUI"
                    "SupportAssistClientUI"
                    "SupportAssistAppWire"
                    "SupportAssistAgent"
                    "SupportAssistHardwareDiags"
                )

                # Add the associated items to the application object
                $App | Add-Member -MemberType NoteProperty -Name "AssociatedFolders" -Value $AssociatedFolders -Force
                $App | Add-Member -MemberType NoteProperty -Name "AssociatedServices" -Value $AssociatedServices -Force
                $App | Add-Member -MemberType NoteProperty -Name "AssociatedProcesses" -Value $AssociatedProcesses -Force
                break
            }
        }
    }

    # Find all Appx packages for Dell SupportAssist and add them to the list of applications that can be removed
    try {
        $AppxPackages = Get-AppxPackage -Name "Dell*SupportAssist*" -AllUsers -ErrorAction Stop
    }
    catch {
        Write-Host "[Error] Failed to find Dell SupportAssist Appx packages."
        Write-Host "[Error] $($_.Exception.Message)"
        $ExitCode = 1
    }

    # If Appx packages are found, create a custom object for each and add it to the list of applications that can be removed
    if ($AppxPackages) {
        foreach ($Package in $AppxPackages) {
            $AppObject = [PSCustomObject]@{
                DisplayName     = $Package.Name
                PackageFullName = $Package.PackageFullName
                UninstallType   = "Appx"
            }

            $DellApplicationsThatCanBeRemoved.Add($AppObject)
        }
    }

    if (($DellApplicationsThatCanBeRemoved | Measure-Object).Count -eq 0) {
        Write-Host "[Info] No Dell SupportAssist applications found."
    }
    else {
        Write-Host "[Info] Found $(($DellApplicationsThatCanBeRemoved | Measure-Object).Count) Dell SupportAssist application(s):`n"
    }

    # Output the list of Dell applications that can be removed
    ($DellApplicationsThatCanBeRemoved | Select-Object DisplayName, UninstallType | Format-Table -AutoSize | Out-String).Trim() | Write-Host

    Write-Host ""

    # Initialize a list of applications to uninstall
    $AppsToUninstall = New-Object System.Collections.Generic.List[object]

    # If 'Remove All' was selected, add all found applications to the uninstall list
    if ($RemoveAll) {
        foreach ($App in $DellApplicationsThatCanBeRemoved) {
            $AppsToUninstall.Add($App)
        }
    }

    # If 'Remove All' was not selected but individual applications were selected, add those to the uninstall list
    if (-not $RemoveAll -and $RemoveDellSupportAssistForBusiness) {
        $AppsFromList = $DellApplicationsThatCanBeRemoved | Where-Object { $_.DisplayName -eq "Dell SupportAssist for Business" }
        foreach ($App in $AppsFromList) {
            $AppsToUninstall.Add($App)
        }
    }

    if (-not $RemoveAll -and $RemoveDellSupportAssistForHome) {
        $AppsFromList = $DellApplicationsThatCanBeRemoved | Where-Object { $_.DisplayName -eq "Dell SupportAssist for Home" }
        foreach ($App in $AppsFromList) {
            $AppsToUninstall.Add($App)
        }
    }

    if (-not $RemoveAll -and $RemoveDellSupportAssistAppxPackages) {
        $AppsFromList = $DellApplicationsThatCanBeRemoved | Where-Object { $_.UninstallType -eq "Appx" }
        foreach ($App in $AppsFromList) {
            $AppsToUninstall.Add($App)
        }
    }

    if (-not $RemoveAll -and $RemoveDellSupportAssistOSRecoveryPlugin) {
        $AppsFromList = $DellApplicationsThatCanBeRemoved | Where-Object { $_.DisplayName -eq "Dell SupportAssist OS Recovery Plugin for Dell Update" }
        foreach ($App in $AppsFromList) {
            $AppsToUninstall.Add($App)
        }
    }

    if (-not $RemoveAll -and $RemoveDellUpdateSupportAssistUpdatePlugin) {
        $AppsFromList = $DellApplicationsThatCanBeRemoved | Where-Object { $_.DisplayName -eq "Dell Update - SupportAssist Update Plugin" }
        foreach ($App in $AppsFromList) {
            $AppsToUninstall.Add($App)
        }
    }

    # If there are no apps to uninstall, and any removal options were selected, inform the user
    if ($AppsToUninstall.Count -eq 0 -and ($RemoveAll -or $RemoveDellSupportAssistForBusiness -or $RemoveDellSupportAssistForHome -or $RemoveDellSupportAssistAppxPackages -or $RemoveDellSupportAssistOSRecoveryPlugin -or $RemoveDellUpdateSupportAssistUpdatePlugin)) {
        Write-Host "[Info] None of the Dell SupportAssist applications selected for removal were detected.`n"
    }

    # If 'Force Close Before Uninstall' was selected, close each of the associated processes before attempting to uninstall
    if ($ForceCloseBeforeUninstall) {
        $AppsToUninstall | ForEach-Object {
            $AppName = $_.DisplayName
            $AssociatedProcesses = $_.AssociatedProcesses

            # Skip if there are no associated processes defined for the application
            if (-not $AssociatedProcesses) { return }

            # Check if there are any associated processes to close
            $RunningProcesses = Get-Process -Name $AssociatedProcesses -ErrorAction SilentlyContinue

            # If running processes are found, attempt to stop them
            if ($RunningProcesses) {
                Write-Host "[Info] Stopping open processes for '$AppName'."

                # Loop through each process and attempt to stop it
                foreach ($Process in $RunningProcesses) {
                    try {
                        $Process | Stop-Process -Force -Confirm:$false -ErrorAction Stop
                        Write-Host "[Info] Successfully stopped the process '$($Process.Name)'."
                    }
                    catch {
                        Write-Host "[Error] Failed to stop the '$($Process.Name)' process."
                        Write-Host "[Error] $($_.Exception.Message)"
                        $ExitCode = 1
                    }
                }
            }
            Write-Host ""
        }
    }

    # Loop through each application and attempt to uninstall it
    $AppsToUninstall | ForEach-Object {
        $AppName = $_.DisplayName
        $PackageFullName = $_.PackageFullName
        $UninstallString = $_.UninstallString
        $UninstallType = $_.UninstallType
        $FailedToUninstall = $False

        # Check if there is a quiet uninstall string available and use that if it exists
        if ($_.QuietUninstallString) {
            $UninstallString = $_.QuietUninstallString
        }

        switch ($UninstallType) {
            # If the UninstallString is for msiexec, extract the GUID and use msiexec to uninstall
            "MSI" {
                # Extract the GUID from the uninstall string
                $GUID = [regex]::Matches($UninstallString, '\{[0-9A-Fa-f\-]{36}\}').Value

                # Error if the GUID is null or empty and continue to the next application
                if ([string]::IsNullOrWhiteSpace($GUID)) {
                    Write-Host "[Error] Unable to extract GUID from uninstall string '$UninstallString' for the application $AppName."
                    $ExitCode = 1
                    return
                }

                Write-Host "[Info] Attempting to uninstall '$AppName' using msiexec."
                try {
                    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $GUID /qn /norestart" -Wait -PassThru -ErrorAction Stop

                    if ($Process.ExitCode -ne 0) {
                        throw "Exit code not equal to 0."
                    }
                }
                catch {
                    Write-Host "[Error] Failed to uninstall $AppName. Exit Code: $($Process.ExitCode)"
                    Write-Host "[Error] $($_.Exception.Message)"
                    $FailedToUninstall = $True
                    $ExitCode = 1
                }
            }
            "EXE" {
                Write-Host "[Info] Attempting to uninstall '$AppName' using the uninstall string '$UninstallString'."

                try {
                    $Process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$UninstallString`"" -Wait -NoNewWindow -PassThru -ErrorAction Stop

                    if ($Process.ExitCode -ne 0) {
                        throw "Exit code not equal to 0."
                    }
                }
                catch {
                    Write-Host "[Error] Failed to uninstall $AppName. Exit Code: $($Process.ExitCode)"
                    Write-Host "[Error] $($_.Exception.Message)"
                    $FailedToUninstall = $True
                    $ExitCode = 1
                }
            }
            "Appx" {
                Write-Host "[Info] Attempting to uninstall '$AppName' using Remove-AppxPackage."

                try {
                    Remove-AppxPackage -Package "$PackageFullName" -AllUsers -ErrorAction Stop

                    # Sleep to ensure the Appx package has time to uninstall before verification
                    Start-Sleep -Seconds 2
                }
                catch {
                    Write-Host "[Error] Failed to uninstall $AppName."
                    Write-Host "[Error] $($_.Exception.Message)"
                    $FailedToUninstall = $True
                    $ExitCode = 1
                }
            }
            default {
                Write-Host "[Error] Uninstall type for '$AppName' is unknown. Skipping uninstallation."
                $FailedToUninstall = $True
                $ExitCode = 1
            }
        }

        # Test each of the associated folders to see if there are still any left behind
        foreach ($Folder in $_.AssociatedFolders) {
            if (Test-Path $Folder) {
                Write-Host "[Warning] The folder '$Folder' associated with '$AppName' still exists after uninstallation."
                Write-Host "[Warning] This might indicate that the uninstall did not complete successfully, or it may be used by a different Dell application."
            }
        }

        # Test each of the associated services to see if there are still any left behind
        foreach ($Service in $_.AssociatedServices) {
            if (Get-Service -Name $Service -ErrorAction SilentlyContinue) {
                Write-Host "[Warning] The service '$Service' associated with '$AppName' still exists after uninstallation."
            }
        }

        # Test each of the associated processes to see if there are still any left behind
        foreach ($Process in $_.AssociatedProcesses) {
            if (Get-Process -Name $Process -ErrorAction SilentlyContinue) {
                Write-Host "[Warning] The process '$Process' associated with '$AppName' is still running after uninstallation."
            }
        }

        # Verify that the application is no longer installed
        if (-not $FailedToUninstall -and $UninstallType -match "MSI|EXE") {
            try {
                $TestIfAppStillExists = Find-InstallKey -DisplayName $AppName -ErrorAction Stop

                # Determine the uninstall type of the found applications
                $TestIfAppStillExists | ForEach-Object {
                    $ThisApp = $_
                    switch -regex ($ThisApp.UninstallString) {
                        "msiexec.exe" {
                            $ThisApp | Add-Member -MemberType NoteProperty -Name "UninstallType" -Value "MSI" -Force
                            break
                        }
                        "\.exe" {
                            $ThisApp | Add-Member -MemberType NoteProperty -Name "UninstallType" -Value "EXE" -Force
                            break
                        }
                        default {
                            $ThisApp | Add-Member -MemberType NoteProperty -Name "UninstallType" -Value "Unknown" -Force
                        }
                    }
                }

                # Filter the results to only include those with the same uninstall type
                $TestIfAppStillExists = $TestIfAppStillExists | Where-Object {$_.UninstallType -eq $UninstallType}

                # If the application is still found with the same uninstall type, mark the uninstall as failed
                if ($TestIfAppStillExists) {
                    Write-Host "[Error] Verification check found that '$AppName' is still installed."
                    $FailedToUninstall = $True
                }
            }
            catch {
                Write-Host "[Error] Failed to verify if '$AppName' was successfully uninstalled. Assuming it did fail to uninstall."
                Write-Host "[Error] $($_.Exception.Message)"
                $FailedToUninstall = $True
                $ExitCode = 1
            }
        }

        # The Appx package requires a different method to verify it was uninstalled
        if (-not $FailedToInstall -and $UninstallType -match "Appx") {
            try {
                $TestIfAppStillExists = Get-AppxPackage -Name "Dell*SupportAssist*" -AllUsers -ErrorAction Stop

                if ($TestIfAppStillExists) {
                    Write-Host "[Error] Appx verification check found that '$AppName' is still installed."
                    $FailedToUninstall = $True
                }
            }
            catch {
                Write-Host "[Error] Failed to verify if '$AppName' was successfully uninstalled. Assuming it did fail to uninstall."
                Write-Host "[Error] $($_.Exception.Message)"
                $FailedToUninstall = $True
                $ExitCode = 1
            }
        }

        # Set exit code to 1 if any part of the uninstall failed
        if ($FailedToUninstall) {
            Write-Host "[Error] Uninstall failed for '$AppName.'"
            $ExitCode = 1
        }
        else {
            Write-Host "[Info] Successfully uninstalled '$AppName'."
        }

        Write-Host ""
    }

    # Identify any additional SupportAssist applications that this script does not handle
    $AdditionalApps = $FoundDellApplications | Where-Object { $_.DisplayName -notin $SupportedDellSupportAssistNames -and $_.DisplayName -notin $AppsToUninstall.DisplayName }

    # If any additional applications were found, output a warning and list them
    if ($AdditionalApps) {
        Write-Host "[Warning] Additional SupportAssist applications found. This script does not support the removal of these applications."
        Write-Host "[Warning] Please use the 'Uninstall A Windows Application' script from the Template Library to uninstall these, or uninstall them manually."
        foreach ($App in $AdditionalApps) {
            if ($App.QuietUninstallString) {
                Write-Host ""
                ($App | Select-Object DisplayName, UninstallString, QuietUninstallString | Format-List | Out-String).Trim() | Write-Host
                Write-Host ""
            }
            else {
                Write-Host ""
                ($App | Select-Object DisplayName, UninstallString | Format-List | Out-String).Trim() | Write-Host
                Write-Host ""
            }
        }
    }

    # Identify any additional SupportAssist Appx packages that this script does not handle
    $AdditionalAppxPackages = Get-AppxPackage -Name "Dell*SupportAssist*" -AllUsers -ErrorAction Stop | Where-Object { $_.Name -notin $DellApplicationsThatCanBeRemoved.DisplayName }

    # If any additional Appx packages were found, output a warning and list them
    if ($AdditionalAppxPackages) {
        Write-Host "[Warning] Additional SupportAssist Appx packages found. This script does not support the removal of these applications."
        Write-Host "[Warning] If desired, please uninstall these manually using Remove-AppxPackage."

        foreach ($App in $AdditionalAppxPackages) {
            Write-Host ""
            ($App | Select-Object Name, PackageFullName | Format-List | Out-String).Trim() | Write-Host
            Write-Host ""
        }
    }

    exit $ExitCode
}
end {
    
    
    
}