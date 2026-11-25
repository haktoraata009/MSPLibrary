#Requires -Version 5.1

<#
.SYNOPSIS
    Writes a one-line patch status and antivirus status for every Windows device, from the NinjaOne
    API, into Text custom fields that Halo can sync for client reports.

.DESCRIPTION
    Reads NinjaOne patch and antivirus data for all devices through the NinjaOne public API and
    writes two Text custom fields on each Windows device. Each value starts with OK, WARN or FAIL,
    so Halo reports can filter with "starts with".

      patchStatus  for example "OK: 12 installed in 30 days (last 2026-11-20), 3 pending, 0 failed"
                   FAIL = a patch failed. WARN = patches pending and none installed in 30 days,
                   or no patch data. OK = otherwise.
      avStatus     for example "OK: Windows Defender, on, definitions up to date, 0 threats in 30 days"
                   FAIL = no antivirus reported, or antivirus off or expired.
                   WARN = definitions out of date, or threats found in 30 days.

    A field is only written when its value changed.

    Run it on ONE always-on management device (not on every device), for example daily.
    It uses the same NinjaOne API client and Secure fields as
    "RPT-HW Warranty - NinjaOne Dates to Custom Field".

    Setup (once):
      1. NinjaOne API client with scopes Monitoring and Management (see the warranty script).
      2. Create device custom fields patchStatus and avStatus (Text).
         Automations: Read Only. API: Read/Write.
      3. ninjaApiClientId and ninjaApiClientSecret (Secure) filled in on the management device.
      4. Add this script with the two script variables below and schedule it on the management device.

    Script variables:
      ninjaInstance  Drop-down: app.ninjarmm.com, us2.ninjarmm.com, eu.ninjarmm.com,
                     ca.ninjarmm.com, oc.ninjarmm.com. The host you log in to NinjaOne with.
      dryRun         Checkbox. When ticked, prints what it would write and changes nothing.

    Exit codes: 0 = done, 1 = setup or API error (see the log).

.NOTES
    Minimum OS: Windows 10, Windows Server 2016+
    Run as: System, on one management device
    Version: 1.0
    Release Notes: 1.0 (2026-11-25) First version. Uses /v2/queries/os-patches, os-patch-installs,
                   antivirus-status, antivirus-threats and custom-fields, and
                   PATCH /v2/device/{id}/custom-fields. The NinjaOne API functions are the same in
                   all NinjaOne API scripts; keep them identical.
#>

[CmdletBinding()]
param (
    [Parameter()][string]$NinjaInstance = $env:ninjaInstance,
    [Parameter()][string]$DryRun = $env:dryRun
)

begin {
    # Custom field names (case sensitive). Fixed here; no script variable needed.
    $PatchFieldName = "patchStatus"
    $AvFieldName    = "avStatus"

    # Settings
    $LookbackDays   = 30
    $MaxFieldLength = 200
    $DeviceClasses  = @('WINDOWS_WORKSTATION', 'WINDOWS_SERVER')

    # --- NinjaOne API (same in all NinjaOne API scripts; keep identical) ---
    $ClientIdFieldName = "ninjaApiClientId"       # Secure field on the management device
    $SecretFieldName   = "ninjaApiClientSecret"   # Secure field on the management device
    $AllowedInstances  = @('app.ninjarmm.com', 'us2.ninjarmm.com', 'eu.ninjarmm.com', 'ca.ninjarmm.com', 'oc.ninjarmm.com')
    $RequestTimeoutSec = 60
    $MaxRetries        = 3
    $QueryPageSize     = 1000

    function Invoke-WebApi {
        # One HTTPS call with retry on 429 and 5xx. Never prints the token.
        param(
            [Parameter(Mandatory = $true)][string]$Method,
            [Parameter(Mandatory = $true)][string]$Uri,
            [Parameter(Mandatory = $true)][string]$Token,
            [object]$Body
        )
        $headers = @{ Authorization = "Bearer $Token"; Accept = 'application/json' }
        $shortPath = ([uri]$Uri).PathAndQuery
        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            try {
                $params = @{ Method = $Method; Uri = $Uri; Headers = $headers; TimeoutSec = $RequestTimeoutSec; UseBasicParsing = $true; ErrorAction = 'Stop' }
                if ($null -ne $Body) {
                    $json = ConvertTo-Json -InputObject $Body -Depth 8 -Compress
                    $params.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $params.ContentType = 'application/json; charset=utf-8'
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
                throw "HTTP $status on $Method $shortPath - $($_.Exception.Message)"
            }
        }
    }

    function Invoke-NinjaApi {
        param([string]$Method, [string]$Path, [object]$Body)
        $response = Invoke-WebApi -Method $Method -Uri "https://$script:Instance$Path" -Token $script:Token -Body $Body
        return $response
    }

    function Connect-NinjaApi {
        # Reads the API client from the Secure fields and gets a token. Returns $true or $false.
        $script:Instance = ([string]$NinjaInstance).Trim().ToLower() -replace '^https?://', '' -replace '/.*$', ''
        if ($AllowedInstances -notcontains $script:Instance) {
            Write-Host "[Error] ninjaInstance '$NinjaInstance' is not a known NinjaOne host. Use one of: $($AllowedInstances -join ', ')."
            return $false
        }
        try {
            $clientId = Ninja-Property-Get $ClientIdFieldName
            $clientSecret = Ninja-Property-Get $SecretFieldName
        }
        catch {
            Write-Host "[Error] Could not read '$ClientIdFieldName' / '$SecretFieldName'. Run this script from NinjaOne on the management device."
            return $false
        }
        if (-not $clientId -or -not $clientSecret) {
            Write-Host "[Error] '$ClientIdFieldName' or '$SecretFieldName' is empty on this device. Fill both Secure fields on the management device."
            return $false
        }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        try {
            $tokenResponse = Invoke-RestMethod -Method Post -Uri "https://$script:Instance/ws/oauth/token" -UseBasicParsing -TimeoutSec $RequestTimeoutSec -ErrorAction Stop `
                -ContentType 'application/x-www-form-urlencoded' `
                -Body @{ grant_type = 'client_credentials'; client_id = $clientId; client_secret = $clientSecret; scope = 'monitoring management' }
            $script:Token = $tokenResponse.access_token
        }
        catch {
            $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 'no response' }
            Write-Host "[Error] NinjaOne API sign-in failed (HTTP $status). Check the client ID, secret, scopes and ninjaInstance."
            return $false
        }
        finally {
            $clientSecret = $null
        }
        if (-not $script:Token) {
            Write-Host "[Error] NinjaOne API sign-in returned no token."
            return $false
        }
        return $true
    }

    function Get-NinjaList {
        # Lists that page with pageSize and after (last ID), for example /v2/devices.
        param([string]$Path)
        $all = New-Object System.Collections.Generic.List[object]
        $after = 0
        do {
            $page = @(Invoke-NinjaApi -Method Get -Path "$($Path)?pageSize=1000&after=$after")
            foreach ($item in $page) { $all.Add($item) }
            if ($page.Count) { $after = ($page | Measure-Object -Property id -Maximum).Maximum }
        } while ($page.Count -eq 1000)
        return $all.ToArray()
    }

    function Get-NinjaQuery {
        # /v2/queries/* reports. They page with a cursor; the next page is asked for with cursor=<name>.
        param([string]$Path)
        $all = New-Object System.Collections.Generic.List[object]
        $join = if ($Path.Contains('?')) { '&' } else { '?' }
        $cursor = $null
        $pages = 0
        do {
            $uri = "$Path$($join)pageSize=$QueryPageSize"
            if ($cursor) { $uri += "&cursor=$([uri]::EscapeDataString($cursor))" }
            $response = Invoke-NinjaApi -Method Get -Path $uri
            $results = @($response.results)
            foreach ($item in $results) { $all.Add($item) }
            $cursor = $response.cursor.name
            $pages++
        } while ($cursor -and $results.Count -ge $QueryPageSize -and $pages -lt 500)
        return $all.ToArray()
    }

    function ConvertFrom-NinjaTime {
        # NinjaOne returns times as Unix time in seconds (sometimes milliseconds). Returns UTC DateTime or $null.
        param($Value)
        if ($null -eq $Value -or "$Value" -eq '') { return $null }
        $n = 0.0
        if (-not [double]::TryParse("$Value", [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { return $null }
        if ($n -le 0) { return $null }
        if ($n -gt 100000000000) { $n = $n / 1000 }
        return [DateTimeOffset]::FromUnixTimeSeconds([long][math]::Floor($n)).UtcDateTime
    }
    # --- end NinjaOne API ---

    function Format-Word {
        # "UP_TO_DATE" -> "up to date"
        param([string]$Text)
        return ($Text -replace '_', ' ').Trim().ToLower()
    }

    function Limit-Length {
        param([string]$Text)
        if ($Text.Length -gt $MaxFieldLength) { return $Text.Substring(0, $MaxFieldLength - 3) + '...' }
        return $Text
    }
}

process {
    $ExitCode = 0
    $isDryRun = $DryRun -match '^(1|true|yes)$'

    if (-not (Connect-NinjaApi)) { exit 1 }
    Write-Host "[Info] Signed in to $script:Instance. Dry run: $isDryRun."

    $now = [DateTime]::UtcNow
    $since = $now.AddDays(-$LookbackDays)

    try {
        $devices = @(Get-NinjaList -Path '/v2/devices' | Where-Object { $DeviceClasses -contains $_.nodeClass })
        Write-Host "[Info] $($devices.Count) Windows devices."

        $pending = @(Get-NinjaQuery -Path '/v2/queries/os-patches')
        $installs = @(Get-NinjaQuery -Path "/v2/queries/os-patch-installs?installedAfter=$($since.ToString('yyyy-MM-dd'))")
        $avStatus = @(Get-NinjaQuery -Path '/v2/queries/antivirus-status')
        $threats = @(Get-NinjaQuery -Path '/v2/queries/antivirus-threats')
        $current = @(Get-NinjaQuery -Path "/v2/queries/custom-fields?fields=$PatchFieldName,$AvFieldName")
    }
    catch {
        Write-Host "[Error] NinjaOne API query failed: $_"
        exit 1
    }
    Write-Host "[Info] Records: $($pending.Count) pending patches, $($installs.Count) patch installs, $($avStatus.Count) antivirus, $($threats.Count) threats."

    # Index everything by device ID.
    $pendingBy = @{}; $installBy = @{}; $avBy = @{}; $threatBy = @{}; $currentBy = @{}
    foreach ($p in $pending) {
        $k = [string]$p.deviceId
        if (-not $pendingBy.ContainsKey($k)) { $pendingBy[$k] = New-Object System.Collections.Generic.List[object] }
        $pendingBy[$k].Add($p)
    }
    foreach ($i in $installs) {
        $at = ConvertFrom-NinjaTime $i.installedAt
        if (-not $at) { $at = ConvertFrom-NinjaTime $i.timestamp }
        if ($at -and $at -lt $since) { continue }    # the API filter is a date; check it here too
        $k = [string]$i.deviceId
        if (-not $installBy.ContainsKey($k)) { $installBy[$k] = New-Object System.Collections.Generic.List[object] }
        $installBy[$k].Add([PSCustomObject]@{ Status = "$($i.status)"; At = $at })
    }
    foreach ($a in $avStatus) {
        $k = [string]$a.deviceId
        if (-not $avBy.ContainsKey($k)) { $avBy[$k] = New-Object System.Collections.Generic.List[object] }
        $avBy[$k].Add($a)
    }
    foreach ($t in $threats) {
        $at = ConvertFrom-NinjaTime $t.timestamp
        if ($at -and $at -lt $since) { continue }
        $k = [string]$t.deviceId
        if (-not $threatBy.ContainsKey($k)) { $threatBy[$k] = 0 }
        $threatBy[$k]++
    }
    foreach ($c in $current) { $currentBy[[string]$c.deviceId] = $c.fields }

    $written = 0; $unchanged = 0; $failed = 0
    foreach ($d in $devices) {
        $k = [string]$d.id
        $name = if ($d.systemName) { $d.systemName } else { "device $($d.id)" }

        # --- Patch status ---
        $inst = if ($installBy.ContainsKey($k)) { $installBy[$k].ToArray() } else { @() }
        $ok = @($inst | Where-Object { $_.Status -ne 'FAILED' })
        $instFailed = @($inst | Where-Object { $_.Status -eq 'FAILED' }).Count
        $pend = if ($pendingBy.ContainsKey($k)) { $pendingBy[$k].ToArray() } else { @() }
        $pendFailed = @($pend | Where-Object { "$($_.status)" -eq 'FAILED' }).Count
        $pendOpen = @($pend | Where-Object { "$($_.status)" -notmatch '^(FAILED|REJECTED|INSTALLED)$' }).Count
        $failedTotal = $instFailed + $pendFailed
        $last = ($ok | Where-Object { $_.At } | Sort-Object At -Descending | Select-Object -First 1)
        $lastText = if ($last) { " (last $($last.At.ToString('yyyy-MM-dd')))" } else { '' }

        if ($inst.Count -eq 0 -and $pend.Count -eq 0) {
            $patchValue = "WARN: no patch data in NinjaOne (check the patch policy)"
        }
        else {
            $level = if ($failedTotal -gt 0) { 'FAIL' } elseif ($pendOpen -gt 0 -and $ok.Count -eq 0) { 'WARN' } else { 'OK' }
            $patchValue = "${level}: $($ok.Count) installed in $LookbackDays days$lastText, $pendOpen pending, $failedTotal failed"
        }

        # --- Antivirus status ---
        $threatCount = if ($threatBy.ContainsKey($k)) { $threatBy[$k] } else { 0 }
        $avList = if ($avBy.ContainsKey($k)) { $avBy[$k].ToArray() } else { @() }
        if ($avList.Count -eq 0) {
            $avValue = "FAIL: no antivirus reported to NinjaOne, $threatCount threats in $LookbackDays days"
        }
        else {
            # Prefer a product that is on.
            $av = $avList | Sort-Object { if ("$($_.productState)" -match 'ON|ENABLED|ACTIVE') { 0 } else { 1 } } | Select-Object -First 1
            $state = Format-Word "$($av.productState)"
            $defs = Format-Word "$($av.definitionStatus)"
            $level = 'OK'
            if ($state -match 'off|disabled|expired|snoozed') { $level = 'FAIL' }
            elseif ($defs -match 'out|old|expired' -or $threatCount -gt 0) { $level = 'WARN' }
            $parts = @("$($av.productName)".Trim())
            if ($state) { $parts += $state }
            if ($defs) { $parts += "definitions $defs" }
            $avValue = "${level}: $(($parts | Where-Object { $_ }) -join ', '), $threatCount threats in $LookbackDays days"
        }

        $patchValue = Limit-Length $patchValue
        $avValue = Limit-Length $avValue

        # Only send fields that changed.
        $body = @{}
        $old = $currentBy[$k]
        if ("$($old.$PatchFieldName)" -ne $patchValue) { $body[$PatchFieldName] = $patchValue }
        if ("$($old.$AvFieldName)" -ne $avValue) { $body[$AvFieldName] = $avValue }
        if ($body.Count -eq 0) { $unchanged++; continue }

        if ($isDryRun) {
            Write-Host "[DryRun] $name : $patchValue | $avValue"
            $written++
            continue
        }
        try {
            $null = Invoke-NinjaApi -Method Patch -Path "/v2/device/$([int]$d.id)/custom-fields" -Body $body
            $written++
        }
        catch {
            $failed++
            Write-Host "[Warn] $name : $_"
        }
    }

    $verb = if ($isDryRun) { 'would be updated' } else { 'updated' }
    Write-Host "[Info] Devices $verb : $written. Unchanged: $unchanged. Failed: $failed."
    if ($failed -gt 0) {
        Write-Host "[Info] Failures on PATCH usually mean the custom field is missing or its API permission is not Read/Write."
        $ExitCode = 1
    }
    $script:Token = $null
    exit $ExitCode
}
