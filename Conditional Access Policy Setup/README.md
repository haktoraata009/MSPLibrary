# Conditional Access Policy Setup

Baseline Conditional Access policy installers for SMB tenants.

## Before you run

- Run from an admin workstation with the AzureAD module and Conditional Access Administrator rights.
- Policies can lock users out. Create them in report-only mode first and exclude break-glass accounts.
- The office named location uses documentation IPs (203.0.113.x) and office.example.com. Replace with your office IPs.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [AddConditionalAccessPolicies](AddConditionalAccessPolicies.ps1) | Creates a baseline set of Conditional Access policies for SMB tenants, including a trusted office named location (AzureAD module). | - | Admin PC |
| [BaselineConditionalAccessPolicies](BaselineConditionalAccessPolicies.ps1) | Creates or updates the baseline Conditional Access policies and refreshes the office named location from a DNS record (AzureAD module). | - | Admin PC |
| [Install-ITPMBaselineCAPolicies](Install-ITPMBaselineCAPolicies.ps1) | Variant of the baseline Conditional Access policy installer with the office IP named location excluded from MFA policies (AzureAD module). | - | Admin PC |
<!-- scripts:end -->
