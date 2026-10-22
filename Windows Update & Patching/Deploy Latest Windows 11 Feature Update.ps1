#Requires -Version 5.1

<#
.SYNOPSIS
    Update Windows 11 to the latest available Feature Update using the Windows 11 Install Assistant. This script does not wait for the installation assistant to complete.
.DESCRIPTION
    Update Windows 11 to the latest available Feature Update using the Windows 11 Install Assistant. This script does not wait for the installation assistant to complete.
.EXAMPLE
    (No Parameters)

    Checking https://endoflife.date/windows for the latest Windows build information.
    Parsing the response from https://endoflife.date/windows
    Retrieving the systems current Windows 11 version.
    The latest supported feature update is Windows 11 24H2 and it was released on 10/1/2024.
    The system currently has the feature update Windows 11 23H2 installed.

    Verifying the feature update compatibility.
    Successfully retrieved the compatibility results.

    Compatibility Test Result: Capable
    The upgrade is not currently in progress.

    Downloading the Windows 11 Installation Assistant executable.
    URL 'https://go.microsoft.com/fwlink/?linkid=2171764' was given.
    Downloading the file...
    Waiting for 7 seconds.
    Download Attempt 1
    Download complete.

    Verifying the executable's signature.
    The signature is valid and appears to be what was expected.

    Initiating Windows 11 feature upgrade.
    [Warning] This may take a few hours to complete. You can view the logs at 'C:\Windows\Logs\Windows11InstallAssistant' and 'C:\Program Files (x86)\WindowsInstallationAssistant\Logs' if any failure occurs.
    If no failure occurs, these files may be empty.

    ### Windows 11 Upgrade Process ###
    PID         : 2548
    Name        : Windows10UpgraderApp
    Description : Windows Installation Assistant
    Path        : C:\Program Files (x86)\WindowsInstallationAssistant\Windows10UpgraderApp.exe

.PARAMETER InstallAssistantDownloadURL
    Defines the URL from which the Windows 11 Installation Assistant will be downloaded.

.PARAMETER DownloadDestination
    Provides the destination file path where Windows11InstallationAssistant.exe should be saved.

.PARAMETER UpdateLogLocation
    Specifies the folder location where the installation assistant logs will be stored.

.PARAMETER EndOfLifeURL
    Defines the URL to the endoflife.date api.

.NOTES
    Minimum OS Architecture Supported: Windows 11, ARM and IoT editions are not supported.
    Version: 1.1
    Release Notes: Added an error for IoT editions of Windows, updated functions, set to ignore 26H1, and changed "already on latest version" from error to non-error.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$InstallAssistantDownloadURL = 'https://go.microsoft.com/fwlink/?linkid=2171764',
    [Parameter()]
    [String]$DownloadDestination = "$env:TEMP\Windows11InstallAssistant\Windows11InstallationAssistant.exe",
    [Parameter()]
    [String]$UpdateLogLocation = "$env:SYSTEMROOT\Logs\Windows11InstallAssistant",
    [Parameter()]
    [String]$EndOfLifeURL = "https://endoflife.date/api/windows.json"
)

begin {
    #region Validation

    # Check if the operating system build version is less than 22000 (Windows 11 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 22000) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 11 (22000)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Determine the method to retrieve the operating system information based on PowerShell version.
    try {
        $OS = if ($PSVersionTable.PSVersion.Major -lt 3) {
            Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
        } else {
            Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        }
    } catch {
        # If the above retrieval fails, display an error message and exit.
        Write-Host -Object "[Error] Unable to retrieve information about the current operating system."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Check if the system is running Windows 11. If not, display an error message and exit.
    if ($OS.Caption -notmatch "Windows 11") {
        Write-Host -Object "[Error] This device is not currently running Windows 11. It is currently running '$($OS.Caption)'."
        exit 1
    }

    # Check if the system is running an IoT edition of Windows. If so, display an error message and exit.
    if ($OS.Caption -match "IoT") {
        Write-Host -Object "[Error] This device is currently running an IoT edition of Windows. It is currently running '$($OS.Caption)'."
        Write-Host -Object "[Error] IoT editions are not compatible with the Windows 11 Installation Assistant."
        exit 1
    }

    # Check if the system is using an ARM processor. If so, display an error message and exit.
    if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -match "arm") {
        Write-Host -Object "[Error] This device is running an ARM version of Windows. Its architecture is currently '$([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)'."
        Write-Host -Object "[Error] ARM is currently not supported by the Windows 11 Installation Assistant: https://support.microsoft.com/en-us/topic/windows-update-assistant-3550dfb2-a015-7765-12ea-fba2ac36fb3f#id0efd=windows_11."
        exit 1
    }

    try {
        # Retrieve the volume information for the system drive (C: or equivalent).
        # Replace ":" in the drive letter environment variable to match the Get-Volume cmdlet parameter.
        $osDrive = Get-Volume -DriveLetter ($env:SystemDrive -replace ":") -ErrorAction Stop

        # If there's no remaining size property, throw an error to be caught below.
        if (!$osDrive.SizeRemaining) {
            throw "Failed to retrieve the remaining size for drive '$env:SystemDrive'."
        }

    } catch {
        # If the volume information retrieval fails, output an error message and exit.
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to get the size of the current os drive ($env:SystemDrive)."
        exit 1
    }

    # Ensure there is at least 64GB of free space on the system drive before continuing.
    if ($osDrive.SizeRemaining -lt 64GB) {
        Write-Host -Object "[Error] The current free space for the system drive '$env:SystemDrive' is $([math]::Round(($osDrive.SizeRemaining / 1GB),2)). There is not enough free space. You must have at least 64GB of free space."
        exit 1
    }

    #endregion
    #region Helper Functions

    function Get-HardwareReadiness() {
        # Modified copy of https://aka.ms/HWReadinessScript minus the signature, as of 7/26/2023.
        # Only modification was replacing Get-WmiObject with Get-CimInstance for PowerShell 7 compatibility
        # Source Microsoft article: https://techcommunity.microsoft.com/t5/microsoft-endpoint-manager-blog/understanding-readiness-for-windows-11-with-microsoft-endpoint/ba-p/2770866

        #=============================================================================================================================
        #
        # Script Name:     HardwareReadiness.ps1
        # Description:     Verifies the hardware compliance. Return code 0 for success.
        #                  In case of failure, returns non zero error code along with error message.

        # This script is not supported under any Microsoft standard support program or service and is distributed under the MIT license

        # Copyright (C) 2021 Microsoft Corporation

        # Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
        # files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
        # modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
        # is furnished to do so, subject to the following conditions:

        # The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

        # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
        # WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
        # COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
        # ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

        #=============================================================================================================================

        [int]$MinOSDiskSizeGB = 64
        [int]$MinMemoryGB = 4
        [Uint32]$MinClockSpeedMHz = 1000
        [Uint32]$MinLogicalCores = 2
        [Uint16]$RequiredAddressWidth = 64

        $PASS_STRING = "PASS"
        $FAIL_STRING = "FAIL"
        $FAILED_TO_RUN_STRING = "FAILED TO RUN"
        $UNDETERMINED_CAPS_STRING = "UNDETERMINED"
        $UNDETERMINED_STRING = "Undetermined"
        $CAPABLE_STRING = "Capable"
        $NOT_CAPABLE_STRING = "Not capable"
        $CAPABLE_CAPS_STRING = "CAPABLE"
        $NOT_CAPABLE_CAPS_STRING = "NOT CAPABLE"
        $STORAGE_STRING = "Storage"
        $OS_DISK_SIZE_STRING = "OSDiskSize"
        $MEMORY_STRING = "Memory"
        $SYSTEM_MEMORY_STRING = "System_Memory"
        $GB_UNIT_STRING = "GB"
        $TPM_STRING = "TPM"
        $TPM_VERSION_STRING = "TPMVersion"
        $PROCESSOR_STRING = "Processor"
        $SECUREBOOT_STRING = "SecureBoot"
        $I7_7820HQ_CPU_STRING = "i7-7820hq CPU"

        # 0=name of check, 1=attribute checked, 2=value, 3=PASS/FAIL/UNDETERMINED
        $logFormat = '{0}: {1}={2}. {3}; '

        # 0=name of check, 1=attribute checked, 2=value, 3=unit of the value, 4=PASS/FAIL/UNDETERMINED
        $logFormatWithUnit = '{0}: {1}={2}{3}. {4}; '

        # 0=name of check.
        $logFormatReturnReason = '{0}, '

        # 0=exception.
        $logFormatException = '{0}; '

        # 0=name of check, 1= attribute checked and its value, 2=PASS/FAIL/UNDETERMINED
        $logFormatWithBlob = '{0}: {1}. {2}; '

        # return returnCode is -1 when an exception is thrown. 1 if the value does not meet requirements. 0 if successful. -2 default, script didn't run.
        $outObject = @{ returnCode = -2; returnResult = $FAILED_TO_RUN_STRING; returnReason = ""; logging = "" }

        # NOT CAPABLE(1) state takes precedence over UNDETERMINED(-1) state
        function Private:UpdateReturnCode {
            param(
                [Parameter(Mandatory = $true)]
                [ValidateRange(-2, 1)]
                [int] $ReturnCode
            )

            switch ($ReturnCode) {

                0 {
                    if ($outObject.returnCode -eq -2) {
                        $outObject.returnCode = $ReturnCode
                    }
                }
                1 {
                    $outObject.returnCode = $ReturnCode
                }
                -1 {
                    if ($outObject.returnCode -ne 1) {
                        $outObject.returnCode = $ReturnCode
                    }
                }
            }
        }

        $Source = @"
using Microsoft.Win32;
using System;
using System.Runtime.InteropServices;

    public class CpuFamilyResult
    {
        public bool IsValid { get; set; }
        public string Message { get; set; }
    }

    public class CpuFamily
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct SYSTEM_INFO
        {
            public ushort ProcessorArchitecture;
            ushort Reserved;
            public uint PageSize;
            public IntPtr MinimumApplicationAddress;
            public IntPtr MaximumApplicationAddress;
            public IntPtr ActiveProcessorMask;
            public uint NumberOfProcessors;
            public uint ProcessorType;
            public uint AllocationGranularity;
            public ushort ProcessorLevel;
            public ushort ProcessorRevision;
        }

        [DllImport("kernel32.dll")]
        internal static extern void GetNativeSystemInfo(ref SYSTEM_INFO lpSystemInfo);

        public enum ProcessorFeature : uint
        {
            ARM_SUPPORTED_INSTRUCTIONS = 34
        }

        [DllImport("kernel32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool IsProcessorFeaturePresent(ProcessorFeature processorFeature);

        private const ushort PROCESSOR_ARCHITECTURE_X86 = 0;
        private const ushort PROCESSOR_ARCHITECTURE_ARM64 = 12;
        private const ushort PROCESSOR_ARCHITECTURE_X64 = 9;

        private const string INTEL_MANUFACTURER = "GenuineIntel";
        private const string AMD_MANUFACTURER = "AuthenticAMD";
        private const string QUALCOMM_MANUFACTURER = "Qualcomm Technologies Inc";

        public static CpuFamilyResult Validate(string manufacturer, ushort processorArchitecture)
        {
            CpuFamilyResult cpuFamilyResult = new CpuFamilyResult();

            if (string.IsNullOrWhiteSpace(manufacturer))
            {
                cpuFamilyResult.IsValid = false;
                cpuFamilyResult.Message = "Manufacturer is null or empty";
                return cpuFamilyResult;
            }

            string registryPath = "HKEY_LOCAL_MACHINE\\Hardware\\Description\\System\\CentralProcessor\\0";
            SYSTEM_INFO sysInfo = new SYSTEM_INFO();
            GetNativeSystemInfo(ref sysInfo);

            switch (processorArchitecture)
            {
                case PROCESSOR_ARCHITECTURE_ARM64:

                    if (manufacturer.Equals(QUALCOMM_MANUFACTURER, StringComparison.OrdinalIgnoreCase))
                    {
                        bool isArmv81Supported = IsProcessorFeaturePresent(ProcessorFeature.ARM_SUPPORTED_INSTRUCTIONS);

                        if (!isArmv81Supported)
                        {
                            string registryName = "CP 4030";
                            long registryValue = (long)Registry.GetValue(registryPath, registryName, -1);
                            long atomicResult = (registryValue >> 20) & 0xF;

                            if (atomicResult >= 2)
                            {
                                isArmv81Supported = true;
                            }
                        }

                        cpuFamilyResult.IsValid = isArmv81Supported;
                        cpuFamilyResult.Message = isArmv81Supported ? "" : "Processor does not implement ARM v8.1 atomic instruction";
                    }
                    else
                    {
                        cpuFamilyResult.IsValid = false;
                        cpuFamilyResult.Message = "The processor isn't currently supported for Windows 11";
                    }

                    break;

                case PROCESSOR_ARCHITECTURE_X64:
                case PROCESSOR_ARCHITECTURE_X86:

                    int cpuFamily = sysInfo.ProcessorLevel;
                    int cpuModel = (sysInfo.ProcessorRevision >> 8) & 0xFF;
                    int cpuStepping = sysInfo.ProcessorRevision & 0xFF;

                    if (manufacturer.Equals(INTEL_MANUFACTURER, StringComparison.OrdinalIgnoreCase))
                    {
                        try
                        {
                            cpuFamilyResult.IsValid = true;
                            cpuFamilyResult.Message = "";

                            if (cpuFamily >= 6 && cpuModel <= 95 && !(cpuFamily == 6 && cpuModel == 85))
                            {
                                cpuFamilyResult.IsValid = false;
                                cpuFamilyResult.Message = "";
                            }
                            else if (cpuFamily == 6 && (cpuModel == 142 || cpuModel == 158) && cpuStepping == 9)
                            {
                                string registryName = "Platform Specific Field 1";
                                int registryValue = (int)Registry.GetValue(registryPath, registryName, -1);

                                if ((cpuModel == 142 && registryValue != 16) || (cpuModel == 158 && registryValue != 8))
                                {
                                    cpuFamilyResult.IsValid = false;
                                }
                                cpuFamilyResult.Message = "PlatformId " + registryValue;
                            }
                        }
                        catch (Exception ex)
                        {
                            cpuFamilyResult.IsValid = false;
                            cpuFamilyResult.Message = "Exception:" + ex.GetType().Name;
                        }
                    }
                    else if (manufacturer.Equals(AMD_MANUFACTURER, StringComparison.OrdinalIgnoreCase))
                    {
                        cpuFamilyResult.IsValid = true;
                        cpuFamilyResult.Message = "";

                        if (cpuFamily < 23 || (cpuFamily == 23 && (cpuModel == 1 || cpuModel == 17)))
                        {
                            cpuFamilyResult.IsValid = false;
                        }
                    }
                    else
                    {
                        cpuFamilyResult.IsValid = false;
                        cpuFamilyResult.Message = "Unsupported Manufacturer: " + manufacturer + ", Architecture: " + processorArchitecture + ", CPUFamily: " + sysInfo.ProcessorLevel + ", ProcessorRevision: " + sysInfo.ProcessorRevision;
                    }

                    break;

                default:
                    cpuFamilyResult.IsValid = false;
                    cpuFamilyResult.Message = "Unsupported CPU category. Manufacturer: " + manufacturer + ", Architecture: " + processorArchitecture + ", CPUFamily: " + sysInfo.ProcessorLevel + ", ProcessorRevision: " + sysInfo.ProcessorRevision;
                    break;
            }
            return cpuFamilyResult;
        }
    }
"@

        # Storage
        try {
            $osDrive = Get-CimInstance -Class Win32_OperatingSystem | Select-Object -Property SystemDrive
            $osDriveSize = Get-CimInstance -Class Win32_LogicalDisk -Filter "DeviceID='$($osDrive.SystemDrive)'" | Select-Object @{Name = "SizeGB"; Expression = { $_.Size / 1GB -as [int] } }

            if ($null -eq $osDriveSize) {
                UpdateReturnCode -ReturnCode 1
                $outObject.returnReason += $logFormatReturnReason -f $STORAGE_STRING
                $outObject.logging += $logFormatWithBlob -f $STORAGE_STRING, "Storage is null", $FAIL_STRING

            } elseif ($osDriveSize.SizeGB -lt $MinOSDiskSizeGB) {
                UpdateReturnCode -ReturnCode 1
                $outObject.returnReason += $logFormatReturnReason -f $STORAGE_STRING
                $outObject.logging += $logFormatWithUnit -f $STORAGE_STRING, $OS_DISK_SIZE_STRING, ($osDriveSize.SizeGB), $GB_UNIT_STRING, $FAIL_STRING
            } else {
                $outObject.logging += $logFormatWithUnit -f $STORAGE_STRING, $OS_DISK_SIZE_STRING, ($osDriveSize.SizeGB), $GB_UNIT_STRING, $PASS_STRING
                UpdateReturnCode -ReturnCode 0
            }
        } catch {
            UpdateReturnCode -ReturnCode -1
            $outObject.logging += $logFormat -f $STORAGE_STRING, $OS_DISK_SIZE_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
            $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"
        }

        # Memory (bytes)
        try {
            $memory = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum | Select-Object @{Name = "SizeGB"; Expression = { $_.Sum / 1GB -as [int] } }

            if ($null -eq $memory) {
                UpdateReturnCode -ReturnCode 1
                $outObject.returnReason += $logFormatReturnReason -f $MEMORY_STRING
                $outObject.logging += $logFormatWithBlob -f $MEMORY_STRING, "Memory is null", $FAIL_STRING
            } elseif ($memory.SizeGB -lt $MinMemoryGB) {
                UpdateReturnCode -ReturnCode 1
                $outObject.returnReason += $logFormatReturnReason -f $MEMORY_STRING
                $outObject.logging += $logFormatWithUnit -f $MEMORY_STRING, $SYSTEM_MEMORY_STRING, ($memory.SizeGB), $GB_UNIT_STRING, $FAIL_STRING
            } else {
                $outObject.logging += $logFormatWithUnit -f $MEMORY_STRING, $SYSTEM_MEMORY_STRING, ($memory.SizeGB), $GB_UNIT_STRING, $PASS_STRING
                UpdateReturnCode -ReturnCode 0
            }
        } catch {
            UpdateReturnCode -ReturnCode -1
            $outObject.logging += $logFormat -f $MEMORY_STRING, $SYSTEM_MEMORY_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
            $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"
        }

        # TPM
        try {
            $tpm = Get-Tpm

            if ($null -eq $tpm) {
                UpdateReturnCode -ReturnCode 1
                $outObject.returnReason += $logFormatReturnReason -f $TPM_STRING
                $outObject.logging += $logFormatWithBlob -f $TPM_STRING, "TPM is null", $FAIL_STRING
            } elseif ($tpm.TpmPresent) {
                $tpmVersion = Get-CimInstance -Class Win32_Tpm -Namespace root\CIMV2\Security\MicrosoftTpm | Select-Object -Property SpecVersion

                if ($null -eq $tpmVersion.SpecVersion) {
                    UpdateReturnCode -ReturnCode 1
                    $outObject.returnReason += $logFormatReturnReason -f $TPM_STRING
                    $outObject.logging += $logFormat -f $TPM_STRING, $TPM_VERSION_STRING, "null", $FAIL_STRING
                }

                $majorVersion = $tpmVersion.SpecVersion.Split(",")[0] -as [int]
                if ($majorVersion -lt 2) {
                    UpdateReturnCode -ReturnCode 1
                    $outObject.returnReason += $logFormatReturnReason -f $TPM_STRING
                    $outObject.logging += $logFormat -f $TPM_STRING, $TPM_VERSION_STRING, ($tpmVersion.SpecVersion), $FAIL_STRING

                } else {
                    $outObject.logging += $logFormat -f $TPM_STRING, $TPM_VERSION_STRING, ($tpmVersion.SpecVersion), $PASS_STRING
                    UpdateReturnCode -ReturnCode 0
                }
            } else {
                if ($tpm.GetType().Name -eq "String") {
                    UpdateReturnCode -ReturnCode -1
                    $outObject.logging += $logFormat -f $TPM_STRING, $TPM_VERSION_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
                    $outObject.logging += $logFormatException -f $tpm
                } else {
                    UpdateReturnCode -ReturnCode 1
                    $outObject.returnReason += $logFormatReturnReason -f $TPM_STRING
                    $outObject.logging += $logFormat -f $TPM_STRING, $TPM_VERSION_STRING, ($tpm.TpmPresent), $FAIL_STRING
                }

            }
        } catch {
            UpdateReturnCode -ReturnCode -1
            $outObject.logging += $logFormat -f $TPM_STRING, $TPM_VERSION_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
            $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"
        }

        # CPU Details
        $cpuDetails;
        try {
            $cpuDetails = @(Get-CimInstance -Class Win32_Processor)[0]

            if ($null -eq $cpuDetails) {
                UpdateReturnCode -ReturnCode 1

                $outObject.returnReason += $logFormatReturnReason -f $PROCESSOR_STRING
                $outObject.logging += $logFormatWithBlob -f $PROCESSOR_STRING, "CpuDetails is null", $FAIL_STRING
            } else {
                $processorCheckFailed = $false

                # AddressWidth
                if ($null -eq $cpuDetails.AddressWidth -or $cpuDetails.AddressWidth -ne $RequiredAddressWidth) {
                    UpdateReturnCode -ReturnCode 1
                    $processorCheckFailed = $true
                }

                # ClockSpeed is in MHz
                if ($null -eq $cpuDetails.MaxClockSpeed -or $cpuDetails.MaxClockSpeed -le $MinClockSpeedMHz) {
                    UpdateReturnCode -ReturnCode 1;
                    $processorCheckFailed = $true
                }

                # Number of Logical Cores
                if ($null -eq $cpuDetails.NumberOfLogicalProcessors -or $cpuDetails.NumberOfLogicalProcessors -lt $MinLogicalCores) {
                    UpdateReturnCode -ReturnCode 1
                    $processorCheckFailed = $true
                }

                # CPU Family
                Add-Type -TypeDefinition $Source
                $cpuFamilyResult = [CpuFamily]::Validate([String]$cpuDetails.Manufacturer, [uint16]$cpuDetails.Architecture)

                $cpuDetailsLog = "{AddressWidth=$($cpuDetails.AddressWidth); MaxClockSpeed=$($cpuDetails.MaxClockSpeed); NumberOfLogicalCores=$($cpuDetails.NumberOfLogicalProcessors); Manufacturer=$($cpuDetails.Manufacturer); Caption=$($cpuDetails.Caption); $($cpuFamilyResult.Message)}"

                if (!$cpuFamilyResult.IsValid) {
                    UpdateReturnCode -ReturnCode 1
                    $processorCheckFailed = $true

                }

                if ($processorCheckFailed) {
                    $outObject.returnReason += $logFormatReturnReason -f $PROCESSOR_STRING
                    $outObject.logging += $logFormatWithBlob -f $PROCESSOR_STRING, ($cpuDetailsLog), $FAIL_STRING
                } else {
                    $outObject.logging += $logFormatWithBlob -f $PROCESSOR_STRING, ($cpuDetailsLog), $PASS_STRING
                    UpdateReturnCode -ReturnCode 0
                }
            }
        } catch {
            UpdateReturnCode -ReturnCode -1
            $outObject.logging += $logFormat -f $PROCESSOR_STRING, $PROCESSOR_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
            $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"
        }

        # SecureBoot
        try {
            $isSecureBootEnabled = Confirm-SecureBootUEFI
            $outObject.logging += $logFormatWithBlob -f $SECUREBOOT_STRING, $CAPABLE_STRING, $PASS_STRING
            UpdateReturnCode -ReturnCode 0
        } catch [System.PlatformNotSupportedException] {
            # PlatformNotSupportedException "Cmdlet not supported on this platform." - SecureBoot is not supported or is non-UEFI computer.
            UpdateReturnCode -ReturnCode 1
            $outObject.returnReason += $logFormatReturnReason -f $SECUREBOOT_STRING
            $outObject.logging += $logFormatWithBlob -f $SECUREBOOT_STRING, $NOT_CAPABLE_STRING, $FAIL_STRING
        } catch [System.UnauthorizedAccessException] {
            UpdateReturnCode -ReturnCode -1
            $outObject.logging += $logFormatWithBlob -f $SECUREBOOT_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
            $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"
        } catch {
            UpdateReturnCode -ReturnCode -1
            $outObject.logging += $logFormatWithBlob -f $SECUREBOOT_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
            $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"
        }

        # i7-7820hq CPU
        try {
            $supportedDevices = @('surface studio 2', 'precision 5520')
            $systemInfo = @(Get-CimInstance -Class Win32_ComputerSystem)[0]

            if ($null -ne $cpuDetails) {
                if ($cpuDetails.Name -match 'i7-7820hq cpu @ 2.90ghz') {
                    $modelOrSKUCheckLog = $systemInfo.Model.Trim()
                    if ($supportedDevices -contains $modelOrSKUCheckLog) {
                        $outObject.logging += $logFormatWithBlob -f $I7_7820HQ_CPU_STRING, $modelOrSKUCheckLog, $PASS_STRING
                        $outObject.returnCode = 0
                    }
                }
            }
        } catch {
            if ($outObject.returnCode -ne 0) {
                UpdateReturnCode -ReturnCode -1
                $outObject.logging += $logFormatWithBlob -f $I7_7820HQ_CPU_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
                $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"

            }
        }

        switch ($outObject.returnCode) {

            0 { $outObject.returnResult = $CAPABLE_CAPS_STRING }
            1 { $outObject.returnResult = $NOT_CAPABLE_CAPS_STRING }
            -1 { $outObject.returnResult = $UNDETERMINED_CAPS_STRING }
            -2 { $outObject.returnResult = $FAILED_TO_RUN_STRING }
        }

        $outObject | ConvertTo-Json -Compress
    }

    # Utility function for downloading files.
    function Invoke-Download {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $True)]
            [System.Uri]$URL,
            [Parameter(Mandatory = $True)]
            [String]$Path,
            [Parameter()]
            [int]$Attempts = 3,
            [Parameter()]
            [Switch]$SkipSleep,
            [Parameter()]
            [Switch]$Overwrite,
            [Parameter()]
            [ValidateSet("Chrome", "Edge", "Firefox", "Firefox ESR", "Safari", "InternetExplorer", "Opera")]
            [String]$UserAgent,
            [Parameter()]
            [Switch]$Quiet
        )

        # Determine the supported TLS versions and set the appropriate security protocol
        # Prefer Tls13 and Tls12 if both are available, otherwise just Tls12, or warn if unsupported.
        $SupportedTLSversions = [enum]::GetValues('Net.SecurityProtocolType')
        if ( ($SupportedTLSversions -contains 'Tls13') -and ($SupportedTLSversions -contains 'Tls12') ) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol::Tls13 -bor [System.Net.SecurityProtocolType]::Tls12
        } elseif ( $SupportedTLSversions -contains 'Tls12' ) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        } else {
            # Warn the user if TLS 1.2 and 1.3 are not supported, which may cause the download to fail
            Write-Host -Object "[Warning] TLS 1.2 and/or TLS 1.3 are not supported on this system. This download may fail!"
            if ($PSVersionTable.PSVersion.Major -lt 3) {
                Write-Host -Object "[Warning] PowerShell 2 / .NET 2.0 doesn't support TLS 1.2."
            }
        }

        # Trim whitespace from the URL and Path parameters.
        if ($Path) { $Path = $Path.Trim() }

        # Throw an error if no URL or Path was provided.
        if (!$URL) {
            Write-Error -Category InvalidArgument -Exception (New-Object System.ArgumentNullException("You must provide a URL."))
            return
        }
        if (!$Path) {
            Write-Error -Category InvalidArgument -Exception (New-Object System.ArgumentNullException("You must provide a file path."))
            return
        }

        # If the URL doesn't start with http or https, prepend https.
        if ($URL -notmatch "^http") {
            try {
                $URL = [System.Uri]"https://$URL"
            } catch {
                Write-Error -Category InvalidArgument -Exception (New-Object System.UriFormatException("The URL '$($URL.OriginalString)' is not valid. Please ensure it starts with http:// or https:// and is properly formatted."))
                return
            }
            Write-Host -Object "[Warning] The URL given is missing http(s). The URL has been modified to the following: '$($URL.AbsoluteUri)'."
        } elseif (-not $Quiet) {
            # Display the URL being used for the download.
            Write-Host -Object "URL '$($URL.AbsoluteUri)' was given."
        }

        # Check if the path contains invalid characters or reserved characters after the drive letter.
        if ($Path -and ($Path -match '[/*?"<>|]' -or ($Path.Length -ge 2 -and $Path.Substring(2) -match "[:]"))) {
            Write-Error -Category InvalidArgument -Exception (New-Object System.ArgumentException("The file path specified '$Path' contains one of the following invalid characters: '/*?`"<>|:'"))
            return
        }

        # Check each folder in the path to ensure it isn't a reserved name (CON, PRN, AUX, etc.).
        $Path -split '\\' | ForEach-Object {
            $Folder = ($_).Trim()
            if ($Folder -match '^(CON|PRN|AUX|NUL)$' -or $Folder -match '^(LPT|COM)\d+$') {
                Write-Error -Category InvalidArgument -Exception (New-Object System.ArgumentException("An invalid folder name was given in '$Path'. The following folder names are reserved: CON, PRN, AUX, NUL, COM1-9, LPT1-9"))
                return
            }
        }

        # Temporarily disable progress reporting to speed up script performance
        $PreviousProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        # If no filename is included in the path (no extension), try to determine it from Content-Disposition.
        if (($Path | Split-Path -Leaf) -notmatch "[.]") {

            if (-not $Quiet) { Write-Host -Object "No filename provided in '$Path'. Checking the URL for a suitable filename." }

            $AbsolutePath = $URL.AbsolutePath

            # If the AbsolutePath is not blank or a slash, attempt to extract the filename from the OriginalString of the URL.
            if ($AbsolutePath -ne "/" -and $AbsolutePath -ne "") {
                $ProposedFilename = Split-Path $URL.OriginalString -Leaf
            }

            # Verify that the proposed filename doesn't contain invalid characters.
            if ($ProposedFilename -and $ProposedFilename -notmatch "[^A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]" -and $ProposedFilename -match "[.]") {
                $Filename = $ProposedFilename
            }

            # If running on older PowerShell versions without Invoke-WebRequest require a filename.
            if ($PSVersionTable.PSVersion.Major -lt 4) {
                # Restore the original progress preference setting
                $ProgressPreference = $PreviousProgressPreference

                Write-Error -Category NotImplemented -Exception (New-Object System.ArgumentException("You must provide a filename for systems not running PowerShell 4 or higher."))
                return
            }

            if (!$Filename) {
                if (-not $Quiet) { Write-Host -Object "No filename was discovered in the URL. Attempting to discover the filename via the Content-Disposition header." }
                $Request = 1

                # Make multiple attempts (as defined by $Attempts) to retrieve the Content-Disposition header.
                while ($Request -le $Attempts) {
                    # If SkipSleep is not set, wait for a random time between 3 and 15 seconds before each attempt
                    if (!($SkipSleep)) {
                        $SleepTime = Get-Random -Minimum 3 -Maximum 15
                        if (-not $Quiet) { Write-Host -Object "Waiting for $SleepTime seconds." }
                        Start-Sleep -Seconds $SleepTime
                    }

                    if ($Request -ne 1 -and -not $Quiet) { Write-Host "" }
                    if (-not $Quiet) { Write-Host -Object "Attempt $Request" }

                    # Perform a HEAD request to get headers only.
                    # If the HEAD request fails, print a warning.
                    try {
                        $HeaderRequest = Invoke-WebRequest -Uri $URL -Method "HEAD" -MaximumRedirection 10 -UseBasicParsing -ErrorAction Stop
                    } catch {
                        Write-Host -Object "[Warning] $($_.Exception.Message)"
                        Write-Host -Object "[Warning] The header request failed."
                    }

                    # Check if the Content-Disposition header is present.
                    # If present, parse it to extract the filename.
                    if (!$HeaderRequest.Headers."Content-Disposition") {
                        Write-Host -Object "[Warning] The web server did not provide a Content-Disposition header."
                    } else {
                        $Content = [System.Net.Mime.ContentDisposition]::new($HeaderRequest.Headers."Content-Disposition")
                        $Filename = $Content.FileName
                    }

                    # If a filename was found, break out of the loop.
                    if ($Filename) {
                        $Request = $Attempts
                    }

                    $Request++
                }
            }

            # If a filename is still not found, throw an error.
            if ($Filename) {
                $Path = "$Path\$Filename"
            } else {
                # Restore the original progress preference setting
                $ProgressPreference = $PreviousProgressPreference

                Write-Error -Category ObjectNotFound -Exception (New-Object System.IO.FileNotFoundException("Unable to find a suitable filename from the URL."))
                return
            }
        }

        # If the file already exists at the specified path, restore the progress setting and throw an error.
        if ((Test-Path -Path $Path -ErrorAction SilentlyContinue) -and !$Overwrite) {
            # Restore the original progress preference setting
            $ProgressPreference = $PreviousProgressPreference

            Write-Error -Category ResourceExists -Exception (New-Object System.IO.IOException("A file already exists at the path '$Path'."))
            return
        }

        # Remove any extra slashes from the path.
        $Path = $Path -replace '\\+', '\'

        # Ensure that the destination folder exists, if not, try to create it.
        $DestinationFolder = $Path | Split-Path
        if (!(Test-Path -Path $DestinationFolder -ErrorAction SilentlyContinue)) {
            try {
                if (-not $Quiet) { Write-Host -Object "Attempting to create the folder '$DestinationFolder' as it does not exist." }
                New-Item -Path $DestinationFolder -ItemType "directory" -ErrorAction Stop | Out-Null
                if (-not $Quiet) { Write-Host -Object "Successfully created the folder." }
            } catch {
                # Restore the original progress preference setting
                $ProgressPreference = $PreviousProgressPreference

                $_ | Write-Error
                return
            }
        }

        # Determine the user agent string based on the provided UserAgent parameter
        if ($UserAgent) {
            $UserAgentString = switch ($UserAgent) {
                "Chrome" {
                    "Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) AppleWebKit/534.6 (KHTML, like Gecko) Chrome/7.0.500.0 Safari/534.6"
                }
                "Edge" {
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36 Edg/139.0.3405.86"
                }
                "Firefox" {
                    "Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) Gecko/20100401 Firefox/4.0"
                }
                "Firefox ESR" {
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0"
                }
                "InternetExplorer" {
                    "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT; Windows NT 10.0; en-US)"
                }
                "Opera" {
                    "Opera/9.70 (Windows NT; Windows NT 10.0; en-US) Presto/2.2.1"
                }
                "Safari" {
                    "Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) AppleWebKit/533.16 (KHTML, like Gecko) Version/5.0 Safari/533.16"
                }
            }
        }

        if (-not $Quiet) { Write-Host -Object "Downloading the file..." }

        # Initialize the download attempt counter.
        $DownloadAttempt = 1
        while ($DownloadAttempt -le $Attempts) {
            # If SkipSleep is not set, wait for a random time between 3 and 15 seconds before each attempt
            if (!($SkipSleep)) {
                $SleepTime = Get-Random -Minimum 3 -Maximum 15
                if (-not $Quiet) { Write-Host -Object "Waiting for $SleepTime seconds." }
                Start-Sleep -Seconds $SleepTime
            }

            # Provide a visual break between attempts
            if ($DownloadAttempt -ne 1 -and -not $Quiet) { Write-Host "" }
            if (-not $Quiet) { Write-Host -Object "Download Attempt $DownloadAttempt" }

            try {
                if ($PSVersionTable.PSVersion.Major -lt 4) {
                    # For older versions of PowerShell, use WebClient to download the file
                    $WebClient = New-Object System.Net.WebClient

                    # Set the user agent if requested
                    if ($UserAgent) {
                        $WebClient.Headers.Add("User-Agent", $UserAgentString)
                    }

                    # Download the file
                    $WebClient.DownloadFile($URL, $Path)
                } else {
                    # For PowerShell 4.0 and above, use Invoke-WebRequest with specified arguments
                    $WebRequestArgs = @{
                        Uri                = $URL
                        OutFile            = $Path
                        MaximumRedirection = 10
                        UseBasicParsing    = $true
                    }

                    # Set the user agent if requested
                    if ($UserAgent) {
                        $WebRequestArgs.Add("UserAgent", $UserAgentString)
                    }

                    Invoke-WebRequest @WebRequestArgs
                }

                # Verify if the file was successfully downloaded
                $File = Test-Path -Path $Path -ErrorAction SilentlyContinue
            } catch {
                # Handle any errors that occur during the download attempt
                Write-Host -Object "[Warning] An error has occurred while downloading!"
                Write-Host -Object "[Warning] $($_.Exception.Message)"

                # If the file partially downloaded, delete it to avoid corruption
                if (Test-Path -Path $Path -ErrorAction SilentlyContinue) {
                    Remove-Item $Path -Force -Confirm:$false -ErrorAction SilentlyContinue
                }

                $File = $False
            }

            # If the file was successfully downloaded, exit the loop
            if ($File) {
                $DownloadAttempt = $Attempts
            } elseif ($DownloadAttempts -ne ($Attempts - 1)) {
                # Warn the user if the download attempt failed and there are remaining attempts
                Write-Host -Object "[Warning] File failed to download. Retrying...`n"
            }

            # Increment the attempt counter
            $DownloadAttempt++
        }

        # Restore the original progress preference setting
        $ProgressPreference = $PreviousProgressPreference

        # Final check: if the file still doesn't exist, report an error and exit
        if (!(Test-Path $Path)) {
            Write-Error -Category ObjectNotFound -Exception (New-Object System.IO.FileNotFoundException("Failed to download file. Please verify the URL of '$URL'."))
            return
        } else {
            # If the download succeeded, return the path to the downloaded file
            return $Path
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

    #endregion

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    # Attempt to determine if the current session is running with Administrator privileges.
    try {
        $IsElevated = Test-IsElevated -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running this script in an elevated session."
        exit 1
    }

    if (!$IsElevated) {
        Write-Host -Object "[Error] The user '$env:USERNAME' is not running this script in an elevated session. Please run this script as System or in an elevated session."
        exit 1
    }

    #region Update Availability
    # Inform the user about the URL being checked
    Write-Host -Object "Checking https://endoflife.date/windows for the latest Windows build information."
    try {
        # Invoke a REST call to retrieve JSON data about Windows builds
        $EndOfLifeResponse = Invoke-RestMethod -Method Get -Uri $EndOfLifeURL -ContentType "application/json" -MaximumRedirection 10 -UseBasicParsing -ErrorAction Stop

        # Filter the JSON response for Windows 11 builds (cycles that match '11-' and end in 'w')
        $Windows11BuildJSON = $EndOfLifeResponse | Where-Object { $_.Cycle -match '^11-' -and $_.Cycle -match "w$" -and $_.Cycle -notmatch "-26h1-" }

        # Throw an error if no Windows 11 builds are found
        if (!$Windows11BuildJSON) {
            throw "No Windows 11 builds found in the response."
        }
    } catch {
        # Catch any errors from the REST call or the filtering process
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve the latest Windows build information from $EndOfLifeURL."
        exit 1
    }

    # Inform the user that the response will be parsed
    Write-Host -Object "Parsing the response from https://endoflife.date/windows"

    # Create a list to store all relevant Windows 11 build information
    $Windows11Builds = New-Object System.Collections.Generic.List[Object]

    $ErrorActionPreference = "Stop"

    # Iterate through each Windows 11 build JSON object
    $Windows11BuildJSON | ForEach-Object {
        try {
            # Extract major, minor, and build numbers from the 'latest' version string
            $Major = $_.latest -replace '^(\d+)\.(\d+)\.(\d+)$', '$1'
            $Minor = $_.latest -replace '^(\d+)\.(\d+)\.(\d+)$', '$2'
            $Build = $_.latest -replace '^(\d+)\.(\d+)\.(\d+)$', '$3'

            # Construct a custom PowerShell object for each build
            $WindowBuild = [PSCustomObject]@{
                cycle        = $_.cycle
                releaseLabel = $_.releaseLabel
                releaseDate  = Get-Date $_.releaseDate
                eol          = Get-Date $_.eol
                version      = $_.latest
                major        = $Major
                minor        = $Minor
                build        = $Build
                link         = $_.link
                lts          = $_.lts
                support      = Get-Date $_.support
            }

            # Add the newly created object to the Windows 11 builds collection
            $Windows11Builds.Add($WindowBuild)
        } catch {
            # Capture any errors in parsing the date or version properties
            Write-Host -Object "[Warning] $($_.Exception.Message)"
            Write-Host -Object "[Warning] Failed to parse the date for the build $($_.releaseLabel)."
            return
        }
    }

    $ErrorActionPreference = "Continue"

    # If no Windows 11 builds were successfully parsed, show an error and exit
    if ($Windows11Builds.Count -lt 1) {
        Write-Host -Object "[Error] Failed to parse any of the Windows 11 builds."
        exit 1
    }

    # Retrieve the current Windows 11 version from the system's registry
    Write-Host -Object "Retrieving the system's current Windows 11 version."
    try {
        $CurrentVersion = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop | Select-Object -ExpandProperty DisplayVersion -ErrorAction SilentlyContinue
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve the latest feature update installed."
        exit 1
    }

    # Sort the Windows 11 build objects by release date in descending order
    $Windows11Builds = $Windows11Builds | Sort-Object releaseDate -Descending

    # Retrieve the first (newest) build from the sorted list
    $LatestBuild = $Windows11Builds | Select-Object -First 1

    # Display information about the latest supported Windows 11 feature update
    Write-Host -Object "The latest supported feature update is Windows $(($LatestBuild.releaseLabel -replace '\(W\)').Trim()) and it was released on $($LatestBuild.releaseDate.ToShortDateString())."
    Write-Host -Object "The system currently has the feature update Windows 11 $CurrentVersion installed."

    # Compare the running system's build number to the newest build's number
    if ([System.Environment]::OSVersion.Version.Build -ge $LatestBuild.build) {
        Write-Host -Object "The system is already running the same or a newer feature update than the latest supported version."
        exit $ExitCode
    }

    #endregion
    #region Assess Compatibility

    try {
        # Temporarily set the ErrorActionPreference to "Stop" so that any errors are caught as exceptions.
        $ErrorActionPreference = "Stop"

        Write-Host -Object "`nVerifying the feature update compatibility."

        # Retrieve hardware readiness data, convert the JSON results into a PowerShell object.
        $Result = Get-HardwareReadiness | Select-Object -Unique | ConvertFrom-Json
        Write-Host -Object "Successfully retrieved the compatibility results.`n"

        # Reset the ErrorActionPreference to default ("Continue") so that non-terminating errors don't stop the script.
        $ErrorActionPreference = "Continue"
    } catch {
        # If any error occurs while fetching hardware readiness, display error messages and exit.
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve the compatibility results."
        exit 1
    }

    # Based on the returnCode property in the JSON result, evaluate the device's compatibility.
    switch ($Result.returnCode) {
        0 {
            $ResultString = "Capable"
        }
        1 {
            $ResultString = "[Alert] Not capable"
            $Incompatible = $True
        }
        -2 {
            $ResultString = "[Error] Failed to run"
            $Incompatible = $True
        }
        default {
            $ResultString = "[Error] Undetermined"
            $Incompatible = $True
        }
    }

    # If there's a more detailed reason for incompatibility, append it to the result string.
    if ($Result.returnReason) {
        $ResultString = "$ResultString - $($Result.returnReason)"

        # This removes any trailing commas or spaces at the end if they exist.
        $ResultString = $ResultString -replace ",\s*$"
    }

    Write-Host -Object "Compatibility Test Result: $ResultString"

    # If the system is flagged as incompatible, display an error and exit.
    if ($Incompatible) {
        Write-Host -Object "[Error] This device is either incompatible with the feature update or its compatibility could not be determined."
        exit 1
    }

    #endregion
    #region Download Assistant

    # Check if the Windows 11 Upgrade process is already running.
    $Windows11UpgradeApp = Get-Process -Name "Windows10UpgraderApp" -ErrorAction SilentlyContinue

    if (!$Windows11UpgradeApp) {
        # No upgrade process is detected.
        Write-Host -Object "The upgrade is not currently in progress."
    } else {
        # If found, display an error with information on the process and exit.
        Write-Host -Object "[Error] The Windows 11 upgrade is already in progress via the process below."
        Write-Host -Object "`n### Windows 11 Upgrade Process ###"
        ($Windows11UpgradeApp | Select-Object @{ Name = 'PID'; Expression = { $_.Id } }, Name, Description, Path |
            Format-List PID, Name, Description, Path | Out-String).Trim() | Write-Host
        exit 1
    }

    Write-Host -Object "`nDownloading the Windows 11 Installation Assistant executable."
    try {
        $WindowsInstallAssistant = Invoke-Download -Path $DownloadDestination -URL $InstallAssistantDownloadURL -Overwrite -ErrorAction Stop
        Write-Host -Object "Download complete."
    } catch {
        # If the download fails, display an error message and exit.
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to download the Windows 11 Installation Assistant at '$InstallAssistantDownloadURL'."
        exit 1
    }

    Write-Host -Object "`nVerifying the executable's signature."
    try {
        # Check the digital signature of the downloaded executable to ensure authenticity.
        $InstallationAssistantSignature = Get-AuthenticodeSignature $WindowsInstallAssistant -ErrorAction Stop
    } catch {
        # If signature retrieval fails, display an error and exit.
        Write-Host -Object "$($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to read the executable signature for the file '$WindowsInstallAssistant'."
        exit 1
    }

    # If the signature isn't valid, assume the file is corrupted or tampered with, and exit.
    if ($InstallationAssistantSignature.Status -ne "Valid") {
        Write-Host -Object "[Error] An invalid signature status of '$($InstallationAssistantSignature.Status)' was provided. Perhaps the downloaded file '$WindowsInstallAssistant' was corrupted in transit?"
        exit 1
    }


    # Check the signer's certificate subject to confirm it's Microsoft Corporation.
    if ($InstallationAssistantSignature.SignerCertificate.Subject -ne "CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US") {
        Write-Host -Object "[Error] An invalid signature subject of '$($InstallationAssistantSignature.SignerCertificate.Subject)' was provided. 'CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US' was expected."
        exit 1
    }

    Write-Host -Object "The signature is valid and appears to be what was expected."

    # Ensure the log folder exists, and if not, create it.
    if (!(Test-Path -Path $UpdateLogLocation -ErrorAction SilentlyContinue)) {
        Write-Host -Object "`nThe log folder '$UpdateLogLocation' does not currently exist. Attempting to create the folder."
        try {
            New-Item -Path $UpdateLogLocation -ItemType Directory -Force | Out-Null
            Write-Host -Object "Successfully created the log folder."
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to create log folder '$UpdateLogLocation'"
            exit 1
        }
    }
    #endregion
    #region Start Assistant

    # Define the arguments to be passed to the Installation Assistant.
    $InstallAssistantArguments = @(
        "/QuietInstall"
        "/SkipEULA"
        "/NoRestartUI"
        "/Auto Upgrade"
        "/CopyLogs `"$UpdateLogLocation`""
    )

    # Set up the process invocation parameters, including where to log standard output and errors.
    $InstallAssistantProcessArguments = @{
        FilePath               = $WindowsInstallAssistant
        ArgumentList           = $InstallAssistantArguments
        RedirectStandardOutput = "$UpdateLogLocation\$(New-Guid).stdout.log"
        RedirectStandardError  = "$UpdateLogLocation\$(New-Guid).stderr.log"
        NoNewWindow            = $True
    }

    Write-Host -Object "`nInitiating Windows 11 feature upgrade."
    Write-Host -Object "[Warning] This may take a few hours to complete. You can view the logs at '$UpdateLogLocation' and '${env:ProgramFiles(x86)}\WindowsInstallationAssistant\Logs' if any failure occurs."
    Write-Host -Object "If no failure occurs, these files may be empty."

    try {
        # Start the Windows 11 upgrade process silently in the background.
        Start-Process @InstallAssistantProcessArguments
    } catch {
        # If the process fails to start, display an error message and exit.
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to start the Windows 11 upgrade process using the file '$WindowsInstallAssistant'."
        exit 1
    }

    Start-Sleep -Seconds 30
    # Check if the Windows 10 Upgrade process is running.
    $Windows11UpgradeApp = Get-Process -Name "Windows10UpgraderApp" -ErrorAction SilentlyContinue

    if (!$Windows11UpgradeApp) {
        # No upgrade process is detected.
        Write-Host -Object "[Error] Failed to detect the upgrade process."
        Write-Host -Object "[Error] Failed to start the Windows 11 upgrade process using the file '$WindowsInstallAssistant'."
        exit 1
    } else {
        Write-Host -Object "`n### Windows 11 Upgrade Process ###"
        ($Windows11UpgradeApp | Select-Object @{ Name = 'PID'; Expression = { $_.Id } }, Name, Description, Path |
            Format-List PID, Name, Description, Path | Out-String).Trim() | Write-Host
    }
    #endregion

    exit $ExitCode
}
end {
    
    
    
}