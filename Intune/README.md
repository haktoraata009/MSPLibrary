# Intune

Intune and Autopilot helpers: hardware hashes, remote wipe, Win32 app detection, app assignments and small user settings.

## Before you run

- DET- scripts go in the Intune Win32 app detection rule.
- Scripts marked Run as User change HKCU and must run in the user context.
- CFG-INT Device - Remote Wipe erases the device. Confirm the target first.
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
| [ADM-INT Intune Apps - Assignments (Graph REST)](ADM-INT%20Intune%20Apps%20-%20Assignments%20%28Graph%20REST%29.ps1) | Lists every Intune app and which groups it is assigned to. | Tenant admin (M365) | Admin PC | No | ⚠️ Uses old ADAL sign-in; prefer the Graph SDK version. | - |
| [ADM-INT Intune Apps - Assignments (Graph SDK)](ADM-INT%20Intune%20Apps%20-%20Assignments%20%28Graph%20SDK%29.ps1) | Lists every Intune app and which groups it is assigned to. | Tenant admin (M365) | Admin PC | No | - | - |
| [CFG-INT Device - Remote Wipe](CFG-INT%20Device%20-%20Remote%20Wipe.ps1) | Wipes the device, either keeping user data or fully resetting it. | Config change | System | Restarts device | ⚠️ Erases the device. Confirm the target before running. | `computerNameBypass`, `computerToWipe`, `Username`, `wipeOption` |
| [CFG-INT Office AutoCorrect - Disable Replace Text](CFG-INT%20Office%20AutoCorrect%20-%20Disable%20Replace%20Text.ps1) | Turns off AutoCorrect text replacement in Office for the signed-in user. | Config change | User | No | - | - |
| [CFG-INT Outlook - Cached Mode 6 Months](CFG-INT%20Outlook%20-%20Cached%20Mode%206%20Months.ps1) | Sets Outlook to keep 6 months of mail offline. | Config change | User | No | ⚠️ Older mail is only available online. | - |
| [DET-INT Teams - Detection](DET-INT%20Teams%20-%20Detection.ps1) | Intune detection rule: reports success when the new Teams is installed. | Intune detection | Intune | No | - | - |
| [FIX-INT AppLocker - Policy Cleanup](FIX-INT%20AppLocker%20-%20Policy%20Cleanup.ps1) | Deletes leftover AppLocker policy files after an Intune AppLocker policy is removed. | Repair / Fix | System | Needed to apply | ⚠️ Removes all local AppLocker rules. | - |
| [FIX-INT Intune - Force Sync](FIX-INT%20Intune%20-%20Force%20Sync.ps1) | Starts an Intune sync from the device straight away. | Repair / Fix | System | No | - | - |
| [INS-INT Teams - Install or Update](INS-INT%20Teams%20-%20Install%20or%20Update.ps1) | Installs or updates the new Microsoft Teams using teamsbootstrapper.exe. | Install / Update | System | No | ⚠️ Package with teamsbootstrapper.exe as an Intune Win32 app. | - |
| [REM-INT HP Bloatware - Remove](REM-INT%20HP%20Bloatware%20-%20Remove.ps1) | Removes common HP preinstalled apps (Intune version with detection log). | Uninstall | System | No | ⚠️ Uninstalls without prompting. | - |
| [REM-INT Teams Classic Appx - Remove](REM-INT%20Teams%20Classic%20Appx%20-%20Remove.ps1) | Removes the built-in consumer Teams app. | Uninstall | System | No | - | - |
| [RPT-INT Autopilot - Export Hardware Hash CSV](RPT-INT%20Autopilot%20-%20Export%20Hardware%20Hash%20CSV.ps1) | Saves the device's Autopilot hardware hash to C:\HWID as a CSV for upload. | Report (read-only) | System | No | ⚠️ Installs a script from PowerShell Gallery. | - |
| [RPT-INT Autopilot - Get-WindowsAutopilotInfo](RPT-INT%20Autopilot%20-%20Get-WindowsAutopilotInfo.ps1) | Community script that collects Autopilot hardware hashes and can upload them to Intune. | Report (read-only) | System | Optional | ⚠️ With -Online -Assign -Reboot it registers and restarts the device. | - |
| [RPT-INT Autopilot - Hardware ID to Custom Field](RPT-INT%20Autopilot%20-%20Hardware%20ID%20to%20Custom%20Field.ps1) | Reads the Autopilot hardware hash and saves it to a custom field. | Report (read-only) | System | No | - | `customFieldName` |
<!-- scripts:end -->
