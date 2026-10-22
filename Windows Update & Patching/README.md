# Windows Update & Patching

Windows Update checks and controls: feature updates, drivers, delivery optimisation and patch-failure alerting.

## Before you run

- If your RMM already manages patching, use only the alert and diagnostic scripts here.
- Feature update and driver scripts download large files and may restart the device.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [Deploy Latest Windows 11 Feature Update](Deploy%20Latest%20Windows%2011%20Feature%20Update.ps1) | Update Windows 11 to the latest available Feature Update using the Windows 11 Install Assistant. | `Username` | Yes |
| [Install MS Driver updates via Windows Update](Install%20MS%20Driver%20updates%20via%20Windows%20Update.ps1) | Searches Microsoft Update for pending driver updates, downloads and installs them. | - | Yes |
| [Patching - Set Bandwidth Delivery Optimization for Windows](Patching%20-%20Set%20Bandwidth%20Delivery%20Optimization%20for%20Windows.ps1) | Limit how much bandwidth a device can consume with updates and microsoft store updates. | `maxBackgroundDownloadSpeed`, `maxForegroundDownloadSpeed` | Yes |
| [Set Feature Updates via Registry](Set%20Feature%20Updates%20via%20Registry.ps1) | Lock Windows Update to only request a specific feature update that you specify. | `resetToDefaults`, `targetVersion` | Yes |
| [Windows Patch Failure Alert](Windows%20Patch%20Failure%20Alert.ps1) | Alerts when Windows updates have failed to install, a reboot to finish patching is overdue, or no update has installed successfully for too long. | `daysToCheck`, `daysWithoutSuccessfulUpdate`, `ignoreDefenderDefinitions`, `ignoreStoreApps`, `multilineCustomFieldName`, `pendingRebootAlertDays` +2 more | No |
| [Windows Update Diagnostic](Windows%20Update%20Diagnostic.ps1) | Diagnose Windows Update issues. | `Days`, `NinjaPesterTesting`, `resultscustomfield` | No |
<!-- scripts:end -->
