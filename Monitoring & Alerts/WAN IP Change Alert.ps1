#Requires -Version 3

<#
.SYNOPSIS
    Alert when a device's current WAN IP address deviates from expected IP(s). Expected IP(s) can be provided at runtime or via a Custom Field. Multiple IPs should be comma-separated.

.DESCRIPTION
    Alert when a device's current WAN IP address deviates from expected IP(s). Expected IP(s) can be provided at runtime or via a Custom Field. Multiple IPs should be comma-separated.

.PARAMETER -ExpectedWANIP
    Enter the expected WAN IP(s) for the device. CIDR blocks are not supported. If providing multiple expected IPs, they should be comma-separated, for example: 150.23.12.13,150.23.12.14

.PARAMETER -ExpectedWANIPFromCustomFieldName 
    Name of the Custom Field to retrieve the expected WAN IP(s) from. CIDR blocks are not supported. If storing multiple IPs in this field, they should be comma-separated, for example: 150.23.12.13,150.23.12.14
    
.PARAMETER -WANIPHistoryCustomFieldName
    Name of the Custom Field where the current IP address will be written. If the field is already populated, the current IP will be appended to this field with a timestamp.

.EXAMPLE
    -ExpectedWANIP "10.0.0.2","104.190.27.83"
    
    [Info] Checking IP(s) entered at runtime.

    [Info] Testing 10.0.0.2:
    [Info] 10.0.0.2 is a valid IP address.

    [Info] Testing 104.190.27.83:
    [Info] 104.190.27.83 is a valid IP address.

    [Info] Current IP address: 104.190.27.83
    [Info] 104.190.27.83 is an expected IP address for WIN10PRO-1809!

.EXAMPLE
    -ExpectedWANIP "129.200.10.21"
    
    [Info] Checking IP(s) entered at runtime.

    [Info] Testing 129.200.10.21:
    [Info] 129.200.10.21 is a valid IP address.

    [Info] Current IP address: 104.190.27.83
    [Alert] No expected IPs match the current IP 104.190.27.83.

.EXAMPLE
    -ExpectedWANIP "104.190.27.83" -WANIPHistoryCustomFieldName "Multiline"
    
    [Info] Checking IP(s) entered at runtime.

    [Info] Testing 104.190.27.83:
    [Info] 104.190.27.83 is a valid IP address.

    [Info] Current IP address: 104.190.27.83
    [Info] 104.190.27.83 is an expected IP address for WIN10PRO-1809!

    [Info] Writing current IP to custom field 'Multiline'
    [Info] Successfully wrote to custom field 'Multiline':
    2025-01-24 10:33:32 AM | 104.190.27.83

.EXAMPLE
    -ExpectedWANIPFromCustomFieldName "Text"

    [Info] Retrieving data from 'Text' custom field.
    [Info] Checking IP(s) retrieved from custom field 'Text'.

    [Info] Testing 100.0.2.2:
    [Info] 100.0.2.2 is a valid IP address.

    [Info] Testing 104.190.27.83:
    [Info] 104.190.27.83 is a valid IP address.

    [Info] Current IP address: 104.190.27.83
    [Info] 104.190.27.83 is an expected IP address for WIN10PRO-1809!

.EXAMPLE 
    -ExpectedWANIPFromCustomFieldName "Text" -WANIPHistoryCustomFieldName "Multiline"

    [Info] Retrieving data from 'Text' custom field.
    [Info] Checking IP(s) retrieved from custom field 'Text'.

    [Info] Testing 100.0.2.2:
    [Info] 100.0.2.2 is a valid IP address.

    [Info] Testing 104.190.27.83:
    [Info] 104.190.27.83 is a valid IP address.

    [Info] Current IP address: 104.190.27.83
    [Info] 104.190.27.83 is an expected IP address for WIN10PRO-1809!

    [Info] Writing current IP to custom field 'Multiline'
    [Info] Successfully wrote to custom field 'Multiline':
    2025-01-24 10:34:34 AM | 104.190.27.83

.NOTES
    Minimum OS Architecture Supported: Windows 8, Windows Server 2012
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string[]]$ExpectedWANIP,

    [Parameter()]
    [string]$ExpectedWANIPFromCustomFieldName,

    [Parameter()]
    [string]$WANIPHistoryCustomFieldName
)

begin {
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    if ($env:ExpectedWANIP -and $env:ExpectedWANIP -ne 'null'){
        $ExpectedWANIP = $env:ExpectedWANIP
    }

    if ($env:ExpectedWANIPFromCustomFieldName -and $env:ExpectedWANIPFromCustomFieldName -ne 'null'){
        $ExpectedWANIPFromCustomFieldName = $env:ExpectedWANIPFromCustomFieldName
    }

    if ($env:WANIPHistoryCustomFieldName -and $env:WANIPHistoryCustomFieldName -ne 'null'){
        $WANIPHistoryCustomFieldName = $env:WANIPHistoryCustomFieldName
    }

    if (-not $ExpectedWANIP -and -not $ExpectedWANIPFromCustomFieldName){
        Write-Host "[Error] Please provide either the WAN IP address you are expecting this machine to have, or the name of a custom field to retrieve the expected IPs from."
        exit 1
    }

    function Test-IPAddress {
        param(
            [string]$IP
        )

        Write-Host "[Info] Testing $IP`:"
        switch ($IP) {
            # check IP for a slash, which indicates CIDR notation was used
            {$_ -match "/"} {
                Write-Host "[Error] This script does not support CIDR notation. If you need to expect multiple IP addresses, you can use commas to separate them."
                exit 1
            }
            # check IP for invalid characters (anything other than a digit or a period) 
            {$_ -match "[^\d\.]"} {
                Write-Host "[Error] Invalid characters detected in IP address."
                exit 1
            }
            # check if partial IP address was provided
            {$_ -notmatch "\d+\.\d+\.\d+\.\d+"} {
                Write-Host "[Error] Partial IP addresses are not allowed. Please include all 4 octets in each expected IP."
                exit 1
            }
        }

        # validate the IP by casting to [ipaddress], if it does not error then it should be a valid IP
        try{
            $ReturnIP = ([ipaddress]$IP).IPAddressToString
        }
        catch{
            Write-Host "[Error] $IP is not a valid IP address. Please make sure all expected IP addresses are valid, and remove any leading zeros."
            exit 1
        }
        
        # in some cases, the above will not fail but the ReturnIP value will not match the input IP exactly
        # if these values don't match exactly, this is likely due to leading zeros in the given IP, as ReturnIP will not have any leading zeros
        if ($ReturnIP -ne $IP){
            Write-Host "[Error] Error while testing $IP. This is likely due to the IP address containing leading zeros. Please remove any leading zeros in your expected IP addresses."
            exit 1
        }

        Write-Host "[Info] $IP is a valid IP address.`n"
        return $ReturnIP
    }

    function Get-NinjaProperty {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
            [String]$Name,
            [Parameter()]
            [String]$Type,
            [Parameter()]
            [String]$DocumentName
        )
        
        # Initialize a hashtable for documentation parameters
        $DocumentationParams = @{}
    
        # If a document name is provided, add it to the documentation parameters
        if ($DocumentName) { $DocumentationParams["DocumentName"] = $DocumentName }
    
        # Define types that require options to be retrieved
        $NeedsOptions = "DropDown", "MultiSelect"
        
        # If a document name is provided, retrieve the property value from the document
        if ($DocumentName) {
            # Throw an error if the type is "Secure", as it's not a valid type in this context
            if ($Type -Like "Secure") { throw [System.ArgumentOutOfRangeException]::New("$Type is an invalid type! Please check here for valid types. https://ninjarmm.zendesk.com/hc/en-us/articles/16973443979789-Command-Line-Interface-CLI-Supported-Fields-and-Functionality") }
        
            # Notify the user that the value is being retrieved from a Ninja document
            Write-Host "Retrieving value from Ninja Document..."
            $NinjaPropertyValue = Ninja-Property-Docs-Get -AttributeName $Name @DocumentationParams 2>&1
        
            # If the property type requires options, retrieve them
            if ($NeedsOptions -contains $Type) {
                $NinjaPropertyOptions = Ninja-Property-Docs-Options -AttributeName $Name @DocumentationParams 2>&1
            }
        }
        else {
            # If no document name is provided, retrieve the property value directly
            $NinjaPropertyValue = Ninja-Property-Get -Name $Name 2>&1
    
            # If the property type requires options, retrieve them
            if ($NeedsOptions -contains $Type) {
                $NinjaPropertyOptions = Ninja-Property-Options -Name $Name 2>&1
            }
        }
        
        # Throw an exception if there was an error retrieving the property value or options
        if ($NinjaPropertyValue.Exception) { throw $NinjaPropertyValue }
        if ($NinjaPropertyOptions.Exception) { throw $NinjaPropertyOptions }
        
        # Handle the property value based on its type
        switch ($Type) {
            "Attachment" {
                # Convert JSON formatted property value to a PowerShell object
                $NinjaPropertyValue | ConvertFrom-Json
            }
            "Checkbox" {
                # Convert the value to a boolean
                [System.Convert]::ToBoolean([int]$NinjaPropertyValue)
            }
            "Date or Date Time" {
                # Convert a Unix timestamp to local date and time
                $UnixTimeStamp = $NinjaPropertyValue
                $UTC = (Get-Date "1970-01-01 00:00:00").AddSeconds($UnixTimeStamp)
                $TimeZone = [TimeZoneInfo]::Local
                [TimeZoneInfo]::ConvertTimeFromUtc($UTC, $TimeZone)
            }
            "Decimal" {
                # Convert the value to a double (floating-point number)
                [double]$NinjaPropertyValue
            }
            "Device Dropdown" {
                # Convert JSON formatted property value to a PowerShell object
                $NinjaPropertyValue | ConvertFrom-Json
            }
            "Device MultiSelect" {
                # Convert JSON formatted property value to a PowerShell object
                $NinjaPropertyValue | ConvertFrom-Json
            }
            "Dropdown" {
                # Convert options to a CSV format and match the GUID to retrieve the display name
                $Options = $NinjaPropertyOptions -replace '=', ',' | ConvertFrom-Csv -Header "GUID", "Name"
                $Options | Where-Object { $_.GUID -eq $NinjaPropertyValue } | Select-Object -ExpandProperty Name
            }
            "Integer" {
                # Convert the value to an integer
                [int]$NinjaPropertyValue
            }
            "MultiSelect" {
                # Convert options to a CSV format, then match and return selected items
                $Options = $NinjaPropertyOptions -replace '=', ',' | ConvertFrom-Csv -Header "GUID", "Name"
                $Selection = ($NinjaPropertyValue -split ',').trim()
        
                foreach ($Item in $Selection) {
                    $Options | Where-Object { $_.GUID -eq $Item } | Select-Object -ExpandProperty Name
                }
            }
            "Organization Dropdown" {
                # Convert JSON formatted property value to a PowerShell object
                $NinjaPropertyValue | ConvertFrom-Json
            }
            "Organization Location Dropdown" {
                # Convert JSON formatted property value to a PowerShell object
                $NinjaPropertyValue | ConvertFrom-Json
            }
            "Organization Location MultiSelect" {
                # Convert JSON formatted property value to a PowerShell object
                $NinjaPropertyValue | ConvertFrom-Json
            }
            "Organization MultiSelect" {
                # Convert JSON formatted property value to a PowerShell object
                $NinjaPropertyValue | ConvertFrom-Json
            }
            "Time" {
                # Convert the value from seconds to a time format in the local timezone
                $Seconds = $NinjaPropertyValue
                $UTC = ([timespan]::fromseconds($Seconds)).ToString("hh\:mm\:ss")
                $TimeZone = [TimeZoneInfo]::Local
                $ConvertedTime = [TimeZoneInfo]::ConvertTimeFromUtc($UTC, $TimeZone)
        
                Get-Date $ConvertedTime -DisplayHint Time
            }
            default {
                # For any other types, return the raw value
                $NinjaPropertyValue
            }
        }
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
}
process {
    if (-not (Test-IsElevated)) {
        Write-Host -Object "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    # test WAN IP from script variable and store in IPFromRuntime variable
    if ($ExpectedWANIP){
        Write-Host "[Info] Checking IP(s) entered at runtime.`n"
        # separate and sanitize IPs from script variable, in case they have quotes around them or spaces 
        $ExpectedWANIP = ($ExpectedWANIP -split ",").Trim(' "')

        # create empty list to add each valid IP to
        $IPFromRuntime = [System.Collections.Generic.List[string]]::New()

        # add each valid IP to the list variable
        foreach ($IP in $ExpectedWANIP){
            $value = Test-IPAddress $IP
            $IPFromRuntime.Add($value)
        }
    }

    # test WAN IP from Custom Field and store in IPFromCustomField variable
    if ($ExpectedWANIPFromCustomFieldName){
        try{
            Write-Host "[Info] Retrieving data from '$ExpectedWANIPFromCustomFieldName' custom field."
            $CustomFieldValue = Get-NinjaProperty -Name $ExpectedWANIPFromCustomFieldName -Type "TEXT"
        }
        catch{
            Write-Host "[Error] Error retrieving Custom Field data."
            Write-Host "$($_.Exception.Message)"
            exit 1
        }

        if ($null -eq $CustomFieldValue){
            Write-Host "[Error] The custom field '$ExpectedWANIPFromCustomFieldName' is blank. Please make sure this field contains expected IP addresses."
            exit 1
        }
        
        Write-Host "[Info] Checking IP(s) retrieved from custom field '$ExpectedWANIPFromCustomFieldName'.`n"
        # separate and sanitize IPs retrieved from Custom Field, in case they have quotes around them or spaces
        $CustomFieldValue = ($CustomFieldValue -split ",").Trim(' "')

        # create empty list to add each valid IP to
        $IPFromCustomField = [System.Collections.Generic.List[string]]::New()

        # add each valid IP to the list variable
        foreach ($IP in $CustomFieldValue){
            $value = Test-IPAddress $IP
            $IPFromCustomField.Add($value)
        }
    }

    # if IPs were provided in both the custom field and script variable, and they are not the exact same, error out
    # if Compare-Object has any output, it means there are differences between the two objects
    if (
        ($IPFromRuntime -and $IPFromCustomField) -and 
        (Compare-Object -ReferenceObject $IPFromRuntime -DifferenceObject $IPFromCustomField)
    ){
        Write-Host "[Error] IPs differ between the Custom Field value ($($IPFromCustomField -join ", ")) and the expected IPs in the script variable ($($IPFromRuntime -join ", ")). These values must match."
        exit 1
    }
    else{
        # otherwise, whether they are the same or only one was provided, create array out of the possible verified IP variables, get the unique values
        $ExpectedIP = (@($IPFromRuntime, $IPFromCustomField) | Select-Object -Unique)
    }

    # get current IP address
    $CurrentIP = try{
        (Invoke-WebRequest -Uri "api.ipify.org" -UseBasicParsing).Content
    }
    catch{
        Write-Host "[Error] Error retrieving current IP address."
        Write-Host "$($_.Exception.Message)"
        exit 1
    }

    Write-Host "[Info] Current IP address: $CurrentIP"

    # check if IP addresses match
    if ($CurrentIP -in $ExpectedIP){
        Write-Host "[Info] $CurrentIP is an expected IP address for $env:computername!`n"
    }
    else{
        Write-Host "[Alert] None of the expected IPs match the current WAN IP address $CurrentIP.`n"
    }

    # write current IP to custom field section
    if ($WANIPHistoryCustomFieldName){
        $timestamp = Get-Date -Format "yyyy-MM-dd"

        # read current value to determine how to set the new value
        try{
            $currentValue = Get-NinjaProperty -Name $WANIPHistoryCustomFieldName -ErrorAction Stop
        }
        catch{
            Write-Host "[Error] Error reading current value of custom field '$WANIPHistoryCustomFieldName'."
            Write-Host "$($_.Exception.Message)"
            exit 1
        }

        # set up value to write to the custom field, if any
        if ($currentValue){
            # if the CF does not already contain the current IP in the most recent (topmost) entry, the new value to set should be the new IP with a timestamp at the top, with the rest of the current content of the CF after it
            if (($currentValue | Select-Object -First 1) -notmatch $CurrentIP){
                $valueToSet = $timestamp + " | $CurrentIP`n" + ($currentValue -join "`n")
            }
            else{
                Write-Host "[Info] Current IP $CurrentIP is already the most recent IP in the '$WANIPHistoryCustomFieldName' custom field. No new value will be written."
            }
        }
        else{
            # if the CF does not have content, we will add the current IP along with a timestamp
            $valueToSet = $timestamp + " | $CurrentIP"
        }

        if ($valueToSet){
            try{
                Write-Host "[Info] Writing current IP to custom field '$WANIPHistoryCustomFieldName'."
                Set-NinjaProperty -Name $WANIPHistoryCustomFieldName -Type "MULTILINE" -Value $valueToSet
                Write-Host "[Info] Successfully wrote to custom field '$WANIPHistoryCustomFieldName'`:"
                $valueToSet | Write-Host
            }
            catch{
                Write-Host "[Error] Error writing '$valueToSet' to custom field '$WANIPHistoryCustomFieldName'."
                Write-Host "$($_.Exception.Message)"
                exit 1
            }
        }
    }

    exit 0
}
end {
    
    
    
}