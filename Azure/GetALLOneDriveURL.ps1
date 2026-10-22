<#
Export-OneDriveUrls.ps1
Exports all provisioned OneDrive (personal) site URLs in the tenant.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TenantAdminUrl,   # e.g. https://contoso-admin.sharepoint.com

    [Parameter(Mandatory=$true)]
    [string]$OutputCsvPath     # e.g. C:\Temp\OneDriveUrls.csv
)

# Requires: Microsoft.Online.SharePoint.PowerShell
# Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser

Connect-SPOService -Url $TenantAdminUrl

$oneDrives = Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Url -like '-my.sharepoint.com/personal/'"

$oneDrives |
    Select-Object Owner, Url, Title, StorageQuota, StorageUsageCurrent, LastContentModifiedDate |
    Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8

Write-Host "Exported $($oneDrives.Count) OneDrive sites to $OutputCsvPath"