#Requires -Version 5.1

<#
.SYNOPSIS
    Set the support contact and website information for a device as well as the model and manufacturer. This information is displayed in the "About" or "PC Info" section in the Settings app, and in the "System" section of the Control Panel. 

.DESCRIPTION
    Set the support contact and website information for a device as well as the model and manufacturer. This information is displayed in the "About" or "PC Info" section in the Settings app, and in the "System" section of the Control Panel. 

.PARAMETER -Manufacturer
    Enter the desired manufacturer label for the device. Input is limited to 255 characters. Note that in the Settings app, either Support URL or Support Phone must be populated in order for the Manufacturer setting to display. "

.PARAMETER -SupportPhone
    Enter the support phone number. Input is limited to 20 characters.

.PARAMETER -SupportURL
    Enter the support URL. Must be an HTTPS URL.

.PARAMETER -SupportHours
    Enter the hours that support is available. Input is limited to 255 characters. Note that in the Settings app, either Support URL or Support Phone must be populated in order for the Support Hours setting to display. "

.PARAMETER -Model
    Enter the desired model label for the device. Input is limited to 255 characters.

.PARAMETER -RemoveIfBlank
    Check this box to remove any of the above script variables that are left blank.

.EXAMPLE
    -Manufacturer "Test" -Model "Test" -SupportURL "https://google.com"
    
    [Info] Setting Manufacturer to 'Test'.
    Set HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation\Manufacturer to 'Test'.

    [Info] Setting SupportURL to 'https://google.com'.
    Set HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation\SupportURL to 'https://google.com'.

    [Info] Setting Model to 'Test'.
    Set HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation\Model to 'Test'.

.EXAMPLE
    -Manufacturer "" -Model "Test" -SupportURL "" -SupportHours "" -SupportPhone "" -RemoveIfBlank

    [Info] Removing blank items from HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation registry key.

    [Info] Current value of HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation\Manufacturer: 'Test'
    [Info] Removing the registry value for Manufacturer.
    [Info] Successfully removed the registry value for Manufacturer!

    [Info] Current value of HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation\SupportHours: 'Test'
    [Info] Removing the registry value for Support Hours.
    [Info] Successfully removed the registry value for Support Hours!

    [Info] Current value of HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation\SupportURL: 'https://google.com'
    [Info] Removing the registry value for Support URL.
    [Info] Successfully removed the registry value for Support URL!

    [Info] Current value of HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation\SupportPhone: 'Test'
    [Info] Removing the registry value for Support Phone.
    [Info] Successfully removed the registry value for Support Phone!

    [Info] Finished removing blank items.

    [Info] Setting the registry value for Model to 'Test'.
    HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation\Model is already the value 'Test'.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$Manufacturer,

    [Parameter()]
    [string]$SupportPhone,

    [Parameter()]
    [string]$SupportURL,

    [Parameter()]
    [string]$SupportHours,

    [Parameter()]
    [string]$Model,

    [Parameter()]
    [switch]$RemoveIfBlank = [System.Convert]::ToBoolean($env:removeIfBlank)
)

begin {
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:Manufacturer)){
        $Manufacturer = $env:Manufacturer
    }

    if (-not [string]::IsNullOrWhiteSpace($env:SupportPhone)){
        $SupportPhone = $env:SupportPhone
    }

    if (-not [string]::IsNullOrWhiteSpace($env:SupportURL)){
        $SupportURL = $env:SupportURL
    }

    if (-not [string]::IsNullOrWhiteSpace($env:SupportHours)){
        $SupportHours = $env:SupportHours
    }

    if (-not [string]::IsNullOrWhiteSpace($env:Model)){
        $Model = $env:Model
    }

    $ExitCode = 0

    if ($Manufacturer){
        # test for character limit
        $characterCount = (Measure-Object -InputObject $Manufacturer -Character).Characters 
        if ($characterCount -gt 255){
            Write-Host "[Error] The input value for Manufacturer is limited to 255 characters. Your input is $characterCount characters long."
            $Manufacturer = $null
            $ExitCode = 1
        }
    }

    if ($SupportPhone){
        # test for character limit
        $characterCount = (Measure-Object -InputObject $SupportPhone -Character).Characters 
        if ($characterCount -gt 20){
            Write-Host "[Error] The input value for Support Phone is limited to 20 characters. Your input is $characterCount characters long."
            $SupportPhone = $null
            $ExitCode = 1
        }
    }

    if ($SupportHours){
        # test for character limit
        $characterCount = (Measure-Object -InputObject $SupportHours -Character).Characters 
        if ($characterCount -gt 255){
            Write-Host "[Error] The input value for Support Hours is limited to 255 characters. Your input is $characterCount characters long."
            $SupportHours = $null
            $ExitCode = 1
        }
    }

    if ($Model){
        # test for character limit
        $characterCount = (Measure-Object -InputObject $Model -Character).Characters 
        if ($characterCount -gt 255){
            Write-Host "[Error] The input value for Model is limited to 255 characters. Your input is $characterCount characters long."
            $Model = $null
            $ExitCode = 1
        }
    }

    if (-not $Manufacturer -and -not $Model -and -not $SupportPhone -and -not $SupportHours -and -not $SupportURL -and -not $RemoveIfBlank){
        Write-Host "[Error] At least one option needs to be selected."
        exit 1
    }

    if ($SupportURL -and $SupportURL -notmatch "^https://"){
        Write-Host "[Error] Invalid Support URL detected: '$SupportURL'. This script requires an HTTPS URL."
        exit 1
    }

    function Set-RegKey {
        param (
            $Path,
            $Name,
            $Value,
            [ValidateSet("DWord", "QWord", "String", "ExpandedString", "Binary", "MultiString", "Unknown")]
            $PropertyType = "DWord"
        )
    
        # Check if the specified registry path exists
        if (!(Test-Path -Path $Path)) {
            try {
                # If the path does not exist, create it
                New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
            }
            catch {
                # If there is an error creating the path, output an error message and exit
                Write-Host "[Error] Unable to create the registry path $Path for $Name. Please see the error below!"
                Write-Host "[Error] $($_.Exception.Message)"
                exit 1
            }
        }
    
        # Check if the registry key already exists at the specified path
        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            # Retrieve the current value of the registry key
            $CurrentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
            if ($CurrentValue -eq $Value) {
                Write-Host "$Path\$Name is already the value '$Value'.`n"
            }
            else {
                try {
                    # Update the registry key with the new value
                    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -Confirm:$false -ErrorAction Stop | Out-Null
                }
                catch {
                    # If there is an error setting the key, output an error message and exit
                    Write-Host "[Error] Unable to set registry key for $Name at $Path. Please see the error below!"
                    Write-Host "[Error] $($_.Exception.Message)"
                    exit 1
                }
                # Output the change made to the registry key
                Write-Host "$Path\$Name changed from '$CurrentValue' to '$((Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name)'.`n"
            }
        }
        else {
            try {
                # If the registry key does not exist, create it with the specified value and property type
                New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force -Confirm:$false -ErrorAction Stop | Out-Null
            }
            catch {
                # If there is an error creating the key, output an error message and exit
                Write-Host "[Error] Unable to set registry key for $Name at $Path. Please see the error below!"
                Write-Host "[Error] $($_.Exception.Message)"
                exit 1
            }
            # Output the creation of the new registry key
            Write-Host "Set $Path\$Name to '$((Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name)'.`n"
        }
    }
}
process {
    if (-not (Test-IsElevated)) {
        Write-Host -Object "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    $BaseRegPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation"

    $currentSettings = try {
        Get-ItemProperty $BaseRegPath -ErrorAction Stop
    }
    catch{
        Write-Host "[Error] Error getting current branding settings from registry."
        Write-Host "[Error] $($_.Exception.Message)"
        exit 1
    }

    $currentSettingsHash = @{
        Manufacturer = $currentSettings.Manufacturer
        SupportPhone = $currentSettings.SupportPhone
        SupportURL = $currentSettings.SupportURL
        SupportHours = $currentSettings.SupportHours
        Model = $currentSettings.Model
    }

    # remove blank/null parameters
    if ($RemoveIfBlank){
        Write-Host "[Info] Removing blank items from HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation registry key.`n"
        
        $paramsToCheck = @{
            Manufacturer    = $Manufacturer
            "Support Phone" = $SupportPhone
            "Support URL"   = $SupportURL
            "Support Hours" = $SupportHours
            Model           = $Model
        }

        # create list for parameters that will be deleted, containing the spaced name of the parameter
        $paramsToDelete = [System.Collections.Generic.List[string]]::new()

        # determine what will be deleted
        foreach ($param in $paramsToCheck.Keys){
            $value = $paramsToCheck[$param]
            $paramNoSpaces = $param -replace " ",""

            # if there are no PSBoundParameters, but we got here, this is running using script/environment variables
            # if running the script directly, only the parameters that are given blank string values will be removed
            if (([string]::IsNullOrWhiteSpace($value)) -and ($paramNoSpaces -in $PSBoundParameters.Keys -or $PSBoundParameters.Keys.Count -eq 0)){
                # add the parameter name to the list
                $paramsToDelete.Add($param)

                # create variable to represent this parameter being deleted
                New-Variable -Name "removing$paramNoSpaces" -Value $true
            }
        }

        # store the current relevant settings in variables
        $currentSupportPhone = $currentSettingsHash.SupportPhone
        $currentManufacturer = $currentSettingsHash.Manufacturer
        $currentSupportHours = $currentSettingsHash.SupportHours

        # warn the user that removing the Support URL while keeping the Support Phone will result in a default URL being displayed
        if ($removingSupportURL -and -not $removingSupportPhone -and -not [string]::IsNullOrWhiteSpace($currentSupportPhone)){
            Write-Host "[Warning] In the Settings app, removing the Support URL without removing the Support Phone will result in a default Support URL that links to https://support.microsoft.com/en-us.`n"
        }
        # otherwise warn the user that removing the URL and phone, or removing only the URL when the phone is blank, will also affect the Manufacturer and Support Hours settings if they are populated
        elseif (
            $removingSupportURL -and 
            -not ($removingManufacturer -and $removingSupportHours) -and
            ($removingSupportPhone -or [string]::IsNullOrWhiteSpace($currentSupportPhone)) -and
            ($currentManufacturer -or $currentSupportHours)
        ){
            Write-Host "[Warning] If both Support URL and Support Phone are empty, Manufacturer and Support Hours will be hidden in the Settings app.`n"              
        }

        # delete the blank parameters
        foreach ($param in $paramsToDelete){
            $paramNoSpaces = $param -replace " ",""

            # get current value of the parameter
            $currentValue = (Get-ItemProperty $BaseRegPath -Name $paramNoSpaces -ErrorAction SilentlyContinue).$paramNoSpaces
            
            # if the above finds a value, proceed with removing the value
            if ($null -ne $currentValue){
                Write-Host "[Info] Current value of HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation\$paramNoSpaces`: '$currentValue'"
                Write-Host "[Info] Removing the registry value for $param."

                try{
                    Remove-ItemProperty $BaseRegPath -Name $paramNoSpaces -ErrorAction Stop
                    Write-Host "[Info] Successfully removed the registry value for $param!`n"
                    # set entry for this value in current settings hashtable to null since the remove was successful
                    $currentSettingsHash[$paramNoSpaces] = ""
                }
                catch{
                    Write-Host "[Error] Error removing the registry value for $param`:"
                    Write-Host "$($_.Exception.Message)"
                    $ExitCode = 1
                }
            }
            elseif ($null -eq $currentValue){
                Write-Host "[Warning] Registry value for $param does not exist. No action taken.`n"
            }
        }
        Write-Host "[Info] Finished removing blank items.`n"
    }

    # check the current values of Support URL and Support Phone
    $currentSupportURL = $currentSettingsHash.SupportURL
    $currentSupportPhone = $currentSettingsHash.SupportPhone
    $currentManufacturer = $currentSettingsHash.Manufacturer
    $currentSupportHours = $currentSettingsHash.SupportHours

    # warn that Manufacturer and Support Hours are dependent on one of either Support URL or Support Phone being populated
    if (
        [string]::IsNullOrWhiteSpace($currentSupportPhone) -and [string]::IsNullOrWhiteSpace($currentSupportURL) -and
        -not $SupportURL -and -not $SupportPhone -and
        ($Manufacturer -or $SupportHours -or $currentManufacturer -or $currentSupportHours)
    ){
        Write-Host "[Warning] In the Settings app, Manufacturer and Support Hours will not display unless the Support URL or Support Phone settings are populated.`n"
    }

    # warn if SupportURL is not populated that it will be shown with a default link if SupportPhone is or will be populated
    if ([string]::IsNullOrWhiteSpace($currentSupportURL) -and -not $SupportURL -and ($SupportPhone -or $currentSupportPhone)){
        Write-Host "[Warning] Support URL is not populated. In the Settings app, when Support Phone is populated, a default Support URL will show that links to https://support.microsoft.com/en-us.`n"
    }

    # set values if provided
    if ($Manufacturer){
        try{
            Write-Host "[Info] Setting the registry value for Manufacturer to '$Manufacturer'."
            Set-RegKey $BaseRegPath -Name 'Manufacturer' -Value "$Manufacturer" -PropertyType "String"
        }
        catch{
            Write-Host "[Error] Error setting Manufacturer registry value:"
            Write-Host "$($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    if ($SupportPhone){
        try{
            Write-Host "[Info] Setting the registry value for Support Phone to '$SupportPhone'."
            Set-RegKey $BaseRegPath -Name 'SupportPhone' -Value "$SupportPhone" -PropertyType "String"
        }
        catch{
            Write-Host "[Error] Error setting SupportPhone registry value:"
            Write-Host "$($_.Exception.Message)"
            $ExitCode = 1
        }
    }
    
    if ($SupportURL){
        try{
            Write-Host "[Info] Setting the registry value for Support URL to '$SupportURL'."
            Set-RegKey $BaseRegPath -Name 'SupportURL' -Value "$SupportURL" -PropertyType "String"
        }
        catch{
            Write-Host "[Error] Error setting SupportURL registry value:"
            Write-Host "$($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    if ($SupportHours){
        try{
            Write-Host "[Info] Setting the registry value for Support Hours to '$SupportHours'."
            Set-RegKey $BaseRegPath -Name 'SupportHours' -Value "$SupportHours" -PropertyType "String"
        }
        catch{
            Write-Host "[Error] Error setting Support Hours registry value:"
            Write-Host "$($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    if ($Model){
        try{
            Write-Host "[Info] Setting the registry value for Model to '$Model'."
            Set-RegKey $BaseRegPath -Name 'Model' -Value "$Model" -PropertyType "String"
        }
        catch{
            Write-Host "[Error] Error setting Model registry value:"
            Write-Host "$($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    exit $ExitCode
}
end {
    
    
    
}