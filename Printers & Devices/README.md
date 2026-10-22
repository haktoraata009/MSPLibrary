# Printers & Devices

Printer mapping and queue fixes, Bluetooth unpairing.

## Before you run

- CFG-HW Printer - Add Network Printer installs per machine, so every user profile gets the printer.
- Clearing the print queue deletes pending jobs.
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
| [CFG-HW Bluetooth - Unpair Devices](CFG-HW%20Bluetooth%20-%20Unpair%20Devices.ps1) | Unpairs Bluetooth devices (connected ones by default). | Config change | System | No | ⚠️ Users must pair devices again. | `UnpairAllDevices` |
| [CFG-HW Printer - Add Network Printer](CFG-HW%20Printer%20-%20Add%20Network%20Printer.ps1) | Adds or removes a shared network printer for every user on the device. | Config change | System | No | ⚠️ Restarts the print spooler. | `ComputerName`, `forceRestart`, `printerSharePath`, `removePrinter` |
| [FIX-HW Printer - Clear Print Queue](FIX-HW%20Printer%20-%20Clear%20Print%20Queue.ps1) | Clears stuck print jobs and lists printers. | Repair / Fix | System | No | ⚠️ Deletes pending print jobs. Restarts the print spooler. | `CustomFieldName` |
<!-- scripts:end -->
