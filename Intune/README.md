# Intune

Intune and Autopilot helpers: hardware hashes, remote wipe, Win32 app detection and small user settings.

## Before you run

- Detection scripts (for example msteams-detection.ps1) go in the Intune Win32 app detection rule.
- HKCU scripts must run in the user context. Device scripts run as System.
- Remote Wipe resets the device. Confirm the target first.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [Audit Autopilot Hardware ID](Audit%20Autopilot%20Hardware%20ID.ps1) | Gets the hardware ID and saves it to a custom field. | `customFieldName` | No |
| [Collect Windows AutoPilot Info](Collect%20Windows%20AutoPilot%20Info.ps1) | Installs Get-WindowsAutoPilotInfo from PSGallery and saves the device hardware hash to C:\HWID\AutoPilotHWID-<serial>.csv. | - | Yes |
| [Get-WindowsAutopilotInfo](Get-WindowsAutopilotInfo.ps1) | Retrieves the Windows AutoPilot deployment details from one or more computers | - | No |
| [Intune-AppLockerCleanup](Intune-AppLockerCleanup.ps1) | Removes AppLocker policy files from C:\Windows\System32\AppLocker, useful after unassigning an Intune AppLocker policy. | - | Yes |
| [MSTeams Update](MSTeams%20Update.ps1) | Runs teamsbootstrapper.exe to install or update new Teams; package with teamsbootstrapper.exe as an Intune Win32 app. | - | Yes |
| [msteams-detection](msteams-detection.ps1) | Intune detection script that returns success when the new Teams (MSTeams) package is installed. | - | No |
| [New-ItemProperty Disable AutoText](New-ItemProperty%20Disable%20AutoText.ps1) | Turns off Office AutoCorrect replace-text for the current user (HKCU). | - | Yes |
| [Remote Wipe](Remote%20Wipe.ps1) | Wipe a device with a selected option such as keeping the user data or fully cleaning the internal drive (protected wipe). | `computerNameBypass`, `computerToWipe`, `Username`, `wipeOption` | Yes |
| [RemoveAppxTeams](RemoveAppxTeams.ps1) | Removes the built-in consumer Teams Appx package and writes a log file Intune can use for detection. | - | Yes |
| [RemoveHPBloat](RemoveHPBloat.ps1) | Removes common HP preinstalled apps and writes a log file Intune can use for detection. | - | Yes |
| [Set_Outlook_Cache](Set_Outlook_Cache.ps1) | Sets the Outlook cached mode sync window policy (syncwindowsetting = 6 months) for the current user. | - | Yes |
| [Sync device with Intune](Sync%20device%20with%20Intune.ps1) | Triggers an immediate MDM sync with Intune from the device. | - | Yes |
<!-- scripts:end -->
