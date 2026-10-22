#Requires -Version 5

<#
.SYNOPSIS
    Generates a report of users whose passwords are nearing expiration, including both Active Directory domain and local accounts. Outputs an alert if any expiring accounts are found.
.DESCRIPTION
    Generates a report of users whose passwords are nearing expiration, including both Active Directory domain and local accounts. Outputs an alert if any expiring accounts are found.
.LINK
    https://ninjarmm.zendesk.com/hc/en-us/articles/206864826-Policies-Condition-Configuration
.EXAMPLE
    -DaysUntilExpiration 999999999999 - On a Workstation

    [Info] Not a Domain Controller. Checking the domain users on this machine...
    [Info] Not a Domain Controller. Checking all local users on this machine...
    [Alert] Users with passwords expiring in 999999999999 day(s) were found!

    Username        User Principal Name      E-mail Address     Password Expiration Date 
    --------        -------------------      --------------     ------------------------ 
    cheart          cheart@test.lan          cheart@example.com 11/4/2024 6:01:44 PM     
    s     user      s     user@test.lan                         11/5/2024 9:06:30 AM     
    s        us'er' s        us'er'@test.lan                    11/5/2024 9:35:08 AM     
    s        us'er  s        us'er@test.lan                     11/5/2024 9:44:57 AM     
    suse)r9         suse)r9@test.lan                            11/5/2024 9:39:38 AM     
.EXAMPLE
    -DaysUntilExpiration 14 - On a Workstation

    [Info] Not a Domain Controller. Checking the domain users on this machine...
    [Info] Not a Domain Controller. Checking all local users on this machine...
    [Info] No users with expiring passwords found!

.EXAMPLE
    -DaysUntilExpiration 999999999999 - On a Domain Controller

    [Info] This is a domain controller. Checking all users...
    [Alert] Users with passwords expiring in 999999999999 day(s) were found!

    Username         User Principal Name       E-mail Address     Password Expiration Date
    --------         -------------------       --------------     ------------------------
    tuser1           tuser1@test.lan           tuser1@example.com 11/4/2024 8:13:59 AM    
    tuser2           tuser2@test.lan           tuser2@example.com 11/4/2024 8:13:59 AM    
    tuser3           tuser3@test.lan           tuser3@example.com 11/4/2024 8:13:59 AM    
    tuser4           tuser4@test.lan           tuser4@example.com 11/4/2024 8:13:59 AM    
    tuser5           tuser5@test.lan           tuser5@example.com 11/4/2024 8:13:59 AM    
    tuser6           tuser6@test.lan           tuser6@example.com 11/4/2024 8:13:59 AM    
    tuser7           tuser7@test.lan           tuser7@example.com 11/4/2024 8:13:59 AM    
    tuser8           tuser8@test.lan           tuser8@example.com 11/4/2024 8:14:00 AM    
    tuser9           tuser9@test.lan           tuser9@example.com 11/5/2024 10:39:20 AM   
    cheart           cheart@test.lan           cheart@example.com 11/4/2024 5:01:44 PM    
    s     user       s     user@test.lan                          11/5/2024 8:06:29 AM    
    s        us'er'  s        us'er'@test.lan                     11/5/2024 8:35:08 AM    
    s          user' s          user'@test.lan                    11/5/2024 8:35:37 AM    
    s        us'er   s        us'er@test.lan                      11/5/2024 8:44:57 AM    
    suse)r9          suse)r9@test.lan                             11/5/2024 8:39:38 AM      

.EXAMPLE
    -DaysUntilExpiration 14 - On a Domain Controller

    [Info] This is a domain controller. Checking all users...
    [Info] No users with expiring passwords found!

PARAMETER: -DaysUntilExpiration "ReplaceWithAnyNumber"
    Users whose passwords expire within the specified number of days will be included in the report and trigger an alert.

PARAMETER: -CurrentUsers
    Only users that are currently logged in will be included in the report and trigger an alert.

PARAMETER: -CustomFieldName "ReplaceMeWithAnyMultilineCustomField"
    Optionally specify the name of a multiline custom field to export the results to.

PARAMETER: -ExcludeFGPPUsers
    Choose to exclude users with Fine Grained Password Policies from the report. This option has no effect when the script is ran on a domain controller.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.1
    Release Notes: Updated script to work in any language/culture. Added detection for users with Fine Grained Password Policies and added parameter to exclude them from the report. 

#>

[CmdletBinding()]
param (
    [Parameter()]
    $DaysUntilExpiration = "14",
    [Parameter()]
    [Switch]$CurrentUsers = [System.Convert]::ToBoolean($env:loggedInUsersOnly),
    [Parameter()]
    [String]$CustomFieldName,
    [Parameter()]
    [switch]$ExcludeFGPPUsers = [System.Convert]::ToBoolean($env:ExcludeFineGrainedPasswordPolicyUsersOnWorkstations)
)

begin {
    # If script form variables are used, replace the command line parameters with their value.
    if ($env:daysUntilPasswordExpiration) { $DaysUntilExpiration = $env:daysUntilPasswordExpiration }
    if ($env:customFieldName) { $CustomFieldName = $env:customFieldName }

    # Check if $DaysUntilExpiration is not provided (null or empty). 
    # If it is missing, output an error message and exit the script.
    if (!$DaysUntilExpiration) {
        Write-Host -Object "[Error] You must provide a valid expiration cutoff."
        exit 1
    }

    # Check if $DaysUntilExpiration contains any non-numeric characters (using regex).
    # If it contains anything other than digits, output an error message and exit.
    if ($DaysUntilExpiration -match '[^0-9]') {
        Write-Host -Object "[Error] An invalid expiration cutoff of '$DaysUntilExpiration' was provided. Please provide a positive whole number that is greater than 0."
        exit 1
    }

    # Attempt to cast $DaysUntilExpiration to a long integer.
    # If an exception occurs during the conversion, output an error message and exit.
    try {
        $ErrorActionPreference = "Stop"
        $DaysUntilExpiration = [long]$DaysUntilExpiration
        $ErrorActionPreference = "Continue"
    }
    catch {
        Write-Host -Object "[Error] An invalid expiration cutoff of '$DaysUntilExpiration' was provided. Please provide a positive whole number that is greater than 0."
        Write-Host -Object "[Error] $($_.Exception.Message)."
        exit 1
    }

    # Check if $DaysUntilExpiration is less than 1 (i.e., not a positive whole number).
    # If it's invalid, output an error message and exit the script.
    if ($DaysUntilExpiration -lt 1) {
        Write-Host -Object "[Error] An invalid expiration cutoff of '$DaysUntilExpiration' was provided. Please provide a positive whole number that is greater than 0."
        exit 1
    }

    function Test-IsElevated {
        # Get the current Windows identity of the user running the script
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    
        # Create a WindowsPrincipal object based on the current identity
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
    
        # Check if the current user is in the Administrator role
        # The function returns $True if the user has administrative privileges, $False otherwise
        # 544 is the value for the Built In Administrators role
        # Reference: https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsbuiltinrole?view=netframework-4.8.1
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]'544')
    }

    function Test-IsDomainController {
        # Determine the method to retrieve the operating system information based on PowerShell version
        try {
            $OS = if ($PSVersionTable.PSVersion.Major -lt 3) {
                Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
            }
            else {
                Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            }
        }
        catch {
            Write-Host -Object "[Error] Unable to validate whether or not this device is a domain controller."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    
        # Check if the ProductType is "2", which indicates that the system is a domain controller
        if ($OS.ProductType -eq "2") {
            return $true
        }
    }

    function Test-IsEntraJoined {
        # Check if the operating system version is Windows 10 or higher
        if ([environment]::OSVersion.Version.Major -ge 10) {
            # Run the dsregcmd.exe tool to check Entra join status and look for "AzureAdJoined : YES"
            $dsreg = dsregcmd.exe /status | Select-String "AzureAdJoined : YES"
        }
    
        # If the search found the "AzureAdJoined : YES" string, return True, otherwise return False
        if ($dsreg) { return $True }else { return $False }
    }

    function Test-IsDomainJoined {
        # Check the PowerShell version to determine the appropriate cmdlet to use
        try {
            if ($PSVersionTable.PSVersion.Major -lt 3) {
                return $(Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
            }
            else {
                return $(Get-CimInstance -Class Win32_ComputerSystem).PartOfDomain
            }
        }
        catch {
            Write-Host -Object "[Error] Unable to validate whether or not this device is a part of a domain."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    function Get-QUser {
        $quser = quser.exe
        $quser -replace '\s{2,}', ',' -replace '>' | ConvertFrom-Csv
    }

    function Test-IsDomainReachable {
        try {
            $searcher = [adsisearcher]"(&(objectCategory=computer)(name=$env:ComputerName))"
            $searcher.FindOne()
        }
        catch {
            Write-Host -Object "[Error] Failed to connect to the domain!"
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $False
        }
    }

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
            Write-Host -Object "[Error] Failed to scan registry keys at 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
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
            Write-Host -Object "[Error] Failed to gather complete profile information."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        $CompleteUserProfiles = $UserProfiles | ForEach-Object {
            $SID = $_.SID
            $Win32Object = $AllAccounts | Where-Object { $_.SID -like $SID }

            if ($Win32Object) {
                $Win32Object | Add-Member -NotePropertyName UserHive -NotePropertyValue $_.UserHive
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

    function Set-NinjaProperty {
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
  

    # Attempt to retrieve the current datetime using Get-Date. 
    try {
        $Today = Get-Date -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] Failed to retrieve current date."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    # Check if the script is being run with elevated (Administrator) privileges.
    # If not, output an error message and exit the script.
    if (!(Test-IsElevated)) {
        Write-Host "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    # Check if the machine is joined to Microsoft Entra. 
    # If true, output a warning that the script cannot check Entra accounts but will check local accounts.
    if (Test-IsEntraJoined) {
        Write-Host "[Warning] This script is unable to check Microsoft Entra accounts, however, the script will check the local accounts on the machine."
    }

    # If $CurrentUsers is defined, retrieve the active users on the machine using Get-Quser.
    if ($CurrentUsers) {
        $ActiveUsers = Get-Quser

        # get all property names of the $ActiveUsers object
        $properties = ($ActiveUsers | Get-Member -MemberType NoteProperty).Name
        
        # get all the values of these properties into a string array. this will later be used to filter the password expiration report to only logged on users
        $ActiveUsersValues = foreach ($prop in $properties){$activeusers.$prop}
    }

    # Initialize an empty list to store users that will be reported.
    $UsersToReport = New-Object System.Collections.Generic.List[object]

    $IsDomainController = Test-IsDomainController
    # Check if the machine is a domain controller. If it is, proceed with checking all domain users.
    if ($IsDomainController) {
        Write-Host "[Info] This is a domain controller. Checking all users..."

        if ($ExcludeFGPPUsers){
            Write-Host "[Warning] The 'Exclude Fine Grained Password Policy Users' option has no effect on domain controllers."
        }

        try {
            # Set error handling to stop on errors, and retrieve all Active Directory users with expiring passwords.
            $ErrorActionPreference = "Stop"
            $AllActiveDirectoryUsers = Get-ADUser -Filter { Enabled -eq $True -and PasswordNeverExpires -eq $False } -Properties SamAccountName, UserPrincipalName, mail, pwdLastSet, msDS-UserPasswordExpiryTimeComputed 
            
            # Select and format the relevant user properties for reporting.
            $AllActiveDirectoryUsers = $AllActiveDirectoryUsers | Select-Object @{ Name = "Username"; Expression = { $_.SamAccountName } },
            @{ Name = "User Principal Name"; Expression = { $_.UserPrincipalName } },
            @{ Name = "E-mail Address"; Expression = { $_.mail } }, 
            @{ Name = "Password Expiration Date"; Expression = { 
                    if ($_.pwdLastSet -eq 0) { 
                        "Must change at next logon" 
                    }
                    else { 
                        [datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed") 
                    } 
                } 
            }

            # Reset error handling to continue after retrieving the users.
            $ErrorActionPreference = "Continue"
        }
        catch {
            # If retrieving users fails, output an error message and exit the script.
            Write-Host -Object "[Error] Failed to retrieve expiring Active Directory user accounts."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        # Filter the users to find those with passwords expiring within the specified timeframe or on the next logon.
        try {
            $ExpiringADUsers = $AllActiveDirectoryUsers | Where-Object { $_."Password Expiration Date" -and $_."Password Expiration Date" -ne "Must change at next logon" -and ((New-TimeSpan $Today $_."Password Expiration Date" -ErrorAction Stop).Days -lt $DaysUntilExpiration -or $DaysUntilExpiration -eq 0) }
            $ExpiredADUsers = $AllActiveDirectoryUsers | Where-Object { $_."Password Expiration Date" -eq "Must change at next logon" }
        }
        catch {
            Write-Host -Object "[Error] Failed to compute the password expiration timespan."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        # If $ActiveUsers is defined, further filter the users to include only those who are currently logged in.
        if ($ActiveUsers) {
            $ExpiringADUsers = $ExpiringADUsers | Where-Object { $ActiveUsers.Username -contains $_.Username }
            $ExpiredADUsers = $ExpiredADUsers | Where-Object { $ActiveUsers.Username -contains $_.Username }
        }

        # Add expiring users and expired users to the report list.
        if ($ExpiringADUsers) { $ExpiringADUsers | ForEach-Object { $UsersToReport.Add($_) } }
        if ($ExpiredADUsers) { $ExpiredADUsers | ForEach-Object { $UsersToReport.Add($_) } }
    }

    # Check if the machine is domain-joined but not a domain controller.
    # If true, it will check domain users logged into this machine.
    if ((Test-IsDomainJoined) -and !($IsDomainController)) {
        Write-Host "[Info] Not a Domain Controller. Checking the domain users on this machine..."

        # If the domain controller is unreachable, display an error that not all domain users may be included.
        if (!(Test-IsDomainReachable)) {
            Write-Host -Object "[Error] A secure connection to the domain controller could not be established. Some domain users may be missing from the results."
            $ExitCode = 1
        }

        # Retrieve previously logged-in domain accounts that have expiring passwords.
        $PreviouslyLoggedInDomainAccounts = Get-UserHives | Where-Object { -not $_.Disabled -and $_.Domain -eq $env:USERDOMAIN -and $_.PasswordExpires }
        $UsersWithExpiration = New-Object System.Collections.Generic.List[Object]

        # Loop through the previously logged-in domain accounts.
        $PreviouslyLoggedInDomainAccounts | ForEach-Object {
            # Check if the domain is reachable. If not, display an error and skip further processing.
            if (!(Test-IsDomainReachable -ErrorAction SilentlyContinue)) {
                Write-Host -Object "[Error] Unable to check '$($_.Name)' while the computer is disconnected from the domain!"
                $ExitCode = 1
                return
            }

            # Extract user information from ADSI
            $Username = $_.Name
            try{
                # set up ADSI searcher object
                $searcher = [adsisearcher]""
                
                # get max password age from domain root
                $searcher.Filter = ""
                $maxPasswordAge = [System.TimeSpan]::FromTicks($searcher.FindOne().Properties['maxpwdage'][0] * -1)
                
                # change filter so we can get user information
                $searcher.Filter = "samaccountname=$Username"
                
                # get the password last set date for the user
                $LastSetTime = [datetime]::FromFileTime($searcher.FindOne().Properties['pwdlastset'][0])
                
                # expirationDate is the password last set date plus the maximum password age
                $expirationDate = $lastSetTime + $maxPasswordAge
            }
            catch{
                Write-Host "[Error] Error while trying to determine the password expiration date for '$Username'."
                Write-Host "$($_.Exception.Message)"
                $ExitCode = 1
                return
            }
            
            # check if user has a Fine Grained Password Policy applied
            try{
                # initialize usingFGPP variable to False
                $usingFGPP = $false

                # search user first
                if ($searcher.FindOne().Properties."msds-psoapplied"){
                    $usingFGPP = $true
                }
                else{
                    # if not user, then search each group user is a member of
                    $groups = $searcher.FindOne().Properties.memberof

                    foreach ($group in $groups){
                        $searcher.Filter = "distinguishedName=$group"

                        if ($searcher.FindOne().Properties."msds-psoapplied"){
                            # if a group the user is a member of has this property, it is using a FGPP. set the variable to True and break out of the loop
                            $usingFGPP = $true
                            break
                        }
                    }
                    # put the search filter back to the user
                    $searcher.Filter = "samaccountname=$Username"
                }
            }
            catch{
                Write-Host "[Error] Error while determining if '$Username' is using a Fine Grained Password Policy."
                Write-Host "$($_.Exception.Message)"
                $ExitCode = 1
                return
            }

            # if FGPP users are excluded, and this user is using FGPP, continue to the next user
            if ($ExcludeFGPPUsers -and $usingFGPP){
                return
            }

            # Construct the expiring user object.
            try{
                $ExpiringDomainUser = [PSCustomObject]@{
                    Username                   = $Username
                    "User Principal Name"      = $searcher.FindOne().Properties.userprincipalname | Select-Object -First 1
                    "E-mail Address"           = $searcher.FindOne().Properties.mail | Select-Object -First 1
                    "Password Expiration Date" = $(
                            if ($searcher.FindOne().Properties.pwdlastset -like 0){
                                "Must change at next logon" 
                            }
                            elseif ($usingFGPP){
                                "Using Fine Grained Password Policy"
                            }
                            else{
                                $expirationDate
                            }
                    )
                }
                # add expiring user object to list
                $UsersWithExpiration.Add($ExpiringDomainUser)
            }
            catch{
                Write-Host "[Error] Error creating expiring user object for '$Username'."
                Write-Host "$($_.Exception.Message)"
                $ExitCode = 1
            }
        }

        # If active users are defined, filter the users to include only those currently logged in.
        if ($ActiveUsers) {
            $UsersWithExpiration = $UsersWithExpiration | Where-Object {$_.Username -in $ActiveUsersValues}
        }

        if ($UsersWithExpiration."Password Expiration Date" -match "Fine Grained Password Policy"){
            Write-Host "`n[Warning] A user with a Fine Grained Password Policy has been detected. When not running on a domain controller, this script cannot calculate password expiration for users with these policies. Learn more: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/adac/fine-grained-password-policies?tabs=adac`n"
        }

        # Process each user with expiring passwords
        $UsersWithExpiration | ForEach-Object {
            $ExpiringUser = $_
            try {
                # Filter expiring user based on password expiration dates.
                $ErrorActionPreference = "Stop"

                # if the Password Expiration Date is an actual date, exclude it if it does not expire within the $DaysUntilExpiration threshold
                if ($ExpiringUser."Password Expiration Date" -is [datetime]){
                    $ExpiringUser = $ExpiringUser | Where-Object {((New-TimeSpan $Today $_."Password Expiration Date" -ErrorAction Stop).Days -lt $DaysUntilExpiration)}
                }
                
                $ErrorActionPreference = "Continue"
            }
            catch {
                Write-Host -Object "[Error] Failed to compute password expiration timespan for '$Username'."
                Write-Host -Object "[Error] $($_.Exception.Message)"
                $ExitCode = 1
                $ErrorActionPreference = "Continue"
                return
            }

            # Add the expiring user to the report if it is still present
            if ($ExpiringUser) {
                $UsersToReport.Add($ExpiringUser)
            }
        }
    }

    # Check if the machine is not a domain controller. If not, proceed to check local user accounts.
    if (!($IsDomainController)) {
        Write-Host "[Info] Not a Domain Controller. Checking all local users on this machine..."

        try {
            # Retrieve local users whose accounts are enabled and have expiring passwords.
            $LocalUsers = Get-LocalUser -ErrorAction Stop | Where-Object { $_.Enabled -and $_.PasswordExpires -and ((New-TimeSpan $Today $_.PasswordExpires -ErrorAction Stop).Days -lt $DaysUntilExpiration) }

            # Retrieve local users whose passwords have never been set (expired users).
            $ExpiredLocalUsers = Get-LocalUser -ErrorAction Stop | Where-Object { $_.Enabled -and -not $_.PasswordLastSet }
        }
        catch {
            # If any errors occur during the retrieval of local users or computing the password expiration timespan, output an error message.
            Write-Host -Object "[Error] Failed to retrieve local users and compute the password expiration timespan."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }

        # If there are active users logged in, filter the users to include only those currently logged in.
        if ($ActiveUsers) {
            $LocalUsers = $LocalUsers | Where-Object { $_.Name -in $ActiveUsersValues }
            $ExpiredLocalUsers = $ExpiredLocalUsers | Where-Object { $_.Name -in $ActiveUsersValues }
        }

        # Add local users with expiring passwords to the report.
        $LocalUsers | ForEach-Object {
            $UserObject = [PSCustomObject]@{
                Username                   = $_.Name
                "Password Expiration Date" = $_.PasswordExpires
            }

            $UsersToReport.Add($UserObject)
        }

        # Add local users whose passwords are set to change at next logon to the report.
        $ExpiredLocalUsers | ForEach-Object {
            $UserObject = [PSCustomObject]@{
                Username                   = $_.Name
                "Password Expiration Date" = "Must change at next logon"
            }

            $UsersToReport.Add($UserObject)
        }
    }

    # If users with expiring passwords are found, display an alert and format the report for output.
    if ($UsersToReport) {
        Write-Host "[Alert] Users with passwords expiring in $DaysUntilExpiration day(s) were found!"

        # Format the report to display the users with expiring passwords.
        $Report = $UsersToReport | Format-Table | Out-String

        # Prepare the custom field value based on the formatted user data.
        $CustomFieldValue = ($UsersToReport | Format-List | Out-String).Trim()

        # Output the report to the console.
        Write-Host $Report
    }
    else {
        # If no users with expiring passwords are found, display a message.
        $Report = "No users with expiring passwords found!"
        # Set the custom field value to match the report.
        $CustomFieldValue = $Report
        # Output the report to the console.
        Write-Host "[Info] $Report"
    }

    # If a custom field name is provided, attempt to set the custom field with the report value.
    if ($CustomFieldName) {
        try {
            Write-Host "[Info] Attempting to set Custom Field '$CustomFieldName'."
            Set-NinjaProperty -Name $CustomFieldName -Value $CustomFieldValue
            Write-Host "[Info] Successfully set Custom Field '$CustomFieldName'!"
        }
        catch {
            Write-Host "[Error] Error while trying to write to Custom Field '$CustomFieldName'."
            Write-Host "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    exit $ExitCode
}
end {
    
    
    
}
