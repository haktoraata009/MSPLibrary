# Monitoring & Alerts

Scheduled checks that write a status to a custom field and exit non-zero when something needs attention.

## Before you run

- Built for NinjaOne: script variables arrive as $env:camelCase and results go to custom fields through Ninja-Property-Set.
- Schedule daily or weekly and alert on the custom field or exit code.
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
| [CFG-SYS BSOD - Enable Mini Dumps](CFG-SYS%20BSOD%20-%20Enable%20Mini%20Dumps.ps1) | Turns on small crash dump files so blue screens can be diagnosed. | Config change | System | Needed to apply | - | - |
| [MON-HW Disk - Space Alert](MON-HW%20Disk%20-%20Space%20Alert.ps1) | Alerts when a drive is low on free space. | Monitor / Alert | System | No | - | `alertOnlyForDataVolumes`, `dataVolumeMinimumFreeSize`, `dataVolumeMinimumPercentageFree`, `excludeDataVolumesFromAlert`, `excludeRecoveryAndEspPartitions`, `hideNonalertingVolumesFromActivityLog` +11 more |
| [MON-HW SSD - Wear Health Alert](MON-HW%20SSD%20-%20Wear%20Health%20Alert.ps1) | Alerts when an SSD is worn out or failing. | Monitor / Alert | System | No | - | `WearLevelPercentMax` |
| [MON-NET WAN IP - Change Alert](MON-NET%20WAN%20IP%20-%20Change%20Alert.ps1) | Alerts when the site's public IP is not the expected one. | Monitor / Alert | System | No | - | `computername`, `ExpectedWANIP`, `ExpectedWANIPFromCustomFieldName`, `WANIPHistoryCustomFieldName` |
| [MON-SYS BSOD - Alert](MON-SYS%20BSOD%20-%20Alert.ps1) | Alerts when the device has had a blue screen crash recently. | Monitor / Alert | System | No | - | `maxEvents`, `minutesAgo`, `multilineCustomFieldName`, `saveFullHistory`, `Username`, `wysiwygCustomFieldName` |
| [MON-SYS Services - Stopped Automatic Services](MON-SYS%20Services%20-%20Stopped%20Automatic%20Services.ps1) | Alerts on automatic services that are not running, and can start them. | Monitor / Alert | System | No | ⚠️ With start enabled it starts services without asking. | `servicesToExclude`, `startFoundServices` |
| [RPT-HW Battery - Health Report](RPT-HW%20Battery%20-%20Health%20Report.ps1) | Reports laptop battery wear and health. | Report (read-only) | System | No | - | `Username`, `wysiwygCustomFieldName` |
| [RPT-SYS Performance - System Check](RPT-SYS%20Performance%20-%20System%20Check.ps1) | Measures CPU, memory, disk and network use over a short period. | Report (read-only) | System | No | ⚠️ Optional speed test uses bandwidth. | `daysSinceLastReboot`, `displayUserMessage`, `durationToPerformTests`, `numberOfEvents`, `performInternetSpeedTest`, `randomSleepForSpeedTest` +2 more |
| [RPT-SYS Reliability Index - Report](RPT-SYS%20Reliability%20Index%20-%20Report.ps1) | Reports the Windows Reliability score and its daily trend. | Report (read-only) | System | No | - | `computername`, `TextCustomFieldName`, `WYSIWYGCustomFieldName` |
<!-- scripts:end -->
