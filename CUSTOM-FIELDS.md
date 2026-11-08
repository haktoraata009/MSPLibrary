# NinjaOne custom fields

Each script that writes results to a NinjaOne custom field has the field name written into the script. When the script runs from NinjaOne it writes to that field with `Ninja-Property-Set`. Create the field with the exact **Name** below (case sensitive), the type shown, and **Automations** access set to **Read/Write**. No script variable is needed for the field name. Script variables are only for values you may change, such as a number of days.

Earlier versions had field-name script variables (for example `Custom Field Name` or `Wysiwyg Custom Field Name`). The scripts no longer read them, so delete them from the script in NinjaOne.

## If a field stays empty

- The field **Name** (not the Label) matches exactly, same case. `patchFailureStatus` is not `PatchFailureStatus`.
- In NinjaOne you type a Label and Ninja builds the Name in camelCase: Label `Patch Failure Status` gives Name `patchFailureStatus`.
- The field type matches (Text, Multi-line, WYSIWYG, Secure). Text is one short line; Multi-line holds up to 10,000 characters.
- Automations access is Read/Write.
- Role custom fields must be added to the device role. Global custom fields work on every device.
- If the activity log says `Unable to find ninjarmm-cli.exe`, the NinjaOne agent on that device is damaged. Test on another device.

## Fields by script

| Custom field Name | Type | Script | What it holds |
|---|---|---|---|
| `printQueueResult` | Multi-line | FIX-HW Printer - Clear Print Queue | Print queue clear result |
| `dismRepairResult` | Multi-line | FIX-MNT DISM - Image Repair | DISM output |
| `diskOptimizeReport` | WYSIWYG | FIX-MNT Disk - Optimize and Defrag | Fragmentation chart and result |
| `msertScanResult` | Multi-line | FIX-SEC MSERT - Run Scan | MSERT scan result |
| `adPasswordExpiry` | Multi-line | MON-AD Password - Expiration Alert | Users whose passwords are about to expire |
| `diskSpaceStatus` | Multi-line | MON-HW Disk - Space Alert | Volume free space report |
| `wmiHealthStatus` | Multi-line | MON-MNT WMI - Health Check | WMI health result |
| `ipConnectionMatches` | Multi-line | MON-NET Connections - Search for IP Address | Matching connections |
| `networkProfile` | Multi-line | MON-NET Network Profile - Check | Network profile per adapter |
| `wanIpHistory` | Multi-line | MON-NET WAN IP - Change Alert | WAN IP history |
| `bitlockerStatus` | Multi-line | MON-SEC BitLocker - Status Alert | BitLocker status per volume |
| `bitlockerRecoveryKey` | Secure | MON-SEC BitLocker - Status Alert | BitLocker recovery keys |
| `fileHashMatches` | Multi-line | MON-SEC File Hash - Found Alert | Files matching the hash |
| `bruteForceLogons` | Multi-line | MON-SEC Logon - Brute Force Alert | Failed logon bursts |
| `usbDriveAlert` | Multi-line | MON-SEC USB - Drive Alert | USB drives found |
| `wanIpBlocklist` | Multi-line | MON-SEC WAN IP - Blocklist Check | Blocklist results |
| `bsodHistory` | Multi-line | MON-SYS BSOD - Alert | BSOD events |
| `patchFailureStatus` | Text | MON-WU Windows Update - Patch Failure Alert | FAILED: &lt;count and KBs&gt; or OK: no failed updates |
| `patchFailureDetail` | Multi-line | MON-WU Windows Update - Patch Failure Alert | One line per failed update: date, result, error code, title |
| `adDomainSummary` | WYSIWYG | RPT-AD Domain - Audit Report | Domain summary card |
| `adEnabledUsers` | WYSIWYG | RPT-AD Domain - Audit Report | Enabled users table |
| `adDisabledUsers` | WYSIWYG | RPT-AD Domain - Audit Report | Disabled users table |
| `adGroupMembership` | WYSIWYG | RPT-AD Domain - Audit Report | Group membership table |
| `adActiveUsers` | WYSIWYG | RPT-AD Users - Active Users Report | Active users summary and table |
| `batteryHealthReport` | WYSIWYG | RPT-HW Battery - Health Report | Battery health report |
| `hardwareid` | Multi-line | RPT-INT Autopilot - Hardware ID to Custom Field | Autopilot hardware hash |
| `entraJoinType` | Text | RPT-M365 Entra Join - Device Status | Join type, e.g. Microsoft Entra Joined |
| `entraTenantInfo` | Multi-line | RPT-M365 Entra Join - Device Status | Tenant name, tenant ID and device ID |
| `deviceDescription` | Text | RPT-MNT Device - Description | Windows device description |
| `eventLogSearchReport` | WYSIWYG | RPT-MNT Event Log - Search | Matching events |
| `registrySearchResult` | Multi-line | RPT-MNT Registry - Find Key | Matching registry keys |
| `scheduledTasksReport` | WYSIWYG | RPT-MNT Scheduled Tasks - Report | Scheduled tasks table |
| `speedTestReport` | WYSIWYG | RPT-NET Internet - Speed Test | Speed test results |
| `rdpStatus` | Text | RPT-NET RDP - Status and Port | RDP enabled/disabled and port |
| `wifiKey` | Secure | RPT-NET Wi-Fi - Current Password to Secure Field | Current Wi-Fi password |
| `wifiReport` | WYSIWYG | RPT-NET Wi-Fi - Report | Wi-Fi report |
| `outlookDataFiles` | WYSIWYG | RPT-OFF OST PST - Large Files Report | Large OST/PST files |
| `antivirusReport` | WYSIWYG | RPT-SEC Antivirus - Detect Installed | All antivirus results |
| `antivirusName` | Text | RPT-SEC Antivirus - Detect Installed | Detected antivirus names |
| `antivirusStatus` | Text | RPT-SEC Antivirus - Detect Installed | Antivirus status |
| `antivirusDefinitions` | Text | RPT-SEC Antivirus - Detect Installed | Definition date and whether out of date |
| `browserExtensions` | WYSIWYG | RPT-SEC Browser Extensions - Report | Browser extensions table |
| `credentialGuardStatus` | Text | RPT-SEC Credential Guard - Status | Credential Guard status |
| `firewallStatus` | Text | RPT-SEC Firewall - Audit Status | Firewall profile status |
| `failedLogonReport` | WYSIWYG | RPT-SEC Logon - Failed Password Attempts | Failed password attempts |
| `remoteAccessTools` | Multi-line | RPT-SEC Remote Access Tools - Report | Remote access tools found (CSV) |
| `startupItemsReport` | WYSIWYG | RPT-SEC Startup Items - Autorunsc Audit | Autoruns startup items report |
| `usbStorageAccess` | Text | RPT-SEC USB - Storage Access Status | Enabled, Disabled or Unable to Determine |
| `sqlInstances` | WYSIWYG | RPT-SRV SQL - Instances | SQL instance table |
| `performanceReport` | WYSIWYG | RPT-SYS Performance - System Check | Performance data |
| `activePowerPlan` | Text | RPT-SYS Power Plan - Report | Active power plan |
| `activePowerSettings` | Multi-line | RPT-SYS Power Plan - Report | Power settings |
| `reliabilityIndex` | Text | RPT-SYS Reliability Index - Report | Latest reliability score |
| `reliabilityReport` | WYSIWYG | RPT-SYS Reliability Index - Report | Daily reliability table |
| `LocalAdmins` | Text | RPT-USR Local Admins - Report | Local administrators |
| `localUsersReport` | WYSIWYG | RPT-USR Local Users - Report | Local users table |
| `lastLoggedInUser` | Text | RPT-USR Logged-In User - UPN to Custom Field | Signed-in user's UPN |
| `logonHistory` | WYSIWYG | RPT-USR Logon - History Report | Logon history table |
| `orphanedProfiles` | WYSIWYG | RPT-USR Profiles - Orphaned Profiles | Orphaned profiles |
| `TotalUsersProfileSize` | Text | RPT-USR Profiles - Size Report | Total profile size |
| `windowsUpdateDiagnostic` | Multi-line | RPT-WU Windows Update - Diagnostic | Diagnostic log |
