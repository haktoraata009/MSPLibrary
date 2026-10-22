#Requires -Version 5.1

<#
.SYNOPSIS
    Wipe a device with a selected option such as keeping the user data or fully cleaning the internal drive (protected wipe).
.DESCRIPTION
    Wipe a device with a selected option such as keeping the user data or fully cleaning the internal drive (protected wipe).
.EXAMPLE
    -WipeOption "Protected Wipe" -ComputerToWipe "WIN11-DOM-TEST"
    
    Verifying the script is running on the correct computer.
    The computer name is correct (WIN11-DOM-TEST).
    Attempting to initiate a computer wipe using the option 'Protected Wipe'.

    A computer wipe has been initiated.

.PARAMETER -WipeOption "ReplaceMeWithAValidOption"
    Choose between a basic wipe, a wipe that fully cleans the internal drive, a wipe that preserves user files, or a wipe that preserves provisioning packages.
    Valid Options: "Wipe", "Protected Wipe", "Wipe but Keep User Files", "Wipe but Keep Provisioning Data"

.PARAMETER -ComputerToWipe "ReplaceMeWithTheDesiredComputersName"
    Enter the name of the computer you're trying to initiate a computer wipe on.

.PARAMETER -ComputerNameBypass
    Bypass the computer name safety check.

.NOTES
    Minimum OS Architecture Supported: Windows 10
    Version: 1.1
    Release Notes: Updated the checkbox script variable, changed the names of the parameters, moved validation outside the parameter section, and switched to Write-Host instead of throwing an error.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$WipeOption,
    [Parameter()]
    [String]$ComputerToWipe,
    [Parameter()]
    [Switch]$ComputerNameBypass = [System.Convert]::ToBoolean($env:computerNameBypass)
)

begin {
    if ($env:wipeOption) { $WipeOption = $env:wipeOption }
    if ($env:computerToWipe) { $ComputerToWipe = $env:computerToWipe }
    
    # If the ComputerNameBypass flag is enabled, bypass verifying the computer name.
    if ($ComputerNameBypass) {
        # Inform the user that bypass is active.
        Write-Host -Object "[Warning] Computer Name Bypass was selected. The script will NOT verify that it is running on the correct computer."

        # If a computer name was provided, ignore it.
        if ($ComputerToWipe) {
            Write-Host -Object "[Warning] Ignoring the provided computer name '$ComputerToWipe'."
            $ComputerToWipe = $null
        }
    }

    # Ensure that a wipe option has been provided.
    if ([String]::IsNullOrWhiteSpace($WipeOption)) {
        Write-Host -Object "[Error] You must select a wipe option such as 'Wipe', 'Protected Wipe', 'Wipe but Keep User Files', 'Wipe but Keep Provisioning Data'."
        exit 1
    }

    # Remove any extra whitespace from the wipe option.
    $WipeOption = $WipeOption.Trim()

    # Define a list of valid wipe options.
    $ValidWipeOptions = "Wipe", "Protected Wipe", "Wipe but keep user files", "Wipe but keep provisioning data"
    
    # Verify that the provided wipe option is valid.
    if ($ValidWipeOptions -notcontains $WipeOption) {
        Write-Host -Object "[Error] An invalid wipe option of '$WipeOption' was provided. Please select a valid wipe option such as 'Wipe', 'Protected Wipe', 'Wipe but keep user files', 'Wipe but keep provisioning data'."
        exit 1
    }

    # Check if 'Protected Wipe' is supported on the current OS build.
    if ([System.Environment]::OSVersion.Version.Build -lt 1703 -and $WipeOption -eq "Protected Wipe") {
        Write-Host -Object "[Error] The current OS build is '$([System.Environment]::OSVersion.Version.Build)'. 'Protected Wipe' is only available on Windows builds 1703 or higher."
        exit 1
    }

    # Check if 'Wipe but Keep User Files' is supported on the current OS build.
    if ([System.Environment]::OSVersion.Version.Build -lt 1709 -and $WipeOption -eq "Wipe but Keep User Files") {
        Write-Host "[Error] The current OS build is '$([System.Environment]::OSVersion.Version.Build)'. 'Wipe but Keep User Files' is only available on Windows builds 1709 or higher."
        exit 1
    }

    # If no computer name is provided and the bypass is not enabled, show an error.
    if ([String]::IsNullOrWhiteSpace($ComputerToWipe) -and !$ComputerNameBypass) {
        Write-Host -Object "[Error] You must provide the computer name for the computer you are trying to wipe."
        exit 1
    }

    
    # If a computer name is provided, trim it and indicate verification will occur.
    if ($ComputerToWipe) {
        $ComputerToWipe = $ComputerToWipe.Trim()

        Write-Host -Object "Verifying the script is running on the correct computer."
    }

    # Verify that the provided computer name matches the current computer name, unless bypass is enabled.
    if ($ComputerToWipe -ne $env:COMPUTERNAME -and !$ComputerNameBypass) {
        Write-Host -Object "[Error] The computer name '$ComputerToWipe' does not equal '$env:COMPUTERNAME'. Unable to wipe computer."
        exit 1
    }
    elseif ($ComputerToWipe) {
        Write-Host -Object "The computer name is correct ($env:COMPUTERNAME)."
    }

    function Test-IsServer {
        [CmdletBinding()]
        param()
    
        # Determine the method to retrieve the operating system information based on PowerShell version
        $OS = if ($PSVersionTable.PSVersion.Major -lt 3) {
            Get-WmiObject -Class Win32_OperatingSystem
        }
        else {
            Get-CimInstance -ClassName Win32_OperatingSystem
        }
    
        # Check if the ProductType is "2", which indicates that the system is a domain controller or is a server
        if ($OS.ProductType -eq "2" -or $OS.ProductType -eq "3") {
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
        # 544 is the value for the Built In Administrators role
        # Reference: https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsbuiltinrole
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]'544')
    }

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    # Attempt to determine if the script is running with elevated (Administrator) privileges.
    try {
        $IsElevated = Test-IsElevated -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running with Administrator privileges."
        exit 1
    }

    # If the script is not running with elevated privileges, output an access denied message and exit.
    if (!$IsElevated) {
        Write-Host -Object "[Error] Access Denied: Please run with Administrator privileges."
        exit 1
    }

    # Attempt to determine if the device is a server.
    try {
        $IsServer = Test-IsServer -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the device is a workstation or server."
        exit 1
    }

    # If the device is identified as a server, the script does not support it; output an error and exit.
    if ($IsServer) {
        Write-Host -Object "[Error] This script does not support Windows Server."
        exit 1
    }

    # Map the provided wipe option to its corresponding internal wipe method.
    $WipeMethod = switch ($WipeOption) {
        "Wipe" { "Wipe" }
        "Protected Wipe" { "WipeProtected" }
        "Wipe but Keep User Files" { "WipePersistUserData" }
        "Wipe but Keep Provisioning Data" { "WipePersistProvisionedData" }
    }

    # Try to initiate the computer wipe process by creating a CIM session and setting up parameters.
    try {
        Write-Host -Object "Attempting to initiate a computer wipe using the option '$WipeOption'."
        $Session = New-CimSession

        $Param = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create("param", "", "String", "In")
        $Params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
        $Params.Add($Param)
    }
    catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to create the required CIM Session to wipe the computer."
        exit 1
    }

    # Define the CIM parameters using splatting for retrieving the RemoteWipe instance.
    $CimSplat = @{
        Namespace = "root\cimv2\mdm\dmmap"
        ClassName = "MDM_RemoteWipe"
        Filter    = "ParentID='./Vendor/MSFT' and InstanceID='RemoteWipe'"
    }

    # Attempt to retrieve the CIM instance and invoke the appropriate wipe method.
    try {
        $Instance = Get-CimInstance @CimSplat
        $Session.InvokeMethod($CimSplat["Namespace"], $Instance, "do$($WipeMethod)Method", $Params)
    }
    catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to wipe the computer with the option '$WipeOption'."
        exit 1
    }

    # Inform the user that the computer wipe has been initiated.
    Write-Host -Object "A computer wipe has been initiated."

    exit $ExitCode
}
end {
    
    
    
}