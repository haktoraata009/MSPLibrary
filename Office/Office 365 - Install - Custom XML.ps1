#Requires -Version 5.1

<#
.SYNOPSIS
    Installs an Office product using the Office Deployment Tool. Generates a custom configuration XML, supports shared computer licensing, and performs a silent install.
.DESCRIPTION
    Installs an Office product using the Office Deployment Tool. Generates a custom configuration XML, supports shared computer licensing, and performs a silent install.

.EXAMPLE
    -OfficeSuites "Microsoft 365 Apps for enterprise" -Project "Project Online Desktop Client" -Visio "Visio Plan 2"
    -UpdateChannel "Current Channel" -ProductActivation "User based" -UninstallAnyMSIVersions -ForceRestart

    Checking if 'Microsoft 365 Apps for enterprise' is already installed.
    Checking if 'Microsoft Visio' is already installed.
    Checking if 'Microsoft Project' is already installed.
    Verifying that no other editions of Office are installed.
    Verifying that no other editions of Visio are installed.
    Verifying that no other editions of Project are installed.
    Verifying that no conflicting products are installed.
    Attempting to save the deployment XML at 'C:\Windows\TEMP\Office365Install\OfficeInstall.xml'.
    ### Deployment XML ###
    <Configuration ID="b9ae23b4-2822-441b-a8ea-3a39ba9f6c73">
        <Add OfficeClientEdition="64" Channel="Current" MigrateArch="TRUE">
            <Product ID="O365ProPlusRetail">
                <Language ID="MatchOS" Fallback="en-us" />
                <Language ID="MatchInstalled" />
                <Language ID="MatchPreviousMSI" />
                <ExcludeApp ID="Groove" />
                <ExcludeApp ID="Lync" />
                <ExcludeApp ID="Publisher" />
            </Product>
                <Product ID="VisioProRetail">
                <Language ID="MatchOS" Fallback="en-us" />
                <Language ID="MatchInstalled" />
                <Language ID="MatchPreviousMSI" />
                <ExcludeApp ID="Groove" />
            </Product>
            <Product ID="ProjectProRetail">
                <Language ID="MatchOS" Fallback="en-us" />
                <Language ID="MatchInstalled" />
                <Language ID="MatchPreviousMSI" />
                <ExcludeApp ID="Groove" />
            </Product>
        </Add>
        <Property Name="SharedComputerLicensing" Value="0" />
        <Property Name="DeviceBasedLicensing" Value="0" />
        <Property Name="FORCEAPPSHUTDOWN" Value="FALSE" />
        <Property Name="SCLCacheOverride" Value="0" />
        <Property Name="AUTOACTIVATE" Value="1" />
        <Display Level="None" AcceptEULA="TRUE" />
        <Updates Enabled="TRUE" />
        <RemoveMSI />
    </Configuration>

    Retrieving the Office Deployment Tool (ODT).
    Waiting for 34 seconds.
    Downloading the Office Deployment Tool.
    URL 'https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_18925-20138.exe' was given.
    Downloading the file...
    Waiting for 5 seconds.
    Download Attempt 1
    Extracting the Office Deployment Tool from the setup package.
    Downloading your desired office product(s).
    Installing your desired office product(s).
    Install completed.

    Verifying that 'Microsoft 365 Apps for enterprise' was successfully installed.
    Success!
    Verifying that 'Microsoft Visio' was successfully installed.
    Success!
    Verifying that 'Microsoft Project' was successfully installed.
    Success!
    Scheduling restart for 8/5/2025 4:22 PM.

.PARAMETER OfficeSuites
    Specify the Office suite you want to install.

.PARAMETER Visio
    Specify the Visio product you want to install.

.PARAMETER Project
    Specify the Project product you want to install.

.PARAMETER UpdateChannel
    Specify your desired update channel for your selected Office products. This does not apply to volume-licensed products, which use their own specific channel.

.PARAMETER ProductActivation
    Select the activation method to use for your selected Office products. This does not apply to volume-licensed products.

.PARAMETER VolumeKey
    Provide a volume key for your specified volume-licensed products. Only one product can be licensed at a time.

.PARAMETER MicrosoftAccessRuntime365
    Enable the installation of Microsoft Access Runtime 365.

.PARAMETER UninstallAnyMSIVersions
    Enable the removal of existing MSI-based Office installations, including Visio and Project.

.PARAMETER ForceRestart
    Restart the computer after successfully installing your Office product.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 2.0
    Release notes: Split generated XML and user-provided XML into two separate scripts. Added more XML options.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$OfficeSuites,
    [Parameter()]
    [String]$Visio,
    [Parameter()]
    [String]$Project,
    [Parameter()]
    [String]$UpdateChannel = "Current Channel",
    [Parameter()]
    [String]$ProductActivation = "User based",
    [Parameter()]
    [String]$VolumeKey,
    [Parameter()]
    [String]$OfficeInstallDownloadPath = "$env:TEMP",
    [Parameter()]
    [Switch]$MicrosoftAccessRuntime365 = [System.Convert]::ToBoolean($env:microsoftAccessRuntime365),
    [Parameter()]
    [Switch]$UninstallAnyMSIVersions = [System.Convert]::ToBoolean($env:uninstallAnyMsiVersions),
    [Parameter()]
    [Switch]$ForceRestart = [System.Convert]::ToBoolean($env:forceRestart)
)

begin {
    # If script form variables are used, replace the command-line parameters with their values.
    if ($env:officeSuites) { $OfficeSuites = $env:officeSuites }
    if ($env:visio) { $Visio = $env:visio }
    if ($env:project) { $Project = $env:project }
    if ($env:additionalProducts) { $AdditionalProducts = $env:additionalProducts }
    if ($env:updateChannel) { $UpdateChannel = $env:updateChannel }
    if ($env:productActivation) { $ProductActivation = $env:productActivation }
    if ($env:volumeKey) { $VolumeKey = $env:volumeKey }


    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Define valid Office suites for installation
    $ValidOfficeSuites = @(
        "Microsoft 365 Apps for enterprise"
        "Microsoft 365 Apps for enterprise (no Teams)"
        "Microsoft 365 Apps for business"
        "Microsoft 365 Apps for business (no Teams)"
        "Office LTSC Professional Plus 2024 - Volume License"
        "Office LTSC Standard 2024 - Volume License"
        "Office LTSC Professional Plus 2021 - Volume License"
        "Office LTSC Professional Plus 2021 (SPLA) - Volume License"
        "Office LTSC Standard 2021 - Volume License"
        "Office LTSC Standard 2021 (SPLA) - Volume License"
        "Office Professional Plus 2019 - Volume License"
        "Office Standard 2019 - Volume License"
    )

    # Validate the Office suite parameter
    if ($OfficeSuites) {
        if ([String]::IsNullOrWhiteSpace($OfficeSuites)) {
            Write-Host -Object "[Error] You must provide a valid Office suite to install."
            Write-Host -Object "### Valid Office Suites ###"
            $ValidOfficeSuites
            exit 1
        }

        $OfficeSuites = $OfficeSuites.Trim()

        # Check if the provided Office suite is valid
        if ($ValidOfficeSuites -notcontains $OfficeSuites) {
            Write-Host -Object "[Error] An invalid Office suite of '$OfficeSuites' was given. Please specify a valid Office suite to install."
            Write-Host -Object "### Valid Office Suites ###"
            $ValidOfficeSuites
            exit 1
        }
    }

    # Validate the Visio product parameter
    if ($Visio) {
        $ValidVisioProducts = @(
            "Visio Plan 2"
            "Visio LTSC Professional 2024 - Volume License"
            "Visio LTSC Standard 2024 - Volume License"
            "Visio LTSC Professional 2021 - Volume License"
            "Visio LTSC Standard 2021 - Volume License"
            "Visio Professional 2019 - Volume License"
            "Visio Standard 2019 - Volume License"
            "Visio Professional 2016 - Volume License"
            "Visio Standard 2016 - Volume License"
        )

        if ([String]::IsNullOrWhiteSpace($Visio)) {
            Write-Host -Object "[Error] The Visio product provided is invalid. Please specify a valid Visio product or leave it blank."
            Write-Host -Object "### Valid Visio Products ###"
            $ValidVisioProducts
            exit 1
        }

        $Visio = $Visio.Trim()

        # Check if the provided Visio product is valid
        if ($ValidVisioProducts -notcontains $Visio) {
            Write-Host -Object "[Error] An invalid Visio product of '$Visio' was given. Please specify a valid Visio product or leave it blank."
            Write-Host -Object "### Valid Visio Products ###"
            $ValidVisioProducts
            exit 1
        }
    }

    # Validate the Project product parameter
    if ($Project) {
        $ValidProjectProducts = @(
            "Project Online Desktop Client"
            "Project Professional 2024 - Volume License"
            "Project Standard 2024 - Volume License"
            "Project Professional 2021 - Volume License"
            "Project Standard 2021 - Volume License"
            "Project Professional 2019 - Volume License"
            "Project Standard 2019 - Volume License"
            "Project Professional 2016 - Volume License"
            "Project Standard 2016 - Volume License"
        )

        if ([String]::IsNullOrWhiteSpace($Project)) {
            Write-Host -Object "[Error] The Project product provided is invalid. Please specify a valid Project product or leave it blank."
            Write-Host -Object "### Valid Project Products ###"
            $ValidProjectProducts
            exit 1
        }

        $Project = $Project.Trim()

        # Check if the provided Project product is valid
        if ($ValidProjectProducts -notcontains $Project) {
            Write-Host -Object "[Error] An invalid Project product of '$Project' was given. Please specify a valid Project product or leave it blank."
            Write-Host -Object "### Valid Project Products ###"
            $ValidProjectProducts
            exit 1
        }
    }

    # Ensure at least one product is provided for installation
    if (!$OfficeSuites -and !$Visio -and !$Project -and !$MicrosoftAccessRuntime365) {
        Write-Host -Object "[Error] You must provide at least one product to install."
        exit 1
    }

    # Define valid update channels
    $ValidUpdateChannels = @(
        "Current Channel"
        "Current Channel (Preview)"
        "Monthly Enterprise Channel"
        "Semi-Annual Enterprise Channel"
        "Semi-Annual Enterprise Channel (Preview)"
    )

    # Validate the update channel parameter
    if ([String]::IsNullOrWhiteSpace($UpdateChannel)) {
        Write-Host -Object "[Error] You must specify a valid update channel."
        Write-Host -Object "### Valid Update Channels ###"
        $ValidUpdateChannels
        exit 1
    }

    $UpdateChannel = $UpdateChannel.Trim()

    # Check if the provided update channel is valid
    if ($ValidUpdateChannels -notcontains $UpdateChannel) {
        Write-Host -Object "[Error] An invalid update channel of '$UpdateChannel' was given. Please specify a valid update channel."
        Write-Host -Object "### Valid Update Channels ###"
        $ValidUpdateChannels
        exit 1
    }

    # Define valid product activation methods
    $ValidProductActivation = @(
        "User based"
        "Shared Computer"
        "Device based"
    )

    # Validate the product activation parameter
    if ([String]::IsNullOrWhiteSpace($ProductActivation)) {
        Write-Host -Object "[Error] You must specify a valid product activation method."
        Write-Host -Object "### Valid Product Activation Methods ###"
        $ValidProductActivation
        exit 1
    }

    $ProductActivation = $ProductActivation.Trim()

    # Check if the provided product activation method is valid
    if ($ValidProductActivation -notcontains $ProductActivation) {
        Write-Host -Object "[Error] An invalid product activation method of '$ProductActivation' was given. Please select a valid product activation method."
        Write-Host -Object "### Valid Product Activation Methods ###"
        $ValidProductActivation
        exit 1
    }

    # Validate the provided volume key if it exists
    if ($VolumeKey) {
        # Check if the volume key is blank or contains only whitespace
        if ([string]::IsNullOrWhiteSpace($VolumeKey)) {
            Write-Host -Object "[Error] The volume key you have provided is blank."
            exit 1
        }

        # Trim any whitespace from the volume key
        $VolumeKey = $VolumeKey.Trim()

        # Ensure the volume key matches the expected format (five groups of five alphanumeric characters separated by dashes)
        if ($VolumeKey -notmatch "(?:[A-Z0-9]{5}-){4}[A-Z0-9]{5}") {
            Write-Host -Object "[Error] The volume key '$VolumeKey' doesn't look correct. Typically, Office keys contain five groups of five alphanumeric characters separated by dashes."
            exit 1
        }
    }

    # Ensure a volume key is only used with volume products
    if ($VolumeKey -and $OfficeSuites -notmatch "Volume" -and $Visio -notmatch "Volume" -and $Project -notmatch "Volume") {
        Write-Host -Object "[Error] You must select at least one volume product to use this volume key."
        exit 1
    }

    # Validate that only one volume product is selected when a volume key is provided
    if ($VolumeKey) {
        # Increment the count for each selected volume product
        if ($OfficeSuites -match "Volume") { $VolumeCount = $VolumeCount + 1 }
        if ($Visio -match "Volume") { $VolumeCount = $VolumeCount + 1 }
        if ($Project -match "Volume") { $VolumeCount = $VolumeCount + 1 }

        # Check if more than one volume product is selected
        if ($VolumeCount -gt 1) {
            Write-Host -Object "[Error] There are more than one volume products selected; however, only one volume key can be specified."
            exit 1
        }
    }

    if (!$VolumeKey -and ($OfficeSuites -match "Volume" -or $Visio -match "Volume" -or $Project -match "Volume")) {
        Write-Host -Object "[Warning] No volume key was provided for your volume-licensed product(s)."
        Write-Host -Object "[Warning] A KMS key will be used to proceed with the installation of your selected product(s)."
        Write-Host -Object "[Warning] Note: KMS keys will not activate your product, and it will remain 'unlicensed' after installation.`n"
    }

    function Get-ODTURL {
        [CmdletBinding()]
        param()

        # Define the URL for the Office Deployment Tool download page
        $Uri = 'https://www.microsoft.com/en-us/download/details.aspx?id=49117'
        $DownloadURL = $Null

        # Attempt to retrieve the download link up to 3 times
        for ($i = 1; $i -le 3; $i++) {
            try {
                # Wait for a random duration between 3 and 60 seconds before each attempt
                $SleepTime = Get-Random -Minimum 3 -Maximum 60
                Write-Host -Object "Waiting for $SleepTime seconds."
                Start-Sleep -Seconds $SleepTime

                # Fetch the webpage content using Invoke-WebRequest
                $MSWebPage = Invoke-WebRequest -Uri $Uri -UseBasicParsing -MaximumRedirection 10 -ErrorAction Stop

                # Search for the first link containing "officedeploymenttool" in the href attribute
                $DownloadURL = $MSWebPage.Links | Where-Object { $_.href -like "*officedeploymenttool*.exe" } | Select-Object -ExpandProperty href -First 1

                # Break the loop if a valid download URL is found
                if ($DownloadURL) {
                    break
                }

                # Warn if the download link is not found
                Write-Host "[Warning] Unable to find the download link for the Office Deployment Tool at: $Uri. Attempt $i of 3."
            } catch {
                # Warn if unable to connect to the Microsoft website
                Write-Host "[Warning] Unable to connect to the Microsoft website. Attempt $i of 3."
            }
        }

        # Throw an exception if the download link could not be retrieved after 3 attempts
        if (!$DownloadURL) {
            throw (New-Object System.Exception("Unable to find the download link for the Office Deployment Tool at: $Uri"))
        }

        # Return the download URL
        return $DownloadURL
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
            [Switch]$Overwrite
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
        if (!$URL) { throw [System.ArgumentNullException]::New("You must provide a URL.") }
        if (!$Path) { throw [System.ArgumentNullException]::New("You must provide a file path.") }

        # If the URL doesn't start with http or https, prepend https.
        if ($URL -notmatch "^http") {
            try {
                $URL = [System.Uri]"https://$URL"
            } catch {
                throw [System.UriFormatException]::New("[Error] The URL '$($URL.OriginalString)' is not valid. Please ensure it starts with http:// or https:// and is properly formatted.")
            }
            Write-Host -Object "[Warning] The URL given is missing http(s). The URL has been modified to the following: '$($URL.AbsoluteUri)'."
        } else {
            # Display the URL being used for the download.
            Write-Host -Object "URL '$($URL.AbsoluteUri)' was given."
        }

        # Check if the path contains invalid characters or reserved characters after the drive letter.
        if ($Path -and ($Path -match '[/*?"<>|]' -or $Path.SubString(3) -match "[:]")) {
            throw [System.IO.InvalidDataException]::New("[Error] The file path specified '$Path' contains one of the following invalid characters: '/*?`"<>|:'")
        }

        # Check each folder in the path to ensure it isn't a reserved name (CON, PRN, AUX, etc.).
        $Path -split '\\' | ForEach-Object {
            $Folder = ($_).Trim()
            if ($Folder -match '^CON$' -or $Folder -match '^PRN$' -or $Folder -match '^AUX$' -or $Folder -match '^NUL$' -or $Folder -match '^LPT\d$' -or $Folder -match '^COM\d+$') {
                throw [System.IO.InvalidDataException]::New("[Error] An invalid folder name was given in '$Path'. The following folder names are reserved: CON, PRN, AUX, NUL, COM1-9, LPT1-9")
            }
        }

        # Temporarily disable progress reporting to speed up script performance
        $PreviousProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        # If no filename is included in the path (no extension), try to determine it from Content-Disposition.
        if (($Path | Split-Path -Leaf) -notmatch "[.]") {

            Write-Host -Object "No filename provided in '$Path'. Checking the URL for a suitable filename."

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

                throw [System.NotSupportedException]::New("You must provide a filename for systems not running PowerShell 4 or higher.")
            }

            if (!$Filename) {
                Write-Host -Object "No filename was discovered in the URL. Attempting to discover the filename via the Content-Disposition header."
                $Request = 1

                # Make multiple attempts (as defined by $Attempts) to retrieve the Content-Disposition header.
                while ($Request -le $Attempts) {
                    # If SkipSleep is not set, wait for a random time between 3 and 15 seconds before each attempt
                    if (!($SkipSleep)) {
                        $SleepTime = Get-Random -Minimum 3 -Maximum 15
                        Write-Host -Object "Waiting for $SleepTime seconds."
                        Start-Sleep -Seconds $SleepTime
                    }

                    if ($Request -ne 1) { Write-Host "" }
                    Write-Host -Object "Attempt $Request"

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

                throw [System.IO.FileNotFoundException]::New("Unable to find a suitable filename from the URL.")
            }
        }

        # If the file already exists at the specified path, restore the progress setting and throw an error.
        if ((Test-Path -Path $Path -ErrorAction SilentlyContinue) -and !$Overwrite) {
            # Restore the original progress preference setting
            $ProgressPreference = $PreviousProgressPreference

            throw [System.IO.IOException]::New("A file already exists at the path '$Path'.")
        }

        # Remove any extra slashes from the path.
        $Path = $Path -replace '\\+', '\'

        # Ensure that the destination folder exists, if not, try to create it.
        $DestinationFolder = $Path | Split-Path
        if (!(Test-Path -Path $DestinationFolder -ErrorAction SilentlyContinue)) {
            try {
                Write-Host -Object "Attempting to create the folder '$DestinationFolder' as it does not exist."
                New-Item -Path $DestinationFolder -ItemType "directory" -ErrorAction Stop | Out-Null
                Write-Host -Object "Successfully created the folder."
            } catch {
                # Restore the original progress preference setting
                $ProgressPreference = $PreviousProgressPreference

                throw $_
            }
        }

        Write-Host -Object "Downloading the file..."

        # Initialize the download attempt counter.
        $DownloadAttempt = 1
        while ($DownloadAttempt -le $Attempts) {
            # If SkipSleep is not set, wait for a random time between 3 and 15 seconds before each attempt
            if (!($SkipSleep)) {
                $SleepTime = Get-Random -Minimum 3 -Maximum 15
                Write-Host -Object "Waiting for $SleepTime seconds."
                Start-Sleep -Seconds $SleepTime
            }

            # Provide a visual break between attempts
            if ($DownloadAttempt -ne 1) { Write-Host "" }
            Write-Host -Object "Download Attempt $DownloadAttempt"

            try {
                if ($PSVersionTable.PSVersion.Major -lt 4) {
                    # For older versions of PowerShell, use WebClient to download the file
                    $WebClient = New-Object System.Net.WebClient
                    $WebClient.DownloadFile($URL, $Path)
                } else {
                    # For PowerShell 4.0 and above, use Invoke-WebRequest with specified arguments
                    $WebRequestArgs = @{
                        Uri                = $URL
                        OutFile            = $Path
                        MaximumRedirection = 10
                        UseBasicParsing    = $true
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
            } else {
                # Warn the user if the download attempt failed
                Write-Host -Object "[Warning] File failed to download.`n"
            }

            # Increment the attempt counter
            $DownloadAttempt++
        }

        # Restore the original progress preference setting
        $ProgressPreference = $PreviousProgressPreference

        # Final check: if the file still doesn't exist, report an error and exit
        if (!(Test-Path $Path)) {
            throw [System.IO.FileNotFoundException]::New("[Error] Failed to download file. Please verify the URL of '$URL'.")
        } else {
            # If the download succeeded, return the path to the downloaded file
            return $Path
        }
    }

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
            # Initialize a list to store found installation keys
            $InstallList = New-Object System.Collections.Generic.List[Object]

            # If no custom user base key is provided, search in the standard HKLM paths
            if (!$UserBaseKey) {
                $ErrorActionPreference = "Stop"
                # Search in the 32-bit uninstall registry key and add results to the list
                try {
                    $Result = Get-ChildItem -Path "Registry::HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" }
                    if ($Result) { $InstallList.Add($Result) }
                } catch {
                    Write-Host -Object "[Warning] Failed to retrieve registry keys at 'HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'."
                    throw $_
                }

                # Search in the 64-bit uninstall registry key and add results to the list
                try {
                    $Result = Get-ChildItem -Path "Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" }
                    if ($Result) { $InstallList.Add($Result) }
                } catch {
                    Write-Host -Object "[Warning] Failed to retrieve registry keys at 'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'."
                    throw $_
                }

                $ErrorActionPreference = "Continue"
            } else {
                $ErrorActionPreference = "Stop"
                # If a custom user base key is provided, search in the corresponding Wow6432Node path and add results to the list
                try {
                    $Result = Get-ChildItem -Path "$UserBaseKey\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" }
                    if ($Result) { $InstallList.Add($Result) }
                } catch {
                    Write-Host -Object "[Warning] Failed to retrieve registry keys at '$UserBaseKey\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'."
                    throw $_
                }

                try {
                    # Search in the custom user base key for the standard uninstall path and add results to the list
                    $Result = Get-ChildItem -Path "$UserBaseKey\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" }
                    if ($Result) { $InstallList.Add($Result) }
                } catch {
                    Write-Host -Object "[Warning] Failed to retrieve registry keys at '$UserBaseKey\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'."
                    throw $_
                }

                $ErrorActionPreference = "Continue"
            }

            # If the UninstallString switch is set, return only the UninstallString property of the found keys
            if ($UninstallString) {
                $InstallList | Select-Object -ExpandProperty UninstallString -ErrorAction SilentlyContinue
            } else {
                $InstallList
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
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running this script in an elevated session."
        exit 1
    }

    if (!$IsElevated) {
        Write-Host -Object "[Error] The user '$env:USERNAME' is not running this script in an elevated session. Please run this script as System or in an elevated session."
        exit 1
    }

    # Check if the Office installation directory exists, if not, create it.
    if (!(Test-Path -Path "$OfficeInstallDownloadPath\Office365Install" -ErrorAction SilentlyContinue)) {
        try {
            New-Item -Path "$OfficeInstallDownloadPath\Office365Install" -ItemType Directory -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to create the Office download directory at '$OfficeInstallDownloadPath\Office365Install'."
            exit 1
        }
    }

    # Initialize a list to store products to search for during installation validation.
    $ProductsToSearchFor = New-Object System.Collections.Generic.List[String]

    # Add the Office suite to the search list if specified.
    if ($OfficeSuites) {
        $OfficeProductToSearchFor = $OfficeSuites -replace "- Volume License" -replace "no Teams" -replace "SPLA" -replace "[()]"
        $ProductsToSearchFor.Add($OfficeProductToSearchFor.Trim())
    }

    # Add the Visio product to the search list if specified.
    if ($Visio) {
        $VisioProductToSearchFor = $Visio -replace "- Volume License" -replace "no Teams" -replace "SPLA" -replace "[()]" -replace "Visio Plan 2", "Microsoft Visio"
        $ProductsToSearchFor.Add($VisioProductToSearchFor.Trim())
    }

    # Add the Project product to the search list if specified.
    if ($Project) {
        $ProjectProductToSearchFor = $Project -replace "- Volume License" -replace "no Teams" -replace "SPLA" -replace "[()]" -replace "Project Online Desktop Client", "Microsoft Project"
        $ProductsToSearchFor.Add($ProjectProductToSearchFor.Trim())
    }

    # Add Microsoft Access Runtime 365 to the search list if specified.
    if ($MicrosoftAccessRuntime365) {
        $ProductsToSearchFor.Add("Microsoft Access Runtime 365")
    }

    # Check if any of the specified products are already installed.
    $ProductsToSearchFor | ForEach-Object {
        try {
            Write-Host -Object "Checking if '$_' is already installed."
            $InstalledProduct = Find-InstallKey -DisplayName $_ -ErrorAction Stop
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to check if the product is already installed."
            exit 1
        }

        # Exit if the product is already installed.
        if ($InstalledProduct) {
            Write-Host -Object "[Error] The selected product '$_' is already installed. Please uninstall it prior to using this script."
            exit 1
        }
    }

    # Validate that no other editions of Office are installed.
    if ($OfficeSuites) {
        Write-Host -Object "Verifying that no other editions of Office are installed."

        $OfficeSuitesToSearchFor = $ValidOfficeSuites -replace "- Volume License" -replace "no Teams" -replace "SPLA" -replace "[()]" | ForEach-Object { $_.Trim() }

        $OfficeSuitesToSearchFor | Select-Object -Unique | ForEach-Object {
            try {
                $InstalledProduct = Find-InstallKey -DisplayName $_ -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to check if Office is already installed."
                exit 1
            }

            # Exit if another edition of Office is installed.
            if ($InstalledProduct) {
                Write-Host -Object "[Error] The selected product '$_' is already installed."
                Write-Host -Object "[Error] You cannot install a different version of Office while it is installed."
                exit 1
            }
        }
    }

    # Validate that no other editions of Visio are installed.
    if ($Visio) {
        Write-Host -Object "Verifying that no other editions of Visio are installed."

        $VisioProductsToSearchFor = $ValidVisioProducts -replace "- Volume License" -replace "no Teams" -replace "SPLA" -replace "[()]" -replace "Visio Plan 2", "Microsoft Visio" | ForEach-Object { $_.Trim() }

        $VisioProductsToSearchFor | Select-Object -Unique | ForEach-Object {
            try {
                $InstalledProduct = Find-InstallKey -DisplayName $_ -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to check if Visio is already installed."
                exit 1
            }

            # Exit if another edition of Visio is installed.
            if ($InstalledProduct) {
                Write-Host -Object "[Error] The selected product '$_' is already installed."
                Write-Host -Object "[Error] You cannot install a different version of Visio while it is installed."
                exit 1
            }
        }
    }

    # Validate that no other editions of Project are installed.
    if ($Project) {
        Write-Host -Object "Verifying that no other editions of Project are installed."

        $ProjectProductsToSearchFor = $ValidProjectProducts -replace "- Volume License" -replace "no Teams" -replace "SPLA" -replace "[()]" -replace "Project Online Desktop Client", "Microsoft Project" | ForEach-Object { $_.Trim() }

        $ProjectProductsToSearchFor | Select-Object -Unique | ForEach-Object {
            try {
                $InstalledProduct = Find-InstallKey -DisplayName $_ -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to check if Project is already installed."
                exit 1
            }

            # Exit if another edition of Project is installed.
            if ($InstalledProduct) {
                Write-Host -Object "[Error] The selected product '$_' is already installed."
                Write-Host -Object "[Error] You cannot install a different version of Project while it is installed."
                exit 1
            }
        }
    }

    # Check for conflicting products if Visio or Project is selected
    if ($Visio -or $Project) {
        Write-Host -Object "Verifying that no conflicting products are installed."

        # Filter valid Office volume editions and clean up their names
        $OfficeVolumeEditions = $ValidOfficeSuites | Where-Object { $_ -match "Volume" }
        $OfficeVolumeEditions = $OfficeVolumeEditions -replace "- Volume License" -replace "no Teams" -replace "SPLA" -replace "[()]" | ForEach-Object { $_.Trim() }

        # Check if any conflicting Office volume editions are installed
        $OfficeVolumeEditions | Select-Object -Unique | ForEach-Object {
            try {
                $InstalledProduct = Find-InstallKey -DisplayName $_ -ErrorAction Stop
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to check if Office is already installed."
                exit 1
            }

            if ($InstalledProduct) {
                Write-Host -Object "[Error] A conflicting product '$_' is installed."
                Write-Host -Object "[Error] You cannot install a volume edition of Visio or Project while a volume edition of Office is installed."
                Write-Host -Object "[Error] If you want to use a volume edition of Office and Visio or Project at the same time, they will need to be installed together."
                exit 1
            }
        }
    }

    # Check for conflicts if Microsoft Access Runtime 365 is selected
    if ($MicrosoftAccessRuntime365) {
        Write-Host -Object "Verifying that no conflicting products are installed."

        try {
            # Check registry keys for installed versions of Microsoft Access
            $64BitRegistryKey = Get-ChildItem -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths" -ErrorAction Stop | Where-Object { $_.Name -like "*MSACCESS.EXE*" }
            $32BitRegistryKey = Get-ChildItem -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths" -ErrorAction Stop | Where-Object { $_.Name -like "*MSACCESS.EXE*" }
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Unable to verify that no conflicting products are currently installed."
            exit 1
        }

        # Exit if the full version of Microsoft Access is already installed
        if ($32BitRegistryKey -or $64BitRegistryKey) {
            Write-Host -Object "[Error] The full version of Microsoft Access is already installed."
            exit 1
        }
    }

    # Verify Access is not included with the selected Office suite
    if ($OfficeSuites -and $MicrosoftAccessRuntime365) {
        Write-Host -Object "Verifying Access is not already included with your selected version of Office."

        # Filter Office suites that include Access
        $OfficeAdditionsThatIncludeAccess = $ValidOfficeSuites | Where-Object { $_ -match "365" -or $_ -match "Professional" }

        # Exit if the selected Office suite already includes Access
        if ($OfficeAdditionsThatIncludeAccess -contains $OfficeSuites) {
            Write-Host -Object "[Error] '$OfficeSuites' already includes the full version of Microsoft Access."
            exit 1
        }
    }

    # Validate compatibility between volume editions of Office, Visio, and Project
    if ($OfficeSuites -match "Volume" -and ($Visio -match "Volume" -or $Project -match "Volume")) {
        Write-Host -Object "Verifying install combination is compatible."

        try {
            # Extract the year from the Office suite name
            [int]$OfficeEdition = [regex]::Match($OfficeSuites, '\d{4}').Value
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to extract the year from '$OfficeSuites'."
            exit 1
        }

        # Extract the year from the Visio product name if applicable
        if ($Visio -match "Volume") {
            try {
                [int]$VisioEdition = [regex]::Match($Visio, '\d{4}').Value
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to extract the year from '$Visio'."
                exit 1
            }
        }

        # Extract the year from the Project product name if applicable
        if ($Project -match "Volume") {
            try {
                [int]$ProjectEdition = [regex]::Match($Project, '\d{4}').Value
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to extract the year from '$Project'."
                exit 1
            }
        }

        # Check compatibility between Office and Visio editions
        if ($Visio -match "Volume" -and $OfficeEdition -lt $VisioEdition) {
            Write-Host -Object "[Error] '$OfficeSuites' and '$Visio' are incompatible."
            Write-Host -Object "[Error] You must either use a subscription version of Office or one that is the same age as or newer than $VisioEdition."
            exit 1
        }

        # Check compatibility between Office and Project editions
        if ($Project -match "Volume" -and $OfficeEdition -lt $ProjectEdition) {
            Write-Host -Object "[Error] '$OfficeSuites' and '$Project' are incompatible."
            Write-Host -Object "[Error] You must either use a subscription version of Office or one that is the same age as or newer than $ProjectEdition."
            exit 1
        }
    }

    # Initialize the XML configuration for Office installation
    [XML]$OfficeXML = @"
<Configuration ID="b9ae23b4-2822-441b-a8ea-3a39ba9f6c73">
    <Add OfficeClientEdition="64"></Add>
    <Property Name="SharedComputerLicensing" Value="0" />
    <Property Name="DeviceBasedLicensing" Value="0" />
    <Property Name="FORCEAPPSHUTDOWN" Value="FALSE" />
    <Property Name="SCLCacheOverride" Value="0" />
    <Property Name="AUTOACTIVATE" Value="1" />
    <Display Level="None" AcceptEULA="TRUE" />
    <Updates Enabled="TRUE" />
</Configuration>
"@

    # Map the UpdateChannel parameter to its corresponding value for the XML
    switch ($UpdateChannel) {
        "Current Channel" { $ChannelValue = "Current" }
        "Current Channel (Preview)" { $ChannelValue = "CurrentPreview" }
        "Monthly Enterprise Channel" { $ChannelValue = "MonthlyEnterprise" }
        "Semi-Annual Enterprise Channel" { $ChannelValue = "SemiAnnual" }
        "Semi-Annual Enterprise Channel (Preview)" { $ChannelValue = "SemiAnnualPreview" }
    }

    # Override the channel value for specific Office suites if applicable
    if ($OfficeSuites) {
        switch ($OfficeSuites) {
            "Office LTSC Professional Plus 2024 - Volume License" { $ChannelValue = "PerpetualVL2024" }
            "Office LTSC Standard 2024 - Volume License" { $ChannelValue = "PerpetualVL2024" }
            "Office LTSC Professional Plus 2021 - Volume License" { $ChannelValue = "PerpetualVL2021" }
            "Office LTSC Professional Plus 2021 (SPLA) - Volume License" { $ChannelValue = "PerpetualVL2021" }
            "Office LTSC Standard 2021 - Volume License" { $ChannelValue = "PerpetualVL2021" }
            "Office LTSC Standard 2021 (SPLA) - Volume License" { $ChannelValue = "PerpetualVL2021" }
            "Office Professional Plus 2019 - Volume License" { $ChannelValue = "PerpetualVL2019" }
            "Office Standard 2019 - Volume License" { $ChannelValue = "PerpetualVL2019" }
        }
    }

    # Update the XML configuration with the selected channel and migration settings
    try {
        $OfficeAddition = $OfficeXML.SelectSingleNode("//Add")
        $OfficeAddition.SetAttribute("Channel", $Null)
        $OfficeAddition.Channel = $ChannelValue

        $OfficeAddition.SetAttribute("MigrateArch", $Null)
        $OfficeAddition.MigrateArch = "TRUE"
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to add the update channel to the XML."
        exit 1
    }

    # Add the selected Office suite to the XML configuration
    if ($OfficeSuites) {
        # Set the volume key if applicable
        if ($VolumeKey -and $OfficeSuites -match "Volume") { $OfficeKey = $VolumeKey }

        # Map the Office suite parameter to its corresponding ProductID and default volume key
        switch ($OfficeSuites) {
            "Microsoft 365 Apps for enterprise" { $ProductID = "O365ProPlusRetail" }
            "Microsoft 365 Apps for enterprise (no Teams)" { $ProductID = "O365ProPlusEEANoTeamsRetail" }
            "Microsoft 365 Apps for business" { $ProductID = "O365BusinessRetail" }
            "Microsoft 365 Apps for business (no Teams)" { $ProductID = "O365BusinessEEANoTeamsRetail" }
            "Office LTSC Professional Plus 2024 - Volume License" {
                $ProductID = "ProPlus2024Volume"
                if (!$VolumeKey) { $OfficeKey = "XJ2XN-FW8RK-P4HMP-DKDBV-GCVGB" }
            }
            "Office LTSC Standard 2024 - Volume License" {
                $ProductID = "Standard2024Volume"
                if (!$VolumeKey) { $OfficeKey = "V28N4-JG22K-W66P8-VTMGK-H6HGR" }
            }
            "Office LTSC Professional Plus 2021 - Volume License" {
                $ProductID = "ProPlus2021Volume"
                if (!$VolumeKey) { $OfficeKey = "FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH" }
            }
            "Office LTSC Professional Plus 2021 (SPLA) - Volume License" {
                $ProductID = "ProPlusSPLA2021Volume"
                if (!$VolumeKey) {
                    Write-Host -Object "[Error] The SPLA edition requires a Volume Key to install."
                    exit 1
                }
            }
            "Office LTSC Standard 2021 - Volume License" {
                $ProductID = "Standard2021Volume"
                if (!$VolumeKey) { $OfficeKey = "KDX7X-BNVR8-TXXGX-4Q7Y8-78VT3" }
            }
            "Office LTSC Standard 2021 (SPLA) - Volume License" {
                $ProductID = "StandardSPLA2021Volume"
                if (!$VolumeKey) {
                    Write-Host -Object "[Error] The SPLA edition requires a Volume Key to install."
                    exit 1
                }
            }
            "Office Professional Plus 2019 - Volume License" {
                $ProductID = "ProPlus2019Volume"
                if (!$VolumeKey) { $OfficeKey = "NMMKJ-6RK4F-KMJVX-8D9MJ-6MWKP" }
            }
            "Office Standard 2019 - Volume License" {
                $ProductID = "Standard2019Volume"
                if (!$VolumeKey) { $OfficeKey = "6NWWJ-YQWMR-QKGCB-6TMB3-9D9HK" }
            }
        }

        # Add the Office suite configuration to the XML
        try {
            $OfficeProduct = $OfficeXML.CreateElement("Product")
            $OfficeProduct.SetAttribute("ID", $Null)
            $OfficeProduct.ID = $ProductID
            if ($OfficeKey) {
                $OfficeProduct.SetAttribute("PIDKEY", $Null)
                $OfficeProduct.PIDKEY = $OfficeKey
            }

            # Add language settings
            $MatchOSLanguage = $OfficeXML.CreateElement("Language")
            $MatchOSLanguage.SetAttribute("ID", $Null)
            $MatchOSLanguage.SetAttribute("Fallback", $Null)
            $MatchOSLanguage.ID = "MatchOS"
            $MatchOSLanguage.Fallback = "en-us"
            $OfficeProduct.AppendChild($MatchOSLanguage) | Out-Null

            $MatchInstalledLanguage = $OfficeXML.CreateElement("Language")
            $MatchInstalledLanguage.SetAttribute("ID", $Null)
            $MatchInstalledLanguage.ID = "MatchInstalled"
            $OfficeProduct.AppendChild($MatchInstalledLanguage) | Out-Null

            $MatchPreviousMSILanguage = $OfficeXML.CreateElement("Language")
            $MatchPreviousMSILanguage.SetAttribute("ID", $Null)
            $MatchPreviousMSILanguage.ID = "MatchPreviousMSI"
            $OfficeProduct.AppendChild($MatchPreviousMSILanguage) | Out-Null

            # Exclude specific apps from the installation
            $ExcludeGroove = $OfficeXML.CreateElement("ExcludeApp")
            $ExcludeGroove.SetAttribute("ID", $Null)
            $ExcludeGroove.ID = "Groove"
            $OfficeProduct.AppendChild($ExcludeGroove) | Out-Null

            $ExcludeLync = $OfficeXML.CreateElement("ExcludeApp")
            $ExcludeLync.SetAttribute("ID", $Null)
            $ExcludeLync.ID = "Lync"
            $OfficeProduct.AppendChild($ExcludeLync) | Out-Null

            $ExcludePublisher = $OfficeXML.CreateElement("ExcludeApp")
            $ExcludePublisher.SetAttribute("ID", $Null)
            $ExcludePublisher.ID = "Publisher"
            $OfficeProduct.AppendChild($ExcludePublisher) | Out-Null

            $OfficeAddition.AppendChild($OfficeProduct) | Out-Null
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to add the desired Office suite to the XML."
            exit 1
        }
    }

    # Add the selected Visio product to the XML configuration
    if ($Visio) {
        # Set the volume key if applicable
        if ($VolumeKey -and $Visio -match "Volume") { $VisioKey = $VolumeKey }

        # Map the Visio parameter to its corresponding ProductID and default volume key
        switch ($Visio) {
            "Visio Plan 2" { $VisioProductID = "VisioProRetail" }
            "Visio LTSC Professional 2024 - Volume License" {
                $VisioProductID = "VisioPro2024Volume"
                if (!$VolumeKey) { $VisioKey = "B7TN8-FJ8V3-7QYCP-HQPMV-YY89G" }
            }
            "Visio LTSC Standard 2024 - Volume License" {
                $VisioProductID = "VisioStd2024Volume"
                if (!$VolumeKey) { $VisioKey = "JMMVY-XFNQC-KK4HK-9H7R3-WQQTV" }
            }
            "Visio LTSC Professional 2021 - Volume License" {
                $VisioProductID = "VisioPro2021Volume"
                if (!$VolumeKey) { $VisioKey = "KNH8D-FGHT4-T8RK3-CTDYJ-K2HT4" }
            }
            "Visio LTSC Standard 2021 - Volume License" {
                $VisioProductID = "VisioStd2021Volume"
                if (!$VolumeKey) { $VisioKey = "MJVNY-BYWPY-CWV6J-2RKRT-4M8QG" }
            }
            "Visio Professional 2019 - Volume License" {
                $VisioProductID = "VisioPro2019Volume"
                if (!$VolumeKey) { $VisioKey = "9BGNQ-K37YR-RQHF2-38RQ3-7VCBB" }
            }
            "Visio Standard 2019 - Volume License" {
                $VisioProductID = "VisioStd2019Volume"
                if (!$VolumeKey) { $VisioKey = "7TQNQ-K3YQQ-3PFH7-CCPPM-X4VQ2" }
            }
            "Visio Professional 2016 - Volume License" {
                $VisioProductID = "VisioProXVolume"
                if (!$VolumeKey) { $VisioKey = "69WXN-MBYV6-22PQG-3WGHK-RM6XC" }
            }
            "Visio Standard 2016 - Volume License" {
                $VisioProductID = "VisioStdXVolume"
                if (!$VolumeKey) { $VisioKey = "NY48V-PPYYH-3F4PX-XJRKJ-W4423" }
            }
        }

        # Add the Visio product configuration to the XML
        try {
            $VisioProduct = $OfficeXML.CreateElement("Product")
            $VisioProduct.SetAttribute("ID", $Null)
            $VisioProduct.ID = $VisioProductID
            if ($VisioKey) {
                $VisioProduct.SetAttribute("PIDKEY", $Null)
                $VisioProduct.PIDKEY = $VisioKey
            }

            # Add language settings
            $MatchOSLanguage = $OfficeXML.CreateElement("Language")
            $MatchOSLanguage.SetAttribute("ID", $Null)
            $MatchOSLanguage.SetAttribute("Fallback", $Null)
            $MatchOSLanguage.ID = "MatchOS"
            $MatchOSLanguage.Fallback = "en-us"
            $VisioProduct.AppendChild($MatchOSLanguage) | Out-Null

            $MatchInstalledLanguage = $OfficeXML.CreateElement("Language")
            $MatchInstalledLanguage.SetAttribute("ID", $Null)
            $MatchInstalledLanguage.ID = "MatchInstalled"
            $VisioProduct.AppendChild($MatchInstalledLanguage) | Out-Null

            $MatchPreviousMSILanguage = $OfficeXML.CreateElement("Language")
            $MatchPreviousMSILanguage.SetAttribute("ID", $Null)
            $MatchPreviousMSILanguage.ID = "MatchPreviousMSI"
            $VisioProduct.AppendChild($MatchPreviousMSILanguage) | Out-Null

            # Exclude specific apps from the installation
            $ExcludeGroove = $OfficeXML.CreateElement("ExcludeApp")
            $ExcludeGroove.SetAttribute("ID", $Null)
            $ExcludeGroove.ID = "Groove"
            $VisioProduct.AppendChild($ExcludeGroove) | Out-Null

            $OfficeAddition.AppendChild($VisioProduct) | Out-Null
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to add the desired Visio product to the XML."
            exit 1
        }
    }

    # Check if the Project product is specified
    if ($Project) {
        # Set the volume key if applicable
        if ($VolumeKey -and $Project -match "Volume") { $ProjectKey = $VolumeKey }

        # Map the Project parameter to its corresponding ProductID and default volume key
        switch ($Project) {
            "Project Online Desktop Client" { $ProjectProductID = "ProjectProRetail" }
            "Project Professional 2024 - Volume License" {
                $ProjectProductID = "ProjectPro2024Volume"
                if (!$VolumeKey) { $ProjectKey = "FQQ23-N4YCY-73HQ3-FM9WC-76HF4" }
            }
            "Project Standard 2024 - Volume License" {
                $ProjectProductID = "ProjectStd2024Volume"
                if (!$VolumeKey) { $ProjectKey = "PD3TT-NTHQQ-VC7CY-MFXK3-G87F8" }
            }
            "Project Professional 2021 - Volume License" {
                $ProjectProductID = "ProjectPro2021Volume"
                if (!$VolumeKey) { $ProjectKey = "FTNWT-C6WBT-8HMGF-K9PRX-QV9H8" }
            }
            "Project Standard 2021 - Volume License" {
                $ProjectProductID = "ProjectStd2021Volume"
                if (!$VolumeKey) { $ProjectKey = "J2JDC-NJCYY-9RGQ4-YXWMH-T3D4T" }
            }
            "Project Professional 2019 - Volume License" {
                $ProjectProductID = "ProjectPro2019Volume"
                if (!$VolumeKey) { $ProjectKey = "B4NPR-3FKK7-T2MBV-FRQ4W-PKD2B" }
            }
            "Project Standard 2019 - Volume License" {
                $ProjectProductID = "ProjectStd2019Volume"
                if (!$VolumeKey) { $ProjectKey = "C4F7P-NCP8C-6CQPT-MQHV9-JXD2M" }
            }
            "Project Professional 2016 - Volume License" {
                $ProjectProductID = "ProjectProXVolume"
                if (!$VolumeKey) { $ProjectKey = "WGT24-HCNMF-FQ7XH-6M8K7-DRTW9" }
            }
            "Project Standard 2016 - Volume License" {
                $ProjectProductID = "ProjectStdXVolume"
                if (!$VolumeKey) { $ProjectKey = "D8NRQ-JTYM3-7J2DX-646CT-6836M" }
            }
        }

        # Add the Project product configuration to the XML
        try {
            $ProjectProduct = $OfficeXML.CreateElement("Product")
            $ProjectProduct.SetAttribute("ID", $Null)
            $ProjectProduct.ID = $ProjectProductID
            if ($ProjectKey) {
                $ProjectProduct.SetAttribute("PIDKEY", $Null)
                $ProjectProduct.PIDKEY = $ProjectKey
            }

            # Add language settings
            $MatchOSLanguage = $OfficeXML.CreateElement("Language")
            $MatchOSLanguage.SetAttribute("ID", $Null)
            $MatchOSLanguage.SetAttribute("Fallback", $Null)
            $MatchOSLanguage.ID = "MatchOS"
            $MatchOSLanguage.Fallback = "en-us"
            $ProjectProduct.AppendChild($MatchOSLanguage) | Out-Null

            $MatchInstalledLanguage = $OfficeXML.CreateElement("Language")
            $MatchInstalledLanguage.SetAttribute("ID", $Null)
            $MatchInstalledLanguage.ID = "MatchInstalled"
            $ProjectProduct.AppendChild($MatchInstalledLanguage) | Out-Null

            $MatchPreviousMSILanguage = $OfficeXML.CreateElement("Language")
            $MatchPreviousMSILanguage.SetAttribute("ID", $Null)
            $MatchPreviousMSILanguage.ID = "MatchPreviousMSI"
            $ProjectProduct.AppendChild($MatchPreviousMSILanguage) | Out-Null

            # Exclude specific apps from the installation
            $ExcludeGroove = $OfficeXML.CreateElement("ExcludeApp")
            $ExcludeGroove.SetAttribute("ID", $Null)
            $ExcludeGroove.ID = "Groove"
            $ProjectProduct.AppendChild($ExcludeGroove) | Out-Null

            $OfficeAddition.AppendChild($ProjectProduct) | Out-Null
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to add the desired project product to the XML."
            exit 1
        }
    }

    # Check if Microsoft Access Runtime 365 is specified
    if ($MicrosoftAccessRuntime365) {
        try {
            $AdditionalProductXML = $OfficeXML.CreateElement("Product")
            $AdditionalProductXML.SetAttribute("ID", $Null)
            $AdditionalProductXML.ID = "AccessRuntimeRetail"

            # Add language settings
            $MatchOSLanguage = $OfficeXML.CreateElement("Language")
            $MatchOSLanguage.SetAttribute("ID", $Null)
            $MatchOSLanguage.SetAttribute("Fallback", $Null)
            $MatchOSLanguage.ID = "MatchOS"
            $MatchOSLanguage.Fallback = "en-us"
            $AdditionalProductXML.AppendChild($MatchOSLanguage) | Out-Null

            $MatchInstalledLanguage = $OfficeXML.CreateElement("Language")
            $MatchInstalledLanguage.SetAttribute("ID", $Null)
            $MatchInstalledLanguage.ID = "MatchInstalled"
            $AdditionalProductXML.AppendChild($MatchInstalledLanguage) | Out-Null

            $MatchPreviousMSILanguage = $OfficeXML.CreateElement("Language")
            $MatchPreviousMSILanguage.SetAttribute("ID", $Null)
            $MatchPreviousMSILanguage.ID = "MatchPreviousMSI"
            $AdditionalProductXML.AppendChild($MatchPreviousMSILanguage) | Out-Null

            $OfficeAddition.AppendChild($AdditionalProductXML) | Out-Null
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to add the Access Runtime to the XML."
            exit 1
        }
    }

    # Configure product activation settings based on the selected option
    switch ($ProductActivation) {
        "Shared Computer" {
            $SharedComputerLicensing = $OfficeXML.Configuration.Property | Where-Object { $_.Name -eq 'SharedComputerLicensing' }
            $SharedComputerLicensing.Value = "1"
        }
        "Device based" {
            $DeviceBasedLicensing = $OfficeXML.Configuration.Property | Where-Object { $_.Name -eq 'DeviceBasedLicensing' }
            $DeviceBasedLicensing.Value = "1"
        }
    }

    # Add the RemoveMSI property to the XML if specified
    if ($UninstallAnyMSIVersions) {
        try {
            Write-Host -Object "Uninstall MSI is selected. If any MSI version is installed, it may be removed."
            $RemoveMSI = $OfficeXML.CreateElement("RemoveMSI")
            $OfficeXML.Configuration.AppendChild($RemoveMSI) | Out-Null
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to add the RemoveMSI property."
            exit 1
        }
    }

    # Save the deployment XML to the specified path
    Write-Host -Object "Attempting to save the deployment XML at '$OfficeInstallDownloadPath\Office365Install\OfficeInstall.xml'."
    try {
        $OfficeXML.Save("$OfficeInstallDownloadPath\Office365Install\OfficeInstall.xml")

        Write-Host -Object "### Deployment XML ###"
        Get-Content -Path "$OfficeInstallDownloadPath\Office365Install\OfficeInstall.xml" -ErrorAction Stop | Write-Host
        Write-Host -Object ""
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to save the Office XML."
        exit 1
    }

    # Retrieve the Office Deployment Tool (ODT) download URL
    Write-Host -Object "Retrieving the Office Deployment Tool (ODT)."
    try {
        $OfficeDeploymentToolURL = Get-ODTURL -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve the Office Deployment Tool download URL."
        exit 1
    }

    # Download the Office Deployment Tool
    Write-Host -Object "Downloading the Office Deployment Tool."
    try {
        $ODTSetupFilePath = Invoke-Download -URL $OfficeDeploymentToolURL -Path "$OfficeInstallDownloadPath\Office365Install\ODTSetup.exe" -Overwrite -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to download the Office Deployment Tool."
        exit 1
    }

    # Extract the Office Deployment Tool from the setup package
    Write-Host -Object "Extracting the Office Deployment Tool from the setup package."
    try {
        $ExtractArguments = @(
            "/extract:`"$OfficeInstallDownloadPath\Office365Install`""
            "/norestart"
            "/quiet"
        )

        $ExtractProcess = Start-Process -FilePath $ODTSetupFilePath -ArgumentList $ExtractArguments -WorkingDirectory "$OfficeInstallDownloadPath\Office365Install" -NoNewWindow -PassThru -ErrorAction Stop
        $ExtractStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $ExtractTimeout = 300

        while (!$ExtractProcess.HasExited -and $ExtractStopwatch.Elapsed.TotalSeconds -lt $ExtractTimeout) {
            Start-Sleep -Milliseconds 100
        }

        if($ExtractStopwatch.Elapsed.TotalSeconds -ge $ExtractTimeout){
            $ExtractTimeoutInMinutes = [Math]::Round(($ExtractTimeout / 60), 0)
            Write-Host -Object "[Warning] $ExtractTimeoutInMinutes minute timeout has been reached."
        }

        if (!(Test-Path -Path "$OfficeInstallDownloadPath\Office365Install\setup.exe" -PathType Leaf -ErrorAction SilentlyContinue)) {
            throw(New-Object System.IO.FileNotFoundException("Unable to find '$OfficeInstallDownloadPath\Office365Install\setup.exe'."))
        }

        $ODTFilePath = "$OfficeInstallDownloadPath\Office365Install\setup.exe"
        $ExtractStopwatch.Reset()
    } catch {
        if ($ExtractStopwatch) { $Stopwatch.Reset() }

        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to extract the Office Deployment Tool."
        exit 1
    }

    # Download and install the desired Office products using the Office Deployment Tool
    try {
        Write-Host -Object "Downloading your desired office product(s)."
        $DownloadToolArguments = @(
            "/download"
            "`"$OfficeInstallDownloadPath\Office365Install\OfficeInstall.xml`""
        )

        $DownloadProcess = Start-Process -FilePath $ODTFilePath -ArgumentList $DownloadToolArguments -WorkingDirectory "$OfficeInstallDownloadPath\Office365Install" -NoNewWindow -PassThru -ErrorAction Stop
        $DownloadStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $DownloadTimeout = 5400

        while (!$DownloadProcess.HasExited -and $DownloadStopwatch.Elapsed.TotalSeconds -lt $DownloadTimeout) {
            Start-Sleep -Milliseconds 100
        }

        if($DownloadStopwatch.Elapsed.TotalSeconds -ge $DownloadTimeout){
            $DownloadTimeoutInMinutes = [Math]::Round(($DownloadTimeout / 60), 0)
            Write-Host -Object "[Warning] $DownloadTimeoutInMinutes minute timeout has been reached."
        }

        $DownloadStopwatch.Reset()

        Write-Host -Object "Installing your desired office product(s)."
        $DeploymentToolArguments = @(
            "/configure"
            "`"$OfficeInstallDownloadPath\Office365Install\OfficeInstall.xml`""
        )

        $InstallProcess = Start-Process -FilePath $ODTFilePath -ArgumentList $DeploymentToolArguments -WorkingDirectory "$OfficeInstallDownloadPath\Office365Install" -NoNewWindow -PassThru -ErrorAction Stop
        $InstallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $InstallTimeout = 1800

        while (!$InstallProcess.HasExited -and $InstallStopwatch.Elapsed.TotalSeconds -lt $InstallTimeout) {
            Start-Sleep -Milliseconds 100
        }

        if($InstallStopwatch.Elapsed.TotalSeconds -ge $InstallTimeout){
            $InstallTimeoutInMinutes = [Math]::Round(($InstallTimeout / 60), 0)
            Write-Host -Object "[Warning] $InstallTimeoutInMinutes minute timeout has been reached. Killing the process."

            $InstallProcess | Stop-Process -Force -ErrorAction SilentlyContinue
        }

        $InstallStopwatch.Reset()

        Write-Host -Object "Install completed.`n"
    } catch {
        if($DownloadStopwatch){ $DownloadStopwatch.Reset() }
        if($InstallStopwatch){ $InstallStopwatch.Reset() }

        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to install your desired office product."
        exit 1
    }

    # Verify that each product in the installation list was successfully installed.
    $ProductsToSearchFor | ForEach-Object {
        Write-Host -Object "Verifying that '$_' was successfully installed."
        try {
            # Check the registry for the installed product using its display name.
            $InstalledProduct = Find-InstallKey -DisplayName $_ -ErrorAction Stop
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to check if the product is already installed."
            exit 1
        }

        # If the product is not found in the registry, log an error and set the exit code.
        if (!$InstalledProduct) {
            Write-Host -Object "[Error] Unable to find '$_'. You may want to manually verify that it was installed."
            $ExitCode = 1
        } else {
            Write-Host -Object "Success!"
        }
    }

    # Wait for 120 seconds before attempting to clean up the installation folder.
    try {
        Start-Sleep -Seconds 120
        # Remove the Office installation directory and its contents.
        Remove-Item -Path "$OfficeInstallDownloadPath\Office365Install" -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to remove the folder '$OfficeInstallDownloadPath\Office365Install'."
        $ExitCode = 1
    }

    # If the ForceRestart switch is enabled and there were no errors, schedule a system restart.
    if ($ForceRestart -and $ExitCode -eq 0) {
        try {
            # Calculate the restart time (60 seconds from now).
            $RestartTime = (Get-Date).AddSeconds(60)
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to add 60 seconds to the current date and time."
            $ExitCode = 1
        }

        Write-Host -Object "Scheduling restart for $($RestartTime.ToShortDateString()) $($RestartTime.ToShortTimeString())."

        try {
            # Use the shutdown.exe tool to schedule the restart.
            $RestartArguments = @(
                "/r"
                "/t 60"
            )
            Start-Process -FilePath "$env:WINDIR\System32\shutdown.exe" -ArgumentList $RestartArguments -NoNewWindow -Wait -ErrorAction Stop
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to schedule the restart."
            exit 1
        }
    }

    exit $ExitCode
}
end {
    
    
    
}