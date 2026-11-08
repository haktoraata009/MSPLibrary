# NinjaOne custom fields

Scripts that write results to NinjaOne custom fields now have a built-in field name. Create the field with the exact **Name** below (case sensitive), the type shown, and **Automations** access set to **Read/Write**. Leave the field-name script variable blank to use the built-in name, or enter another field's exact Name to override it.

## If a field stays empty

- The field **Name** (not the Label) matches exactly, same case. `patchFailureStatus` is not `PatchFailureStatus`.
- In NinjaOne you type a Label and Ninja builds the Name in camelCase: Label `Patch Failure Status` gives Name `patchFailureStatus`.
- The field type matches (Text, Multi-line, WYSIWYG, Secure). Text is one short line; Multi-line holds up to 10,000 characters.
- Automations access is Read/Write.
- Role custom fields must be added to the device role. Global custom fields work on every device.
- The field-name script variable is blank, or holds the exact field Name.

## Fields by script

| Custom field Name | Type | Script | Override variable | What it holds |
|---|---|---|---|---|
| `printQueueResult` | Multi-line | FIX-HW Printer - Clear Print Queue | Custom Field Name (`$env:CustomFieldName`) | Print queue clear result |
| `dismRepairResult` | Multi-line | FIX-MNT DISM - Image Repair | Multiline Custom Field Name (`$env:multilineCustomFieldName`) | DISM output |
| `diskOptimizeReport` | WYSIWYG | FIX-MNT Disk - Optimize and Defrag | Wysiwyg Custom Field Name (`$env:wysiwygCustomFieldName`) | Fragmentation chart and result |
| `msertScanResult` | Multi-line | FIX-SEC MSERT - Run Scan | Custom Field Name (`$env:customFieldName`) | MSERT scan result |
| `adPasswordExpiry` | Multi-line | MON-AD Password - Expiration Alert | Custom Field Name (`$env:customFieldName`) | Users whose passwords are about to expire |
| `diskSpaceStatus` | Multi-line | MON-HW Disk - Space Alert | Multiline Custom Field Name (`$env:multilineCustomFieldName`) | Volume free space report |
| `wmiHealthStatus` | Multi-line | MON-MNT WMI - Health Check | Multiline Custom Field Name (`$env:MultilineCustomFieldName`) | WMI health result |
| `ipConnectionMatches` | Multi-line | MON-NET Connections - Search for IP Address | Custom Field Name (`$env:customFieldName`) | Matching connections |
| `networkProfile` | Multi-line | MON-NET Network Profile - Check | Network Profile Custom Field Name (`$env:networkProfileCustomFieldName`) | Network profile per adapter |
| `wanIpHistory` | Multi-line | MON-NET WAN IP - Change Alert | WANIP History Custom Field Name (`$env:WANIPHistoryCustomFieldName`) | WAN IP history |
| `bitlockerStatus` | Multi-line | MON-SEC BitLocker - Status Alert | Bitlocker Status Multiline Custom Field (`$env:bitlockerStatusMultilineCustomField`) | BitLocker status per volume |
| `bitlockerRecoveryKey` | Secure | MON-SEC BitLocker - Status Alert | Bitlocker Key Custom Field (`$env:bitlockerKeyCustomField`) | BitLocker recovery keys |
| `fileHashMatches` | Multi-line | MON-SEC File Hash - Found Alert | Custom Field Name (`$env:customFieldName`) | Files matching the hash |
| `bruteForceLogons` | Multi-line | MON-SEC Logon - Brute Force Alert | Multiline Custom Field Name (`$env:MultilineCustomFieldName`) | Failed logon bursts |
| `usbDriveAlert` | Multi-line | MON-SEC USB - Drive Alert | Custom Field Name (`$env:customFieldName`) | USB drives found |
| `wanIpBlocklist` | Multi-line | MON-SEC WAN IP - Blocklist Check | Multiline Custom Field Name (`$env:multilineCustomFieldName`) | Blocklist results |
| `bsodHistory` | Multi-line | MON-SYS BSOD - Alert | Multiline Custom Field Name (`$env:multilineCustomFieldName`) | BSOD events |
| `patchFailureStatus` | Text | MON-WU Windows Update - Patch Failure Alert | Status Custom Field Name (`$env:statusCustomFieldName`) | One-line status, [OK] or [Alert] |
| `patchFailureDetail` | Multi-line | MON-WU Windows Update - Patch Failure Alert | Multiline Custom Field Name (`$env:multilineCustomFieldName`) | Failed updates and reboot detail |
| `adDomainSummary` | WYSIWYG | RPT-AD Domain - Audit Report | Domain Summary Wysiwyg Custom Field Name (`$env:domainSummaryWysiwygCustomFieldName`) | Domain summary card |
| `adEnabledUsers` | WYSIWYG | RPT-AD Domain - Audit Report | Enabled Users Wysiwyg Custom Field Name (`$env:enabledUsersWysiwygCustomFieldName`) | Enabled users table |
| `adDisabledUsers` | WYSIWYG | RPT-AD Domain - Audit Report | Disabled Users Wysiwyg Custom Field Name (`$env:disabledUsersWysiwygCustomFieldName`) | Disabled users table |
| `adGroupMembership` | WYSIWYG | RPT-AD Domain - Audit Report | Group Membership Wysiwyg Custom Field Name (`$env:groupMembershipWysiwygCustomFieldName`) | Group membership table |
| `adActiveUsers` | WYSIWYG | RPT-AD Users - Active Users Report | Wysiwyg Custom Field Name (`$env:wysiwygCustomFieldName`) | Active users summary and table |
| `batteryHealthReport` | WYSIWYG | RPT-HW Battery - Health Report | Wysiwyg Custom Field Name (`$env:wysiwygCustomFieldName`) | Battery health report |
| `hardwareid` | Multi-line | RPT-INT Autopilot - Hardware ID to Custom Field | Custom Field Name (`$env:customFieldName`) | Autopilot hardware hash (already the script default) |
| `entraJoinType` | Text | RPT-M365 Entra Join - Device Status | Join Type Custom Field Name (`$env:joinTypeCustomFieldName`) | Join type, e.g. Microsoft Entra Joined |
| `entraTenantInfo` | Multi-line | RPT-M365 Entra Join - Device Status | Tenant Info Custom Field Name (`$env:tenantInfoCustomFieldName`) | Tenant name, tenant ID and device ID |
| `deviceDescription` | Text | RPT-MNT Device - Description | Name Of Custom Field (`$env:nameOfCustomField`) | Windows device description |
| `eventLogSearchReport` | WYSIWYG | RPT-MNT Event Log - Search | Wysiwyg Custom Field Name (`$env:wysiwygCustomFieldName`) | Matching events |
| `registrySearchResult` | Multi-line | RPT-MNT Registry - Find Key | Custom Field Name (`$env:customFieldName`) | Matching registry keys |
| `scheduledTasksReport` | WYSIWYG | RPT-MNT Scheduled Tasks - Report | WYSIWYG Custom Field Name (`$env:WYSIWYGCustomFieldName`) | Scheduled tasks table |
| `speedTestReport` | WYSIWYG | RPT-NET Internet - Speed Test | Wysiwyg Custom Field Name (`$env:wysiwygCustomFieldName`) | Speed test results |
| `rdpStatus` | Text | RPT-NET RDP - Status and Port | Rdp Status Custom Field Name (`$env:rdpStatusCustomFieldName`) | RDP enabled/disabled and port |
| `wifiKey` | Secure | RPT-NET Wi-Fi - Current Password to Secure Field | Secure Custom Field To Store Password (`$env:SecureCustomFieldToStorePassword`) | Current Wi-Fi password |
| `wifiReport` | WYSIWYG | RPT-NET Wi-Fi - Report | Wysiwyg Custom Field Name (`$env:wysiwygCustomFieldName`) | Wi-Fi report |
| `outlookDataFiles` | WYSIWYG | RPT-OFF OST PST - Large Files Report | Wysiwyg Custom Field Name (`$env:wysiwygCustomFieldName`) | Large OST/PST files |
| `antivirusReport` | WYSIWYG | RPT-SEC Antivirus - Detect Installed | Wysiwyg Custom Field Name (`$env:wysiwygCustomFieldName`) | All antivirus results |
| `antivirusName` | Text | RPT-SEC Antivirus - Detect Installed | Antivirus Name Custom Field (`$env:antivirusNameCustomField`) | Detected antivirus names |
| `antivirusStatus` | Text | RPT-SEC Antivirus - Detect Installed | Status Custom Field Name (`$env:statusCustomFieldName`) | Antivirus status |
| `antivirusDefinitions` | Text | RPT-SEC Antivirus - Detect Installed | Definition Date And Status Custom Field (`$env:definitionDateAndStatusCustomField`) | Definition date and whether out of date |
| `browserExtensions` | WYSIWYG | RPT-SEC Browser Extensions - Report | WYSIWYG Custom Field Name (`$env:WYSIWYGCustomFieldName`) | Browser extensions table |
| `credentialGuardStatus` | Text | RPT-SEC Credential Guard - Status | Text Custom Field Name (`$env:TextCustomFieldName`) | Credential Guard status |
| `firewallStatus` | Text | RPT-SEC Firewall - Audit Status | Firewall Status Custom Field Name (`$env:firewallStatusCustomFieldName`) | Firewall profile status |
| `failedLogonReport` | WYSIWYG | RPT-SEC Logon - Failed Password Attempts | Wysiwyg Custom Field Name (`$env:wysiwygCustomFieldName`) | Failed password attempts |
| `remoteAccessTools` | Multi-line | RPT-SEC Remote Access Tools - Report | Export Csv Results To This Custom Field (`$env:exportCsvResultsToThisCustomField`) | Remote access tools found (CSV) |
| `startupItemsReport` | WYSIWYG | RPT-SEC Startup Items - Autorunsc Audit | Custom Field Name (`$env:customFieldName`) | Autoruns startup items report |
| `usbStorageAccess` | Text | RPT-SEC USB - Storage Access Status | Custom Field Name (`$env:customFieldName`) | Enabled, Disabled or Unable to Determine |
| `sqlInstances` | WYSIWYG | RPT-SRV SQL - Instances | Wysiwyg Custom Field Name (`$env:WysiwygCustomFieldName`) | SQL instance table |
| `performanceReport` | WYSIWYG | RPT-SYS Performance - System Check | Wysiwyg Custom Field Name (`$env:wysiwygCustomFieldName`) | Performance data |
| `activePowerPlan` | Text | RPT-SYS Power Plan - Report | Power Plan Custom Field Name (`$env:powerPlanCustomFieldName`) | Active power plan (already the script default) |
| `activePowerSettings` | Multi-line | RPT-SYS Power Plan - Report | Power Settings Custom Field Name (`$env:powerSettingsCustomFieldName`) | Power settings (already the script default) |
| `reliabilityIndex` | Text | RPT-SYS Reliability Index - Report | Text Custom Field Name (`$env:TextCustomFieldName`) | Latest reliability score |
| `reliabilityReport` | WYSIWYG | RPT-SYS Reliability Index - Report | WYSIWYG Custom Field Name (`$env:WYSIWYGCustomFieldName`) | Daily reliability table |
| `LocalAdmins` | Text | RPT-USR Local Admins - Report | Custom Field Name (`$env:customFieldName`) | Local administrators (already the script default, capital L) |
| `localUsersReport` | WYSIWYG | RPT-USR Local Users - Report | Wysiwyg Custom Field Name (`$env:wysiwygCustomFieldName`) | Local users table |
| `lastLoggedInUser` | Text | RPT-USR Logged-In User - UPN to Custom Field | Custom Field Name (`$env:customFieldName`) | Signed-in user's UPN (already the script default) |
| `logonHistory` | WYSIWYG | RPT-USR Logon - History Report | Wysiwyg Custom Field Name (`$env:wysiwygCustomFieldName`) | Logon history table |
| `orphanedProfiles` | WYSIWYG | RPT-USR Profiles - Orphaned Profiles | Wysiwyg Custom Field Name (`$env:wysiwygCustomFieldName`) | Orphaned profiles |
| `TotalUsersProfileSize` | Text | RPT-USR Profiles - Size Report | Custom Field Name (`$env:customFieldName`) | Total profile size (already the script default, capital T) |
| `windowsUpdateDiagnostic` | Multi-line | RPT-WU Windows Update - Diagnostic | Resultscustomfield (`$env:resultscustomfield`) | Diagnostic log |

Fields marked Secure hold secrets. Restrict who can view them in NinjaOne.
