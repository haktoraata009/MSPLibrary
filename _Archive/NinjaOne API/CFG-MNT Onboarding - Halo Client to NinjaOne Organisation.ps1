#Requires -Version 5.1

<#
.SYNOPSIS
    Creates the NinjaOne organisation for a Halo client: same name, one location per Halo site,
    policies copied from a template organisation. Then prints the Windows installer link for each
    location.

.DESCRIPTION
    Run on demand from the management device when a new client is signed. The script:
      1. Reads the client name and its site names from Halo (read only).
      2. Checks NinjaOne. If an organisation with the same name already exists, it creates nothing
         and only prints the installer links (safe to run again).
      3. Creates the organisation from the template organisation (settings copied by NinjaOne),
         with the template's policy mappings and one location per Halo site ("Main" if none).
      4. Prints the Windows MSI installer link for each location.

    Using the same name as Halo lets the NinjaOne-Halo integration match the organisation to the
    client. Check the mapping in Halo after the next integration sync.

    The installer links let any device join the organisation. Share them only with the technician
    doing the deployment. Choose Manual approval if you want to approve each new device.

    Setup (once):
      1. NinjaOne API client (scopes Monitoring and Management) in the Secure fields
         ninjaApiClientId and ninjaApiClientSecret on the management device.
      2. Halo API application (read clients and sites is enough for this script) and the
         haloApiUrl, haloApiClientId, haloApiClientSecret (and optional haloApiTenant) fields on the
         management device, as for "MON-SYS Stale Devices - NinjaOne Last Seen to Halo".
      3. A template organisation in NinjaOne with your standard policies and settings.
         Its ID is in the address bar when you open it in NinjaOne.

    Script variables:
      ninjaInstance           Drop-down: app.ninjarmm.com, us2.ninjarmm.com, eu.ninjarmm.com,
                              ca.ninjarmm.com, oc.ninjarmm.com.
      haloClientId            Integer. Required. The Halo client ID (in the address bar when you
                              open the client in Halo).
      templateOrganizationId  Integer. Required. The NinjaOne template organisation ID.
      nodeApprovalMode        Drop-down: Automatic, Manual. Required. How new devices are approved.
      dryRun                  Checkbox. Shows what it would create. Creates nothing.

    Exit codes: 0 = done, 1 = setup or API error.

.NOTES
    Minimum OS: Windows 10, Windows Server 2016+
    Run as: System, on one management device
    Version: 1.0
    Release Notes: 1.0 (2026-11-25) First version. Uses Halo /api/Client and /api/Site, and NinjaOne
                   /v2/organizations-detailed, POST /v2/organizations, /v2/organization/{id}/locations
                   and /v2/organization/{id}/location/{id}/installer/WINDOWS_MSI. The NinjaOne API and
                   Halo API functions are the same in all API scripts; keep them identical.
#>

[CmdletBinding()]
param (
    [Parameter()][string]$NinjaInstance = $env:ninjaInstance,
    [Parameter()][string]$HaloClientId = $env:haloClientId,
    [Parameter()][string]$TemplateOrganizationId = $env:templateOrganizationId,
    [Parameter()][string]$NodeApprovalMode = $env:nodeApprovalMode,
    [Parameter()][string]$DryRun = $env:dryRun
)

begin {
    $InstallerType = 'WINDOWS_MSI'
    $DefaultLocationName = 'Main'

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
    $isDryRun = $DryRun -match '^(1|true|yes)$'

    # --- Variables ---
    $clientId = 0; $templateId = 0
    if (-not [int]::TryParse("$HaloClientId", [ref]$clientId) -or $clientId -le 0) {
        Write-Host "[Error] haloClientId must be the Halo client ID (a number)."
        exit 1
    }
    if (-not [int]::TryParse("$TemplateOrganizationId", [ref]$templateId) -or $templateId -le 0) {
        Write-Host "[Error] templateOrganizationId must be the NinjaOne template organisation ID (a number)."
        exit 1
    }
    $approval = switch -Regex ("$NodeApprovalMode".Trim()) {
        '^(?i)automatic$' { 'AUTOMATIC' }
        '^(?i)manual$' { 'MANUAL' }
        default { $null }
    }
    if (-not $approval) {
        Write-Host "[Error] nodeApprovalMode must be Automatic or Manual."
        exit 1
    }

    if (-not (Connect-NinjaApi)) { exit 1 }
    if (-not (Connect-HaloApi)) { exit 1 }
    Write-Host "[Info] Signed in to $script:Instance and Halo. Dry run: $isDryRun."

    # --- Halo client and sites (read only) ---
    try {
        $client = Invoke-HaloApi -Method Get -Path "/api/Client/$clientId"
        $siteResponse = Invoke-HaloApi -Method Get -Path "/api/Site?client_id=$clientId&pageinate=false"
    }
    catch {
        Write-Host "[Error] Could not read Halo client $clientId : $_"
        exit 1
    }
    $name = "$($client.name)".Trim()
    if (-not $name) {
        Write-Host "[Error] Halo client $clientId has no name or was not found."
        exit 1
    }
    $sites = if ($null -ne $siteResponse.sites) { @($siteResponse.sites) } else { @($siteResponse) }
    $locationNames = @($sites | ForEach-Object { "$($_.name)".Trim() } | Where-Object { $_ } | Sort-Object -Unique)
    if ($locationNames.Count -eq 0) { $locationNames = @($DefaultLocationName) }
    Write-Host "[Info] Halo client $clientId : '$name'. Sites: $($locationNames -join ', ')."

    # --- NinjaOne: existing organisation and template ---
    try {
        $orgs = @(Get-NinjaList -Path '/v2/organizations-detailed')
    }
    catch {
        Write-Host "[Error] Could not list NinjaOne organisations: $_"
        exit 1
    }
    $existing = @($orgs | Where-Object { "$($_.name)".Trim() -eq $name })
    $orgId = $null

    if ($existing.Count -gt 0) {
        $orgId = [int]$existing[0].id
        Write-Host "[Info] NinjaOne organisation '$name' already exists (ID $orgId). Nothing created."
    }
    else {
        $template = @($orgs | Where-Object { [int]$_.id -eq $templateId }) | Select-Object -First 1
        if (-not $template) {
            Write-Host "[Error] Template organisation $templateId was not found in NinjaOne."
            exit 1
        }
        $policies = @($template.policies | Where-Object { $_.nodeRoleId -and $_.policyId } |
            ForEach-Object { @{ nodeRoleId = [int]$_.nodeRoleId; policyId = [int]$_.policyId } })
        if ($policies.Count -eq 0) {
            Write-Host "[Warn] Template '$($template.name)' has no policy mappings. Set the policies on the new organisation by hand."
        }
        $body = @{
            name             = $name
            description      = "Halo client $clientId"
            nodeApprovalMode = $approval
            locations        = @($locationNames | ForEach-Object { @{ name = $_ } })
            policies         = $policies
        }
        if ($isDryRun) {
            Write-Host "[DryRun] Would create organisation '$name' from template '$($template.name)' ($templateId)."
            Write-Host "[DryRun] Approval: $approval. Locations: $($locationNames -join ', '). Policy mappings: $($policies.Count)."
            exit 0
        }
        try {
            $created = Invoke-NinjaApi -Method Post -Path "/v2/organizations?templateOrganizationId=$templateId" -Body $body
            $orgId = [int](@($created)[0]).id
        }
        catch {
            Write-Host "[Error] Could not create the organisation: $_"
            exit 1
        }
        if (-not $orgId) {
            Write-Host "[Error] NinjaOne did not return the new organisation ID. Check NinjaOne before running again."
            exit 1
        }
        Write-Host "[Info] Created NinjaOne organisation '$name' (ID $orgId) with $($policies.Count) policy mappings."
    }

    # --- Installer links ---
    try {
        $locations = @(Invoke-NinjaApi -Method Get -Path "/v2/organization/$orgId/locations")
    }
    catch {
        Write-Host "[Error] Could not list locations for organisation $orgId : $_"
        exit 1
    }
    $ExitCode = 0
    foreach ($loc in $locations) {
        try {
            $installer = Invoke-NinjaApi -Method Get -Path "/v2/organization/$orgId/location/$([int]$loc.id)/installer/$InstallerType"
            Write-Host "[Info] Installer ($InstallerType) for '$($loc.name)': $($installer.url)"
        }
        catch {
            Write-Host "[Warn] No installer link for '$($loc.name)': $_"
            $ExitCode = 1
        }
    }
    Write-Host "[Info] Anyone with an installer link can add a device to this organisation. Share it only with the technician doing the deployment."
    Write-Host "[Info] Next: after the next Halo integration sync, check that '$name' is mapped to Halo client $clientId."

    $script:Token = $null
    $script:HaloToken = $null
    exit $ExitCode
}
