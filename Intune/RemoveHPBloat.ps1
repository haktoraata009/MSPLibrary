# Create a log file just so Intune knows this was already run

If (!(Test-Path "$($Env:ProgramData)\Microsoft\RemoveOEMBloatware"))
{
   New-Item -Path "$($Env:ProgramData)\Microsoft\" -Name "RemoveOEMBloatware" -ItemType "Directory"
}
Set-Content -Path "$($Env:ProgramData)\Microsoft\RemoveOEMBloatware\RemoveHPBloatware.log" -Value "Installed"

# Start logging
Start-Transcript "$($Env:ProgramData)\Microsoft\RemoveOEMBloatware\RemoveHPBloatware.log"

#Set HP's store app identifier
$HPidentifier = "AD2F1837"

#Find installed packages whose names start with the HP identifier
$InstalledPackages = Get-AppxPackage -AllUsers | Where {($_.Name -match "^$HPidentifier")}
#Find provisioned packages whose names start with the HP identifier
$ProvisionedPackages = Get-AppxProvisionedPackage -Online | Where {($_.DisplayName -match "^$HPidentifier")}
#Find the installed apps based on the name starting with HP but skip any firmware installs
$InstalledPrograms = Get-Package | Where {($_.Name -match "^HP ") -and ($_.Name -notmatch "Firmware")}

# Remove provisioned packages first
ForEach ($ProvPackage in $ProvisionedPackages) {

    Write-Host -Object "Attempting to remove provisioned package: [$($ProvPackage.DisplayName)]..."

    Try {
        $Null = Remove-AppxProvisionedPackage -PackageName $ProvPackage.PackageName -Online -ErrorAction Stop
        Write-Host -Object "Successfully removed provisioned package: [$($ProvPackage.DisplayName)]"
    }
    Catch {Write-Warning -Message "Failed to remove provisioned package: [$($ProvPackage.DisplayName)]"}
}

# Remove appx packages
ForEach ($AppxPackage in $InstalledPackages) {
                                            
    Write-Host -Object "Attempting to remove Appx package: [$($AppxPackage.Name)]..."

    Try {
        $Null = Remove-AppxPackage -Package $AppxPackage.PackageFullName -AllUsers -ErrorAction Stop
        Write-Host -Object "Successfully removed Appx package: [$($AppxPackage.Name)]"
    }
    Catch {Write-Warning -Message "Failed to remove Appx package: [$($AppxPackage.Name)]"}
}

# Remove installed programs
$InstalledPrograms | ForEach {

    Write-Host -Object "Attempting to uninstall: [$($_.Name)]..."

    Try {
        $Null = $_ | Uninstall-Package -AllVersions -Force -ErrorAction Stop
        Write-Host -Object "Successfully uninstalled: [$($_.Name)]"
    }
    Catch {Write-Warning -Message "Failed to uninstall: [$($_.Name)]"}
}

Stop-Transcript