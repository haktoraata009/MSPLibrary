# Office

Microsoft 365 Apps install, repair and Outlook data file checks.

## Before you run

- Install and Repair download from Microsoft and close Office apps. Warn users first.
- The install script builds an Office Deployment Tool XML from script variables, or uses your own XML.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [Office 365 - Install - Custom XML](Office%20365%20-%20Install%20-%20Custom%20XML.ps1) | Installs an Office product using the Office Deployment Tool. | `additionalProducts`, `forceRestart`, `microsoftAccessRuntime365`, `officeSuites`, `productActivation`, `project` +5 more | Yes |
| [Office 365 - Repair](Office%20365%20-%20Repair.ps1) | Repairs Microsoft Office 365 installations supporting Quick Repair and Online Repair modes. | `forceCloseOfficeApps`, `rebootIfSuccessful`, `repairMode` | Yes |
| [Office 365 Modern Auth Alert](Office%20365%20Modern%20Auth%20Alert.ps1) | Monitors if user profiles have modern auth for Office 365 enabled or disabled. | - | No |
| [Report on Large OST and PST Files](Report%20on%20Large%20OST%20and%20PST%20Files.ps1) | Searches local drives for .pst and .ost files that exceed a defined size and optionally saves the results to a custom field. | `minimumAlertAndReportingSize`, `multilineCustomFieldName`, `Username`, `wysiwygCustomFieldName` | No |
<!-- scripts:end -->
