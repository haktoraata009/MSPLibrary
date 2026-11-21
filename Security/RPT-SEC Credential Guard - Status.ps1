#Requires -Version 5.1

<#
.SYNOPSIS
    Reports Credential Guard (incl. UEFI lock), VBS/HVCI, Secure Boot, TPM and BitLocker status.

.DESCRIPTION
    Version 1.0 of this script exits with "Incompatible with System" on any Windows 10/11 Pro device,
    because Credential Guard needs an Enterprise or Education licence. That gate fired before
    any other check, so Pro devices reported nothing useful. The original script also never
    checked BitLocker.

    This version:
      - Reads the edition from EditionID (not the localised Caption text).
      - Still reports Credential Guard licensing, but does not stop there.
      - Reads Credential Guard config from GPO, Intune (PolicyManager), the Lsa key and the
        Windows 11 22H2+ default, in that order, so "with/without UEFI lock" is found.
      - Uses Win32_DeviceGuard for the effective state (configured + running) of
        Credential Guard and HVCI, plus overall VBS state.
      - Reports Secure Boot, TPM and BitLocker on the OS drive (protection status,
        encryption %, key protector TYPES only - never the recovery password).

    Runs as SYSTEM under NinjaOne. No script variables.

    Custom fields to create (Text, Automations Read/Write):
      credentialGuardStatus - Credential Guard, config (UEFI lock), VBS and HVCI summary
      bitlockerSecureBootStatus - BitLocker on the OS drive, Secure Boot and TPM summary

.EXAMPLE
    (No parameters)

    Edition              : Professional
    CredentialGuard      : Not licensed (Professional edition)
    CGConfiguration      : Disabled [Default]
    VBS                  : Running
    HVCI                 : Running
    SecureBoot           : On
    TPM                  : Ready (2.0)
    BitLocker            : C: On, 100%, Tpm+RecoveryPassword

.NOTES
    Minimum OS: Windows 10, Windows 11, Windows Server 2016+
    Version: 2.0
    Release Notes: Edition gate no longer blocks reporting; GPO/Intune config paths;
                   VBS/HVCI/Secure Boot/TPM/BitLocker added; custom field name typo fixed.
#>

[CmdletBinding()]
param ()

begin {
    # Custom field names (case sensitive). NinjaOne finds the field by Name; no script variable needed.
    $TextCustomFieldName = "credentialGuardStatus"   # Text field: Credential Guard / VBS / HVCI summary
    # Text field: BitLocker / Secure Boot / TPM summary. Set to "" to append it to credentialGuardStatus instead.
    $BitLockerCustomFieldName = "bitlockerSecureBootStatus"

    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Set-NinjaTextField {
        param(
            [Parameter(Mandatory = $true)][string]$Name,
            [Parameter(Mandatory = $true)][string]$Value
        )
        Write-Host "[Info] Setting Ninja custom field '$Name'..."
        $result = Ninja-Property-Set -Name $Name -Value $Value 2>&1
        if ($result.Exception) { throw $result }
        Write-Host "[Info] Set '$Name' to '$Value'."
    }

    function Get-RegValue {
        param([string]$Path, [string]$Name)
        $item = Get-ItemProperty -Path "Registry::$Path" -ErrorAction SilentlyContinue
        if ($item) { return $item.$Name }
        return $null
    }

    function Get-CredentialGuardLicensing {
        # Credential Guard is only available on Enterprise / Education / Server 2016+.
        # A Pro device that was downgraded from Enterprise/Education keeps it running;
        # IsolatedCredentialsRootSecret marks that case (Microsoft Learn, Credential Guard overview).
        $editionId = Get-RegValue 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'EditionID'
        $build = [int](Get-RegValue 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'CurrentBuildNumber')
        $installationType = Get-RegValue 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'InstallationType'

        $licensed = $false
        if ($editionId -match '^(Enterprise|Education|IoTEnterprise|ServerRdsh)') { $licensed = $true }
        elseif ($installationType -match 'Server' -and $build -ge 14393) { $licensed = $true }
        elseif ($editionId -match '^Professional') {
            $secret = Get-RegValue 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0' 'IsolatedCredentialsRootSecret'
            if ($null -ne $secret) { $licensed = $true }
        }

        [PSCustomObject]@{
            EditionId = $editionId
            Build     = $build
            Licensed  = $licensed
        }
    }

    function Get-CredentialGuardConfiguration {
        # Precedence: GPO > Intune/MDM > local Lsa value > Windows 11 22H2+ default.
        # 0 = Disabled, 1 = Enabled with UEFI lock, 2 = Enabled without UEFI lock.
        $sources = @(
            @{ Source = 'GPO';     Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard';                Name = 'LsaCfgFlags' },
            @{ Source = 'Intune';  Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\current\device\DeviceGuard';   Name = 'LsaCfgFlags' },
            @{ Source = 'Local';   Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa';                          Name = 'LsaCfgFlags' },
            @{ Source = 'Default'; Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa';                          Name = 'LsaCfgFlagsDefault' }
        )
        foreach ($s in $sources) {
            $v = Get-RegValue $s.Path $s.Name
            if ($null -ne $v) {
                $text = switch ([int]$v) {
                    0 { 'Disabled' }
                    1 { 'Enabled with UEFI lock' }
                    2 { 'Enabled without UEFI lock' }
                    default { "Unknown value $v" }
                }
                return [PSCustomObject]@{ Status = $text; Source = $s.Source }
            }
        }
        return [PSCustomObject]@{ Status = 'Not configured'; Source = 'None' }
    }

    function Get-DeviceGuardState {
        # SecurityServices*: 1 = Credential Guard, 2 = HVCI (memory integrity).
        # VirtualizationBasedSecurityStatus: 0 = Off, 1 = Enabled not running, 2 = Running.
        $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace 'root\Microsoft\Windows\DeviceGuard' -ErrorAction SilentlyContinue
        if (-not $dg) {
            return [PSCustomObject]@{ VBS = 'Unavailable'; CGConfigured = $false; CGRunning = $false; HVCI = 'Unavailable' }
        }
        $vbs = switch ([int]$dg.VirtualizationBasedSecurityStatus) {
            0 { 'Off' }
            1 { 'Enabled, not running' }
            2 { 'Running' }
            default { 'Unknown' }
        }
        $hvci = if ($dg.SecurityServicesRunning -contains 2) { 'Running' }
                elseif ($dg.SecurityServicesConfigured -contains 2) { 'Configured, not running' }
                else { 'Off' }
        [PSCustomObject]@{
            VBS          = $vbs
            CGConfigured = ($dg.SecurityServicesConfigured -contains 1)
            CGRunning    = ($dg.SecurityServicesRunning -contains 1)
            HVCI         = $hvci
        }
    }

    function Get-SecureBootState {
        try {
            if (Confirm-SecureBootUEFI -ErrorAction Stop) { return 'On' } else { return 'Off' }
        }
        catch [System.PlatformNotSupportedException] { return 'Legacy BIOS' }
        catch { return 'Unknown' }
    }

    function Get-TpmState {
        try {
            $tpm = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction Stop
            if (-not $tpm) { return 'Not present' }
            $version = ($tpm.SpecVersion -split ',')[0].Trim()
            if ($tpm.IsEnabled_InitialValue -and $tpm.IsActivated_InitialValue) { return "Ready ($version)" }
            return "Present, not ready ($version)"
        }
        catch { return 'Unknown' }
    }

    function Get-BitLockerState {
        param([string]$MountPoint = $env:SystemDrive)
        # Key protector TYPES only. Never output the recovery password itself.
        if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
            try {
                $v = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction Stop
                $types = ($v.KeyProtector | ForEach-Object { $_.KeyProtectorType.ToString() } | Sort-Object -Unique) -join '+'
                if (-not $types) { $types = 'No protectors' }
                return "$MountPoint $($v.ProtectionStatus), $([int]$v.EncryptionPercentage)%, $types"
            }
            catch { }
        }
        # Fallback for devices without the BitLocker module (e.g. Server without the feature tools).
        try {
            $vol = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftVolumeEncryption' -ClassName Win32_EncryptableVolume -Filter "DriveLetter='$MountPoint'" -ErrorAction Stop
            if (-not $vol) { return "$MountPoint Not encryptable" }
            $prot = (Invoke-CimMethod -InputObject $vol -MethodName GetProtectionStatus).ProtectionStatus
            $pct = (Invoke-CimMethod -InputObject $vol -MethodName GetConversionStatus).EncryptionPercentage
            $protText = switch ([int]$prot) { 0 { 'Off' } 1 { 'On' } default { 'Unknown' } }
            return "$MountPoint $protText, $([int]$pct)%"
        }
        catch { return "$MountPoint Unknown" }
    }
}

process {
    if (-not (Test-IsElevated)) {
        Write-Host "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    $ExitCode = 0

    $lic    = Get-CredentialGuardLicensing
    $cfg    = Get-CredentialGuardConfiguration
    $dg     = Get-DeviceGuardState
    $secure = Get-SecureBootState
    $tpm    = Get-TpmState
    $bl     = Get-BitLockerState

    if (-not $lic.Licensed) {
        $cgStatus = "Not licensed ($($lic.EditionId) edition)"
    }
    elseif ($dg.CGRunning) {
        $cgStatus = 'Running'
    }
    elseif ($dg.CGConfigured) {
        $cgStatus = 'Configured, not running (restart pending?)'
    }
    else {
        $cgStatus = 'Not running'
    }

    $cgConfigText = if ($cfg.Source -eq 'None') { $cfg.Status } else { "$($cfg.Status) [$($cfg.Source)]" }

    $result = [PSCustomObject]@{
        Edition         = $lic.EditionId
        CredentialGuard = $cgStatus
        CGConfiguration = $cgConfigText
        VBS             = $dg.VBS
        HVCI            = $dg.HVCI
        SecureBoot      = $secure
        TPM             = $tpm
        BitLocker       = $bl
    }

    # Warnings for states that need action.
    if ($cfg.Status -eq 'Disabled' -and $dg.CGRunning) {
        Write-Host "[Warning] Credential Guard is disabled in config but still running."
        Write-Host "          Restart needed, or it is UEFI locked and must be cleared with the opt-out tool."
        Write-Host "          https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/configure#disable-credential-guard-with-uefi-lock"
    }
    if ($bl -notmatch ' On,') {
        Write-Host "[Warning] BitLocker protection is not On for $env:SystemDrive."
    }
    if ($secure -ne 'On') {
        Write-Host "[Warning] Secure Boot is $secure."
    }

    # Custom field output. Short text so it fits a Ninja Text field.
    $cgSummary = "CG: $cgStatus | Cfg: $cgConfigText | VBS: $($dg.VBS) | HVCI: $($dg.HVCI)"
    $blSummary = "BitLocker: $bl | SecureBoot: $secure | TPM: $tpm"

    if ($TextCustomFieldName) {
        $value = if ($BitLockerCustomFieldName) { $cgSummary } else { "$cgSummary | $blSummary" }
        try { Set-NinjaTextField -Name $TextCustomFieldName -Value $value }
        catch {
            Write-Host "[Error] Failed to set custom field '$TextCustomFieldName' to '$value'."
            Write-Host "$($_.Exception.Message)"
            $ExitCode = 1
        }
    }
    if ($BitLockerCustomFieldName) {
        try { Set-NinjaTextField -Name $BitLockerCustomFieldName -Value $blSummary }
        catch {
            Write-Host "[Error] Failed to set custom field '$BitLockerCustomFieldName' to '$blSummary'."
            Write-Host "$($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    $result | Format-List | Out-String | Write-Host
    exit $ExitCode
}
