# Office

Microsoft 365 Apps install, repair and Outlook data file checks.

## Before you run

- Install and Repair download from Microsoft and close Office apps. Warn users first.
- The install script builds an Office Deployment Tool XML from script variables, or uses your own XML.
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
| [FIX-OFF Microsoft 365 Apps - Repair](FIX-OFF%20Microsoft%20365%20Apps%20-%20Repair.ps1) | Runs a quick or online repair of Microsoft 365 Apps. | Repair / Fix | System | Optional | ⚠️ Closes Office apps. Warn users first. | `forceCloseOfficeApps`, `rebootIfSuccessful`, `repairMode` |
| [INS-OFF Microsoft 365 Apps - Install (Custom XML)](INS-OFF%20Microsoft%20365%20Apps%20-%20Install%20%28Custom%20XML%29.ps1) | Installs Microsoft 365 Apps with the Office Deployment Tool, using your settings or XML. | Install / Update | System | Optional | ⚠️ Closes Office apps. Can remove older MSI Office. | `additionalProducts`, `forceRestart`, `microsoftAccessRuntime365`, `officeSuites`, `productActivation`, `project` +5 more |
| [MON-OFF Modern Auth - Alert](MON-OFF%20Modern%20Auth%20-%20Alert.ps1) | Alerts when Office modern authentication is turned off for a user. | Monitor / Alert | System | No | - | - |
| [RPT-OFF OST PST - Large Files Report](RPT-OFF%20OST%20PST%20-%20Large%20Files%20Report.ps1) | Finds Outlook OST and PST files over a set size. | Report (read-only) | System | No | - | `minimumAlertAndReportingSize`, `multilineCustomFieldName`, `Username`, `wysiwygCustomFieldName` |
<!-- scripts:end -->
