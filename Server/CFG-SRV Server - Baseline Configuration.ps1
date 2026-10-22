

#Install Telnet
dism /online /Enable-Feature /FeatureName:TelnetClient

#Set High Performance Power
PowerCfg -SetActive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

#DEP Settings
bcdedit /set nx OptIn

#Change CD Drive Letter
Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | Select-Object -First 1 | Set-WmiInstance -Arguments @{DriveLetter='R:'}

# Set to Minidump
Get-WmiObject -Class Win32_OSRecoveryConfiguration -EnableAllPrivileges | Set-WmiInstance -Arguments @{ DebugInfoType=3 }

#Set Boot timeout
bcdedit /timeout 10

#Disable IE Enhance Security
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
Stop-Process -Name Explorer -Confirm:$false

#Set to NZ Region
Set-WinSystemLocale en-NZ
Set-WinHomeLocation -GeoId 183
$LanguageList = New-WinUserLanguageList -Language en-NZ
Set-WinUserLanguageList -LanguageList $LanguageList -Force

#Disable Windows Update
New-ItemProperty -Path Registry::HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU -Name NoAutoUpdate -PropertyType DWORD -Value 1 -Force

#Enable .NET 3.5
dism /online /Enable-Feature /FeatureName:NetFx3 /all

#Set to NZ Time
Set-TimeZone -Id "New Zealand Standard Time"

#Enable RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
#Enable Firewall Rule
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
#Enable RDP Authentication
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0

#Disable defrag Scheduled task
If ((Get-ScheduledTask -TaskName 'ScheduledDefrag').State -eq 'Ready') 
{
    Disable-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath '\Microsoft\Windows\Defrag'
}

# Ignore remote keyboard
New-ItemProperty -Path "Registry::HKLM\System\CurrentControlSet\Control\Keyboard Layout" -Name IgnoreRemoteKeyboardLayout -PropertyType DWORD -Value 1 -Force

