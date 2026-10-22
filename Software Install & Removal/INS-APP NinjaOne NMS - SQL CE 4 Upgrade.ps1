# This scripts automates the SQL database upgrade process related to NinjaNMS

# Parameters
$pathToDirectory = "C:\ProgramData\Ninja Network Management\NMS\Server\NMSDB\Upgrade_Download"
$pathToSource = "C:\ProgramData\Ninja Network Management\NMS\Server\NMSDB"
$pathToTarget = "C:\ProgramData\Ninja Network Management\NMS\Server\NMSDB\SQLCE4"
$whereToDownload = "https://ninjauploads.s3.amazonaws.com/blob:https://app.ninjarmm.com/ae1f85e4-ef1598566076459/NMS_SQLCe_4.0_Upgrade.zip"
$fileLocation = "$pathToDirectory\NMS SQLCe_4.0_Upgrade.zip"

Write-Host "Path should be: $pathToDirectory"

# Download and extract needed upgrade archive and create folder for upgrade tool logging

New-Item -ItemType Directory -Force -Path "$pathToSource\DBUpgradeLogs"
New-Item -ItemType Directory -Force -Path "$pathToSource\Upgrade_Download"
$down = New-Object System.Net.WebClient
$down.DownloadFile($whereToDownload, $fileLocation);

Expand-Archive -LiteralPath $fileLocation -DestinationPath $pathToDirectory

# (Wait for about 1 minutes for the Services to fully stop, there is a delay for the processes ptserverService.exe
# [NinjaNetworkManageServer] and ptagentService.exe [NinjaNetworkManageAgent] to disappear from Task Manager).

Write-Host "Stopping Ninja Network Management Services."

Get-Service NinjaNetworkManageServer | Stop-Service -PassThru | Set-Service -StartupType Disabled
Get-Service NinjaNetworkManageAgent | Stop-Service -PassThru | Set-Service -StartupType Disabled

Start-Sleep -Seconds 60

Write-Host "Stopped Ninja Network Management Services."

# This will remove the data_*.sdf files which are where NMS temporarily stores the data before moving it to the cloud for the Ninja Console.)

Write-Host "Removing old data_*.sdf files."

Remove-Item "\ProgramData\Ninja Network Management\NMS\Server\NMSDB\data_*.sdf" -Force

Write-Host "Removed old data_*.sdf files."

# Run the database upgrade tool on the remaining 6 files Pt*.sdf

Write-Host "Running database upgrade tool."

Start-Process -FilePath "$pathToDirectory\NMS SQLCe_4.0_Upgrade\Release\UpgradeNmsDb.exe" -ArgumentList "source=`"C:\ProgramData\Ninja Network Management\NMS\Server\NMSDB`" target=`"C:\ProgramData\Ninja Network Management\NMS\Server\NMSDB\SQLCE4`"" -RedirectStandardError $pathToSource\DBUpgradeLogs\error.log -RedirectStandardOutput $pathToSource\DBUpgradeLogs\output.log

Start-Sleep -Seconds 60

$oldSdfs = (Get-ChildItem $pathToSource | Where-Object{$_.Name -like "Pt*"})

Start-Sleep -Seconds 15

foreach($oldSdf in $oldSdfs) {
    Remove-Item $pathToSource\$oldSdf -Force
}

Start-Sleep -Seconds 15

$newSdfs = (Get-ChildItem $pathToTarget | Where-Object{$_.Name -like "Pt*"})

Start-Sleep -Seconds 15

foreach($newSdf in $newSdfs) {
    Copy-Item $pathToTarget\$newSdf -Destination $pathToSource
}

Start-Sleep -Seconds 15

Remove-Item $pathToTarget -Recurse -Force

Write-Host "Ran database upgrade tool."

# Copy over "System.Data.SQLServerCe.dll" and "System.Data.SqlServerCe.Entity.dll" to 
# "C:\Program Files (x86)\Ninja Network Management\Ninja NMS\Server" and replace existing files and remove downloads.

Write-Host "Replacing .dlls with upgraded versions."

Copy-Item "$pathToDirectory\NMS SQLCe_4.0_Upgrade\System.Data.SqlServerCe.dll" -Destination "C:\Program Files (x86)\Ninja Network Management\Ninja NMS\Server" -Force

Copy-Item "$pathToDirectory\NMS SQLCe_4.0_Upgrade\System.Data.SqlServerCe.Entity.dll" -Destination "C:\Program Files (x86)\Ninja Network Management\Ninja NMS\Server" -Force

Write-Host "Replaced .dlls with upgraded versions."

Remove-Item "$pathToSource\Upgrade_Download" -Recurse -Force

# Start re-enable 'automatic' for the Services and start the Services back up for NinjaNetworkManageServer and NinjaNetworkManageAgent)

Write-Host "Starting Ninja Network Management Services."

Get-Service NinjaNetworkManageServer | Set-Service -StartupType Manual
Get-Service NinjaNetworkManageServer | Start-Service
Get-Service NinjaNetworkManageServer | Set-Service -StartupType Automatic

Get-Service NinjaNetworkManageAgent | Set-Service -StartupType Manual
Get-Service NinjaNetworkManageAgent | Start-Service
Get-Service NinjaNetworkManageAgent | Set-Service -StartupType Automatic

Write-Host "Started Ninja Network Management Services."

Write-Host "Upgrade complete."
