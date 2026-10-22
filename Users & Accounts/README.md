# Users & Accounts

Local user and profile reports, local admin management and session control.

## Before you run

- Report scripts are read-only.
- Create Local Admin User has placeholder Username and Password values. Pass the password in through a secure script variable rather than typing it into the script.
- Log Off Users ends sessions without saving work.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [Create Local Admin User](Create%20Local%20Admin%20User.ps1) | No description yet. | - | Yes |
| [Delete Cached Windows Credentials](Delete%20Cached%20Windows%20Credentials.ps1) | Deletes cached Microsoft credentials from Windows Credential Manager for the current user. | - | Yes |
| [Disable Local Admin Tools](Disable%20Local%20Admin%20Tools.ps1) | This will disable the selected administrator tools depending on your selection (Defaults to all). | `allTools`, `excludeUsers` | Yes |
| [Enable Local Admin Tools](Enable%20Local%20Admin%20Tools.ps1) | This will enable the selected administrator tools depending on your selection (Defaults to all). | `allTools`, `excludeUsers` | Yes |
| [Local Admins Report](Local%20Admins%20Report.ps1) | Updates a custom field with a list of local admins. | `customFieldName`, `delimiter` | No |
| [Local Users Report](Local%20Users%20Report.ps1) | List all local accounts on the machine and optionally save the results to a WYSIWYG custom field. | `includeDisabledUsers`, `Username`, `wysiwygCustomFieldName` | No |
| [Log Off Users](Log%20Off%20Users.ps1) | Logs off user(s) specified. | `logOffAllUsers`, `usersToLogoff` | Yes |
| [Orphaned User Profile Report](Orphaned%20User%20Profile%20Report.ps1) | Looks for user profile folders that do not have an associated user account. | `ComputerName`, `wysiwygCustomFieldName` | No |
| [User Logon History Report](User%20Logon%20History%20Report.ps1) | Generate a report of user session start (logon) and stop (logoff) events. | `ExcludeUsersFromReport`, `inTheLastXDays`, `maxRecordsToReturn`, `multilineCustomFieldName`, `RetrieveExcludedUsersFromCustomField`, `Username` +2 more | No |
| [User Profile Size Report](User%20Profile%20Size%20Report.ps1) | Updates a Custom Field with the total size of all User Profiles. | `customFieldName`, `sizeInGbToAlertOn` | No |
<!-- scripts:end -->
