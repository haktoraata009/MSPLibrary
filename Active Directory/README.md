# Active Directory

Reports and fixes for on-premises Active Directory.

## Before you run

- Run on a domain controller or a machine with RSAT (ActiveDirectory module).
- FIX-AD Entra Connect - Resolve Sync Object changes cloud identities. Run it one line at a time.
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
| [FIX-AD Entra Connect - Resolve Sync Object](FIX-AD%20Entra%20Connect%20-%20Resolve%20Sync%20Object.ps1) | Step-by-step commands to re-link an on-prem AD user to its cloud account when sync breaks. | Repair / Fix | Admin PC | No | ⚠️ Changes cloud identities. Run one line at a time and check each result. | - |
| [MON-AD Password - Expiration Alert](MON-AD%20Password%20-%20Expiration%20Alert.ps1) | Lists users whose passwords expire soon and alerts so they can be reminded. | Monitor / Alert | Domain controller | No | - | `ComputerName`, `customFieldName`, `daysUntilPasswordExpiration`, `ExcludeFineGrainedPasswordPolicyUsersOnWorkstations`, `loggedInUsersOnly` |
| [RPT-AD Domain - Audit Report](RPT-AD%20Domain%20-%20Audit%20Report.ps1) | Summarises the AD environment: domain controllers, FSMO roles, users, groups and policies. | Report (read-only) | Domain controller | No | - | `disabledUsersWysiwygCustomFieldName`, `domainSummaryWysiwygCustomFieldName`, `enabledUsersWysiwygCustomFieldName`, `groupMembershipWysiwygCustomFieldName`, `inactivityDaysLimit`, `Username` |
| [RPT-AD Users - Active Users Report](RPT-AD%20Users%20-%20Active%20Users%20Report.ps1) | Lists AD users who have logged on within a set number of days. | Report (read-only) | Domain controller | No | - | `excludeDisabledUsersFromReport`, `maximumDaysSinceLastLogin`, `multilineCustomFieldName`, `Username`, `wysiwygCustomFieldName` |
| [RPT-AD Users - Export Details](RPT-AD%20Users%20-%20Export%20Details.ps1) | Exports all AD users' name, department, email and phone to C:\temp\export-all.csv. | Report (read-only) | Domain controller | No | - | - |
| [RPT-AD Users - Last Logon Report](RPT-AD%20Users%20-%20Last%20Logon%20Report.ps1) | Checks every domain controller for each user's true last logon and saves a CSV. | Report (read-only) | Domain controller | No | ⚠️ Queries every DC; slow in large domains. | - |
<!-- scripts:end -->
