# Windows Configuration

Workstation baseline settings: power, taskbar, wallpaper, screensaver, long paths, trusted sites and device branding.

## Before you run

- Run as System to apply to all users. Scripts marked Run as User apply to the signed-in user.
- CFG-SYS Computer - Rename needs a restart, and domain credentials for domain-joined devices.
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
| [CFG-SYS Branding - Set Support Info](CFG-SYS%20Branding%20-%20Set%20Support%20Info.ps1) | Sets support contact details shown in Windows Settings. | Config change | System | No | - | `Manufacturer`, `Model`, `removeIfBlank`, `SupportHours`, `SupportPhone`, `SupportURL` |
| [CFG-SYS Computer - Rename](CFG-SYS%20Computer%20-%20Rename.ps1) | Renames the computer, including domain-joined devices. | Config change | System | Needed to apply | ⚠️ Needs a restart. Domain devices need domain credentials. | `computername`, `domainAdminPasswordCustomField`, `domainAdminUsername`, `newComputerName`, `reboot` |
| [CFG-SYS Context Menu - Restore Classic](CFG-SYS%20Context%20Menu%20-%20Restore%20Classic.ps1) | Brings back the full right-click menu on Windows 11. | Config change | User | No | ⚠️ Applies after Explorer restarts or the user signs in again. | - |
| [CFG-SYS Fast Startup - Enable or Disable](CFG-SYS%20Fast%20Startup%20-%20Enable%20or%20Disable.ps1) | Turns Fast Startup on or off. | Config change | System | No | - | `action` |
| [CFG-SYS Long File Paths - Enable](CFG-SYS%20Long%20File%20Paths%20-%20Enable.ps1) | Allows file paths longer than 260 characters. | Config change | System | Optional | - | `reboot` |
| [CFG-SYS Optional Features - Enable](CFG-SYS%20Optional%20Features%20-%20Enable.ps1) | Turns on selected optional Windows features. | Config change | System | Optional | - | `featureNameToInstall`, `getFeatureNameList`, `installParentOrDefaultFeatures`, `restartIfNeeded` |
| [CFG-SYS Screensaver - Set](CFG-SYS%20Screensaver%20-%20Set.ps1) | Sets the screensaver and timeout for all users. | Config change | System | No | - | `forceReboot`, `onResumeEnterPassword`, `photosDirectoryPath`, `selectScreensaver`, `textFor3DText`, `Username` +1 more |
| [CFG-SYS Start Menu Power Options - Enable or Disable](CFG-SYS%20Start%20Menu%20Power%20Options%20-%20Enable%20or%20Disable.ps1) | Shows or hides shut down, restart, sleep and hibernate in the Start menu. | Config change | System | No | - | `Action`, `computername`, `hibernate`, `restart`, `shutdown`, `sleep` |
| [CFG-SYS Taskbar - Windows 11 Settings](CFG-SYS%20Taskbar%20-%20Windows%2011%20Settings.ps1) | Sets Windows 11 taskbar options such as alignment, search and widgets. | Config change | System | No | ⚠️ Can restart Explorer; the screen flickers. | `autoHideTaskbar`, `restartExplorer`, `searchButton`, `taskbarAlignment`, `taskViewButton`, `widgetsButton` |
| [CFG-SYS Trusted Sites - Add or Remove](CFG-SYS%20Trusted%20Sites%20-%20Add%20or%20Remove.ps1) | Adds, removes or lists trusted sites for Edge and Internet Explorer. | Config change | System | No | ⚠️ Trusted sites get relaxed security settings. | `action`, `trustZone`, `url`, `Username` |
| [CFG-SYS Wallpaper - Set](CFG-SYS%20Wallpaper%20-%20Set.ps1) | Sets the desktop wallpaper for all users. | Config change | System | No | ⚠️ Can restart Explorer; the screen flickers. | `AppData`, `directoryToStoreWallpaperIn`, `replaceTranscodedWallpaperFile`, `restartExplorer`, `Username`, `wallpaperDisplayMode` +1 more |
| [RPT-SYS Power Plan - Report](RPT-SYS%20Power%20Plan%20-%20Report.ps1) | Reports the active power plan and its settings. | Report (read-only) | System | No | - | `powerPlanCustomFieldName`, `powerSettingsCustomFieldName` |
<!-- scripts:end -->
