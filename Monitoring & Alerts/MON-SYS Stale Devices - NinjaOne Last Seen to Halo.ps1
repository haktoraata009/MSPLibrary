#Requires -Version 5.1

<#
.SYNOPSIS
    Finds devices that have not contacted NinjaOne for a long time, writes a one-line status to a
    Text custom field for Halo, and can raise one Halo review ticket per client.

.DESCRIPTION
    Old devices that are offline for weeks are often retired, lost or rebuilt. They still count in
    NinjaOne and in billing. This script reads every agent device from the NinjaOne API and writes:

      lastSeenStatus  "OK: online"
                      "OK: offline under 30 days, last seen 2026-11-20"
                      "WARN: offline over 30 days, last seen 2026-10-11"
                      "FAIL: offline over 90 days, last seen 2026-07-02"

    The value only changes when the device changes band, so it is not rewritten every day.
    Halo can sync the field and report on "starts with WARN" or "starts with FAIL".

    When createHaloTickets is ticked, the script also creates one Halo ticket per client that lists
    the devices that moved into WARN or FAIL since the last run. Devices already flagged are not
    raised again. The NinjaOne organisation is matched to the Halo client by exact name.
    If the ticket cannot be created, the devices are not marked, so the next run tries again.

    Run it on ONE always-on management device, for example daily.

    Setup (once):
      1. NinjaOne API client (scopes Monitoring and Management) in the Secure fields
         ninjaApiClientId and ninjaApiClientSecret on the management device.
      2. Device custom field lastSeenStatus (Text). Automations: Read Only. API: Read/Write.
      3. For Halo tickets: a Halo API application (Client ID and Secret, agent login, permission to
         read clients and create tickets). On the management device fill haloApiUrl (Text, for
         example https://yourcompany.halopsa.com), haloApiClientId and haloApiClientSecret (Secure),
         and haloApiTenant (Text) only if Halo gave you a tenant name.
      4. Find the Halo ticket type ID to use (Halo: Configuration > Tickets > Ticket Types; the ID
         is in the address bar when you open the type).

    Script variables:
      ninjaInstance      Drop-down: app.ninjarmm.com, us2.ninjarmm.com, eu.ninjarmm.com,
                         ca.ninjarmm.com, oc.ninjarmm.com.
      createHaloTickets  Checkbox. Create Halo review tickets for newly stale devices.
      haloTicketTypeId   Integer. Halo ticket type for the review tickets. Required when
                         createHaloTickets is ticked.
      dryRun             Checkbox. Prints what it would do. Writes nothing and creates no tickets.
                         It still signs in to Halo (read only) to check the client names match.

    Exit codes: 0 = done, 1 = setup or API error, or a Halo client could not be matched.

.NOTES
    Minimum OS: Windows 10, Windows Server 2016+
    Run as: System, on one management device
    Version: 1.0
    Release Notes: 1.0 (2026-11-25) First version. Uses /v2/devices, /v2/organizations,
                   /v2/queries/custom-fields, PATCH /v2/device/{id}/custom-fields, and Halo
                   /auth/token, /api/Client and /api/Tickets. The NinjaOne API and Halo API functions
                   are the same in all API scripts; keep them identical.
#>

[CmdletBinding()]
param (
    [Parameter()][string]$NinjaInstance = $env:ninjaInstance,
    [Parameter()][string]$CreateHaloTickets = $env:createHaloTickets,
    [Parameter()][string]$HaloTicketTypeId = $env:haloTicketTypeId,
    [Parameter()][string]$DryRun = $env:dryRun
)

begin {
    # Custom field name (case sensitive). Fixed here; no script variable needed.
    $StatusFieldName = "lastSeenStatus"

    # Settings
    $WarnDays = 30
    $FailDays = 90
    # Agent devices only (network devices and cloud monitors are left out).
    $DeviceClassPattern = '^(WINDOWS_|MAC|LINUX_)'

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

    # --- Halo API (same in all Halo API scripts; keep identical) ---
    $HaloUrlFieldName      = "haloApiUrl"            # Text field on the management device
    $HaloTenantFieldName   = "haloApiTenant"         # Text field, optional
    $HaloClientIdFieldName = "haloApiClientId"       # Secure field on the management device
    $HaloSecretFieldName   = "haloApiClientSecret"   # Secure field on the management device

    function Connect-HaloApi {
        # Reads the Halo API application from the custom fields and gets a token. Returns $true or $false.
        try {
            $url = [string](Ninja-Property-Get $HaloUrlFieldName)
            $haloId = Ninja-Property-Get $HaloClientIdFieldName
            $haloSecret = Ninja-Property-Get $HaloSecretFieldName
        }
        catch {
            Write-Host "[Error] Could not read the Halo fields '$HaloUrlFieldName', '$HaloClientIdFieldName', '$HaloSecretFieldName'."
            return $false
        }
        $tenant = $null
        try { $tenant = [string](Ninja-Property-Get $HaloTenantFieldName) } catch { }
        $url = $url.Trim().TrimEnd('/')
        if ($url -notmatch '^https://[A-Za-z0-9.-]+(:\d+)?$') {
            Write-Host "[Error] '$HaloUrlFieldName' must be the Halo web address only, for example https://yourcompany.halopsa.com (https, no path)."
            return $false
        }
        if (-not $haloId -or -not $haloSecret) {
            Write-Host "[Error] '$HaloClientIdFieldName' or '$HaloSecretFieldName' is empty on this device."
            return $false
        }
        $query = ''
        if ($tenant -and $tenant.Trim()) { $query = "?tenant=$([uri]::EscapeDataString($tenant.Trim()))" }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        try {
            $tokenResponse = Invoke-RestMethod -Method Post -Uri "$url/auth/token$query" -UseBasicParsing -TimeoutSec $RequestTimeoutSec -ErrorAction Stop `
                -ContentType 'application/x-www-form-urlencoded' `
                -Body @{ grant_type = 'client_credentials'; client_id = $haloId; client_secret = $haloSecret; scope = 'all' }
            $script:HaloToken = $tokenResponse.access_token
        }
        catch {
            $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 'no response' }
            Write-Host "[Error] Halo API sign-in failed (HTTP $status). Check the Halo URL, client ID, secret and tenant."
            return $false
        }
        finally {
            $haloSecret = $null
        }
        if (-not $script:HaloToken) {
            Write-Host "[Error] Halo API sign-in returned no token."
            return $false
        }
        $script:HaloUrl = $url
        $script:HaloClientCache = @{}
        return $true
    }

    function Invoke-HaloApi {
        param([string]$Method, [string]$Path, [object]$Body)
        $response = Invoke-WebApi -Method $Method -Uri "$script:HaloUrl$Path" -Token $script:HaloToken -Body $Body
        return $response
    }

    function Find-HaloClientId {
        # Halo client ID with exactly this name (not case sensitive), or $null.
        param([string]$Name)
        $key = $Name.Trim().ToLower()
        if ($script:HaloClientCache.ContainsKey($key)) { return $script:HaloClientCache[$key] }
        $response = Invoke-HaloApi -Method Get -Path "/api/Client?search=$([uri]::EscapeDataString($Name.Trim()))&pageinate=false"
        $list = if ($null -ne $response.clients) { @($response.clients) } else { @($response) }
        $match = @($list | Where-Object { "$($_.name)".Trim() -eq $Name.Trim() })
        $id = if ($match.Count -eq 1) { [int]$match[0].id } else { $null }
        $script:HaloClientCache[$key] = $id
        return $id
    }

    function New-HaloTicket {
        # Creates one Halo ticket and returns its ID.
        param([int]$ClientId, [int]$TicketTypeId, [string]$Summary, [string]$DetailsHtml)
        $ticket = @{ client_id = $ClientId; tickettype_id = $TicketTypeId; summary = $Summary; details_html = $DetailsHtml }
        $response = Invoke-HaloApi -Method Post -Path '/api/Tickets' -Body @($ticket)
        return (@($response)[0]).id
    }

    function ConvertTo-HtmlText {
        param([string]$Text)
        return [System.Net.WebUtility]::HtmlEncode($Text)
    }
    # --- end Halo API ---
}

process {
    $ExitCode = 0
    $isDryRun = $DryRun -match '^(1|true|yes)$'
    $makeTickets = $CreateHaloTickets -match '^(1|true|yes)$'
    $ticketTypeId = 0
    if ($makeTickets -and -not [int]::TryParse("$HaloTicketTypeId", [ref]$ticketTypeId)) {
        Write-Host "[Error] haloTicketTypeId must be a number when createHaloTickets is ticked."
        exit 1
    }

    if (-not (Connect-NinjaApi)) { exit 1 }
    Write-Host "[Info] Signed in to $script:Instance. Dry run: $isDryRun. Halo tickets: $makeTickets."

    try {
        $devices = @(Get-NinjaList -Path '/v2/devices' | Where-Object { "$($_.nodeClass)" -match $DeviceClassPattern -and "$($_.approvalStatus)" -ne 'PENDING' })
        $orgs = @(Get-NinjaList -Path '/v2/organizations')
        $current = @(Get-NinjaQuery -Path "/v2/queries/custom-fields?fields=$StatusFieldName")
    }
    catch {
        Write-Host "[Error] NinjaOne API query failed: $_"
        exit 1
    }
    $orgName = @{}
    foreach ($o in $orgs) { $orgName[[string]$o.id] = "$($o.name)" }
    $currentBy = @{}
    foreach ($c in $current) { $currentBy[[string]$c.deviceId] = "$($c.fields.$StatusFieldName)" }
    Write-Host "[Info] $($devices.Count) agent devices in $($orgs.Count) organisations."

    # --- Work out each device's status ---
    $now = [DateTime]::UtcNow
    $changes = New-Object System.Collections.Generic.List[object]
    foreach ($d in $devices) {
        $seen = ConvertFrom-NinjaTime $d.lastContact
        $seenText = if ($seen) { $seen.ToString('yyyy-MM-dd') } else { 'unknown' }
        $days = if ($seen) { ($now - $seen).TotalDays } else { [double]::MaxValue }
        if ($d.offline -ne $true) { $value = "OK: online" }
        elseif ($days -ge $FailDays) { $value = "FAIL: offline over $FailDays days, last seen $seenText" }
        elseif ($days -ge $WarnDays) { $value = "WARN: offline over $WarnDays days, last seen $seenText" }
        else { $value = "OK: offline under $WarnDays days, last seen $seenText" }

        $old = $currentBy[[string]$d.id]
        if ($old -eq $value) { continue }
        $level = ($value -split ':')[0]
        $oldLevel = if ($old) { ($old -split ':')[0] } else { '' }
        # Raise when the device moves up into WARN or FAIL (OK->WARN, OK->FAIL, WARN->FAIL).
        $rank = @{ '' = 0; 'OK' = 0; 'WARN' = 1; 'FAIL' = 2 }
        $isNew = ($rank[$level] -gt 0) -and ($rank[$level] -gt [int]$rank[$oldLevel])
        $changes.Add([PSCustomObject]@{
            Id = [int]$d.id; Name = if ($d.systemName) { "$($d.systemName)" } else { "device $($d.id)" }
            OrgId = [string]$d.organizationId; Value = $value; IsNew = $isNew; LastSeen = $seenText; Write = $true
        })
    }
    $newOnes = @($changes | Where-Object { $_.IsNew })
    Write-Host "[Info] Status changes: $($changes.Count). Newly stale: $($newOnes.Count)."

    # --- Halo tickets, one per client ---
    if ($newOnes.Count -gt 0) {
        $haloReady = $false
        if ($makeTickets) {
            $haloReady = Connect-HaloApi
            if (-not $haloReady) { $ExitCode = 1 }
        }
        foreach ($group in ($newOnes | Group-Object OrgId)) {
            $client = $orgName[$group.Name]
            if (-not $client) { $client = "organisation $($group.Name)" }
            $list = @($group.Group | Sort-Object Value, Name)
            Write-Host "[Info] $client : $($list.Count) newly stale: $(($list | ForEach-Object { "$($_.Name) ($($_.LastSeen))" }) -join ', ')"
            if (-not $makeTickets) { continue }
            if (-not $haloReady) {
                foreach ($x in $list) { $x.Write = $false }     # try again next run
                continue
            }
            try {
                $clientId = Find-HaloClientId -Name $client
                if (-not $clientId) {
                    Write-Host "[Warn] No Halo client named exactly '$client'. No ticket created; these devices will be raised again next run."
                    foreach ($x in $list) { $x.Write = $false }
                    $ExitCode = 1
                    continue
                }
                $rows = ($list | ForEach-Object { "<tr><td>$(ConvertTo-HtmlText $_.Name)</td><td>$(ConvertTo-HtmlText $_.LastSeen)</td><td>$(ConvertTo-HtmlText $_.Value)</td></tr>" }) -join ''
                $html = "<p>These devices have not contacted NinjaOne for over $WarnDays days.</p>" +
                        "<table><tr><th>Device</th><th>Last seen</th><th>Status</th></tr>$rows</table>" +
                        "<p>For each device: confirm with the client whether it is still in use. If retired, remove it from NinjaOne and update the contract quantity. If in use, bring it back online.</p>"
                $summary = "Stale device review: $($list.Count) device(s) offline over $WarnDays days"
                if ($isDryRun) {
                    Write-Host "[DryRun] Would create Halo ticket for client $clientId '$client': $summary"
                }
                else {
                    $ticketId = New-HaloTicket -ClientId $clientId -TicketTypeId $ticketTypeId -Summary $summary -DetailsHtml $html
                    Write-Host "[Info] Halo ticket $ticketId created for '$client'."
                }
            }
            catch {
                Write-Host "[Warn] Halo ticket for '$client' failed: $_"
                foreach ($x in $list) { $x.Write = $false }
                $ExitCode = 1
            }
        }
    }

    # --- Write the field ---
    $written = 0; $failed = 0; $held = 0
    foreach ($ch in $changes) {
        if (-not $ch.Write) { $held++; continue }
        if ($isDryRun) {
            Write-Host "[DryRun] $($ch.Name) : $($ch.Value)"
            $written++
            continue
        }
        try {
            $null = Invoke-NinjaApi -Method Patch -Path "/v2/device/$($ch.Id)/custom-fields" -Body @{ $StatusFieldName = $ch.Value }
            $written++
        }
        catch {
            $failed++
            Write-Host "[Warn] $($ch.Name) : $_"
        }
    }

    $verb = if ($isDryRun) { 'would be updated' } else { 'updated' }
    Write-Host "[Info] Devices $verb : $written. Held for next run: $held. Failed: $failed."
    if ($failed -gt 0) {
        Write-Host "[Info] Failures on PATCH usually mean the custom field is missing or its API permission is not Read/Write."
        $ExitCode = 1
    }
    $script:Token = $null
    $script:HaloToken = $null
    exit $ExitCode
}
