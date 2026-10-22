#Requires -Version 5.1

<#
.SYNOPSIS
    Generates a Wireless LAN report and optionally saves it to a WYSIWYG Custom Field. Location Services must be enabled for this script to work. Only the English language is supported.
.DESCRIPTION
    Generates a Wireless LAN report and optionally saves it to a WYSIWYG Custom Field. Location Services must be enabled for this script to work. Only the English language is supported.

.PARAMETER EnableLocationServicesTemporarily
    If Location Services is disabled, this parameter will attempt to enable it temporarily while this script runs.
    Location Services will be set back to its original value when the script completes.
.PARAMETER WYSIWYGCustomFieldName
    Enter the name of a WYSIWYG Custom Field to populate with the report.

.EXAMPLE
    -WYSIWYGCustomFieldName "wlanreport"

    ### Wi-Fi Adapters ###

    Interface      : Wi-Fi
    Description    : MediaTek Wi-Fi 6 MT7921 Wireless LAN Card
    SSID           : HomeNetwork
    Authentication : WPA3-Personal
    Band           : 5 GHz
    Channel        : 136
    Signal         : 90%
    State          : connected
    RadioType      : 802.11ax

    ### Other Wi-Fi Networks ###

    SSID                             Authentication Band    Channel Signal
    ----                             -------------- ----    ------- ------
    ATT2zg7uj3                       WPA2-Personal  2.4 GHz 11      24%
    Hidden Network                   WPA3-Personal  5 GHz   44      9%
    Hidden Network                   Open           2.4 GHz 6       54%
    ATT3Mmd8tz                       WPA2-Personal  2.4 GHz 6       27%
    NETGEAR14                        WPA2-Personal  2.4 GHz 1       63%

    [Info] Attempting to set the WYSIWYG custom field 'wlanreport'.
    [Info] Successfully set the WYSIWYG custom field 'wlanreport'!

.EXAMPLE
    -EnableLocationServicesTemporarily

    [Info] Attempting to enable Location Services for the system temporarily.
    [Info] Successfully enabled Location Services for the system.

    ### Wi-Fi Adapters ###

    Interface      : Wi-Fi
    Description    : MediaTek Wi-Fi 6 MT7921 Wireless LAN Card
    SSID           : HomeNetwork
    Authentication : WPA3-Personal
    Band           : 5 GHz
    Channel        : 136
    Signal         : 89%
    State          : connected
    RadioType      : 802.11ax

    ### Other Wi-Fi Networks ###

    SSID                             Authentication Band    Channel Signal
    ----                             -------------- ----    ------- ------
    ATT2zg7uj3                       WPA2-Personal  2.4 GHz 11      24%
    Hidden Network                   WPA3-Personal  5 GHz   44      9%
    Hidden Network                   Open           2.4 GHz 6       54%
    ATT3Mmd8tz                       WPA2-Personal  2.4 GHz 6       27%
    NETGEAR14                        WPA2-Personal  2.4 GHz 1       63%

    [Info] Attempting to set Location Services back to its original value 'Deny'.
    [Info] Successfully set Location Services back to its original value.

.NOTES
    Minimum OS Architecture Supported: Windows 10
    Version: 2.0
    Release Notes: Brought up to standards, added option to enable Location Services temporarily, updated WYSIWYG styling, improved error handling.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $WYSIWYGCustomFieldName,
    [Parameter()]
    [Switch]
    $EnableLocationServicesTemporarily = [System.Convert]::ToBoolean($env:enableLocationServicesTemporarily)
)

begin {
    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Import script variable
    if ($env:wysiwygCustomFieldName) { $WYSIWYGCustomFieldName = $env:wysiwygCustomFieldName }

    # Validate the WYSIWYG custom field name if provided
    if ($WYSIWYGCustomFieldName) {
        # Trim the field name to remove leading and trailing whitespace
        $WYSIWYGCustomFieldName = $WYSIWYGCustomFieldName.Trim()

        # Validate that the field is not just whitespace
        if ([string]::IsNullOrWhiteSpace($WYSIWYGCustomFieldName)) {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' parameter contains only spaces. Please provide a valid field name or leave it blank."
            exit 1
        }

        # Validate that the field name contains only alphanumeric characters
        if ($WYSIWYGCustomFieldName -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' of '$WYSIWYGCustomFieldName' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid WYSIWYG custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Function to retrieve the list of Wi-Fi adapters and their details
    function Get-WiFiAdapters {
        [CmdletBinding()]
        param()

        # Run the netsh command to get the list of Wi-Fi adapters and capture the output as a single string
        $NetShOutput = netsh.exe wlan show interfaces | Out-String

        # Error if the command fails
        if ($LASTEXITCODE -ne 0) {
            throw "$NetShOutput"
        }

        # Split the output into separate adapter objects, skipping the first split which is not a adapter object
        $AdapterObjects = $NetShOutput -split "\r\n\r\n" | Select-Object -Skip 1 | Where-Object { $_ }

        foreach ($AdapterObject in $AdapterObjects) {
            # Initialize the variables for extracted information to null
            $Interface = $null
            $State = $null
            $Description = $null
            $SSID = $null
            $Authentication = $null
            $Band = $null
            $Channel = $null
            $Signal = $null
            $RadioType = $null

            # Split the adapter object into lines and trim whitespace
            $ObjectLines = ($AdapterObject -split "\r\n").Trim()

            # Extract the relevant information from the adapter object
            $Interface = (($ObjectLines | Select-String "^Name") -split ":", 2 | Select-Object -Last 1).Trim()
            $State = (($ObjectLines | Select-String "^State") -split ":", 2 | Select-Object -Last 1).Trim()
            $Description = (($ObjectLines | Select-String "^Description") -split ":", 2 | Select-Object -Last 1).Trim()

            # If the adapter is connected, extract additional information
            if ($State -eq "connected") {
                $SSID = (($ObjectLines | Select-String "^SSID") -split ":", 2 | Select-Object -Last 1).Trim()
                $Authentication = (($ObjectLines | Select-String "^Authentication") -split ":", 2 | Select-Object -Last 1).Trim()
                $Band = (($ObjectLines | Select-String "^Band") -split ":", 2 | Select-Object -Last 1).Trim()
                $Channel = (($ObjectLines | Select-String "^Channel") -split ":", 2 | Select-Object -Index 1).Trim()
                $Signal = (($ObjectLines | Select-String "^Signal") -split ":", 2 | Select-Object -Index 1).Trim()
                $RadioType = (($ObjectLines | Select-String "^Radio type") -split ":", 2 | Select-Object -Index 1).Trim()
            }

            # Output the extracted information as a custom object
            [PSCustomObject]@{
                Interface      = $Interface
                Description    = $Description
                SSID           = $SSID
                Authentication = $Authentication
                Band           = $Band
                Channel        = $Channel
                Signal         = $Signal
                State          = $State
                RadioType      = $RadioType
            }
        }
    }

    # Function to retrieve the list of available Wi-Fi networks and their details
    function Get-WiFiNetworks {
        [CmdletBinding()]
        param()

        # Run the netsh command to get the list of available Wi-Fi networks in BSSID mode and capture the output as a single string
        $NetShOutput = netsh.exe wlan show networks mode=bssid | Out-String

        # Error if the command fails
        if ($LASTEXITCODE -ne 0) {
            throw "$NetShOutput"
        }

        # Split the output into separate network objects, skipping the first split which is not a network object
        $NetworkObjects = $NetShOutput -split "\r\n\r\n" | Select-Object -Skip 1 | Where-Object { $_ }

        # Loop through each network object and extract the relevant information
        foreach ($CurrentNetworkObject in $NetworkObjects) {
            # Split the network object into lines and trim whitespace
            $ObjectLines = ($CurrentNetworkObject -split "\r\n").Trim()

            # Extract the SSID
            $SSID = (($ObjectLines | Select-String "^SSID") -split ":", 2 | Select-Object -Last 1).Trim()

            # If the SSID is empty or consists only of whitespace, set it to "Hidden Network"
            if ([string]::IsNullOrWhiteSpace($SSID)) { $SSID = "Hidden Network" }

            # Extract the Authentication type
            $Authentication = (($ObjectLines | Select-String "^Authentication") -split ":", 2 | Select-Object -Last 1).Trim()

            # If there are multiple BSSIDs associated with this SSID, parse the info from the one with the strongest signal
            # Otherwise, just parse the info from the single BSSID
            if ([regex]::Matches($ObjectLines, "BSSID").Count -gt 1) {
                # Split the BSSIDs into separate objects, skipping the first split which is not a BSSID
                $BSSIDObjects = $CurrentNetworkObject -split "BSSID" | Select-Object -Skip 1

                # Initialize the maximum signal to 0
                $MaximumSignal = 0

                # Loop through each BSSID object to find the one with the strongest signal
                foreach ($CurrentBSSIDObject in $BSSIDObjects) {
                    # Split the BSSID object into lines and trim whitespace
                    $BSSIDObjectLines = ($CurrentBSSIDObject -split "\r\n").Trim()

                    # Extract the signal strength and remove the trailing percentage sign
                    $SignalOfThisBSSID = (($BSSIDObjectLines | Select-String "^Signal") -split ":", 2 | Select-Object -Index 1).Trim().TrimEnd("%")

                    # If the signal strength is a valid integer and greater than the current maximum, update the maximum and extract other details
                    if ($SignalOfThisBSSID -as [int] -and $SignalOfThisBSSID -gt $MaximumSignal) {
                        $MaximumSignal = $SignalOfThisBSSID
                        $Signal = "$MaximumSignal%"
                        $RadioType = (($BSSIDObjectLines | Select-String "^Radio type") -split ":", 2 | Select-Object -Index 1).Trim()
                        $Band = (($BSSIDObjectLines | Select-String "^Band") -split ":", 2 | Select-Object -Index 1).Trim()
                        $Channel = (($BSSIDObjectLines | Select-String "^Channel") -split ":", 2 | Select-Object -Index 1).Trim()
                    }
                }
            }
            else {
                $Signal = (($ObjectLines | Select-String "^Signal") -split ":", 2 | Select-Object -Index 1).Trim()
                $RadioType = (($ObjectLines | Select-String "^Radio type") -split ":", 2 | Select-Object -Index 1).Trim()
                $Band = (($ObjectLines | Select-String "^Band") -split ":", 2 | Select-Object -Index 1).Trim()
                $Channel = (($ObjectLines | Select-String "^Channel") -split ":", 2 | Select-Object -Index 1).Trim()
            }

            # Output the extracted information as a custom object
            [PSCustomObject]@{
                SSID           = $SSID
                Authentication = $Authentication
                Band           = $Band
                Channel        = $Channel
                Signal         = $Signal
                RadioType      = $RadioType
            }
        }
    }

    # Function to retrieve the Wi-Fi radio status (hardware and software)
    function Get-WiFiRadioStatus {
        # Run the netsh command to get the Wi-Fi radio status and capture the output
        $NetShOutput = netsh.exe wlan show interfaces

        # Error if the command fails
        if ($LASTEXITCODE -ne 0) {
            throw "$NetShOutput"
        }

        # Initialize the return object with "Off" values
        $RadioStatus = [PSCustomObject]@{
            Hardware = "Off"
            Software = "Off"
        }

        # If we are connected to a network, then hardware and software radio status must be "On"
        if ($NetShOutput -imatch " connected") {
            $RadioStatus.Hardware = "On"
            $RadioStatus.Software = "On"
            return $RadioStatus
        }

        # Otherwise, parse the hardware and software radio status from the output
        foreach ($Line in $NetShOutput) {
            switch -regex ($Line) {
                "Hardware\s(.*)" { $RadioStatus.Hardware = $Matches[1] }
                "Software\s(.*)" { $RadioStatus.Software = $Matches[1] }
            }

            # If both hardware and software radio status are "On" at any point in the loop, we can stop parsing
            if ($RadioStatus.Hardware -eq "On" -and $RadioStatus.Software -eq "On") { break }
        }

        # Return the status object
        return $RadioStatus
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

    # Attempt to determine if the current session is running as the SYSTEM account.
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

    if ($registryChanged) { Write-Host -Object "" }

    # Determine if the Wi-Fi radios are turned on
    try {
        $RadioStatus = Get-WiFiRadioStatus -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] Unable to determine the Wi-Fi radio status. Command output:"
        Write-Host -Object "$($_.Exception.Message)`n"
        if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
    }

    # If no errors occurred above, but the Wi-Fi is turned off, error out
    if ($ExitCode -ne 1 -and ($RadioStatus.Hardware -ne "On" -or $RadioStatus.Software -ne "On")) {
        Write-Host -Object "[Error] Wi-Fi is turned off. Please enable it in order to run this report."
        if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
    }

    # Only proceed if there were no errors so far
    if ($ExitCode -ne 1) {
        # Retrieve info about the Wi-Fi adapters on the device
        try {
            $WiFiAdapters = Get-WiFiAdapters -ErrorAction Stop
        }
        catch {
            Write-Host -Object "[Error] Unable to retrieve the list of Wi-Fi adapters. Command output:"
            Write-Host -Object "$($_.Exception.Message)"
            if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
        }

        # Error if no Wi-Fi adapters were found
        if ($ExitCode -ne 1 -and -not $WiFiAdapters) {
            Write-Host -Object "[Error] No Wi-Fi adapters found on this device."
            if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
        }
    }

    # If Wi-Fi adapters were found, proceed to get the list of available networks
    if ($WiFiAdapters) {
        # Sort Wi-Fi adapters with the connected adapter on top
        $WiFiAdapters = $WiFiAdapters | Sort-Object { if ($_.State -eq "connected") { 0 } else { 1 } }, Interface

        # Retrieve the list of available Wi-Fi networks
        try {
            $WiFiNetworkList = Get-WiFiNetworks -ErrorAction Stop
        }
        catch {
            Write-Host -Object "[Error] Unable to retrieve the list of available Wi-Fi networks."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            if ($registryChanged) { $ExitCode = 1 } else { exit 1 }
        }

        # Filter out the currently connected SSID from the list of available networks
        if ($WiFiAdapters.State -contains "connected") {
            $ConnectedSSID = ($WiFiAdapters | Where-Object { $_.State -eq "connected" }).SSID
            $WiFiNetworkList = $WiFiNetworkList | Where-Object { $_.SSID -ne $ConnectedSSID }
        }

        # Output the list of Wi-Fi adapters
        Write-Host -Object "### Wi-Fi Adapters ###`n"
        ($WiFiAdapters | Format-List | Out-String).Trim() | Write-Host

        Write-Host -Object ""

        Write-Host -Object "### Other Wi-Fi Networks ###"

        if ($WiFiNetworkList) {
            # Sort the list by SSID
            $WiFiNetworkList = $WiFiNetworkList | Sort-Object -Property SSID

            # Output the list in a table format
            Write-Host -Object ""
            ($WiFiNetworkList | Select-Object -Property SSID, Authentication, Band, Channel, Signal | Format-Table -AutoSize | Out-String).Trim() | Write-Host
        }
        else {
            Write-Host -Object "[Info] No other Wi-Fi networks found."
        }
    }

    # Attempt to set Location Services back to its original value
    if ($EnableLocationServicesTemporarily -and $LocationServicesIsDisabled) {
        try {
            Write-Host -Object "`n[Info] Attempting to set Location Services back to its original value '$LocationServices'."
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
            Write-Host -Object "`n[Info] Attempting to set Location Services for the user back to its original value '$LocationServicesPerUser'."
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
            Write-Host -Object "`n[Info] Attempting to set Location Services for desktop apps back to its original value '$LocationServicesDesktopAppsPerUser'."
            Set-ItemProperty -Path $LocationServicesDesktopAppsPerUserRegistryPath -Name "Value" -Value $LocationServicesDesktopAppsPerUser -ErrorAction Stop
            Write-Host -Object "[Info] Successfully set Location Services for desktop apps for the user '$([environment]::UserName)' back to its original value."
        }
        catch {
            Write-Host -Object "[Error] Failed to set '$LocationServicesDesktopAppsPerUserRegistryPath' for the user '$([environment]::UserName)' back to its original value."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    # If a WYSIWYG custom field name was provided, attempt to set the field with the report
    if ($WYSIWYGCustomFieldName) {
        # Convert the Wi-Fi adapters and Wi-Fi networks list to HTML
        if ($WiFiAdapters) {
            $WiFiAdaptersHTML = $WiFiAdapters | ConvertTo-Html -Fragment
        }
        else {
            $WiFiAdaptersHTML = "<p style='margin-top: 0px;'>No Wi-Fi adapters found.</p>"
        }

        if ($WiFiNetworkList) {
            $WiFiNetworkHTML = $WiFiNetworkList | ConvertTo-Html -Fragment
        }
        else {
            $WiFiNetworkHTML = "<p style='margin-top: 0px;'>No other Wi-Fi networks found.</p>"
        }

        # Build the HTML  report
        $Report = "<div class='card flex-grow-1'>
                        <div class='card-title-box'>
                            <div class='card-title'><i class='fa-solid fa-wifi'></i>&nbsp;&nbsp;Wi-Fi Adapters</div>
                        </div>
                        <div class='card-body' style='padding-bottom: 15px; white-space: nowrap;'>
                            $WiFiAdaptersHTML
                        </div>
                        <div class='card-title-box'>
                            <div class='card-title'><i class='fa-solid fa-signal'></i>&nbsp;&nbsp;Other Wi-Fi Networks</div>
                        </div>
                        <div class='card-body' style='white-space: nowrap;'>
                            $WiFiNetworkHTML
                        </div>
                    </div>"

        # Bold all table headers
        $Report = $Report -replace "<th>", "<th><strong>" -replace "</th>", "</strong></th>"

        # Attempt to set the WYSIWYG custom field with the report
        try {
            Write-Host -Object "`n[Info] Attempting to set the WYSIWYG custom field '$WYSIWYGCustomFieldName'."
            Set-NinjaProperty -Name $WYSIWYGCustomFieldName -Value $Report
            Write-Host -Object "[Info] Successfully set the WYSIWYG custom field '$WYSIWYGCustomFieldName'!"
        }
        catch {
            Write-Host -Object "[Error] Failed to set the WYSIWYG custom field '$WYSIWYGCustomFieldName'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    exit $ExitCode
}
end {
    
    
    
}
