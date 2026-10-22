#Requires -Version 5.1

<#
.SYNOPSIS
    Reports on all installed browser extensions for Chrome, Firefox and Edge.
.DESCRIPTION
    Reports on all installed browser extensions for Chrome, Firefox and Edge.
.EXAMPLE
    (No Parameters)

    [Info] A Microsoft Edge installation was detected. Searching Microsoft Edge for browser extensions...
    
    [Info] A Firefox installation was detected. Searching Firefox for browser extensions...

    [Info] Browser extensions were detected.

    Browser           : Edge
    User              : Administrator
    Profile           : Profile 1
    Name              : Edge Feedback
    Extension ID      : ihmafllikibpmigkcoadcmckbfhibefp
    Version           : 1.0.0.1
    Signed In Account : Not signed in
    Description       : User feedback extension

    ...

    Browser           : Firefox
    User              : Administrator
    Profile           : default-release
    Name              : Add-ons Search Detection
    Extension ID      : addons-search-detection@mozilla.com
    Version           : 2.0.0
    Signed In Account : Not signed in
    Description       : 

.EXAMPLE
    -MultilineCustomField "Multiline"

    [Info] A Microsoft Edge installation was detected. Searching Microsoft Edge for browser extensions...

    [Info] A Firefox installation was detected. Searching Firefox for browser extensions...

    [Info] Browser extensions were detected.

    [Info] Attempting to set Custom Field 'Multiline'.
    [Info] Successfully set Custom Field 'Multiline'!

    Browser           : Edge
    User              : Administrator
    Profile           : Profile 1
    Name              : Edge Feedback
    Extension ID      : ihmafllikibpmigkcoadcmckbfhibefp
    Version           : 1.0.0.1
    Signed In Account : Not signed in
    Description       : User feedback extension

    ...

    Browser           : Firefox
    User              : Administrator
    Profile           : default-release
    Name              : Add-ons Search Detection
    Extension ID      : addons-search-detection@mozilla.com
    Version           : 2.0.0
    Signed In Account : Not signed in
    Description       : 

    ...

.EXAMPLE 
    -WysiwygCustomFIeld "WYSIWYG"

    [Info] A Microsoft Edge installation was detected. Searching Microsoft Edge for browser extensions...

    [Info] A Firefox installation was detected. Searching Firefox for browser extensions...

    [Info] Browser extensions were detected.

    [Info] Attempting to set Custom Field 'WYSIWYG'.
    [Info] Successfully set Custom Field 'WYSIWYG'!

    Browser           : Edge
    User              : Administrator
    Profile           : Profile 1
    Name              : Edge Feedback
    Extension ID      : ihmafllikibpmigkcoadcmckbfhibefp
    Version           : 1.0.0.1
    Signed In Account : Not signed in
    Description       : User feedback extension

    ...

    Browser           : Firefox
    User              : Administrator
    Profile           : default-release
    Name              : Add-ons Search Detection
    Extension ID      : addons-search-detection@mozilla.com
    Version           : 2.0.0
    Signed In Account : Not signed in
    Description       : 

    ...

PARAMETER: -MultilineCustomField "ReplaceMeWithNameOfAMultilineCustomField"
    Specify the name of a multiline custom field to optionally store the search results in. Leave blank to not set a multiline field.

PARAMETER: -WysiwygCustomField "ReplaceMeWithAnyWYSIWYGCustomField"
    Specify the name of a WYSIWYG custom field to optionally store the search results in. Leave blank to not set a WYSIWYG field.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.1
    Release Notes: Adds extension version to output. Adds browser signed-in account to output. Improves detection of extensions in Chrome and Edge. Improves error handling. Updates to script output and formatting. Updates functions. 
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$MultilineCustomField,
    [Parameter()]
    [String]$WysiwygCustomField
)

begin {
    # if custom field input is only spaces, set it to null
    if (-not [string]::IsNullOrWhiteSpace($env:WYSIWYGCustomFieldName)){
        $WYSIWYGCustomField = $env:WYSIWYGCustomFieldName.Trim()
    }
    else{
        $WYSIWYGCustomField = $WYSIWYGCustomField.Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($env:MultilineCustomFieldName)){
        $MultilineCustomField = $env:MultilineCustomFieldName.Trim()
    }
    else{
        $MultilineCustomField = $MultilineCustomField.Trim()
    }

    # test custom field for invalid characters
    if ($WYSIWYGCustomField -match "[^0-9A-Z]"){
        Write-Host "[Error] WYSIWYG Custom Field Name contains invalid character(s). Writing to the WYSIWYG Custom Field will be skipped."
        Write-Host "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
        $WYSIWYGCustomField = $null
        $ExitCode = 1
        Write-Host ""
    }

    if ($MultilineCustomField -match "[^0-9A-Z]"){
        Write-Host "[Error] Multiline Custom Field Name contains invalid character(s). Writing to the Multiline Custom Field will be skipped."
        Write-Host "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
        $MultilineCustomField = $null
        $ExitCode = 1
        Write-Host ""
    }

    # Check if $MultilineCustomField and $WysiwygCustomField are both not null and have the same value
    if ($MultilineCustomField -and $WysiwygCustomField -and $MultilineCustomField -eq $WysiwygCustomField) {
        Write-Host "[Error] Custom Fields of different types cannot have the same name."
        Write-Host "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Fields-Configuration-Device-Role-Fields"
        exit 1
    }

    # Function to get user registry hives based on the type of account
    function Get-UserHives {
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
        try {
            $UserProfiles = Foreach ($Pattern in $Patterns) { 
                Get-ItemProperty "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" -ErrorAction Stop |
                    Where-Object { $_.PSChildName -match $Pattern } | 
                    Select-Object @{Name = "SID"; Expression = { $_.PSChildName } },
                    @{Name = "Username"; Expression = { "$($_.ProfileImagePath | Split-Path -Leaf)" } }, 
                    @{Name = "Domain"; Expression = { if ($_.PSChildName -match "S-1-12-1-(\d+-?){4}$") { "AzureAD" }else { $Null } } }, 
                    @{Name = "UserHive"; Expression = { "$($_.ProfileImagePath)\NTuser.dat" } }, 
                    @{Name = "Path"; Expression = { $_.ProfileImagePath } }
            }
        }
        catch {
            Write-Host "[Error] Failed to scan registry keys at 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'."
            Write-Host "[Error] $($_.Exception.Message)"
            exit 1
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
    
        try {
            if ($PSVersionTable.PSVersion.Major -lt 3) {
                $AllAccounts = Get-WmiObject -Class "win32_UserAccount" -ErrorAction Stop
            }
            else {
                $AllAccounts = Get-CimInstance -ClassName "win32_UserAccount" -ErrorAction Stop
            }
        }
        catch {
            Write-Host "[Error] Failed to gather complete profile information."
            Write-Host "[Error] $($_.Exception.Message)"
            exit 1
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

    # Function to check if the current PowerShell session is running with elevated permissions
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Set-CustomField {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $True)]
            [String]$Name,
            [Parameter()]
            [String]$Type,
            [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
            $Value,
            [Parameter()]
            [String]$DocumentName,
            [Parameter()]
            [Switch]$Piped
        )
        # Remove the non-breaking space character
        if ($Type -eq "WYSIWYG") {
            $Value = $Value -replace ' ', '&nbsp;'
        }
        
        # Measure the number of characters in the provided value
        $Characters = $Value | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
    
        # Throw an error if the value exceeds the character limit of 200,000 characters
        if ($Piped -and $Characters -ge 200000) {
            throw [System.ArgumentOutOfRangeException]::New("Character limit exceeded: the value is greater than or equal to 200,000 characters.")
        }
    
        if (!$Piped -and $Characters -ge 45000) {
            throw [System.ArgumentOutOfRangeException]::New("Character limit exceeded: the value is greater than or equal to 45,000 characters.")
        }
        
        # Initialize a hashtable for additional documentation parameters
        $DocumentationParams = @{}
    
        # If a document name is provided, add it to the documentation parameters
        if ($DocumentName) { $DocumentationParams["DocumentName"] = $DocumentName }
        
        # Define a list of valid field types
        $ValidFields = "Attachment", "Checkbox", "Date", "Date or Date Time", "Decimal", "Dropdown", "Email", "Integer", "IP Address", "MultiLine", "MultiSelect", "Phone", "Secure", "Text", "Time", "URL", "WYSIWYG"
    
        # Warn the user if the provided type is not valid
        if ($Type -and $ValidFields -notcontains $Type) { Write-Warning "$Type is an invalid type. Please check here for valid types: https://ninjarmm.zendesk.com/hc/en-us/articles/16973443979789-Command-Line-Interface-CLI-Supported-Fields-and-Functionality" }
        
        # Define types that require options to be retrieved
        $NeedsOptions = "Dropdown"
    
        # If the property is being set in a document or field and the type needs options, retrieve them
        if ($DocumentName) {
            if ($NeedsOptions -contains $Type) {
                $NinjaPropertyOptions = Ninja-Property-Docs-Options -AttributeName $Name @DocumentationParams 2>&1
            }
        }
        else {
            if ($NeedsOptions -contains $Type) {
                $NinjaPropertyOptions = Ninja-Property-Options -Name $Name 2>&1
            }
        }
        
        # Throw an error if there was an issue retrieving the property options
        if ($NinjaPropertyOptions.Exception) { throw $NinjaPropertyOptions }
            
        # Process the property value based on its type
        switch ($Type) {
            "Checkbox" {
                # Convert the value to a boolean for Checkbox type
                $NinjaValue = [System.Convert]::ToBoolean($Value)
            }
            "Date or Date Time" {
                # Convert the value to a Unix timestamp for Date or Date Time type
                $Date = (Get-Date $Value).ToUniversalTime()
                $TimeSpan = New-TimeSpan (Get-Date "1970-01-01 00:00:00") $Date
                $NinjaValue = $TimeSpan.TotalSeconds
            }
            "Dropdown" {
                # Convert the dropdown value to its corresponding GUID
                $Options = $NinjaPropertyOptions -replace '=', ',' | ConvertFrom-Csv -Header "GUID", "Name"
                $Selection = $Options | Where-Object { $_.Name -eq $Value } | Select-Object -ExpandProperty GUID
            
                # Throw an error if the value is not present in the dropdown options
                if (!($Selection)) {
                    throw [System.ArgumentOutOfRangeException]::New("Value is not present in dropdown options.")
                }
            
                $NinjaValue = $Selection
            }
            default {
                # For other types, use the value as is
                $NinjaValue = $Value
            }
        }
            
        # Set the property value in the document if a document name is provided
        if ($DocumentName) {
            $CustomField = Ninja-Property-Docs-Set -AttributeName $Name -AttributeValue $NinjaValue @DocumentationParams 2>&1
        }
        else {
            try {
                # Otherwise, set the standard property value
                if ($Piped) {
                    $CustomField = $NinjaValue | Ninja-Property-Set-Piped -Name $Name 2>&1
                }
                else {
                    $CustomField = Ninja-Property-Set -Name $Name -Value $NinjaValue 2>&1
                }
            }
            catch {
                Write-Host -Object "[Error] Failed to set custom field."
                throw $_.Exception.Message
            }
        }
            
        # Throw an error if setting the property failed
        if ($CustomField.Exception) {
            throw $CustomField
        }
    }

    # Function to find installation keys based on the display name, optionally returning uninstall strings
    function Find-InstallKey {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromPipeline = $True)]
            [String]$DisplayName,
            [Parameter()]
            [Switch]$UninstallString,
            [Parameter()]
            [String]$UserBaseKey
        )
        process {
            # Initialize an empty list to hold installation objects
            $InstallList = New-Object System.Collections.Generic.List[Object]

            # If no user base key is specified, search in the default system-wide uninstall paths
            if (!$UserBaseKey) {
                # Search for programs in 32-bit and 64-bit locations. Then add them to the list if they match the display name
                $Result = Get-ChildItem -Path "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" }
                if ($Result) { $InstallList.Add($Result) }

                $Result = Get-ChildItem -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" }
                if ($Result) { $InstallList.Add($Result) }
            }
            else {
                # If a user base key is specified, search in the user-specified 64-bit and 32-bit paths.
                $Result = Get-ChildItem -Path "$UserBaseKey\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" }
                if ($Result) { $InstallList.Add($Result) }
    
                $Result = Get-ChildItem -Path "$UserBaseKey\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" }
                if ($Result) { $InstallList.Add($Result) }
            }
    
            # If the UninstallString switch is specified, return only the uninstall strings; otherwise, return the full installation objects.
            if ($UninstallString) {
                $InstallList | Select-Object -ExpandProperty UninstallString -ErrorAction SilentlyContinue
            }
            else {
                $InstallList
            }
        }
    }

    # Function to convert JSON to objects, supports empty names for elements which ConvertFrom-JSON does not
    function Convert-JSONToHashtable {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
            [string]$Json
        )
    
        begin {
            try {
                # Add the required .NET assembly for JavaScriptSerializer
                Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
            }
            catch {
                throw
            }

            try {
                # Create a JavaScriptSerializer instance
                $Serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer -ErrorAction Stop
            }
            catch {
                throw
            }
        }
    
        process {
            try {
                # Deserialize the JSON string into a .NET object
                $Object = $Serializer.DeserializeObject($Json)
                Write-Output $Object
            }
            catch {
                throw
            }
        }
    }

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    # Check if the script is running with elevated permissions (administrator rights)
    if (!(Test-IsElevated)) {
        Write-Host "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    # Search for Chrome installations on the system and enable Chrome extension search if found.
    if (Find-InstallKey -DisplayName "Chrome"){
        $ChromeInstallations = $True
    }

    # Search for Firefox installations on the system and enable Firefox extension search if found.
    if (Find-InstallKey -DisplayName "Firefox"){
        $FireFoxInstallations = $True
    }

    # Search for Edge installations on the system and flag if found and enable Edge extension search if found.
    if (Find-InstallKey -DisplayName "Edge"){  
        $EdgeInstallations = $True
    }

    # Retrieve all user profiles from the system
    $UserProfiles = Get-UserHives -Type "All"
    # Loop through each profile on the machine
    Foreach ($UserProfile in $UserProfiles) {
        # Load User ntuser.dat if it's not already loaded
        If (($ProfileWasLoaded = Test-Path Registry::HKEY_USERS\$($UserProfile.SID)) -eq $false) {
            try{
                Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg.exe LOAD HKU\$($UserProfile.SID) `"$($UserProfile.UserHive)`"" -Wait -WindowStyle Hidden
            }
            catch{
                Write-Host "[Error] Error loading the registry hive for $($UserProfile.Name)."
                Write-Host "[Error] $($_.Exception.Message)"
                $ExitCode = 1
                continue
            }
        }

        # Repeat search for installations of browsers but in the user's registry context
        if (Find-InstallKey -UserBaseKey "Registry::HKEY_USERS\$($UserProfile.SID)" -DisplayName "Chrome"){ 
            $ChromeInstallations = $True
        }
        if (Find-InstallKey -UserBaseKey "Registry::HKEY_USERS\$($UserProfile.SID)" -DisplayName "Firefox"){ 
            $FireFoxInstallations = $True
        }
        if (Find-InstallKey -UserBaseKey "Registry::HKEY_USERS\$($UserProfile.SID)" -DisplayName "Edge"){ 
            $EdgeInstallations = $True
        }

        # Unload NTuser.dat
        If ($ProfileWasLoaded -eq $false) {
            [gc]::Collect()
            Start-Sleep 1
            try{
                Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg.exe UNLOAD HKU\$($UserProfile.SID)" -Wait -WindowStyle Hidden | Out-Null
            }
            catch{
                Write-Host "[Error] Error unloading the registry hive for $($UserProfile.Name)."
                Write-Host "[Error] $($_.Exception.Message)"
                $ExitCode = 1
            }
        }
    }

    # Initialize a list to store details of detected browser extensions
    $BrowserExtensions = New-Object System.Collections.Generic.List[object]

    # If Chrome was found, search for Chrome extensions in each user's profile
    if ($ChromeInstallations) {
        Write-Host "`n[Info] A Google Chrome installation was detected. Searching Chrome for browser extensions..."
        $UserProfiles | ForEach-Object {
            $user = $_.Name
            $userPath = $_.Path

            # if the Chrome User Data folder does not exist or cannot be accessed, move on to the next object
            try{
                if (-not (Test-Path -Path "$userPath\AppData\Local\Google\Chrome\User Data" -ErrorAction Stop)){
                    Write-Host "[Warning] Chrome App Data path does not exist for $user`: $userPath\AppData\Local\Google\Chrome\User Data"
                    return
                }
            }
            catch{
                Write-Host "[Error] Chrome App Data could not be accessed for $user."
                $ExitCode = 1
                return
            }

            # if Local State file is present, parse its content. Local State file will contain info about all user profiles in the browser
            if (Test-Path -Path "$userPath\AppData\Local\Google\Chrome\User Data\Local State" -ErrorAction SilentlyContinue){
                try{
                    $AllProfiles = Get-Content -Path "$userPath\AppData\Local\Google\Chrome\User Data\Local State" -Encoding UTF8 -ErrorAction Stop -Raw
                }
                catch{
                    Write-Host "[Error] Error accessing Chrome Local State file under user $user's profile."
                    Write-Host "[Error] $($_.Exception.Message)"
                    $AllProfiles = $null
                    $ExitCode = 1
                }
                if ($AllProfiles){
                    try {
                        $AllProfiles = $AllProfiles | Convert-JSONToHashtable -ErrorAction Stop
                    }
                    catch{
                        Write-Host "[Error] Error while parsing Chrome Local State file under user $user's profile."
                        
                        # JSON errors can be very long so truncate the error message if more than 200 characters
                        if (($_.Exception.Message | Measure-Object -Character).Characters -gt 200){
                            Write-Host "[Error] $($_.Exception.Message.SubString(0,200))..."
                        }
                        else{
                            Write-Host "[Error] $($_.Exception.Message)"
                        }

                        $AllProfiles = $null
                        $ExitCode = 1
                    }
                }
            }

            # get list of preference files from the user's AppData
            $PreferenceFiles = Get-ChildItem "$userPath\AppData\Local\Google\Chrome\User Data\*\*Preferences" -Exclude "System Profile" | Select-Object -ExpandProperty FullName

            foreach ($PreferenceFile in $PreferenceFiles) {
                # read the preference file
                try{
                    $GooglePreferences = Get-Content -Path $PreferenceFile -Encoding UTF8 -ErrorAction Stop -Raw
                }
                catch{
                    Write-Host "[Error] Error reading $PreferenceFile."
                    Write-Host "[Error] $($_.Exception.Message)"
                    $ExitCode = 1
                    continue
                }

                # parse the JSON from the preference file
                try{
                    $GooglePreferences = $GooglePreferences | Convert-JSONToHashtable -ErrorAction Stop
                }
                catch{
                    Write-Host "[Error] Error parsing JSON from $PreferenceFile."

                    # JSON errors can be very long so truncate the error message if more than 200 characters
                    if (($_.Exception.Message | Measure-Object -Character).Characters -gt 200){
                        Write-Host "[Error] $($_.Exception.Message.SubString(0,200))..."
                    }
                    else{
                        Write-Host "[Error] $($_.Exception.Message)"
                    }
                    
                    $ExitCode = 1
                    continue
                }

                # if Local State file has content, read the profile Name and Signed In Account info from it
                # otherwise, get this information from the current preference file
                if ($AllProfiles){
                    $ProfileLocation = $PreferenceFile | Get-Item | Select-Object -ExpandProperty Directory | Split-Path -Leaf
                    $ProfileName = $AllProfiles.profile.info_cache.$ProfileLocation.name
                    $SignedInAccount = $AllProfiles.profile.info_cache.$ProfileLocation.user_name
                }else{
                    $ProfileName = $GooglePreferences.profile.name
                    $SignedInAccount = $GooglePreferences.account_info.email
                }

                # build extension objects and add them to the list of browser extensions
                foreach ($ExtensionID in $GooglePreferences.extensions.settings.Keys) {
                    $thisExtension = $GooglePreferences.extensions.settings.$ExtensionID

                    # if the extension is not active or the name cannot be found, skip it
                    if ($thisExtension.active_bit -eq "False" ) { continue }
                    if (!$thisExtension.manifest.name) { continue }
                    $BrowserExtensions.Add(
                        [PSCustomObject]@{
                            Browser             = "Chrome"
                            User                = $User
                            Profile             = if ($ProfileName){$ProfileName}else{"Unavailable"}
                            Name                = $thisExtension.manifest.name
                            "Extension ID"      = $ExtensionID
                            Version             = if ($thisExtension.manifest.version){$thisExtension.manifest.version}else{"Unavailable"}
                            "Signed In Account" = if ($SignedInAccount){$SignedInAccount}else{"Not signed in"}
                            Description         = $thisExtension.manifest.description
                        }
                    )
                }
            }
        }
        Write-Host ""
    }

    # If Edge was found, search for Edge extensions in each user's profile
    if ($EdgeInstallations) {
        Write-Host "[Info] A Microsoft Edge installation was detected. Searching Microsoft Edge for browser extensions..."
        $UserProfiles | ForEach-Object {
            $user = $_.Name
            $userPath = $_.Path

            # if the Edge User Data folder does not exist or cannot be accessed, move on to the next object
            try{
                if (-not (Test-Path -Path "$userPath\AppData\Local\Microsoft\Edge\User Data" -ErrorAction Stop)){
                    Write-Host "[Warning] Edge App Data path does not exist for $user`: $userPath\AppData\Local\Microsoft\Edge\User Data"
                    return
                }
            }
            catch{
                Write-Host "[Error] Edge App Data could not be accessed for $user."
                $ExitCode = 1
                return
            }

            # if Local State file is present, parse its content. Local State file will contain info about all user profiles in the browser
            if (Test-Path -Path "$userPath\AppData\Local\Microsoft\Edge\User Data\Local State" -ErrorAction SilentlyContinue){
                try{
                    $AllProfiles = Get-Content -Path "$userPath\AppData\Local\Microsoft\Edge\User Data\Local State" -Encoding UTF8 -ErrorAction Stop -Raw
                }
                catch{
                    Write-Host "[Error] Error accessing Edge Local State file under user $user's profile."
                    Write-Host "[Error] $($_.Exception.Message)"
                    $AllProfiles = $null
                    $ExitCode = 1
                }
                if ($AllProfiles){
                    try{
                        $AllProfiles = $AllProfiles | Convert-JSONToHashtable -ErrorAction Stop
                    }
                    catch{
                        Write-Host "[Error] Error while parsing Edge Local State file under user $user's profile."

                        # JSON errors can be very long so truncate the error message if more than 200 characters
                        if (($_.Exception.Message | Measure-Object -Character).Characters -gt 200){
                            Write-Host "[Error] $($_.Exception.Message.SubString(0,200))..."
                        }
                        else{
                            Write-Host "[Error] $($_.Exception.Message)"
                        }

                        $AllProfiles = $null
                        $ExitCode = 1
                    }
                }
            }

            # get list of preference files from the user's AppData
            $PreferenceFiles = Get-ChildItem "$userPath\AppData\Local\Microsoft\Edge\User Data\*\*Preferences" -Exclude "System Profile" | Select-Object -ExpandProperty FullName

            foreach ($PreferenceFile in $PreferenceFiles) {
                # read the preference file
                try{
                    $EdgePreferences = Get-Content -Path $PreferenceFile -Encoding UTF8 -ErrorAction Stop -Raw
                }
                catch{
                    Write-Host "[Error] Error reading $PreferenceFile."
                    Write-Host "[Error] $($_.Exception.Message)"
                    $ExitCode = 1
                    continue
                }

                # parse the JSON from the preference file
                try{
                    $EdgePreferences = $EdgePreferences | Convert-JSONToHashtable -ErrorAction Stop
                }
                catch{
                    Write-Host "[Error] Error parsing JSON from $PreferenceFile."

                    # JSON errors can be very long so truncate the error message if more than 200 characters
                    if (($_.Exception.Message | Measure-Object -Character).Characters -gt 200){
                        Write-Host "[Error] $($_.Exception.Message.SubString(0,200))..."
                    }
                    else{
                        Write-Host "[Error] $($_.Exception.Message)"
                    }

                    $ExitCode = 1
                    continue
                }

                # if Local State file has content, read the profile Name and Signed In Account info from it
                # otherwise, get this information from the current preference file
                if ($AllProfiles){
                    $ProfileLocation = $PreferenceFile | Get-Item | Select-Object -ExpandProperty Directory | Split-Path -Leaf
                    $ProfileName = $AllProfiles.profile.info_cache.$ProfileLocation.name
                    $SignedInAccount = $AllProfiles.profile.info_cache.$ProfileLocation.user_name
                }else{
                    $ProfileName = $EdgePreferences.profile.name
                    $SignedInAccount = $EdgePreferences.account_info.email
                }

                # build extension objects and add them to the list of browser extensions
                foreach ($ExtensionID in $EdgePreferences.extensions.settings.Keys) {
                    $thisExtension = $EdgePreferences.extensions.settings.$ExtensionID

                    # if the extension is not active or the name cannot be found, skip it
                    if ($thisExtension.active_bit -eq "False" ) { continue }
                    if (!$thisExtension.manifest.name) { continue }
                    $BrowserExtensions.Add(
                        [PSCustomObject]@{
                            Browser             = "Edge"
                            User                = $User
                            Profile             = if ($ProfileName){$ProfileName}else{"Unavailable"}
                            Name                = $thisExtension.manifest.name
                            "Extension ID"      = $ExtensionID
                            Version             = if ($thisExtension.manifest.version){$thisExtension.manifest.version}else{"Unavailable"}
                            "Signed In Account" = if ($SignedInAccount){$SignedInAccount}else{"Not signed in"}
                            Description         = $thisExtension.manifest.description
                        }
                    )
                }
            }
        }
        Write-Host ""
    }

    # If Firefox was found, search for Firefox extensions in each user's profile
    if ($FireFoxInstallations) {
        Write-Host "[Info] A Firefox installation was detected. Searching Firefox for browser extensions..." 
        $UserProfiles | ForEach-Object {
            $user = $_.Name
            $userPath = $_.Path

            # if the Firefox profiles folder does not exist or cannot be accessed, move on to the next object
            try{
                if (-not (Test-Path -Path "$userPath\AppData\Roaming\Mozilla\Firefox\Profiles" -ErrorAction Stop)){
                    Write-Host "[Warning] Firefox profiles path does not exist for $user`: $userPath\AppData\Roaming\Mozilla\Firefox\Profiles"
                    return
                }
            }
            catch{
                Write-Host "[Error] Firefox profiles path could not be accessed for $user."
                $ExitCode = 1
                return
            }

            # get list of profile folders
            $FirefoxProfileFolders = Get-ChildItem -Path "$userPath\AppData\Roaming\Mozilla\Firefox\Profiles" -Directory | Select-Object -ExpandProperty FullName

            foreach ( $FirefoxProfile in $FirefoxProfileFolders ) {
                # if extension file is not present, move on to the next profile
                if (!(Test-Path -Path "$FirefoxProfile\extensions.json")) {
                    continue
                }
                
                # get the content of the extensions.json file
                try{
                    $Extensions = Get-Content -Path "$FirefoxProfile\extensions.json" -Encoding UTF8 -ErrorAction Stop -Raw
                }
                catch{
                    Write-Host "[Error] Error reading $FireFoxProfile\extensions.json"
                    Write-Host "[Error] $($_.Exception.Message)"
                    $ExitCode = 1
                    continue
                }

                # parse the JSON from the extensions.json file
                try{
                    $Extensions = $Extensions | Convert-JSONToHashtable -ErrorAction Stop
                }
                catch{
                    Write-Host "[Error] Error parsing JSON from $FirefoxProfile\extensions.json"
                    Write-Host "[Error] $($_.Exception.Message)"
                    $ExitCode = 1
                    continue
                }

                # if signedInUser.json file is present, get the signed in user account from it
                if (Test-Path "$FirefoxProfile\signedInUser.json"){
                    # get the content of the signedInUser.json file
                    try{
                        $SignedInAccount = Get-Content -Path "$FirefoxProfile\signedInUser.json" -Encoding UTF8 -ErrorAction Stop -Raw
                    }
                    catch{
                        Write-Host "[Error] Error reading $FireFoxProfile\signedInUser.json"
                        Write-Host "[Error] $($_.Exception.Message)"
                        $SignedInAccount = "Error"
                        $ExitCode = 1
                    }

                    # if we did not fail to read the file, try to convert the JSON from the file
                    if ($SignedInAccount -ne "Error"){
                        try{
                            $SignedInAccount = ($SignedInAccount | Convert-JSONToHashtable -ErrorAction Stop).accountData.email
                        }
                        catch{
                            Write-Host "[Error] Error parsing JSON from $FirefoxProfile\signedInUser.json"
                            Write-Host "[Error] $($_.Exception.Message)"
                            $SignedInAccount = "Error"
                            $ExitCode = 1
                        }
                    }
                }
                elseif ($SignedInAccount){
                    $SignedInAccount = $null
                }

                # build extension objects and add them to the list of browser extensions
                foreach ($Extension in $Extensions.addons) {
                    $BrowserExtensions.Add(
                        [PSCustomObject]@{
                            Browser             = "Firefox"
                            User                = $_.Name
                            Profile             = ($FirefoxProfile | Split-Path -Leaf) -replace ".+\."
                            Name                = $Extension.defaultLocale.name
                            "Extension ID"      = $Extension.id
                            Version             = if ($Extension.version){$Extension.version}else{"Unavailable"}
                            "Signed In Account" = if ($SignedInAccount){$SignedInAccount}else{"Not signed in"}
                            Description         = $Extension.defaultLocale.description
                        }
                    )
                }
            }
        }
        Write-Host ""
    }

    # Check if there are any browser extensions to process
    if ($BrowserExtensions.Count -gt 0) {
        Write-Host "[Info] Browser extensions were detected.`n"

        # sort list of browser extensions
        $BrowserExtensions = $BrowserExtensions | Sort-Object Browser, User, Profile, Name

        # Format the BrowserExtensions list to include a shortened description if the description is too long.
        $BrowserExtensions = $BrowserExtensions | Select-Object Browser, User, Profile, Name, "Extension ID", Version, "Signed In Account", @{
            Name       = "Description"
            Expression = {
                $Characters = $_.Description | Measure-Object -Character | Select-Object -ExpandProperty Characters
                if ($Characters -gt 75) {
                    "$(($_.Description).SubString(0,75))(...)"
                }
                else {
                    $_.Description
                }
            }
        }

        # if provided, write to Multiline Custom Field
        if ($MultilineCustomField){
            # set the character limit for Multiline Custom Fields
            $multilineCharacterThreshold = 9500

            # create string format to use for the multiline field
            $multilineStringFormat = {
                "User: $($_.User), Profile: $($_.Profile), Name: $($_.Name), " +
                "Extension ID: $($_.'Extension ID'), Version: $($_.Version), " +
                "Signed In Account: $($_.'Signed In Account')"
            }

            # create separate strings for each browser
            $EdgeList = $BrowserExtensions | Where-Object { $_.Browser -eq "Edge" } | ForEach-Object $multilineStringFormat
            $ChromeList = $BrowserExtensions | Where-Object { $_.Browser -eq "Chrome" } | ForEach-Object $multilineStringFormat
            $FireFoxList = $BrowserExtensions | Where-Object { $_.Browser -eq "Firefox" } | ForEach-Object $multilineStringFormat

            # Construct the formatted output
            $formattedMultilineString = @"
Microsoft Edge:
$(if ($EdgeList) { $EdgeList -join "`n" } else { "No extensions found." })

Google Chrome:
$(if ($ChromeList) { $ChromeList -join "`n" } else { "No extensions found." })

Mozilla Firefox:
$(if ($FireFoxList) { $FireFoxList -join "`n" } else { "No extensions found." })
"@

            # Measure the total character count of the formatted string
            $Characters = $formattedMultilineString | Measure-Object -Character | Select-Object -ExpandProperty Characters

            # check if output would exceed Multiline Custom Field character limit and truncate if so
            if ($Characters -ge $multilineCharacterThreshold) {
                Write-Host "[Warning] 10,000 Character Limit for Multiline fields has been reached! Trimming output until the character limit is satisfied..."
                
                # add note to the top of the multiline field that the extensions have been truncated
                $formattedMultilineString = $formattedMultilineString -replace "^(Microsoft Edge:|Google Chrome:|Mozilla Firefox:)", "`nThis info has been truncated to accommodate the 10,000 character limit.`n`n`$1"

                # regex to extract rows from the multiline field
                $rowRegex = "(User:.*?Signed In Account:.*(\n|$))|(Microsoft Edge:|Google Chrome:|Mozilla Firefox:|No extensions found.)"

                $lastRowStep = 1
                while ($Characters -ge $multilineCharacterThreshold){
                    # create a collection of rows in the table
                    $rows = [regex]::Matches($formattedMultilineString, $rowRegex)

                    # get the value of the last row
                    $lastRowValue = $rows[$rows.Count - $lastRowStep].Value

                    # skip rows we want to keep in the multiline field
                    if ($lastRowValue -match "(Microsoft Edge:|Google Chrome:|Mozilla Firefox:|No extensions found\.)"){
                        $lastRowStep++
                        continue
                    }

                    # get the value of the row above the last row
                    $rowAboveLastRow = $rows[$rows.Count - $lastRowStep - 1].Value

                    # remove the last row from the table
                    $formattedMultilineString = $formattedMultilineString -replace [regex]::Escape($lastRowValue)
                    
                    # if the row above the last row is the browser header, add a note underneath
                    if ($rowAboveLastRow -match "(Microsoft Edge:|Google Chrome:|Mozilla Firefox:)"){
                        $formattedMultilineString = $formattedMultilineString -replace [regex]::Escape($rowAboveLastRow), "$rowAboveLastRow`nAll extensions have been truncated."
                    }

                    # set LastRowStep back to 1 in case it was incremented
                    $lastRowStep = 1
                    
                    # Check that we now comply with the character limit. If not restart the do loop.
                    $Characters = $formattedMultilineString | Measure-Object -Character | Select-Object -ExpandProperty Characters
                }
            }

            try{
                Write-Host "[Info] Publishing browser extensions to Multiline Custom Field '$MultilineCustomField'."
                Set-CustomField -Name $MultilineCustomField -Value $formattedMultilineString -Type "Multiline"
                Write-Host "[Info] Successfully set '$MultilineCustomField' Custom Field!`n"
            }
            catch{
                Write-Host "[Error] Error setting '$MultilineCustomField'."
                Write-Host "[Error] $($_.Exception.Message)`n"
                $ExitCode = 1
            }
        }

        # if provided, write to WYSIWYG Custom Field
        if ($WysiwygCustomField){
            # set the character limit for WYSIWYG fields
            $wysiwygCharacterThreshold = 44500
            
            # Convert the matching events into an HTML report.
            $htmlTable = $BrowserExtensions | ConvertTo-Html -Fragment

            # Format width and style of table columns
            $htmlTable = $htmlTable -replace "<th>Browser", "<th style='width:75px;'><b>Browser</b>"
            $htmlTable = $htmlTable -replace "<th>Profile", "<th style='width:130px;'><b>Profile</b>"
            $htmlTable = $htmlTable -replace "<th>Version", "<th><b>Version</b>"
            $htmlTable = $htmlTable -replace "<th>Description", "<th style='width:320px;'><b>Description</b>"
            $htmlTable = $htmlTable -replace "<th>User", "<th style='width:130px;'><b>User</b>"
            $htmlTable = $htmlTable -replace "<th>Name", "<th><b>Name</b>"
            $htmlTable = $htmlTable -replace "<th>Extension ID", "<th style='width:280px;'><b>Extension ID</b>"
            $htmlTable = $htmlTable -replace "<th>Signed In Account", "<th><b>Signed In Account</b>"

            # wrap table in a card layout
            $HtmlTable = "<div class='card flex-grow-1'>
                            <div class='card-title-box'>
                                <div class='card-title'><i class='fa-solid fa-globe'></i>&nbsp;&nbsp;Browser Extensions</div>
                            </div>
                            <div class='card-body' style='white-space: nowrap;'>
                                $HtmlTable
                            </div>
                        </div>"
    
            # Check that the output complies with the hard character limits.
            $Characters = $htmlTable | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters

            # if output exceeds the WYSIWYG character limit, truncate the output
            if ($Characters -ge $wysiwygCharacterThreshold) {
                Write-Host "[Warning] 45,000 Character Limit for WYSIWYG fields has been reached! Trimming output until the character limit is satisfied..."

                # add notice about truncation to the top of the table
                $htmlTable = $htmlTable -replace "<table>", "<p>This info has been truncated to accommodate the 45,000 character limit.</p><table>"

                # regex expression to match tables in the HTML
                $rowRegex = '<tr>.*?</tr>'

                while ($Characters -ge $wysiwygCharacterThreshold) {
                    # create a collection of rows in the table
                    $rows = [regex]::Matches($htmlTable, $rowRegex)

                    # get the value of the last row
                    $lastRowValue = $rows[$rows.Count - 1].Value

                    # remove the last row from the table
                    $htmlTable = $htmlTable -replace [regex]::Escape($lastRowValue)

                    # Check that we now comply with the character limit. If not restart the do loop.
                    $Characters = $htmlTable | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
                }
            }

            # write the HTML table to the WYSIWYG Custom Field
            try{
                Write-Host "[Info] Publishing browser extensions table to WYSIWYG Custom Field '$WYSIWYGCustomField'."
                Set-CustomField -Name $WYSIWYGCustomField -Value $htmlTable -Type "WYSIWYG"
                Write-Host "[Info] Successfully set '$WYSIWYGCustomField' Custom Field!`n"
            }
            catch{
                Write-Host "[Error] Error setting '$WYSIWYGCustomField'."
                Write-Host "[Error] $($_.Exception.Message)`n"
                $ExitCode = 1
            }
        }

        # check if output would exceed Activity Feed character limit and truncate if so
        if (($BrowserExtensions | Format-List | Out-String | Measure-Object -Character | Select-Object -Expand Characters) -ge 9500){
            Write-Host "[Warning] 10,000 Character Limit for the Activity Feed has been reached! Trimming output until the character limit is satisfied..."

            if (-not $WysiwygCustomField){
                Write-Host "[Warning] Please publish this report to a WYSIWYG field for a full listing of extensions."
            }
            
            # truncate the output by removing the last object until we are under the limit
            do {
                $BrowserExtensions = $BrowserExtensions | Select-Object -SkipLast 1

                # Check that we now comply with the character limit. If not restart the do loop.
                $Characters = $BrowserExtensions | Format-List | Out-String | Measure-Object -Character | Select-Object -ExpandProperty Characters
            } while ($Characters -ge 9500)

            # format the output and write it to the Activity Feed
            ($BrowserExtensions | Format-List | Out-String).TrimEnd() + "`n`n(...)" | Write-Host
        }
        else{
            # format the output and write it to the Activity Feed
            ($BrowserExtensions | Format-List | Out-String).Trim() | Write-Host
        }
    }
    else {
        Write-Host "[Info] No browser extensions were found!"
    }

    exit $ExitCode
}
end {
    
    
    
}