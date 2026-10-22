# Networking

Network configuration and reporting: DNS, Wi-Fi, VPN, NetBIOS, RDP and connection checks.

## Before you run

- Changes to DNS, VPN or RDP can drop the remote session. Test on a pilot device you can reach another way.
- RPT-NET Wi-Fi - Current Password to Secure Field stores the key in a secure custom field only. Do not print it to the activity log.
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
| [CFG-NET DNS - Set Server Address](CFG-NET%20DNS%20-%20Set%20Server%20Address.ps1) | Sets the DNS servers on the active network adapter. | Config change | System | No | ⚠️ Wrong DNS can break internet and domain access. | `ListNetworkAdapters`, `NetworkAdapter`, `PrimaryDNSIP`, `Region`, `ResetToAutomatic`, `SecondaryDNSIP` +1 more |
| [CFG-NET NetBIOS - Enable or Disable](CFG-NET%20NetBIOS%20-%20Enable%20or%20Disable.ps1) | Turns NetBIOS on or off on all network adapters. | Config change | System | No | ⚠️ Disabling can break old file shares and name lookups. | `action` |
| [CFG-NET RDP - Enable or Disable](CFG-NET%20RDP%20-%20Enable%20or%20Disable.ps1) | Turns Remote Desktop on or off on workstations. | Config change | System | No | ⚠️ Can cut off remote access. Have another way in. | `action` |
| [CFG-NET VPN - Create Windows VPN](CFG-NET%20VPN%20-%20Create%20Windows%20VPN.ps1) | Creates a VPN connection in the built-in Windows VPN client. | Config change | System | Needed to apply | ⚠️ UDP encapsulation setting needs a restart. | `assumeUdpEncapsulation`, `authenticationMethod`, `createVpnDesktopShortcut`, `dnsSuffix`, `encryptionLevel`, `iconDirectory` +14 more |
| [CFG-NET Wi-Fi - Deploy Profile](CFG-NET%20Wi-Fi%20-%20Deploy%20Profile.ps1) | Adds a Wi-Fi network profile for all users. | Config change | System | No | ⚠️ Wrong settings can disconnect the device from Wi-Fi. | `authenticationType`, `nameOfASecureCustomFieldContainingPresharedKey`, `overwrite`, `ssid` |
| [FIX-NET DNS - Clear Cache](FIX-NET%20DNS%20-%20Clear%20Cache.ps1) | Clears the DNS cache. | Repair / Fix | System | No | - | `numberOfTimesToClearCache` |
| [FIX-NET Network Location - Detection Fix](FIX-NET%20Network%20Location%20-%20Detection%20Fix.ps1) | Fixes domain networks showing as Public after boot on servers and DCs. | Repair / Fix | System | Needed to apply | - | - |
| [MON-NET Connections - Search for IP Address](MON-NET%20Connections%20-%20Search%20for%20IP%20Address.ps1) | Alerts when the device is connected to or listening for a given IP address. | Monitor / Alert | System | No | - | `customFieldName`, `ipAddress` |
| [MON-NET Network Profile - Check](MON-NET%20Network%20Profile%20-%20Check.ps1) | Alerts when a network connection is set to Public instead of Private or Domain. | Monitor / Alert | System | No | - | `networkProfileCustomFieldName` |
| [RPT-NET Internet - Speed Test](RPT-NET%20Internet%20-%20Speed%20Test.ps1) | Runs an internet speed test. | Report (read-only) | System | No | ⚠️ Uses bandwidth. Avoid running on many devices at once. | `appendToCustomField`, `multilineCustomFieldName`, `sleepBeforeRunning`, `wysiwygCustomFieldName` |
| [RPT-NET RDP - Status and Port](RPT-NET%20RDP%20-%20Status%20and%20Port.ps1) | Shows whether Remote Desktop is on and which port it uses. | Report (read-only) | System | No | - | `rdpStatusCustomFieldName` |
| [RPT-NET Wi-Fi - Current Password to Secure Field](RPT-NET%20Wi-Fi%20-%20Current%20Password%20to%20Secure%20Field.ps1) | Reads the password of the connected Wi-Fi and stores it in a secure custom field. | Report (read-only) | System | No | ⚠️ Handles a secret. Use a secure field only. | `EnableLocationServicesTemporarily`, `SecureCustomFieldToStorePassword` |
| [RPT-NET Wi-Fi - Report](RPT-NET%20Wi-Fi%20-%20Report.ps1) | Reports Wi-Fi networks, signal and connection history. | Report (read-only) | System | No | ⚠️ Briefly turns on Location Services to read Wi-Fi details. | `enableLocationServicesTemporarily`, `wysiwygCustomFieldName` |
<!-- scripts:end -->
