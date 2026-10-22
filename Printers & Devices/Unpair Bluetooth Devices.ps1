#Requires -Version 5.1

<#
.SYNOPSIS
    Unpair Bluetooth devices from the system. By default, only connected devices are unpaired. Note that unpairing a device will disconnect it from the system and remove it from the paired Bluetooth devices list.

    MUST be run as the currently logged in user.

    This script is intended to be used in conjunction with the "Enable or Disable Bluetooth" script to unpair devices before disabling Bluetooth, and can also be used on its own to unpair devices without changing the Bluetooth state.
.DESCRIPTION
    Unpair Bluetooth devices from the system. By default, only connected devices are unpaired. Note that unpairing a device will disconnect it from the system and remove it from the paired Bluetooth devices list.

    MUST be run as the currently logged in user.

    This script is intended to be used in conjunction with the "Enable or Disable Bluetooth" script to unpair devices before disabling Bluetooth, and can also be used on its own to unpair devices without changing the Bluetooth state.

.PARAMETER UnpairAllDevices
    When specified, unpairs all paired Bluetooth devices regardless of connection status. By default, only currently connected devices are unpaired.

.EXAMPLE
    [Info] Found 1 connected Bluetooth device(s).

    [Info] Unpairing Bluetooth device 'Jabra Elite 3'...
    [Info] Successfully unpaired 'Jabra Elite 3'.

.EXAMPLE
    -UnpairAllDevices

    [Info] Found 2 paired Bluetooth device(s).

    [Info] Unpairing Bluetooth device 'Jabra Elite 3'...
    [Info] Successfully unpaired 'Jabra Elite 3'.

    [Info] Unpairing Bluetooth device 'MX Keys Mini'...
    [Info] Successfully unpaired 'MX Keys Mini'.

.NOTES
    Minimum OS Architecture Supported: Windows 10
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [switch]$UnpairAllDevices = [System.Convert]::ToBoolean($env:UnpairAllDevices)
)
begin {
    Write-Host -Object ""

    # Check if the operating system build version is less than 10240 (Windows 10 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    #region Helper functions and assembly loading
    # Load the required Windows Runtime types for interacting with Bluetooth
    try {
        [Windows.Devices.Radios.Radio,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
        [Windows.Devices.Bluetooth.BluetoothLEDevice,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
    }
    catch {
        Write-Host -Object "[Error] Failed to load the required Windows Runtime types for Bluetooth."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Add the System.Runtime.WindowsRuntime assembly
    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] Failed to load the Windows Runtime assembly."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Function to await Windows Runtime (WinRT) asynchronous operations and return their results
    function Wait-WinRTTask {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [object]$WinRtTask,
            [Parameter(Mandatory = $true)]
            [Type]$ResultType,
            [Parameter()]
            [int]$TimeoutInSeconds = 30
        )

        # Find the generic AsTask method that converts IAsyncOperation<T> (used by many Bluetooth WinRT operations) to a .NET Task<T>
        # https://learn.microsoft.com/dotnet/api/system.windowsruntimesystemextensions.astask?view=net-10.0#system-windowsruntimesystemextensions-astask(system-windows-runtime-interop-winrt-iasyncoperation-1))
        $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
            $_.Name -eq 'AsTask' -and
            $_.GetParameters().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
        } | Select-Object -First 1)

        # If the AsTask method is not found, write an error and return
        if (-not $asTaskGeneric) {
            Write-Error -Message "Failed to find the generic AsTask method for converting IAsyncOperation<T> to Task<T>." -Category ObjectNotFound
            return
        }

        try {
            # Convert the WinRT IAsyncOperation to a .NET Task
            # https://learn.microsoft.com/dotnet/api/system.reflection.methodinfo.makegenericmethod?view=net-10.0
            $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)

            # Invoke the AsTask method to get a Task object
            # https://learn.microsoft.com/dotnet/api/system.reflection.methodbase.invoke?view=net-10.0#system-reflection-methodbase-invoke(system-object-system-object())
            $netTask = $asTask.Invoke($null, @($WinRtTask))

            # Convert the timeout value from seconds to milliseconds for the Wait method
            $TimeoutInMilliseconds = [int]$TimeoutInSeconds * 1000

            # Wait for the task to complete
            $netTask.Wait($TimeoutInMilliseconds) | Out-Null

            # Check if the task completed successfully
            if (-not $netTask.IsCompleted) {
                Write-Error -Message "The Windows Runtime task did not complete within the allotted timeout of $TimeoutInSeconds seconds." -Category OperationTimeout
                return
            }

            # If the task completed with an exception, write the exception details
            if ($netTask.Exception) {
                $netTask.Exception | Write-Error
            }

            # Return the result
            return $netTask.Result
        }
        catch {
            # If the task completed with an exception, write the exception details and return
            if ($netTask.Exception) {
                $netTask.Exception | Write-Error
            }
            else {
                # Write the caught exception
                $_ | Write-Error
            }
            return
        }
        finally {
            # Clean up the Task object if it was created
            if ($netTask) {
                $netTask.Dispose()
            }
        }
    }

    # Function to unpair a Bluetooth device by its Device ID using WinRT APIs. Must be run as the currently logged in user
    function Unpair-BluetoothDeviceById {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$DeviceID
        )

        # Create a DeviceInformation object for the specified device ID
        $di = Wait-WinRTTask -WinRTTask ([Windows.Devices.Enumeration.DeviceInformation]::CreateFromIdAsync($DeviceId)) -ResultType ([Windows.Devices.Enumeration.DeviceInformation])

        # If the DeviceInformation object could not be created, write an error and return
        if (-not $di) {
            Write-Error -Message "Failed to retrieve device information for device ID '$DeviceID'." -Category ObjectNotFound
            return
        }

        # Attempt to unpair the device
        $unpair = Wait-WinRTTask -WinRtTask ($di.Pairing.UnpairAsync()) -ResultType ([Windows.Devices.Enumeration.DeviceUnpairingResult])

        # Throw an error if the device is not unpaired
        if ($unpair.Status -ne [Windows.Devices.Enumeration.DeviceUnpairingResultStatus]::Unpaired) {
            throw "Failed to unpair the device. Status: $($unpair.Status)"
        }
    }

    # Function to retrieve Classic Bluetooth devices using WinRT APIs
    function Get-BluetoothDevices {
        [CmdletBinding(DefaultParameterSetName = "AllDevices")]
        param (
            [Parameter(ParameterSetName = "AllDevices")]
            [switch]$AllDevices,
            [Parameter(ParameterSetName = "ConnectedDevices")]
            [switch]$ConnectedOnly,
            [Parameter()]
            [switch]$ReturnBluetoothDeviceObjects,
            [Parameter()]
            [switch]$ReturnDeviceInformationObjects
        )

        # Default to all devices if neither parameter is specified
        if (-not $AllDevices -and -not $ConnectedOnly) {
            $AllDevices = $true
        }

        # Default to returning BluetoothDevice objects if neither return type parameter is specified
        if (-not $ReturnBluetoothDeviceObjects -and -not $ReturnDeviceInformationObjects) {
            $ReturnBluetoothDeviceObjects = $true
        }

        try {
            # Determine the query to use based on the parameters
            if ($AllDevices) {
                $Query = [Windows.Devices.Bluetooth.BluetoothDevice]::GetDeviceSelector()
            }
            elseif ($ConnectedOnly) {
                $Query = [Windows.Devices.Bluetooth.BluetoothDevice]::GetDeviceSelectorFromConnectionStatus("Connected")
            }
        }
        catch {
            $_ | Write-Error
            return
        }

        # Use the query to find Bluetooth devices and return the results as a DeviceInformationCollection
        # https://learn.microsoft.com/uwp/api/windows.devices.enumeration.deviceinformation.findallasync
        $ParameterHash = @{
            "WinRTTask"   = [Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync($Query)
            "ResultType"  = [Windows.Devices.Enumeration.DeviceInformationCollection]
            "ErrorAction" = "Stop"
        }

        # Use the helper function to await the WinRT task and return the list of devices
        try {
            $DevicesToReturn = Wait-WinRTTask @ParameterHash
        }
        catch {
            $_ | Write-Error
            return
        }

        if ($ReturnBluetoothDeviceObjects) {
            # Loop through each device and retrieve a BluetoothDevice object via the device ID
            # https://learn.microsoft.com/uwp/api/windows.devices.bluetooth.bluetoothdevice.fromidasync
            $DevicesToReturn = foreach ($Device in $DevicesToReturn) {
                $ParameterHash = @{
                    WinRTTask   = [Windows.Devices.Bluetooth.BluetoothDevice]::FromIdAsync($Device.Id)
                    ResultType  = [Windows.Devices.Bluetooth.BluetoothDevice]
                    ErrorAction = "SilentlyContinue"
                }
                Wait-WinRTTask @ParameterHash
            }
        }

        # Return the list of Bluetooth devices
        return $DevicesToReturn
    }

    # Function to retrieve Bluetooth Low Energy (BLE) devices using WinRT APIs
    function Get-BluetoothLEDevices {
        [CmdletBinding(DefaultParameterSetName = "AllDevices")]
        param (
            [Parameter(ParameterSetName = "AllDevices")]
            [switch]$AllDevices,
            [Parameter(ParameterSetName = "ConnectedDevices")]
            [switch]$ConnectedOnly,
            [Parameter()]
            [switch]$ReturnBluetoothLEDeviceObjects,
            [Parameter()]
            [switch]$ReturnDeviceInformationObjects
        )

        # Default to all devices if neither parameter is specified
        if (-not $AllDevices -and -not $ConnectedOnly) {
            $AllDevices = $true
        }

        # Default to returning BluetoothLEDevice objects if neither return type parameter is specified
        if (-not $ReturnBluetoothLEDeviceObjects -and -not $ReturnDeviceInformationObjects) {
            $ReturnBluetoothLEDeviceObjects = $true
        }

        try {
            # Determine the query to use based on the parameters
            if ($AllDevices) {
                $Query = [Windows.Devices.Bluetooth.BluetoothLEDevice]::GetDeviceSelector()
            }
            elseif ($ConnectedOnly) {
                $Query = [Windows.Devices.Bluetooth.BluetoothLEDevice]::GetDeviceSelectorFromConnectionStatus("Connected")
            }
        }
        catch {
            $_ | Write-Error
            return
        }

        # Use the query to find BLE devices and return the results as a DeviceInformationCollection
        # https://learn.microsoft.com/uwp/api/windows.devices.enumeration.deviceinformation.findallasync
        $ParameterHash = @{
            "WinRTTask"   = [Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync($Query)
            "ResultType"  = [Windows.Devices.Enumeration.DeviceInformationCollection]
            "ErrorAction" = "Stop"
        }

        # Use the helper function to await the WinRT task and return the list of devices
        try {
            $DevicesToReturn = Wait-WinRTTask @ParameterHash
        }
        catch {
            $_ | Write-Error
            return
        }

        if ($ReturnBluetoothLEDeviceObjects) {
            # Loop through each device and retrieve a BluetoothLEDevice object via the device ID
            # https://learn.microsoft.com/uwp/api/windows.devices.bluetooth.bluetoothledevice.fromidasync
            $DevicesToReturn = foreach ($Device in $DevicesToReturn) {
                $ParameterHash = @{
                    WinRTTask   = [Windows.Devices.Bluetooth.BluetoothLEDevice]::FromIdAsync($Device.Id)
                    ResultType  = [Windows.Devices.Bluetooth.BluetoothLEDevice]
                    ErrorAction = "SilentlyContinue"
                }
                Wait-WinRTTask @ParameterHash
            }
        }

        # Return the list of BLE devices
        return $DevicesToReturn
    }

    # Function to retrieve Bluetooth PnP adapters
    function Get-BluetoothAdapters {
        [CmdletBinding()]
        param (
            [Parameter()]
            [switch]$IncludeAll
        )

        # Retrieve the Bluetooth PnP adapters
        try {
            if ($IncludeAll) {
                $BluetoothAdapters = Get-PnpDevice -Class Bluetooth -ErrorAction Stop
            }
            else {
                $BluetoothAdapters = Get-PnpDevice -ErrorAction Stop | Where-Object {$_.Service -eq "BTHUSB"}
            }
        }
        catch {
            throw $_
        }

        # Output each adapter
        foreach ($adapter in $BluetoothAdapters) {
            [PSCustomObject]@{
                Name        = $adapter.FriendlyName
                InstanceID  = $adapter.InstanceId
                Status      = $adapter.Status
                Description = $adapter.Description
                Caption     = $adapter.Caption
            }
        }
    }

    # Function to test if the system is a server
    function Test-IsServer {
        [CmdletBinding()]
        param()

        # Determine the method to retrieve the operating system information based on PowerShell version
        $OS = if ($PSVersionTable.PSVersion.Major -lt 3) {
            Get-WmiObject -Class Win32_OperatingSystem
        } else {
            Get-CimInstance -ClassName Win32_OperatingSystem
        }

        # Check the ProductType to determine if the system is a domain controller (2) or server (3)
        if (($OS.ProductType -eq "2" -or $OS.ProductType -eq "3") -and $OS.OperatingSystemSku -ne "175") {
            return $true
        }
    }

    # Function to test if the current session is running as SYSTEM
    function Test-IsSystem {
        [CmdletBinding()]
        param ()

        # Retrieve the current Windows identity of the user or process running the script
        $WindowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()

        # Check if the identity is a system account by verifying the IsSystem property
        # or comparing the User property to the well-known SID for the LocalSystem account (S-1-5-18)
        $WindowsIdentity.IsSystem -or $WindowsIdentity.User -eq "S-1-5-18"
    }
    #endregion

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    # Attempt to determine if the current session is running as the SYSTEM account.
    try {
        $IsSystem = Test-IsSystem -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$([environment]::UserName)' is the SYSTEM account."
        exit 1
    }

    # Error if the script is running as SYSTEM
    if ($IsSystem) {
        Write-Host -Object "[Error] This script is running as the SYSTEM account. Please run this script as the currently logged in user."
        exit 1
    }

    # Check if the system is a server
    try {
        $IsServer = Test-IsServer -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] Unable to determine if the system is a server."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # If the system is a server, exit the script
    if ($IsServer) {
        Write-Host -Object "[Error] Bluetooth is not supported on server systems."
        exit 1
    }

    #region Retrieve Bluetooth adapters
    # Retrieve the Bluetooth adapters on the device
    try {
        $BluetoothAdapters = Get-BluetoothAdapters -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] Failed to retrieve Bluetooth adapters on this system."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }
    #endregion

    # If there are no Bluetooth adapters detected, report that Bluetooth is not available
    if (-not $BluetoothAdapters) {
        Write-Host -Object "[Info] Bluetooth is not available on this system. No Bluetooth adapters were detected."
        exit 0
    }

    # Bluetooth adapters were detected, so retrieve Bluetooth devices and unpair them
    # Initialize a list to hold devices to unpair
    $DevicesToUnpair = [System.Collections.Generic.List[object]]::new()

    # Retrieve Classic Bluetooth devices
    try {
        if ($UnpairAllDevices) {
            $ClassicDevices = Get-BluetoothDevices -AllDevices -ReturnBluetoothDeviceObjects -ErrorAction Stop
        }
        else {
            $ClassicDevices = Get-BluetoothDevices -ConnectedOnly -ReturnBluetoothDeviceObjects -ErrorAction Stop
        }

        # If any Classic Bluetooth devices were found, add them to the list of devices to unpair
        if ($ClassicDevices) {
            foreach ($device in $ClassicDevices) { $DevicesToUnpair.Add($device) }
        }
    }
    catch {
        Write-Host -Object "[Error] Failed to retrieve Bluetooth devices."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Retrieve Bluetooth Low Energy (BLE) devices
    try {
        if ($UnpairAllDevices) {
            $BLEDevices = Get-BluetoothLEDevices -AllDevices -ReturnBluetoothLEDeviceObjects -ErrorAction Stop
        }
        else {
            $BLEDevices = Get-BluetoothLEDevices -ConnectedOnly -ReturnBluetoothLEDeviceObjects -ErrorAction Stop
        }

        # If any BLE devices were found, add them to the list of devices to unpair
        if ($BLEDevices) {
            foreach ($device in $BLEDevices) { $DevicesToUnpair.Add($device) }
        }
    }
    catch {
        Write-Host -Object "[Error] Failed to retrieve Bluetooth Low Energy devices."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Deduplicate by Bluetooth address in case a dual-mode device appears in both Classic and BLE results
    $DevicesToUnpair = $DevicesToUnpair | Sort-Object -Property BluetoothAddress -Unique

    # Exit if there are no devices to unpair
    if (-not $DevicesToUnpair) {
        if ($UnpairAllDevices) {
            Write-Host -Object "[Info] No paired Bluetooth devices detected."
        }
        else {
            Write-Host -Object "[Info] No connected Bluetooth devices detected."
        }
        exit 0
    }

    if ($UnpairAllDevices) {
        Write-Host -Object "[Info] Found $(($DevicesToUnpair | Measure-Object).Count) paired Bluetooth device(s)."
    }
    else {
        Write-Host -Object "[Info] Found $(($DevicesToUnpair | Measure-Object).Count) connected Bluetooth device(s)."
    }
    Write-Host -Object ""

    #region Unpair Bluetooth Devices
    # Unpair each device
    foreach ($device in $DevicesToUnpair) {
        $deviceName = $device.Name
        $deviceId = $device.DeviceId

        Write-Host -Object "[Info] Unpairing Bluetooth device '$deviceName'..."

        try {
            Unpair-BluetoothDeviceById -DeviceId $deviceId -ErrorAction Stop

            # Brief wait to allow the device to fully unpair
            Start-Sleep -Seconds 2
        }
        catch {
            Write-Host -Object "[Error] Failed to unpair Bluetooth device '$deviceName' with ID '$deviceId'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        #region Verify unpair success
        # Create a new list to hold the devices present after unpairing
        $DevicesAfterUnpair = [System.Collections.Generic.List[object]]::new()

        # Re-query Bluetooth devices after unpairing to confirm removal
        try {
            if ($UnpairAllDevices) {
                $ClassicAfterUnpair = Get-BluetoothDevices -AllDevices -ReturnBluetoothDeviceObjects -ErrorAction Stop
            }
            else {
                $ClassicAfterUnpair = Get-BluetoothDevices -ConnectedOnly -ReturnBluetoothDeviceObjects -ErrorAction Stop
            }

            if ($ClassicAfterUnpair) {
                foreach ($DeviceAfterUnpair in $ClassicAfterUnpair) { $DevicesAfterUnpair.Add($DeviceAfterUnpair) }
            }
        }
        catch {
            Write-Host -Object "[Error] Failed to retrieve Bluetooth devices after unpairing to determine if the unpair was successful."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        # Retrieve Bluetooth Low Energy (BLE) devices again
        try {
            if ($UnpairAllDevices) {
                $BLEAfterUnpair = Get-BluetoothLEDevices -AllDevices -ReturnBluetoothLEDeviceObjects -ErrorAction Stop
            }
            else {
                $BLEAfterUnpair = Get-BluetoothLEDevices -ConnectedOnly -ReturnBluetoothLEDeviceObjects -ErrorAction Stop
            }

            if ($BLEAfterUnpair) {
                foreach ($DeviceAfterUnpair in $BLEAfterUnpair) { $DevicesAfterUnpair.Add($DeviceAfterUnpair) }
            }
        }
        catch {
            Write-Host -Object "[Error] Failed to retrieve Bluetooth Low Energy devices after unpairing to determine if the unpair was successful."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        # Deduplicate by Bluetooth address in case a dual-mode device appears in both Classic and BLE results
        $DevicesAfterUnpair = $DevicesAfterUnpair | Sort-Object -Property BluetoothAddress -Unique

        # If the device ID is still present after unpairing, report an error; otherwise report success
        if ($DevicesAfterUnpair.DeviceId -contains $deviceId) {
            if ($UnpairAllDevices) {
                Write-Host -Object "[Error] The Bluetooth device '$deviceName' is still present in the list of paired devices after attempting to unpair."
                Write-Host -Object "#### Paired devices still present: ####`n"
            }
            else {
                Write-Host -Object "[Error] The Bluetooth device '$deviceName' is still present in the list of connected devices after attempting to unpair."
                Write-Host -Object "#### Connected devices still present: ####`n"
            }
            ($DevicesAfterUnpair | Format-List | Out-String).Trim() | Write-Host
            $ExitCode = 1
        }
        else {
            Write-Host -Object "[Info] Successfully unpaired '$deviceName'."
        }
        #endregion

        Write-Host -Object ""
    }
    #endregion

    # If the exit code is 1 at this point, there was an error unpairing at least one device
    if ($ExitCode -eq 1) {
        Write-Host -Object "[Error] One or more Bluetooth devices failed to unpair."
    }

    exit $ExitCode
}
end {
    
    
    
}