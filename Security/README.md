# Security

Endpoint security checks and hardening: BitLocker, firewall, Defender, USB storage, logon auditing, password policy and threat checks.

## Before you run

- MON- and RPT- scripts are read-only and safe to schedule.
- CFG- scripts change security settings. Pilot them first.
- CFG-SEC TLS - Disable Weak Protocols restarts the device.
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
| [CFG-SEC BitLocker - Suspend](CFG-SEC%20BitLocker%20-%20Suspend.ps1) | Pauses BitLocker until the next restart, for BIOS or firmware updates. | Config change | System | Optional | ⚠️ The drive is unprotected until the device restarts. | `restart`, `restartRegardlessOfBitlockerStatus` |
| [CFG-SEC Certificate - Install](CFG-SEC%20Certificate%20-%20Install.ps1) | Installs a certificate into the chosen certificate store. | Config change | System | No | ⚠️ Changes what the device trusts. Check the certificate source. | `certificatePasswordCustomFieldName`, `certificateStore`, `overwriteCertificateIfExisting`, `urlOrPathToCertificate` |
| [CFG-SEC Defender - Enable PUA Protection](CFG-SEC%20Defender%20-%20Enable%20PUA%20Protection.ps1) | Turns on Defender blocking of potentially unwanted apps. | Config change | System | No | ⚠️ May block some free tools and bundled installers. | - |
| [CFG-SEC Firewall - Configure Exception](CFG-SEC%20Firewall%20-%20Configure%20Exception.ps1) | Creates a Windows Firewall rule with your settings. | Config change | System | No | ⚠️ Opens ports. Keep rules as narrow as possible. | `action`, `direction`, `localIp`, `port`, `profileName`, `programPath` +3 more |
| [CFG-SEC Firewall - Enable or Disable](CFG-SEC%20Firewall%20-%20Enable%20or%20Disable.ps1) | Turns all Windows Firewall profiles on or off. | Config change | System | No | ⚠️ Disabling exposes the device. Enabling may block remote tools. | `defaultActionForInboundTraffic`, `enableOrDisable` |
| [CFG-SEC Inactivity Timeout - Set](CFG-SEC%20Inactivity%20Timeout%20-%20Set.ps1) | Locks the device after a set time without activity. | Config change | System | Needed to apply | ⚠️ Users are locked out sooner. | `force`, `minutes`, `remove` |
| [CFG-SEC Logon - Banner and Disable Auto Login](CFG-SEC%20Logon%20-%20Banner%20and%20Disable%20Auto%20Login.ps1) | Shows a logon notice and turns off automatic sign-in. | Config change | System | Optional | ⚠️ Breaks kiosks or devices that rely on auto sign-in. | `forceRestart`, `logonBannerText`, `logonBannerTitle`, `revertToMicrosoftDefaults` |
| [CFG-SEC Logon Auditing - Enable or Disable](CFG-SEC%20Logon%20Auditing%20-%20Enable%20or%20Disable.ps1) | Turns logon and logoff auditing on or off. | Config change | System | No | ⚠️ More events in the Security log. | `AuditLogoffAction`, `AuditLogonAction`, `Username`, `WinDir` |
| [CFG-SEC Password on Wake - Enable](CFG-SEC%20Password%20on%20Wake%20-%20Enable.ps1) | Requires a password when the device wakes from sleep. | Config change | System | No | - | - |
| [CFG-SEC Password Policy - Set](CFG-SEC%20Password%20Policy%20-%20Set.ps1) | Sets password rules: length, age, complexity and lockout. | Config change | System | No | ⚠️ On a DC this changes the whole domain policy. | `initiateGpupdateIfNecessary`, `lockoutDurationInMinutes`, `maximumLoginAttempts`, `maximumPasswordAge`, `minimumPasswordAge`, `minimumPasswordLength` +4 more |
| [CFG-SEC Removable Storage - Set Access](CFG-SEC%20Removable%20Storage%20-%20Set%20Access.ps1) | Allows or blocks read, write and run access to USB drives. | Config change | System | Optional | ⚠️ Blocks USB drives users may depend on. | `AllowRead`, `AllowReadAndExecute`, `AllowWrite`, `DenyExecute`, `DenyRead`, `DenyWrite` +3 more |
| [CFG-SEC TLS - Disable Weak Protocols](CFG-SEC%20TLS%20-%20Disable%20Weak%20Protocols.ps1) | Turns off SSL 2.0, SSL 3.0, TLS 1.0 and TLS 1.1, and makes sure TLS 1.2 is on. | Config change | System | Restarts device | ⚠️ Restarts the device. Old apps that need TLS 1.0 may stop working. | `forceRestart` |
| [FIX-SEC MSERT - Run Scan](FIX-SEC%20MSERT%20-%20Run%20Scan.ps1) | Downloads and runs the Microsoft Safety Scanner and reports what it found. | Repair / Fix | System | No | ⚠️ Long scan with high CPU. Can remove infected files. | `customFieldName`, `scanTimeoutInMinutes`, `scanType` |
| [MON-SEC BitLocker - Status Alert](MON-SEC%20BitLocker%20-%20Status%20Alert.ps1) | Alerts when a fixed drive is not fully protected by BitLocker. | Monitor / Alert | System | No | - | `bitlockerDisabledAllDrivesTagName`, `bitlockerEnabledAllDrivesTagName`, `bitlockerKeyCustomField`, `bitlockerPartialDrivesTagName`, `bitlockerStatusMultilineCustomField`, `bitlockerStatusWysiwygCustomField` +1 more |
| [MON-SEC BitLocker - Unencrypted Disk Alert](MON-SEC%20BitLocker%20-%20Unencrypted%20Disk%20Alert.ps1) | Counts drives that are not encrypted and alerts. | Monitor / Alert | System | No | - | - |
| [MON-SEC File Hash - Found Alert](MON-SEC%20File%20Hash%20-%20Found%20Alert.ps1) | Alerts when a file with a given hash is found. | Monitor / Alert | System | No | ⚠️ Large searches use disk and CPU. | `customFieldName`, `fileExtensionToSearchFor`, `hash`, `hashType`, `searchPath`, `timeoutInMinutes` |
| [MON-SEC Logon - Brute Force Alert](MON-SEC%20Logon%20-%20Brute%20Force%20Alert.ps1) | Alerts on many failed logons in a short time. | Monitor / Alert | System | No | - | `AlertMethod`, `FailedAttemptsLimit`, `InTheLastXHours`, `MultilineCustomFieldName`, `WYSIWYGCustomFieldName` |
| [MON-SEC USB - Drive Alert](MON-SEC%20USB%20-%20Drive%20Alert.ps1) | Alerts when a USB drive is plugged in. | Monitor / Alert | System | No | - | `customFieldName` |
| [MON-SEC WAN IP - Blocklist Check](MON-SEC%20WAN%20IP%20-%20Blocklist%20Check.ps1) | Alerts when the site's public IP is on a spam or threat blocklist. | Monitor / Alert | System | No | - | `multilineCustomFieldName` |
| [RPT-SEC Antivirus - Detect Installed](RPT-SEC%20Antivirus%20-%20Detect%20Installed.ps1) | Detects which antivirus is installed and its status. | Report (read-only) | System | No | - | `antivirusNameCustomField`, `definitionDateAndStatusCustomField`, `definitionsAgeLimitInDays`, `statusCustomFieldName`, `wysiwygCustomFieldName` |
| [RPT-SEC Browser Extensions - Report](RPT-SEC%20Browser%20Extensions%20-%20Report.ps1) | Lists Chrome, Edge and Firefox extensions for every user. | Report (read-only) | System | No | - | `MultilineCustomFieldName`, `WYSIWYGCustomFieldName` |
| [RPT-SEC Credential Guard - Status](RPT-SEC%20Credential%20Guard%20-%20Status.ps1) | Reports whether Credential Guard is set up and running. | Report (read-only) | System | No | - | `computername`, `TextCustomFieldName` |
| [RPT-SEC Exchange - Hafnium Exploit Check](RPT-SEC%20Exchange%20-%20Hafnium%20Exploit%20Check.ps1) | Checks Exchange Server logs for signs of the 2021 Hafnium attack. | Report (read-only) | Server | No | - | - |
| [RPT-SEC Firewall - Audit Status](RPT-SEC%20Firewall%20-%20Audit%20Status.ps1) | Shows whether each Windows Firewall profile is on. | Report (read-only) | System | No | - | `domainProfile`, `firewallStatusCustomFieldName`, `privateProfile`, `publicProfile` |
| [RPT-SEC Logon - Failed Password Attempts](RPT-SEC%20Logon%20-%20Failed%20Password%20Attempts.ps1) | Counts failed sign-in attempts per user. | Report (read-only) | System | No | - | `detailedReport`, `retrieveLogsFromComputerName`, `usernameToCheck`, `wysiwygCustomFieldName` |
| [RPT-SEC Remote Access Tools - Report](RPT-SEC%20Remote%20Access%20Tools%20-%20Report.ps1) | Lists remote access tools installed on the device, such as TeamViewer or AnyDesk. | Report (read-only) | System | No | - | `exportCsvResultsToThisCustomField`, `exportJsonResultsToThisCustomField`, `includeToolsThatWereNotFound`, `retrieveIgnoreListFromCustomField`, `toolsToIgnore` |
| [RPT-SEC Startup Items - Autorunsc Audit](RPT-SEC%20Startup%20Items%20-%20Autorunsc%20Audit.ps1) | Lists everything that starts with Windows using Sysinternals Autorunsc. | Report (read-only) | System | No | ⚠️ Downloads Autorunsc from Microsoft. | `checkAppinitEntries`, `checkAutostartServices`, `checkBootEntries`, `checkCodecs`, `checkExplorerAddons`, `checkImageHijacks` +17 more |
| [RPT-SEC USB - Storage Access Status](RPT-SEC%20USB%20-%20Storage%20Access%20Status.ps1) | Reports whether USB storage is allowed on the device. | Report (read-only) | System | No | - | `customFieldName` |
<!-- scripts:end -->
