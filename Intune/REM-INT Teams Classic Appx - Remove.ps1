# Create a log file just so Intune knows this was already run
If (!(Test-Path "$($Env:ProgramData)\Microsoft\RemoveOEMBloatware"))
{
   New-Item -Path "$($Env:ProgramData)\Microsoft\" -Name "RemoveOEMBloatware" -ItemType "Directory"
}
Set-Content -Path "$($Env:ProgramData)\Microsoft\RemoveOEMBloatware\RemoveAppxTeams.log" -Value "Removal Script"

# Start logging
Start-Transcript "$($Env:ProgramData)\Microsoft\RemoveOEMBloatware\RemoveAppxTeams.log"

#Get appx package info
$AppxPackage = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "MicrosoftTeams" }

# Remove appx package
Write-Host -Object "Attempting to remove Appx package: [$($AppxPackage.DisplayName)]..."

Try {
  $Null = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "MicrosoftTeams" } | Remove-AppxProvisionedPackage -Online -AllUsers -ErrorAction Stop
  Write-Host -Object "Successfully removed Appx package: [$($AppxPackage.DisplayName)]"
}
  Catch {Write-Warning -Message "Failed to remove Appx package: [$($AppxPackage.DisplayName)]"
}

