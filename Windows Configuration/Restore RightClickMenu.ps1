# Define the registry flag path
$RegistryFlagPath = "Registry::HKEY_CURRENT_USER\Software\Company\RunOnce_RightClickFix"

# Check if the script has been executed before
if (Test-Path $RegistryFlagPath) {
    Write-Host 'Script has already been executed. Exiting...'
    Exit 0
}
else {
    try {
        # Create or modify the registry flag to indicate that the script has been executed
        New-Item -Path $RegistryFlagPath -Force

        # Define the registry path for your modifications
        $RegistryPath = "Registry::HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"

        try {
            # Create or modify the registry key and set its value
            New-Item -Path $RegistryPath -Force
            Set-ItemProperty -Path $RegistryPath -Name '(Default)' -Value ''

            Write-Host 'Windows 11 right-click menu adjusted to be Windows 10 style.'
        }
        catch {
            Write-Host "An error occurred: $_"
        }
    }
    catch {
        Write-Host "An error occurred while creating the registry flag: $_"
    }
}

# Restart Windows Explorer
Stop-Process -Name explorer -Force
Start-Sleep -Seconds 5
Start-Process explorer

Exit 0