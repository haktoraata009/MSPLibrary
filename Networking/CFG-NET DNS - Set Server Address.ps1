#Requires -Version 5.1

<#
.SYNOPSIS
    Set or modify the IPv4 DNS servers of a specified active network adapter. If no adapter is specified, the script will attempt to modify the active adapter.
.DESCRIPTION
    Set or modify the IPv4 DNS servers of a specified active network adapter. If no adapter is specified, the script will attempt to modify the active adapter.

.PARAMETER -ListNetworkAdapters
    List all active/connected network adapters. If this is selected, the script will ignore any other parameters.
.PARAMETER -Region
    Select your region. This is required if specifying IP addresses for the primary and secondary DNS servers. Valid options are NA, CA, U2, EU, and OC.
.PARAMETER -NetworkAdapter "Ethernet"
    Enter the alias  or index of the network adapter to modify. If not specified, the script will attempt to modify the active adapter.
.PARAMETER -PrimaryDNSIP "1.1.1.1"
    Enter the IP address of the primary DNS server.
.PARAMETER -SecondaryDNSIP "8.8.8.8"
    Enter the IP address of the secondary DNS server.
.PARAMETER -ResetToAutomatic
    Check this box to reset the DNS server settings to automatic.

.EXAMPLE
    -ListNetworkAdapters

    InterfaceAlias              InterfaceIndex ConnectionState DNSServers
    --------------              -------------- --------------- ----------
    Ethernet                                14       Connected 192.168.176.1

.EXAMPLE
    -NetworkAdapter "Ethernet" -Region "NA" -PrimaryDNSIP "8.8.8.8" -SecondaryDNSIP "1.1.1.1"

    [Info] Using the network adapter with alias 'Ethernet' and index '14'.

    [Info] Setting the DNS servers for the network adapter 'Ethernet' to '8.8.8.8, 1.1.1.1'...
    [Info] The DNS servers for the network adapter 'Ethernet' have been set to '8.8.8.8, 1.1.1.1'.

    ### Previous DNS server configuration: ###

    InterfaceAlias InterfaceIndex PrimaryDNSServer SecondaryDNSServer AutomaticDNS
    -------------- -------------- ---------------- ------------------ ------------
    Ethernet                   14 192.168.176.1                               True

    ### Current DNS server configuration: ###

    InterfaceAlias InterfaceIndex PrimaryDNSServer SecondaryDNSServer AutomaticDNS
    -------------- -------------- ---------------- ------------------ ------------
    Ethernet                   14 8.8.8.8          1.1.1.1                   False

.EXAMPLE
    -NetworkAdapter "Ethernet" -ResetToAutomatic

    [Info] Using the network adapter with alias 'Ethernet' and index '14'.

    [Info] Resetting DNS server addresses for the network adapter 'Ethernet' to automatic...
    [Info] DNS server addresses for the network adapter 'Ethernet' have been reset to automatic.

    ### Previous DNS server configuration: ###

    InterfaceAlias InterfaceIndex PrimaryDNSServer SecondaryDNSServer AutomaticDNS
    -------------- -------------- ---------------- ------------------ ------------
    Ethernet                   14 8.8.8.8          1.1.1.1                   False

    ### Current DNS server configuration: ###

    InterfaceAlias InterfaceIndex PrimaryDNSServer SecondaryDNSServer AutomaticDNS
    -------------- -------------- ---------------- ------------------ ------------
    Ethernet                   14 192.168.176.1                               True

.NOTES
    Minimum OS Architecture Supported: Windows 10
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [switch]$ListNetworkAdapters = [System.Convert]::ToBoolean($env:ListNetworkAdapters),
    [Parameter()]
    [string]$Region,
    [Parameter()]
    [string]$NetworkAdapter,
    [Parameter()]
    [string]$PrimaryDNSIP,
    [Parameter()]
    [string]$SecondaryDNSIP,
    [Parameter()]
    [switch]$ResetToAutomatic = [System.Convert]::ToBoolean($env:ResetToAutomatic)
)

begin {
    # Check if the operating system build version is less than 10240 (Windows 10) minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Import the script variables
    if ($env:Region) { $Region = $env:Region }
    if ($env:NetworkAdapter) { $NetworkAdapter = $env:NetworkAdapter }
    if ($env:PrimaryDNSIP) { $PrimaryDNSIP = $env:PrimaryDNSIP }
    if ($env:SecondaryDNSIP) { $SecondaryDNSIP = $env:SecondaryDNSIP }

    # Function to test if this script is running on a server OS
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

    # Error if a server OS is detected
    if (Test-IsServer) {
        Write-Host -Object "[Error] This script is not supported on server operating systems. Only workstations are supported."
        exit 1
    }

    # Warn if the user is trying to list network adapters while also providing DNS settings
    if ($ListNetworkAdapters -and ($Region -or $NetworkAdapter -or $PrimaryDNSIP -or $SecondaryDNSIP -or $ResetToAutomatic)) {
        Write-Host -Object "[Warning] The 'List Network Adapters' option is selected, but other settings are also provided. The script will only list the active network adapters and will not modify any DNS settings."
        $Region = $null
        $NetworkAdapter = $null
        $PrimaryDNSIP = $null
        $SecondaryDNSIP = $null
        $ResetToAutomatic = $null
    }

    # Validate the region if provided
    if ($Region) {
        $Region = $Region.Trim()

        $SupportedRegions = @("NA", "US2", "EU", "CA", "OC")

        if ([string]::IsNullOrWhiteSpace($Region)) {
            Write-Host -Object "[Error] The region is empty or whitespace. Please provide one of the following regions: $($SupportedRegions -join ", ")"
            exit 1
        }

        # Check if the region is one of the supported regions
        if ($SupportedRegions -notcontains $Region) {
            Write-Host -Object "[Error] The region '$Region' is not supported. Please provide one of the following regions: $($SupportedRegions -join ', ')."
            exit 1
        }
    }

    # Validate the primary DNS IP if provided
    if ($PrimaryDNSIP) {
        $PrimaryDNSIP = $PrimaryDNSIP.Trim()

        if ([string]::IsNullOrWhiteSpace($PrimaryDNSIP)) {
            Write-Host -Object "[Error] The primary DNS IP address is empty or whitespace. Please provide a valid IP address or leave it blank."
            exit 1
        }

        # Check if the primary DNS IP is formatted correctly as an IPv4 address
        if ($PrimaryDNSIP -notmatch "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
            Write-Host -Object "[Error] The primary DNS IP address '$PrimaryDNSIP' is not formatted correctly as an IPv4 address. Please provide a valid IP address in the format 'x.x.x.x'."
            exit 1
        }

        # Check if the primary DNS IP is a valid IPv4 address
        if (-not [System.Net.IPAddress]::TryParse($PrimaryDNSIP, [ref]$null)) {
            Write-Host -Object "[Error] The primary DNS IP address '$PrimaryDNSIP' is not a valid IPv4 address. Please provide a valid IP address."
            exit 1
        }
    }

    # Validate the secondary DNS IP if provided
    if ($SecondaryDNSIP) {
        $SecondaryDNSIP = $SecondaryDNSIP.Trim()

        if ([string]::IsNullOrWhiteSpace($SecondaryDNSIP)) {
            Write-Host -Object "[Error] The secondary DNS IP address is empty or whitespace. Please provide a valid IP address or leave it blank."
            exit 1
        }

        # Check if the secondary DNS IP is formatted correctly as an IPv4 address
        if ($SecondaryDNSIP -notmatch "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
            Write-Host -Object "[Error] The secondary DNS IP address '$SecondaryDNSIP' is not formatted correctly as an IPv4 address. Please provide a valid IP address in the format 'x.x.x.x'."
            exit 1
        }

        # Check if the secondary DNS IP is a valid IPv4 address
        if (-not [System.Net.IPAddress]::TryParse($SecondaryDNSIP, [ref]$null)) {
            Write-Host -Object "[Error] The secondary DNS IP address '$SecondaryDNSIP' is not a valid IPv4 address. Please provide a valid IP address."
            exit 1
        }

        # Check if the secondary DNS IP is the same as the primary DNS IP
        if ($PrimaryDNSIP -eq $SecondaryDNSIP) {
            Write-Host -Object "[Error] The primary and secondary DNS IP addresses cannot be the same. Please provide different IP addresses."
            exit 1
        }
    }

    # Function to retrieve and display all active network adapters
    function Get-ActiveNetworkAdapters {
        param (
            [switch]$WriteToHost
        )

        # Identify loopback adapters on the device by if they have an IP address that starts with 127.
        try {
            $LoopbackAdapters = Get-NetIPAddress -ErrorAction Stop | Where-Object {$_.IPAddress -match "^127\."}
        }
        catch {
            Write-Host -Object "[Error] Unable to retrieve loopback adapters."
            exit 1
        }

        # Find the active IPv4 network adapters
        try {
            $ActiveNetworkAdaptersObject = Get-NetIPInterface -AddressFamily IPv4 -ConnectionState Connected -ErrorAction Stop | Sort-Object -Property InterfaceAlias |
                Select-Object -Property InterfaceAlias, InterfaceIndex, ConnectionState, @{
                    Name = "DNSServers";
                    Expression = {
                        (Get-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
                    }
                }
        }
        catch {
            Write-Host -Object "[Error] Unable to retrieve network adapters."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        # Filter out the loopback addresses
        $ActiveNetworkAdaptersObject = $ActiveNetworkAdaptersObject | Where-Object {$_.InterfaceIndex -notin $LoopbackAdapters.InterfaceIndex}

        # If WriteToHost is selected, format the output as a table and write it to the host
        # Otherwise, return the object
        if ($WriteToHost) {
            $ActiveNetworkAdaptersObject | Format-Table -AutoSize | Out-String | Write-Host
        }
        else {
            return $ActiveNetworkAdaptersObject
        }
    }

    # Error if the user is trying to reset to automatic while also providing DNS settings
    if ($ResetToAutomatic -and ($PrimaryDNSIP -or $SecondaryDNSIP)) {
        Write-Host -Object "[Error] You cannot reset the DNS settings to automatic while also providing primary or secondary DNS IP addresses. Please choose one option or the other."
        exit 1
    }

    # Validate the network adapter if provided
    if ($NetworkAdapter) {
        $NetworkAdapter = $NetworkAdapter.Trim()

        if ([string]::IsNullOrWhiteSpace($NetworkAdapter)) {
            Write-Host -Object "[Error] The network adapter name is empty or whitespace. Please provide a valid network adapter name or leave it blank."
            exit 1
        }

        # If the network adapter provided is only digits, treat it as an index and validate it
        # Otherwise, treat it as an alias
        if ($NetworkAdapter -match "^\d+$") {
            try {
                $NetworkAdapterIndex = [int]$NetworkAdapter
            }
            catch {
                Write-Host -Object "[Error] The network adapter index '$NetworkAdapter' is not a valid integer. Please provide a valid and connected network adapter index or leave it blank."
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Get-ActiveNetworkAdapters -WriteToHost
                exit 1
            }

            try {
                $NetworkAdapterToModify = Get-NetAdapter -InterfaceIndex $NetworkAdapterIndex -ErrorAction Stop
            }
            catch {
                Write-Host -Object "[Error] Failed to retrieve a network adapter with the index '$NetworkAdapterIndex'. Please provide a valid and connected network adapter index or leave it blank."
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Get-ActiveNetworkAdapters -WriteToHost
                exit 1
            }
        }
        else {
            $NetworkAdapterAlias = $NetworkAdapter

            try {
                $NetworkAdapterToModify = Get-NetAdapter -InterfaceAlias $NetworkAdapterAlias -ErrorAction Stop
            }
            catch {
                Write-Host -Object "[Error] Failed to retrieve a network adapter with the alias '$NetworkAdapterAlias'. Please provide a valid and connected network adapter alias or leave it blank."
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Get-ActiveNetworkAdapters -WriteToHost
                exit 1
            }
        }
    }

    # Error if neither servers are provided and we are not resetting to default
    if (-not $ListNetworkAdapters -and [string]::IsNullOrWhiteSpace($NetworkAdapter) -and [string]::IsNullOrWhiteSpace($PrimaryDNSIP) -and [string]::IsNullOrWhiteSpace($SecondaryDNSIP) -and -not $ResetToAutomatic) {
        Write-Host -Object "[Error] No DNS options were selected or filled out. Please choose or fill out at least one option."
        exit 1
    }

    # Error if a network adapter was provided but no DNS options were selected
    if ($NetworkAdapter -and [string]::IsNullOrWhiteSpace($PrimaryDNSIP) -and [string]::IsNullOrWhiteSpace($SecondaryDNSIP) -and -not $ResetToAutomatic) {
        Write-Host -Object "[Error] A network adapter was specified, but no DNS options were selected. Please provide a primary or secondary DNS IP address, or check the 'Reset To Automatic' option."
        exit 1
    }

    # Error if DNS IPs were specified but a region was not provided
    if (-not $Region -and ($PrimaryDNSIP -or $SecondaryDNSIP)) {
        Write-Host -Object "[Error] A region must be chosen when specifying DNS IP addresses. Please provide a valid region or use the 'Reset To Automatic' option."
        exit 1
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
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running with Administrator privileges."
        exit 1
    }

    if (!$IsElevated) {
        Write-Host -Object "[Error] Access Denied: The user '$env:Username' does not have administrator privileges, or the script is not running with elevated permissions."
        exit 1
    }

    # If the user requested to list the network adapters, list them and exit
    if ($ListNetworkAdapters) {
        Get-ActiveNetworkAdapters -WriteToHost
        exit 0
    }

    # Initialize the changesMade variable
    $changesMade = $False

    # Define a list of NinjaOne agent and patcher hostnames to verify DNS resolution against
    $RequiredAgentHostnames = @(
        # Global agent/patcher endpoints
        [PSCustomObject]@{ Hostname = "resources.ninjarmm.com"; Region = "Global" }
        [PSCustomObject]@{ Hostname = "agent-tun-usw-1.ninjarmm.com"; Region = "Global" }
        [PSCustomObject]@{ Hostname = "agent-tun-usw-2.ninjarmm.com"; Region = "Global" }
        [PSCustomObject]@{ Hostname = "agent-tun-usw-3.ninjarmm.com"; Region = "Global" }
        [PSCustomObject]@{ Hostname = "ninjauploads.s3.amazonaws.com"; Region = "Global" }
        # NA region agent/patcher endpoints
        [PSCustomObject]@{ Hostname = "app.ninjarmm.com"; Region = "NA" }
        [PSCustomObject]@{ Hostname = "fts-prod-oregon-1.ninjarmm.com"; Region = "NA" }
        [PSCustomObject]@{ Hostname = "fts-prod-oregon-2.ninjarmm.com"; Region = "NA" }
        [PSCustomObject]@{ Hostname = "rtc-us-west-1.ninjarmm.com"; Region = "NA" }
        [PSCustomObject]@{ Hostname = "rtc-us-west-2.ninjarmm.com"; Region = "NA" }
        # US2 region agent/patcher endpoints
        [PSCustomObject]@{ Hostname = "fts-1.us2.ninjarmm.com"; Region = "US2" }
        [PSCustomObject]@{ Hostname = "rtc-us2.us2.ninjarmm.com"; Region = "US2" }
        [PSCustomObject]@{ Hostname = "agent-tun-use2-0.us2.ninjarmm.com"; Region = "US2" }
        # EU region agent/patcher endpoints
        [PSCustomObject]@{ Hostname = "agent-eu-central.ninjarmm.com"; Region = "EU" }
        [PSCustomObject]@{ Hostname = "fts-prod-frankfurt.ninjarmm.com"; Region = "EU" }
        [PSCustomObject]@{ Hostname = "rtc-eu-central-1.ninjarmm.com"; Region = "EU" }
        [PSCustomObject]@{ Hostname = "agent-tun-euc-0.ninjarmm.com"; Region = "EU" }
        # CA region agent/patcher endpoints
        [PSCustomObject]@{ Hostname = "ca.ninjarmm.com"; Region = "CA" }
        [PSCustomObject]@{ Hostname = "agent-ca.ninjarmm.com"; Region = "CA" }
        [PSCustomObject]@{ Hostname = "rtc-ca-central.ninjarmm.com"; Region = "CA" }
        [PSCustomObject]@{ Hostname = "tun-ca-central-1.ninjarmm.com"; Region = "CA" }
        [PSCustomObject]@{ Hostname = "connect-ca-central-s1.ninjarmm.com"; Region = "CA" }
        [PSCustomObject]@{ Hostname = "connect-ca-central-s2.ninjarmm.com"; Region = "CA" }
        [PSCustomObject]@{ Hostname = "connect-ca-central-s3.ninjarmm.com"; Region = "CA" }
        # OC region agent/patcher endpoints
        [PSCustomObject]@{ Hostname = "oc.ninjarmm.com"; Region = "OC" }
        [PSCustomObject]@{ Hostname = "rtc-ap-southeast-2-0.ninjarmm.com"; Region = "OC" }
        [PSCustomObject]@{ Hostname = "tun-apse2-0.ninjarmm.com"; Region = "OC" }
        [PSCustomObject]@{ Hostname = "fts-prod-sydney.ninjarmm.com"; Region = "OC" }
    )

    # Determine the hostnames to test against based on the provided region
    $HostnamesToTest = $RequiredAgentHostnames | Where-Object {$_.Region -eq "$Region" -or $_.Region -eq "Global"} | Select-Object -ExpandProperty Hostname

    # Test the primary DNS server
    if ($PrimaryDNSIP) {
        foreach ($hostname in $HostnamesToTest) {
            try {
                $DNSResult = Resolve-DnsName -Name $hostname -Server $PrimaryDNSIP -Type A -DnsOnly -NoHostsFile -ErrorAction Stop

                # DNS servers blocking a specific domain usually return 0.0.0.0 as the IP address
                if ($DNSResult.IPAddress -contains "0.0.0.0") {
                    throw "The server at '$PrimaryDNSIP' returned an invalid IP address for '$hostname'. It is likely being blocked by the server."
                }
            }
            catch {
                Write-Host -Object "[Error] DNS resolution failed for the primary DNS server '$PrimaryDNSIP' while testing '$hostname'."
                Write-Host -Object "[Error] Please check the DNS server configuration or choose a different DNS server."
                Write-Host -Object "[Error] Ninja whitelisting information: https://ninjarmm.zendesk.com/hc/en-us/articles/211406886-Global-Allowlist-Whitelist-Information"
                Write-Host -Object "[Error] $($_.Exception.Message)"
                exit 1
            }
        }
    }

    # Test the secondary DNS server
    if ($SecondaryDNSIP) {
        foreach ($hostname in $HostnamesToTest) {
            try {
                $DNSResult = Resolve-DnsName -Name $hostname -Server $SecondaryDNSIP -Type A -DnsOnly -NoHostsFile -ErrorAction Stop

                # DNS servers blocking a specific domain usually return 0.0.0.0 as the IP address
                if ($DNSResult.IPAddress -contains "0.0.0.0") {
                    throw "The server at '$PrimaryDNSIP' returned an invalid IP address for '$hostname'. It is likely being blocked by the server."
                }
            }
            catch {
                Write-Host -Object "[Error] DNS resolution failed for the secondary DNS server '$SecondaryDNSIP' while testing '$hostname'."
                Write-Host -Object "[Error] Please check the DNS server configuration or choose a different DNS server."
                Write-Host -Object "[Error] Ninja whitelisting information: https://ninjarmm.zendesk.com/hc/en-us/articles/211406886-Global-Allowlist-Whitelist-Information"
                Write-Host -Object "[Error] $($_.Exception.Message)"
                exit 1
            }
        }
    }

    # If a network adapter wasn't specified, attempt to find an active one
    if (-not $NetworkAdapterToModify) {
        Write-Host -Object "[Info] No network adapter specified. Attempting to find an active network adapter..."
        $ActiveAdapters = Get-ActiveNetworkAdapters

        # If there is only one active network adapter, use it
        # Otherwise, error out and list the active adapters
        if (($ActiveAdapters | Measure-Object).Count -eq 1) {
            $NetworkAdapterToModify = Get-NetAdapter -InterfaceIndex $ActiveAdapters.InterfaceIndex
            Write-Host -Object "[Info] Found a single active network adapter with alias '$($NetworkAdapterToModify.InterfaceAlias)' and index '$($NetworkAdapterToModify.InterfaceIndex)'."
        }
        else {
            Write-Host -Object "[Error] Multiple active network adapters found. Please specify a network adapter to modify."
            Get-ActiveNetworkAdapters -WriteToHost
            exit 1
        }
    }
    elseif ($NetworkAdapterToModify.Count -gt 1) {
        Write-Host -Object "[Error] Multiple network adapters found with the alias or index '$NetworkAdapter'. Please specify a unique network adapter to modify."
        Get-ActiveNetworkAdapters -WriteToHost
        exit 1
    }
    else {
        Write-Host -Object "[Info] Using the network adapter with alias '$($NetworkAdapterToModify.InterfaceAlias)' and index '$($NetworkAdapterToModify.InterfaceIndex)'."
    }

    Write-Host ""

    # Get the current DNS servers of the network adapter
    try {
        $StartingDNSServers = (Get-DnsClientServerAddress -InterfaceIndex $NetworkAdapterToModify.InterfaceIndex -AddressFamily IPv4 -ErrorAction Stop).ServerAddresses
    }
    catch {
        Write-Host -Object "[Error] Unable to retrieve DNS server addresses for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)'."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Retrieve the network adapter settings from the registry
    try {
        $AdapterSettings = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($NetworkAdapterToModify.InterfaceGuid)" -ErrorAction Stop
    }
    catch {
        Write-Host "[Error] Failed to retrieve interface settings for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)'."
        Write-Host "[Error] $($_.Exception.Message)"
        exit 1
    }

    # If DNS for this adapter is configured manually, the name servers will be present in this property separated by commas
    $ManuallyConfiguredDNSServers = $AdapterSettings.NameServer -split ","

    # Determine if the DNS servers are set to automatic or manually configured
    if ([string]::IsNullOrWhiteSpace($ManuallyConfiguredDNSServers)) {
        $StartingAutomaticDNSStatus = $true
        $CurrentAutomaticDNSStatus = $true
    }
    else {
        $StartingAutomaticDNSStatus = $false
        $CurrentAutomaticDNSStatus = $false
        $StartingManualPrimaryDNSAddress = $ManuallyConfiguredDNSServers[0]
        $StartingManualSecondaryDNSAddress = $ManuallyConfiguredDNSServers[1]
    }

    # If the user requested to reset to automatic, reset the DNS settings
    if ($ResetToAutomatic) {
        # If the DNS servers are already set to automatic, inform the user
        # Otherwise, continue to reset the DNS settings
        if ($StartingAutomaticDNSStatus) {
            Write-Host -Object "[Info] The network adapter '$($NetworkAdapterToModify.InterfaceAlias)' is already using automatic DNS settings."
        }
        else {
            $DHCPEnabled = $AdapterSettings.EnableDhcp
            $DHCPServer = $AdapterSettings.DhcpServer
            $DNSServerFromDhcp = $AdapterSettings.DhcpNameServer

            # Error if the network adapter does not have DHCP enabled
            if ($DHCPEnabled -eq 0) {
                Write-Host -Object "[Error] The network adapter '$($NetworkAdapterToModify.InterfaceAlias)' does not have DHCP enabled. Please enable DHCP on the adapter to reset DNS settings to automatic."
                $DHCPError = $true
                $ExitCode = 1
            }

            # Error if the DHCP server is not set or is invalid
            if (-not $DHCPError -and ($DHCPServer -eq "255.255.255.255" -or [string]::IsNullOrWhiteSpace($DHCPServer))) {
                Write-Host -Object "[Error] The network adapter '$($NetworkAdapterToModify.InterfaceAlias)' does not have a DHCP server identified. Please ensure your DHCP server is working correctly and try again."
                $DHCPError = $true
                $ExitCode = 1
            }

            # Error if the DHCP server is not providing any DNS servers
            if (-not $DHCPError -and ([string]::IsNullOrWhiteSpace($DNSServerFromDhcp))) {
                Write-Host -Object "[Error] The DHCP server at $DHCPServer does not provide any DNS servers."
                $DHCPError = $true
                $ExitCode = 1
            }

            # If there are no DHCP-related errors, continue to reset the DNS settings
            if (-not $DHCPError) {
                try {
                    Write-Host -Object "[Info] Resetting DNS server addresses for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)' to automatic..."
                    Set-DnsClientServerAddress -InterfaceIndex $NetworkAdapterToModify.InterfaceIndex -ResetServerAddresses -ErrorAction Stop
                    Write-Host -Object "[Info] DNS server addresses for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)' have been reset to automatic."
                    $CurrentAutomaticDNSStatus = $true
                    $changesMade = $true
                }
                catch {
                    Write-Host -Object "[Error] Failed to reset DNS server addresses for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)'."
                    Write-Host -Object "[Error] $($_.Exception.Message)"
                    $ExitCode = 1
                }
            }
        }
    }

    # If the user provided both primary and secondary DNS IPs, set them
    if ($PrimaryDNSIP -and $SecondaryDNSIP) {
        # If both primary and secondary DNS IPs are already manually configured, check if they match the provided values
        if ($StartingManualPrimaryDNSAddress -eq $PrimaryDNSIP -and $StartingManualSecondaryDNSAddress -eq $SecondaryDNSIP) {
            Write-Host -Object "[Info] The DNS servers of '$($NetworkAdapterToModify.InterfaceAlias)' are already set to '$($StartingDNSServers -join ", ")'."
        }
        else {
            $DNSServersToSet = @($PrimaryDNSIP, $SecondaryDNSIP)
            try {
                Write-Host -Object "[Info] Setting the DNS servers for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)' to '$($DNSServersToSet -join ", ")'..."
                Set-DnsClientServerAddress -InterfaceIndex $NetworkAdapterToModify.InterfaceIndex -ServerAddresses $DNSServersToSet -ErrorAction Stop
                Write-Host -Object "[Info] The DNS servers for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)' have been set to '$($DNSServersToSet -join ", ")'."
                $CurrentAutomaticDNSStatus = $false
                $changesMade = $true
            }
            catch {
                Write-Host -Object "[Error] Failed to set primary DNS server for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)'."
                Write-Host -Object "[Error] $($_.Exception.Message)"
                $ExitCode = 1
            }
        }
    }

    # If the user provided a primary DNS IP but not a secondary DNS IP, set the primary DNS IP
    if ($PrimaryDNSIP -and -not $SecondaryDNSIP) {
        switch ($PrimaryDNSIP) {
            # Error if the requested primary DNS IP is the same as the current secondary DNS IP
            $StartingManualSecondaryDNSAddress {
                Write-Host -Object "[Error] The primary DNS server cannot be set to the same IP address as the secondary DNS server. Please provide a different primary DNS IP address."
                $ExitCode = 1
            }
            # If the requested primary DNS IP is the same as the current primary DNS IP, inform the user
            $StartingManualPrimaryDNSAddress {
                Write-Host -Object "[Info] The primary DNS server of '$($NetworkAdapterToModify.InterfaceAlias)' is already set to '$PrimaryDNSIP'."
            }
            # Otherwise, continue to set the primary DNS server
            default {
                $DNSServersToSet = @($PrimaryDNSIP, $StartingManualSecondaryDNSAddress)
                Write-Host -Object "[Info] Setting the primary DNS server for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)' to '$PrimaryDNSIP'..."
                try {
                    Set-DnsClientServerAddress -InterfaceIndex $NetworkAdapterToModify.InterfaceIndex -ServerAddresses $DNSServersToSet -ErrorAction Stop
                    Write-Host -Object "[Info] The primary DNS server for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)' has been set to '$PrimaryDNSIP'."
                    $CurrentAutomaticDNSStatus = $false
                    $changesMade = $true
                }
                catch {
                    Write-Host -Object "[Error] Failed to set primary DNS server for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)'."
                    Write-Host -Object "[Error] $($_.Exception.Message)"
                    $ExitCode = 1
                }
            }
        }
    }

    # If the user provided a secondary DNS IP but not a primary DNS IP, set the secondary DNS IP
    if ($SecondaryDNSIP -and -not $PrimaryDNSIP) {
        # If automatic DNS is enabled and we are only setting a secondary DNS IP, error out
        if ($StartingAutomaticDNSStatus) {
            Write-Host -Object "[Error] The network adapter '$($NetworkAdapterToModify.InterfaceAlias)' is currently using automatic DNS, but a manual primary IP address is not being configured. Please provide a primary DNS IP in order to set the secondary DNS IP properly."
            $ExitCode = 1
        }
        else {
            switch ($SecondaryDNSIP) {
                # Error if the requested secondary DNS IP is the same as the current primary DNS IP
                $StartingManualPrimaryDNSAddress {
                    Write-Host -Object "[Error] The secondary DNS server cannot be set to the same IP address as the primary DNS server. Please provide a different secondary DNS IP address."
                    $ExitCode = 1
                }
                # If the requested secondary DNS IP is the same as the current secondary DNS IP, inform the user
                $StartingManualSecondaryDNSAddress {
                    Write-Host -Object "[Info] The secondary DNS server of '$($NetworkAdapterToModify.InterfaceAlias)' is already set to '$SecondaryDNSIP'."
                }
                # Otherwise, continue to set the secondary DNS IP
                default {
                    $DNSServersToSet = @($StartingManualPrimaryDNSAddress, $SecondaryDNSIP)
                    Write-Host -Object "[Info] Setting the secondary DNS server for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)' to '$SecondaryDNSIP'..."
                    try {
                        Set-DnsClientServerAddress -InterfaceIndex $NetworkAdapterToModify.InterfaceIndex -ServerAddresses $DNSServersToSet -ErrorAction Stop
                        Write-Host -Object "[Info] The secondary DNS server for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)' has been set to '$SecondaryDNSIP'."
                        $CurrentAutomaticDNSStatus = $false
                        $changesMade = $true
                    }
                    catch {
                        Write-Host -Object "[Error] Failed to set secondary DNS server for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)'."
                        Write-Host -Object "[Error] $($_.Exception.Message)"
                        $ExitCode = 1
                    }
                }
            }
        }
    }

    Write-Host ""

    if ($changesMade) {
        # Output the previous DNS configuration of the network adapter
        Write-Host -Object "### Previous DNS server configuration: ###`n"
        ([PSCustomObject]@{
            InterfaceAlias = $NetworkAdapterToModify.InterfaceAlias
            InterfaceIndex = $NetworkAdapterToModify.InterfaceIndex
            PrimaryDNSServer = $StartingDNSServers[0]
            SecondaryDNSServer = $StartingDNSServers[1]
            AutomaticDNS = $StartingAutomaticDNSStatus
        } | Format-Table -AutoSize | Out-String).Trim() | Write-Host
        Write-Host -Object ""
    }

    # Retrieve the current DNS server addresses after modification
    try {
        $CurrentDNSServers = (Get-DnsClientServerAddress -InterfaceIndex $NetworkAdapterToModify.InterfaceIndex -AddressFamily IPv4 -ErrorAction Stop).ServerAddresses
    }
    catch {
        Write-Host -Object "[Error] Unable to retrieve DNS server addresses for the network adapter '$($NetworkAdapterToModify.InterfaceAlias)'. Changes made: $changesMade"
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Output the current DNS configuration of the network adapter
    Write-Host -Object "### Current DNS server configuration: ###`n"
    ([PSCustomObject]@{
        InterfaceAlias = $NetworkAdapterToModify.InterfaceAlias
        InterfaceIndex = $NetworkAdapterToModify.InterfaceIndex
        PrimaryDNSServer = $CurrentDNSServers[0]
        SecondaryDNSServer = $CurrentDNSServers[1]
        AutomaticDNS = $CurrentAutomaticDNSStatus
    } | Format-Table -AutoSize | Out-String).Trim() | Write-Host

    exit $ExitCode
}
end {
    
    
    
}