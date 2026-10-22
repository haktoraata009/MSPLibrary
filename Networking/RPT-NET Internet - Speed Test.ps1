#Requires -Version 5.1

<#
.SYNOPSIS
    Runs an internet speed test. This test uses M-Lab’s MSAK server under their Acceptable Use Policy. By proceeding, you consent to public collection of network data, including your IP. Details: https://www.measurementlab.net/aup/.
.DESCRIPTION
    Runs an internet speed test. This test uses M-Lab’s MSAK server under their Acceptable Use Policy. By proceeding, you consent to public collection of network data, including your IP. Details: https://www.measurementlab.net/aup/.

.EXAMPLE
    -WysiwygCustomField "WYSIWYG" -MultilineCustomField "multiline" -Append

    ==============================================================================
    This test is provided by Measurement Lab (M-Lab) and is subject to their
    Acceptable Use Policy. By proceeding, you consent to the collection of network
    performance data, including your IP address, which will be publicly available
    to support open internet research. For details, please review M-Lab's
    Acceptable Use Policy at https://www.measurementlab.net/aup/.
    ==============================================================================


    Requesting the nearest throughput test server and authentication information for the next test.
    ### Request Attempt 1 ###
    Response received.
    Attempting to parse the access information from the response.

    Retrieving the network adapter to be used for the test.

    Connecting to the download speed test server at 'wss://msak-mlab2-abc00.mlab.measurement-lab.org/throughput/v1/download?cc=bbr&streams=3&duration=10000&delay=0&bytes=0&client_session_id=*****&access_token=*****&index=0&locate_version=v2&metro_rank=0'.
    [Download Test Stream 1]
    Starting the download speed test.
    Download test completed in 10.23 seconds. Total bytes received: 304087040
    [Download Test Stream 2]
    Starting the download speed test.
    Download test completed in 10.15 seconds. Total bytes received: 324009984
    [Download Test Stream 3]
    Starting the download speed test.
    Download test completed in 10.2 seconds. Total bytes received: 219152384

    Connecting to the upload speed test server at 'wss://msak-mlab2-abc00.mlab.measurement-lab.org/throughput/v1/upload?cc=bbr&streams=3&duration=10000&delay=0&bytes=0&client_session_id=*****&access_token=*****&index=0&locate_version=v2&metro_rank=0'.
    [Upload Test Stream 1]
    Performing the upload speed test.
    Upload test completed in 9.99 seconds. Total bytes sent: 270270464
    [Upload Test Stream 2]
    Performing the upload speed test.
    Upload test completed in 9.99 seconds. Total bytes sent: 320143360
    [Upload Test Stream 3]
    Performing the upload speed test.
    Upload test completed in 9.99 seconds. Total bytes sent: 424214528

    Requesting the nearest latency test server and authentication information for the next test.
    ### Request Attempt 1 ###
    Response received.
    Attempting to parse the access information from the response.

    Connecting to the network latency server at msak-mlab2-abc00.mlab.measurement-lab.org
    Kickoff packet sent
    Performing network latency test.
    Retrieving latency results from https://msak-mlab2-abc00.mlab.measurement-lab.org/latency/v1/result?access_token=*****&index=0&locate_version=v2&metro_rank=0
    Determining the minimum, maximum and average latency from test results.

    Attempting to set the Custom Field 'multiline'.
    Attempting to retrieve existing information from 'multiline'.
    Successfully retrieved the existing information from 'multiline'.
    Successfully set Custom Field 'multiline'!

    Attempting to set the Custom Field 'WYSIWYG'.
    Retrieving existing information from 'WYSIWYG'.
    Converting JSON to HTML.
    Retrieving past results from HTML.
    Successfully retrieved past results from HTML.
    Successfully updated the custom field 'WYSIWYG'!

    ### Speed Test Results ###
    Date        : 2/10/2025 1:00 AM
    Server      : msak-mlab2-abc00.mlab.measurement-lab.org
    Down        : 623.3 Mbps
    Up          : 105.13 Mbps
    Interface   : Ethernet0 - Wired
    MAC Address : 00:00:00:00:00:00
    Jitter      : 5.478 ms
    Latency     : 7.64 ms
    Low         : 5.939 ms
    High        : 67.54 ms

PARAMETER: -MultilineCustomField "ReplaceMeWithAMultilineCustomField"
    Optionally specify the name of a multiline custom field to save the results to.

PARAMETER: -WysiwygCustomField "ReplaceMeWithAWYSIWYGCustomField"
    Optionally specify the name of a WYSIWYG custom field to save the results to.

PARAMETER: -Append
    If saving the results to a multiline or WYSIWYG custom field, append the results rather than overwrite them.

PARAMETER: -SleepBeforeRunning
    Sleep for a random duration between 0 and 60 minutes before running the speed test.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.2
    Release Notes: Added ErrorAction to the Custom Field assignment and renamed the functions used for custom fields.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$MultilineCustomField,
    [Parameter()]
    [String]$WysiwygCustomField,
    [Parameter()]
    [Switch]$Append = [System.Convert]::ToBoolean($env:appendToCustomField),
    [Parameter()]
    [Switch]$SleepBeforeRunning = [System.Convert]::ToBoolean($env:sleepBeforeRunning),
    [Parameter()]
    [String]$CongestionAlgorithm = "bbr",
    [Parameter()]
    [Int]$NumberOfStreams = 3,
    [Parameter()]
    [long]$TestDurationInMilliseconds = 10000,
    [Parameter()]
    [long]$TestSize = 0
)

begin {
    # If script form variables are used, replace the command line parameters with their value.
    if ($env:multilineCustomFieldName) { $MultilineCustomField = $env:multilineCustomFieldName }
    if ($env:wysiwygCustomFieldName) { $WysiwygCustomField = $env:wysiwygCustomFieldName }

    Write-Host -Object "`n=============================================================================="
    Write-Host -Object "This test is provided by Measurement Lab (M-Lab) and is subject to their"
    Write-Host -Object "Acceptable Use Policy. By proceeding, you consent to the collection of network"
    Write-Host -Object "performance data, including your IP address, which will be publicly available"
    Write-Host -Object "to support open internet research. For details, please review M-Lab's"
    Write-Host -Object "Acceptable Use Policy at https://www.measurementlab.net/aup/."
    Write-Host -Object "==============================================================================`n"

    # Check if a multiline custom field is specified
    if ($MultilineCustomField) {
        # Trim any leading or trailing whitespace
        $MultilineCustomField = $MultilineCustomField.Trim()

        # If the trimmed value is empty, display an error and exit
        if (!$MultilineCustomField) {
            Write-Host -Object "[Error] The 'Multiline Custom Field Name' is invalid."
            Write-Host -Object "[Error] Please provide a valid multiline custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }

        # Validate that the field name contains only alphanumeric characters
        if ($MultilineCustomField -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'Multiline Custom Field Name' of '$MultilineCustomField' is invalid as it contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid multiline custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Check if a WYSIWYG custom field is specified
    if ($WysiwygCustomField) {
        # Trim any leading or trailing whitespace
        $WysiwygCustomField = $WysiwygCustomField.Trim()

        # If the trimmed value is empty, display an error and exit
        if (!$WysiwygCustomField) {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' is invalid."
            Write-Host -Object "[Error] Please provide a valid WYSIWYG custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }

        # Validate that the field name contains only alphanumeric characters
        if ($WysiwygCustomField -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' of '$WysiwygCustomField' is invalid as it contains invalid characters.."
            Write-Host -Object "[Error] Please provide a valid WYSIWYG custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # If 'Append' is used without 'WysiwygCustomField' and 'MultilineCustomField', display an error message and exit the script with an error code.
    if ($Append -and !$MultilineCustomField -and !$WysiwygCustomField) {
        Write-Host -Object "[Error] You must specify either a WYSIWYG or Multiline custom field to append data."
        exit 1
    }

    # Determine the supported TLS versions and set the appropriate security protocol
    $SupportedTLSversions = [enum]::GetValues('Net.SecurityProtocolType')
    if ( ($SupportedTLSversions -contains 'Tls13') -and ($SupportedTLSversions -contains 'Tls12') ) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol::Tls13 -bor [System.Net.SecurityProtocolType]::Tls12
    } elseif ( $SupportedTLSversions -contains 'Tls12' ) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    } else {
        # Warn the user if TLS 1.2 and 1.3 are not supported, which may cause the action to fail
        Write-Warning "TLS 1.2 and/or TLS 1.3 are not supported on this system. This action may fail!"
        if ($PSVersionTable.PSVersion.Major -lt 3) {
            Write-Warning "PowerShell 2 / .NET 2.0 doesn't support TLS 1.2."
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
        $ValidFields = "Attachment", "Checkbox", "Date", "Date or Date Time", "Decimal", "Dropdown", "Email", "Integer", "IP Address", "MultiLine",
        "MultiSelect", "Phone", "Secure", "Text", "Time", "URL", "WYSIWYG"

        # Warn the user if the provided type is not valid
        if ($Type -and $ValidFields -notcontains $Type) {
            $Link = "https://ninjarmm.zendesk.com/hc/en-us/articles/16973443979789-Command-Line-Interface-CLI-Supported-Fields-and-Functionality"
            Write-Warning "$Type is an invalid type. Please check here for valid types: $Link"
        }

        # Define types that require options to be retrieved
        $NeedsOptions = "Dropdown"

        # If the property is being set in a document or field and the type needs options, retrieve them
        if ($DocumentName) {
            if ($NeedsOptions -contains $Type) {
                $NinjaPropertyOptions = Ninja-Property-Docs-Options -AttributeName $Name @DocumentationParams 2>&1
            }
        } else {
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
        } else {
            try {
                # Otherwise, set the standard property value
                if ($Piped) {
                    $CustomField = $NinjaValue | Ninja-Property-Set-Piped -Name $Name 2>&1
                } else {
                    $CustomField = Ninja-Property-Set -Name $Name -Value $NinjaValue 2>&1
                }
            } catch {
                Write-Host -Object "[Error] Failed to set custom field."
                throw $_.Exception.Message
            }
        }

        # Throw an error if setting the property failed
        if ($CustomField.Exception) {
            throw $CustomField
        }
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
            if ($Type -Like "Secure") {
                $Link = "https://ninjarmm.zendesk.com/hc/en-us/articles/16973443979789-Command-Line-Interface-CLI-Supported-Fields-and-Functionality"
                throw [System.ArgumentOutOfRangeException]::New(
                    "$Type is an invalid type! Please check here for valid types. $Link"
                )
            }

            # Notify the user that the value is being retrieved from a Ninja document
            Write-Host -Object "Retrieving value from Ninja Document..."
            $NinjaPropertyValue = Ninja-Property-Docs-Get -AttributeName $Name @DocumentationParams 2>&1

            # If the property type requires options, retrieve them
            if ($NeedsOptions -contains $Type) {
                $NinjaPropertyOptions = Ninja-Property-Docs-Options -AttributeName $Name @DocumentationParams 2>&1
            }
        } else {
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

        # Throw an error if the retrieved property value is null or empty
        if (!($NinjaPropertyValue)) {
            throw "The Custom Field '$Name' is empty!"
        }

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

    function Get-TestURLs {
        [CmdletBinding()]
        param(
            [Parameter()]
            [String]$Type,
            [Parameter()]
            [String]$MLabsThroughputAPI = 'https://locate.measurementlab.net/v2/nearest/msak/throughput1',
            [Parameter()]
            [String]$MLabsLatencyAPI = 'https://locate.measurementlab.net/v2/nearest/msak/latency1'
        )

        $ValidTypes = "Throughput", "Latency"
        if ($ValidTypes -notcontains $Type) {
            throw [System.NotSupportedException]::New("'$Type' is not a valid type. Only 'Throughput' and 'Latency' test urls can be retrieved.")
        }

        # Notify user that the script is requesting the closest speed test server
        Write-Host -Object "Requesting the nearest $Type test server and authentication information for the next test."

        # Suppress progress output for web requests
        $PreviousProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        # Attempt to retrieve the nearest test server with up to 3 retries
        $ServerRequestAttempts = 1
        $MaxAttempts = 3
        while ($ServerRequestAttempts -le $MaxAttempts) {
            $SleepTime = Get-Random -Minimum 3 -Maximum 15
            Start-Sleep -Seconds $SleepTime

            if ($ServerRequestAttempts -ne 1) { Write-Host -Object "" }
            Write-Host -Object "### Request Attempt $ServerRequestAttempts ###"

            # Define the web request parameters
            $ServerRequestArgs = @{
                MaximumRedirection = 10
                UseBasicParsing    = $true
                Method             = "Get"
                TimeOut            = 30
            }

            switch ($Type) {
                "Throughput" { $ServerRequestArgs.URI = $MLabsThroughputAPI }
                "Latency" { $ServerRequestArgs.URI = $MLabsLatencyAPI }
            }

            try {
                $ErrorActionPreference = "Stop"

                $MLabsServerRequest = Invoke-WebRequest @ServerRequestArgs
                $MLabsNearestServers = $MLabsServerRequest.Content | ConvertFrom-Json

            } catch {
                # Handle request errors and warn the user
                Write-Host -Object "[Warning] $($_.Exception.Message)"
                Write-Host -Object "[Warning] Failed to retrieve the nearest speed test server location."
            } finally {
                $ErrorActionPreference = "Continue"
            }

            # If the server list was successfully retrieved, exit the retry loop
            if ($MLabsNearestServers) {
                Write-Host -Object "Response received."
                $ServerRequestAttempts = $MaxAttempts
            }

            $ServerRequestAttempts++
        }

        # Restore the original progress preference setting
        $ProgressPreference = $PreviousProgressPreference

        # Exit if no servers were retrieved
        if (!$MLabsNearestServers) {
            Write-Host -Object "[Error] Failed to retrieve the nearest Measurement Labs test server."
            exit 1
        }

        # Attempt to extract download and upload test URLs from the response
        Write-Host -Object "Attempting to parse the access information from the response."

        switch ($Type) {
            "Throughput" {
                $DownloadKey = "wss:///throughput/v1/download"
                $UploadKey = "wss:///throughput/v1/upload"

                $ThroughputServerHostname = $MLabsNearestServers.results.hostname[0]
                $DownloadTestURL = $MLabsNearestServers.results.urls[0]."$DownloadKey"
                $UploadTestURL = $MLabsNearestServers.results.urls[0]."$UploadKey"

                if (!$DownloadTestURL -or !$UploadTestURL -or !$ThroughputServerHostname) {
                    Write-Host -Object "[Error] Failed to retrieve the throughput test URL's from the server response."
                    Write-Host -Object "`n### Throughput Server Response ###"
                    $MLabsNearestServers.Content | Write-Host
                    exit 1
                }
            }
            "Latency" {
                $LatencyAuthKey = "https:///latency/v1/authorize"
                $LatencyResultKey = "https:///latency/v1/result"

                $LatencyAuthUrl = $MLabsNearestServers.results.urls[0]."$LatencyAuthKey"
                $LatencyResultUrl = $MLabsNearestServers.results.urls[0]."$LatencyResultKey"
                $LatencyServerHostname = $MLabsNearestServers.results.hostname[0]

                if (!$LatencyAuthUrl -or !$LatencyResultUrl -or !$LatencyServerHostname) {
                    Write-Host -Object "[Error] Failed to retrieve the latency test URL's from the server response."
                    Write-Host -Object "`n### Latency Server Response ###"
                    $MLabsNearestServers.Content | Write-Host
                    exit 1
                }
            }
        }

        switch ($Type) {
            "Throughput" {
                [PSCustomObject]@{
                    ThroughputServerHostname = $ThroughputServerHostname
                    DownloadTestURL          = $DownloadTestURL
                    UploadTestURL            = $UploadTestURL
                }
            }
            "Latency" {
                [PSCustomObject]@{
                    LatencyServerHostname = $LatencyServerHostname
                    LatencyAuthURL        = $LatencyAuthUrl
                    LatencyResultUrl      = $LatencyResultUrl
                }
            }
        }
    }

    # Generates an RFC 9562 compatible UUID (not the same as New-GUID)
    function New-UUIDv7 {
        # Get the current Unix timestamp in milliseconds (PowerShell 5.1 compatible)
        $UnixTimestampMs = [math]::Floor((New-Object System.DateTimeOffset (Get-Date)).ToUnixTimeMilliseconds())

        # Convert the timestamp to hexadecimal (48 bits)
        $TimeHex = "{0:X8}{1:X4}" -f ($UnixTimestampMs -shr 16), ($UnixTimestampMs -band 0xFFFF)

        # Generate 6 random bytes (48 bits) using a cryptographic RNG
        $RandomBytes = New-Object byte[] 6
        $Rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        $Rng.GetBytes($RandomBytes)
        $RandomBits = ($RandomBytes | ForEach-Object { "{0:X2}" -f $_ }) -join ""

        # Ensure the version bit is set to '7' (UUIDv7)
        $VersionHex = "7" + $RandomBits.Substring(0, 3)  # Version 7 (UUIDv7)

        # Generate the variant (RFC 9562 requires MSB 10xx)
        $VariantByte = [byte]($RandomBytes[3] -band 0x3F -bor 0x80) # Ensures 10xx (RFC 9562-compliant)
        $VariantHex = "{0:X2}" -f $VariantByte

        # Construct the final UUIDv7 format: 8-4-4-4-12
        $UUIDv7 = -join @(
            $TimeHex.Substring(0, 8), # First 8 hex chars (32 bits)
            "-",
            $TimeHex.Substring(8, 4), # Next 4 hex chars (16 bits)
            "-",
            $VersionHex, # 4 hex chars, including version "7"
            "-",
            $VariantHex, # 4 hex chars, including variant
            "-",
            $RandomBits.Substring(6)   # Last 12 hex chars (48 bits)
        )

        return $UUIDv7
    }

    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    # Ensure the script is running with administrator privileges if setting a custom field
    if (!(Test-IsElevated) -and ($MultilineCustomField -or $WysiwygCustomField)) {
        Write-Host -Object "[Error] Administrator privileges are required to set a custom field."
        exit 1
    }

    # Generates an RFC 9562 compatible UUID (not the same as New-GUID)
    $TestUUID = New-UUIDv7

    # Introduce a random delay between 0 to 60 minutes in 2-minute increments
    $MaximumDelay = 60
    $TimeChunks = 2
    $Parts = ($MaximumDelay / $TimeChunks) + 1
    $RandomNumber = Get-Random -Minimum 0 -Maximum $Parts
    $Minutes = $RandomNumber * $TimeChunks

    # If $SleepBeforeRunning is enabled, pause execution for the calculated delay
    if ($SleepBeforeRunning) {
        Write-Host -Object "Waiting for $Minutes minutes before performing the Speedtest as requested.`n"
        Start-Sleep -Seconds $($Minutes * 60)
    }

    # Retrieve the nearest servers test url
    try {
        Write-Host -Object ""
        $ThroughputTestInfo = Get-TestURLs -Type "throughput" -ErrorAction Stop

        $ThroughputServerHostname = $ThroughputTestInfo | Select-Object -ExpandProperty "ThroughputServerHostname"
        $DownloadTestURL = $ThroughputTestInfo | Select-Object -ExpandProperty "DownloadTestURL"
        $UploadTestURL = $ThroughputTestInfo | Select-Object -ExpandProperty "UploadTestURL"
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve the url for the download test."
        exit 1
    }

    # Retrieve the network adapter being used for the speed test
    Write-Host -Object "`nRetrieving the network adapter to be used for the test."
    try {
        # Perform a test connection to the speed test server to determine the interface
        $TestPing = Test-NetConnection -ComputerName $ThroughputServerHostname -ErrorAction Stop

        # If an interface alias is found, get its corresponding network adapter
        if ($TestPing.InterfaceAlias) {
            $Adapter = Get-NetAdapter -Name $TestPing.InterfaceAlias -ErrorAction Stop

            # Determine the adapter type (wired, Wi-Fi, or other)
            $AdapterType = switch -Wildcard ($Adapter.MediaType) {
                "802.3" { "Wired" }
                "*802.11" { "Wi-Fi" }
                Default {
                    "Other"
                }
            }

            # Format the adapter information as a string
            $AdapterString = "$($Adapter.Name) - $AdapterType"
        }

        # If the adapter was not successfully retrieved, throw an error
        if (!$Adapter) {
            throw [System.Net.NetworkInformation.NetworkInformationException]::New("Unable to retrieve the network adapter.")
        }
    } catch {
        # Handle errors related to network adapter retrieval
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve the network adapter to be used for the test."
        $ExitCode = 1
    }

    # Inform the user that the script is connecting to the download speed test server.
    $DownloadTestURL = $DownloadTestURL -replace '\?access_token=', "?cc=$CongestionAlgorithm&streams=$NumberOfStreams&duration=$TestDurationInMilliseconds&delay=0&bytes=$TestSize&client_session_id=$TestUUID&access_token="
    Write-Host -Object "`nConnecting to the download speed test server at '$($DownloadTestURL -replace 'token=[^&]*','token=*****')'."

    # Create a separate job for each download stream to improve performance.
    $DownloadJobs = for ($i = 0; $i -lt $NumberOfStreams; $i++) {
        Start-Job -ArgumentList $DownloadTestURL, $i -ScriptBlock {
            param(
                $DownloadTestURL,
                $DownloadStreamNumber
            )

            Write-Host -Object "[Download Test Stream $($DownloadStreamNumber + 1)]"

            # Function to create a WebSocket connection
            function Create-WebSocket {
                [CmdletBinding()]
                param (
                    [Parameter()]
                    [System.Uri]$URL,
                    [Parameter()]
                    $CancelToken
                )

                try {
                    # Initialize a new WebSocket client
                    $Socket = New-Object System.Net.WebSockets.ClientWebSocket

                    # Set WebSocket options
                    $Socket.Options.AddSubProtocol('net.measurementlab.throughput.v1')
                    $Socket.Options.SetBuffer(64KB, 64KB)

                    # Attempt to connect to the WebSocket server
                    $Socket.ConnectAsync($URL, $CancelToken.Token).Wait()
                } catch [AggregateException] {
                    # Unwrap and display the actual exception
                    foreach ($innerException in $_.Exception.InnerExceptions) {
                        Write-Host "[Error] $($innerException.Message)"
                        if ($innerException.InnerException) {
                            Write-Host "[Error][Inner Exception] $($innerException.InnerException.Message)"
                        }
                    }

                    # Rethrow the error if connection fails
                    throw $_
                } catch {
                    # Rethrow the error if connection fails
                    throw $_
                }

                # Return the WebSocket object
                return $Socket
            }

            # Function to remove/close a WebSocket connection
            function Remove-WebSocket {
                [CmdletBinding()]
                param (
                    [Parameter()]
                    [String]$SocketName,
                    [Parameter()]
                    $Socket
                )

                try {
                    # Ensure the socket exists and is in an open or close-received state before closing
                    if ($Socket -and ($Socket -eq [System.Net.WebSockets.WebSocketState]::Open -or $Socket -eq [System.Net.WebSockets.WebSocketState]::CloseReceived)) {
                        $Socket.CloseAsync(
                            [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,
                            "Closing connection",
                            [Threading.CancellationToken]::None
                        ).Wait()
                    }
                } catch {
                    # Handle errors during WebSocket closure
                    Write-Host -Object "[Error] $($_.Exception.Message)"
                    Write-Host -Object "[Error] Failed to close the websocket '$Socket'."

                    throw $_
                } finally {
                    # Ensure the socket is properly disposed of after closure
                    if ($Socket) {
                        $Socket.Dispose()
                    }
                }
            }

            try {
                # Create a cancellation token to allow for graceful cancellation of WebSocket operations.
                $CancelToken = New-Object System.Threading.CancellationTokenSource

                # Create a WebSocket connection to the download server.
                $DownloadSocket = Create-WebSocket -URL $DownloadTestURL -CancelToken $CancelToken -ErrorAction Stop
            } catch [AggregateException] {
                # If an error occurs, attempt to remove/close the WebSocket before exiting.
                Remove-WebSocket -SocketName "Download WebSocket" -Socket $DownloadSocket -ErrorAction SilentlyContinue

                exit 1
            } catch {
                # If an error occurs, attempt to remove/close the WebSocket before exiting.
                Remove-WebSocket -SocketName "Download WebSocket" -Socket $DownloadSocket -ErrorAction SilentlyContinue

                # Display error messages and exit the script.
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to connect to the download server for the speed test."
                exit 1
            }

            # Notify user that the download speed test is starting.
            Write-Host -Object "Starting the download speed test."

            # Define buffer size for receiving data.
            $BufferSize = 64KB
            $Buffer = New-Object 'byte[]' $BufferSize
            $TotalBytesReceived = 0

            # Start a stopwatch to measure elapsed time for the test.
            $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            # Ensure the WebSocket connection is open before proceeding.
            if ($DownloadSocket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                Write-Host -Object "[Error] The WebSocket required for the download speed test is in an invalid state '$($DownloadSocket.State)'."
                exit 1
            }

            # Set error handling to stop execution upon encountering an error.
            $ErrorActionPreference = "Stop"

            # Begin receiving data in a loop while the WebSocket remains open.
            do {
                try {
                    # Define a buffer for receiving messages.
                    $ReceiveBuffer = [System.ArraySegment[byte]]($Buffer)

                    # Receive data asynchronously through the WebSocket.
                    $ReceiveResult = $DownloadSocket.ReceiveAsync($ReceiveBuffer, $CancelToken.Token).Result

                    # Handle different message types from the WebSocket.
                    switch ($ReceiveResult.MessageType) {
                        # If a close message is received, break the loop.
                        { $_ -eq [System.Net.WebSockets.WebSocketMessageType]::Close } {
                            break
                        }
                        # If binary data is received, increment the total received byte count.
                        { $_ -eq [System.Net.WebSockets.WebSocketMessageType]::Binary } {
                            $TotalBytesReceived += $ReceiveResult.Count
                        }
                        # If text data is received, convert it from JSON and store it.
                        { $_ -eq [System.Net.WebSockets.WebSocketMessageType]::Text } {
                            $MessageText = [System.Text.Encoding]::UTF8.GetString($Buffer, 0, $ReceiveResult.Count)
                            $MessageText
                        }
                    }

                    # Stop the test if it exceeds 120 seconds.
                    if ($Stopwatch.Elapsed.TotalSeconds -ge 120) {
                        Write-Host -Object "[Error] The download speed test timed out."
                        exit 1
                    }
                }
                # Handle aggregate exceptions (multiple errors occurring simultaneously).
                catch [AggregateException] {
                    foreach ($innerException in $_.Exception.InnerExceptions) {
                        Write-Host -Object "[Warning] $($innerException.Message)"

                        if ($innerException.InnerException) {
                            Write-Host -Object "[Warning][Inner Exception] $($innerException.InnerException.Message)"
                        }
                    }

                    # Attempt to reconnect the download WebSocket after an error.
                    Write-Host -Object "Attempting to reconnect the download test WebSocket."
                    Remove-WebSocket -SocketName "Download WebSocket" -Socket $DownloadSocket -ErrorAction SilentlyContinue

                    try {
                        $CancelToken = New-Object System.Threading.CancellationTokenSource
                        $DownloadSocket = Create-WebSocket -URL $DownloadTestURL -CancelToken $CancelToken -ErrorAction Stop
                    } catch {
                        Write-Host -Object "[Error] $($_.Exception.Message)"
                        Write-Host -Object "[Error] Failed to reconnect the download test websocket."
                        exit 1
                    }

                    # Reset the received byte count.
                    $TotalBytesReceived = 0
                }
                # Handle general exceptions and attempt a reconnect.
                catch {
                    Write-Host -Object "[Warning] $($_.Exception.Message)"

                    Write-Host -Object "Attempting to reconnect the download test WebSocket."
                    Remove-WebSocket -SocketName "Download WebSocket" -Socket $DownloadSocket -ErrorAction SilentlyContinue

                    try {
                        $CancelToken = New-Object System.Threading.CancellationTokenSource
                        $DownloadSocket = Create-WebSocket -URL $DownloadTestURL -CancelToken $CancelToken -ErrorAction Stop
                    } catch {
                        Write-Host -Object "[Error] $($_.Exception.Message)"
                        Write-Host -Object "[Error] Failed to reconnect the download test websocket."
                        exit 1
                    }

                    # Reset the received byte count.
                    $TotalBytesReceived = 0
                }
            } while ($DownloadSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open)

            # Restore the default error handling behavior.
            $ErrorActionPreference = "Continue"

            # Stop the stopwatch as the test has completed.
            $Stopwatch.Stop()
            $TotalSeconds = [math]::Round($Stopwatch.Elapsed.TotalSeconds, 2)
            Write-Host -Object "Download test completed in $TotalSeconds seconds. Total bytes received: $TotalBytesReceived"

            # Attempt to close and remove the WebSocket connection.
            try {
                Remove-WebSocket -SocketName "Download WebSocket" -Socket $DownloadSocket -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to close the WebSocket used for the download speed test."
                $ExitCode = 1
            }
        }
    }

    # Wait for all background download jobs to complete before proceeding
    $DownloadJobs | Wait-Job | Out-Null

    # Initialize lists to store received messages, UUIDs, and bytes received
    $DownloadTestReceivedMessages = New-Object System.Collections.Generic.List[object]
    $DownloadJobReceivedMessages = New-Object System.Collections.Generic.List[object]

    # Process results from each download job
    for ($i = 0; $i -lt $NumberOfStreams; $i++) {
        # Retrieve job results and convert from JSON format
        $DownloadJobReceivedMessages = $DownloadJobs[$i] | Receive-Job -ErrorAction SilentlyContinue -ErrorVariable "DownloadJobErrors" | ConvertFrom-Json

        # Extract the unique identifier (UUID) from the received messages
        $UUID = $DownloadJobReceivedMessages | Where-Object { $_.UUID } | Select-Object -ExpandProperty "UUID"

        # Loop through all received messages and ensure each one has a UUID
        $DownloadJobReceivedMessages | ForEach-Object {
            if (!($_.UUID)) {
                # If a message does not have a UUID, assign it the extracted UUID
                $_ | Add-Member -MemberType NoteProperty -Name "UUID" -Value $UUID
            }

            # Store the processed message
            $DownloadTestReceivedMessages.Add($_)
        }
    }

    # Check if any errors occurred while retrieving job results
    $DownloadJobFailures = $DownloadJobs | Get-Job | Where-Object { $_.State -ne "Completed" }

    # Attempt to remove all download jobs forcefully to clean up resources.
    try {
        $DownloadJobs | Remove-Job -Force -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to remove background task(s) used to test the download speed."
        $ExitCode = 1
    }

    # Check if any errors occurred during the download test.
    if ($DownloadJobFailures -or $DownloadJobErrors) {
        Write-Host -Object "[Error] Errors were encountered while testing the download speed."

        # If specific errors were captured, print them to the console.
        if ($DownloadJobErrors) {
            $DownloadJobErrors | ForEach-Object { Write-Host -Object "[Error] $($_.Exception.Message)" }
        }

        exit 1
    }

    # Group the received messages by UUID, as each download test instance should have a unique identifier.
    $GroupedTests = $DownloadTestReceivedMessages | Group-Object -Property UUID

    # Extract the last received message from each download test, which likely contains the final statistics.
    $LastMessageOfEachDownloadTest = $GroupedTests | ForEach-Object {
        $_.Group | Sort-Object ElapsedTime | Select-Object -Last 1
    }

    # Validate that at least some bytes were received and elapsed time exists
    if (!$LastMessageOfEachDownloadTest.Network.BytesSent -or !$DownloadTestReceivedMessages.ElapsedTime) {
        Write-Host -Object "[Error] Failed to retrieve the elapsed time or the bytes received. Unable to calculate the download speed."
        exit 1
    }

    # Retrieve the number of bytes received and elapsed time from the last message.
    $DownloadElapsedTime = $DownloadTestReceivedMessages.ElapsedTime | Sort-Object | Select-Object -Last 1
    try {
        $BytesReceivedForTest = $LastMessageOfEachDownloadTest.Network.BytesSent | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to calculate the total bytes received."
        exit 1
    }

    # Calculate the download speed in Mbps (megabits per second).
    $DownloadSpeedMbps = [math]::Round((($BytesReceivedForTest * 8) / $DownloadElapsedTime), 2)

    # Notify the user that the script is connecting to the upload speed test server.
    $UploadTestURL = $UploadTestURL -replace '\?access_token=', "?cc=$CongestionAlgorithm&streams=$NumberOfStreams&duration=$TestDurationInMilliseconds&delay=0&bytes=$TestSize&client_session_id=$TestUUID&access_token="
    Write-Host -Object "`nConnecting to the upload speed test server at '$($UploadTestURL -replace 'token=[^&]*','token=*****')'."

    # Create a separate job for each upload stream to improve performance.
    $UploadJobs = for ($i = 0; $i -lt $NumberOfStreams; $i++) {
        Start-Job -ArgumentList $UploadTestURL, $i -ScriptBlock {
            param(
                $UploadTestURL,
                $UploadStreamNumber
            )

            Write-Host -Object "[Upload Test Stream $($UploadStreamNumber + 1)]"

            # Function to create a WebSocket connection
            function Create-WebSocket {
                [CmdletBinding()]
                param (
                    [Parameter()]
                    [System.Uri]$URL,
                    [Parameter()]
                    $CancelToken
                )

                try {
                    # Initialize a new WebSocket client
                    $Socket = New-Object System.Net.WebSockets.ClientWebSocket

                    # Set WebSocket options
                    $Socket.Options.AddSubProtocol('net.measurementlab.throughput.v1')
                    $Socket.Options.SetBuffer(64KB, 64KB)

                    # Attempt to connect to the WebSocket server
                    $Socket.ConnectAsync($URL, $CancelToken.Token).Wait()
                } catch [AggregateException] {
                    # Unwrap and display the actual exception
                    foreach ($innerException in $_.Exception.InnerExceptions) {
                        Write-Host "[Error] $($innerException.Message)"
                        if ($innerException.InnerException) {
                            Write-Host "[Error][Inner Exception] $($innerException.InnerException.Message)"
                        }
                    }

                    # Rethrow the error if connection fails
                    throw $_
                } catch {
                    # Rethrow the error if connection fails
                    throw $_
                }

                # Return the WebSocket object
                return $Socket
            }

            # Function to remove/close a WebSocket connection
            function Remove-WebSocket {
                [CmdletBinding()]
                param (
                    [Parameter()]
                    [String]$SocketName,
                    [Parameter()]
                    $Socket
                )

                try {
                    # Ensure the socket exists and is in an open or close-received state before closing
                    if ($Socket -and ($Socket -eq [System.Net.WebSockets.WebSocketState]::Open -or $Socket -eq [System.Net.WebSockets.WebSocketState]::CloseReceived)) {
                        $Socket.CloseAsync(
                            [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,
                            "Closing connection",
                            [Threading.CancellationToken]::None
                        ).Wait()
                    }
                } catch {
                    # Handle errors during WebSocket closure
                    Write-Host -Object "[Error] $($_.Exception.Message)"
                    Write-Host -Object "[Error] Failed to close the websocket '$Socket'."

                    throw $_
                } finally {
                    # Ensure the socket is properly disposed of after closure
                    if ($Socket) {
                        $Socket.Dispose()
                    }
                }
            }

            try {
                # Create a cancellation token source to allow for cancellation of the upload test.
                $CancelToken = New-Object System.Threading.CancellationTokenSource

                # Establish a WebSocket connection to the upload server
                $UploadSocket = Create-WebSocket -URL $UploadTestURL -CancelToken $CancelToken -ErrorAction Stop
            } catch [AggregateException] {
                # If the connection fails, attempt to remove/close the WebSocket.
                Remove-WebSocket -SocketName "Upload WebSocket" -Socket $UploadSocket -ErrorAction SilentlyContinue

                exit 1
            } catch {
                # If the connection fails, attempt to remove/close the WebSocket.
                Remove-WebSocket -SocketName "Upload WebSocket" -Socket $UploadSocket -ErrorAction SilentlyContinue

                # Output an error message and exit the script.
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to connect to the upload server for the speed test."
                exit 1
            }

            # Notify the user that the upload speed test is beginning.
            Write-Host -Object "Performing the upload speed test."

            # Define the buffer size for data transmission.
            $BufferSize = 64KB
            $Buffer = New-Object 'byte[]' $BufferSize

            # Create a random byte generator and fill the buffer with random data.
            $Random = New-Object System.Random
            $Random.NextBytes($Buffer)

            # Initialize a counter for the total bytes sent.
            $TotalBytesSent = 0

            # Start a stopwatch to measure the elapsed time for the test.
            $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            # Ensure the WebSocket connection is open before proceeding with the test.
            if ($UploadSocket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
                Write-Host -Object "[Error] The WebSocket required for the upload speed test is in an invalid state '$($UploadSocket.State)'."
                exit 1
            }

            # Set error handling preference to stop execution on encountering an error.
            $ErrorActionPreference = "Stop"

            # Begin sending data in a loop while the WebSocket remains open.
            do {
                try {
                    # Create buffer objects for sending and receiving data.
                    $SendBuffer = [System.ArraySegment[byte]]($Buffer)
                    $ReceiveBuffer = [System.ArraySegment[byte]]($Buffer)

                    # Receive a response from the server after sending data.
                    if (!$ReceiveTask -and $UploadSocket.State -ne [System.Net.WebSockets.WebSocketState]::CloseReceived) {
                        $ReceiveTask = $UploadSocket.ReceiveAsync($ReceiveBuffer, [System.Threading.CancellationToken]::None)
                    }

                    # If a receive task exists and has completed, process the received data.
                    if ($ReceiveTask -and $ReceiveTask.Wait(0)) {
                        # Extract the received message.
                        $ReceiveResult = $ReceiveTask.Result

                        # If the message type is text, decode and store it.
                        if ($ReceiveResult.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Text) {
                            $MessageText = [System.Text.Encoding]::UTF8.GetString($Buffer, 0, $ReceiveResult.Count)
                            if ($MessageText) {
                                $MessageText
                            }
                        }

                        # Reset the receive task after processing.
                        $ReceiveTask = $Null
                    }

                    # Send the buffered data as a binary message.
                    $UploadSocket.SendAsync($SendBuffer, [System.Net.WebSockets.WebSocketMessageType]::Binary, $true, $CancelToken.Token).Wait()

                    # Receive a response from the server after sending data.
                    if (!$ReceiveTask -and $UploadSocket.State -ne [System.Net.WebSockets.WebSocketState]::CloseReceived) {
                        $ReceiveTask = $UploadSocket.ReceiveAsync($ReceiveBuffer, [System.Threading.CancellationToken]::None)
                    }

                    if ($ReceiveTask -and $ReceiveTask.Wait(0)) {
                        # Extract the actual receive result
                        $ReceiveResult = $ReceiveTask.Result

                        if ($ReceiveResult.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Text) {
                            $MessageText = [System.Text.Encoding]::UTF8.GetString($Buffer, 0, $ReceiveResult.Count)
                            if ($MessageText) {
                                $MessageText
                            }
                        }

                        $ReceiveTask = $Null
                    }

                    # Keep track of the total number of bytes sent.
                    $TotalBytesSent += $BufferSize

                    # Stop the test if it runs for longer than 120 seconds.
                    if ($Stopwatch.Elapsed.TotalSeconds -ge 120) {
                        Write-Host -Object "[Error] The upload speed test timed out."
                        exit 1
                    }
                }
                # Handle aggregate exceptions (multiple errors occurring simultaneously).
                catch [AggregateException] {
                    foreach ($innerException in $_.Exception.InnerExceptions) {
                        Write-Host -Object "[Warning] $($innerException.Message)"
                        if ($innerException.InnerException) {
                            Write-Host -Object "[Warning][Inner Exception] $($innerException.InnerException.Message)"
                        }
                    }

                    # Attempt to reconnect the upload WebSocket after an error.
                    Write-Host -Object "Attempting to reconnect the upload test WebSocket."
                    Remove-WebSocket -SocketName "Upload WebSocket" -Socket $UploadSocket -ErrorAction Stop

                    try {
                        $CancelToken = New-Object System.Threading.CancellationTokenSource
                        $UploadSocket = Create-WebSocket -URL $UploadTestURL -CancelToken $CancelToken -ErrorAction Stop
                    } catch {
                        Write-Host -Object "[Error] $($_.Exception.Message)"
                        Write-Host -Object "[Error] Failed to reconnect the upload test websocket."
                        exit 1
                    }

                    # Reset the total bytes sent count.
                    $TotalBytesSent = 0
                }
                # Handle general exceptions and attempt a reconnect.
                catch {
                    Write-Host -Object "[Warning] $($_.Exception.Message)"

                    Write-Host -Object "Attempting to reconnect the upload test WebSocket."
                    Remove-WebSocket -SocketName "Upload WebSocket" -Socket $UploadSocket -ErrorAction Stop

                    try {
                        $CancelToken = New-Object System.Threading.CancellationTokenSource
                        $UploadSocket = Create-WebSocket -URL $UploadTestURL -CancelToken $CancelToken -ErrorAction Stop
                    } catch {
                        Write-Host -Object "[Error] $($_.Exception.Message)"
                        Write-Host -Object "[Error] Failed to reconnect the upload test websocket."
                        exit 1
                    }

                    # Reset the total bytes sent count.
                    $TotalBytesSent = 0
                }
            } while ($UploadSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open)

            # Restore the default error handling behavior.
            $ErrorActionPreference = "Continue"

            # Stop the stopwatch as the test has completed.
            $Stopwatch.Stop()
            $TotalSeconds = [math]::Round($Stopwatch.Elapsed.TotalSeconds, 2)
            Write-Host -Object "Upload test completed in $TotalSeconds seconds. Total bytes sent: $TotalBytesSent"

            # Attempt to close and remove the WebSocket connection.
            try {
                Remove-WebSocket -SocketName "Upload WebSocket" -Socket $UploadSocket -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to close the WebSocket used for the upload speed test."
                $ExitCode = 1
            }
        }
    }

    # Wait for all upload jobs to complete before processing their results
    $UploadJobs | Wait-Job | Out-Null

    # Initialize lists to store received messages, UUIDs, and bytes sent
    $UploadTestReceivedMessages = New-Object System.Collections.Generic.List[object]
    $UploadJobReceivedMessages = New-Object System.Collections.Generic.List[object]

    # Process results from each upload job
    for ($i = 0; $i -lt $NumberOfStreams; $i++) {
        # Retrieve job results and convert from JSON format
        $UploadJobReceivedMessages = $UploadJobs[$i] | Receive-Job -ErrorAction SilentlyContinue -ErrorVariable "UploadJobErrors" | ConvertFrom-Json

        # Extract the unique identifier (UUID) from the received messages
        $UUID = $UploadJobReceivedMessages | Where-Object { $_.UUID } | Select-Object -ExpandProperty "UUID"

        # Loop through all received messages and ensure each one has a UUID
        $UploadJobReceivedMessages | ForEach-Object {
            if (!($_.UUID)) {
                # If a message does not have a UUID, assign it the extracted UUID
                $_ | Add-Member -MemberType NoteProperty -Name "UUID" -Value $UUID
            }

            # Store the processed message
            $UploadTestReceivedMessages.Add($_)
        }
    }

    # Check if any errors occurred while retrieving job results
    $UploadJobFailures = $UploadJobs | Get-Job | Where-Object { $_.State -ne "Completed" }

    # Attempt to remove all background upload jobs forcefully
    try {
        $UploadJobs | Remove-Job -Force -ErrorAction Stop
    } catch {
        # If an error occurs while removing jobs, display an error message
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to remove background task(s) used to test the upload speed."

        # Set an exit code indicating failure
        $ExitCode = 1
    }

    # Check if any upload jobs encountered errors or did not complete successfully
    if ($UploadJobFailures -or $UploadJobErrors) {
        Write-Host -Object "[Error] Errors were encountered while testing the upload speed."

        # If specific job errors exist, display them
        if ($UploadJobErrors) {
            $UploadJobErrors | ForEach-Object { Write-Host -Object "[Error] $($_.Exception.Message)" }
        }

        # Exit the script due to failure in upload speed test jobs
        exit 1
    }

    # Group all received upload test messages by UUID
    $GroupedTests = $UploadTestReceivedMessages | Group-Object -Property UUID

    # Extract the last received message (most recent result) from each upload test group
    $LastMessageOfEachUploadTest = $GroupedTests | ForEach-Object {
        $_.Group | Sort-Object ElapsedTime | Select-Object -Last 1
    }

    # Validate that at least some bytes were sent and elapsed time exists
    if (!$LastMessageOfEachUploadTest.Network.BytesReceived -or !$UploadTestReceivedMessages.ElapsedTime) {
        Write-Host -Object "[Error] Failed to retrieve the elapsed time or the bytes received. Unable to calculate the upload speed."
        exit 1
    }

    # Retrieve the number of bytes sent and elapsed time from the last message.
    $UploadElapsedTime = $UploadTestReceivedMessages.ElapsedTime | Sort-Object | Select-Object -Last 1
    try {
        $BytesSentForTest = $LastMessageOfEachUploadTest.Network.BytesReceived | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to calculate the total bytes sent."
        exit 1
    }

    # Calculate the upload speed in Mbps (megabits per second).
    $UploadSpeedMbps = [math]::Round((($BytesSentForTest * 8) / $UploadElapsedTime), 2)

    # Retrieve the nearest servers test url
    try {
        Write-Host -Object ""
        $LatencyTestInfo = Get-TestURLs -Type "latency" -ErrorAction Stop

        $LatencyServerHostname = $LatencyTestInfo | Select-Object -ExpandProperty "LatencyServerHostname"
        $LatencyAuthURL = $LatencyTestInfo | Select-Object -ExpandProperty "LatencyAuthURL"
        $LatencyResultUrl = $LatencyTestInfo | Select-Object -ExpandProperty "LatencyResultUrl"
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve the url for the latency test."
        exit 1
    }

    # Notify the user that network latency measurement is starting
    Write-Host -Object "`nConnecting to the network latency server at $LatencyServerHostname"
    try {
        $PreviousProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        $ErrorActionPreference = "Stop"

        # Define arguments for HTTP request to the latency authentication server
        $ServerRequestArgs = @{
            MaximumRedirection = 10
            UseBasicParsing    = $true
            Method             = "Get"
            TimeOut            = 30
        }

        # Send a request to retrieve test details from the authentication server
        $TestRequest = Invoke-WebRequest @ServerRequestArgs -Uri $LatencyAuthUrl
        $TestDetails = $TestRequest.Content

        # Initialize a UDP client for sending and receiving latency test packets
        $UdpClient = New-Object System.Net.Sockets.UdpClient
        $UdpClient.Connect($LatencyServerHostname, 1053)

        # Convert the test details into a byte array and send a kickoff packet
        $KickoffBytes = [System.Text.Encoding]::UTF8.GetBytes($TestDetails)
        $UdpClient.Send($KickoffBytes, $KickoffBytes.Length) | Out-Null
        Write-Host "Kickoff packet sent"

        # Set the duration for the latency test (45 seconds)
        $EndTime = (Get-Date).AddSeconds(45)

        Write-Host "Performing network latency test."
        $ReceivedMessages = New-Object System.Collections.Generic.List[string]

        # Continuously listen for incoming UDP packets until the time limit is reached
        while ((Get-Date) -lt $EndTime) {
            if ($UdpClient.Available -gt 0) {
                # Define an endpoint to store sender's details
                $RemoteEndPoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 1053)

                # Receive the incoming UDP packet and decode its content
                $ReceivedBytes = $UdpClient.Receive([ref]$RemoteEndPoint)
                $ReceivedData = [System.Text.Encoding]::UTF8.GetString($ReceivedBytes)

                # Store received message if it contains valid data
                if ($ReceivedData) {
                    $ReceivedMessages.Add($ReceivedData)
                }

                # Echo back the received packet to the sender for validation
                if ($ReceivedBytes) {
                    $UdpClient.Send($ReceivedBytes, $ReceivedBytes.Length) | Out-Null
                }
            }
        }

        # Close the UDP client after completing the test
        $UdpClient.Close()
    } catch {
        # Handle errors that occur during latency testing
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to determine the network latency."
        exit 1
    } finally {
        $ErrorActionPreference = "Continue"
    }

    try {
        $ErrorActionPreference = "Stop"

        # Notify user that latency results are being retrieved
        Write-Host -Object "Retrieving latency results from $($LatencyResultUrl -replace 'token=[^&]*','token=*****')"

        # Request latency test results from the result server
        $LatencyServerResultResponse = Invoke-WebRequest @ServerRequestArgs -Uri $LatencyResultUrl
        $LatencyTestResults = $LatencyServerResultResponse.Content | ConvertFrom-Json

        # Validate that test results contain valid JSON data
        if (!$LatencyTestResults) {
            throw [System.NullReferenceException]::New("No JSON response from the result server was detected.")
        }

        Write-Host -Object "Determining the minimum, maximum and average latency from test results."

        # Extract Round Trip Time (RTT) measurements from the test results
        $RoundTrips = $LatencyTestResults.RoundTrips | Select-Object -ExpandProperty RTT | Where-Object { $_ }

        # Ensure RTT values are available for further calculations
        if (!$RoundTrips) {
            throw [System.NullReferenceException]::New("No Round Trip Measurements were included in the results.")
        }

        # Compute minimum, maximum, and average Round Trip Time (RTT)
        $MinRTT = $RoundTrips | Measure-Object -Minimum -ErrorAction Stop | Select-Object -ExpandProperty Minimum -ErrorAction Stop
        $MaxRTT = $RoundTrips | Measure-Object -Maximum -ErrorAction Stop | Select-Object -ExpandProperty Maximum -ErrorAction Stop
        $AvgRTT = $RoundTrips | Measure-Object -Average -ErrorAction Stop | Select-Object -ExpandProperty Average -ErrorAction Stop


        # Convert RTT values from microseconds to milliseconds and round to three decimal places.
        $MinLatency = [math]::Round(($MinRTT / 1000), 3)
        $MaxLatency = [math]::Round(($MaxRTT / 1000), 3)
        $AvgLatency = [math]::Round(($AvgRTT / 1000), 3)

        # Compute the standard deviation of RTT values to determine network jitter.
        $RTTStandardDeviation = [math]::Sqrt(($RoundTrips | ForEach-Object { [Math]::Pow(($_ - $AvgRTT), 2) } | Measure-Object -Sum).Sum / ($RoundTrips.Count - 1))
        $Jitter = [math]::Round(($RTTStandardDeviation / 1000), 3)
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to determine the network latency."
        exit 1
    } finally {
        $ErrorActionPreference = "Continue"
    }

    try {
        $ErrorActionPreference = "Stop"

        # Create a formatted result object to store test results.
        $FormattedResult = [PSCustomObject]@{
            DownloadTestId = $DownloadJobReceivedMessages.UUID[0]
            UploadTestId   = $UploadJobReceivedMessages.UUID[0]
            Date           = Get-Date
            Server         = $ThroughputServerHostname
            Down           = "$DownloadSpeedMbps Mbps"
            Up             = "$UploadSpeedMbps Mbps"
            Interface      = $AdapterString
            MacAddress     = $($Adapter.MacAddress -replace "-", ":")
            Jitter         = "$Jitter ms"
            Latency        = "$AvgLatency ms"
            Low            = "$MinLatency ms"
            High           = "$MaxLatency ms"
        }
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to format the results into a human readable format."
        exit 1
    } finally {
        $ErrorActionPreference = "Continue"
    }

    # If a multiline custom field is provided, attempt to store the formatted result.
    if ($MultilineCustomField) {
        try {
            # Notify the user of the attempt to set the custom field.
            Write-Host -Object "`nAttempting to set the Custom Field '$MultilineCustomField'."

            # Initialize a list to hold the custom field value.
            $CustomFieldValue = New-Object System.Collections.Generic.List[String]

            # Format the result as a structured list and add it to the custom field.
            $CustomFieldValue.Add($($FormattedResult | Format-List -Property @{Name = "Date"; Expression = {
                            "$($_.Date.ToShortDateString()) $($_.Date.ToShortTimeString())" }
                    }, Server, Down, Up, Interface, MacAddress, Jitter, Latency,
                    Low, High | Out-String).Trim())

            # If appending to an existing custom field, retrieve and merge previous results.
            if ($Append) {
                try {
                    Write-Host -Object "Attempting to retrieve existing information from '$MultilineCustomField'."
                    $ExistingMultilineLineByLine = New-Object System.Collections.Generic.List[String]

                    # Retrieve existing stored information.
                    Get-CustomField -Name $MultilineCustomField -ErrorAction Stop | Where-Object { $_ } | ForEach-Object {
                        $ExistingMultilineLineByLine.Add($_)
                    }

                    # Process existing multiline data to adjust formatting.
                    $i = 0
                    $ExistingMultilineInfo = $ExistingMultilineLineByLine | ForEach-Object {
                        if ($_ -match 'Date' -and $ExistingMultilineLineByLine[$i - 2] -notmatch 'ResultUrl') {
                            $_ -replace 'Date', "`nDate"
                        }

                        if ($_ -match 'ResultUrl') {
                            $_ -replace 'ResultUrl', "`nResultUrl"
                        }

                        if ($_ -notmatch 'Date' -and $_ -notmatch 'ResultUrl') {
                            $_
                        }

                        $i++
                    }

                    # Append retrieved existing information to the custom field.
                    $CustomFieldValue.Add($($ExistingMultilineInfo | Out-String))

                    Write-Host -Object "Successfully retrieved the existing information from '$MultilineCustomField'."
                } catch {
                    # Warn the user if there was an issue retrieving prior data.
                    Write-Host -Object "[Warning] $($_.Exception.Message)"
                }
            }

            # Check if the character limit for the custom field is exceeded.
            $Characters = ($CustomFieldValue | Out-String) | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
            if ($Characters -ge 9500) {
                Write-Warning "The 10,000-character limit has been reached! Trimming output until the character limit is satisfied."

                # Truncate output if it exceeds the limit.
                $i = 0
                [array]$CustomFieldList = $ExistingMultilineInfo
                do {
                    # Notify the user that data is being truncated.
                    $CustomFieldValue = New-Object System.Collections.Generic.List[String]
                    $CustomFieldValue.Add("This info has been truncated to accommodate the 10,000 character limit.")

                    # Reverse the order of existing data so that the latest entries appear first.
                    [array]::Reverse($CustomFieldList)

                    # Remove the oldest entry to reduce character count.
                    $CustomFieldList[$i] = $null
                    $i++

                    # Restore the original order of remaining data.
                    [array]::Reverse($CustomFieldList)

                    # Append truncated data back to the custom field value.
                    $CustomFieldValue.Add($($CustomFieldList | Out-String))

                    # Recalculate character count and continue trimming if necessary.
                    $Characters = ($CustomFieldValue | Out-String) | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
                }while ($Characters -ge 9500)
            }

            # Store the final processed data in the custom field.
            Set-CustomField -Name $MultilineCustomField -Value ($CustomFieldValue | Out-String) -ErrorAction Stop
            Write-Host -Object "Successfully set Custom Field '$MultilineCustomField'!"
        } catch {
            # Handle errors encountered while setting the custom field.
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    # Check if a WYSIWYG custom field is provided
    if ($WysiwygCustomField) {
        try {
            # Notify the user about setting the custom field
            Write-Host -Object "`nAttempting to set the Custom Field '$WysiwygCustomField'."

            # Initialize a list to store the custom field value
            $CustomFieldValue = New-Object System.Collections.Generic.List[String]

            # Create an HTML structure to display the Speedtest results
            $HTML = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-gauge-high'></i>&nbsp;&nbsp;Speedtest Results</div>
        <div class='card-link-box'>
            <a href='https://www.measurementlab.net/' target='_blank' class='card-link' rel='nofollow noopener noreferrer'>
                <i class='fas fa-arrow-up-right-from-square' style='color: #337ab7;'></i>
            </a>
        </div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        <div class='container' style='padding-left: 0px'>
            <div class='row'>
                <div class='col-sm'>
                    <p class='card-text'><b>Date</b><br>$($FormattedResult.Date.ToShortDateString()) $($FormattedResult.Date.ToShortTimeString())</p>
                </div>
                <div class='col-md'>
                    <p class='card-text' style='white-space: nowrap;'><b>Speedtest Server</b><br>$($FormattedResult.Server)</p>
                </div>
                <div class='col-md'>
                    <p class='card-text' style='white-space: nowrap;'><b>$($FormattedResult.Interface)</b><br><i class='fa-solid fa-ethernet'></i>&nbsp;&nbsp;$($FormattedResult.MacAddress)</p>
                </div>
            </div>
        </div>
        <div class='container my-4' style='width: 70em'>
            <div class='row' style='padding-left: 0px'>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' style='color: #008001; white-space: nowrap;'>$($FormattedResult.Down)</div>
                        <div class='stat-desc'><i class='fa-solid fa-circle-down'></i>&nbsp;&nbsp;Download</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' style='color: #008001; white-space: nowrap;'>$($FormattedResult.Up)</div>
                        <div class='stat-desc'><i class='fa-solid fa-circle-up'></i>&nbsp;&nbsp;Upload</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' style='color: #008001; white-space: nowrap;'>$($FormattedResult.Jitter)</div>
                        <div class='stat-desc'><i class='fa-solid fa-chart-line'></i>&nbsp;&nbsp;Jitter</div>
                    </div>
                </div>
            </div>
            <div class='row' style='padding-left: 0px'>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' style='color: #008001; white-space: nowrap;'>$($FormattedResult.Latency)</div>
                        <div class='stat-desc'><i class='fa-solid fa-server'></i>&nbsp;&nbsp;Latency</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' style='color: #008001; white-space: nowrap;'>$($FormattedResult.High)</div>
                        <div class='stat-desc'><i class='fa-solid fa-chevron-up'></i>&nbsp;&nbsp;High</div>
                    </div>
                </div>
                <div class='col-sm-4'>
                    <div class='stat-card' style='display: flex;'>
                        <div class='stat-value' style='color: #008001; white-space: nowrap;'>$($FormattedResult.Low)</div>
                        <div class='stat-desc'><i class='fa-solid fa-chevron-down'></i>&nbsp;&nbsp;Low</div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
"

            # Adjust the icon based on the adapter type (Wired, Wi-Fi, or Other)
            switch ($AdapterType) {
                "Wi-Fi" {
                    $HTML = $HTML -replace 'fa-solid fa-ethernet', 'fa-solid fa-wifi'
                }
                "Other" {
                    $HTML = $HTML -replace 'fa-solid fa-ethernet', 'fa-solid fa-circle-question'
                }
            }

            # Add the generated HTML content to the custom field
            $CustomFieldValue.Add($HTML)

            # Store the current test result in a list
            $PastResults = New-Object System.Collections.Generic.List[Object]
            $PastResults.Add($FormattedResult)

            # If appending, retrieve existing past results and add them to the list
            if ($Append) {
                try {
                    Write-Host -Object "Retrieving existing information from '$WysiwygCustomField'."
                    $ExistingHTML = Get-CustomField -Name $WysiwygCustomField -ErrorAction Stop

                    Write-Host -Object "Converting JSON to HTML."
                    $ExistingHTML = $ExistingHTML | ConvertFrom-Json | Select-Object -ExpandProperty HTML

                    Write-Host -Object "Retrieving past results from HTML."
                    # Extract existing results from the HTML code block
                    $CodeBlock = $ExistingHTML -split '<code.*' | Where-Object { $_ -match 'DownloadTestId' -or $_ -match 'ResultId' }
                    $CodeBlock = $($CodeBlock -replace '</code>').Trim()
                    $ExistingResults = $CodeBlock | Out-String | ConvertFrom-Json

                    if ($ExistingResults) {
                        Write-Host -Object "Successfully retrieved past results from HTML."
                        $ExistingResults | ForEach-Object { $PastResults.Add($_) }
                    }
                } catch {
                    Write-Host -Object "[Warning] $($_.Exception.Message)"
                }
            }

            # Format and filter past test results for an HTML table, excluding the current test result
            $PastResultsForTable = $PastResults | Where-Object { $_.DownloadTestId -ne $FormattedResult.DownloadTestId } |
                Select-Object @{Name = "Date"; Expression = { $_.Date.DateTime } }, Server, Down, Up, Interface,
                @{Name = "MAC Address"; Expression = { $_.MacAddress } }, Jitter, Latency, Low, High

            # If past results exist, process them into an HTML table
            if ($($PastResultsForTable | Measure-Object).Count -gt 0) {
                # Convert the past results into an HTML table
                $PastResultsTable = $PastResultsForTable | ConvertTo-Html -Fragment

                # Enhance the HTML table with icons for better readability
                $PastResultsTable = $PastResultsTable -replace '<th>Date', "<th style='width: 19em'>Date"
                $PastResultsTable = $PastResultsTable -replace '<th>Down', "<th style='width: 9em'><i class='fa-solid fa-circle-down'></i>&nbsp;&nbsp;Down"
                $PastResultsTable = $PastResultsTable -replace '<th>Up', "<th style='width: 9em'><i class='fa-solid fa-circle-up'></i>&nbsp;&nbsp;Up"
                $PastResultsTable = $PastResultsTable -replace '<th>Jitter', "<th style='width: 7em'><i class='fa-solid fa-chart-line'></i>&nbsp;&nbsp;Jitter"
                $PastResultsTable = $PastResultsTable -replace '<th>Latency', "<th style='width: 7em'><i class='fa-solid fa-server'></i>&nbsp;&nbsp;Latency"
                $PastResultsTable = $PastResultsTable -replace '<th>High', "<th style='width: 7em'><i class='fa-solid fa-chevron-up'></i>&nbsp;&nbsp;High"
                $PastResultsTable = $PastResultsTable -replace '<th>Low', "<th style='width: 7em'><i class='fa-solid fa-chevron-down'></i>&nbsp;&nbsp;Low"
                $PastResultsTable = $PastResultsTable -replace '<th>', '<th><b>'
                $PastResultsTable = $PastResultsTable -replace '</th>', '</b></th>'

                # Add a header and insert the past results table into the custom field value
                $PastResultsCard = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-book'></i>&nbsp;&nbsp;Past Results</div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        $PastResultsTable
    </div>
</div>"
                $CustomFieldValue.Add($PastResultsCard)
            }

            # Store the past results as a hidden JSON block inside the HTML for later retrieval
            $JSON = "<code class='d-none'>
$(($PastResults | ConvertTo-Json) -replace '"',"'")
</code>"
            $CustomFieldValue.Add($JSON)

            # Check if the custom field size exceeds the character limit (200,000 characters)
            $Characters = $CustomFieldValue | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
            if ($Characters -ge 190000) {
                Write-Warning "The 200,000-character limit has been reached! Trimming output until the character limit is satisfied."

                # Trim old records until the character count is within the limit
                $i = 0
                [array]$NewPastResults = $PastResults
                do {
                    # Recreate the custom field output with a truncation warning
                    $CustomFieldValue = New-Object System.Collections.Generic.List[string]
                    $CustomFieldValue.Add("<h1>This information has been truncated to fit within the 200,000-character limit.</h1>")
                    $CustomFieldValue.Add($HTML)

                    # Reverse the list so the newest result is at the top
                    [array]::Reverse($NewPastResults)
                    $NewPastResults[$i] = $Null
                    $i++

                    # Reverse back to the original order
                    [array]::Reverse($NewPastResults)

                    # Recreate the past results table with the truncated dataset
                    $PastResultsForTable = $NewPastResults | Where-Object { $_.DownloadTestId -ne $FormattedResult.DownloadTestId } |
                        Select-Object @{Name = "Date"; Expression = { $_.Date.DateTime } }, Server, Down, Up, Interface,
                        @{Name = "MAC Address"; Expression = { $_.MacAddress } }, Jitter, Latency, Low, High

                    if ($($PastResultsForTable | Measure-Object).Count -gt 0) {
                        $PastResultsTable = $PastResultsForTable | ConvertTo-Html -Fragment

                        # Format the results to have clickable links and a bold header.
                        $PastResultsTable = $PastResultsTable -replace '<th>Date', "<th style='width: 19em'><b>Date</b>"
                        $PastResultsTable = $PastResultsTable -replace '<th>Down', "<th style='width: 9em'><i class='fa-solid fa-circle-down'></i>&nbsp;&nbsp;Down"
                        $PastResultsTable = $PastResultsTable -replace '<th>Up', "<th style='width: 9em'><i class='fa-solid fa-circle-up'></i>&nbsp;&nbsp;Up"
                        $PastResultsTable = $PastResultsTable -replace '<th>Jitter', "<th style='width: 7em'><i class='fa-solid fa-chart-line'></i>&nbsp;&nbsp;Jitter"
                        $PastResultsTable = $PastResultsTable -replace '<th>Latency', "<th style='width: 7em'><i class='fa-solid fa-server'></i>&nbsp;&nbsp;Latency"
                        $PastResultsTable = $PastResultsTable -replace '<th>High', "<th style='width: 7em'><i class='fa-solid fa-chevron-up'></i>&nbsp;&nbsp;High"
                        $PastResultsTable = $PastResultsTable -replace '<th>Low', "<th style='width: 7em'><i class='fa-solid fa-chevron-down'></i>&nbsp;&nbsp;Low"
                        $PastResultsTable = $PastResultsTable -replace '<th>', '<th><b>'
                        $PastResultsTable = $PastResultsTable -replace '</th>', '</b></th>'

                        # Add the reformatted past results
                        $PastResultsCard = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-book'></i>&nbsp;&nbsp;Past Results</div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        $PastResultsTable
    </div>
</div>"
                        $CustomFieldValue.Add($PastResultsCard)
                    }

                    # Store the truncated JSON block
                    $JSON = "<code class='d-none'>
$(($NewPastResults | ConvertTo-Json) -replace '"',"'")
</code>"
                    $CustomFieldValue.Add($JSON)

                    # Verify if trimming is still necessary
                    $Characters = $CustomFieldValue | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
                }while ($Characters -ge 190000)
            }

            # Save the final HTML and JSON content into the WYSIWYG custom field
            Set-CustomField -Name $WysiwygCustomField -Value $CustomFieldValue -ErrorAction Stop
            Write-Host -Object "Successfully updated the custom field '$WysiwygCustomField'!"
        } catch {
            # Catch any errors and log them
            Write-Host -Object "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    # Display the Speed Test results in the activity feed
    Write-Host -Object "`n### Speed Test Results ###"
    ($FormattedResult | Format-List -Property @{Name = "Date"; Expression = { "$($_.Date.ToShortDateString()) $($_.Date.ToShortTimeString())" } },
    Server, Down, Up, Interface, @{Name = "MAC Address"; Expression = { $_.MacAddress } }, Jitter, Latency, Low, High | Out-String).Trim() | Write-Host

    # Exit with appropriate status code
    exit $ExitCode
}
end {
    
    
    
}