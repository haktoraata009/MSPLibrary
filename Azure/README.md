# Azure

Microsoft 365, Entra ID, Exchange Online and OneDrive admin scripts.

## Before you run

- Run from an admin workstation, not through the RMM agent (except RPT-M365 Entra Join - Device Status).
- Needs the module named in the script (Microsoft.Graph, ExchangeOnlineManagement, Microsoft.Online.SharePoint.PowerShell, MSOnline or AzureAD).
- Sign in with an account that holds the right admin role. MSOnline and AzureAD modules are retired; prefer the Graph versions.
- Tenant IDs, app IDs and secrets are placeholders such as <TenantID>. Supply your own at run time and never commit them.
- Read the script and understand the expected outcome before running it, even when the table says it is safe.

## Scripts

Names follow the [naming convention](../README.md#naming-convention): `<TYPE>-<AREA> <Subject> - <Action>`.

- **Function** - Monitor / Alert, Report (read-only), Config change, Repair / Fix, Install / Update, Uninstall, Tenant admin (M365) or Intune detection.
- **Run as** - System (through the RMM), User (signed-in user's context), Admin PC (admin workstation signed in to the tenant), or the server role named.
- **Reboot** - No; Optional (a script variable can restart the device); Needed to apply (change takes effect after the next restart); Restarts device (the script restarts it).
- **Caution** - what can go wrong or what users will notice.
- **Script variables** - NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

<!-- scripts:start -->
| Script | What it does | Function | Run as | Reboot | Caution | Script variables |
|---|---|---|---|---|---|---|
| [ADM-M365 Admin Roles - Report](ADM-M365%20Admin%20Roles%20-%20Report.ps1) | Lists who holds Microsoft 365 admin roles and saves a CSV. | Tenant admin (M365) | Admin PC | No | - | - |
| [ADM-M365 App Consent - Grant for Single User](ADM-M365%20App%20Consent%20-%20Grant%20for%20Single%20User.ps1) | Grants an app permission to act for one user, without tenant-wide admin consent. | Tenant admin (M365) | Admin PC | No | ⚠️ Grants app permissions. Check the app and scopes. | - |
| [ADM-M365 Calendar - Permissions List](ADM-M365%20Calendar%20-%20Permissions%20List.ps1) | Lists who has access to each mailbox calendar. | Tenant admin (M365) | Admin PC | No | ⚠️ Slow on large tenants. | - |
| [ADM-M365 Calendar - Permissions Report](ADM-M365%20Calendar%20-%20Permissions%20Report.ps1) | Exports calendar permissions for all or selected mailboxes to CSV. | Tenant admin (M365) | Admin PC | No | - | - |
| [ADM-M365 Distribution Groups - Bulk Create](ADM-M365%20Distribution%20Groups%20-%20Bulk%20Create.ps1) | Creates a list of Exchange Online distribution groups. | Tenant admin (M365) | Admin PC | No | ⚠️ Creates tenant objects. Edit the group list first. | - |
| [ADM-M365 Groups - Export Members](ADM-M365%20Groups%20-%20Export%20Members.ps1) | Exports every Entra group with its members, email and type to CSV. | Tenant admin (M365) | Admin PC | No | - | - |
| [ADM-M365 Mailbox - Audit Log Search](ADM-M365%20Mailbox%20-%20Audit%20Log%20Search.ps1) | Searches a mailbox audit log between two dates, for example to find deleted email. | Tenant admin (M365) | Admin PC | No | - | - |
| [ADM-M365 MFA - Status Report (Legacy MSOnline)](ADM-M365%20MFA%20-%20Status%20Report%20%28Legacy%20MSOnline%29.ps1) | Reports MFA status per user using the retired MSOnline module. | Tenant admin (M365) | Admin PC | No | ⚠️ MSOnline is retired; prefer the Graph version. | - |
| [ADM-M365 MFA - Status Report](ADM-M365%20MFA%20-%20Status%20Report.ps1) | Reports each user's MFA registration and methods via Microsoft Graph. | Tenant admin (M365) | Admin PC | No | - | - |
| [ADM-M365 OneDrive - Export Site URLs](ADM-M365%20OneDrive%20-%20Export%20Site%20URLs.ps1) | Exports every OneDrive URL with owner and storage used. | Tenant admin (M365) | Admin PC | No | - | - |
| [ADM-M365 OneDrive - Remove Sharing Links](ADM-M365%20OneDrive%20-%20Remove%20Sharing%20Links.ps1) | Removes every sharing link and permission from a user's OneDrive files. | Tenant admin (M365) | Admin PC | No | ⚠️ Cannot be undone. Shared users lose access straight away. | - |
| [ADM-M365 OneDrive - Remove User Access](ADM-M365%20OneDrive%20-%20Remove%20User%20Access.ps1) | Removes one user's access from every OneDrive in the tenant and logs the changes. | Tenant admin (M365) | Admin PC | No | ⚠️ Cannot be undone in bulk. Check the user first. | - |
| [ADM-M365 SharePoint - Create Sites from CSV](ADM-M365%20SharePoint%20-%20Create%20Sites%20from%20CSV.ps1) | Creates Microsoft 365 groups and SharePoint team sites in bulk from a CSV. | Tenant admin (M365) | Admin PC | No | ⚠️ Creates tenant objects. Check the CSV first. | - |
| [RPT-M365 Entra Join - Device Status](RPT-M365%20Entra%20Join%20-%20Device%20Status.ps1) | Shows whether the device is Entra joined, hybrid joined or domain joined. | Report (read-only) | System | No | - | `joinTypeCustomFieldName`, `tenantInfoCustomFieldName` |
<!-- scripts:end -->
