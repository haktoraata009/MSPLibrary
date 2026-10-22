# Active Directory

Reports and fixes for on-premises Active Directory.

## Before you run

- Run on a domain controller or a machine with RSAT (ActiveDirectory module).
- Report scripts are read-only. Resolve AD Sync Object changes Entra ID objects; read it line by line before use.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [Active Directory - Active Users Report](Active%20Directory%20-%20Active%20Users%20Report.ps1) | Retrieves and reports on active Active Directory users based on their last login date. | `excludeDisabledUsersFromReport`, `maximumDaysSinceLastLogin`, `multilineCustomFieldName`, `Username`, `wysiwygCustomFieldName` | No |
| [Active Directory - Audit Report](Active%20Directory%20-%20Audit%20Report.ps1) | Generates a report of the current Active Directory environment and optionally saves the information to a WYSIWYG custom field. | `disabledUsersWysiwygCustomFieldName`, `domainSummaryWysiwygCustomFieldName`, `enabledUsersWysiwygCustomFieldName`, `groupMembershipWysiwygCustomFieldName`, `inactivityDaysLimit`, `Username` | No |
| [ADUserLastLogon](ADUserLastLogon.ps1) | Queries every domain controller for each user's real last logon time and exports the result to CSV. | - | No |
| [Export AD User Details](Export%20AD%20User%20Details.ps1) | One-liner that exports all AD users (name, city, company, department, email, phone) to C:\temp\export-all.csv. | - | No |
| [Export-GroupsAndMembers](Export-GroupsAndMembers.ps1) | Exports all Entra ID (Azure AD) groups with their members, email address and group type to CSV via Microsoft Graph. | - | Admin PC |
| [Password Expiration Alert Report](Password%20Expiration%20Alert%20Report.ps1) | Generates a report of users whose passwords are nearing expiration, including both Active Directory domain and local accounts. | `ComputerName`, `customFieldName`, `daysUntilPasswordExpiration`, `ExcludeFineGrainedPasswordPolicyUsersOnWorkstations`, `loggedInUsersOnly` | No |
| [Resolve AD Sync Object](Resolve%20AD%20Sync%20Object.ps1) | Snippets to fix a broken Entra Connect match: read the on-prem ImmutableID, hard-link it to the cloud user, and fix a UPN. | - | Yes |
<!-- scripts:end -->
