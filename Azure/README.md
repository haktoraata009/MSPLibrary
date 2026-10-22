# Azure

Microsoft 365, Entra ID, Exchange Online and OneDrive admin scripts.

## Before you run

- Run from an admin workstation, not through the RMM agent.
- Needs the module named in the script (Microsoft.Graph, ExchangeOnlineManagement, Microsoft.Online.SharePoint.PowerShell, MSOnline or AzureAD).
- Sign in with an account that holds the right admin role. MSOnline and AzureAD modules are retired; prefer the Graph versions.
- Tenant IDs, app IDs and secrets are placeholders such as <TenantID>. Supply your own at run time and never commit them.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [AddConditionalAccessPolicies](AddConditionalAccessPolicies.ps1) | Creates a baseline set of Conditional Access policies for SMB tenants, including a trusted office named location (AzureAD module). | - | Admin PC |
| [AdminReport](AdminReport.ps1) | Exports Microsoft 365 admin role membership to CSV using Microsoft Graph (o365reports.com script). | - | Admin PC |
| [Create SharePoint site 365Group](Create%20SharePoint%20site%20365Group.ps1) | Creates Microsoft 365 groups and SharePoint team sites in bulk from a CSV via Microsoft Graph. | - | Admin PC |
| [DistributionGroup](DistributionGroup.ps1) | Creates a list of Exchange Online distribution groups from an inline table (edit names and addresses first). | - | Admin PC |
| [Get All Calendar Permission](Get%20All%20Calendar%20Permission.ps1) | Lists calendar folder permissions for every Exchange Online mailbox. | - | Admin PC |
| [Get-MFAStatus](Get-MFAStatus.ps1) | Reports Azure MFA status for all users, admins only, or selected users (MSOnline module). | - | Admin PC |
| [GetALLOneDriveURL](GetALLOneDriveURL.ps1) | Exports every provisioned OneDrive site URL with owner, quota and usage to CSV (SharePoint Online module). | - | Admin PC |
| [GetMailboxCalendarPermissions](GetMailboxCalendarPermissions.ps1) | Exports Exchange Online mailbox calendar permissions to CSV, with filters (o365reports.com script). | - | Admin PC |
| [GetMFA status report](GetMFA%20status%20report.ps1) | Exports per-user MFA registration and method status to CSV via Microsoft Graph (o365reports.com script). | - | Admin PC |
| [Grant consent on behalf of a single user](Grant%20consent%20on%20behalf%20of%20a%20single%20user.ps1) | Grants delegated OAuth consent for one app on behalf of a single user via Microsoft Graph (Microsoft sample). | - | Admin PC |
| [Microsoft Entra Audit](Microsoft%20Entra%20Audit.ps1) | Retrieves details regarding the device's Microsoft Entra/Azure AD connection status. | `joinTypeCustomFieldName`, `tenantInfoCustomFieldName` | No |
| [OneDrive Cleanup](OneDrive%20Cleanup.ps1) | Removes sharing links and permissions from all files in a user's OneDrive via Graph app-only auth. Fill in tenant, app ID and secret at run time. | - | Admin PC |
| [RemoveUserOneDrivePemriesion](RemoveUserOneDrivePemriesion.ps1) | Removes a user from every OneDrive in the tenant where they are not the owner and writes a CSV of actions. | - | Admin PC |
| [Run-MailboxAuditLogSearcher](Run-MailboxAuditLogSearcher.ps1) | Searches a mailbox's audit log between two dates (optionally by subject) and returns the matching operations. | - | Admin PC |
<!-- scripts:end -->
