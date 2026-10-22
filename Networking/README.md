# Networking

Network configuration and reporting: DNS, Wi-Fi, VPN, NetBIOS, RDP and connection checks.

## Before you run

- Changes to DNS, VPN or RDP can drop the remote session. Test on a pilot device you can reach another way.
- Get Current Wi-Fi Password stores the key in a secure custom field only. Do not print it to the activity log.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [Clear DNS Cache](Clear%20DNS%20Cache.ps1) | Clear's the DNS Cache the number of times you specify (defaults to 3). | `numberOfTimesToClearCache` | Yes |
| [Create Windows VPN](Create%20Windows%20VPN.ps1) | Creates a VPN using the built-in Windows VPN client, with configuration options from Ninja Documentation or Device Custom Fields. | `assumeUdpEncapsulation`, `authenticationMethod`, `createVpnDesktopShortcut`, `dnsSuffix`, `encryptionLevel`, `iconDirectory` +14 more | Yes |
| [Deploy Wi-Fi Profile](Deploy%20Wi-Fi%20Profile.ps1) | Deploy a wifi profile to all users on a given device. | `authenticationType`, `nameOfASecureCustomFieldContainingPresharedKey`, `overwrite`, `ssid` | Yes |
| [Enable or Disable NetBios](Enable%20or%20Disable%20NetBios.ps1) | Disables or Enables NETBIOS on all network adapters | `action` | Yes |
| [Enable or Disable Remote Desktop (RDP)](Enable%20or%20Disable%20Remote%20Desktop%20%28RDP%29.ps1) | Enables or Disables RDP for workstations only. | `action` | Yes |
| [Get Current Wi-Fi Password](Get%20Current%20Wi-Fi%20Password.ps1) | Retrieve the password of the currently connected Wi-Fi network and store it in a secure custom field. | `EnableLocationServicesTemporarily`, `SecureCustomFieldToStorePassword` | Yes |
| [Internet Speed Test](Internet%20Speed%20Test.ps1) | Runs an internet speed test. | `appendToCustomField`, `multilineCustomFieldName`, `sleepBeforeRunning`, `wysiwygCustomFieldName` | No |
| [Network Connection Profile Check](Network%20Connection%20Profile%20Check.ps1) | Checks the current network connections to see what profile they are currently using and optionally save the results to a custom field. | `networkProfileCustomFieldName` | No |
| [Network Location Detection Fix](Network%20Location%20Detection%20Fix.ps1) | Sets the NLA registry value that makes domain networks detect correctly after boot (fixes 'Public network' on DCs and servers). | - | Yes |
| [Remote Desktop - Check Status and Port](Remote%20Desktop%20-%20Check%20Status%20and%20Port.ps1) | Reports the status of Remote Desktop and the port it is listening on. | `rdpStatusCustomFieldName` | No |
| [Search TCP UDP Connections for Specified IP Address](Search%20TCP%20UDP%20Connections%20for%20Specified%20IP%20Address.ps1) | Alert on specified addresses that are Listening or Established and optionally save the results to a custom field. | `customFieldName`, `ipAddress` | No |
| [Set or Modify DNS Server Address](Set%20or%20Modify%20DNS%20Server%20Address.ps1) | Set or modify the IPv4 DNS servers of a specified active network adapter. | `ListNetworkAdapters`, `NetworkAdapter`, `PrimaryDNSIP`, `Region`, `ResetToAutomatic`, `SecondaryDNSIP` +1 more | Yes |
| [Wi-Fi Report](Wi-Fi%20Report.ps1) | Generates a Wireless LAN report and optionally saves it to a WYSIWYG Custom Field. | `enableLocationServicesTemporarily`, `wysiwygCustomFieldName` | Yes |
<!-- scripts:end -->
