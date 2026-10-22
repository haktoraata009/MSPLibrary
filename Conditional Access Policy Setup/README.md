# Conditional Access Policy Setup

Baseline Conditional Access policy installers for SMB tenants.

## Before you run

- Run from an admin workstation with the AzureAD module and Conditional Access Administrator rights.
- Policies can lock users out. Create them in report-only mode first and exclude break-glass accounts.
- The office named location uses documentation IPs (203.0.113.x) and office.example.com. Replace with your office IPs.
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
| [ADM-CA Conditional Access - Add Baseline Policies (Older)](ADM-CA%20Conditional%20Access%20-%20Add%20Baseline%20Policies%20%28Older%29.ps1) | Older version of the baseline Conditional Access policy installer. | Tenant admin (M365) | Admin PC | No | ⚠️ Can lock users out. Prefer the current version. | - |
| [ADM-CA Conditional Access - Add Baseline Policies](ADM-CA%20Conditional%20Access%20-%20Add%20Baseline%20Policies.ps1) | Creates the baseline Conditional Access policies and a trusted office location. | Tenant admin (M365) | Admin PC | No | ⚠️ Can lock users out. Use report-only first and exclude break-glass accounts. | - |
| [ADM-CA Conditional Access - Baseline Policies (DNS Location)](ADM-CA%20Conditional%20Access%20-%20Baseline%20Policies%20%28DNS%20Location%29.ps1) | Creates or updates baseline Conditional Access policies; office IPs come from a DNS record. | Tenant admin (M365) | Admin PC | No | ⚠️ Can lock users out. Use report-only first and exclude break-glass accounts. | - |
| [ADM-CA Conditional Access - ITPM Baseline Policies (v2)](ADM-CA%20Conditional%20Access%20-%20ITPM%20Baseline%20Policies%20%28v2%29.ps1) | Second version of the ITPM baseline Conditional Access policies. | Tenant admin (M365) | Admin PC | No | ⚠️ Can lock users out. Use report-only first and exclude break-glass accounts. | - |
| [ADM-CA Conditional Access - ITPM Baseline Policies](ADM-CA%20Conditional%20Access%20-%20ITPM%20Baseline%20Policies.ps1) | Baseline Conditional Access policies with the office location excluded from MFA prompts. | Tenant admin (M365) | Admin PC | No | ⚠️ Can lock users out. Use report-only first and exclude break-glass accounts. | - |
<!-- scripts:end -->
