# Security

Endpoint security checks and hardening: BitLocker, firewall, Defender, USB storage, logon auditing, password policy and threat checks.

## Before you run

- Audit and report scripts are read-only and safe to schedule.
- Hardening scripts (TLS, password policy, removable storage, firewall) change security settings. Pilot them first.
- Suspend BitLocker can restart the device if you choose that option.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [Audit Brute Force Logon Attempts](Audit%20Brute%20Force%20Logon%20Attempts.ps1) | Audit and alert on brute force logon attempts. | `AlertMethod`, `FailedAttemptsLimit`, `InTheLastXHours`, `MultilineCustomFieldName`, `WYSIWYGCustomFieldName` | No |
| [BitLocker Status Check](BitLocker%20Status%20Check.ps1) | Reports the BitLocker encryption status for all fixed drives, raises alerts for unprotected or partially encrypted volumes, and optionally saves results to custom fields and assigns device tags. | `bitlockerDisabledAllDrivesTagName`, `bitlockerEnabledAllDrivesTagName`, `bitlockerKeyCustomField`, `bitlockerPartialDrivesTagName`, `bitlockerStatusMultilineCustomField`, `bitlockerStatusWysiwygCustomField` +1 more | No |
| [Credential Guard Status](Credential%20Guard%20Status.ps1) | Reports on whether Credential Guard is configured and running on a given device. | `computername`, `TextCustomFieldName` | No |
| [Defender - Enable PUA Protection](Defender%20-%20Enable%20PUA%20Protection.ps1) | Enables Potentially Unwanted Application (PUA) protection in Microsoft Defender. | - | Yes |
| [Detect Installed Antivirus](Detect%20Installed%20Antivirus.ps1) | Detect the antivirus software currently installed and set the relevant custom fields accordingly. | `antivirusNameCustomField`, `definitionDateAndStatusCustomField`, `definitionsAgeLimitInDays`, `statusCustomFieldName`, `wysiwygCustomFieldName` | No |
| [Disable Weak TLS and SSL Protocols](Disable%20Weak%20TLS%20and%20SSL%20Protocols.ps1) | Disables TLS 1.0, TLS 1.1, SSL 2.0, SSL 3.0. | `forceRestart` | Yes |
| [Enable Logon Banner and Disable Automatic Login](Enable%20Logon%20Banner%20and%20Disable%20Automatic%20Login.ps1) | Disables the automatic login feature and ensures that a dialog box is presented each time a user signs in. | `forceRestart`, `logonBannerText`, `logonBannerTitle`, `revertToMicrosoftDefaults` | Yes |
| [Enable or Disable User Logon Logoff Auditing](Enable%20or%20Disable%20User%20Logon%20Logoff%20Auditing.ps1) | Enable or disable user logon and logoff auditing. | `AuditLogoffAction`, `AuditLogonAction`, `Username`, `WinDir` | Yes |
| [Enable Require Password On Wake](Enable%20Require%20Password%20On%20Wake.ps1) | Enables password on wake from sleep/hibernation. | - | Yes |
| [Failed Password Attempt Report](Failed%20Password%20Attempt%20Report.ps1) | Returns the number of failed login attempts of all users or for a specific user. | `detailedReport`, `retrieveLogsFromComputerName`, `usernameToCheck`, `wysiwygCustomFieldName` | No |
| [Firewall - Audit Status](Firewall%20-%20Audit%20Status.ps1) | Get the current status of the specified Windows firewall profile. | `domainProfile`, `firewallStatusCustomFieldName`, `privateProfile`, `publicProfile` | No |
| [Firewall - Configure Exceptions](Firewall%20-%20Configure%20Exceptions.ps1) | Create and apply a firewall rule with your specified configuration options. | `action`, `direction`, `localIp`, `port`, `profileName`, `programPath` +3 more | Yes |
| [Firewall - Enable or Disable](Firewall%20-%20Enable%20or%20Disable.ps1) | Enable or disable all Windows Firewall profiles (Domain, Public, Private). | `defaultActionForInboundTraffic`, `enableOrDisable` | Yes |
| [Hafnian Exploit Check](Hafnian%20Exploit%20Check.ps1) | Checks Exchange Server logs for indicators of the 2021 Hafnium ProxyLogon exploits (CVE-2021-26855 and related). | - | No |
| [Hash Found Alert](Hash%20Found%20Alert.ps1) | Alerts if a file with the extension and specified hash is found in the given search directory or subdirectories. | `customFieldName`, `fileExtensionToSearchFor`, `hash`, `hashType`, `searchPath`, `timeoutInMinutes` | No |
| [Install Certificate - Windows](Install%20Certificate%20-%20Windows.ps1) | Installs a given certificate to the selected location. | `certificatePasswordCustomFieldName`, `certificateStore`, `overwriteCertificateIfExisting`, `urlOrPathToCertificate` | Yes |
| [Installed Remote Access Tools Report](Installed%20Remote%20Access%20Tools%20Report.ps1) | This script will look for remote access tools installed on the system. | `exportCsvResultsToThisCustomField`, `exportJsonResultsToThisCustomField`, `includeToolsThatWereNotFound`, `retrieveIgnoreListFromCustomField`, `toolsToIgnore` | No |
| [List Browser Extensions](List%20Browser%20Extensions.ps1) | Reports on all installed browser extensions for Chrome, Firefox and Edge. | `MultilineCustomFieldName`, `WYSIWYGCustomFieldName` | No |
| [Set Inactivity Timeout](Set%20Inactivity%20Timeout.ps1) | Configures the inactivity timeout to a specified duration or removes it if desired. | `force`, `minutes`, `remove` | Yes |
| [Set Password Policy](Set%20Password%20Policy.ps1) | Make changes to the default domain password policy (if run on a Domain Controller) or the local password security policy (if run on a non-domain joined machine). | `initiateGpupdateIfNecessary`, `lockoutDurationInMinutes`, `maximumLoginAttempts`, `maximumPasswordAge`, `minimumPasswordAge`, `minimumPasswordLength` +4 more | Yes |
| [Set Removable Storage Access](Set%20Removable%20Storage%20Access.ps1) | Disable or Enable Write, Read, and Execute access to Removable Storage devices. | `AllowRead`, `AllowReadAndExecute`, `AllowWrite`, `DenyExecute`, `DenyRead`, `DenyWrite` +3 more | Yes |
| [Start Microsoft MSERT Scan](Start%20Microsoft%20MSERT%20Scan.ps1) | Run the Microsoft Safety Scanner, collect the results, and optionally save the results to a multiline custom field. | `customFieldName`, `scanTimeoutInMinutes`, `scanType` | Yes |
| [Startup Audit Using Autorunsc](Startup%20Audit%20Using%20Autorunsc.ps1) | Runs Autorunsc with your selected options and outputs the results to the activity log and optionally a WYSIWYG custom field. | `checkAppinitEntries`, `checkAutostartServices`, `checkBootEntries`, `checkCodecs`, `checkExplorerAddons`, `checkImageHijacks` +17 more | Yes |
| [Suspend BitLocker](Suspend%20BitLocker.ps1) | Suspends BitLocker Protection until after the next restart. | `restart`, `restartRegardlessOfBitlockerStatus` | Yes |
| [Unencrypted Disk Alert](Unencrypted%20Disk%20Alert.ps1) | Returns the number of drives in the Unlocked and FullyDecrypted state. | - | No |
| [USB Drive Alert](USB%20Drive%20Alert.ps1) | Alerts when a USB drive is detected and optionally saves the results to a Custom Field. | `customFieldName` | No |
| [USB Storage Status](USB%20Storage%20Status.ps1) | Checks if the workstation currently allows access to USB storage devices and optionally saves the results to a custom field. | `customFieldName` | No |
| [WAN IP Blocklist Check](WAN%20IP%20Blocklist%20Check.ps1) | Checks several common blacklists to see if the device's WAN IP is currently being blacklisted. | `multilineCustomFieldName` | No |
<!-- scripts:end -->
