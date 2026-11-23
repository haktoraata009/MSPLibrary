#Requires -Version 5.1

<#
.SYNOPSIS
    Counts unencrypted fixed drives, alerts on exit code 2, and writes the
    bitlockerSecureBootStatus custom field (BitLocker, Secure Boot, TPM).
.DESCRIPTION
    Returns the number of fixed (non-USB) drives in the Unlocked and FullyDecrypted state.

    Also writes the Text custom field bitlockerSecureBootStatus with the same summary as
    RPT-SEC Credential Guard - Status, so the field reads the same whichever script ran last:
      BitLocker: C: On, 100%, RecoveryPassword+Tpm | SecureBoot: On | TPM: Ready (2.0)
    Works on every Windows edition (Pro, Business, Enterprise, Education). No Credential
    Guard licence needed. Never outputs the BitLocker recovery password (key protector TYPES only).

    No script variables: do not add any under Script Variables in NinjaOne. The field name is
    fixed in the begin block ($BitLockerCustomFieldName). Set it to "" to skip the field write.

    Custom field to create (Text, Automations Read/Write):
      bitlockerSecureBootStatus - BitLocker on the OS drive, Secure Boot and TPM summary

    Exit codes:
      0 = no unencrypted fixed drive and the field was written
      1 = not run elevated, or the custom field write failed
      2 = one or more unencrypted fixed drives (takes priority over 1)
.EXAMPLE
    No parameters needed.

    Unencrypted Disk Count: 0
    [Info] Setting Ninja custom field 'bitlockerSecureBootStatus'...
    [Info] Set 'bitlockerSecureBootStatus' to 'BitLocker: C: On, 100%, RecoveryPassword+Tpm | SecureBoot: On | TPM: Ready (2.0)'.
.OUTPUTS
    int
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Uses Get-BitLockerVolume, falls back on manage-bde.exe for the drive count and on
    Win32_EncryptableVolume for the field summary.
    Version: 2.0
    Release Notes: 1.1 Renamed script. 1.2 Header states it writes no custom field.
                   2.0 Writes bitlockerSecureBootStatus (same format as RPT-SEC Credential Guard - Status);
                   needs PowerShell 5.1; exit 1 when the field write fails.
.COMPONENT
    Misc
#>

[CmdletBinding()]
param ()

begin {
    # Custom field name (case sensitive). NinjaOne finds the field by Name; no script variable needed.
    # Text field: BitLocker / Secure Boot / TPM summary. Set to "" to skip the field write.
    $BitLockerCustomFieldName = "bitlockerSecureBootStatus"

    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        if ($p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
        { Write-Output $true }
        else
        { Write-Output $false }
    }
    function Get-DriveLetter {
        param()
        Get-Disk | Where-Object { $_.bustype -ne 'USB' } | Get-Partition | Where-Object { $_.DriveLetter } | Select-Object -ExpandProperty DriveLetter
    }
    function Invoke-ManageBDE {
        [CmdletBinding()]
        param ()
        # Check if manage-bde.exe is available
        if ((Get-Command -Name "manage-bde.exe" -ErrorAction SilentlyContinue)) {
            # Get physical drives
            Get-DriveLetter | ForEach-Object {
                $DriveLetter = $_
                $ReturnObj = [PSCustomObject]@{
                    MountPoint = "$_`:"
                }
                # Get data from manage-bde.exe and convert the text to objects for easier processing
                (manage-bde.exe -status "$_`:") -split "`n" | Where-Object { $_ -like "*:*" } | ForEach-Object {
                    $First = ($_ -split ":")[0].Trim() -replace ' '
                    $Last = ($_ -split ":")[1].Trim() -replace ' '
                    if ($First -notlike "Name" -and $First -notlike "BitLocker Drive Encryption" -and $First -notlike "Volume $DriveLetter") {
                        if ($First -like "ConversionStatus") {
                            # Renames ConversionStatus to VolumeStatus to match Get-BitLockerVolume's output
                            $ReturnObj | Add-Member -MemberType NoteProperty -Name "VolumeStatus" -Value $Last
                        }
                        else {
                            $ReturnObj | Add-Member -MemberType NoteProperty -Name $First -Value $Last
                        }
                    }
                }
                $ReturnObj
            } | Select-Object MountPoint, LockStatus, VolumeStatus
        }
        else {
            Write-Host "Windows Feature BitLocker is not install."
            Write-Output 0
        }
    }

    # The four functions below are copied from RPT-SEC Credential Guard - Status v2.0.1.
    # Keep them identical so both scripts write the same text to bitlockerSecureBootStatus.
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
        Write-Error -Message "Access Denied. Please run with Administrator privileges."
        exit 1
    }
    $Result = if ($PSVersionTable.PSVersion.Major -le 4) {
        Invoke-ManageBDE
    }
    else {
        try {
            Get-DriveLetter | Get-BitLockerVolume | Select-Object MountPoint, LockStatus, VolumeStatus
        }
        catch {
            Write-Output "Falling back on manage-bde.exe"
            Invoke-ManageBDE
        }
    }
    $UnencryptedDisks = if ($Result) {
        (($Result | Where-Object { "Unlocked" -like $_.LockStatus -and "FullyDecrypted" -like $_.VolumeStatus }).LockStatus).Count
    }
    else {
        (Get-DriveLetter).Count
    }

    # Return a count of Unlocked drives
    Write-Host "Unencrypted Disk Count: $UnencryptedDisks"

    # Custom field: same format as RPT-SEC Credential Guard - Status.
    $FieldFailed = $false
    if ($BitLockerCustomFieldName) {
        $blSummary = "BitLocker: $(Get-BitLockerState) | SecureBoot: $(Get-SecureBootState) | TPM: $(Get-TpmState)"
        try { Set-NinjaTextField -Name $BitLockerCustomFieldName -Value $blSummary }
        catch {
            Write-Host "[Error] Failed to set custom field '$BitLockerCustomFieldName' to '$blSummary'."
            Write-Host "$($_.Exception.Message)"
            $FieldFailed = $true
        }
    }

    # Return an exit code of 2 if one or more disks are unencrypted (alert wins over a field error)
    if ($UnencryptedDisks -gt 0) {
        exit 2
    }
    if ($FieldFailed) {
        exit 1
    }
    exit 0
}
end {



}
