New-Item -Type Directory -Path "C:\HWID" -ErrorAction SilentlyContinue
Set-Location -Path "C:\HWID"
$env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
Install-PackageProvider -Name NuGet -Force
Install-Script -Name Get-WindowsAutoPilotInfo -Force
$DeviceSerialNumber = (Get-WindowsAutoPilotInfo)."Device Serial Number"
$DeviceHardwareHash = (Get-WindowsAutoPilotInfo)."Hardware Hash"
Get-WindowsAutoPilotInfo -OutputFile "AutoPilotHWID-$DeviceSerialNumber.csv"
