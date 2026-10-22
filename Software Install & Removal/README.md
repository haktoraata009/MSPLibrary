# Software Install & Removal

Install runtimes (PowerShell 7, .NET) and remove bloatware or unwanted remote tools.

## Before you run

- REM- scripts uninstall software without prompting. Check the app list before running on a fleet.
- Run as System through your RMM.
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
| [FIX-APP Appx - Re-register All Packages](FIX-APP%20Appx%20-%20Re-register%20All%20Packages.ps1) | Re-registers all built-in Windows apps to fix a broken Start menu or Settings app. | Repair / Fix | User | No | ⚠️ Slow, with many error lines that can be ignored. | - |
| [INS-APP .NET Framework 4 - Install](INS-APP%20.NET%20Framework%204%20-%20Install.ps1) | Turns on .NET Framework 4.x features, optionally from offline media. | Install / Update | System | Optional | - | - |
| [INS-APP NinjaOne NMS - SQL CE 4 Upgrade](INS-APP%20NinjaOne%20NMS%20-%20SQL%20CE%204%20Upgrade.ps1) | Upgrades the NinjaOne NMS database engine to SQL CE 4.0. | Install / Update | Server | No | ⚠️ Stops NMS services during the upgrade. | - |
| [INS-APP PowerShell 5.1 - Upgrade](INS-APP%20PowerShell%205.1%20-%20Upgrade.ps1) | Upgrades old Windows to PowerShell 5.1, including .NET 4.5.2. | Install / Update | System | Needed to apply | ⚠️ Needs a restart to finish. | `forceRestart`, `Temp` |
| [INS-APP PowerShell 7 - Install or Upgrade](INS-APP%20PowerShell%207%20-%20Install%20or%20Upgrade.ps1) | Installs or upgrades PowerShell 7. | Install / Update | System | No | - | `addPowershellToTheWindowsPath`, `addToFileAndExplorerContextMenu`, `disableTelemetry`, `enableAndUseMicrosoftUpdate`, `registerPowershellToEventViewer`, `upgradeIfFound` +1 more |
| [REM-APP Dell SupportAssist - Uninstall](REM-APP%20Dell%20SupportAssist%20-%20Uninstall.ps1) | Uninstalls Dell SupportAssist apps. | Uninstall | System | No | - | `ForceCloseBeforeUninstall`, `RemoveAll`, `RemoveDellSupportAssistAppxPackages`, `RemoveDellSupportAssistForBusiness`, `RemoveDellSupportAssistForHome`, `RemoveDellSupportAssistOSRecoveryPlugin` +2 more |
| [REM-APP HP Bloatware - Remove](REM-APP%20HP%20Bloatware%20-%20Remove.ps1) | Removes HP preinstalled apps, services and Appx packages. | Uninstall | System | No | ⚠️ Uninstalls without prompting. | - |
| [REM-APP HP Support Assistant - Uninstall](REM-APP%20HP%20Support%20Assistant%20-%20Uninstall.ps1) | Uninstalls HP Support Assistant. | Uninstall | System | No | - | - |
| [REM-APP Microsoft Bloatware - Remove](REM-APP%20Microsoft%20Bloatware%20-%20Remove.ps1) | Removes common preinstalled Microsoft Store apps. | Uninstall | System | No | ⚠️ Uninstalls without prompting. Check the app list. | `appsToRemove`, `overrideWithCustomFieldName` |
| [REM-APP TeamViewer - Uninstall](REM-APP%20TeamViewer%20-%20Uninstall.ps1) | Uninstalls TeamViewer. | Uninstall | System | No | ⚠️ Check nobody relies on TeamViewer for support. | `Username` |
<!-- scripts:end -->
