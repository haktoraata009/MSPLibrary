# Maintenance & Troubleshooting

Repair and diagnostic tools for technicians: DISM, WMI, search index, event logs and registry search.

## Before you run

- Run on demand against one device, not on a schedule.
- Repair scripts (DISM, defrag, search rebuild) use disk and CPU. Run outside business hours where possible.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [Clear Browser Cache](Clear%20Browser%20Cache.ps1) | Clear the browser cache for all users (when run as system), some users (when a user is specified), or just the current user (when run as current user) depending on how the script is run. | `forceCloseBrowsers`, `googleChrome`, `microsoftEdge`, `mozillaFirefox`, `username`, `usernames` | Yes |
| [DISM - Windows Image Repair](DISM%20-%20Windows%20Image%20Repair.ps1) | Start a Windows image repair utilizing the DISM tool with your specified options. | `componentCleanup`, `forceReboot`, `healthAction`, `maxTimeout`, `multilineCustomFieldName`, `repairSource` +3 more | Yes |
| [Find Registry Key](Find%20Registry%20Key.ps1) | Find a registry key path, property or value that contains your given search text. | `customFieldName`, `rootKeyToSearch`, `searchDepth`, `searchFor`, `searchForMatchingKeyPaths`, `searchForMatchingKeyProperties` +2 more | No |
| [Get Device Description](Get%20Device%20Description.ps1) | Retrieves the current device description and optionally saves it to a custom field. | `nameOfCustomField` | No |
| [Optimize and Defrag Hard Drives](Optimize%20and%20Defrag%20Hard%20Drives.ps1) | Analyzes or optimizes volumes (HDDs, SSDs, and mount points) using the appropriate method per drive type. | `action`, `driveLettersOrMountPoints`, `multilineCustomFieldName`, `performActionOnAllVolumes`, `Username`, `wysiwygCustomFieldName` | Yes |
| [Optimize EventLog](Optimize%20EventLog.ps1) | This script will set event viewer up to record additional information (according to best practices) as well as increase the eventlog sizes to 256MB's and 500MB for the Security Log. | `setToMicrosoftDefaults`, `WhatIf` | Yes |
| [Rebuild Search Index](Rebuild%20Search%20Index.ps1) | Deletes the existing Windows Search Index and forces Windows to rebuild it. | - | Yes |
| [Reset Windows Activation](Reset%20Windows%20Activation.ps1) | Replaces the current Windows product key with the firmware-embedded (OEM) key and re-activates. | - | Yes |
| [Scheduled Task Report](Scheduled%20Task%20Report.ps1) | Retrieves a list of scheduled tasks and outputs the list into the activity feed. | `includeDisabledTasks`, `includeMicrosoftTasks`, `MultilineCustomFieldName`, `TaskName`, `Username`, `WYSIWYGCustomFieldName` | No |
| [Search Event Log](Search%20Event%20Log.ps1) | Search for specific events in Event Viewer based on the event log they were in, the source of the event, or the specific event IDs used. | `eventEnd`, `eventIds`, `eventLogMessage`, `eventLogName`, `eventLogSource`, `eventStart` +3 more | No |
| [WMI - Health Check](WMI%20-%20Health%20Check.ps1) | Test the most common WMI classes for issues, optionally reporting to a multiline or WYSIWYG custom field. | `MultilineCustomFieldName`, `Username`, `WYSIWYGCustomFieldName` | No |
<!-- scripts:end -->
