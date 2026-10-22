# Windows Configuration

Workstation baseline settings: power, taskbar, wallpaper, screensaver, long paths, trusted sites and device branding.

## Before you run

- Run as System to apply to all users. Some scripts apply to the current user only when run as that user.
- Rename Computer needs a restart, and domain credentials for domain-joined devices.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [Active Power Plan Report](Active%20Power%20Plan%20Report.ps1) | Reports the active power plan and active power settings. | `powerPlanCustomFieldName`, `powerSettingsCustomFieldName` | No |
| [Add or Remove Trusted Site](Add%20or%20Remove%20Trusted%20Site.ps1) | Manages trusted sites in Internet Explorer and Edge by adding, removing, or listing HTTPS URLs in specified trust zones. | `action`, `trustZone`, `url`, `Username` | Yes |
| [Change Screensaver](Change%20Screensaver.ps1) | Change the screensaver settings for all user profiles on a Windows machine. | `forceReboot`, `onResumeEnterPassword`, `photosDirectoryPath`, `selectScreensaver`, `textFor3DText`, `Username` +1 more | Yes |
| [Configure Windows 11 Taskbar Settings](Configure%20Windows%2011%20Taskbar%20Settings.ps1) | Configure common Windows 11 taskbar settings for all users (when run as 'System') or just the current user (when run as 'Current Logged On User'). | `autoHideTaskbar`, `restartExplorer`, `searchButton`, `taskbarAlignment`, `taskViewButton`, `widgetsButton` | Yes |
| [Enable Long File Paths](Enable%20Long%20File%20Paths.ps1) | Enables long file paths on Windows. | `reboot` | Yes |
| [Enable Optional Windows Features on Workstations](Enable%20Optional%20Windows%20Features%20on%20Workstations.ps1) | Enable Optional Windows Features on Workstations. | `featureNameToInstall`, `getFeatureNameList`, `installParentOrDefaultFeatures`, `restartIfNeeded` | Yes |
| [Enable or Disable Fast Startup](Enable%20or%20Disable%20Fast%20Startup.ps1) | Enable or Disable Windows Fast Boot, also known as Hiberboot or Fast Startup. | `action` | Yes |
| [Enable or Disable Start Menu Power Options](Enable%20or%20Disable%20Start%20Menu%20Power%20Options.ps1) | Enable (show) or disable (hide) the shutdown, restart, sleep, and hibernate options in the start menu power options in Windows. | `Action`, `computername`, `hibernate`, `restart`, `shutdown`, `sleep` | Yes |
| [Rename Computer](Rename%20Computer.ps1) | Renames domain-joined or non-domain-joined computers. | `computername`, `domainAdminPasswordCustomField`, `domainAdminUsername`, `newComputerName`, `reboot` | Yes |
| [Restore RightClickMenu](Restore%20RightClickMenu.ps1) | Restores the classic Windows 10 right-click menu on Windows 11 for the current user (runs once). | - | Yes |
| [Set Computer Branding - Windows](Set%20Computer%20Branding%20-%20Windows.ps1) | Set the support contact and website information for a device as well as the model and manufacturer. | `Manufacturer`, `Model`, `removeIfBlank`, `SupportHours`, `SupportPhone`, `SupportURL` | Yes |
| [Set Desktop Wallpaper](Set%20Desktop%20Wallpaper.ps1) | This sets the desktop background for all existing users (if run as System) or the currently logged-in user (if run as 'Current Logged on User'). | `AppData`, `directoryToStoreWallpaperIn`, `replaceTranscodedWallpaperFile`, `restartExplorer`, `Username`, `wallpaperDisplayMode` +1 more | Yes |
<!-- scripts:end -->
