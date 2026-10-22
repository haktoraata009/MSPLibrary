# Author:          Stefan Runarsson
# Date:            12/05/2020
#
#**********************************************************************************************************************
#                   Create Required Objects and Initialise Variables
#**********************************************************************************************************************

# Import required Modules
Import-Module PSTerminalServices 

# Load .Net and Visual Basic which allows the construction of forms
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null

# Setup constants and initialise variables
#$WSHNetwork = new-Object -com WScript.Network 

$RDGatewayIP = "10.1.0.5"
$LogLocation = "\\domain.com\logging$\Connection Logging\"
$LogFile = $LogLocation + "Connection Log $(Get-Date -Format yyyy-MM-dd).csv"
$DaystoKeep = 30
$Server = $Env:ComputerName

# Clear the error variable
$Error.Clear()
#Don't report any errors that crop up - prevents the flash of red in the powershell console should it be visible.
$ErrorActionPreference = "SilentlyContinue"

#---------------------------------------------------------------------
#                   Sub-routines and Functions
#---------------------------------------------------------------------


#---------------------------------------------------------------------
#                   Main Script
#---------------------------------------------------------------------

#Check if todays log file exists, if not create it
If (!(Test-Path $LogFile))
{
  Add-Content -Path $LogFile -Value "User Name, Logon Time, RDSH Server, Connection Type, Workstation Name, IP Address, Geolocation Info"
  #Since this is the first run for the day, delete the old files as well
  Get-ChildItem $LogLocation -Recurse | Where-Object { $_.LastWriteTime -lt $($CurrentDate.AddDays(-$DaystoKeep)) } | Remove-Item
}

#Read in the latest Windows event
$Event = Get-WinEvent -LogName "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" -MaxEvents 5| Where-Object {$_.ID -eq 21 -or $_.ID -eq 25}
#Get the session info from the event
$DomainUser = $Event[0].Properties[0].Value
$SessionID = $Event[0].Properties[1].Value
$ClientIP = $Event[0].Properties[2].Value
$ConnectionTime = $Event[0].TimeCreated

#Split the username and domain, keep only the username
$UserName = $DomainUser.Split("\")[1]

#Determine if the session is a new one or a reconnection
$ClientName = $(Get-TSSession $SessionID).ClientName
If ($Event[0].ID -eq 21)
{
  $ConnectionType = "New Logon"
}
If ($Event[0].ID -eq 25)
{
  $ConnectionType = "Reconnection"
}
 
#If the reported IP is the RDG server, query the gateway to get information on the remote connection 
If ($ClientIP -match $RDGatewayIP)
{
  $External = $True
  $SessionInfo = Get-WmiObject -class "Win32_TSGatewayConnection" -namespace "root\cimv2\TerminalServices" -Computer $RDGatewayIP -Authentication 6 | Where {$_.UserName -eq $DomainUser}
  $ClientIP = $SessionInfo.ClientAddress
  $GeoDetails = Invoke-RestMethod -Uri "https://ipinfo.io/$ClientIP"
  $Region = $GeoDetails.Region
  $ISP = $GeoDetails.Org
}


If ($External)
{
  $Text = "Region: $Region & ISP: $ISP" 
  Add-Content -Path $LogFile -Value "$UserName, $ConnectionTime, $Server, $ConnectionType, $ClientName, $ClientIP, $Text"
}
Else
{
  $Text = "Logged on from trusted IP so no geodata obtained"
  Add-Content -Path $LogFile -Value "$UserName, $ConnectionTime, $Server, $ConnectionType, $ClientName, $ClientIP, $Text"
}