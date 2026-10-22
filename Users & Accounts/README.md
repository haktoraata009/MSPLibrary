# Users & Accounts

Local user and profile reports, local admin management and session control.

## Before you run

- RPT- scripts are read-only.
- CFG-USR Local Admin - Create User has placeholder Username and Password values. Pass the password in through a secure script variable rather than typing it into the script.
- FIX-USR Sessions - Log Off Users ends sessions without saving work.
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
| [CFG-USR Admin Tools - Disable](CFG-USR%20Admin%20Tools%20-%20Disable.ps1) | Blocks users from tools such as Command Prompt, Registry Editor and Task Manager. | Config change | System | No | ⚠️ Can block support work. Test first. | `allTools`, `excludeUsers` |
| [CFG-USR Admin Tools - Enable](CFG-USR%20Admin%20Tools%20-%20Enable.ps1) | Re-allows Command Prompt, Registry Editor, Task Manager and similar tools. | Config change | System | No | - | `allTools`, `excludeUsers` |
| [CFG-USR Local Admin - Create User](CFG-USR%20Local%20Admin%20-%20Create%20User.ps1) | Creates or updates a local administrator account. | Config change | System | No | ⚠️ Creates an admin account. Pass the password securely. | - |
| [FIX-USR Credential Manager - Clear Microsoft Credentials](FIX-USR%20Credential%20Manager%20-%20Clear%20Microsoft%20Credentials.ps1) | Deletes saved Microsoft sign-ins from Credential Manager. | Repair / Fix | User | No | ⚠️ User must sign in to Office and Teams again. | - |
| [FIX-USR Sessions - Log Off Users](FIX-USR%20Sessions%20-%20Log%20Off%20Users.ps1) | Signs out selected users. | Repair / Fix | System | No | ⚠️ Unsaved work is lost. Warn users first. | `logOffAllUsers`, `usersToLogoff` |
| [RPT-USR Local Admins - Report](RPT-USR%20Local%20Admins%20-%20Report.ps1) | Lists local administrators and saves them to a custom field. | Report (read-only) | System | No | - | `customFieldName`, `delimiter` |
| [RPT-USR Local Users - Report](RPT-USR%20Local%20Users%20-%20Report.ps1) | Lists local accounts with status and last logon. | Report (read-only) | System | No | - | `includeDisabledUsers`, `Username`, `wysiwygCustomFieldName` |
| [RPT-USR Logon - History Report](RPT-USR%20Logon%20-%20History%20Report.ps1) | Lists user logon and logoff times. | Report (read-only) | System | No | - | `ExcludeUsersFromReport`, `inTheLastXDays`, `maxRecordsToReturn`, `multilineCustomFieldName`, `RetrieveExcludedUsersFromCustomField`, `Username` +2 more |
| [RPT-USR Profiles - Orphaned Profiles](RPT-USR%20Profiles%20-%20Orphaned%20Profiles.ps1) | Finds profile folders with no matching user account. | Report (read-only) | System | No | - | `ComputerName`, `wysiwygCustomFieldName` |
| [RPT-USR Profiles - Size Report](RPT-USR%20Profiles%20-%20Size%20Report.ps1) | Reports total user profile size and can alert when it is too big. | Report (read-only) | System | No | - | `customFieldName`, `sizeInGbToAlertOn` |
<!-- scripts:end -->
