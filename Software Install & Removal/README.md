# Software Install & Removal

Install runtimes (PowerShell 7, .NET) and remove bloatware or unwanted remote tools.

## Before you run

- Removal scripts uninstall software without prompting. Check the app list before running on a fleet.
- Run as System through your RMM.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [Fix All AppxPackage](Fix%20All%20AppxPackage.ps1) | Re-registers all Appx packages (Start menu, Settings and Store apps) for the current user. | - | Yes |
| [Install .Net Framework 4](Install%20.Net%20Framework%204.ps1) | Install NetFx4 features(.NET 4.x), with the option to install from an offline source. | - | Yes |
| [Install PowerShell 7](Install%20PowerShell%207.ps1) | Installs or upgrades the latest version of PowerShell 7 / PowerShell Core. | `addPowershellToTheWindowsPath`, `addToFileAndExplorerContextMenu`, `disableTelemetry`, `enableAndUseMicrosoftUpdate`, `registerPowershellToEventViewer`, `upgradeIfFound` +1 more | Yes |
| [Remove HP Bloatware](Remove%20HP%20Bloatware.ps1) | Removes HP preinstalled apps, Appx packages and services (community script, see header for sources). | - | Yes |
| [Remove Microsoft Bloatware](Remove%20Microsoft%20Bloatware.ps1) | Removes common bloatware that is often pre-installed on a PC. | `appsToRemove`, `overrideWithCustomFieldName` | Yes |
| [Remove TeamViewer](Remove%20TeamViewer.ps1) | Uninstalls TeamViewer. | `Username` | Yes |
| [Software Removal - Uninstall Dell Support Assist](Software%20Removal%20-%20Uninstall%20Dell%20Support%20Assist.ps1) | Removes Dell Support Assist applications from the system. | `ForceCloseBeforeUninstall`, `RemoveAll`, `RemoveDellSupportAssistAppxPackages`, `RemoveDellSupportAssistForBusiness`, `RemoveDellSupportAssistForHome`, `RemoveDellSupportAssistOSRecoveryPlugin` +2 more | Yes |
| [Software Removal - Uninstall HP Support Assistant](Software%20Removal%20-%20Uninstall%20HP%20Support%20Assistant.ps1) | Removes the HP Support Assistant. | - | Yes |
| [Update NMS SQLCE Engine](Update%20NMS%20SQLCE%20Engine.ps1) | Upgrades the NinjaOne NMS database engine to SQL CE 4.0 on the NMS server. | - | Yes |
| [Upgrade PowerShell](Upgrade%20PowerShell.ps1) | Upgrades PowerShell to version 5.1 by installing .NET Framework 4.5.2 and installing the proper Windows Management Framework (WMF) for the OS. | `forceRestart`, `Temp` | Yes |
<!-- scripts:end -->
