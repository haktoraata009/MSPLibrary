#Requires -Version 5.1

<#
.SYNOPSIS
    Reports the BitLocker encryption status for all fixed drives, raises alerts for unprotected or partially encrypted volumes, and optionally saves results to custom fields and assigns device tags.
.DESCRIPTION
    Reports the BitLocker encryption status for all fixed drives, raises alerts for unprotected or partially encrypted volumes, and optionally saves results to custom fields and assigns device tags.

.EXAMPLE
    (No Parameters)
    Scanning for BitLocker volumes.
    Filtering out USBs and CDs (if any).
    [Alert] The BitLocker volume at 'D:' has a volume status of 'FullyDecrypted'.
    [Alert] The BitLocker volume at 'D:' has a protection status of 'Off'.

    ### BitLocker Status Report ###
    MountPoint CapacityGB   VolumeStatus EncryptionPercentage KeyProtector
    ---------- ----------   ------------ -------------------- ------------
    C:           49.46777 FullyEncrypted                  100 {Tpm, RecoveryPassword}
    D:           126.9824 FullyDecrypted                    0 {}

.PARAMETER BitlockerStatusMultilineCustomField
    Name of a multiline custom field to save the BitLocker status report.

.PARAMETER BitlockerStatusWYSIWYGCustomField
    Name of a WYSIWYG custom field to save the BitLocker status report.

.PARAMETER BitlockerEnabledAllDrivesTagName
    Tag to assign when BitLocker is fully enabled on all drives.

.PARAMETER BitlockerPartialDrivesTagName
    Tag to assign when BitLocker is enabled on some but not all drives.

.PARAMETER BitlockerDisabledAllDrivesTagName
    Tag to assign when BitLocker is disabled on all drives.

.PARAMETER BitlockerKeyCustomField
    Name of a custom field to save the BitLocker recovery keys.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$BitlockerStatusMultilineCustomField = $env:bitlockerStatusMultilineCustomField,
    [Parameter()]
    [String]$BitlockerStatusWYSIWYGCustomField = $env:bitlockerStatusWysiwygCustomField,
    [Parameter()]
    [String]$BitlockerEnabledAllDrivesTagName = $env:bitlockerEnabledAllDrivesTagName,
    [Parameter()]
    [String]$BitlockerPartialDrivesTagName = $env:bitlockerPartialDrivesTagName,
    [Parameter()]
    [String]$BitlockerDisabledAllDrivesTagName = $env:bitlockerDisabledAllDrivesTagName,
    [Parameter()]
    [String]$BitlockerKeyCustomField = $env:bitlockerKeyCustomField
)

begin {
    #region OS Version Check
    # Check if the OS build is below 10240 (Windows 10 / Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }
    #endregion OS Version Check

    #region Validation
    # Validate BitLocker Status Multiline Custom Field if provided
    if ($BitlockerStatusMultilineCustomField) {
        if ([String]::IsNullOrWhiteSpace($BitlockerStatusMultilineCustomField)) {
            Write-Host -Object "[Error] BitLocker status multiline custom field name was provided but is empty or only whitespace."
            exit 1
        }

        $BitlockerStatusMultilineCustomField = $BitlockerStatusMultilineCustomField.Trim()

        if ($BitlockerStatusMultilineCustomField -match "[^0-9A-Za-z]") {
            Write-Host -Object "[Error] The 'BitLocker Status Multiline Custom Field' of '$BitlockerStatusMultilineCustomField' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Validate BitLocker Status WYSIWYG Custom Field if provided
    if ($BitlockerStatusWYSIWYGCustomField) {
        if ([String]::IsNullOrWhiteSpace($BitlockerStatusWYSIWYGCustomField)) {
            Write-Host -Object "[Error] BitLocker status WYSIWYG custom field name was provided but is empty or only whitespace."
            exit 1
        }

        $BitlockerStatusWYSIWYGCustomField = $BitlockerStatusWYSIWYGCustomField.Trim()

        if ($BitlockerStatusWYSIWYGCustomField -match "[^0-9A-Za-z]") {
            Write-Host -Object "[Error] The 'BitLocker Status WYSIWYG Custom Field' of '$BitlockerStatusWYSIWYGCustomField' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Validate BitLocker Enabled All Drives Tag Name if provided
    if ($BitlockerEnabledAllDrivesTagName) {
        if ([String]::IsNullOrWhiteSpace($BitlockerEnabledAllDrivesTagName)) {
            Write-Host -Object "[Error] BitLocker enabled all drives tag name was provided but is empty or only whitespace."
            exit 1
        }

        $BitlockerEnabledAllDrivesTagName = $BitlockerEnabledAllDrivesTagName.Trim()

        if ($BitlockerEnabledAllDrivesTagName.Length -gt 40) {
            Write-Host -Object "[Error] The 'BitLocker Enabled All Drives Tag Name' of '$BitlockerEnabledAllDrivesTagName' is invalid."
            Write-Host -Object "[Error] The tag name contains greater than 40 characters."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/34271351079821-Getting-Started-with-NinjaOne-Device-Tags"
            exit 1
        }
    }

    # Validate BitLocker Partial Drives Tag Name if provided
    if ($BitlockerPartialDrivesTagName) {
        if ([String]::IsNullOrWhiteSpace($BitlockerPartialDrivesTagName)) {
            Write-Host -Object "[Error] BitLocker partial drives tag name was provided but is empty or only whitespace."
            exit 1
        }

        $BitlockerPartialDrivesTagName = $BitlockerPartialDrivesTagName.Trim()

        if ($BitlockerPartialDrivesTagName.Length -gt 40) {
            Write-Host -Object "[Error] The 'BitLocker Partial Drives Tag Name' of '$BitlockerPartialDrivesTagName' is invalid."
            Write-Host -Object "[Error] The tag name contains greater than 40 characters."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/34271351079821-Getting-Started-with-NinjaOne-Device-Tags"
            exit 1
        }
    }

    # Validate BitLocker Disabled All Drives Tag Name if provided
    if ($BitlockerDisabledAllDrivesTagName) {
        if ([String]::IsNullOrWhiteSpace($BitlockerDisabledAllDrivesTagName)) {
            Write-Host -Object "[Error] BitLocker disabled all drives tag name was provided but is empty or only whitespace."
            exit 1
        }

        $BitlockerDisabledAllDrivesTagName = $BitlockerDisabledAllDrivesTagName.Trim()

        if ($BitlockerDisabledAllDrivesTagName.Length -gt 40) {
            Write-Host -Object "[Error] The 'BitLocker Disabled All Drives Tag Name' of '$BitlockerDisabledAllDrivesTagName' is invalid."
            Write-Host -Object "[Error] The tag name contains greater than 40 characters."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/34271351079821-Getting-Started-with-NinjaOne-Device-Tags"
            exit 1
        }
    }

    # Validate BitLocker Key Custom Field if provided
    if ($BitlockerKeyCustomField) {
        if ([String]::IsNullOrWhiteSpace($BitlockerKeyCustomField)) {
            Write-Host -Object "[Error] BitLocker key custom field name was provided but is empty or only whitespace."
            exit 1
        }

        $BitlockerKeyCustomField = $BitlockerKeyCustomField.Trim()

        if ($BitlockerKeyCustomField -match "[^0-9A-Za-z]") {
            Write-Host -Object "[Error] The 'BitLocker Key Custom Field' of '$BitlockerKeyCustomField' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }
    #endregion Validation

    #region Helper Functions
    function Test-IsElevated {
        [CmdletBinding()]
        param ()

        # Get the current Windows identity of the user running the script
        $WindowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()

        # Create a WindowsPrincipal object based on the current identity
        $WindowsPrincipal = New-Object -TypeName "System.Security.Principal.WindowsPrincipal" -ArgumentList $WindowsIdentity

        # Check if the current user is in the Administrator role
        # The function returns $True if the user has administrative privileges, $False otherwise
        # 544 is the value for the Built In Administrators role
        # Reference: https://learn.microsoft.com/dotnet/api/system.security.principal.windowsbuiltinrole
        $WindowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]'544')
    }
    #endregion Helper Functions

    # Initialize the exit code to 0 (success); individual operations may set it to 1
    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    #region Pre-flight Checks
    # Attempt to determine if the current session is running with Administrator privileges
    try {
        $IsElevated = Test-IsElevated -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running this script in an elevated session."
        exit 1
    }

    # Exit if the script is not running in an elevated session
    if (!$IsElevated) {
        Write-Host -Object "[Error] The user '$env:USERNAME' is not running this script in an elevated session. Please run this script as System or in an elevated session."
        exit 1
    }

    # Check if the BitLocker PowerShell module is available before proceeding
    try {
        $BitlockerModuleAvailable = Get-Module -Name BitLocker -ListAvailable -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to search for the BitLocker PowerShell module."
        exit 1
    }

    # Exit if the BitLocker module is not installed
    if (!$BitlockerModuleAvailable) {
        Write-Host -Object "[Error] The BitLocker PowerShell module is not available. Unable to continue."
        Write-Host -Object "[Error] https://learn.microsoft.com/powershell/module/bitlocker"
        exit 1
    }
    #endregion Pre-flight Checks

    #region Data Collection
    try {
        Write-Host -Object "Scanning for BitLocker volumes."
        $BitlockerVolumes = Get-BitLockerVolume -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve BitLocker volumes."
        exit 1
    }

    Write-Host -Object "Filtering out USBs and CDs (if any)."

    try {
        $RemovableDisks = Get-CimInstance -ClassName "Win32_Volume" -ErrorAction Stop | Where-Object { $_.DriveType -ne 3 } | Select-Object -Property DriveLetter
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to scan disks for non-fixed disks."
        exit 1
    }

    # Exclude removable and optical drives from the BitLocker volume list
    if ($RemovableDisks) {
        $BitlockerVolumes = $BitlockerVolumes | Where-Object { $RemovableDisks.DriveLetter -notcontains $_.MountPoint }
    }
    #endregion Data Collection

    #region Condition Alerts
    # Check each volume for alert conditions and report any issues found
    foreach ($Volume in $BitlockerVolumes) {
        # Alert if protection is active but encryption is not yet complete
        if ($Volume.ProtectionStatus -eq "On" -and $Volume.EncryptionPercentage -ne 100) {
            Write-Host -Object "[Alert] The BitLocker volume at '$($Volume.MountPoint)' has only been encrypted by '$($Volume.EncryptionPercentage)%'."
        }

        # Alert if the volume is in a state other than fully encrypted
        if ($Volume.VolumeStatus -ne "FullyEncrypted") {
            Write-Host -Object "[Alert] The BitLocker volume at '$($Volume.MountPoint)' has a volume status of '$($Volume.VolumeStatus)'."
        }

        # Alert if BitLocker protection is not turned on
        if ($Volume.ProtectionStatus -ne "On") {
            Write-Host -Object "[Alert] The BitLocker volume at '$($Volume.MountPoint)' has a protection status of '$($Volume.ProtectionStatus)'."
        }
    }

    Write-Host -Object "`n### BitLocker Status Report ###"
    ($BitlockerVolumes | Sort-Object -Property MountPoint |
        Format-Table -Property MountPoint, CapacityGB, VolumeStatus, EncryptionPercentage, KeyProtector -AutoSize | Out-String).Trim() | Write-Host
    #endregion Condition Alerts

    #region Tag Management
    # Categorize volumes by BitLocker protection state for tag assignment decisions
    $EnabledVolumes = $BitlockerVolumes | Where-Object { $_.ProtectionStatus -eq "On" -and $_.EncryptionPercentage -eq 100 }
    $DisabledVolumes = $BitlockerVolumes | Where-Object { $_.ProtectionStatus -eq "Off" }
    $PartialVolumes = $BitlockerVolumes | Where-Object { $EnabledVolumes -notcontains $_ -and $DisabledVolumes -notcontains $_ }

    # Retrieve the current device tags only when at least one tag parameter is provided
    if ($BitlockerEnabledAllDrivesTagName -or $BitlockerPartialDrivesTagName -or $BitlockerDisabledAllDrivesTagName) {
        Write-Host -Object "`nRetrieving assigned tags."
        try {
            $CurrentlyAssignedTags = Get-NinjaTag -ErrorAction Stop
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to retrieve the list of currently assigned tags."
            $ExitCode = 1
        }
    }

    # Manage the "all drives enabled" tag based on the current BitLocker state
    if ($BitlockerEnabledAllDrivesTagName) {
        # Remove the tag if any drives are not fully protected
        if ((!$EnabledVolumes -or $PartialVolumes -or $DisabledVolumes) -and $CurrentlyAssignedTags -contains $BitlockerEnabledAllDrivesTagName) {
            Write-Host -Object "Removing the tag '$BitlockerEnabledAllDrivesTagName' from the current device."
            try {
                Remove-NinjaTag -Name $BitlockerEnabledAllDrivesTagName -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to remove the tag '$BitlockerEnabledAllDrivesTagName'."
                $ExitCode = 1
            }
        }

        # Skip assignment if the tag is already correctly applied
        if (!$PartialVolumes -and !$DisabledVolumes -and $CurrentlyAssignedTags -contains $BitlockerEnabledAllDrivesTagName) {
            Write-Host -Object "The tag '$BitlockerEnabledAllDrivesTagName' is already assigned to this device."
        }

        # Assign the tag when all drives are fully protected
        if (!$PartialVolumes -and !$DisabledVolumes -and $CurrentlyAssignedTags -notcontains $BitlockerEnabledAllDrivesTagName) {
            Write-Host -Object "Assigning the tag '$BitlockerEnabledAllDrivesTagName' to the current device."
            try {
                Set-NinjaTag -Name $BitlockerEnabledAllDrivesTagName -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to set the tag '$BitlockerEnabledAllDrivesTagName'."
                $ExitCode = 1
            }
        }
    }

    # Manage the "partial drives" tag based on the current BitLocker state
    if ($BitlockerPartialDrivesTagName) {
        # Remove the tag if no drives are enabled or partially protected
        if (!$EnabledVolumes -and !$PartialVolumes -and $CurrentlyAssignedTags -contains $BitlockerPartialDrivesTagName) {
            Write-Host -Object "Removing the tag '$BitlockerPartialDrivesTagName' from the current device."
            try {
                Remove-NinjaTag -Name $BitlockerPartialDrivesTagName -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to remove the tag '$BitlockerPartialDrivesTagName'."
                $ExitCode = 1
            }
        }

        # Remove the tag if all drives are now fully protected (no longer a mixed state)
        if (!$PartialVolumes -and !$DisabledVolumes -and $CurrentlyAssignedTags -contains $BitlockerPartialDrivesTagName) {
            Write-Host -Object "Removing the tag '$BitlockerPartialDrivesTagName' from the current device."
            try {
                Remove-NinjaTag -Name $BitlockerPartialDrivesTagName -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to remove the tag '$BitlockerPartialDrivesTagName'."
                $ExitCode = 1
            }
        }

        # Skip assignment if the tag is already correctly applied
        if (($PartialVolumes -or ($EnabledVolumes -and $DisabledVolumes)) -and $CurrentlyAssignedTags -contains $BitlockerPartialDrivesTagName) {
            Write-Host -Object "The tag '$BitlockerPartialDrivesTagName' is already assigned to this device."
        }

        # Assign the tag when some drives are protected and others are not
        if (($PartialVolumes -or ($EnabledVolumes -and $DisabledVolumes)) -and $CurrentlyAssignedTags -notcontains $BitlockerPartialDrivesTagName) {
            Write-Host -Object "Assigning the tag '$BitlockerPartialDrivesTagName' to the current device."
            try {
                Set-NinjaTag -Name $BitlockerPartialDrivesTagName -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to set the tag '$BitlockerPartialDrivesTagName'."
                $ExitCode = 1
            }
        }
    }

    # Manage the "all drives disabled" tag based on the current BitLocker state
    if ($BitlockerDisabledAllDrivesTagName) {
        # Remove the tag if any drives have protection on or are in a partial state
        if ((!$DisabledVolumes -or $PartialVolumes -or $EnabledVolumes) -and $CurrentlyAssignedTags -contains $BitlockerDisabledAllDrivesTagName) {
            Write-Host -Object "Removing the tag '$BitlockerDisabledAllDrivesTagName' from the current device."
            try {
                Remove-NinjaTag -Name $BitlockerDisabledAllDrivesTagName -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to remove the tag '$BitlockerDisabledAllDrivesTagName'."
                $ExitCode = 1
            }
        }

        # Skip assignment if the tag is already correctly applied
        if (($DisabledVolumes -and !$PartialVolumes -and !$EnabledVolumes) -and $CurrentlyAssignedTags -contains $BitlockerDisabledAllDrivesTagName) {
            Write-Host -Object "The tag '$BitlockerDisabledAllDrivesTagName' is already assigned to this device."
        }

        # Assign the tag when all drives have BitLocker disabled
        if (($DisabledVolumes -and !$PartialVolumes -and !$EnabledVolumes) -and $CurrentlyAssignedTags -notcontains $BitlockerDisabledAllDrivesTagName) {
            Write-Host -Object "Assigning the tag '$BitlockerDisabledAllDrivesTagName' to the current device."
            try {
                Set-NinjaTag -Name $BitlockerDisabledAllDrivesTagName -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to set the tag '$BitlockerDisabledAllDrivesTagName'."
                $ExitCode = 1
            }
        }
    }
    #endregion Tag Management

    #region Key Retrieval
    if ($BitlockerKeyCustomField) {
        Write-Host -Object "`nAttempting to retrieve the BitLocker recovery keys."

        try {
            $EncryptedVolumes = Get-CimInstance -Namespace "root\CIMv2\Security\MicrosoftVolumeEncryption" -ClassName "Win32_EncryptableVolume" -ErrorAction Stop
            # Exclude removable drives from the encrypted volumes list
            if ($RemovableDisks) {
                $EncryptedVolumes = $EncryptedVolumes | Where-Object { $RemovableDisks.DriveLetter -notcontains $_.DriveLetter }
            }
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to retrieve all the encryption keys."
            $ExitCode = 1
        }

        $BitlockerKeys = New-Object -TypeName System.Collections.Generic.List[Object]
        # Retrieve all numerical recovery passwords for each encrypted volume
        foreach ($EncryptedVolume in $EncryptedVolumes) {
            # Retrieve key protector IDs of type RecoveryPassword (type 3)
            try {
                $KeyProtectorResult = Invoke-CimMethod -InputObject $EncryptedVolume -MethodName "GetKeyProtectors" -Arguments @{ KeyProtectorType = [uint32]3 } -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to retrieve a key protector for volume '$($EncryptedVolume.DriveLetter)'."
                $ExitCode = 1
            }

            # Retrieve the numerical password for each key protector
            foreach ($KeyId in $KeyProtectorResult.VolumeKeyProtectorID) {
                try {
                    $RecoveryKeyResult = Invoke-CimMethod -InputObject $EncryptedVolume -MethodName "GetKeyProtectorNumericalPassword" -Arguments @{ VolumeKeyProtectorID = $KeyId } -ErrorAction Stop

                    # Skip key protectors that do not have a numerical password
                    if (!$RecoveryKeyResult.NumericalPassword) { continue }

                    $BitlockerKeys.Add(
                        [PSCustomObject]@{
                            DriveLetter = $EncryptedVolume.DriveLetter
                            ProtectorID = $KeyId
                            RecoveryKey = $RecoveryKeyResult.NumericalPassword
                        }
                    )
                } catch {
                    Write-Host -Object "[Error] $($_.Exception.Message)"
                    Write-Host -Object "[Error] Failed to retrieve the numerical password for the key '$KeyId' on the volume '$($EncryptedVolume.DriveLetter)'."
                    $ExitCode = 1
                }
            }
        }

        # Alert for any encrypted volumes that are missing a stored recovery key
        if ($BitlockerKeys.Count -gt 0) {
            foreach ($BitlockerVolume in $BitlockerVolumes) {
                # Check if the current volume has a corresponding entry in the retrieved key list
                if ($BitlockerKeys.DriveLetter -notcontains $BitlockerVolume.MountPoint) {
                    Write-Host -Object "[Alert] No BitLocker key detected for the volume '$($BitlockerVolume.MountPoint)'."
                }
            }
        }

        # Alert if no recovery keys were found across all volumes
        if ($BitlockerKeys.Count -lt 1) { Write-Host -Object "[Alert] No BitLocker keys were found." }

        # Build a pipe-delimited string of drive letter and recovery key pairs
        Write-Host -Object "`nBuilding Custom Field Value."
        $CustomFieldValue = New-Object -TypeName "System.Text.StringBuilder"
        $i = 0
        foreach ($Key in $BitlockerKeys) {
            $i++

            [Void]$CustomFieldValue.Append("$($Key.DriveLetter) $($Key.RecoveryKey)")

            # Add a separator between entries, but not after the last one
            if ($i -lt $BitlockerKeys.Count) { [Void]$CustomFieldValue.Append(" | ") }
        }

        try {
            Write-Host -Object "Attempting to set the custom field '$BitlockerKeyCustomField'."
            Set-NinjaProperty -Name $BitlockerKeyCustomField -Value $CustomFieldValue.ToString() -ErrorAction Stop
            $KeysSaved = $True
            Write-Host -Object "Success."
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to save to the custom field '$BitlockerKeyCustomField'."
            $ExitCode = 1
        }
    }
    #endregion Key Retrieval

    #region Multiline Output
    if ($BitlockerStatusMultilineCustomField) {
        Write-Host -Object "`nAttempting to set the custom field '$BitlockerStatusMultilineCustomField'."

        # Enrich each volume with its corresponding recovery key status
        $VolumesWithKeys = foreach ($BitlockerVolume in $BitlockerVolumes) {
            # Find all recovery keys for this volume by matching the drive letter to the mount point
            $MatchingKeys = $BitlockerKeys | Where-Object { $_.DriveLetter -eq $BitlockerVolume.MountPoint }

            [PSCustomObject]@{
                MountPoint        = $BitlockerVolume.MountPoint
                Size              = "$([Math]::Round($BitlockerVolume.CapacityGB, 2)) GB"
                VolumeStatus      = $BitlockerVolume.VolumeStatus
                EncryptionPercent = "$($BitlockerVolume.EncryptionPercentage)%"
                KeyProtectors     = if ($BitlockerVolume.KeyProtector) { $($BitlockerVolume.KeyProtector -join ", ") } else { "None" }
                ProtectionStatus  = $BitlockerVolume.ProtectionStatus
                KeyStatus         = if ($MatchingKeys) { "Saved" } else { "Missing" }
            }
        }

        try {
            Set-NinjaProperty -Name $BitlockerStatusMultilineCustomField -Value $(($VolumesWithKeys | Format-List | Out-String).Trim()) -ErrorAction Stop
            Write-Host -Object "Success."
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to set the custom field '$BitlockerStatusMultilineCustomField'."
            $ExitCode = 1
        }
    }
    #endregion Multiline Output

    #region WYSIWYG Output
    if ($BitlockerStatusWYSIWYGCustomField) {
        Write-Host -Object "`nBuilding HTML report."

        $HtmlValue = New-Object -TypeName System.Collections.Generic.List[string]
        $HtmlValue.Add("<div>")

        # Build one card per BitLocker volume
        foreach ($BitlockerVolume in $BitlockerVolumes) {
            $MatchingKey = $BitlockerKeys | Where-Object { $_.DriveLetter -eq $BitlockerVolume.MountPoint }

            # Show a warning icon when a recovery key could not be retrieved
            $KeyStatusText = if ($MatchingKey) { "Key Status: Saved" } else {
                "<i class='fa-solid fa-triangle-exclamation' style='color: #FAC905'></i>&nbsp;&nbsp;Key Status: Missing"
            }

            # Determine the sidebar color based on protection status and encryption completeness
            $SidebarColor = if ($DisabledVolumes.MountPoint -contains $BitlockerVolume.MountPoint) {
                "#FF4B56"
            } elseif ($PartialVolumes.MountPoint -contains $BitlockerVolume.MountPoint -or !$MatchingKey) {
                "#FAC905"
            } else {
                "#008001"
            }

            $EncodedMountPoint = [System.Net.WebUtility]::HtmlEncode($BitlockerVolume.MountPoint)
            $EncodedProtectionStatus = [System.Net.WebUtility]::HtmlEncode($BitlockerVolume.ProtectionStatus)
            $EncodedVolumeStatus = [System.Net.WebUtility]::HtmlEncode($BitlockerVolume.VolumeStatus)

            # Build a comma-separated list of key protector types for this volume
            $KeyProtectorTypes = if ($BitlockerVolume.KeyProtector) {
                ($BitlockerVolume.KeyProtector | ForEach-Object { [System.Net.WebUtility]::HtmlEncode($_.KeyProtectorType) }) -join ", "
            } else {
                "None"
            }

            # Calculate the unencrypted portion as the complement of the encryption percentage
            $EncryptedPercent = $BitlockerVolume.EncryptionPercentage
            $UnencryptedPercent = 100 - $EncryptedPercent

            $HtmlValue.Add("
  <div class='card flex-grow-1' style='padding-left: 0px; width: 45em;'>
    <div class='container' style='white-space: nowrap; padding-left: 0px;'>
      <div class='row'>
        <div class='col-auto'>
          <div style='width: 5px; height: 100%; background-color: $SidebarColor;'></div>
        </div>
        <div class='col'>
          <div class='card-title-box'>
            <div class='card-title'><i class='fa-solid fa-hard-drive'></i>&nbsp;&nbsp;$EncodedMountPoint</div>
          </div>
          <div class='card-body' style='white-space: nowrap;'>
            <div class='container'>
              <div class='row' style='flex-wrap: nowrap;'>
                <div class='col-sm'>
                  <p class='card-text'>Protection Status: $EncodedProtectionStatus</p>
                  <p class='card-text'>Volume Status: $EncodedVolumeStatus</p>
                  <p class='card-text'>Key Protectors: $KeyProtectorTypes</p>
                </div>
                <div class='col-sm text-end' style='text-align: right;'>
                  <p class='card-text'>Size: $([Math]::Round($BitlockerVolume.CapacityGB, 2)) GB</p>
                  <p class='card-text'>$KeyStatusText</p>
                </div>
              </div>
              <div class='row'>
                <div class='p-2 linechart'>
                  <div style='width: $($EncryptedPercent)%; background-color: #09344F;'></div>
                  <div style='width: $($UnencryptedPercent)%; background-color: #04FF48;'></div>
                </div>
                <ul class='unstyled p-2' style='display: flex; justify-content: space-between;'>
                  <li style='white-space: nowrap;'>
                    <span class='chart-key' style='background-color: #09344F;'></span>
                    <span>Encrypted ($($EncryptedPercent)%)</span>
                  </li>
                  <li style='white-space: nowrap;'>
                    <span class='chart-key' style='background-color: #04FF48;'></span>
                    <span>Unencrypted ($($UnencryptedPercent)%)</span>
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>")
        }

        $HtmlValue.Add("</div>")

        try {
            Write-Host -Object "Attempting to set the custom field '$BitlockerStatusWYSIWYGCustomField'."
            Set-NinjaProperty -Name $BitlockerStatusWYSIWYGCustomField -Value $HtmlValue -Type "WYSIWYG" -ErrorAction Stop
            Write-Host -Object "Success."
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to set the custom field '$BitlockerStatusWYSIWYGCustomField'."
            $ExitCode = 1
        }
    }
    #endregion WYSIWYG Output

    exit $ExitCode
}
end {
    
    
    
}
