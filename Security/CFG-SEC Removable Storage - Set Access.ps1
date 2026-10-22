#Requires -Version 2.0

<#
.SYNOPSIS
    Disable or Enable Write, Read, and Execute access to Removable Storage devices.
.DESCRIPTION
    Disable or Enable Write, Read, and Execute access to Floppy, CD/DVD, Tape, WPD, and/or USB devices.
    Disable actions are done first, then allow actions are done after.
.PARAMETER Device
    Device types that the permissions will be applied to. Accepts a list separated by commas. Devices supported: Floppy, DVD, Tape, WPD, USB
.PARAMETER DenyRead
    Denies read access to device(s).
.PARAMETER DenyWrite
    Denies write access to device(s).
.PARAMETER DenyExecute
    Denies execute access to device(s). WPD devices do not support this and will be skipped.
.PARAMETER AllowRead
    Allows read access to device(s).
.PARAMETER AllowWrite
    Allows write access to device(s).
.PARAMETER AllowReadAndExecute
    Allows execute access to device(s). WPD devices do not support this and will be skipped.
.PARAMETER ForceReboot
    Reboots computer after applying settings.
.EXAMPLE
     -Device DVD -DenyRead -DenyWrite -DenyExecute
    Disable Write, Read, and Execute access to CD/DVD drive.
.EXAMPLE
     -Device DVD -AllowRead -AllowWrite -AllowReadAndExecute
    Allow Write, Read, and Execute access to CD/DVD drive.
.EXAMPLE
     -Device DVD -DenyWrite -DenyExecute -AllowRead
    Disable Write, Read, and Execute access to CD/DVD drive, but Allow Read.
.OUTPUTS
    None
.NOTES
    Minimum OS Architecture Supported: Windows 7, Windows Server 2012
    Local Group Policy updates like this requires the computer to rebooted.
    Version: 1.1
    Release Notes: Added notice that computer will restart if ForceReboot is used. Using both the "Allow" and "Deny" options of the same permission (Read, Write, Execute) is no longer permitted. Changed "Allow Read" to "Allow Read and Execute." Added warning that WPD does not support the Execute option. Improved input validation and error handling. Added Set-RegKey function. Updated parameter descriptions and output.
#>

[CmdletBinding()]
param (
    # Supported devices Floppy, DVD, Tape, WPD, USB
    [String[]]
    $Device,
    [switch]
    $DenyRead = [System.Convert]::ToBoolean($env:DenyRead),
    [switch]
    $DenyWrite = [System.Convert]::ToBoolean($env:DenyWrite),
    [switch]
    $DenyExecute = [System.Convert]::ToBoolean($env:DenyExecute),
    [switch]
    $AllowRead = [System.Convert]::ToBoolean($env:AllowRead),
    [switch]
    $AllowWrite = [System.Convert]::ToBoolean($env:AllowWrite),
    [switch]
    $AllowReadAndExecute = [System.Convert]::ToBoolean($env:AllowReadAndExecute),
    [switch]
    $ForceReboot = [System.Convert]::ToBoolean($env:ForceReboot)
)

begin {
    function Test-StringEmpty {
        param([string]$Text)
        # Returns true if string is empty, null, or whitespace
        process {
            try {
                # Prefer IsNullOrWhiteSpace if it is available
                return [string]::IsNullOrWhiteSpace($Text)
            }
            catch {
                # Otherwise fall back to IsNullOrEmpty with a trim
                return [string]::IsNullOrEmpty($Text.Trim())
            }
        }
    }
    function Test-IsElevated {
        [CmdletBinding()]
        param ()
    
        # Get the current Windows identity of the user running the script
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    
        # Create a WindowsPrincipal object based on the current identity
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
    
        # Check if the current user is in the Administrator role
        # The function returns $True if the user has administrative privileges, $False otherwise
        # 544 is the value for the Built In Administrators role
        # Reference: https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsbuiltinrole
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]'544')
    }

    $ExitCode = 0

    # import device from environment variable
    if (-not (Test-StringEmpty -Text $env:device)) {
        $Device = $env:Device
    }

    if (Test-StringEmpty $device) {
        Write-Host "[Error] Device is required."
        exit 1
    }

    $validDeviceOptions = "Floppy", "DVD", "Tape", "WPD", "USB"

    # create new list to store verified devices
    $verifiedDevices = New-Object System.Collections.Generic.List[string]
    
    # split the device string if it has a comma and trim the whitespace
    $Device = $Device | ForEach-Object {
        $_ -split ',' | ForEach-Object {
            "$_".Trim()
        }
    }

    # check if the device is supported
    # if so, add it to the verified devices list
    foreach ($CurDevice in $Device) {
        if ($validDeviceOptions -notcontains $CurDevice) {
            Write-Host "[Error] Device '$CurDevice' is not supported."
            $ExitCode = 1
        }
        else{
            $verifiedDevices.Add($CurDevice)
        }
    }

    # if there are no verified devices, error out
    if ($verifiedDevices.Count -eq 0){
        Write-Host "[Error] No valid devices were provided."
        exit 1
    }

    # error if no permissions are selected
    if ((-not $DenyRead -and -not $DenyWrite -and -not $DenyExecute) -and (-not $AllowRead -and -not $AllowWrite -and -not $AllowReadAndExecute)) {
        Write-Host "[Error] At least one Deny or Allow is required."
        exit 1
    }

    # validate that Deny and Allow parameters for the same permission are not used together
    if (($DenyRead -and $AllowRead) -or ($DenyWrite -and $AllowWrite) -or ($DenyExecute -and $AllowReadAndExecute) -or ($DenyRead -and $AllowReadAndExecute)) {
        Write-Host "[Error] You cannot use both Deny and Allow options for the same permission."
        exit 1
    }

    function Set-RegKey {
        [CmdletBinding()]
        param (
            [Parameter()]
            [String]$Path,
            [Parameter()]
            [String]$Name,
            [Parameter()]
            $Value,
            [Parameter()]
            [ValidateSet("DWord", "QWord", "String", "ExpandedString", "Binary", "MultiString", "Unknown")]
            [String]$PropertyType = "DWord"
        )
    
        if(Test-StringEmpty -Text $Path){
            throw (New-Object System.ArgumentNullException("You must provide a valid path to a registry key."))
        }
    
        if($Path -notmatch "^(Registry::|HKCR:\\|HKCU:\\|HKLM:\\|HKU:\\|HKCC:\\|TestRegistry:\\)"){
            throw (New-Object System.ArgumentException("The path provided '$Path' is invalid as it does not start with 'Registry::', 'HKCR:\', 'HKCU:\', 'HKLM:\', 'HKU:\' or 'HKCC:\'."))
        }
    
        if($Path -match "^Registry::" -and $Path -notmatch "^Registry::(HKCR\\|HKEY_CLASSES_ROOT\\|HKCU\\|HKEY_CURRENT_USER\\|HKLM\\|HKEY_LOCAL_MACHINE|HKU\\|HKEY_USERS|HKCC\\|HKEY_CURRENT_CONFIG)"){
            throw (New-Object System.ArgumentException("The path provided '$Path' is invalid as it does not start with a valid registry root such as 'HKLM\' or 'HKEY_LOCAL_MACHINE\'."))
        }
    
        if(Test-StringEmpty -Text $Name){
            throw (New-Object System.ArgumentNullException("You must provide a valid name for the registry property."))
        }
    
        # Check if the specified registry path exists
        if (!(Test-Path -Path $Path)) {
            try {
                # If the path does not exist, create it
                New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
            }
            catch {
                throw $_
            }
        }
    
        # Check if the registry key already exists at the specified path
        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            # Retrieve the current value of the registry key
            $CurrentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
            if ($CurrentValue -eq $Value) {
                Write-Host "$Path\$Name is already the value '$Value'."
            }
            else {
                try {
                    # Update the registry key with the new value
                    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -Confirm:$false -ErrorAction Stop | Out-Null
                }
                catch {
                    throw $_
                }
    
                # Output the change made to the registry key
                Write-Host "$Path\$Name changed from $CurrentValue to $((Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name)"
            }
    
            return
        }
    
        try {
            # If the registry key does not exist, create it with the specified value and property type
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force -Confirm:$false -ErrorAction Stop | Out-Null
        }
        catch {
            throw $_
        }
    
        # Output the creation of the new registry key
        Write-Host "Set $Path\$Name to $((Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name)"
    }
}
process {
    if (-not (Test-IsElevated)) {
        Write-Host "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    # list of devices along with their registry paths and settings
    $RegSettings = @(
        [PSCustomObject]@{
            Name        = "Floppy"
            BasePath    = "HKLM:\Software\Policies\Microsoft\Windows\RemovableStorageDevices\{53f56311-b6bf-11d0-94f2-00a0c91efb8b}"
            DenyExecute = "Deny_Execute"
            DenyWrite   = "Deny_Write"
            DenyRead    = "Deny_Read"
        },
        [PSCustomObject]@{
            Name        = "DVD"
            BasePath    = "HKLM:\Software\Policies\Microsoft\Windows\RemovableStorageDevices\{53f56308-b6bf-11d0-94f2-00a0c91efb8b}"
            DenyExecute = "Deny_Execute"
            DenyWrite   = "Deny_Write"
            DenyRead    = "Deny_Read"
        },
        [PSCustomObject]@{
            Name        = "Tape"
            BasePath    = "HKLM:\Software\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630b-b6bf-11d0-94f2-00a0c91efb8b}"
            DenyExecute = "Deny_Execute"
            DenyWrite   = "Deny_Write"
            DenyRead    = "Deny_Read"
        },
        [PSCustomObject]@{
            Name      = "WPD"
            BasePath  = "HKLM:\Software\Policies\Microsoft\Windows\RemovableStorageDevices\{6AC27878-A6FA-4155-BA85-F98F491D4F33}","HKLM:\Software\Policies\Microsoft\Windows\RemovableStorageDevices\{F33FDC04-D1AC-4E8E-9A30-19BBD4B108AE}"
            DenyWrite = "Deny_Write"
            DenyRead  = "Deny_Read"
        },
        [PSCustomObject]@{
            Name        = "USB"
            BasePath    = "HKLM:\Software\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}"
            DenyExecute = "Deny_Execute"
            DenyWrite   = "Deny_Write"
            DenyRead    = "Deny_Read"
        }
    )

    # check if the user is setting WPD devices to allow or deny execute access, warn if so
    if ($verifiedDevices -contains "WPD" -and ($AllowReadAndExecute -or $DenyExecute)){
        Write-Host "[Warning] WPD devices do not support execute access."
        if ($AllowReadAndExecute){
            Write-Host "[Warning] Read access will still be granted."
        }
    }

    try {
        $verifiedDevices | ForEach-Object {
            # save current device name to a variable (i.e. "DVD","USB", etc)
            $CurDevice = $_

            # loop through the registry settings of the current device
            $RegSettings | Where-Object { $_.Name -contains $CurDevice } | ForEach-Object {
                # save current device registry setting object to a variable
                $CurRegSetting = $_

                # save the registry paths for this device to a variable
                $RegistryPaths = $CurRegSetting.BasePath

                # Build Deny list
                $DenyOptions = New-Object System.Collections.Generic.List[string]
                if ($DenyRead) { $DenyOptions.Add("Read")}
                if ($DenyWrite) { $DenyOptions.Add("Write")}
                if ($DenyExecute) { $DenyOptions.Add("Execute")}

                # Build Allow list
                $AllowOptions = New-Object System.Collections.Generic.List[string]
                if ($AllowRead -and -not $AllowReadAndExecute) { $AllowOptions.Add("Read")}
                if ($AllowWrite) { $AllowOptions.Add("Write")}
                if ($AllowReadAndExecute) { $AllowOptions.Add("Read"); $AllowOptions.Add("Execute")}

                # Loop though each item in the deny options list
                $DenyOptions | ForEach-Object {
                    # save current deny option to a variable (i.e. "Read", "Write", "Execute")
                    $CurDenyOption = $_

                    # if the device is WPD and option is Execute, skip because WPD devices do not support execute access
                    if ($CurDevice -eq "WPD" -and $CurDenyOption -eq "Execute"){
                        return
                    }

                    Write-Host "`n[Info] Changing the registry to deny $CurDenyOption access to $CurDevice devices."
                    foreach ($Path in $RegistryPaths) {
                        # check if the current deny option exists in the current registry setting
                        # if so, proceed with changing the registry key
                        if ($CurRegSetting."Deny$CurDenyOption") {
                            $CurDenyType = $CurRegSetting."Deny$CurDenyOption"

                            try{
                                Set-RegKey -Path $Path -Name $CurDenyType -Value 1 -PropertyType "DWORD"
                            }
                            catch{
                                Write-Host "[Error] Error denying $CurDenyOption access to $CurDevice devices."
                                Write-Host "[Error] $($_.Exception.Message)"
                                $ErrorSettingDenyRegistry = $true
                                $ExitCode = 1
                            }
                        }
                    }
                    # if no error occurred while setting the registry keys, print a success message
                    if (-not $ErrorSettingDenyRegistry){
                        Write-Host "[Info] Successfully denied $CurDenyOption access to $CurDevice devices."
                    }
                }

                # Loop though each item in the allow options list
                $AllowOptions | ForEach-Object {
                    # save current allow option to a variable (i.e. "Read", "Write", "Execute")
                    $CurAllowOption = $_

                    # if the device is WPD and option is Execute, skip because WPD devices do not support execute access
                    if ($CurDevice -eq "WPD" -and $CurAllowOption -eq "Execute"){
                        return
                    }

                    Write-Host "`n[Info] Changing the registry to allow $CurAllowOption access to $CurDevice devices."
                    foreach ($Path in $RegistryPaths){
                        # check if the current allow option exists in the current registry setting
                        # if so, proceed with changing the registry key
                        if ($CurRegSetting."Deny$CurAllowOption") {
                            $CurAllowType = $CurRegSetting."Deny$CurAllowOption"

                            try{
                                Set-RegKey -Path $Path -Name $CurAllowType -Value 0 -PropertyType "DWORD"
                            }
                            catch{
                                Write-Host "[Error] Error allowing $CurAllowOption access to $CurDevice devices."
                                Write-Host "[Error] $($_.Exception.Message)"
                                $ErrorSettingAllowRegistry = $true
                                $ExitCode = 1
                            }
                        }
                    }
                    # if no error occurred while setting the registry keys, print a success message
                    if (-not $ErrorSettingAllowRegistry){
                        Write-Host "[Info] Successfully allowed $CurAllowOption access to $CurDevice devices."
                    }
                }
            }
        }

        Write-Host "`n[Info] Running group policy update."

        # Generate unique log file names for capturing the stdout and stderr of the 'gpupdate.exe' process.
        $StandardOutLog = "$env:TEMP\$(Get-Random)_gpupdate_stdout.log"

        try {
            # Start the group policy update process
            $gpupdateProcess = Start-Process -FilePath "$env:SystemRoot\System32\gpupdate.exe" -ArgumentList "/force" -Wait -NoNewWindow -PassThru -RedirectStandardOutput $StandardOutLog -ErrorAction Stop
        }
        catch {
            # If the 'gpupdate.exe' process fails to start, output an error message
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to start '$env:SystemRoot\System32\gpupdate.exe'."
            $ExitCode = 1
        }

        # If the exit code is non-zero (indicating an error occurred), display an error message
        if ($gpupdateProcess.ExitCode -ne 0) {
            Write-Host -Object "[Error] Failed to update group policy, exit code: $($gpupdateProcess.ExitCode)"

            # Check if the standard output log file exists.
            if (Test-Path -Path $StandardOutLog -ErrorAction SilentlyContinue) {
                # Retrieve the contents of the error log
                $errorContent = Get-Content -Path $StandardOutLog -ErrorAction SilentlyContinue
                
                if ($ErrorContent){
                    # Remove blank lines and the header of the log
                    $errorContent = $errorContent | Where-Object {$_} | Select-Object -Skip 1 | Out-String

                    # Add [Error] prefix to the beginning
                    $errorContent = $errorContent.Trim() -replace "^","[Error] "
                    
                    # Display the error content to the user
                    $errorContent | Out-Host
                }

                try {
                    # Attempt to delete the stdout log file after displaying its contents.
                    Remove-Item -Path $StandardOutLog -ErrorAction Stop
                }
                catch {
                    Write-Host -Object "[Error] Failed to remove standard output log at '$StandardOutLog'"
                }
            }
            Write-Host ""
            Write-Host "[Error] Group policy may need to be refreshed manually."
            $ExitCode = 1
        }
        else {
            Write-Host -Object "[Info] Group policy update completed successfully."
        }

        Write-Host ""

        # if force reboot was selected, schedule a reboot in 1 minute and notify the user
        if ($ForceReboot) {
            Write-Host "[Info] Rebooting computer in 60 seconds..."
            shutdown.exe -r -t 60
        }
        else {
            Write-Host "[Info] Computer will need to be rebooted for the changes to take effect."
        }
        exit $ExitCode
    }
    catch {
        Write-Host "[Error] $($_.Exception.Message)"
        exit 1
    }
}
end {
    
    
    
}
