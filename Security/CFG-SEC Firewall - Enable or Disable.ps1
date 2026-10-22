#Requires -Version 5.1

<#
.SYNOPSIS
    Enable or disable all Windows Firewall profiles (Domain, Public, Private). You can also choose whether to block inbound traffic by default.
.DESCRIPTION
    Enable or disable all Windows Firewall profiles (Domain, Public, Private). You can also choose whether to block inbound traffic by default.
.PARAMETER Enable
    Enables all Windows Firewall profiles (Domain, Public, Private).
.PARAMETER Disable
    Disables all Windows Firewall profiles (Domain, Public, Private).
.PARAMETER DefaultActionForInboundTraffic
    Allow or Block inbound traffic that doesn't match a rule in all Windows Firewall profiles (Domain, Public, Private).
.EXAMPLE
    -Disable
    [Info] Successfully set Domain firewall profile to disabled.
    [Info] Successfully set Private firewall profile to disabled.
    [Info] Successfully set Public firewall profile to disabled.

    ProfileName Enabled DefaultInboundAction
    ----------- ------- --------------------
    Domain        False        NotConfigured
    Private       False        NotConfigured
    Public        False        NotConfigured
.EXAMPLE
    -Enable
    [Info] Successfully set Domain firewall profile to enabled.
    [Info] Successfully set Private firewall profile to enabled.
    [Info] Successfully set Public firewall profile to enabled.

    ProfileName Enabled DefaultInboundAction
    ----------- ------- --------------------
    Domain         True        NotConfigured
    Private        True        NotConfigured
    Public         True        NotConfigured
.EXAMPLE
    -Enable -DefaultActionForInboundTraffic "Block"
    [Info] Successfully set Domain to enabled and inbound traffic to blocked.
    [Info] Successfully set Private to enabled and inbound traffic to blocked.
    [Info] Successfully set Public to enabled and inbound traffic to blocked.

    ProfileName Enabled DefaultInboundAction
    ----------- ------- --------------------
    Domain         True                Block
    Private        True                Block
    Public         True                Block
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.2
    Release Notes: Renamed script.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [switch]$Enable,
    [Parameter()]
    [switch]$Disable,
    [Parameter()]
    [string]$DefaultActionForInboundTraffic
)

begin {
    switch ($env:enableOrDisable) {
        "Enable" { $Enable = $True }
        "Disable" { $Disable = $True }
    }

    if ($env:defaultActionForInboundTraffic){
        $DefaultActionForInboundTraffic = $env:defaultActionForInboundTraffic
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
}
process {
    if (-not (Test-IsElevated)) {
        Write-Host "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    if ($Enable -and $Disable) {
        Write-Host "[Error] Can not enable and disable the firewall at the same time."
        exit 1
    }

    if (-not $Enable -and -not $Disable) {
        Write-Host "[Error] Either Enable or Disable must be selected."
        exit 1
    }

    if ($DefaultActionForInboundTraffic -and $DefaultActionForInboundTraffic -notmatch "^Allow$|^Block$"){
        Write-Host "[Error] Invalid inbound traffic action provided. Valid options are 'Allow' and 'Block'."
        exit 1
    }

    $ExitCode = 0

    # set up variables with expected values
    if ($Enable) {
        $expectedEnabledOrDisabledValue = "enabled"
        $expectedTrueOrFalseValue = "True"
    }
    else {
        $expectedEnabledOrDisabledValue = "disabled"
        $expectedTrueOrFalseValue = "False"
    }

    $expectedAllowedOrBlockedValue = switch ($DefaultActionForInboundTraffic){
        "Allow" {"allowed"}
        "Block" {"blocked"}
    }

    # set up array of firewall profiles
    $profiles = "Domain", "Private", "Public"

    # set up splat that will be added to depending on settings needed
    $NetFirewallSplat = @{
        ErrorAction = "Stop"
    }

    foreach ($profileName in $profiles) {
        # get the settings of the current profile
        $profileSettings = Get-NetFirewallProfile $profileName

        # add the profile to the splat
        $NetFirewallSplat.Profile = $profileName

        # if the profile is already set to on/off and we are not blocking inbound traffic, continue on to the next profile
        # otherwise add the desired setting to the splat
        if ($profileSettings.Enabled -eq $expectedTrueOrFalseValue -and -not $DefaultActionForInboundTraffic) {
            Write-Host "[Info] $profileName profile is already set to $expectedEnabledOrDisabledValue."
            continue
        }
        else {
            $NetFirewallSplat.Enabled = "$expectedTrueOrFalseValue"
        }

        # if we are changing the inbound traffic action and all required settings are already set, continue on to the next profile
        # otherwise add the required values to the splat
        if ($DefaultActionForInboundTraffic -and $profileSettings.DefaultInboundAction -eq $DefaultActionForInboundTraffic -and $profileSettings.DefaultOutboundAction -eq "Allow" -and $profileSettings.Enabled -eq $expectedTrueOrFalseValue) {
            Write-Host "[Info] $profileName profile is already $expectedEnabledOrDisabledValue and inbound traffic is already $expectedAllowedOrBlockedValue."
            continue
        }
        elseif ($DefaultActionForInboundTraffic) {
            $NetFirewallSplat.DefaultInboundAction = $DefaultActionForInboundTraffic
            $NetFirewallSplat.DefaultOutboundAction = "Allow"
        }

        # if the splat has either of these settings populated, proceed with trying to set them
        if ($NetFirewallSplat.Enabled -or $NetFirewallSplat.DefaultInboundAction) {
            try {
                Set-NetFirewallProfile @NetFirewallSplat

                # output success message
                if (-not $NetFirewallSplat.DefaultInboundAction) {
                    Write-Host "[Info] Successfully set $profileName firewall profile to $expectedEnabledOrDisabledValue."
                }
                else {
                    Write-Host "[Info] Successfully set $profileName to $expectedEnabledOrDisabledValue and inbound traffic to $expectedAllowedOrBlockedValue."
                }
            }
            catch {
                Write-Host "[Error] Error while changing settings for the $profileName firewall profile."
                Write-Host "[Error] $($_.Exception.Message)"
                $ExitCode = 1
            }
        }

        # clear splat settings
        $NetFirewallSplat.Remove("Profile")
        $NetFirewallSplat.Remove("Enabled")
        $NetFirewallSplat.Remove("DefaultInboundAction")
        $NetFirewallSplat.Remove("DefaultOutboundAction")
    }

    # output status of all firewall profiles after the loop
    Get-NetFirewallProfile | Sort-Object Name | Format-Table @{n = "ProfileName"; e = { $_.Name } }, Enabled, DefaultInboundAction

    exit $ExitCode
}
end {
    
    
    
}

