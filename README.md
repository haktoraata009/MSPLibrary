# MSP Library

PowerShell scripts for day-to-day managed service provider work: workstation baselines, monitoring and alerting, security checks and hardening, and Microsoft 365 / Entra ID administration.

Most endpoint scripts are written for **NinjaOne** but run fine on their own. Each folder has a README that explains what every script does, which script variables it reads and whether it changes the device.

## Folders

| Folder | What's in it |
|---|---|
| [Active Directory](Active%20Directory) | On-premises AD reports and sync fixes |
| [Azure](Azure) | Microsoft 365, Entra ID, Exchange Online and OneDrive admin |
| [Conditional Access Policy Setup](Conditional%20Access%20Policy%20Setup) | Baseline Conditional Access policy installers |
| [Intune](Intune) | Intune and Autopilot helpers, Win32 app detection |
| [Maintenance & Troubleshooting](Maintenance%20%26%20Troubleshooting) | Repair and diagnostic tools for technicians |
| [Monitoring & Alerts](Monitoring%20%26%20Alerts) | Scheduled health checks that alert through custom fields |
| [Networking](Networking) | DNS, Wi-Fi, VPN, NetBIOS, RDP and connection checks |
| [Office](Office) | Microsoft 365 Apps install and repair, OST/PST checks |
| [Printers & Devices](Printers%20%26%20Devices) | Printer mapping, print queue and Bluetooth |
| [Security](Security) | BitLocker, firewall, Defender, USB, auditing and hardening |
| [Server](Server) | Windows Server, RDS/FSLogix, SQL and Intune Graph scripts |
| [Software Install & Removal](Software%20Install%20%26%20Removal) | Runtimes and bloatware or remote-tool removal |
| [Users & Accounts](Users%20%26%20Accounts) | Local users, admins, profiles and sessions |
| [Windows Configuration](Windows%20Configuration) | Workstation baseline settings |
| [Windows Update & Patching](Windows%20Update%20%26%20Patching) | Update controls and patch-failure alerting |

## Using a script in NinjaOne

1. Go to **Administration > Library > Automation**, then **Add > New Script**.
2. Paste the script. Set **Language** to PowerShell, **Operating system** to Windows, **Architecture** to All, and **Run as** to System (unless the folder README says otherwise).
3. Add a **Script Variable** for each name listed in the folder README's *Script variables* column. Use the same name: NinjaOne passes it to the script as `$env:<name>`.
4. If the script writes to a custom field, create that field first and give Automations **Read/Write** access.
5. Test on one pilot device, then schedule it or add it to a policy.

## Running a script locally

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& '.\Security\BitLocker Status Check.ps1' -Verbose
```

Run endpoint scripts from an elevated PowerShell window. Scripts marked **Admin PC** connect to a Microsoft 365 tenant and need the module named in the script.

## Safety

- Read a script before you run it. The *Changes device?* column is a guide, not a guarantee.
- Pilot every change script on one device before rolling it out.
- Tenant IDs, app IDs, secrets, domains and server names in this repo are placeholders (`<TenantID>`, `contoso.com`, `FILESERVER`). Supply your own at run time and never commit real values.

## Credits

Many scripts are adapted from the NinjaOne template library, Microsoft samples (MIT licence), o365reports.com, Vasil Michev's OneDrive scripts and community gists. Original authors and licences are kept in each script's header.

## Licence

Scripts are provided as-is, without warranty. Check each script's header for its original licence before reusing it.
