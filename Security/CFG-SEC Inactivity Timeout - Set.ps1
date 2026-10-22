#Requires -Version 5.1

<#
.SYNOPSIS
    Configures the inactivity timeout to a specified duration or removes it if desired. Use the 'Force' checkbox to override the existing setting if it is already configured.
.DESCRIPTION
    Configures the inactivity timeout to a specified duration or removes it if desired. Use the 'Force' checkbox to override the existing setting if it is already configured.
.EXAMPLE
    -Minutes 5
    This sets the Inactivity (Lock Computer) timeout to 5 minutes and does not change it if already set.
.EXAMPLE
    -Minutes 5 -Force
    This sets the Inactivity (Lock Computer) timeout to 5 minutes and forces the change if already set.
.EXAMPLE
    -Remove
    This removes the Inactivity (Lock Computer) timeout if it is set.
.EXAMPLE
    PS C:\> Set-IdleLock.ps1 -Minutes 5
    This sets the Inactivity (Lock Computer) timeout to 5 minutes.
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.1
    Release Notes: Adds the option to remove the timeout. Replaces the Set-ItemProp function with the Set-RegKey function.
.COMPONENT
    LocalUserAccountManagement
#>

[CmdletBinding()]
param (
    [Parameter()]
    [int]$Minutes,
    [Parameter()]
    [switch]$Remove = [System.Convert]::ToBoolean($env:remove),
    [Parameter()]
    [switch]$Force = [System.Convert]::ToBoolean($env:force)
)

begin {
    if ($env:minutes) {
        try {
            $Minutes = $env:minutes
        }
        catch {
            Write-Host "[Error] Minutes must be between 0 and 9999 (inclusive)."
            exit 1
        }
    }

    if ($Remove) {
        if ($Minutes -eq 0) {
            # If Minutes is set to 0 and Remove is set, remove the InactivityTimeoutSecs key
        }
        elseif (-not [String]::IsNullOrWhiteSpace($env:minutes)) {
            # Check if Minutes is set when Remove is set
            Write-Host "[Error] Minutes must not be set or must be set to 0 when Remove is used."
            exit 1
        }
    }
    else {
        # Check if Minutes is set if Remove is not set
        if ([String]::IsNullOrWhiteSpace($env:minutes) -or $Minutes -gt 9999 -or $Minutes -lt 0) {
            Write-Host "[Error] Minutes must be between 0 and 9999 (inclusive)."
            exit 1
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
        # 544 is the value for the Built-In Administrators role
        # Reference: https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsbuiltinrole
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]'544')
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

        # Check if the specified registry path exists
        if (!(Test-Path -Path $Path)) {
            try {
                # If the path does not exist, create it
                New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
            }
            catch {
                throw $_
            }
        }

        # Check if the registry key already exists at the specified path
        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            # Retrieve the current value of the registry key
            $CurrentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
            if ($CurrentValue -eq $Value) {
                Write-Host "$Path\$Name is already set to the value '$Value'."
            }
            else {
                try {
                    # Update the registry key with the new value
                    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -Confirm:$false -ErrorAction Stop | Out-Null
                }
                catch {
                    throw $_
                }

                # Output the change made to the registry key
                Write-Host "$Path\$Name changed from $CurrentValue to $((Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name)"
            }

            return
        }

        try {
            # If the registry key does not exist, create it with the specified value and property type
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force -Confirm:$false -ErrorAction Stop | Out-Null
        }
        catch {
            throw $_
        }

        # Output the creation of the new registry key
        Write-Host "Set $Path\$Name to $((Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name)"
    }
}
process {
    if (-not (Test-IsElevated)) {
        Write-Host "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    $Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    $IdleName = "InactivityTimeoutSecs"
    $Seconds = $Minutes * 60
    # Override "Check if already set"
    if (-not $Force) {
        # Check if already removed
        if ($Remove) {
            if (-not (Get-ItemProperty -Path $Path -Name $IdleName -ErrorAction SilentlyContinue)) {
                Write-Host "[Info] The Inactivity timeout is already removed."
                exit 0
            }
        }
        # Check if already set
        elseif ($(Get-ItemProperty -Path $Path | Select-Object -Property $IdleName -ExpandProperty $IdleName -ErrorAction SilentlyContinue)) {
            $CurrentIdleSeconds = $(Get-ItemPropertyValue -Path $Path -Name $IdleName)
            # If value already set, do nothing.
            if ($CurrentIdleSeconds) {
                Write-Host "[Error] The Inactivity timeout is currently set to $($CurrentIdleSeconds/60) minutes. Use the Force option to change the timeout to $Minutes minutes."
                exit 1
            }
        }
    }

    # Sets InactivityTimeoutSecs to $Minutes
    try {
        if ($Remove) {
            # Remove the InactivityTimeoutSecs key if it exists
            if (-not (Get-ItemProperty -Path $Path -Name $IdleName -ErrorAction SilentlyContinue)) {
                Write-Host "[Info] The Inactivity timeout is already removed."
                exit 0
            }
            Remove-ItemProperty -Path $Path -Name $IdleName -ErrorAction SilentlyContinue | Out-Null
            Write-Host "[Info] Removed the Inactivity timeout."
            exit 0
        }
        Set-RegKey -Path $Path -Name $IdleName -Value $Seconds
        Write-Host "[Info] Set the Inactivity timeout to $($Minutes) minutes."
        if ($Minutes -eq 0) {
            Write-Host "[Info] Inactivity timeout set to 0 minutes. This is the same as disabling the inactivity timeout."
        }
    }
    catch {
        Write-Host "$($_.Exception.Message)"
        exit 1
    }
}
end {
    
    
    
}

