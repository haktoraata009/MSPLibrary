# Printers & Devices

Printer mapping and queue fixes, Bluetooth unpairing.

## Before you run

- Add Network Printer installs per machine, so every user profile gets the printer.
- Clearing the print queue deletes pending jobs.

## Scripts

**Script variables** are the NinjaOne script variables the script reads as `$env:<name>`. Create them with the same names in the NinjaOne script editor, or pass the matching parameter when running locally.

**Changes device?** Yes = the script can change settings, files, services or restart the device. No = read-only report or check. Admin PC = runs against a Microsoft 365 or Entra tenant from an admin workstation. This is worked out from the code, so read the script before running it.

<!-- scripts:start -->
| Script | What it does | Script variables | Changes device? |
|---|---|---|---|
| [Add Network Printer](Add%20Network%20Printer.ps1) | Adds or removes a shared network printer for all user profiles on this computer as a per computer connection. | `ComputerName`, `forceRestart`, `printerSharePath`, `removePrinter` | Yes |
| [Troubleshoot Printers and Clear Print Queue](Troubleshoot%20Printers%20and%20Clear%20Print%20Queue.ps1) | Clear print queues and list printers to help troubleshoot printing issues. | `CustomFieldName` | Yes |
| [Unpair Bluetooth Devices](Unpair%20Bluetooth%20Devices.ps1) | Unpair Bluetooth devices from the system. | `UnpairAllDevices` | Yes |
<!-- scripts:end -->
