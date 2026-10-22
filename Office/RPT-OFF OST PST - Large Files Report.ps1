#Requires -Version 5.1

<#
.SYNOPSIS
    Searches local drives for .pst and .ost files that exceed a defined size and optionally saves the results to a custom field. If no unit is provided for the 'Minimum Alert and Reporting Size', the value will be interpreted as gigabytes.
.DESCRIPTION
    Searches local drives for .pst and .ost files that exceed a defined size and optionally saves the results to a custom field. If no unit is provided for the 'Minimum Alert and Reporting Size', the value will be interpreted as gigabytes.
.EXAMPLE
    -MinimumAlertSize "1kb"
   
    Searching 'C:\' for files with extension '.ost'...
    Searching 'C:\' for files with extension '.pst'...

    [Alert] .ost and .pst files were found that are larger than '1kb'.

    Name          : Report-LargeOSTFiles.ost
    FullName      : C:\Users\cheart\Desktop\Report-LargeOSTFiles.ost
    CreationTime  : 3/13/2025 9:50 AM
    LastWriteTime : 3/13/2025 9:10 AM
    Size          : 12.36 KB

    Name          : Report-LargeOSTFiles.pst
    FullName      : C:\Users\cheart\Desktop\Report-LargeOSTFiles.pst
    CreationTime  : 3/13/2025 9:50 AM
    LastWriteTime : 3/13/2025 9:10 AM
    Size          : 12.36 KB

.EXAMPLE
    -MinimumAlertSize "1 PB"

    Searching 'C:\' for files with extension '.ost'...
    Searching 'C:\' for files with extension '.pst'...

    No .ost or .pst files that are larger than '1 PB' were found.

.PARAMETER -MinimumAlertSize "50 GB"
    The minimum file size required for a .pst or .ost file to be included in the report. If no unit is provided, the value will be interpreted as gigabytes.

.PARAMETER -MultilineCustomField "ReplaceMeWithAnyMultilineCustomField"
    Optionally enter the name of a multiline custom field to save the results to.

.PARAMETER -WYSIWYGCustomField "ReplaceMeWithAnyWYSIWYGCustomField"
    Optionally enter the name of a WYSIWYG custom field to save the results to.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.1
    Release Notes: Switched to always searching all folders and drives; added custom field support; added .pst files to the search; switched to using a user-defined unit size for the alert; updated all functions.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$MinimumAlertSize = "50 GB",
    [Parameter()]
    [String]$Extensions = ".ost, .pst",
    [Parameter()]
    [String]$MultilineCustomField,
    [Parameter()]
    [String]$WYSIWYGCustomField
)

begin {
    # If script form variables are used, replace the command line parameters with their value.
    if ($env:minimumAlertAndReportingSize) { $MinimumAlertSize = $env:minimumAlertAndReportingSize }
    if ($env:multilineCustomFieldName) { $MultilineCustomField = $env:multilineCustomFieldName }
    if ($env:wysiwygCustomFieldName) { $WYSIWYGCustomField = $env:wysiwygCustomFieldName }

    # Check if the $MinimumAlertSize variable is null, empty, or consists only of whitespace.
    if ([String]::IsNullOrWhiteSpace($MinimumAlertSize)) {
        Write-Host -Object "[Error] You must provide a valid minimum size to alert on."
        exit 1
    }

    # Remove any leading or trailing whitespace from the minimum alert size.
    $MinimumAlertSize = $MinimumAlertSize.Trim()

    # Validate the format: Ensure $MinimumAlertSize does not contain any invalid characters.
    # Allowed characters include digits, a period, spaces, and valid unit strings (PB, TB, GB, MB, KB, B, Bytes).
    if ($MinimumAlertSize -match "[^0-9. (PB|TB|GB|MB|KB|B|Bytes)]") {
        Write-Host -Object "[Error] The minimum size of '$MinimumAlertSize' is invalid. It contains invalid characters, please specify a file size such as '50 GB'."
        exit 1
    }

    
    # Validate the overall format of the minimum alert size.
    # It must start with one or more digits, optionally followed by a period and more digits,
    # then optional whitespace and an optional valid unit.
    if ($MinimumAlertSize -notmatch "^[0-9]+\.?[0-9]*\s*(PB|TB|GB|MB|KB|B|Bytes)?$") {
        Write-Host -Object "[Error] The minimum size of '$MinimumAlertSize' is invalid. It's in an invalid format, please specify a file size such as '50 GB'."
        exit 1
    }

    # If no valid unit is found at the end of the string, warn the user and assume Gigabytes.
    if ($MinimumAlertSize -notmatch "(PB|TB|GB|MB|KB|B|Bytes)$") {
        Write-Host -Object "`n[Warning] No unit was specified for '$MinimumAlertSize'. Assuming that the number given is in Gigabytes.`n"

        # Append "GB" to the value.
        $MinimumAlertSize = "$($MinimumAlertSize.Trim()) GB"
    }

    # Validate the Multiline Custom Field if it is provided.
    if ($MultilineCustomField) {
        # Check if the provided field is empty or whitespace.
        if ([String]::IsNullOrWhiteSpace($MultilineCustomField)) {
            Write-Host -Object "[Error] The 'Multiline Custom Field Name' is invalid."
            Write-Host -Object "[Error] Please provide a valid multiline custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }

        # Trim any whitespace.
        $MultilineCustomField = $MultilineCustomField.Trim()

        # Validate that the custom field contains only valid characters (digits and uppercase letters).
        if ($MultilineCustomField -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'Multiline Custom Field Name' of '$MultilineCustomField' is invalid as it contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid multiline custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Validate the WYSIWYG Custom Field if it is provided.
    if ($WYSIWYGCustomField) {
        # Check if the provided field is empty or whitespace.
        if ([String]::IsNullOrWhiteSpace($WYSIWYGCustomField)) {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' is invalid."
            Write-Host -Object "[Error] Please provide a valid WYSIWYG custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }

        # Trim any whitespace.
        $WYSIWYGCustomField = $WYSIWYGCustomField.Trim()

        # Validate that the custom field contains only valid characters (digits and uppercase letters).
        if ($WYSIWYGCustomField -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' of '$WYSIWYGCustomField' is invalid as it contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid WYSIWYG custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Initialize a list to store the extensions to search for.
    $ExtensionsToSearch = New-Object System.Collections.Generic.List[String]

    # If the extensions are comma-separated, split them and trim any whitespace.
    if ($Extensions -match ",") {
        $Extensions -split "," | ForEach-Object { $ExtensionsToSearch.Add($_.Trim()) }
    }
    else {
        $ExtensionsToSearch.Add($Extensions.Trim())
    }
    
    # Initialize a list to track extensions that need to be modified (to add a leading dot if missing).
    $ExtensionsToReplace = New-Object System.Collections.Generic.List[object]
    $ExtensionsToSearch | ForEach-Object {
        # If the extension does not start with a period, prepare to add one.
        if ($_ -notmatch "^\.") {
            $NewExtension = ".$_"

            # Create a PSCustomObject with the index of the extension and its new value.
            $ExtensionsToReplace.Add(
                [PSCustomObject]@{
                    Index        = $ExtensionsToSearch.IndexOf("$_")
                    NewExtension = $NewExtension
                }
            )
            
            # Warn the user that the extension was missing a dot and is being corrected.
            Write-Warning "Missing . for extension. Changing extension search to '$NewExtension'."
        }
    }

    # Apply the replacements to add a leading dot for extensions missing it.
    $ExtensionsToReplace | ForEach-Object {
        $ExtensionsToSearch[$_.index] = $_.NewExtension 
    }

    # Initialize a list to store extensions that contain illegal characters.
    $ExtensionsToRemove = New-Object System.Collections.Generic.List[String]

    # Define a regex pattern to match invalid characters or an extension that ends in a period.
    $invalidExtensions = '[<>:"/\\|\x00-\x1F]|\.$'
    $ExtensionsToSearch | ForEach-Object {
        if ($_ -match $invalidExtensions) {
            Write-Host -Object "[Error] Extension $_ contains one of the following invalid characters or ends in a period: '\:<>`"/|'"
            
            # Add the invalid extension to the removal list.
            $ExtensionsToRemove.Add($_)
            $ExitCode = 1
        }
    }

    # Remove the invalid extensions from the search list.
    $ExtensionsToRemove | ForEach-Object {
        $ExtensionsToSearch.Remove($_) | Out-Null
    }

    # If there are no valid extensions left, display an error and exit.
    if ($ExtensionsToSearch.Count -eq 0) {
        Write-Host -Object "[Error] No valid extensions to search!"
        exit 1
    }

    # Initialize a list for paths to search.
    $PathsToSearch = New-Object System.Collections.Generic.List[String]
    try {
        # Get all filesystem drives with both free and used space, then add their root paths to the list.
        Get-PSDrive -PSProvider FileSystem -ErrorAction Stop | Where-Object { $_.Free -and $_.Used } | ForEach-Object {
            # If the root doesn't match a typical format (e.g., "C:\"), adjust accordingly.
            if ($_.Root -notmatch '^[A-Z]:\\$' -and $_.Root -match '^[A-Z]:$') {
                $PathsToSearch.Add("$($_.Root)\")
            }
            else {
                $PathsToSearch.Add($_.Root)
            }
        }
    }
    catch {
        # If an error occurs while retrieving drives, display the error message and exit.
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to get list of drives to search."
        exit 1
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

    # Convert file size strings (e.g., "50 GB") into their equivalent numeric byte values.
    function ConvertTo-Bytes {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromPipeline)]
            [String[]]$FileSize,
            [Parameter()]
            [String]$DefaultTo
        )
        process {
            # Check if the input is null or an empty string.
            if ([String]::IsNullOrEmpty($FileSize)) {
                throw (New-Object System.ArgumentNullException("You must provide a file size string to convert into bytes."))
            }

            # Define an array of valid default unit options.
            $ValidDefaults = "PB", "TB", "GB", "MB", "KB", "B", "Bytes"

            # Check if $DefaultTo has a value and is not in the list of valid defaults.
            if ($DefaultTo -and $ValidDefaults -notcontains $DefaultTo) {
                throw (New-Object System.ArgumentOutOfRangeException("You cannot default to '$DefaultTo'. Valid default options include: 'PB', 'TB', 'GB', 'MB', 'KB', 'B', and 'Bytes'."))
            }

            # Create a generic list to store validated file size strings.
            $FileSizesToConvert = New-Object System.Collections.Generic.List[String]

            # Iterate over each provided file size string.
            $FileSize | ForEach-Object {
                # Check if the string is null, empty, or whitespace.
                if ([String]::IsNullOrWhiteSpace($_)) {
                    Write-Error -Category ObjectNotFound -Exception (New-Object System.ArgumentNullException("FileSize", "An empty file size string was given. Unable to convert null into bytes."))
                    return
                }

                # Validate the string for any characters not allowed.
                # This regex permits digits, the period, whitespace, dashes, and valid unit strings (PB, TB, GB, MB, KB, B, Bytes).
                if ($_.Trim() -match "[^0-9. (PB|TB|GB|MB|KB|B|Bytes)-]") {
                    Write-Error -Category InvalidArgument -Exception (New-Object System.ArgumentException("The file size of '$_' is invalid; it contains invalid characters. Please specify a file size such as '50 GB'."))
                    return
                }
        
                # Validate the overall format of the file size string.
                if ($_.Trim() -notmatch "^-?[0-9]+\.?[0-9]*\s*(PB|TB|GB|MB|KB|B|Bytes)?$") {
                    Write-Error -Category InvalidArgument -Exception (New-Object System.ArgumentException("The file size of '$_' is invalid; it's in an invalid format. Please specify a file size such as '50 GB'"))
                    return
                }

                # If the trimmed input does not end with one of the valid units (PB, TB, GB, MB, KB, B, or Bytes)
                if ($_.Trim() -notmatch "(PB|TB|GB|MB|KB|B|Bytes)$") {
                    # Store the trimmed input string for easier reference.
                    $CurrentString = $_.Trim()

                    # Determine which unit to append based on the default unit ($DefaultTo)
                    $NewString = switch ($DefaultTo) {
                        'PB' { "$CurrentString PB" }
                        'TB' { "$CurrentString TB" }
                        'GB' { "$CurrentString GB" }
                        'MB' { "$CurrentString MB" }
                        'KB' { "$CurrentString KB" }
                        default { "$CurrentString Bytes" }
                    }

                    # Add the newly formatted string to the list of file sizes to convert.
                    $FileSizesToConvert.Add($NewString)
                
                    return
                }

                # Add the validated, trimmed file size string to our list.
                $FileSizesToConvert.Add($_.Trim())
            }

            # If no valid file sizes were found, throw an error.
            if ($FileSizesToConvert.Count -lt 1) {
                throw (New-Object System.ArgumentNullException("You must provide a file size string to convert into bytes."))
            }

            # Process each validated file size string and convert it into bytes.
            $FileSizesToConvert | ForEach-Object {
                $DigitCharacters = $Null

                try {
                    # Extract the numeric portion from the string (digits, decimal point, and optional minus sign)
                    # and convert it to a decimal.
                    [decimal]$DigitCharacters = $_ -replace '[^0-9.-]'
                }
                catch {
                    $_
                    return
                }
            
                # Determine the unit in the file size string using regex in a switch statement.
                # Multiply the numeric value by the corresponding byte constant.
                switch -regex ($_) {
                    'PB$' { $DigitCharacters * 1PB; break }
                    'TB$' { $DigitCharacters * 1TB; break }
                    'GB$' { $DigitCharacters * 1GB; break }
                    'MB$' { $DigitCharacters * 1MB; break }
                    'KB$' { $DigitCharacters * 1KB; break }
                    'B$' { $DigitCharacters * 1; break }
                    'Bytes$' { $DigitCharacters * 1; break }
                }
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

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    # Attempt to determine if the current session is running with Administrator privileges.
    try {
        $IsElevated = Test-IsElevated -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running with Administrator privileges."
        exit 1
    }

    # If the session is not elevated, notify the user and exit.
    if (!$IsElevated) {
        Write-Host -Object "[Error] Access Denied: Please run with Administrator privileges."
        exit 1
    }

    # Attempt to convert the minimum alert size from a file size string to bytes.
    try {
        $MinimumAlertSizeBytes = ConvertTo-Bytes -FileSize $MinimumAlertSize -DefaultTo "GB" -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to determine the minimum file size for alerting and reporting based on '$MinimumAlertSize'."
        exit 1
    }

    # Initialize a list to store error information that need to be in the custom fields.
    $CustomFieldErrorInfo = New-Object System.Collections.Generic.List[Object]

    # Initialize a list to keep track of the search jobs that will be created.
    $SearchJobs = New-Object System.Collections.Generic.List[Object]

    # Loop through each path in the list of paths to search.
    # For each path, loop through each file extension to search.
    foreach ($Path in $PathsToSearch) {
        foreach ($Extension in $ExtensionsToSearch) {
            Write-Host -Object "Searching '$Path' for files with extension '$Extension'..."

            # Start a background job for each path and extension combination.
            $SearchJobs.Add(
                (
                    Start-Job -ScriptBlock {
                        param($Path, $Extension, $MinimumAlertSizeBytes)

                        # Convert file sizes given in bytes to a human-friendly string format (e.g., "2.8 MB").
                        function ConvertTo-FriendlySize {
                            [CmdletBinding()]
                            param(
                                [Parameter(ValueFromPipeline)]
                                [long[]]$Bytes,
                                [Parameter()]
                                [long]$RoundTo = 2
                            )
                            process {
                                # Validate input: If $Bytes is null or an empty string set Bytes equal to 0.
                                if ([String]::IsNullOrEmpty($Bytes)) {
                                    $Bytes = 0
                                }

                                # Process each file size in the input array.
                                $Bytes | ForEach-Object {
                                    $ConvertedBytes = $Null

                                    # If the current file size is 0, immediately output "0 Bytes" and skip further processing.
                                    if ($_ -eq 0) {
                                        "0 Bytes"
                                        return
                                    }

                                    # Define an array of size units from Bytes to Zettabytes
                                    $DataSizes = 'Bytes,KB,MB,GB,TB,PB,EB,ZB' -split ','

                                    try {
                                        # Initialize the conversion variable with the current byte value.
                                        $ConvertedBytes = $_

                                        # This loop repeats as long as the value is divisible by 1KB, incrementing the index by 1 each time. 
                                        # The index is later used to select the appropriate unit for the human-friendly string.
                                        for ( $Index = 0; ($ConvertedBytes -ge 1KB -or $ConvertedBytes -le -1KB) -and $Index -lt $DataSizes.Count; $Index++ ) {
                                            $ConvertedBytes = $ConvertedBytes / 1KB
                                        }
                                    }
                                    catch {
                                        $_
                                        return
                                    }

                                    # If conversion resulted in a null or false value, write an error message.
                                    if (!$ConvertedBytes) {
                                        Write-Error -Category ObjectNotFound -Exception (New-Object System.Data.ObjectNotFoundException("Failed to convert '$_' into a human-friendly string."))
                                        return
                                    }

                                    # Format the converted value rounded to the specified number of decimal places,
                                    # and append the corresponding unit from the $DataSizes array.
                                    "$([System.Math]::Round($ConvertedBytes, $RoundTo)) $($DataSizes[$Index])"
                                }
                            }
                        }

                        # Search for files that match the specified extension under the provided path.
                        # Only include files whose length is greater than or equal to $MinimumAlertSizeBytes.
                        # Select and format file properties for output: Name, FullName, CreationTime, LastWriteTime, Length, and a human-friendly Size.
                        Get-ChildItem -Path $Path -Filter "*$Extension" -Recurse -File -Force | Where-Object { $_.Length -ge $MinimumAlertSizeBytes } | 
                            Select-Object Name, FullName, @{Name = "CreationTime"; Expression = { "$(($_.CreationTime).ToShortDateString()) $(($_.CreationTime).ToShortTimeString())" }},
                            @{Name = "LastWriteTime"; Expression = { "$(($_.LastWriteTime).ToShortDateString()) $(($_.LastWriteTime).ToShortTimeString())" }}, 
                                Length, @{Name = "Size"; Expression = { ConvertTo-FriendlySize $_.Length } } | ConvertTo-Csv
                    } -ArgumentList $Path, $Extension, $MinimumAlertSizeBytes
                )
            )
        }
    }

    # Wait for all search jobs to complete, with a timeout of 9000 seconds (2.5 hours).
    $SearchJobs | Wait-Job -Timeout 9000 | Out-Null

    # Identify any jobs that are still running (i.e., incomplete due to timeout).
    $IncompleteJobs = $SearchJobs | Get-Job | Where-Object { $_.State -eq "Running" }
    if ($IncompleteJobs) {
        Write-Host -Object "[Error] The timeout period of 2.5 hours has been reached, but not all files or directories have been searched!"
        
        # Log an error message in the custom field error information list.
        $CustomFieldErrorInfo.Add(
            [PSCustomObject]@{
                Target  = "N/A"
                Message = "[Error] The timeout period of 2.5 hours has been reached, but not all files or directories have been searched!"
            }
        )
        $ExitCode = 1
    }

    # Collect and process the output from each search job.
    $MatchingItems = $SearchJobs | ForEach-Object {
        $_ | Get-Job | Receive-Job -ErrorAction SilentlyContinue -ErrorVariable JobErrors | ConvertFrom-Csv
    }

    # Remove duplicate entries based on the FullName property.
    if ($MatchingItems) {
        $MatchingItems = $MatchingItems | Sort-Object FullName -Unique
    }

    # Check for any jobs that did not complete successfully and log errors accordingly.
    $FailedJobs = $SearchJobs | Get-Job | Where-Object { $_.State -ne "Completed" }
    if ($JobErrors -or $FailedJobs) {
        $CustomFieldErrorInfo.Add(
            [PSCustomObject]@{
                Target  = "N/A"
                Message = "[Error] Failed to search certain directories due to an error."
            }
        )

        # If there were job errors, log details about each error.
        if ($JobErrors) {
            $JobErrors | ForEach-Object {
                $CustomFieldErrorInfo.Add(
                    [PSCustomObject]@{
                        Target  = $_.TargetObject
                        Message = "[Error] $($_.Exception.Message)"
                    }
                )
            }
        }
        $ExitCode = 1
    }

    # If either the Multiline or WYSIWYG custom field is specified, output an empty line.
    if ($MultilineCustomField -or $WYSIWYGCustomField) {
        Write-Host -Object ""
    }

    # If the Multiline Custom Field is provided, proceed with setting it.
    if ($MultilineCustomField) {
        Write-Host -Object "Attempting to set Custom Field '$MultilineCustomField'."

        # Prepare the output for the custom field as a list of strings.
        $CustomFieldValue = New-Object System.Collections.Generic.List[String]

        # If there are matching items from the file search.
        # Create a duplicate list of matching items with selected properties.
        # This prevents modifying the original list if truncation is needed later.
        if ($MatchingItems) {
            $CustomFieldList = $MatchingItems | Select-Object -Property Name, @{ Name = "Path"; Expression = { $_.FullName } }, 
            @{ Name = "File Creation Time"; Expression = { $_.CreationTime } }, @{ Name = "Last Write Time"; Expression = { $_.LastWriteTime } }, 
            @{ Name = "File Size"; Expression = { $_.Size } }
        }
        else {
            # If no matching items are found, display a message.
            $CustomFieldList = "No .ost or .pst files that are larger than '$MinimumAlertSize' were found."
        }

        # Start formatting the custom field output.
        $CustomFieldValue.Add("`n")
        $CustomFieldValue.Add(($CustomFieldList | Out-String).Trim())

        # If there are any errors captured, format them; otherwise, display a no-errors message.
        if ($CustomFieldErrorInfo.Count -gt 0) {
            $ErrorList = $CustomFieldErrorInfo | Format-List
        }
        else {
            $ErrorList = "No errors were detected while searching for .ost or .pst files larger than '$MinimumAlertSize'."
        }

        # Add two newlines and then the error list to the custom field output.
        $CustomFieldValue.Add("`n`n")
        $CustomFieldValue.Add(($ErrorList | Out-String).Trim())

        # Check if the current output exceeds the 10,000-character limit.
        $Characters = $CustomFieldValue | Out-String | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
        if ($Characters -ge 9500) {
            Write-Warning "10,000 Character Limit has been reached! Trimming output until the character limit is satisfied..."
                
            # Initialize counters for file and error entries and removals.
            $fileEntries = 0
            $errorEntries = 0
            $removals = 0

            # Loop to trim the output until the character count is within limits.
            do {
                # Recreate the custom field output starting with a truncation warning.
                $CustomFieldValue = New-Object System.Collections.Generic.List[String]
                $CustomFieldValue.Add("This info has been truncated to accommodate the 10,000 character limit.")
                $CustomFieldValue.Add("`n`n")
                    
                # Reverse the custom field list (sorted alphabetically) to remove the smallest item.
                if ($CustomFieldList -and $CustomFieldList.Count -gt 0) {
                    [array]::Reverse($CustomFieldList)

                    # Remove the next item (i.e. set it to null) and increment the file entry counter.
                    $CustomFieldList[$fileEntries] = $null
                    $fileEntries++

                    # Reverse the array back to its original order.
                    [array]::Reverse($CustomFieldList)
                }

                # Add the (possibly truncated) custom field list back into the output.
                $CustomFieldValue.Add(($CustomFieldList | Out-String).Trim())

                # If errors exist and the custom field list is now empty, trim the error list.
                if ($CustomFieldErrorInfo.Count -gt 0 -and (!$CustomFieldList -or $CustomFieldList.Count -eq 0)) {
                    [array]::Reverse($ErrorList)

                    # Remove the next error entry (if it matches a row) and increment the error entry counter.
                    $ErrorList[$errorEntries] = $null
                    $errorEntries++

                    # Reverse the error list back to its original order.
                    [array]::Reverse($ErrorList)
                }

                # Add two newlines and then the (possibly trimmed) error list.
                $CustomFieldValue.Add("`n`n")
                $CustomFieldValue.Add(($ErrorList | Out-String).Trim())

                # Recalculate the total number of characters in the output.
                $Characters = $CustomFieldValue | Out-String | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
                $removals++
            }while ($Characters -ge 9500 -and $removals -ge 100000000)

            # If too many removals were needed, indicate a timeout error.
            if ($removals -ge 100000000) {
                Write-Host -Object "[Error] Timeout reached for trimming the multiline output. The current character count is '$Characters'."
                $ExitCode = 1
            }
        }

        # Attempt to set the custom field with the final output.
        try {
            Set-CustomField -Name $MultilineCustomField -Value $CustomFieldValue
            Write-Host -Object "Successfully set the Custom Field '$MultilineCustomField'!"
        }
        catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    # Process and attempt to set the WYSIWYG custom field using search results and errors.
    if ($WYSIWYGCustomField) {
        Write-Host -Object "Attempting to set Custom Field '$WYSIWYGCustomField'."

        # Prepare the output for the WYSIWYG custom field.
        $CustomFieldValue = New-Object System.Collections.Generic.List[String]

        # If there are matching items, convert them into an HTML report.
        if ($MatchingItems) {
            $MatchingFilesTable = $MatchingItems | Select-Object -Property Name, @{ Name = "Path"; Expression = { $_.FullName } }, 
            @{ Name = "File Creation Time"; Expression = { $_.CreationTime } }, @{ Name = "Last Write Time"; Expression = { $_.LastWriteTime } }, 
            @{ Name = "File Size"; Expression = { $_.Size } } | ConvertTo-Html -Fragment

            # Apply formatting to the HTML table headers.
            $MatchingFilesTable = $MatchingFilesTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"
            $MatchingFilesTable = $MatchingFilesTable -replace "<th><b>File Creation Time", "<th style='width: 14em'><b>File Creation Time"
            $MatchingFilesTable = $MatchingFilesTable -replace "<th><b>Last Write Time", "<th style='width: 14em'><b>Last Write Time"
            $MatchingFilesTable = $MatchingFilesTable -replace "<th><b>File Size", "<th style='width: 8em'><b>File Size"
        }
        else {
            # If no matching items are found, provide an HTML message.
            $MatchingFilesTable = "<p>No .ost or .pst files that are larger than '$MinimumAlertSize' were found.</p>"
        }

        # Create a card layout for the matching files HTML report.
        $MatchingFilesCard = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-book'></i>&nbsp;&nbsp;Large OST and PST Files</div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        $MatchingFilesTable
    </div>
</div>"
            
        # Add the HTML card to the custom field output.
        $CustomFieldValue.Add($MatchingFilesCard)

        # If errors were encountered, convert them to an HTML list; otherwise, provide a no-errors message.
        if ($CustomFieldErrorInfo.Count -gt 0) {
            $ErrorInfoTable = $CustomFieldErrorInfo | ConvertTo-Html -As "List" -Fragment
            $ErrorInfoTable = $ErrorInfoTable -replace "<tr><td><hr>", "<tr><td>"
            $ErrorInfoTable = $ErrorInfoTable -replace "<td>Message:</td>", "<td><b>Message:</b></td>"
            $ErrorInfoTable = $ErrorInfoTable -replace "<td>Target:</td>", "<td><b>Target:</b></td>"
        }
        else {
            $ErrorInfoTable = "<p>No errors were detected while searching for .ost or .pst files larger than '$MinimumAlertSize'.</p>"
        }
        
        # Create a card layout for the error information.
        $ErrorInfoCard = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-circle-exclamation' style='color: #D53948;'></i>&nbsp;&nbsp;Search Errors</div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        $ErrorInfoTable
    </div>
</div>"

        # Add the error card to the custom field output.
        $CustomFieldValue.Add($ErrorInfoCard)

        # Check if the WYSIWYG output exceeds the 45,000-character limit.
        $Characters = $CustomFieldValue | Out-String | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
        if ($Characters -ge 43000) {
            Write-Warning "45,000 Character Limit has been reached! Trimming output until the character limit is satisfied..."
                
            # Initialize counters for file and error entries and removals.
            $fileEntries = 0
            $errorEntries = 0
            $removals = 0
            do {
                # Recreate the custom field output starting with a truncation warning.
                $CustomFieldValue = New-Object System.Collections.Generic.List[String]
                $CustomFieldValue.Add("<h1>This info has been truncated to accommodate the 45,000 character limit.</h1>")

                # Sort the HTML table of matching files in reverse alphabetical order by flipping the array.
                [array]::Reverse($MatchingFilesTable)

                # If the next entry is a row, remove it.
                if ($MatchingFilesTable[$fileEntries] -match '<tr><td>') {
                    $MatchingFilesTable[$fileEntries] = $null
                }
                $fileEntries++

                # Flip the array back to its original order.
                [array]::Reverse($MatchingFilesTable)

                # Recreate the matching files card with the (possibly trimmed) table.
                $MatchingFilesCard = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-book'></i>&nbsp;&nbsp;Large OST and PST Files</div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        $MatchingFilesTable
    </div>
</div>"

                # Add the matching files card to the output.
                $CustomFieldValue.Add($MatchingFilesCard)

                # If there are errors and the matching files table is empty, trim the error table.
                if ($CustomFieldErrorInfo.Count -gt 0 -and !($MatchingFilesTable | Where-Object { $_ -match '<tr><td>' })) {
                    [array]::Reverse($ErrorInfoTable)

                    # If the next error row matches, remove it.
                    if ($ErrorInfoTable[$errorEntries] -match '<tr><td>') {
                        $ErrorInfoTable[$errorEntries] = $null
                    }
                    $errorEntries++

                    # Reverse the error table back to its original order.
                    [array]::Reverse($ErrorInfoTable)
                }

                # Recreate the error info card with the (possibly trimmed) error table.
                $ErrorInfoCard = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-circle-exclamation' style='color: #D53948;'></i>&nbsp;&nbsp;Search Errors</div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        $ErrorInfoTable
    </div>
</div>"

                # Add the error info card to the output.
                $CustomFieldValue.Add($ErrorInfoCard)

                # Check if the output now complies with the character limit.
                $Characters = $CustomFieldValue | Out-String | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
                $removals++
            }while ($Characters -ge 43000 -and $removals -le 100000000)

            # If too many removals were needed, output a timeout error.
            if ($removals -ge 100000000) {
                Write-Host -Object "[Error] Timeout reached for trimming the WYSIWYG output. The current character count is '$Characters'."
                $ExitCode = 1
            }
        }
        
        # Attempt to set the WYSIWYG custom field with the final output.
        try {
            Set-CustomField -Name $WYSIWYGCustomField -Value $CustomFieldValue
            Write-Host -Object "Successfully set the Custom Field '$WYSIWYGCustomField'!"
        }
        catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to set the Custom Field '$WYSIWYGCustomField'."
            $ExitCode = 1
        }
    }

    # Output the search results to the activity log.
    if (!$MatchingItems) {
        Write-Host -Object "`nNo .ost or .pst files that are larger than '$MinimumAlertSize' were found.`n"
    }
    else {
        Write-Host -Object "`n[Alert] .ost and .pst files were found that are larger than '$MinimumAlertSize'.`n"
        ($MatchingItems | Format-List -Property Name, FullName, CreationTime, LastWriteTime, Size | Out-String).Trim() | Write-Host
    }

    # If any errors were encountered during the search, output them.
    if ($JobErrors -or $FailedJobs) {
        Write-Host -Object ""
        Write-Host -Object "[Error] Failed to search certain directories due to an error."

        if ($JobErrors) {
            Write-Host -Object ""

            ($JobErrors | ForEach-Object {
                [PSCustomObject]@{
                    Target  = $($_.TargetObject)
                    Message = "[Error] $($_.Exception.Message)"
                }
            } | Format-List | Out-String).Trim() | Write-Host
        }
        $ExitCode = 1
    }

    # Clean up: Remove all search jobs.
    $SearchJobs | Get-Job | Remove-Job -Force

    # Exit the script with the appropriate exit code.
    exit $ExitCode
}
end {
    
    
    
}