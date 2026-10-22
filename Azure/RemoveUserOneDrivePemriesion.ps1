<#
Remove-UserFromAllOneDrives.ps1
Removes a specified user from every OneDrive site in the tenant (except where they are the Owner).
Creates a CSV report of actions.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TenantAdminUrl,     # e.g. https://contoso-admin.sharepoint.com

    [Parameter(Mandatory=$true)]
    [string]$TargetUserUpn,      # e.g. exemployee@contoso.com

    [Parameter(Mandatory=$true)]
    [string]$ReportCsvPath       # e.g. C:\Temp\RemoveUserFromOneDrives_Report.csv
)

Connect-SPOService -Url $TenantAdminUrl

$oneDrives = Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Url -like '-my.sharepoint.com/personal/'"

$report = foreach ($site in $oneDrives) {

    $result = [ordered]@{
        OneDriveUrl          = $site.Url
        OneDriveOwner        = $site.Owner
        SkippedAsOwner       = $false
        RemovedAsSCA         = $false
        RemovedAsUser        = $false
        Notes                = $null
    }

    # Skip removing from their OWN OneDrive
    if ($site.Owner -ieq $TargetUserUpn) {
        $result.SkippedAsOwner = $true
        $result.Notes = "Skipped (target is owner of this OneDrive)"
        [pscustomobject]$result
        continue
    }

    # 1) Remove Site Collection Admin (if set)
    try {
        Set-SPOUser -Site $site.Url -LoginName $TargetUserUpn -IsSiteCollectionAdmin $false -ErrorAction Stop
        $result.RemovedAsSCA = $true
    } catch {
        # Not fatal; user may not be SCA or may not exist on that site
        $result.Notes = "Set-SPOUser SCA removal: $($_.Exception.Message)"
    }

    # 2) Remove from site collection user list
    try {
        Remove-SPOUser -Site $site.Url -LoginName $TargetUserUpn -ErrorAction Stop
        $result.RemovedAsUser = $true
    } catch {
        $msg = $_.Exception.Message
        if ($result.Notes) { $result.Notes += " | " }
        $result.Notes += "Remove-SPOUser: $msg"
    }

    [pscustomobject]$result
}

$report | Export-Csv -Path $ReportCsvPath -NoTypeInformation -Encoding UTF8
Write-Host "Done. Report: $ReportCsvPath"