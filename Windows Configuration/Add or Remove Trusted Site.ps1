#Requires -Version 5.1

<#
.SYNOPSIS
    Manages trusted sites in Internet Explorer and Edge by adding, removing, or listing HTTPS URLs in specified trust zones.
.DESCRIPTION
    Manages trusted sites in Internet Explorer and Edge by adding, removing, or listing HTTPS URLs in specified trust zones.
.EXAMPLE
    -Action "Add" -URL "https://*.ninjaone.com" -TrustZone "Trusted Sites"

    Parsing the domain, subdomain, and range information.
    Gathering user profiles.

    ### Configuring the URL 'https://*.ninjaone.com' for Administrator ###
    Created 'Registry::HKEY_USERS\S-1-5-21-745448846-3964690785-1211766275-500\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\ninjaone.com\https' with the value '2'.

    ### Internet Trust Zones ###

    Site                       TrustZone      User          Domain
    ----                       ---------      ----          ------
    https://*.example.test.com Local Intranet Administrator WIN11-TEST
    https://*.ninjaone.com     Trusted Sites  Administrator WIN11-TEST

.PARAMETER Action
    Specify whether you would like to add or remove a site from a trust zone, or list the current trust zones.

.PARAMETER URL
    Enter the URL you would like to add or remove from a trust zone, or filter the list of sites by.

.PARAMETER TrustZone
    Select the trust zone you would like to add or remove the site from, or filter the list of sites by.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$Action = $env:action,
    [Parameter()]
    [String]$URL = $env:url,
    [Parameter()]
    [String]$TrustZone = $env:trustZone
)

begin {
    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    #region Validation
    # Define valid actions for the script
    $ValidActions = "Add", "Remove", "List"

    # Validate that an action was provided
    if ([String]::IsNullOrWhiteSpace($Action)) {
        Write-Host -Object "[Error] You must provide a valid action. Valid actions include: $($ValidActions -join ", ")."
        exit 1
    }

    # Remove leading/trailing whitespace from the action
    $Action = $Action.Trim()

    # Verify the action is one of the valid options
    if ($ValidActions -notcontains $Action) {
        Write-Host -Object "[Error] An invalid action '$Action' was provided. Valid actions include: $($ValidActions -join ", ")."
        exit 1
    }

    # For Add or Remove actions, ensure both URL and TrustZone are provided
    if ($Action -ne "List") {
        if ([String]::IsNullOrWhiteSpace($URL)) {
            Write-Host -Object "[Error] You must provide a valid URL to add or remove a site from a trust zone."
            exit 1
        }

        if ([String]::IsNullOrWhiteSpace($TrustZone)) {
            Write-Host -Object "[Error] You must provide a valid trust zone to add or remove a site from."
            exit 1
        }
    }

    # Validate the URL format if one is provided
    if ($URL) {
        if ([String]::IsNullOrWhiteSpace($URL)) {
            Write-Host -Object "[Error] You must provide a URL that is more than whitespace."
            exit 1
        }

        # Remove leading/trailing whitespace
        $URL = $URL.Trim()

        # Reject HTTP URLs (only HTTPS allowed)
        if ($URL -match "^http" -and $URL -notmatch "^https") {
            Write-Host -Object "[Error] The URL you have provided does not use HTTPS. Please specify an HTTPS URL."
            exit 1
        }

        # Auto-prepend https:// if missing
        if ($URL -notmatch "^https" -and $URL -notmatch "://") {
            $URL = "https://$URL"
            Write-Host -Object "[Warning] The URL you provided does not contain 'https'. Your URL will be updated to '$URL'."
        }

        # Final validation that URL is HTTPS
        if ($URL -notmatch "^https://") {
            Write-Host -Object "[Error] The URL you provided '$URL' is invalid. Only HTTPS sites are supported by this script."
            exit 1
        }

        # Validate wildcard usage (only for subdomains, max one wildcard)
        if ($URL -notmatch "https://(\d+|\*)\.(\d+|\*)\.(\d+|\*)\.(\d+|\*)$") {
            if ($URL -match "\*.*\*") {
                Write-Host -Object "[Error] The URL you provided '$URL' is invalid. It contains too many wildcards."
                exit 1
            }

            if ($URL -match "[*]" -and ($URL -notmatch "\*\." -or $URL -match "\.\*")) {
                Write-Host -Object "[Error] The URL you provided '$URL' is invalid. It contains an invalid wildcard pattern. Wildcards can only be used for subdomains."
                exit 1
            }
        }
    }

    # Define valid trust zones
    $ValidTrustZones = "Local Intranet", "Trusted Sites", "Restricted Sites"

    # Validate the trust zone if one is provided
    if ($TrustZone) {
        if ([String]::IsNullOrWhiteSpace($TrustZone)) {
            Write-Host -Object "[Error] You must provide a trust zone that is more than whitespace. Valid trust zones include: $($ValidTrustZones -join ", ")."
            exit 1
        }

        # Remove leading/trailing whitespace
        $TrustZone = $TrustZone.Trim()

        # Verify the trust zone is one of the valid options
        if ($ValidTrustZones -notcontains $TrustZone) {
            Write-Host -Object "[Error] The trust zone you provided '$TrustZone' is invalid. Valid trust zones include: $($ValidTrustZones -join ", ")."
            exit 1
        }
    }
    #endregion
    #region Helper Functions
    function Get-TrustZoneSites {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $True)]
            [Object[]]$UserProfiles
        )

        $TrustedSites = New-Object -TypeName System.Collections.Generic.List[object]
        $TrustZones = @(
            [PSCustomObject]@{ Name = "Local Intranet"; Value = 1 }
            [PSCustomObject]@{ Name = "Trusted Sites"; Value = 2 }
            [PSCustomObject]@{ Name = "Restricted Sites"; Value = 4 }
        )

        foreach ($UserProfile in $UserProfiles) {
            $DomainKeys = Get-ChildItem -Path "Registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains"
            foreach ($DomainKey in $DomainKeys) {
                $Domain = $DomainKey.Name -replace "^.*\\"

                $DomainKeyProperties = $DomainKey | Get-ItemProperty
                if ($DomainKeyProperties.https) {
                    $TrustZoneName = $TrustZones | Where-Object { $_.Value -eq $DomainKeyProperties.https } | Select-Object -ExpandProperty Name
                    [PSCustomObject]@{
                        Site      = "https://*.$Domain"
                        TrustZone = $TrustZoneName
                        User      = $UserProfile.Name
                        Domain    = $UserProfile.Domain
                    }

                    continue
                }

                $SubdomainKeys = $DomainKey | Get-ChildItem
                foreach ($SubdomainKey in $SubdomainKeys) {
                    $Subdomain = $SubdomainKey.Name -replace "^.*\\"

                    $SubdomainProperties = $SubdomainKey | Get-ItemProperty
                    if ($SubdomainProperties.https) {
                        $TrustZoneName = $TrustZones | Where-Object { $_.Value -eq $SubdomainProperties.https } | Select-Object -ExpandProperty Name

                        [PSCustomObject]@{
                            Site      = "https://$Subdomain.$Domain"
                            TrustZone = $TrustZoneName
                            User      = $UserProfile.Name
                            Domain    = $UserProfile.Domain
                        }
                    }
                }
            }

            $RangeKeys = Get-ChildItem -Path "Registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Ranges"
            foreach ($RangeKey in $RangeKeys) {
                $RangeProperties = $RangeKey | Get-ItemProperty
                $TrustZoneName = $TrustZones | Where-Object { $_.Value -eq $RangeProperties.https } | Select-Object -ExpandProperty Name

                [PSCustomObject]@{
                    Site      = "https://$($RangeProperties.":Range")"
                    TrustZone = $TrustZoneName
                    User      = $UserProfile.Name
                    Domain    = $UserProfile.Domain
                }
            }
        }
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
                # If the path does not exist, create it
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
                    # Update the registry key with the new value
                    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -Confirm:$false -ErrorAction Stop | Out-Null
                    $Status.Add("Updated")
                } catch {
                    throw $_
                }
            }
        } else {
            try {
                # If the registry key does not exist, create it with the specified value and property type
                New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force -Confirm:$false -ErrorAction Stop | Out-Null
                $Status.Add("CreatedRegKey")
            } catch {
                throw $_
            }
        }

        # Output will be the registry key and its value
        try {
            $output = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        } catch {
            throw $_
        }

        # Add previous value to the output object
        $output | Add-Member -MemberType NoteProperty -Name "PreviousValue" -Value $previousValue
        # Add status to the output object
        $output | Add-Member -MemberType NoteProperty -Name "Status" -Value $Status
        return $output
    }

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

                # Exclude users specified in the ExcludedUsers list
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

    #region Parse Domain/Range
    # Parse the URL to extract domain, subdomain, or IP range information
    if ($URL) {
        Write-Host -Object "Parsing the domain, subdomain, and range information."
        $WithoutHTTPS = $URL -replace "https://"

        # Check if the URL is an IP range (e.g., 192.168.1.1)
        if ($WithoutHTTPS -match "^(\d+|\*)\.(\d+|\*)\.(\d+|\*)\.(\d+|\*)$") {
            $DesiredRange = $WithoutHTTPS
        } else {
            # Extract domain and subdomain from the URL
            if ($WithoutHTTPS -match "([^.]+\.[^.]+)$") {
                $Domain = $matches[1] # Extract the domain (e.g., example.com)
                $Subdomain = $WithoutHTTPS -replace "\.?$Domain$", "" # Extract subdomains (e.g., sub)
                if ($Subdomain -eq "*") { $Subdomain = $null } # Clear subdomain if it's just a wildcard
            } else {
                $Domain = $WithoutHTTPS -replace "\*\." # Remove wildcard from domain
                $Subdomain = $null
            }
        }
    }

    # Retrieve all user profiles on the system
    try {
        Write-Host -Object "Gathering user profiles."
        $UserProfiles = Get-UserHive -Type "All" -ErrorAction Stop
        $ProfileWasLoaded = New-Object System.Collections.Generic.List[object]
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to gather all user profiles."
        exit 1
    }

    # Load user registry hives that aren't currently in memory
    foreach ($UserProfile in $UserProfiles) {
        if (!(Test-Path -Path Registry::HKEY_USERS\$($UserProfile.SID) -ErrorAction SilentlyContinue)) {
            try {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg.exe LOAD HKU\$($UserProfile.SID) `"$($UserProfile.UserHive)`"" -Wait -WindowStyle Hidden -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to load HKU\$($UserProfile.SID)."
                exit 1
            }
            $ProfileWasLoaded.Add($UserProfile)
        }
    }

    # Map the trust zone name to its registry value
    switch ($TrustZone) {
        "Local Intranet" { $RegistryValue = 1 }
        "Trusted Sites" { $RegistryValue = 2 }
        "Restricted Sites" { $RegistryValue = 4 }
    }

    # Retrieve and display existing trust zone entries if listing or removing
    if ($Action -eq "List" -or $Action -eq "Remove") {
        Write-Host -Object "Gathering domains and ranges from trust zones."

        try {
            $TrustedSites = Get-TrustZoneSites -UserProfiles $UserProfiles -ErrorAction Stop
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to retrieve the Internet trust zone information for all users."
            exit 1
        }

        # Handle the List action
        if ($Action -eq "List") {
            # Filter results by URL if provided
            if ($URL) {
                Write-Host -Object "Filtering list to only display entries that contain '$URL'."
                $TrustedSites = $TrustedSites | Where-Object { $_.Site -eq $URL }
            }

            # Filter results by trust zone if provided
            if ($TrustZone) {
                Write-Host -Object "Filtering list to only display entries that contain '$TrustZone'."
                $TrustedSites = $TrustedSites | Where-Object { $_.TrustZone -eq $TrustZone }
            }

            # Display results or message if no sites found
            if ($TrustedSites) {
                Write-Host -Object "`n### Internet Trust Zones ###"
                $TrustedSites | Sort-Object User | Format-Table -AutoSize
            } else {
                if ($URL -or $TrustZone) {
                    Write-Host -Object "`nThere are no sites matching your criteria in the trust zone list."
                } else {
                    Write-Host -Object "`nThere are no sites currently assigned to a trust zone."
                }
            }

            exit $ExitCode
        }
    }
    #endregion

    #region Add or Remove
    # Iterate through each user profile to apply the trust zone configuration
    foreach ($UserProfile in $UserProfiles) {
        Write-Host -Object "`n### Configuring the URL '$URL' for $($UserProfile.Name) ###"
        try {
            # For Remove action, check if the site exists in the specified trust zone
            if ($Action -eq "Remove" -and $TrustZone) {
                $SiteToRemove = $TrustedSites | Where-Object { $_.User -eq $UserProfile.Name -and
                    $_.Domain -eq $UserProfile.Domain -and $_.Site -eq $URL -and $_.TrustZone -eq $TrustZone }

                # Skip if the URL is not found in the trust zone (already removed)
                if (!$SiteToRemove) {
                    Write-Host -Object "This URL has already been removed from the trust zone '$TrustZone' for this user."
                    continue
                }
            }

            # Construct the base registry path for Internet Settings ZoneMap
            $BasePath = "Registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap"

            # Build the registry path for domain entries
            if ($Domain) {
                $RegistryPath = "$BasePath\Domains\$Domain"
                # Add subdomain to the path if present
                if ($Subdomain) {
                    $RegistryPath = "$RegistryPath\$Subdomain"
                }
            }

            # Handle IP range entries
            if ($DesiredRange) {
                $i = 1
                $CurrentRanges = Get-ChildItem -Path "$BasePath\Ranges" -ErrorAction SilentlyContinue

                # Search for an existing range entry matching the desired range
                foreach ($Range in $CurrentRanges) {
                    $Properties = $Range | Get-ItemProperty -ErrorAction Stop

                    if ($Properties.":Range" -eq $DesiredRange) {
                        $RegistryPath = $Range.PSPath -replace "Microsoft\.PowerShell\.Core\\"
                        continue
                    }
                    $i++
                }

                # If no existing range found, create a new Range entry
                if (!$RegistryPath) {
                    $RegistryPath = "$BasePath\Ranges\Range$i"
                }
            }

            # Execute Add or Remove action on the registry
            switch ($Action) {
                "Add" {
                    # Set the https registry value for the domain/subdomain
                    $SiteAdd = Set-RegKey -Path $RegistryPath -Name "https" -Value $RegistryValue -ErrorAction Stop
                    # If dealing with IP range, also set the :Range value
                    if ($DesiredRange) {
                        $RangeAdd = Set-RegKey -Path $RegistryPath -Name ":Range" -Value $DesiredRange -PropertyType "String" -ErrorAction Stop
                    }
                }
                "Remove" {
                    # Remove the registry key if it exists, otherwise mark as already removed
                    if (!(Test-Path -Path $RegistryPath -ErrorAction SilentlyContinue)) {
                        $SiteAdd = [PSCustomObject]@{ Status = "AlreadyRemoved" }
                    } else {
                        Remove-Item -Path $RegistryPath -ErrorAction Stop
                        # Clean up parent domain key if no subdomains remain
                        if ($Subdomain) {
                            Remove-Item -Path "$BasePath\Domains\$Domain" -ErrorAction Stop
                        }

                        $SiteAdd = [PSCustomObject]@{ Status = "Removed" }
                    }
                }
            }
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to set the registry key at '$RegistryPath'"
            exit 1
        }

        # Display status messages for the https registry operation
        switch ($SiteAdd.Status) {
            "AlreadyRemoved" { Write-Host -Object "The registry key '$RegistryPath' was already removed." }
            "Removed" { Write-Host -Object "The registry key '$RegistryPath' was successfully removed." }
            "AlreadySet" { Write-Host -Object "The trust zone registry key was already set to the value '$RegistryValue' at '$RegistryPath\https'." }
            "Updated" { Write-Host -Object "Updated '$RegistryPath\https' from '$($SiteAdd.PreviousValue)' to '$RegistryValue'." }
            "CreatedRegKey" { Write-Host -Object "Created '$RegistryPath\https' with the value '$RegistryValue'." }
        }

        # Display status messages for the range registry operation (if applicable)
        switch ($RangeAdd.Status) {
            "AlreadyRemoved" { Write-Host -Object "The registry key '$RegistryPath' was already removed." }
            "Removed" { Write-Host -Object "The registry key '$RegistryPath' was successfully removed." }
            "AlreadySet" { Write-Host -Object "The range registry key was already set to the value '$DesiredRange' at '$RegistryPath\:Range'." }
            "Updated" { Write-Host -Object "Updated '$RegistryPath\:Range' from '$($RangeAdd.PreviousValue)' to '$DesiredRange'." }
            "CreatedRegKey" { Write-Host -Object "Created '$RegistryPath\:Range' with the value '$DesiredRange'." }
        }
    }

    # Unload any user registry hives that were loaded during script execution
    if ($ProfileWasLoaded.Count -gt 0) {
        foreach ($UserProfile in $ProfileWasLoaded) {
            # Force garbage collection and wait before unloading the registry hive
            [gc]::Collect()
            Start-Sleep 1
            try {
                # Unload the user's NTuser.dat registry hive
                Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg.exe UNLOAD HKU\$($UserProfile.SID)" -Wait -WindowStyle Hidden -ErrorAction Stop | Out-Null
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to unload HKU\$($UserProfile.SID)."
                $ExitCode = 1
            }
        }
    }

    #endregion
    #region Re-List Trust Info

    # Retrieve all trust zone sites configured across all user profiles
    try {
        $TrustedSites = Get-TrustZoneSites -UserProfiles $UserProfiles -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve the trust zone information for all users."
        exit 1
    }

    # Display the retrieved trust zone sites or a message if none exist
    if ($TrustedSites) {
        Write-Host -Object "`n### Internet Trust Zones ###"
        # Sort by user and display in table format
        $TrustedSites | Sort-Object User | Format-Table -AutoSize
    } else {
        # Notify user if no sites are configured in any trust zone
        Write-Host -Object "`nThere are no sites currently assigned to a trust zone."
    }
    #endregion

    exit $ExitCode
}
end {
    
    
    
}