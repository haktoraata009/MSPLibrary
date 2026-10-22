#Requires -Version 5.1

<#
.SYNOPSIS
    Configure common Windows 11 taskbar settings for all users (when run as 'System') or just the current user (when run as 'Current Logged On User').
.DESCRIPTION
    Configure common Windows 11 taskbar settings for all users (when run as 'System') or just the current user (when run as 'Current Logged On User').
    Supports configuring taskbar alignment, auto-hide, search button visibility, task view button, and widgets button.

.EXAMPLE
    -TaskbarAlignment "Left"

    Applying taskbar settings for all users.

    Setting taskbar settings for user 'kpradlander'.
    Updated 'Registry::HKEY_USERS\S-1-5-21-745448846-3964690785-1211766275-500\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarAl' from '1' to '0'.

    Finished applying taskbar settings.

.EXAMPLE
    -AutoHideTaskbar "Enable" -TaskbarAlignment "Center"

    Applying taskbar settings for all users.

    Setting taskbar settings for user 'kpradlander'.
    Updated 'Registry::HKEY_USERS\S-1-5-21-745448846-3964690785-1211766275-500\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarAl' from '0' to '1'.
    Updated 'Registry::HKEY_USERS\S-1-5-21-745448846-3964690785-1211766275-500\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3\Settings' byte[8] from '2' to '3'.

    Finished applying taskbar settings.

.EXAMPLE
    -WidgetsButton "Hide" -RestartExplorer

    Applying taskbar settings for all users.

    Setting taskbar settings for user 'kpradlander'.
    Updated 'Registry::HKEY_USERS\S-1-5-21-745448846-3964690785-1211766275-500\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDa' from '1' to '0'.

    Finished applying taskbar settings.

    Restarting Explorer.exe as requested.

.PARAMETER TaskbarAlignment
    Set the taskbar alignment to Left or Center.

.PARAMETER AutoHideTaskbar
    Enable or disable the auto-hide taskbar feature.

.PARAMETER SearchButton
    Set the search button visibility on the taskbar.

.PARAMETER TaskViewButton
   Show or hide the Task View button on the taskbar.

.PARAMETER WidgetsButton
    Show or hide the Widgets button on the taskbar.

.PARAMETER RestartExplorer
    Restart Explorer.exe after applying changes. This is necessary for the widgets button to update immediately.

.NOTES
    Minimum OS Architecture Supported: Windows 11
    Version: 1.1
    Release Notes: Removed UCPD management (moved to a separate script).

#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$TaskbarAlignment = $env:taskbarAlignment,
    [Parameter()]
    [String]$AutoHideTaskbar = $env:autoHideTaskbar,
    [Parameter()]
    [String]$SearchButton = $env:searchButton,
    [Parameter()]
    [String]$TaskViewButton = $env:taskViewButton,
    [Parameter()]
    [String]$WidgetsButton = $env:widgetsButton,
    [Parameter()]
    [Switch]$RestartExplorer = [System.Convert]::ToBoolean($env:restartExplorer)
)

begin {
    # Check if the operating system build version is less than 22000 (Windows 11 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 22000) {
        Write-Host -Object "[Error] This script requires Windows 11 (build 22000 or later). Current build: $([System.Environment]::OSVersion.Version.Build)."
        exit 1
    }

    #region Input Validation
    # Trim and validate Taskbar Alignment
    if ($TaskbarAlignment) {
        if ([String]::IsNullOrWhiteSpace($TaskbarAlignment)) {
            Write-Host -Object "[Error] Taskbar alignment was provided but is empty or only whitespace."
            exit 1
        }

        $TaskbarAlignment = $TaskbarAlignment.Trim()

        $ValidAlignments = "Left", "Center"
        if ($ValidAlignments -notcontains $TaskbarAlignment) {
            Write-Host -Object "[Error] Invalid taskbar alignment '$TaskbarAlignment'. Valid options: $($ValidAlignments -join ', ')."
            exit 1
        }
    }

    # Trim and validate Auto-hide Taskbar
    if ($AutoHideTaskbar) {
        if ([String]::IsNullOrWhiteSpace($AutoHideTaskbar)) {
            Write-Host -Object "[Error] Auto-hide taskbar was provided but is empty or only whitespace."
            exit 1
        }

        $AutoHideTaskbar = $AutoHideTaskbar.Trim()

        $ValidAutoHide = "Enable", "Disable"
        if ($ValidAutoHide -notcontains $AutoHideTaskbar) {
            Write-Host -Object "[Error] Invalid auto-hide option '$AutoHideTaskbar'. Valid options: $($ValidAutoHide -join ', ')."
            exit 1
        }
    }

    # Trim and validate Search Button
    if ($SearchButton) {
        if ([String]::IsNullOrWhiteSpace($SearchButton)) {
            Write-Host -Object "[Error] Search button was provided but is empty or only whitespace."
            exit 1
        }

        $SearchButton = $SearchButton.Trim()

        $ValidSearch = "Hide", "Search Icon Only", "Search Icon and Label", "Search Box"
        if ($ValidSearch -notcontains $SearchButton) {
            Write-Host -Object "[Error] Invalid search button option '$SearchButton'. Valid options: $($ValidSearch -join ', ')."
            exit 1
        }
    }

    # Trim and validate Task View Button
    if ($TaskViewButton) {
        if ([String]::IsNullOrWhiteSpace($TaskViewButton)) {
            Write-Host -Object "[Error] Task View button was provided but is empty or only whitespace."
            exit 1
        }

        $TaskViewButton = $TaskViewButton.Trim()

        $ValidTaskView = "Show", "Hide"
        if ($ValidTaskView -notcontains $TaskViewButton) {
            Write-Host -Object "[Error] Invalid task view button option '$TaskViewButton'. Valid options: $($ValidTaskView -join ', ')."
            exit 1
        }
    }

    # Trim and validate Widgets Button
    if ($WidgetsButton) {
        if ([String]::IsNullOrWhiteSpace($WidgetsButton)) {
            Write-Host -Object "[Error] Widgets button was provided but is empty or only whitespace."
            exit 1
        }

        $WidgetsButton = $WidgetsButton.Trim()

        $ValidWidgets = "Show", "Hide"
        if ($ValidWidgets -notcontains $WidgetsButton) {
            Write-Host -Object "[Error] Invalid widgets button option '$WidgetsButton'. Valid options: $($ValidWidgets -join ', ')."
            exit 1
        }
    }

    # Ensure at least one setting or action is specified
    if (!$TaskbarAlignment -and !$AutoHideTaskbar -and !$SearchButton -and !$TaskViewButton -and !$WidgetsButton) {
        Write-Host -Object "[Error] At least one taskbar setting or action must be specified."
        exit 1
    }

    # Detect UCPD when widgets option is selected
    if ($WidgetsButton) {
        $UserProtectionService = Get-Service -Name "UCPD" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" }
        $UserProtectionTask = Get-ScheduledTask -TaskName "UCPD velocity" -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -ErrorAction SilentlyContinue | Where-Object { $_.State -ne "Disabled" }

        if ($UserProtectionService -or $UserProtectionTask) {
            Write-Host -Object "`n[Warning] The widgets setting may be protected by the 'User Choice Protection Driver' as it is currently active."
            Write-Host -Object "[Warning] You may want to run the script 'User Defaults - UCPD - Enable or Disable' to disable this protection.`n"
        }
    }
    #endregion

    #region Helper Functions

    # Test if running as the System account
    function Test-IsSystem {
        [CmdletBinding()]
        param ()

        # Retrieve the current Windows identity of the user or process running the script
        $WindowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()

        # Check if the identity is a system account by verifying the IsSystem property
        # or comparing the User property to the well-known SID for the LocalSystem account (S-1-5-18)
        $WindowsIdentity.IsSystem -or $WindowsIdentity.User -eq "S-1-5-18"
    }

    function Set-RegKey {
        [CmdletBinding()]
        param (
            [Parameter()]
            [String]$Path,
            [Parameter()]
            [String]$Name,
            [Parameter()]
            $Value,
            [Parameter()]
            [ValidateSet("DWord", "QWord", "String", "ExpandedString", "Binary", "MultiString", "Unknown")]
            [String]$PropertyType = "DWord"
        )

        if ([String]::IsNullOrWhiteSpace($Path)) {
            throw (New-Object System.ArgumentNullException("You must provide a valid path to a registry key."))
        }

        if ($Path -notmatch "^(Registry::|HKCR:\\|HKCU:\\|HKLM:\\|HKU:\\|HKCC:\\|TestRegistry:\\)") {
            throw (New-Object System.ArgumentException("The path provided '$Path' is invalid as it does not start with 'Registry::', 'HKCR:\', 'HKCU:\', 'HKLM:\', 'HKU:\' or 'HKCC:\'."))
        }

        if ($Path -match "^Registry::" -and $Path -notmatch "^Registry::(HKCR\\|HKEY_CLASSES_ROOT\\|HKCU\\|HKEY_CURRENT_USER\\|HKLM\\|HKEY_LOCAL_MACHINE|HKU\\|HKEY_USERS|HKCC\\|HKEY_CURRENT_CONFIG)") {
            throw (New-Object System.ArgumentException("The path provided '$Path' is invalid as it does not start with a valid registry root such as 'HKLM\' or 'HKEY_LOCAL_MACHINE\'."))
        }

        if ([String]::IsNullOrWhiteSpace($Name)) {
            throw (New-Object System.ArgumentNullException("You must provide a valid name for the registry property."))
        }

        # Create list to store status messages
        $Status = [System.Collections.Generic.List[String]]::new()

        # Check if the specified registry path exists
        if (!(Test-Path -Path $Path)) {
            try {
                New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
                $Status.Add("CreatedPath")
            } catch {
                throw $_
            }
        }

        # Check if the registry key already exists at the specified path
        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            # Retrieve the current value of the registry key
            $previousValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Name -ErrorAction SilentlyContinue
            if ($previousValue -eq $Value) {
                $Status.Add("AlreadySet")
            } else {
                try {
                    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -Confirm:$false -ErrorAction Stop | Out-Null
                    $Status.Add("Updated")
                } catch {
                    throw $_
                }
            }
        } else {
            try {
                New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force -Confirm:$false -ErrorAction Stop | Out-Null
                $Status.Add("CreatedRegKey")
            } catch {
                throw $_
            }
        }

        # Output the registry key and its value
        try {
            $output = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        } catch {
            throw $_
        }

        $output | Add-Member -MemberType NoteProperty -Name "PreviousValue" -Value $previousValue
        $output | Add-Member -MemberType NoteProperty -Name "Status" -Value $Status
        return $output
    }

    # Retrieves all accounts on a system
    function Get-UserHive {
        [CmdletBinding()]
        param (
            [Parameter()]
            [ValidateSet('AzureAD', 'DomainAndLocal', 'All')]
            [String]$Type = "All",
            [Parameter()]
            [String[]]$ExcludedUsers,
            [Parameter()]
            [switch]$IncludeDefault
        )

        # Define the SID patterns to match based on the selected user type
        $Patterns = switch ($Type) {
            "AzureAD" { "S-1-12-1-(\d+-?){4}$" }
            "DomainAndLocal" { "S-1-5-21-(\d+-?){4}$" }
            "All" { "S-1-12-1-(\d+-?){4}$" ; "S-1-5-21-(\d+-?){4}$" }
        }

        # Retrieve user profile information based on the defined patterns
        $UserProfiles = foreach ($Pattern in $Patterns) {
            Get-ItemProperty "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" |
                Where-Object { $_.PSChildName -match $Pattern } |
                Select-Object @{Name = "SID"; Expression = { $_.PSChildName } },
                @{Name = "Username"; Expression = { "$($_.ProfileImagePath | Split-Path -Leaf)" } },
                @{Name = "Domain"; Expression = { if ($_.PSChildName -match "S-1-12-1-(\d+-?){4}$") { "AzureAD" }else { $Null } } },
                @{Name = "UserHive"; Expression = { "$($_.ProfileImagePath)\NTuser.dat" } },
                @{Name = "Path"; Expression = { $_.ProfileImagePath } }
        }

        # If the IncludeDefault switch is set, add the Default profile to the results
        switch ($IncludeDefault) {
            $True {
                $DefaultProfile = "" | Select-Object Username, SID, UserHive, Path
                $DefaultProfile.Username = "Default"
                $DefaultProfile.Domain = $env:COMPUTERNAME
                $DefaultProfile.SID = "DefaultProfile"
                $DefaultProfile.Userhive = "$env:SystemDrive\Users\Default\NTUSER.DAT"
                $DefaultProfile.Path = "$env:SystemDrive\Users\Default"

                $DefaultProfile | Where-Object { $ExcludedUsers -notcontains $_.Username }
            }
        }

        if ($PSVersionTable.PSVersion.Major -lt 3) {
            $AllAccounts = Get-WmiObject -Class "win32_UserAccount"
        } else {
            $AllAccounts = Get-CimInstance -ClassName "win32_UserAccount"
        }

        $CompleteUserProfiles = $UserProfiles | ForEach-Object {
            $SID = $_.SID
            $Win32Object = $AllAccounts | Where-Object { $_.SID -like $SID }

            if ($Win32Object) {
                $Win32Object | Add-Member -NotePropertyName UserHive -NotePropertyValue $_.UserHive
                $Win32Object | Add-Member -NotePropertyName Path -NotePropertyValue $_.Path
                $Win32Object
            } else {
                [PSCustomObject]@{
                    Name     = $_.Username
                    Domain   = $_.Domain
                    SID      = $_.SID
                    UserHive = $_.UserHive
                    Path     = $_.Path
                }
            }
        }

        # Return the list of user profiles, excluding any specified in the ExcludedUsers list
        $CompleteUserProfiles | Where-Object { $ExcludedUsers -notcontains $_.Name }
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

        # Check the ProductType to determine if the system is a domain controller (2) or server (3)
        if (($OS.ProductType -eq "2" -or $OS.ProductType -eq "3") -and $OS.OperatingSystemSku -ne "175") {
            return $true
        }
    }

    #endregion

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    #region Prerequisites
    # Attempt to determine if the current session is running as the SYSTEM account
    try {
        $IsSystem = Test-IsSystem -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$env:USERNAME' is the SYSTEM account."
        exit 1
    }

    # Attempt to determine if this device is a server or domain controller
    try {
        $IsServer = Test-IsServer -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if this device is a server or domain controller."
        exit 1
    }

    if ($IsServer) {
        Write-Host -Object "[Error] This script is supported only on Windows 11 not on servers or domain controllers."
        exit 1
    }
    #endregion

    #region User Profiles
    # Retrieve all user profile registry hives
    try {
        $UserProfiles = Get-UserHive -Type "All" -ErrorAction Stop
        $ProfileWasLoaded = New-Object System.Collections.Generic.List[object]
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve all of the user profiles."
        exit 1
    }

    # If not running as System, filter to the current user only
    if (!$IsSystem) {
        Write-Host -Object "Applying taskbar settings for the current user."
        try {
            $UserProfiles = $UserProfiles | Where-Object { $_.SID -match "$([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)" }
        } catch {
            Write-Host -Object "[Error] Failed to get current user's SID."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    } else {
        Write-Host -Object "Applying taskbar settings for all users."
    }

    if (!$UserProfiles) {
        Write-Host -Object "[Error] No user profiles found."
        exit 1
    }

    # Load any unloaded user registry hives
    foreach ($UserProfile in $UserProfiles) {
        if (!(Test-Path -Path Registry::HKEY_USERS\$($UserProfile.SID) -ErrorAction SilentlyContinue)) {
            try {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg.exe LOAD HKU\$($UserProfile.SID) `"$($UserProfile.UserHive)`"" -Wait -WindowStyle "Hidden" -ErrorAction Stop
                $ProfileWasLoaded.Add($UserProfile)
            } catch {
                Write-Host -Object "[Warning] $($_.Exception.Message)"
                Write-Host -Object "[Warning] Failed to load the registry hive for $($UserProfile.Name)."
            }
        }
    }
    #endregion

    #region Apply Settings
    # Apply settings for each user
    foreach ($UserProfile in $UserProfiles) {
        Write-Host -Object "`nSetting taskbar settings for user '$($UserProfile.Name)'."
        $AdvancedPath = "Registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        $SearchPath = "Registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Search"

        # Taskbar Alignment
        if ($TaskbarAlignment) {
            $AlignmentValue = switch ($TaskbarAlignment) {
                "Left" { 0 }
                "Center" { 1 }
            }

            try {
                $Result = Set-RegKey -Path $AdvancedPath -Name "TaskbarAl" -Value $AlignmentValue -ErrorAction Stop
                switch ($Result.Status) {
                    "AlreadySet" {
                        Write-Host -Object "Taskbar alignment is already set to '$TaskbarAlignment' for user '$($UserProfile.Name)'."
                    }
                    "Updated" {
                        Write-Host -Object "Updated '$AdvancedPath\TaskbarAl' from '$($Result.PreviousValue)' to '$AlignmentValue'."
                    }
                    "CreatedRegKey" {
                        Write-Host -Object "Set '$AdvancedPath\TaskbarAl' to '$AlignmentValue'."
                    }
                    default {
                        Write-Host -Object "[Warning] Unexpected status '$($Result.Status)' when setting taskbar alignment for user '$($UserProfile.Name)'."
                    }
                }
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to set taskbar alignment for user '$($UserProfile.Name)'."
                $ExitCode = 1
            }
        }

        # Auto-hide Taskbar (binary modification of StuckRects3\Settings byte[8])
        if ($AutoHideTaskbar) {
            $AutoHideDesiredByte = switch ($AutoHideTaskbar) {
                "Enable" { 3 }
                "Disable" { 2 }
            }

            $StuckRectsPath = "Registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
            $CurrentSettings = $null
            try {
                $CurrentSettings = (Get-ItemProperty -Path $StuckRectsPath -Name Settings -ErrorAction Stop).Settings
            } catch {
                Write-Host -Object "[Warning] Unable to read taskbar auto-hide settings for user '$($UserProfile.Name)'. The user may not have logged in yet. Skipping auto-hide for this user."
            }

            if ($null -ne $CurrentSettings -and $CurrentSettings.Length -ge 9) {
                if ($CurrentSettings[8] -eq $AutoHideDesiredByte) {
                    $AutoHideState = if ($AutoHideTaskbar -eq "Enable") { "enabled" } else { "disabled" }
                    Write-Host -Object "Auto-hide taskbar is already $AutoHideState for user '$($UserProfile.Name)'."
                } else {
                    $PreviousByte = $CurrentSettings[8]
                    $CurrentSettings[8] = $AutoHideDesiredByte
                    try {
                        Set-ItemProperty -Path $StuckRectsPath -Name Settings -Value $CurrentSettings -ErrorAction Stop
                        Write-Host -Object "Updated '$StuckRectsPath\Settings' byte[8] from '$PreviousByte' to '$AutoHideDesiredByte'."
                    } catch {
                        Write-Host -Object "[Error] $($_.Exception.Message)"
                        Write-Host -Object "[Error] Failed to set auto-hide taskbar for user '$($UserProfile.Name)'."
                        $ExitCode = 1
                    }
                }
            } elseif ($null -ne $CurrentSettings) {
                Write-Host -Object "[Warning] Taskbar settings data is invalid or too short for user '$($UserProfile.Name)'. Skipping auto-hide for this user."
            }
        }

        # Search Button
        if ($SearchButton) {
            $SearchValue = switch ($SearchButton) {
                "Hide" { 0 }
                "Search Icon Only" { 1 }
                "Search Icon and Label" { 2 }
                "Search Box" { 3 }
            }

            try {
                $Result = Set-RegKey -Path $SearchPath -Name "SearchboxTaskbarMode" -Value $SearchValue -ErrorAction Stop
                switch ($Result.Status) {
                    "AlreadySet" {
                        Write-Host -Object "Search button is already set to '$SearchButton' for user '$($UserProfile.Name)'."
                    }
                    "Updated" {
                        Write-Host -Object "Updated '$SearchPath\SearchboxTaskbarMode' from '$($Result.PreviousValue)' to '$SearchValue'."
                    }
                    "CreatedRegKey" {
                        Write-Host -Object "Set '$SearchPath\SearchboxTaskbarMode' to '$SearchValue'."
                    }
                    default {
                        Write-Host -Object "[Warning] Unexpected status '$($Result.Status)' when setting search button for user '$($UserProfile.Name)'."
                    }
                }
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to set search button for user '$($UserProfile.Name)'."
                $ExitCode = 1
            }
        }

        # Task View Button
        if ($TaskViewButton) {
            $TaskViewValue = switch ($TaskViewButton) {
                "Show" { 1 }
                "Hide" { 0 }
            }

            try {
                $Result = Set-RegKey -Path $AdvancedPath -Name "ShowTaskViewButton" -Value $TaskViewValue -ErrorAction Stop
                switch ($Result.Status) {
                    "AlreadySet" {
                        Write-Host -Object "Task View button is already set to '$TaskViewButton' for user '$($UserProfile.Name)'."
                    }
                    "Updated" {
                        Write-Host -Object "Updated '$AdvancedPath\ShowTaskViewButton' from '$($Result.PreviousValue)' to '$TaskViewValue'."
                    }
                    "CreatedRegKey" {
                        Write-Host -Object "Set '$AdvancedPath\ShowTaskViewButton' to '$TaskViewValue'."
                    }
                    default {
                        Write-Host -Object "[Warning] Unexpected status '$($Result.Status)' when setting Task View button for user '$($UserProfile.Name)'."
                    }
                }
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to set Task View button for user '$($UserProfile.Name)'."
                $ExitCode = 1
            }
        }

        # Widgets Button
        if ($WidgetsButton) {
            $WidgetsValue = switch ($WidgetsButton) {
                "Show" { 1 }
                "Hide" { 0 }
            }

            try {
                $Result = Set-RegKey -Path $AdvancedPath -Name "TaskbarDa" -Value $WidgetsValue -ErrorAction Stop
                switch ($Result.Status) {
                    "AlreadySet" {
                        Write-Host -Object "Widgets button is already set to '$WidgetsButton' for user '$($UserProfile.Name)'."
                    }
                    "Updated" {
                        Write-Host -Object "Updated '$AdvancedPath\TaskbarDa' from '$($Result.PreviousValue)' to '$WidgetsValue'."
                    }
                    "CreatedRegKey" {
                        Write-Host -Object "Set '$AdvancedPath\TaskbarDa' to '$WidgetsValue'."
                    }
                    default {
                        Write-Host -Object "[Warning] Unexpected status '$($Result.Status)' when setting Widgets button for user '$($UserProfile.Name)'."
                    }
                }
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to set Widgets button for user '$($UserProfile.Name)'."
                $ExitCode = 1
            }
        }
    }

    Write-Host -Object "`nFinished applying taskbar settings."
    #endregion

    #region Unload User Hives
    # Unload user hives that were loaded by this script
    if ($ProfileWasLoaded.Count -gt 0) {
        foreach ($UserProfile in $ProfileWasLoaded) {
            [gc]::Collect()
            Start-Sleep 1
            try {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg.exe UNLOAD HKU\$($UserProfile.SID)" -Wait -WindowStyle Hidden -ErrorAction Stop | Out-Null
            } catch {
                Write-Host -Object "[Warning] $($_.Exception.Message)"
                Write-Host -Object "[Warning] Failed to unload the registry hive for $($UserProfile.Name)."
            }
        }
    }
    #endregion

    #region Restart Explorer
    if ($RestartExplorer -and $ExitCode -eq 0) {
        Write-Host "`nRestarting Explorer.exe as requested."

        try {
            Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction Stop
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to stop Explorer.exe."
            $ExitCode = 1
        }

        Start-Sleep -Seconds 1

        if (!($IsSystem) -and !(Get-Process -Name "explorer" -ErrorAction SilentlyContinue)) {
            try {
                Start-Process -FilePath "$env:SYSTEMROOT\explorer.exe" -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to start Explorer.exe."
                $ExitCode = 1
            }
        }
    } elseif ($WidgetsButton) {
        Write-Host -Object "[Warning] You may need to restart Explorer.exe for widget changes to take effect immediately."
    }
    #endregion

    exit $ExitCode
}
end {
    
    
    
}
