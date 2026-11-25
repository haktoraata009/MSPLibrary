#Requires -Version 5.1

<#
.SYNOPSIS
    Writes four one-line Text custom fields for client reports and Halo sync:
    OS support status, Windows 11 readiness, hardware summary and disk space summary.

.DESCRIPTION
    Halo can only sync single-line Text custom fields from NinjaOne. This script writes short
    one-line values that start with OK, WARN or FAIL, so a Halo report can count devices by
    status with a "starts with" filter.

      osSupportStatus    OS name, version, build and the Microsoft end-of-servicing date.
                         Windows 10 22H2: also checks for an active commercial ESU licence.
      win11Ready         Windows 11 hardware readiness. Uses the Windows compatibility appraiser
                         result when present, plus TPM, UEFI/Secure Boot, RAM, disk and CPU checks.
      hardwareSummary    Make and model, CPU, RAM and system disk type and size.
      diskSpaceSummary   Free space on each fixed local volume.

    Status rules:
      osSupportStatus    FAIL past end of servicing (no ESU) | WARN within 180 days, on ESU, or build
                         not in the table | OK otherwise.
      win11Ready         FAIL a hard requirement is missing | WARN CPU not verified | OK ready.
      hardwareSummary    FAIL HDD system disk or under 8 GB RAM | WARN 8 GB RAM or older CPU | OK.
      diskSpaceSummary   FAIL any volume under 10% free | WARN under 20% | OK.

    End-of-servicing dates are in $SupportTable below, from the Microsoft Lifecycle pages.
    Dates marked Estimated follow the published servicing policy (24 months Home/Pro, 36 months
    Enterprise/Education for H2 releases) and should be checked when Microsoft publishes them.
    Update the table when a new Windows version ships; an unknown build reports WARN.

    No script variables: do not add any under Script Variables in NinjaOne. The field names are
    fixed in the begin block. Set a field name to "" to skip that field.

    Custom fields to create (Text, Automations Read/Write):
      osSupportStatus, win11Ready, hardwareSummary, diskSpaceSummary

.EXAMPLE
    (No parameters)

    osSupportStatus  : OK: Windows 11 Pro 25H2 (26200.7171) - supported to 2027-10-12 (321 days)
    win11Ready       : OK: on Windows 11, hardware supported (TPM 2.0, Secure Boot on)
    hardwareSummary  : OK: Dell Latitude 7450 | Intel Core Ultra 5 135U | 16 GB RAM | SSD 477 GB
    diskSpaceSummary : OK: C: 62% free (296 of 476 GB)

.NOTES
    Minimum OS: Windows 10, Windows 11, Windows Server 2016+
    Run as: System
    Version: 1.0
    Release Notes: 1.0 (2026-11-25) First version.
#>

[CmdletBinding()]
param ()

begin {
    # Custom field names (case sensitive). NinjaOne finds the field by Name; no script variable needed.
    $OsFieldName       = "osSupportStatus"
    $Win11FieldName    = "win11Ready"
    $HardwareFieldName = "hardwareSummary"
    $DiskFieldName     = "diskSpaceSummary"

    $MaxFieldLength = 200    # keep each value to one short line
    $WarnDays       = 180    # osSupportStatus: WARN when end of servicing is this close

    # End of servicing by build. Family: HomePro | Enterprise | LTSC | IoTLTSC | Server.
    # Sources: Microsoft Lifecycle pages and Windows release information (checked 2026-11-25).
    $SupportTable = @(
        # Windows 11
        @{ Build = 26300; Family = 'HomePro';    Name = 'Windows 11'; Version = '26H2'; End = '2028-10-10'; Estimated = $true }
        @{ Build = 26300; Family = 'Enterprise'; Name = 'Windows 11'; Version = '26H2'; End = '2029-10-09'; Estimated = $true }
        @{ Build = 26200; Family = 'HomePro';    Name = 'Windows 11'; Version = '25H2'; End = '2027-10-12' }
        @{ Build = 26200; Family = 'Enterprise'; Name = 'Windows 11'; Version = '25H2'; End = '2028-10-10' }
        @{ Build = 26100; Family = 'HomePro';    Name = 'Windows 11'; Version = '24H2'; End = '2026-10-13' }
        @{ Build = 26100; Family = 'Enterprise'; Name = 'Windows 11'; Version = '24H2'; End = '2027-10-12' }
        @{ Build = 26100; Family = 'LTSC';       Name = 'Windows 11'; Version = 'LTSC 2024'; End = '2029-10-09' }
        @{ Build = 26100; Family = 'IoTLTSC';    Name = 'Windows 11'; Version = 'IoT LTSC 2024'; End = '2034-10-10' }
        @{ Build = 22631; Family = 'HomePro';    Name = 'Windows 11'; Version = '23H2'; End = '2025-11-11' }
        @{ Build = 22631; Family = 'Enterprise'; Name = 'Windows 11'; Version = '23H2'; End = '2026-11-10' }
        @{ Build = 22621; Family = 'HomePro';    Name = 'Windows 11'; Version = '22H2'; End = '2024-10-08' }
        @{ Build = 22621; Family = 'Enterprise'; Name = 'Windows 11'; Version = '22H2'; End = '2025-10-14' }
        @{ Build = 22000; Family = 'HomePro';    Name = 'Windows 11'; Version = '21H2'; End = '2023-10-10' }
        @{ Build = 22000; Family = 'Enterprise'; Name = 'Windows 11'; Version = '21H2'; End = '2024-10-08' }
        # Windows 10
        @{ Build = 19045; Family = 'HomePro';    Name = 'Windows 10'; Version = '22H2'; End = '2025-10-14' }
        @{ Build = 19045; Family = 'Enterprise'; Name = 'Windows 10'; Version = '22H2'; End = '2025-10-14' }
        @{ Build = 19044; Family = 'HomePro';    Name = 'Windows 10'; Version = '21H2'; End = '2023-06-13' }
        @{ Build = 19044; Family = 'Enterprise'; Name = 'Windows 10'; Version = '21H2'; End = '2024-06-11' }
        @{ Build = 19044; Family = 'LTSC';       Name = 'Windows 10'; Version = 'LTSC 2021'; End = '2027-01-12' }
        @{ Build = 19044; Family = 'IoTLTSC';    Name = 'Windows 10'; Version = 'IoT LTSC 2021'; End = '2032-01-13' }
        @{ Build = 17763; Family = 'LTSC';       Name = 'Windows 10'; Version = 'LTSC 2019'; End = '2029-01-09' }
        @{ Build = 17763; Family = 'IoTLTSC';    Name = 'Windows 10'; Version = 'IoT LTSC 2019'; End = '2029-01-09' }
        @{ Build = 14393; Family = 'LTSC';       Name = 'Windows 10'; Version = 'LTSB 2016'; End = '2026-10-13' }
        # Windows Server (extended support end)
        @{ Build = 26100; Family = 'Server';     Name = 'Windows Server'; Version = '2025'; End = '2034-11-14' }
        @{ Build = 20348; Family = 'Server';     Name = 'Windows Server'; Version = '2022'; End = '2031-10-14' }
        @{ Build = 17763; Family = 'Server';     Name = 'Windows Server'; Version = '2019'; End = '2029-01-09' }
        @{ Build = 14393; Family = 'Server';     Name = 'Windows Server'; Version = '2016'; End = '2027-01-12' }
        @{ Build = 9600;  Family = 'Server';     Name = 'Windows Server'; Version = '2012 R2'; End = '2023-10-10' }
    )

    # Windows 10 commercial ESU activation IDs (Microsoft Learn, "Enable Extended Security Updates").
    $EsuYears = @(
        @{ Year = 3; Id = '83d49986-add3-41d7-ba33-87c7bfb5c0fb'; End = '2028-10-10' }
        @{ Year = 2; Id = '1043add5-23b1-4afb-9a0f-64343c8f3f8d'; End = '2027-10-12' }
        @{ Year = 1; Id = 'f520e45e-7413-4a34-a497-d2765967d094'; End = '2026-10-13' }
    )

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

    function Limit-Text {
        param([string]$Text, [int]$Max = $MaxFieldLength)
        if ($Text.Length -le $Max) { return $Text }
        return $Text.Substring(0, $Max - 3) + '...'
    }

    function Get-RegValue {
        param([string]$Path, [string]$Name)
        $item = Get-ItemProperty -Path "Registry::$Path" -ErrorAction SilentlyContinue
        if ($item) { return $item.$Name }
        return $null
    }

    function Get-OsInfo {
        $cv = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $build = [int](Get-RegValue $cv 'CurrentBuildNumber')
        $ubr = Get-RegValue $cv 'UBR'
        $editionId = [string](Get-RegValue $cv 'EditionID')
        $installationType = [string](Get-RegValue $cv 'InstallationType')
        $displayVersion = Get-RegValue $cv 'DisplayVersion'
        if (-not $displayVersion) { $displayVersion = Get-RegValue $cv 'ReleaseId' }

        $family = if ($installationType -match 'Server') { 'Server' }
                  elseif ($editionId -match '^IoTEnterpriseS') { 'IoTLTSC' }
                  elseif ($editionId -match '^EnterpriseS') { 'LTSC' }
                  elseif ($editionId -match '^(Enterprise|Education|IoTEnterprise)') { 'Enterprise' }
                  else { 'HomePro' }

        # Edition label without relying on ProductName (Windows 11 still says "Windows 10" there).
        $edition = switch -Regex ($editionId) {
            '^Professional' { 'Pro'; break }
            '^Core'         { 'Home'; break }
            '^EnterpriseS'  { 'Enterprise'; break }
            '^Enterprise'   { 'Enterprise'; break }
            '^Education'    { 'Education'; break }
            '^IoTEnterprise' { 'IoT Enterprise'; break }
            default         { $editionId }
        }
        if ($family -eq 'Server') { $edition = '' }

        [PSCustomObject]@{
            Build          = $build
            Ubr            = $ubr
            EditionId      = $editionId
            Edition        = $edition
            Family         = $family
            DisplayVersion = $displayVersion
        }
    }

    function Get-EsuYear {
        # Highest Windows 10 commercial ESU year with an active licence, or $null.
        foreach ($esu in $EsuYears) {
            try {
                $p = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ID='$($esu.Id)'" -ErrorAction Stop
                if ($p -and [int]$p.LicenseStatus -eq 1) { return $esu }
            }
            catch { }
        }
        return $null
    }

    function Get-OsSupportStatus {
        param($Os)
        $today = (Get-Date).Date
        $buildText = if ($null -ne $Os.Ubr) { "$($Os.Build).$($Os.Ubr)" } else { "$($Os.Build)" }

        $row = $SupportTable | Where-Object { $_.Build -eq $Os.Build -and $_.Family -eq $Os.Family } | Select-Object -First 1
        if (-not $row) {
            $name = if ($Os.Family -eq 'Server') { 'Windows Server' } elseif ($Os.Build -ge 22000) { 'Windows 11' } else { 'Windows 10' }
            return "WARN: $name $($Os.Edition) $($Os.DisplayVersion) ($buildText) - build not in script table, check support date" -replace '\s+', ' '
        }

        $end = [datetime]::ParseExact($row.End, 'yyyy-MM-dd', $null)
        $days = [int]($end - $today).TotalDays
        $label = ("$($row.Name) $($Os.Edition) $($row.Version) ($buildText)" -replace '\s+', ' ').Trim()
        $est = if ($row.Estimated) { ' (est.)' } else { '' }

        if ($days -lt 0) {
            if ($Os.Build -eq 19045 -and $Os.Family -ne 'LTSC') {
                $esu = Get-EsuYear
                if ($esu) {
                    $esuEnd = [datetime]::ParseExact($esu.End, 'yyyy-MM-dd', $null)
                    $esuDays = [int]($esuEnd - $today).TotalDays
                    if ($esuDays -ge 0) {
                        return "WARN: $label - support ended $($row.End), on ESU Year $($esu.Year) to $($esu.End) ($esuDays days)"
                    }
                    return "FAIL: $label - support ended $($row.End), ESU Year $($esu.Year) ended $($esu.End)"
                }
                return "FAIL: $label - support ended $($row.End), no ESU licence found"
            }
            return "FAIL: $label - support ended $($row.End)"
        }
        if ($days -le $WarnDays) {
            return "WARN: $label - support ends $($row.End)$est ($days days)"
        }
        return "OK: $label - supported to $($row.End)$est ($days days)"
    }

    function Get-TpmInfo {
        try {
            $tpm = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction Stop
            if (-not $tpm) { return [PSCustomObject]@{ Version = 'none'; Ready = $false } }
            $version = ($tpm.SpecVersion -split ',')[0].Trim()
            [PSCustomObject]@{ Version = $version; Ready = [bool]($tpm.IsEnabled_InitialValue -and $tpm.IsActivated_InitialValue) }
        }
        catch { [PSCustomObject]@{ Version = 'unknown'; Ready = $false } }
    }

    function Get-SecureBootState {
        try {
            if (Confirm-SecureBootUEFI -ErrorAction Stop) { return 'On' } else { return 'Off' }
        }
        catch [System.PlatformNotSupportedException] { return 'Legacy BIOS' }
        catch { return 'Unknown' }
    }

    function Get-CpuSupportGuess {
        # Rough guide only. The compatibility appraiser result (when present) is authoritative.
        param([string]$CpuName)
        if ($CpuName -match 'Core\(TM\) Ultra|Core Ultra|Ryzen AI|Snapdragon') { return 'Supported' }
        if ($CpuName -match 'Core\(TM\) i[3579]-(\d{4,5})') {
            $num = $Matches[1]
            # 5 digits (10700) or 4 digits starting with 1 (1135G7, 1365U): generation = first two digits.
            $gen = if ($num.Length -eq 5 -or $num.StartsWith('1')) { [int]$num.Substring(0, 2) } else { [int]$num.Substring(0, 1) }
            if ($gen -ge 8) { return 'Supported' } else { return 'Unsupported' }
        }
        if ($CpuName -match 'Core\(TM\) [3579] ') { return 'Supported' }   # Core 3/5/7 series (2023+)
        if ($CpuName -match 'Ryzen [3579] (PRO )?\d{3}\b') { return 'Supported' }   # Ryzen 200 series naming (2025+)
        if ($CpuName -match 'Ryzen (Threadripper )?(PRO )?\d (PRO )?(\d)\d{3}') {
            $series = [int]$Matches[4]
            if ($series -ge 3) { return 'Supported' }
            if ($series -le 1) { return 'Unsupported' }
            return 'Unknown'
        }
        return 'Unknown'
    }

    function Get-AppraiserResult {
        # Windows compatibility appraiser: one subkey per target release, for example GE24H2.
        $base = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators'
        $keys = Get-ChildItem -Path $base -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '(\d{2})H(\d)$' }
        if (-not $keys) { return $null }
        $latest = $keys | Sort-Object { if ($_.PSChildName -match '(\d{2})H(\d)$') { [int]("$($Matches[1])$($Matches[2])") } else { 0 } } | Select-Object -Last 1
        $p = Get-ItemProperty -Path $latest.PSPath -ErrorAction SilentlyContinue
        if (-not $p) { return $null }
        [PSCustomObject]@{
            Target    = $latest.PSChildName
            UpgEx     = [string]$p.UpgEx
            RedReason = [string]$p.RedReason
        }
    }

    function Get-SystemDisk {
        try {
            $part = Get-Partition -DriveLetter ($env:SystemDrive.TrimEnd(':')) -ErrorAction Stop
            $disk = Get-Disk -Number $part.DiskNumber -ErrorAction Stop
            $phys = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { [string]$_.DeviceId -eq [string]$disk.Number } | Select-Object -First 1
            $media = if ($phys) { [string]$phys.MediaType } else { 'Unknown' }
            if ($media -eq 'Unspecified' -and $disk.BusType -eq 'NVMe') { $media = 'SSD' }
            [PSCustomObject]@{ Media = $media; SizeGB = [math]::Round($disk.Size / 1GB) }
        }
        catch { [PSCustomObject]@{ Media = 'Unknown'; SizeGB = 0 } }
    }

    function Get-ShortCpuName {
        param([string]$CpuName)
        $n = $CpuName -replace '\((R|TM)\)', '' -replace 'CPU', '' -replace '@.*$', '' -replace '\d+(th|st|nd|rd) Gen ', '' -replace '(with|w/) Radeon.*$', '' -replace '\S+-Core Processor', '' -replace '\s+', ' '
        return $n.Trim()
    }
}

process {
    if (-not (Test-IsElevated)) {
        Write-Host "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    $ExitCode = 0
    $os = Get-OsInfo
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $cpuName = if ($cpu) { [string]$cpu.Name } else { 'Unknown CPU' }
    # Installed RAM (module capacity). TotalPhysicalMemory is lower when graphics reserve memory.
    $ramBytes = (Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue | Measure-Object -Property Capacity -Sum).Sum
    if (-not $ramBytes -and $cs) { $ramBytes = $cs.TotalPhysicalMemory }
    $ramGB = if ($ramBytes) { [math]::Round($ramBytes / 1GB) } else { 0 }
    $tpm = Get-TpmInfo
    $secureBoot = Get-SecureBootState
    $sysDisk = Get-SystemDisk
    $cpuGuess = Get-CpuSupportGuess -CpuName $cpuName

    # --- osSupportStatus ---
    $osValue = Get-OsSupportStatus -Os $os

    # --- win11Ready ---
    $missing = @()
    $unverified = @()
    if ($tpm.Version -eq 'unknown') { $unverified += 'TPM not readable' }
    elseif ($tpm.Version -notlike '2.0*') { $missing += "TPM $($tpm.Version)" }
    if ($secureBoot -eq 'Legacy BIOS') { $missing += 'Legacy BIOS (needs UEFI)' }
    elseif ($secureBoot -eq 'Unknown') { $unverified += 'Secure Boot not readable' }
    if ($ramGB -lt 4) { $missing += "$ramGB GB RAM" }
    if ($sysDisk.SizeGB -gt 0 -and $sysDisk.SizeGB -lt 64) { $missing += "$($sysDisk.SizeGB) GB disk" }
    if ($cpuGuess -eq 'Unsupported') { $missing += "CPU $(Get-ShortCpuName $cpuName)" }
    $appraiser = Get-AppraiserResult
    $sbText = if ($secureBoot -eq 'On') { 'Secure Boot on' } else { "Secure Boot $secureBoot" }

    if ($os.Family -eq 'Server') {
        $win11Value = "OK: server OS, not applicable"
    }
    elseif ($os.Build -ge 22000) {
        if ($missing.Count) { $win11Value = "WARN: on Windows 11 but hardware not supported - $($missing -join ', ')" }
        elseif ($unverified.Count) { $win11Value = "WARN: on Windows 11, $($unverified -join ', ')" }
        else { $win11Value = "OK: on Windows 11, hardware supported (TPM $($tpm.Version), $sbText)" }
    }
    elseif ($appraiser -and $appraiser.UpgEx -eq 'Red') {
        $reason = if ($appraiser.RedReason -and $appraiser.RedReason -ne 'None') { $appraiser.RedReason } else { 'blocked' }
        $win11Value = "FAIL: not ready - $reason (appraiser $($appraiser.Target))"
        if ($missing.Count) { $win11Value += " | $($missing -join ', ')" }
    }
    elseif ($missing.Count) {
        $win11Value = "FAIL: not ready - $($missing -join ', ')"
    }
    elseif ($unverified.Count) {
        $win11Value = "WARN: not verified - $($unverified -join ', ')"
    }
    elseif ($appraiser -and $appraiser.UpgEx -match 'Green|Yellow') {
        $win11Value = "OK: ready (appraiser $($appraiser.Target) $($appraiser.UpgEx), TPM $($tpm.Version), $sbText)"
    }
    elseif ($cpuGuess -eq 'Supported') {
        $win11Value = "OK: ready (TPM $($tpm.Version), $sbText, CPU on list)"
    }
    else {
        $win11Value = "WARN: TPM, UEFI, RAM and disk OK, CPU not verified ($(Get-ShortCpuName $cpuName))"
    }

    # --- hardwareSummary ---
    $make = if ($cs) { ([string]$cs.Manufacturer -replace ' Inc\.?$', '' -replace ' Corporation$', '' -replace ',.*$', '').Trim() } else { '' }
    $model = if ($cs) { [string]$cs.Model } else { '' }
    if ($make -match '^LENOVO$') {
        # Lenovo puts the machine type in Model; the friendly name is in Win32_ComputerSystemProduct.Version.
        $friendly = (Get-CimInstance -ClassName Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).Version
        if ($friendly) { $model = $friendly }
        $make = 'Lenovo'
    }
    if ($make -and $model -like "$make*") { $model = $model.Substring($make.Length).Trim() }   # "Dell Dell Pro 14" -> "Dell Pro 14"
    $hwStatus = 'OK'
    if ($sysDisk.Media -eq 'HDD' -or $ramGB -lt 8) { $hwStatus = 'FAIL' }
    elseif ($ramGB -le 8 -or $cpuGuess -eq 'Unsupported') { $hwStatus = 'WARN' }
    $diskText = if ($sysDisk.SizeGB) { "$($sysDisk.Media) $($sysDisk.SizeGB) GB" } else { 'disk unknown' }
    $hwValue = ("${hwStatus}: $make $model | $(Get-ShortCpuName $cpuName) | $ramGB GB RAM | $diskText" -replace '\s+', ' ').Trim()

    # --- diskSpaceSummary ---
    $volumes = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue | Where-Object { $_.Size -gt 0 } | Sort-Object DeviceID
    $diskStatus = 'OK'
    $parts = foreach ($v in $volumes) {
        $pct = [math]::Round(($v.FreeSpace / $v.Size) * 100)
        if ($pct -lt 10) { $diskStatus = 'FAIL' }
        elseif ($pct -lt 20 -and $diskStatus -ne 'FAIL') { $diskStatus = 'WARN' }
        "$($v.DeviceID) $pct% free ($([math]::Round($v.FreeSpace / 1GB)) of $([math]::Round($v.Size / 1GB)) GB)"
    }
    $diskValue = if ($parts) { "${diskStatus}: $($parts -join ' | ')" } else { 'WARN: no fixed volumes found' }

    $fields = @(
        [PSCustomObject]@{ Label = 'osSupportStatus';  Name = $OsFieldName;       Value = Limit-Text $osValue }
        [PSCustomObject]@{ Label = 'win11Ready';       Name = $Win11FieldName;    Value = Limit-Text $win11Value }
        [PSCustomObject]@{ Label = 'hardwareSummary';  Name = $HardwareFieldName; Value = Limit-Text $hwValue }
        [PSCustomObject]@{ Label = 'diskSpaceSummary'; Name = $DiskFieldName;     Value = Limit-Text $diskValue }
    )

    foreach ($f in $fields) {
        if (-not $f.Name) { continue }
        try { Set-NinjaTextField -Name $f.Name -Value $f.Value }
        catch {
            Write-Host "[Error] Failed to set custom field '$($f.Name)'. Check it exists as a Text field with Automations Read/Write."
            Write-Host "$($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    $fields | Select-Object Label, Value | Format-List | Out-String | Write-Host

    exit $ExitCode
}
