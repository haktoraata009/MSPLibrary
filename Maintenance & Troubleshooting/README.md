# Maintenance & Troubleshooting

Repair and diagnostic tools for technicians: DISM, WMI, search index, event logs and registry search.

## Before you run

- Run on demand against one device, not on a schedule.
- Repair scripts (DISM, defrag, search rebuild) use disk and CPU. Run outside business hours where possible.
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
| [CFG-MNT Event Log - Optimize Settings](CFG-MNT%20Event%20Log%20-%20Optimize%20Settings.ps1) | Increases event log sizes and turns on extra logging for troubleshooting and security. | Config change | System | No | ⚠️ Uses more disk space for logs. | `setToMicrosoftDefaults`, `WhatIf` |
| [FIX-MNT Browser - Clear Cache](FIX-MNT%20Browser%20-%20Clear%20Cache.ps1) | Clears Chrome, Edge and Firefox cache for all or selected users. | Repair / Fix | System | No | ⚠️ Browsers may need to be closed. | `forceCloseBrowsers`, `googleChrome`, `microsoftEdge`, `mozillaFirefox`, `username`, `usernames` |
| [FIX-MNT Disk - Optimize and Defrag](FIX-MNT%20Disk%20-%20Optimize%20and%20Defrag.ps1) | Trims SSDs and defragments hard drives, choosing the right method per drive. | Repair / Fix | System | No | ⚠️ Heavy disk use. Run after hours. | `action`, `driveLettersOrMountPoints`, `multilineCustomFieldName`, `performActionOnAllVolumes`, `Username`, `wysiwygCustomFieldName` |
| [FIX-MNT DISM - Image Repair](FIX-MNT%20DISM%20-%20Image%20Repair.ps1) | Runs DISM to check and repair the Windows system image. | Repair / Fix | System | No | ⚠️ High CPU and disk use for a long time. Run after hours. | `componentCleanup`, `forceReboot`, `healthAction`, `maxTimeout`, `multilineCustomFieldName`, `repairSource` +3 more |
| [FIX-MNT Windows Activation - Reset to OEM Key](FIX-MNT%20Windows%20Activation%20-%20Reset%20to%20OEM%20Key.ps1) | Replaces the Windows product key with the key built into the firmware and activates. | Repair / Fix | System | No | ⚠️ Removes the current product key. | - |
| [FIX-MNT Windows Search - Rebuild Index](FIX-MNT%20Windows%20Search%20-%20Rebuild%20Index.ps1) | Deletes and rebuilds the Windows Search index. | Repair / Fix | System | No | ⚠️ Search results are incomplete until the rebuild finishes. | - |
| [MON-MNT WMI - Health Check](MON-MNT%20WMI%20-%20Health%20Check.ps1) | Tests common WMI classes and alerts if WMI is broken. | Monitor / Alert | System | No | - | `MultilineCustomFieldName`, `Username`, `WYSIWYGCustomFieldName` |
| [RPT-MNT Device - Description](RPT-MNT%20Device%20-%20Description.ps1) | Reads the computer description and can save it to a custom field. | Report (read-only) | System | No | - | `nameOfCustomField` |
| [RPT-MNT Event Log - Search](RPT-MNT%20Event%20Log%20-%20Search.ps1) | Searches event logs by log, source, ID or text. | Report (read-only) | System | No | - | `eventEnd`, `eventIds`, `eventLogMessage`, `eventLogName`, `eventLogSource`, `eventStart` +3 more |
| [RPT-MNT Registry - Find Key](RPT-MNT%20Registry%20-%20Find%20Key.ps1) | Searches the registry for keys, names or values that contain your text. | Report (read-only) | System | No | ⚠️ Deep searches are slow. | `customFieldName`, `rootKeyToSearch`, `searchDepth`, `searchFor`, `searchForMatchingKeyPaths`, `searchForMatchingKeyProperties` +2 more |
| [RPT-MNT Scheduled Tasks - Report](RPT-MNT%20Scheduled%20Tasks%20-%20Report.ps1) | Lists scheduled tasks on the device. | Report (read-only) | System | No | - | `includeDisabledTasks`, `includeMicrosoftTasks`, `MultilineCustomFieldName`, `TaskName`, `Username`, `WYSIWYGCustomFieldName` |
<!-- scripts:end -->
