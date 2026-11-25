#Requires -Version 5.1

<#
.SYNOPSIS
    Copies each device's NinjaOne warranty dates into Text custom fields, so Halo can sync them.

.DESCRIPTION
    NinjaOne stores warranty dates (from its Dell, HP and Lenovo lookup) as device data, not as a
    custom field, and the NinjaOne-Halo integration does not sync them. A script on the device
    cannot read them either. This script reads them from the NinjaOne public API and writes them
    to two Text custom fields on every device, which Halo can sync:

      warrantyEndDate    yyyy-MM-dd, for example 2027-05-31
      warrantyStartDate  yyyy-MM-dd (shows device age for refresh planning)

    Run it on ONE always-on management device (not on every device), for example daily.
    Devices with no warranty data in NinjaOne are skipped and their fields are left as they are.

    Setup (once):
      1. NinjaOne > Administration > Apps > API > Client App IDs > Add.
         Application platform: API Services (machine-to-machine). Scopes: Monitoring, Management.
         Allowed grant types: Client Credentials. Save the client ID and secret.
      2. Create device custom fields warrantyEndDate and warrantyStartDate (Text).
         Automations: Read Only is enough. API: Read/Write (the script writes them through the API).
      3. Create device custom fields ninjaApiClientId and ninjaApiClientSecret (Secure).
         Automations: Read Only. API: None. Fill them in on the management device only.
      4. Add this script with the two script variables below and schedule it on the management device.

    Script variables:
      ninjaInstance  Drop-down: app.ninjarmm.com, us2.ninjarmm.com, eu.ninjarmm.com,
                     ca.ninjarmm.com, oc.ninjarmm.com. The host you log in to NinjaOne with.
      dryRun         Checkbox. When ticked, prints what it would write and changes nothing.

    The secret is read from the Secure field at run time. It is never printed, and the token is
    only sent to the allow-listed NinjaOne host.

    Exit codes: 0 = done, 1 = setup or API error (see the log).

.NOTES
    Minimum OS: Windows 10, Windows Server 2016+
    Run as: System, on one management device
    Version: 1.1
    Release Notes: 1.1 (2026-11-25) Fix: on PowerShell 5.1 the device list came back empty
                   ("0 devices found") because the API response array was returned directly.
                   1.0 (2026-11-25) First version. Uses GET /v2/device/{id}?expand=warranty and
                   PATCH /v2/device/{id}/custom-fields.
#>

[CmdletBinding()]
param (
    [Parameter()][string]$NinjaInstance = $env:ninjaInstance,
    [Parameter()][string]$DryRun = $env:dryRun
)

begin {
    # Custom field names (case sensitive). Fixed here; no script variable needed.
    $EndFieldName      = "warrantyEndDate"
    $StartFieldName    = "warrantyStartDate"
    $ClientIdFieldName = "ninjaApiClientId"       # Secure field on the management device
    $SecretFieldName   = "ninjaApiClientSecret"   # Secure field on the management device

    # Only these hosts receive the client secret or token.
    $AllowedInstances = @('app.ninjarmm.com', 'us2.ninjarmm.com', 'eu.ninjarmm.com', 'ca.ninjarmm.com', 'oc.ninjarmm.com')

    $RequestTimeoutSec = 60
    $MaxRetries = 3

    function Invoke-NinjaApi {
        param(
            [Parameter(Mandatory = $true)][string]$Method,
            [Parameter(Mandatory = $true)][string]$Path,
            [object]$Body
        )
        $uri = "https://$script:Instance$Path"
        $headers = @{ Authorization = "Bearer $script:Token"; Accept = 'application/json' }
        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            try {
                $params = @{ Method = $Method; Uri = $uri; Headers = $headers; TimeoutSec = $RequestTimeoutSec; UseBasicParsing = $true; ErrorAction = 'Stop' }
                if ($null -ne $Body) {
                    $params.Body = ($Body | ConvertTo-Json -Compress -Depth 5)
                    $params.ContentType = 'application/json'
                }
                # Assign first: PowerShell 5.1 loses JSON arrays when Invoke-RestMethod is returned directly.
                $response = Invoke-RestMethod @params
                return $response
            }
            catch {
                $status = $null
                if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
                if (($status -eq 429 -or $status -ge 500) -and $attempt -lt $MaxRetries) {
                    $wait = 5 * $attempt
                    try { $ra = $_.Exception.Response.Headers['Retry-After']; if ($ra) { $wait = [int]$ra } } catch { }
                    Start-Sleep -Seconds ([math]::Min($wait, 60))
                    continue
                }
                if (-not $status) { $status = "n/a" }
                throw "HTTP $status on $Method $Path - $($_.Exception.Message)"
            }
        }
    }

    function ConvertFrom-NinjaDate {
        # NinjaOne returns warranty dates as Unix time in seconds (sometimes with decimals).
        param($Value)
        if ($null -eq $Value -or "$Value" -eq '') { return $null }
        $n = 0.0
        if (-not [double]::TryParse("$Value", [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { return $null }
        if ($n -le 0) { return $null }
        if ($n -gt 100000000000) { $n = $n / 1000 }   # milliseconds
        return [DateTimeOffset]::FromUnixTimeSeconds([long][math]::Floor($n)).UtcDateTime.ToString('yyyy-MM-dd')
    }
}

process {
    $ExitCode = 0
    $isDryRun = $DryRun -match '^(1|true|yes)$'

    # --- Setup checks ---
    $script:Instance = ([string]$NinjaInstance).Trim().ToLower() -replace '^https?://', '' -replace '/.*$', ''
    if ($AllowedInstances -notcontains $script:Instance) {
        Write-Host "[Error] ninjaInstance '$NinjaInstance' is not a known NinjaOne host. Use one of: $($AllowedInstances -join ', ')."
        exit 1
    }

    try {
        $clientId = Ninja-Property-Get $ClientIdFieldName
        $clientSecret = Ninja-Property-Get $SecretFieldName
    }
    catch {
        Write-Host "[Error] Could not read '$ClientIdFieldName' / '$SecretFieldName'. Run this script from NinjaOne on the management device."
        exit 1
    }
    if (-not $clientId -or -not $clientSecret) {
        Write-Host "[Error] '$ClientIdFieldName' or '$SecretFieldName' is empty on this device. Fill both Secure fields on the management device."
        exit 1
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    # --- Token (client credentials) ---
    try {
        $tokenResponse = Invoke-RestMethod -Method Post -Uri "https://$script:Instance/ws/oauth/token" -UseBasicParsing -TimeoutSec $RequestTimeoutSec -ErrorAction Stop `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body @{ grant_type = 'client_credentials'; client_id = $clientId; client_secret = $clientSecret; scope = 'monitoring management' }
        $script:Token = $tokenResponse.access_token
    }
    catch {
        $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 'no response' }
        Write-Host "[Error] NinjaOne API sign-in failed (HTTP $status). Check the client ID, secret, scopes and ninjaInstance."
        exit 1
    }
    finally {
        $clientSecret = $null
    }
    if (-not $script:Token) {
        Write-Host "[Error] NinjaOne API sign-in returned no token."
        exit 1
    }
    Write-Host "[Info] Signed in to $script:Instance. Dry run: $isDryRun."

    # --- All devices (paged) ---
    $devices = New-Object System.Collections.Generic.List[object]
    $after = 0
    try {
        do {
            $page = @(Invoke-NinjaApi -Method Get -Path "/v2/devices?pageSize=1000&after=$after")
            foreach ($d in $page) { $devices.Add($d) }
            if ($page.Count) { $after = ($page | Measure-Object -Property id -Maximum).Maximum }
        } while ($page.Count -eq 1000)
    }
    catch {
        Write-Host "[Error] Could not list devices: $_"
        exit 1
    }
    Write-Host "[Info] $($devices.Count) devices found."

    # --- Warranty per device ---
    $written = 0; $noData = 0; $failed = 0
    foreach ($d in $devices) {
        $name = if ($d.systemName) { $d.systemName } else { "device $($d.id)" }
        try {
            $detail = Invoke-NinjaApi -Method Get -Path "/v2/device/$([int]$d.id)?expand=warranty"
            $end = ConvertFrom-NinjaDate $detail.warranty.endDate
            $start = ConvertFrom-NinjaDate $detail.warranty.startDate
            if (-not $end -and -not $start) { $noData++; continue }

            # Only these two fields are sent; nothing else on the device is changed.
            $body = @{}
            if ($end) { $body[$EndFieldName] = $end }
            if ($start) { $body[$StartFieldName] = $start }

            if ($isDryRun) {
                Write-Host "[DryRun] $name : end $end, start $start"
            }
            else {
                $null = Invoke-NinjaApi -Method Patch -Path "/v2/device/$([int]$d.id)/custom-fields" -Body $body
            }
            $written++
        }
        catch {
            $failed++
            Write-Host "[Warn] $name : $_"
        }
    }

    $verb = if ($isDryRun) { 'would be written' } else { 'written' }
    Write-Host "[Info] Warranty dates $verb for $written devices. No warranty data: $noData. Failed: $failed."
    if ($failed -gt 0) {
        Write-Host "[Info] Failures on PATCH usually mean the custom field is missing or its API permission is not Read/Write."
        $ExitCode = 1
    }
    $script:Token = $null
    exit $ExitCode
}
