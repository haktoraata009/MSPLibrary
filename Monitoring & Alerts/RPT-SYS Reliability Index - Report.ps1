#Requires -Version 5.1

<#
.SYNOPSIS
    Returns the last score and a daily average report of the Windows Reliability Index.
.DESCRIPTION
    Returns the last score and a daily average report of the Windows Reliability Index.

.EXAMPLE
    (No Parameters)

    [Info] Retrieving reliability index information for SRV19-TEST.
    [Info] Successfully retrieved reliability index information!

    [Info] Latest reliability index score for SRV19-TEST:
    2/19/2025 1:00:00 PM | 6.835

    [Info] Table of daily averages:

    Date      Average Reliability Index
    ----      -------------------------
    2/19/2025                      8.26
    2/18/2025                        10
    2/17/2025                        10
    2/16/2025                        10
    2/15/2025                        10
    2/14/2025                        10
    2/13/2025                        10
    2/12/2025                        10
    2/11/2025                        10
    2/10/2025                        10
    2/9/2025                         10
    2/8/2025                         10
    2/7/2025                         10
    2/6/2025                         10
    2/5/2025                         10
    2/4/2025                         10
    2/3/2025                         10
    2/2/2025                         10
    2/1/2025                         10
    1/31/2025                        10
    1/30/2025                        10
    1/29/2025                        10
    1/28/2025                        10
    1/27/2025                        10
    1/26/2025                        10
    1/25/2025                        10
    1/24/2025                        10
    1/23/2025                        10
    1/22/2025                        10
    1/21/2025                        10
    1/20/2025                        10
    1/19/2025                        10

.PARAMETER -WYSIWYGCustomFieldName "ReplaceMeWithAnyWYSIWYGCustomField"
    Name of the WYSIWYG custom field to populate with the report.

.EXAMPLE
    -WYSIWYGCustomFieldName "ExampleInput"

    [Info] Retrieving reliability index information for SRV19-TEST.
    [Info] Successfully retrieved reliability index information!

    [Info] Retrieving current value of WYSIWYG Custom Field 'WYSIWYG'.
    [Info] Successfully retrieved the current value of 'WYSIWYG'.

    [Info] Publishing Reliability Index daily average table to WYSIWYG Custom Field 'WYSIWYG'.
    [Info] Successfully set 'WYSIWYG' Custom Field!

    [Info] Latest reliability index score for SRV19-TEST:
    2/19/2025 1:00:00 PM | 6.835

    [Info] Table of daily averages:

    Date      Average Reliability Index
    ----      -------------------------
    2/19/2025                      8.26
    2/18/2025                        10
    2/17/2025                        10
    2/16/2025                        10
    2/15/2025                        10
    2/14/2025                        10
    2/13/2025                        10
    2/12/2025                        10
    2/11/2025                        10
    2/10/2025                        10
    2/9/2025                         10
    2/8/2025                         10
    2/7/2025                         10
    2/6/2025                         10
    2/5/2025                         10
    2/4/2025                         10
    2/3/2025                         10
    2/2/2025                         10
    2/1/2025                         10
    1/31/2025                        10
    1/30/2025                        10
    1/29/2025                        10
    1/28/2025                        10
    1/27/2025                        10
    1/26/2025                        10
    1/25/2025                        10
    1/24/2025                        10
    1/23/2025                        10
    1/22/2025                        10
    1/21/2025                        10
    1/20/2025                        10
    1/19/2025                        10

.PARAMETER -TextCustomFieldName "ReplaceMeWithAnyTextCustomField"
    Name of the Text custom field to populate with the most recent reliability index score.
    
.EXAMPLE
    -TextCustomFieldName "ReplaceMeWithAnyMultilineCustomField"

    [Info] Retrieving reliability index information for SRV19-TEST.
    [Info] Successfully retrieved reliability index information!

    [Info] Retrieving current value of Text Custom Field 'Text'.
    [Info] Successfully retrieved the current value of 'Text'.

    [Info] Publishing the latest reliability index score to Text Custom Field 'Text'.
    [Info] Successfully set 'Text' Custom Field to value '2/19/2025 1:00:00 PM | 6.835'!

    [Info] Latest reliability index score for SRV19-TEST:
    2/19/2025 1:00:00 PM | 6.835

    [Info] Table of daily averages:

    Date      Average Reliability Index
    ----      -------------------------
    2/19/2025                      8.26
    2/18/2025                        10
    2/17/2025                        10
    2/16/2025                        10
    2/15/2025                        10
    2/14/2025                        10
    2/13/2025                        10
    2/12/2025                        10
    2/11/2025                        10
    2/10/2025                        10
    2/9/2025                         10
    2/8/2025                         10
    2/7/2025                         10
    2/6/2025                         10
    2/5/2025                         10
    2/4/2025                         10
    2/3/2025                         10
    2/2/2025                         10
    2/1/2025                         10
    1/31/2025                        10
    1/30/2025                        10
    1/29/2025                        10
    1/28/2025                        10
    1/27/2025                        10
    1/26/2025                        10
    1/25/2025                        10
    1/24/2025                        10
    1/23/2025                        10
    1/22/2025                        10
    1/21/2025                        10
    1/20/2025                        10
    1/19/2025                        10
    
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$WYSIWYGCustomFieldName,

    [Parameter()]
    [string]$TextCustomFieldName
)

begin {

    if ($env:WYSIWYGCustomFieldName){
        $WYSIWYGCustomFieldName = $env:WYSIWYGCustomFieldName
    }

    if ($env:TextCustomFieldName){
        $TextCustomFieldName = $env:TextCustomFieldName
    }

    # if custom field input is only spaces or a blank string, set it to null
    # otherwise, trim any whitespace on the ends
    if ([string]::IsNullOrWhiteSpace($WYSIWYGCustomFieldName)){
        $WYSIWYGCustomFieldName = $null
    }
    else{
        $WYSIWYGCustomFieldName = $WYSIWYGCustomFieldName.Trim()
    }

    if ([string]::IsNullOrWhiteSpace($TextCustomFieldName)){
        $TextCustomFieldName = $null
    }
    else{
        $TextCustomFieldName = $TextCustomFieldName.Trim()
    }

    # test custom field for invalid characters
    if ($WYSIWYGCustomFieldName -match "[^0-9A-Z]"){
        Write-Host "[Error] WYSIWYG Custom Field Name contains invalid character(s). Writing to the WYSIWYG Custom Field will be skipped."
        Write-Host "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
        $WYSIWYGCustomFieldName = $null
        $ExitCode = 1
        Write-Host ""
    }

    if ($TextCustomFieldName -match "[^0-9A-Z]"){
        Write-Host "[Error] Text Custom Field Name contains invalid character(s). Writing to the Text Custom Field will be skipped."
        Write-Host "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
        $TextCustomFieldName = $null
        $ExitCode = 1
        Write-Host ""
    }

    function Get-CustomField {
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

    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
}
process {
    if (-not (Test-IsElevated)) {
        Write-Host -Object "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    $ExitCode = 0

    # retrieve reliability index metrics
    try{
        Write-Host "[Info] Retrieving reliability index information for $env:computername."
        $reliabilityMetrics = Get-CimInstance Win32_ReliabilityStabilityMetrics | Sort-Object TimeGenerated -Descending
        Write-Host "[Info] Successfully retrieved reliability index information!`n"
    }
    catch{
        Write-Host "[Error] Error retrieving reliability index information."
        Write-Host "[Error] $($_.Exception.Message)"
        exit 1
    }

    # if any metrics are present, continue with script
    # otherwise, error out with a message that no information is available
    if ($reliabilityMetrics){
        # get unique dates from the metrics
        $dates = $reliabilityMetrics | Group-Object {$_.TimeGenerated.ToShortDateString()}

        # create table with averages of each dates' score, sorted by date (most recent to oldest)
        $reliabilityIndexTable = $(foreach ($currentDate in $dates){
            [PSCustomObject]@{
                Date = $currentDate.Name
                "Average Reliability Index" = [Math]::Round(($currentDate.Group.SystemStabilityIndex | Measure-Object -Average).Average,2)
            }
        }) | Sort-Object {[datetime]::Parse($_.Date)} -Descending

        # get the most recent time and score
        $currentIndexDate = ($reliabilityMetrics | Select-Object -First 1).EndMeasurementDate.ToString()
        $currentIndexScore = ($reliabilityMetrics | Select-Object -First 1).SystemStabilityIndex

        # above values will be written to the Text Custom Field and output to the activity feed using the below formatted string
        $latestIndexInfo = "$currentIndexDate | $currentIndexScore"

        # write to WYSIWYG Custom Field if provided
        if ($WYSIWYGCustomFieldName){
            # convert report to HTML table
            $report = $reliabilityIndexTable | ConvertTo-HTML -Fragment

            # attempt to get the current value of the field, to determine if it already matches the report
            try{
                Write-Host "[Info] Retrieving current value of WYSIWYG Custom Field '$WYSIWYGCustomFieldName'."
                # output will be in JSON format for this type of field, need to first convert it to an object, and we want to compare the HTML so that is extracted into the variable
                $currentValue = (Get-CustomField $WYSIWYGCustomFieldName | ConvertFrom-JSON).HTML
                Write-Host "[Info] Successfully retrieved the current value of '$WYSIWYGCustomFieldName'.`n"
            }
            catch{
                Write-Host "[Error] Error retrieving current value of '$WYSIWYGCustomFieldName'."
                Write-Host "[Error] $($_.Exception.Message)`n"
                # an error occurred while getting the current value of the custom field, so we will skip writing to it
                $skipWYSIWYGCFWrite = $true
                $ExitCode = 1
            }

            # check if the current value of the field is the same as the report. if so, output a message and do not try to write to the field again
            if ($currentValue -eq $report){
                Write-Host "[Info] WYSIWYG Custom Field '$WYSIWYGCustomFieldName' already has the latest information.`n"
            }
            # otherwise, continue with writing to the custom field unless there was an error retrieving the current value above
            elseif (-not ($skipWYSIWYGCFWrite)){
                try{
                    Write-Host "[Info] Publishing Reliability Index daily average table to WYSIWYG Custom Field '$WYSIWYGCustomFieldName'."
                    Set-CustomField -Name $WYSIWYGCustomFieldName -Value $report -Type "WYSIWYG"
                    Write-Host "[Info] Successfully set '$WYSIWYGCustomFieldName' Custom Field!`n"
                }
                catch{
                    Write-Host "[Error] Error setting '$WYSIWYGCustomFieldName'."
                    Write-Host "[Error] $($_.Exception.Message)`n"
                    $ExitCode = 1
                }
            }
        }

        # write to Text custom field if provided
        if ($TextCustomFieldName){
            # attempt to retrieve current value of the text custom field
            try{
                Write-Host "[Info] Retrieving current value of Text Custom Field '$TextCustomFieldName'."
                $currentValue = Get-CustomField $TextCustomFieldName
                Write-Host "[Info] Successfully retrieved the current value of '$TextCustomFieldName'.`n"
            }
            catch{
                Write-Host "[Error] Error retrieving current value of '$TextCustomFieldName'."
                Write-Host "[Error] $($_.Exception.Message)`n"
                # an error occurred while getting the current value of the custom field, so we will skip writing to it
                $skipTextCFWrite = $true
                $ExitCode = 1
            }

            if ($currentValue -eq $latestIndexInfo){
                Write-Host "[Info] Text Custom Field '$TextCustomFieldName' already has the latest information.`n"
            }
            elseif (-not ($skipTextCFWrite)){
                try{
                    Write-Host "[Info] Publishing the latest reliability index score to Text Custom Field '$TextCustomFieldName'."
                    Set-CustomField -Name $TextCustomFieldName -Value $latestIndexInfo -Type "Text"
                    Write-Host "[Info] Successfully set '$TextCustomFieldName' Custom Field to value '$latestIndexInfo'!`n"
                }
                catch{
                    Write-Host "[Error] Error setting '$TextCustomFieldName' to value '$latestIndexInfo'."
                    Write-Host "[Error] $($_.Exception.Message)`n"
                    $ExitCode = 1
                }
            }
        }

        # output information to the activity feed
        Write-Host "[Info] Latest reliability index score for $env:computername`:"
        $latestIndexInfo | Out-Host
        Write-Host "`n[Info] Table of daily averages:"
        $reliabilityIndexTable | Out-Host
    }
    else{
        Write-Host "[Error] Reliability index information could not be found on this machine."
        exit 1
    }
    
    exit $ExitCode
}
end {
    
    
    
}