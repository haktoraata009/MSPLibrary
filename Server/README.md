# Server

Windows Server, RDS/FSLogix and SQL scripts.

## Before you run

- Run on the server named in each script.
- FSLogix and UPD scripts delete or resize profiles. Make sure users are logged off and you have a backup.
- File server, share and domain names are placeholders (FILESERVER, contoso.local). Set your own.
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
| [CFG-SRV NPS - Azure MFA Extension Setup](CFG-SRV%20NPS%20-%20Azure%20MFA%20Extension%20Setup.ps1) | Microsoft setup for the Azure MFA extension on an NPS (RADIUS) server. | Config change | NPS server | No | ⚠️ Affects VPN and Wi-Fi sign-ins through NPS. Plan a change window. | - |
| [CFG-SRV Server - Baseline Configuration (v2)](CFG-SRV%20Server%20-%20Baseline%20Configuration%20%28v2%29.ps1) | Near-identical copy of the base server build script. | Config change | Server | Needed to apply | ⚠️ DEP change needs a restart. | - |
| [CFG-SRV Server - Baseline Configuration](CFG-SRV%20Server%20-%20Baseline%20Configuration.ps1) | Base server build: Telnet client, High Performance power plan and DEP setting. | Config change | Server | Needed to apply | ⚠️ DEP change needs a restart. | - |
| [FIX-SRV FSLogix - Convert UPD to FSLogix](FIX-SRV%20FSLogix%20-%20Convert%20UPD%20to%20FSLogix.ps1) | Converts RDS User Profile Disks to FSLogix profile containers. | Repair / Fix | Server | No | ⚠️ Back up profiles first. Users must be logged off. | `userdomain` |
| [FIX-SRV FSLogix - Profile Cleanup](FIX-SRV%20FSLogix%20-%20Profile%20Cleanup.ps1) | Clears FSLogix sessions and local profile copies on a session host. | Repair / Fix | Server | No | ⚠️ Deletes local profiles. Users must be logged off. | - |
| [FIX-SRV UPD - Resize Profile Disk](FIX-SRV%20UPD%20-%20Resize%20Profile%20Disk.ps1) | Makes an RDS User Profile Disk bigger. | Repair / Fix | Server | No | ⚠️ Back up the disk first. The user must be logged off. | - |
| [MON-SRV SQL - Health Monitor](MON-SRV%20SQL%20-%20Health%20Monitor.ps1) | Alerts on SQL services, database drive space and disk latency. | Monitor / Alert | Server | No | - | `diskFreeSpaceThreshold`, `diskLatencyThreshold`, `requireAgentService`, `Username` |
| [RPT-SRV NTFS - Folder Permissions Report](RPT-SRV%20NTFS%20-%20Folder%20Permissions%20Report.ps1) | Exports folder permissions under a path to CSV. | Report (read-only) | Server | No | ⚠️ Set the folder path first. | - |
| [RPT-SRV RDS - Connection Logging](RPT-SRV%20RDS%20-%20Connection%20Logging.ps1) | Logs RDS user connections (user, client name, IP) to a share. | Report (read-only) | Server | No | - | - |
| [RPT-SRV SQL - Instances](RPT-SRV%20SQL%20-%20Instances.ps1) | Lists SQL Server instances on the server. | Report (read-only) | Server | No | - | `multilineCustomFieldName`, `WysiwygCustomFieldName` |
<!-- scripts:end -->
