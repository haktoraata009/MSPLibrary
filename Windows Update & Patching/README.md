# Windows Update & Patching

Windows Update checks and controls: feature updates, drivers, delivery optimisation and patch-failure alerting.

## Before you run

- If your RMM already manages patching, use only the MON- and RPT- scripts here.
- Feature update and driver scripts download large files and may restart the device.
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
| [CFG-WU Delivery Optimization - Bandwidth Limit](CFG-WU%20Delivery%20Optimization%20-%20Bandwidth%20Limit.ps1) | Limits how much bandwidth Windows and Store updates can use. | Config change | System | No | ⚠️ Updates download slower. | `maxBackgroundDownloadSpeed`, `maxForegroundDownloadSpeed` |
| [CFG-WU Feature Update - Target Version](CFG-WU%20Feature%20Update%20-%20Target%20Version.ps1) | Pins Windows to a chosen feature update version. | Config change | System | No | ⚠️ Blocks newer feature updates until removed. | `resetToDefaults`, `targetVersion` |
| [INS-WU Drivers - Install from Windows Update](INS-WU%20Drivers%20-%20Install%20from%20Windows%20Update.ps1) | Finds and installs driver updates from Microsoft Update. | Install / Update | System | Needed to apply | ⚠️ New drivers can cause hardware issues. Pilot first. | - |
| [INS-WU Feature Update - Windows 11 Latest](INS-WU%20Feature%20Update%20-%20Windows%2011%20Latest.ps1) | Upgrades Windows 11 to the latest feature update with the Installation Assistant. | Install / Update | System | Restarts device | ⚠️ Large download and long install. Schedule after hours. | `Username` |
| [MON-WU Windows Update - Patch Failure Alert](MON-WU%20Windows%20Update%20-%20Patch%20Failure%20Alert.ps1) | Alerts when updates fail, a patch reboot is overdue, or no update has installed for too long. | Monitor / Alert | System | No | - | `daysToCheck`, `daysWithoutSuccessfulUpdate`, `ignoreDefenderDefinitions`, `ignoreStoreApps`, `multilineCustomFieldName`, `pendingRebootAlertDays` +2 more |
| [RPT-WU Windows Update - Diagnostic](RPT-WU%20Windows%20Update%20-%20Diagnostic.ps1) | Checks Windows Update services and settings and reports problems. | Report (read-only) | System | No | - | `Days`, `NinjaPesterTesting`, `resultscustomfield` |
<!-- scripts:end -->
