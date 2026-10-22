#Requires -Version 5.1

<#
.SYNOPSIS
    Change the screensaver settings for all user profiles on a Windows machine.
.DESCRIPTION
    Change the screensaver settings for all user profiles on a Windows machine.

.PARAMETER SelectScreensaver "Bubbles"
    Select the screensaver to apply. If 'None' is selected, the screensaver will be disabled. Options include: None, 3D Text, Blank, Bubbles, Photos, Mystify, Ribbons

.PARAMETER WaitTime
    Specify the wait time in minutes before the screensaver activates. Valid values range from 1 to 9999 minutes. If no value is provided, the default wait time of 15 minutes will be used

.PARAMETER OnResumeEnterPassword
    Choose whether to require the user to log in on resume.

.PARAMETER PhotosDirectoryPath
    Enter the path to the directory containing the images for the 'Photos' screensaver. This must be a local path on the device. If 'Photos' is selected but this is not filled out, the default of each user's Pictures folder will be used.

.PARAMETER TextFor3DText
    Enter the text for the 3D Text screensaver. Only required if 3D Text is selected. Maximum length is 20 characters.

.PARAMETER ForceReboot
    Reboot the device after applying the screensaver settings. This may be needed for all changes to take effect. If not selected, the user may need to log off or restart their computer.
    
.EXAMPLE
    -SelectScreensaver "Ribbons" -WaitTime 10 -OnResumeEnterPassword:$False
    [Info] Working on 'tuser1' profile...

    [Info] Setting screensaver to 'Ribbons'.
    Registry::HKEY_USERS\S-1-5-21-21640437-1735840450-3283185940-1104\Control Panel\Desktop\SCRNSAVE.EXE changed from C:\Windows\System32\Mystify.scr to C:\Windows\System32\Ribbons.scr

    [Info] Setting screensaver timeout to 10 minute(s).
    Registry::HKEY_USERS\S-1-5-21-21640437-1735840450-3283185940-1104\Control Panel\Desktop\ScreenSaveTimeOut changed from 900 to 600

    [Info] Setting screensaver password requirement to False.
    Registry::HKEY_USERS\S-1-5-21-21640437-1735840450-3283185940-1104\Control Panel\Desktop\ScreenSaverIsSecure changed from 1 to 0

    [Info] Finished working on 'tuser1' profile.

.EXAMPLE
    -SelectScreensaver "Mystify" -WaitTime 1 -OnResumeEnterPassword:$True
    [Info] Working on 'tuser1' profile...

    [Info] Setting screensaver to 'Mystify'.
    Registry::HKEY_USERS\S-1-5-21-21640437-1735840450-3283185940-1104\Control Panel\Desktop\SCRNSAVE.EXE changed from C:\Windows\System32\Ribbons.scr to C:\Windows\System32\Mystify.scr

    [Info] Setting screensaver timeout to 1 minute(s).
    Registry::HKEY_USERS\S-1-5-21-21640437-1735840450-3283185940-1104\Control Panel\Desktop\ScreenSaveTimeOut changed from 900 to 60

    [Info] Setting screensaver password requirement to True.
    Registry::HKEY_USERS\S-1-5-21-21640437-1735840450-3283185940-1104\Control Panel\Desktop\ScreenSaverIsSecure changed from 0 to 1

    [Info] Finished working on 'tuser1' profile.

.EXAMPLE
    -SelectScreensaver "3D Text" -WaitTime 5 -OnResumeEnterPassword:$False -TextFor3DText "Hello World"
    [Info] Working on 'tuser1' profile...

    [Info] Setting screensaver to '3D Text'.
    Registry::HKEY_USERS\S-1-5-21-21640437-1735840450-3283185940-1104\Control Panel\Desktop\SCRNSAVE.EXE changed from C:\Windows\System32\Mystify.scr to C:\Windows\System32\ssText3d.scr

    [Info] Setting screensaver timeout to 5 minute(s).
    Registry::HKEY_USERS\S-1-5-21-21640437-1735840450-3283185940-1104\Control Panel\Desktop\ScreenSaveTimeOut changed from 60 to 300

    [Info] Setting screensaver password requirement to False.
    Registry::HKEY_USERS\S-1-5-21-21640437-1735840450-3283185940-1104\Control Panel\Desktop\ScreenSaverIsSecure changed from 1 to 0

    [Info] Setting 3D Text to 'Hello World'.
    Registry::HKEY_USERS\S-1-5-21-21640437-1735840450-3283185940-1104\Software\Microsoft\Windows\CurrentVersion\Screensavers\ssText3d\DisplayString changed from newvalue23 to Hello World

    [Info] Finished working on 'tuser1' profile.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$SelectScreensaver,

    [Parameter()]
    [int]$WaitTime,

    [Parameter()]
    [switch]$OnResumeEnterPassword = [System.Convert]::ToBoolean($env:onResumeEnterPassword),

    [Parameter()]
    [string]$TextFor3DText,

    [Parameter()]
    [string]$PhotosDirectoryPath,
    
    [Parameter()]
    [switch]$ForceReboot = [System.Convert]::ToBoolean($env:forceReboot)
)

begin {
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
    
        if ([String]::IsNullOrWhiteSpace($Path)) {
            throw (New-Object System.ArgumentNullException("You must provide a valid path to a registry key."))
        }
    
        if ($Path -notmatch "^(Registry::|HKCR:\\|HKCU:\\|HKLM:\\|HKU:\\|HKCC:\\|TestRegistry:\\)") {
            throw (New-Object System.ArgumentException("The path provided '$Path' is invalid as it does not start with 'Registry::', 'HKCR:\', 'HKCU:\', 'HKLM:\', 'HKU:\' or 'HKCC:\'."))
        }
    
        if ($Path -match "^Registry::" -and $Path -notmatch "^Registry::(HKCR\\|HKEY_CLASSES_ROOT\\|HKCU\\|HKEY_CURRENT_USER\\|HKLM\\|HKEY_LOCAL_MACHINE|HKU\\|HKEY_USERS|HKCC\\|HKEY_CURRENT_CONFIG)") {
            throw (New-Object System.ArgumentException("The path provided '$Path' is invalid as it does not start with a valid registry root such as 'HKLM\' or 'HKEY_LOCAL_MACHINE\'."))
        }
    
        if ([String]::IsNullOrWhiteSpace($Name)) {
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

    function Get-UserHives {
        [CmdletBinding()]
        param (
            [Parameter()]
            [ValidateSet('AzureAD', 'DomainAndLocal', 'All')]
            [String]$Type = "All",
            [Parameter()]
            [String[]]$ExcludedUsers,
            [Parameter()]
            [switch]$IncludeDefault
        )
    
        # Define the SID patterns to match based on the selected user type
        $Patterns = switch ($Type) {
            "AzureAD" { "S-1-12-1-(\d+-?){4}$" }
            "DomainAndLocal" { "S-1-5-21-(\d+-?){4}$" }
            "All" { "S-1-12-1-(\d+-?){4}$" ; "S-1-5-21-(\d+-?){4}$" }
        }
    
        # Retrieve user profile information based on the defined patterns
        $UserProfiles = Foreach ($Pattern in $Patterns) { 
            Get-ItemProperty "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" |
                Where-Object { $_.PSChildName -match $Pattern } | 
                Select-Object @{Name = "SID"; Expression = { $_.PSChildName } },
                @{Name = "Username"; Expression = { "$($_.ProfileImagePath | Split-Path -Leaf)" } }, 
                @{Name = "Domain"; Expression = { if ($_.PSChildName -match "S-1-12-1-(\d+-?){4}$") { "AzureAD" }else { $Null } } }, 
                @{Name = "UserHive"; Expression = { "$($_.ProfileImagePath)\NTuser.dat" } }, 
                @{Name = "Path"; Expression = { $_.ProfileImagePath } }
        }
    
        # If the IncludeDefault switch is set, add the Default profile to the results
        switch ($IncludeDefault) {
            $True {
                $DefaultProfile = "" | Select-Object Username, SID, UserHive, Path
                $DefaultProfile.Username = "Default"
                $DefaultProfile.Domain = $env:COMPUTERNAME
                $DefaultProfile.SID = "DefaultProfile"
                $DefaultProfile.Userhive = "$env:SystemDrive\Users\Default\NTUSER.DAT"
                $DefaultProfile.Path = "C:\Users\Default"
    
                # Exclude users specified in the ExcludedUsers list
                $DefaultProfile | Where-Object { $ExcludedUsers -notcontains $_.Username }
            }
        }
    
        if ($PSVersionTable.PSVersion.Major -lt 3) {
            $AllAccounts = Get-WmiObject -Class "win32_UserAccount"
        }
        else {
            $AllAccounts = Get-CimInstance -ClassName "win32_UserAccount"
        }
    
        $CompleteUserProfiles = $UserProfiles | ForEach-Object {
            $SID = $_.SID
            $Win32Object = $AllAccounts | Where-Object { $_.SID -like $SID }
    
            if ($Win32Object) {
                $Win32Object | Add-Member -NotePropertyName UserHive -NotePropertyValue $_.UserHive 
                $Win32Object | Add-Member -NotePropertyName Path -NotePropertyValue $_.Path
                $Win32Object
            }
            else {
                [PSCustomObject]@{
                    Name     = $_.Username
                    Domain   = $_.Domain
                    SID      = $_.SID
                    UserHive = $_.UserHive
                    Path     = $_.Path
                }
            }
        }
    
        # Return the list of user profiles, excluding any specified in the ExcludedUsers list
        $CompleteUserProfiles | Where-Object { $ExcludedUsers -notcontains $_.Name }
    }

    # Import the needed functions for working with PIDLs (Pointer to an Item Identifier List) into the Shell32 class
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Shell32 {
    // Converts a file or folder path into a PIDL (Pointer to an Item Identifier List)
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern int SHParseDisplayName(string pszName, IntPtr pbc, out IntPtr ppidl, uint sfgaoIn, out uint psfgaoOut);

    // Converts a PIDL into a file or folder path
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern int SHGetPathFromIDList(IntPtr pidl, char[] pszPath);

    // Retrieves the size of of an item ID list
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern int ILGetSize(IntPtr pidl);

    // Used to free memory
    [DllImport("ole32.dll")]
    public static extern void CoTaskMemFree(IntPtr pv);
}
"@ -Language CSharp

    # Function to convert a path to a PIDL
    function Convert-PathToPIDL {
        param (
            [string]$Path
        )

        # Initialize the PIDL to zero
        $returnPIDL = [IntPtr]::Zero

        try {
            # Call SHParseDisplayName to get the PIDL from the provided path
            # https://learn.microsoft.com/en-us/windows/win32/api/shlobj_core/nf-shlobj_core-shparsedisplayname
            $result = [Shell32]::SHParseDisplayName($Path, [IntPtr]::Zero, [ref]$returnPIDL, 0, [ref][uint32]0)

            # Check if the call was successful
            if ($result -ne 0) {
                throw "Failed to retrieve PIDL for path: $Path (Error Code: $result)"
            }

            # Return the PIDL
            return $returnPIDL
        }
        catch {
            throw $_
        }
    }

    # Function to get the size of a PIDL
    function Get-PIDLSize {
        param (
            [IntPtr]$PIDL
        )

        try {
            # Call the Shell32.dll ILGetSize function
            # https://learn.microsoft.com/en-us/windows/win32/api/shlobj_core/nf-shlobj_core-ilgetsize
            $Size = [Shell32]::ILGetSize($PIDL)
            return $Size
        }
        catch {
            throw $_
        }
    }

    # Function to encode a path into a Base64 encoded PIDL
    # This is used to set the photo screensaver folder via the registry
    function Get-EncryptedPIDLStringFromPath {
        param (
            [string]$Path
        )

        try {
            # Get the PIDL from the path
            $PIDL = Convert-PathToPIDL $Path

            # Get the size of the PIDL structure
            $SizeOfPIDL = Get-PIDLSize $PIDL

            # Create a new byte array the size of the PIDL
            $ByteArray = New-Object byte[] $SizeOfPIDL
            
            # Copy the PIDL data into the byte array
            # https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.marshal.copy?view=net-9.0#system-runtime-interopservices-marshal-copy(system-intptr-system-byte()-system-int32-system-int32)
            [System.Runtime.InteropServices.Marshal]::Copy($PIDL, $ByteArray, 0, $SizeOfPIDL)

            # Encode the byte array to a Base64 string
            $Base64EncodedString = [System.Convert]::ToBase64String($ByteArray)

            return $Base64EncodedString
        }
        catch {
            throw $_
        }
        finally {
            # Free the unmanaged PIDL memory
            if ($PIDL -ne [IntPtr]::Zero -and $null -ne $PIDL) {
                [Shell32]::CoTaskMemFree($PIDL)
            }
        }
    }

    # Function to convert a Base64 encoded PIDL back to a path
    function Convert-PIDLToPath {
        param (
            [string]$EncodedPIDL
        )
    
        # Decode the Base64 string to a byte array
        $DecodedBytes = [System.Convert]::FromBase64String($EncodedPIDL)
    
        try {
            # Allocate memory for the PIDL
            $DecodedPIDLPointer = [System.Runtime.InteropServices.Marshal]::AllocCoTaskMem($DecodedBytes.Length)
    
            # Copy the decoded bytes to the allocated memory
            # https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.marshal.copy?view=net-9.0#system-runtime-interopservices-marshal-copy(system-byte()-system-int32-system-intptr-system-int32)
            [System.Runtime.InteropServices.Marshal]::Copy($DecodedBytes, 0, $DecodedPIDLPointer, $DecodedBytes.Length)
            
            # Create buffer to hold the path
            # The buffer size is 261 characters (Windows default max path length of 260 + null terminator)
            $PathBuffer = New-Object char[] 261
    
            # Call SHGetPathFromIDList to get the path from the PIDL
            # The first parameter is a point to where the data is, the second is where the path will be stored 
            # The function returns 0 on success
            $Result = [Shell32]::SHGetPathFromIDList($DecodedPIDLPointer, $PathBuffer)
            
            # Throw if error occurred
            if ($Result -eq 0) {
                throw "Failed to retrieve path from PIDL."
            }
    
            # Return the decoded path as a string
            return -join $PathBuffer
        }
        catch {
            throw $_
        }
        finally {
            # Free the allocated memory
            if ($DecodedPIDLPointer -ne [IntPtr]::Zero) {
                [System.Runtime.InteropServices.Marshal]::FreeCoTaskMem($DecodedPIDLPointer)
            }
        }
    }
}
process {
    try {
        $IsElevated = Test-IsElevated -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running with Administrator privileges."
        exit 1
    }
    
    if (!$IsElevated) {
        Write-Host -Object "[Error] Access Denied: Please run with Administrator privileges."
        exit 1
    }

    # Import script variables
    if ($env:selectScreensaver) {$selectScreensaver = $env:selectScreensaver}
    if ($env:waitTime) {
        if ([int]::TryParse($env:waitTime, [ref]$null)) {
            $waitTime = [int]$env:waitTime
        }
        else {
            Write-Host "[Error] The wait time must be a valid integer between 1 and 9999 minutes. Please enter a valid wait time."
            exit 1
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($env:textFor3DText)) {$textFor3DText = $env:textFor3DText.Trim()}
    if (-not [string]::IsNullOrWhiteSpace($env:photosDirectoryPath)) {$photosDirectoryPath = $env:photosDirectoryPath.Trim()}

    # Map screensaver dropdown value to SCR file name
    $screensaverMap = @{
        "None"    = ""
        "3D Text" = "ssText3d.scr"
        "Blank"   = "scrnsave.scr"
        "Bubbles" = "Bubbles.scr"
        "Photos"  = "PhotoScreensaver.scr"
        "Mystify" = "Mystify.scr"
        "Ribbons" = "Ribbons.scr"
    }

    # Validate the selected screensaver
    if (-not [string]::IsNullOrWhiteSpace($SelectScreensaver) -and -not $screensaverMap.ContainsKey($SelectScreensaver)) {
        Write-Host "[Error] Invalid screen saver selected. Valid options are: $($screensaverMap.Keys -join ', ')"
        exit 1
    }

    # Validate 3D Text is provided
    if ($SelectScreensaver -eq "3D Text" -and [string]::IsNullOrWhiteSpace($textFor3DText)) {
        Write-Host "[Error] 3D Text screensaver requires text to be provided."
        exit 1
    }

    # Warn if 3D Text is not selected but text is provided
    if ($SelectScreensaver -ne "3D Text" -and -not [string]::IsNullOrWhiteSpace($TextFor3DText)) {
        Write-Host "[Warning] 3D Text was not selected as the screensaver. Ignoring provided Text for 3D Text input.`n"
        $textFor3DText = $null
    }

    # Validate character length of 3D Text
    if ($SelectScreensaver -eq "3D Text" -and $TextFor3DText.Length -gt 20) {
        Write-Host "[Error] 3D Text exceeds the maximum length of 20 characters."
        exit 1
    }

    # Warn if Photos is not selected but path is provided
    if ($SelectScreensaver -ne "Photos" -and -not [string]::IsNullOrWhiteSpace($PhotosDirectoryPath)) {
        Write-Host "[Warning] Photos was not selected as the screensaver. Ignoring provided Photos Directory Path input.`n"
        $PhotosDirectoryPath = $null
    }

    # Error if the provided photos path is a UNC path
    if ($SelectScreensaver -eq "Photos" -and $PhotosDirectoryPath -and $PhotosDirectoryPath -match "^\\\\") {
        Write-Host "[Error] UNC paths cannot be used for the Photos screensaver. Please provide a local path."
        exit 1
    }

    # Error if photos path is not a local path
    if ($SelectScreensaver -eq "Photos" -and $PhotosDirectoryPath -and $PhotosDirectoryPath -notmatch "^[a-zA-Z]:\\") {
        Write-Host "[Error] The provided photo directory path '$PhotosDirectoryPath' is not a valid local path."
        exit 1
    }

    # Validate character length of the photos directory path
    if ($SelectScreensaver -eq "Photos" -and $PhotosDirectoryPath -and $PhotosDirectoryPath.Length -gt 260) {
        Write-Host "[Error] The provided photo directory path '$PhotosDirectoryPath' exceeds the maximum length of 260 characters."
        exit 1
    }

    # Set default photos path if photos is selected but no path provided
    if ($SelectScreensaver -eq "Photos" -and [string]::IsNullOrWhiteSpace($PhotosDirectoryPath)) {
        Write-Host "[Warning] No path chosen for Photos directory. Defaulting to each user's Pictures folder."
        $defaultPhotosPath = $true
    }
    elseif ($SelectScreensaver -eq "Photos") {
        # Otherwise, validate the provided path
        # Error if the provided path doesn't exist
        if (-not (Test-Path -Path $PhotosDirectoryPath)) {
            Write-Host "[Error] The provided photo directory path '$PhotosDirectoryPath' does not exist."
            exit 1
        }

        # Error if the provided path is not a directory
        if (-not (Test-Path -Path $PhotosDirectoryPath -PathType Container)) {
            Write-Host "[Error] The provided photo directory path '$PhotosDirectoryPath' is not a directory."
            exit 1
        }
    }

    # Skip all other options if 'None' is selected as the screensaver
    # Only warn the user if they specified another option
    if ($SelectScreensaver -eq "None") {
        if ($WaitTime -or $OnResumeEnterPassword -or $TextFor3DText -or $PhotosDirectoryPath) {
            Write-Host "[Warning] When 'None' is selected as the screensaver, all other options will be ignored.`n"
        }
        $SkipAllSettings = $true
    }
    else {
        # Check for wait time, if not provided fall back to 15 mins
        # If it is provided, check if it is a valid integer
        if ($waitTime -eq 0) {
            Write-Host "[Warning] Wait time not provided. Defaulting to 15 minutes.`n"
            $waitTime = 15
        }
        elseif ($waitTime -lt 0 -or $waitTime -gt 9999) {
            Write-Host "[Error] The minimum wait time is 1 minute, the maximum is 9999 minutes. Please enter a valid wait time."
            exit 1
        }
    }

    # Warn if force reboot is not selected and a setting is being changed
    if (-not $ForceReboot) {
        Write-Host "[Warning] Force reboot not selected. Changes to screensaver settings may not take effect until the user logs off or restarts their computer.`n"
    }

    $ExitCode = 0

    # Get all user profiles on the machine
    $UserProfiles = Get-UserHives -Type "All"

    # Create list to hold loaded profiles
    # This is used to unload the profiles after the script has run
    $ProfileWasLoaded = New-Object System.Collections.Generic.List[object]
    
    # Loop through each profile on the machine
    foreach ($UserProfile in $UserProfiles) {
        # Store current user SID in variable
        $currentUserSID = $UserProfile.SID
        
        # Load User ntuser.dat if it's not already loaded
        if (!(Test-Path -Path Registry::HKEY_USERS\$currentUserSID -ErrorAction SilentlyContinue)) {
            try {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg.exe LOAD HKU\$currentUserSID `"$($UserProfile.UserHive)`"" -Wait -WindowStyle Hidden
                $ProfileWasLoaded.Add($UserProfile)
            }
            catch {
                Write-Host "[Error] Error loading the profile for '$($UserProfile.Name)'."
                Write-Host "[Error] $($_.Exception.Message)"
                $ExitCode = 1
                continue
            }
        }

        Write-Host "[Info] Working on '$($UserProfile.Name)' profile...`n"

        # Set registry base path for the current user
        $regPath = "Registry::HKEY_USERS\$currentUserSID\Control Panel\Desktop"

        # Get current values for later comparison
        $currentValues = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        $currentScreensaver = $currentValues."SCRNSAVE.EXE"

        # If a screensaver has been selected, set or remove it
        if (-not [string]::IsNullOrWhiteSpace($SelectScreensaver)){
            if ($SelectScreensaver -eq "None") {
                $currentScreenSaverIsSecure = $currentValues."ScreenSaverIsSecure"
                $currentScreenSaverTimeout = $currentValues."ScreenSaveTimeout"

                # Create array of values to check if screensaver is active
                $combined = @($currentScreensaver, $currentScreenSaverIsSecure, $currentScreenSaverTimeout)

                if ([string]::IsNullOrWhiteSpace($combined)) {
                    Write-Host "[Info] Screensaver is already disabled."
                }
                else {
                    try {
                        Write-Host "[Info] Disabling screensaver."

                        # Remove the screensaver registry key
                        if ($currentScreensaver) {
                            Write-Host "[Info] Removing $regPath\SCRNSAVE.EXE (current value: $currentScreensaver)"
                            Remove-ItemProperty -Path $regPath -Name "SCRNSAVE.EXE" -ErrorAction Stop
                        }

                        # Remove the password requirement registry key
                        if ($currentScreenSaverIsSecure) {
                            Write-Host "[Info] Removing $regPath\ScreenSaverIsSecure (current value: $currentScreenSaverIsSecure)"
                            Remove-ItemProperty -Path $regPath -Name "ScreenSaverIsSecure" -ErrorAction Stop
                        }

                        # Remove the screensaver timeout key
                        if ($currentScreenSaverTimeout) {
                            Write-Host "[Info] Removing $regPath\ScreenSaveTimeout (current value: $currentScreenSaverTimeout)"
                            Remove-ItemProperty -Path $regPath -Name "ScreenSaveTimeout" -ErrorAction Stop
                        }

                        Write-Host "[Info] Successfully disabled screensaver."
                    }
                    catch {
                        Write-Host "[Error] Failed to disable screensaver."
                        Write-Host "$($_.Exception.Message)"
                        $ExitCode = 1
                    }
                }
            }
            else {
                $screensaverFileName = $screensaverMap[$SelectScreensaver]

                if ($currentScreensaver -eq "$env:SystemRoot\System32\$screensaverFileName") {
                    Write-Host "[Info] Screensaver is already set to '$SelectScreensaver'."
                }
                else {
                    try {
                        Write-Host "[Info] Setting screensaver to '$SelectScreensaver'."
                        Set-RegKey -Path $regPath -Name "SCRNSAVE.EXE" -Value "$env:SystemRoot\System32\$screensaverFileName" -PropertyType "String"
                    }
                    catch {
                        Write-Host "[Error] Failed to set screensaver."
                        Write-Host "$($_.Exception.Message)"
                        $ExitCode = 1
                    }
                }
            }
            Write-Host ""
        }

        # If set to skip all settings, continue to the next profile
        # This will be true if the user selected 'None' as the screensaver
        if ($SkipAllSettings) {
            Write-Host "[Info] Finished working on '$($UserProfile.Name)' profile.`n"
            continue
        }

        # Set screensaver timeout
        if ($waitTime) {
            # Get the current value
            $currentValue = (Get-ItemProperty -Path $regPath -Name ScreenSaveTimeOut -ErrorAction SilentlyContinue).ScreenSaveTimeOut

            # Check if it is already set, if not then set it
            if ($currentValue -eq ($waitTime * 60)) {
                Write-Host "[Info] Screensaver timeout is already set to $waitTime minute(s)."
            }
            else {
                try {
                    Write-Host "[Info] Setting screensaver timeout to $waitTime minute(s)."
                    Set-RegKey -Path $regPath -Name ScreenSaveTimeOut -Value ($waitTime * 60) -PropertyType "String"
                }
                catch {
                    Write-Host "[Error] Failed to set screensaver timeout."
                    Write-Host "$($_.Exception.Message)"
                    $ExitCode = 1
                }
            }
            Write-Host ""
        }

        # Get current value for password required on resume
        $currentValue = (Get-ItemProperty -Path $regPath -Name ScreenSaverIsSecure -ErrorAction SilentlyContinue).ScreenSaverIsSecure

        # Check if password required on resume is set, if not set it
        if ($OnResumeEnterPassword) {
            if ($currentValue -eq 1) {
                Write-Host "[Info] Screensaver password requirement is already enabled."
            }
            else {
                try {
                    Write-Host "[Info] Enabling screensaver password requirement."
                    Set-RegKey -Path $regPath -Name ScreenSaverIsSecure -Value 1 -PropertyType "String"
                }
                catch {
                    Write-Host "[Error] Failed to enable screensaver password requirement."
                    Write-Host "$($_.Exception.Message)"
                    $ExitCode = 1
                }
            }
        }
        else {
            if ($currentValue -eq 0) {
                Write-Host "[Info] Screensaver password requirement is already disabled."
            }
            else {
                try {
                    Write-Host "[Info] Disabling screensaver password requirement."
                    Set-RegKey -Path $regPath -Name ScreenSaverIsSecure -Value 0 -PropertyType "String"
                }
                catch {
                    Write-Host "[Error] Failed to disable screensaver password requirement."
                    Write-Host "$($_.Exception.Message)"
                    $ExitCode = 1
                }
            }
        }

        # If using the default photos directory path, set the photos directory path to the user's Pictures folder
        if ($defaultPhotosPath){
            $PhotosDirectoryPath = "$($UserProfile.Path)\Pictures"
        }

        # Set photos screensaver directory path
        if ($SelectScreensaver -eq "Photos" -and $PhotosDirectoryPath){
            Write-Host ""
            # Photos screensaver uses a different registry key
            $photosRegPath = "Registry::HKEY_USERS\$currentUserSID\SOFTWARE\Microsoft\Windows Photo Viewer\Slideshow\Screensaver"

            # Convert the photos directory path to an EncryptedPIDL, which is what the registry expects
            try {
                $EncryptedPIDL = Get-EncryptedPIDLStringFromPath $PhotosDirectoryPath
            }
            catch {
                Write-Host "[Error] Error converting '$PhotosDirectoryPath' to EncryptedPIDL string."
                Write-Host "[Error] $($_.Exception.Message)"
                $EncryptedPIDL = $null
                $ExitCode = 1
            }

            # Check if the registry path exists, create it if not
            if (-not (Test-Path -Path $photosRegPath)) {
                try {
                    New-Item -Path $photosRegPath -Force -ErrorAction Stop | Out-Null
                }
                catch {
                    Write-Host "[Error] Error creating the registry path '$photosRegPath' for photos screensaver."
                    Write-Host "$($_.Exception.Message)"
                    $EncryptedPIDL = $null
                    $ExitCode = 1
                }
            }

            if ($EncryptedPIDL){
                # Get the current value of the photos directory path
                $currentValue = (Get-ItemProperty -Path $photosRegPath -Name "EncryptedPIDL" -ErrorAction SilentlyContinue)."EncryptedPIDL"

                # If the current value is not null, try to convert it to a path for comparison
                if ($currentValue){
                    # Get the current value directory path
                    try {
                        # Trim the whitespace and remove null characters
                        $currentValueDirectoryPath = (Convert-PIDLToPath $currentValue).Trim() -replace "\u0000"
                    }
                    catch {
                        Write-Host "[Error] Error converting current PIDL value to path."
                        Write-Host "$($_.Exception.Message)"
                        $currentValueDirectoryPath = $null
                        $ExitCode = 1
                    }
                }

                # Check if it is already set, if not then set it
                if ($currentValueDirectoryPath -eq $PhotosDirectoryPath) {
                    Write-Host "[Info] Photos screensaver is already using '$PhotosDirectoryPath'."
                }
                else {
                    if ($currentValueDirectoryPath) {
                        Write-Host "[Info] Photos screensaver directory is currently using '$currentValueDirectoryPath'."
                    }

                    # Set the photos screensaver directory path
                    try {
                        Write-Host "[Info] Setting photos screensaver to use '$PhotosDirectoryPath'."
                        Set-ItemProperty -Path $photosRegPath -Name "EncryptedPIDL" -Value $EncryptedPIDL -Type "String" -Force -Confirm:$false -ErrorAction Stop
                        Write-Host "[Info] Successfully set photos screensaver to use '$PhotosDirectoryPath'."
                    }
                    catch {
                        Write-Host "[Error] Failed to set photos screensaver directory."
                        Write-Host "$($_.Exception.Message)"
                        $currentValue = $null
                        $ExitCode = 1
                    }
                }
            }
        }

        # Set 3D Text content
        if ($SelectScreensaver -eq "3D Text" -and $textFor3DText) {
            Write-Host ""

            # 3D Text has a different registry path than the rest of the settings
            $3DTextRegPath = "Registry::HKEY_USERS\$currentUserSID\Software\Microsoft\Windows\CurrentVersion\Screensavers\ssText3d"

            # Get the current value of the text
            $currentValue = (Get-ItemProperty -Path $regPath -Name DisplayString -ErrorAction SilentlyContinue).DisplayString

            # Check if it is already set, if not then set it
            if ($currentValue -eq $textFor3DText) {
                Write-Host "[Info] 3D Text is already set to '$textFor3DText'."
            }
            else {
                try {
                    Write-Host "[Info] Setting 3D Text to '$textFor3DText'."
                    Set-RegKey -Path $3DTextRegPath -Name DisplayString -Value $textFor3DText -PropertyType "String"
                }
                catch {
                    Write-Host "[Error] Failed to set 3D Text."
                    Write-Host "$($_.Exception.Message)"
                    $ExitCode = 1
                }
            }
        }
        Write-Host "`n[Info] Finished working on '$($UserProfile.Name)' profile.`n"
    }

    # If user profiles were loaded, unload the profiles
    if ($ProfileWasLoaded.Count -gt 0) {
        foreach ($UserProfile in $ProfileWasLoaded) {
            # Unload NTuser.dat
            [gc]::Collect()
            Start-Sleep 1
            try {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg.exe UNLOAD HKU\$currentUserSID" -Wait -WindowStyle Hidden -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Host "[Error] Error unloading the profile for '$($UserProfile.Name)'."
                Write-Host "[Error] $($_.Exception.Message)"
                $ExitCode = 1
            }
        }
    }

     # if force reboot was selected, schedule a reboot in 1 minute and notify the user
     if ($ForceReboot) {
        Write-Host "[Info] Rebooting computer in 60 seconds..."
        shutdown.exe -r -t 60
    }
    
    exit $ExitCode
}
end {
    
    
    
}