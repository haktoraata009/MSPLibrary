# ============================================================
# Export-GroupsAndMembers.ps1
# Exports all Azure AD groups with their members, group email
# address, and group type to a CSV file.
#
# Requirements:
#   Install-Module Microsoft.Graph -Scope CurrentUser
#
# Usage:
#   .\Export-GroupsAndMembers.ps1
#   .\Export-GroupsAndMembers.ps1 -OutputPath "C:\Reports\groups.csv"
# ============================================================

param (
    [string]$OutputPath = ".\GroupsAndMembers_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

# ── 1. Connect ───────────────────────────────────────────────
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan

Connect-MgGraph -Scopes "Group.Read.All", "GroupMember.Read.All", "User.Read.All" -NoWelcome

Write-Host "Connected.`n" -ForegroundColor Green

# ── 2. Helper: resolve group type label ──────────────────────
function Get-GroupType {
    param ($Group)

    $types = $Group.GroupTypes   # e.g. ["Unified"] or []

    if ($types -contains "Unified") {
        return "Microsoft 365 Group"
    }
    elseif ($Group.SecurityEnabled -and -not $Group.MailEnabled) {
        return "Security Group"
    }
    elseif ($Group.MailEnabled -and -not $Group.SecurityEnabled) {
        return "Distribution Group"
    }
    elseif ($Group.MailEnabled -and $Group.SecurityEnabled) {
        return "Mail-Enabled Security Group"
    }
    else {
        return "Unknown"
    }
}

# ── 3. Fetch all groups ──────────────────────────────────────
Write-Host "Fetching all groups..." -ForegroundColor Cyan

$groups = Get-MgGroup -All `
    -Property "Id,DisplayName,Mail,MailEnabled,SecurityEnabled,GroupTypes"

Write-Host "Found $($groups.Count) group(s). Fetching members...`n" -ForegroundColor Green

# ── 4. Build export rows ─────────────────────────────────────
$report = [System.Collections.Generic.List[PSCustomObject]]::new()
$counter = 0

foreach ($group in $groups) {
    $counter++
    $pct = [math]::Round(($counter / $groups.Count) * 100)
    Write-Progress -Activity "Processing groups" `
                   -Status "$counter of $($groups.Count): $($group.DisplayName)" `
                   -PercentComplete $pct

    $groupType  = Get-GroupType -Group $group
    $groupEmail = if ($group.Mail) { $group.Mail } else { "N/A" }

    # Fetch members for this group
    try {
        $members = Get-MgGroupMember -GroupId $group.Id -All
    }
    catch {
        Write-Warning "Could not retrieve members for '$($group.DisplayName)': $_"
        $members = @()
    }

    if ($members.Count -eq 0) {
        # Still include the group with no members
        $report.Add([PSCustomObject]@{
            GroupName        = $group.DisplayName
            GroupEmail       = $groupEmail
            GroupType        = $groupType
            MemberName       = "(No members)"
            MemberEmail      = ""
            MemberType       = ""
        })
    }
    else {
        foreach ($member in $members) {
            # Resolve display name and email per object type
            $memberName  = $member.AdditionalProperties["displayName"]
            $memberEmail = if ($member.AdditionalProperties["mail"]) {
                              $member.AdditionalProperties["mail"]
                          } elseif ($member.AdditionalProperties["userPrincipalName"]) {
                              $member.AdditionalProperties["userPrincipalName"]
                          } else { "" }
            $memberType  = switch ($member.OdataType) {
                "#microsoft.graph.user"            { "User" }
                "#microsoft.graph.group"           { "Group (Nested)" }
                "#microsoft.graph.servicePrincipal"{ "Service Principal" }
                "#microsoft.graph.device"          { "Device" }
                default                            { $member.OdataType -replace "#microsoft.graph.", "" }
            }

            $report.Add([PSCustomObject]@{
                GroupName        = $group.DisplayName
                GroupEmail       = $groupEmail
                GroupType        = $groupType
                MemberName       = $memberName
                MemberEmail      = $memberEmail
                MemberType       = $memberType
            })
        }
    }
}

Write-Progress -Activity "Processing groups" -Completed

# ── 5. Export to CSV ─────────────────────────────────────────
$report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host "`nExport complete!" -ForegroundColor Green
Write-Host "File : $OutputPath"
Write-Host "Rows : $($report.Count)"

# ── 6. Disconnect ────────────────────────────────────────────
Disconnect-MgGraph | Out-Null
Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Cyan
