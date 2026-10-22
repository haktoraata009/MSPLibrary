# Monitoring & Alerts

Scheduled checks that write a status to a custom field and exit non-zero when something needs attention.

## Before you run

- Built for NinjaOne: script variables arrive as $env:camelCase and results go to custom fields through Ninja-Property-Set.
- Schedule daily or weekly and alert on the custom field or exit code.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [Blue Screen Alert](Blue%20Screen%20Alert.ps1) | Scans the Event Viewer for Blue Screen of Death (BSOD) events and generates an alert if any are detected within the specified time frame. | `maxEvents`, `minutesAgo`, `multilineCustomFieldName`, `saveFullHistory`, `Username`, `wysiwygCustomFieldName` | No |
| [Check Battery Health](Check%20Battery%20Health.ps1) | Retrieves the overall battery health and optionally saves the results to a WYSIWYG custom field. | `Username`, `wysiwygCustomFieldName` | No |
| [Check for Stopped Automatic Services](Check%20for%20Stopped%20Automatic%20Services.ps1) | Reports on or starts services for Automatic Services that are not currently running. | `servicesToExclude`, `startFoundServices` | Yes |
| [Disk Space Alert](Disk%20Space%20Alert.ps1) | Reports on the current volumes on the system. | `alertOnlyForDataVolumes`, `dataVolumeMinimumFreeSize`, `dataVolumeMinimumPercentageFree`, `excludeDataVolumesFromAlert`, `excludeRecoveryAndEspPartitions`, `hideNonalertingVolumesFromActivityLog` +11 more | No |
| [Enable Mini-Dumps for BSOD (Blue Screen)](Enable%20Mini-Dumps%20for%20BSOD%20%28Blue%20Screen%29.ps1) | Turn on mini dumps if they are off, if other dumps are already enabled do not change the configuration. | - | Yes |
| [SSD Wear Health Alert](SSD%20Wear%20Health%20Alert.ps1) | Conditional script that helps determine if an SSD drive is failing or has failed. | `WearLevelPercentMax` | No |
| [System Performance Check](System%20Performance%20Check.ps1) | Collects system performance data (CPU, memory, disk, and network). | `daysSinceLastReboot`, `displayUserMessage`, `durationToPerformTests`, `numberOfEvents`, `performInternetSpeedTest`, `randomSleepForSpeedTest` +2 more | No |
| [WAN IP Change Alert](WAN%20IP%20Change%20Alert.ps1) | Alert when a device's current WAN IP address deviates from expected IP(s). | `computername`, `ExpectedWANIP`, `ExpectedWANIPFromCustomFieldName`, `WANIPHistoryCustomFieldName` | No |
| [Windows Reliability Index Report](Windows%20Reliability%20Index%20Report.ps1) | Returns the last score and a daily average report of the Windows Reliability Index. | `computername`, `TextCustomFieldName`, `WYSIWYGCustomFieldName` | No |
<!-- scripts:end -->
