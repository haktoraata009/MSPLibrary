# Server

Windows Server, RDS/FSLogix, SQL and Intune Graph scripts.

## Before you run

- Run on the server named in each script, or from an admin workstation for the Graph and Intune scripts.
- FSLogix and UPD scripts delete or resize profiles. Make sure users are logged off and you have a backup.
- File server, share and domain names are placeholders (FILESERVER, contoso.local). Set your own.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [Application_Get_Assign](Application_Get_Assign.ps1) | Lists Intune apps and their group assignments via the Graph REST API (Microsoft Intune sample, MIT licence). | - | Admin PC |
| [AzureMfaNpsExtnConfigSetup](AzureMfaNpsExtnConfigSetup.ps1) | Microsoft setup script for the Azure MFA NPS extension: creates the certificate and registers it with the tenant. | - | Yes |
| [Collect MSSQL Instances](Collect%20MSSQL%20Instances.ps1) | Gets a list of MSSQL server instances and optionally save the results to a custom field. | `multilineCustomFieldName`, `WysiwygCustomFieldName` | No |
| [Convert-UPDtoFSLogix](Convert-UPDtoFSLogix.ps1) | Converts RDS User Profile Disks (UPD VHDX) into FSLogix profile container format and folder structure. | `userdomain` | Yes |
| [FSLogixCleanup](FSLogixCleanup.ps1) | Clears FSLogix session keys, FSLogix profile registry entries and local profile folders on a session host. | - | Yes |
| [Get Folder Permissions](Get%20Folder%20Permissions.ps1) | Exports NTFS permissions for every subfolder of a path to CSV. Set the folder path first. | - | No |
| [Get-AppAssignment](Get-AppAssignment.ps1) | Lists all Intune apps and the groups each is assigned to via Microsoft Graph. | - | Admin PC |
| [Install-ITPMBaselineCAPolicies](Install-ITPMBaselineCAPolicies.ps1) | Variant of the baseline Conditional Access policy installer with the office IP named location excluded from MFA policies (AzureAD module). | - | Admin PC |
| [Monitor SQL Server](Monitor%20SQL%20Server.ps1) | Monitors the database services, free space of the drive where the databases reside, and the disk latency of a SQL server. | `diskFreeSpaceThreshold`, `diskLatencyThreshold`, `requireAgentService`, `Username` | No |
| [Resize-UserProfileDisk](Resize-UserProfileDisk.ps1) | Expands an RDS User Profile Disk (VHDX) and its partition, with logging. | - | Yes |
| [Script-ConnectionLogging](Script-ConnectionLogging.ps1) | Logs RDS user session connections (user, client name, IP) to a CSV share for auditing. | - | No |
| [Server configuration](Server%20configuration.ps1) | Base server build: installs Telnet client, sets the High Performance power plan and adjusts DEP. | - | Yes |
| [WindowsOSBaselineConfiguration](WindowsOSBaselineConfiguration.ps1) | Base Windows build: installs Telnet client, sets the High Performance power plan and adjusts DEP. | - | Yes |
<!-- scripts:end -->
