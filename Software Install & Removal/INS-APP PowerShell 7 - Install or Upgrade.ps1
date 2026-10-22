#Requires -Version 5.1

<#
.SYNOPSIS
    Installs or upgrades the latest version of PowerShell 7 / PowerShell Core.
.DESCRIPTION
    Installs or upgrades the latest version of PowerShell 7 / PowerShell Core.

.EXAMPLE
    (No Parameters)

    Requesting the latest release information for PowerShell 7 from 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest'.
    Waiting for 11 seconds before proceeding.
    Request Attempt: 1

    Parsing the response.
    Verifying that PowerShell 7.5.2 is not installed.
    Retrieving the download URL for the MSI.
    Downloading the installer.
    URL 'https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/PowerShell-7.5.2-win-x64.msi' was given.
    Downloading the file...
    Waiting for 11 seconds.
    Download Attempt 1

    Attempting to verify the installer.
    Installer verified.

    Starting installation.

    Verifying that PowerShell 7.5.2 was successfully installed.
    PowerShell 7.5.2 was successfully installed.

.PARAMETER UpgradeIfFound
    If an existing installation of PowerShell is found and it's not the latest release, update it.

.PARAMETER AddToPath
    Adds PowerShell to the Windows PATH environment variable.

.PARAMETER AddToExplorer
    Adds the 'Open PowerShell'/'Open in Terminal' item and the 'Run with PowerShell' item to the context menu in Windows Explorer.

.PARAMETER DisableTelemetry
    Disables PowerShell's telemetry by setting the POWERSHELL_TELEMETRY_OPTOUT environment variable.

.PARAMETER RegisterToEventLog
    Registers PowerShell with the Windows Event Logging manifest.

.PARAMETER EnableAndUseMicrosoftUpdate
    When enabled, this feature ensures you receive the latest PowerShell 7 updates through your traditional Microsoft Update (MU) management flow,
    whether that's with Windows Update for Business, WSUS, Microsoft Endpoint Configuration Manager, or the interactive MU dialog in Settings.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$GitHubReleaseURL = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest",
    [Parameter()]
    [Switch]$UpgradeIfFound = [System.Convert]::ToBoolean($env:upgradeIfFound),
    [Parameter()]
    [Switch]$AddToPath = [System.Convert]::ToBoolean($env:addPowershellToTheWindowsPath),
    [Parameter()]
    [Switch]$AddToExplorer = [System.Convert]::ToBoolean($env:addToFileAndExplorerContextMenu),
    [Parameter()]
    [Switch]$DisableTelemetry = [System.Convert]::ToBoolean($env:disableTelemetry),
    [Parameter()]
    [Switch]$RegisterToEventLog = [System.Convert]::ToBoolean($env:registerPowershellToEventViewer),
    [Parameter()]
    [Switch]$EnableAndUseMicrosoftUpdate = [System.Convert]::ToBoolean($env:enableAndUseMicrosoftUpdate)
)

begin {
    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    #region TLS Settings

    # Determine the supported TLS versions and set the appropriate security protocol
    # Prefer Tls13 and Tls12 if both are available, otherwise just Tls12, or warn if unsupported.
    $SupportedTLSversions = [enum]::GetValues('Net.SecurityProtocolType')
    if ( ($SupportedTLSversions -contains 'Tls13') -and ($SupportedTLSversions -contains 'Tls12') ) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol::Tls13 -bor [System.Net.SecurityProtocolType]::Tls12
    } elseif ( $SupportedTLSversions -contains 'Tls12' ) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    } else {
        # Warn the user if TLS 1.2 and 1.3 are not supported, which may cause the download to fail
        Write-Host -Object "[Warning] TLS 1.2 and/or TLS 1.3 are not supported on this system. This could lead to errors or unexpected results."
        if ($PSVersionTable.PSVersion.Major -lt 3) {
            Write-Host -Object "[Warning] PowerShell 2 / .NET 2.0 doesn't support TLS 1.2."
        }
    }

    #region Helper Functions

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
            [String]$UserAgent
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
    #region Verify Environment

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

    #region Retrieve Release Info

    # Temporarily disable progress reporting to speed up script performance
    $PreviousProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    # Request the latest release information for PowerShell 7 from the GitHub API
    Write-Host -Object "Requesting the latest release information for PowerShell 7 from '$GitHubReleaseURL'."
    $RequestAttempt = 1
    while ($RequestAttempt -le 5) {
        try {
            # Wait for a random time before proceeding to avoid rate-limiting issues
            $SleepTime = Get-Random -Minimum 3 -Maximum 15
            Write-Host -Object "Waiting for $SleepTime seconds before proceeding."
            Start-Sleep -Seconds $SleepTime

            # Provide a visual break between attempts
            if ($RequestAttempt -ne 1) { Write-Host "" }
            Write-Host -Object "Request Attempt: $RequestAttempt"

            # Make the request to GitHub API
            $GitHubResponse = Invoke-WebRequest -Uri $GitHubReleaseURL -Method "GET" -MaximumRedirection 10 -UseBasicParsing -ErrorAction Stop

            # If the response status code is 200, exit the loop
            if ($GitHubResponse.StatusCode -eq 200) {
                $RequestAttempt = 5
            } else {
                Write-Host -Object "[Warning] Status code '$($GitHubResponse.StatusCode)' does not indicate success."
            }
        } catch {
            # Handle any errors that occur during the request attempt
            Write-Host -Object "[Warning] An error occurred while making the request."
            Write-Host -Object "[Warning] $($_.Exception.Message)"
        }

        $RequestAttempt++
    }

    # Restore the original progress preference setting
    $ProgressPreference = $PreviousProgressPreference

    # Parse the response from GitHub to extract the release information
    Write-Host -Object "`nParsing the response."
    try {
        $ErrorActionPreference = "Stop"
        $GitHubResponse = $GitHubResponse | ConvertFrom-Json
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to parse the response from GitHub. Unable to determine the latest release."

        $ErrorActionPreference = "Continue"
    }
    $ErrorActionPreference = "Continue"

    # Extract the latest release version from the response
    $LatestRelease = ($GitHubResponse | Select-Object -ExpandProperty "tag_name") -replace "v"
    if (!$LatestRelease) {
        Write-Host -Object "[Error] Failed to get the latest release from the GitHub response."
        Write-Host -Object "### GitHub Response ###"
        ($GitHubResponse | Format-List | Out-String).Trim() | Write-Host
        exit 1
    }

    #region Verify If Installed

    # Check if the latest version of PowerShell is already installed
    try {
        Write-Host -Object "Verifying that PowerShell $($LatestRelease) is not installed."
        $PowerShellInstallKey = Find-InstallKey -DisplayName "PowerShell 7" -ErrorAction Stop
        $PowerShellInstallKey = $PowerShellInstallKey | Where-Object { $_.DisplayName -notmatch 'preview' }
        $NumberOfInstalled = ($PowerShellInstallKey | Measure-Object).Count
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to verify that PowerShell $($LatestRelease) is not installed."
        exit 1
    }

    # Attempt to check if PowerShell 7 is installed via the Microsoft Store for any user
    try {
        $WindowsStoreInstalls = Get-AppxPackage -Name "Microsoft.PowerShell" -AllUsers -ErrorAction Stop
    } catch {
        # If an error occurs, log a warning message and continue
        Write-Host -Object "[Warning] $($_.Exception.Message)"
        Write-Host -Object "[Warning] Unable to check if PowerShell 7 is installed via the Microsoft Store."
    }

    # If PowerShell installations via the Microsoft Store are found
    if ($WindowsStoreInstalls) {
        Write-Host -Object "[Warning] One or more users have PowerShell 7 installed via the Microsoft Store."
        Write-Host -Object "[Warning] This script does not support Microsoft Store installations because it is not a 'machine-wide' installation."
        Write-Host -Object "[Warning] The latest version of PowerShell 7 will be installed alongside the Microsoft Store version."
    }

    if ($NumberOfInstalled -gt 1) {
        Write-Host -Object "[Error] Multiple versions of PowerShell 7 are installed. Please manually uninstall the duplicate PowerShell versions before proceeding."
        exit 1
    }

    try {
        # If PowerShell is already installed and the upgrade option is not selected, exit with an alert
        if ($PowerShellInstallKey -and !$UpgradeIfFound) {
            Write-Host -Object "[Alert] PowerShell $($PowerShellInstallKey.DisplayVersion) is already installed."
            if ([version]$PowerShellInstallKey.DisplayVersion -lt [version]$LatestRelease) {
                Write-Host -Object "[Warning] An older version of PowerShell was detected. Please use the 'Upgrade if Found' option to update it to the latest release."
            }

            exit $ExitCode
        }

        # If an older version is installed and the upgrade option is selected, proceed with the upgrade
        if ($PowerShellInstallKey -and $UpgradeIfFound -and [version]$PowerShellInstallKey.DisplayVersion -lt [version]$LatestRelease) {
            Write-Host -Object "[Warning] An older PowerShell version was detected ($($PowerShellInstallKey.DisplayVersion)). It will be upgraded to $LatestRelease."
        } elseif ($PowerShellInstallKey -and $UpgradeIfFound -and [version]$PowerShellInstallKey.DisplayVersion -ge [version]$LatestRelease) {
            # If the installed version is greater than or equal to the latest release, exit with an alert
            Write-Host -Object "[Alert] PowerShell $($PowerShellInstallKey.DisplayVersion) is installed and it is greater than or equal to PowerShell $LatestRelease."
            exit $ExitCode
        }
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to verify that PowerShell $($LatestRelease) is not installed."
        exit 1
    }

    #region Retrieve URL

    # Retrieve the download URL for the appropriate MSI installer based on the system architecture
    try {
        Write-Host -Object "Retrieving the download URL for the MSI."

        # Determine the installer regex based on the system architecture
        switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
            'X86' { $InstallerRegex = 'x86\.msi$' }
            'X64' { $InstallerRegex = 'x64\.msi$' }
            'Arm' { $InstallerRegex = 'arm32\.msi$' }
            'Arm64' { $InstallerRegex = 'arm64\.msi$' }
            default {
                throw (New-Object System.Exception("Unable to determine the appropriate installer for your platform '$([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)'."))
            }
        }

        # Find the MSI installer in the GitHub response assets
        $MSI = $GitHubResponse.Assets | Where-Object { $_.Name -match $InstallerRegex }

        # If no installer is found, throw an error
        if (!$MSI) {
            throw (New-Object System.NullReferenceException("No installer found that matched the regex '$InstallerRegex'."))
        }
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to find the MSI for PowerShell $($LatestRelease)."
        exit 1
    }

    #region Verify Existing MSI

    # Flag to determine if the installer needs to be downloaded
    $NeedToDownloadInstaller = $True

    # Check if an installer already exists in the TEMP directory
    if (Test-Path -Path "$env:TEMP\$($MSI.name)" -ErrorAction SilentlyContinue) {
        Write-Host -Object "`nAn installer already exists at '$env:TEMP\$($MSI.name)'. Attempting to verify the installer."

        # Extract the hash algorithm and hash value from the MSI digest
        $Digest = $MSI.digest -split ":"
        $Algorithm = $Digest[0]
        $Hash = $Digest[1]

        try {
            # Verify the file hash of the existing installer
            $HashMatch = (Get-FileHash -Path "$env:TEMP\$($MSI.name)" -Algorithm $Algorithm -ErrorAction Stop).Hash -eq $Hash
        } catch {
            Write-Host -Object "[Warning] $($_.Exception.Message)"
            Write-Host -Object "[Warning] Failed to verify the file integrity of '$env:TEMP\$($MSI.name)'."
            Remove-Item -Path "$env:TEMP\$($MSI.name)" -Confirm:$False -Force -ErrorAction SilentlyContinue
        }

        if ($HashMatch) {
            try {
                # Verify the file signature of the existing installer
                $FileSignature = Get-AuthenticodeSignature -FilePath "$env:TEMP\$($MSI.name)" -ErrorAction Stop
                $ValidSignature = $FileSignature.Status -eq "Valid" -and $FileSignature.SignerCertificate.Subject -eq "CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US"
            } catch {
                Write-Host -Object "[Warning] $($_.Exception.Message)"
                Write-Host -Object "[Warning] Failed to verify the file signature of '$env:TEMP\$($MSI.name)'."
                Remove-Item -Path "$env:TEMP\$($MSI.name)" -Confirm:$False -Force -ErrorAction SilentlyContinue
            }
        }

        if ($HashMatch -and $ValidSignature) {
            # If the hash and signature are valid, use the existing installer
            $NeedToDownloadInstaller = $False
            $MSIInstaller = "$env:TEMP\$($MSI.name)"
            Write-Host -Object "Installer verified."
        } else {
            try {
                # If verification fails, remove the existing installer
                Write-Host -Object "The installer did not pass the verification check. Removing the file to re-download."
                if (Test-Path -Path "$env:TEMP\$($MSI.name)" -ErrorAction SilentlyContinue) {
                    Remove-Item -Path "$env:TEMP\$($MSI.name)" -Confirm:$False -Force -ErrorAction Stop
                }
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to remove the installer file at '$env:TEMP\$($MSI.name)'. Unable to continue."
                exit 1
            }
        }
    }

    #region Download MSI

    # Download the installer if it doesn't exist or failed verification
    if ($NeedToDownloadInstaller) {
        Write-Host -Object "Downloading the installer."

        try {
            # Use the Invoke-Download function to download the installer
            $MSIInstaller = Invoke-Download -URL $MSI.browser_download_url -Path "$env:TEMP\$($MSI.name)" -Overwrite -ErrorAction Stop
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to download the installer file. Unable to continue."
            exit 1
        }
    }

    # Verify that the installer was successfully downloaded
    if (!(Test-Path -Path $MSIInstaller -ErrorAction SilentlyContinue)) {
        Write-Host -Object "[Error] Failed to download the installer to '$env:TEMP\$($MSI.name)'."
        exit 1
    }

    #region Verify Installer

    # Verify the downloaded installer if it was newly downloaded
    if ($NeedToDownloadInstaller) {
        Write-Host -Object "`nAttempting to verify the installer."

        # Extract the hash algorithm and hash value from the MSI digest
        $Digest = $MSI.digest -split ":"
        $Algorithm = $Digest[0]
        $Hash = $Digest[1]

        try {
            # Verify the file hash of the downloaded installer
            $HashMatch = (Get-FileHash -Path $MSIInstaller -Algorithm $Algorithm -ErrorAction Stop).Hash -eq $Hash
        } catch {
            Write-Host -Object "[Warning] $($_.Exception.Message)"
            Write-Host -Object "[Warning] Failed to verify the file integrity of '$MSIInstaller'."
            Remove-Item -Path "$MSIInstaller" -Confirm:$False -Force -ErrorAction SilentlyContinue
        }

        if ($HashMatch) {
            try {
                # Verify the file signature of the downloaded installer
                $FileSignature = Get-AuthenticodeSignature -FilePath "$MSIInstaller" -ErrorAction Stop
                $ValidSignature = $FileSignature.Status -eq "Valid" -and $FileSignature.SignerCertificate.Subject -eq "CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US"
            } catch {
                Write-Host -Object "[Warning] $($_.Exception.Message)"
                Write-Host -Object "[Warning] Failed to verify the file signature of '$MSIInstaller'."
                Remove-Item -Path "$MSIInstaller" -Confirm:$False -Force -ErrorAction SilentlyContinue
            }
        }

        if (!$HashMatch -or !$ValidSignature) {
            try {
                # If verification fails, remove the downloaded installer
                Write-Host -Object "[Error] The installer did not pass the verification check. Unable to continue."
                if (Test-Path -Path "$MSIInstaller" -ErrorAction SilentlyContinue) {
                    Remove-Item -Path "$MSIInstaller" -Confirm:$False -Force -ErrorAction Stop
                }
                exit 1
            } catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                Write-Host -Object "[Error] Failed to remove the installer file at '$MSIInstaller'. Unable to continue."
                exit 1
            }
        }

        Write-Host -Object "Installer verified."
    }

    #region Run Installer

    # Inform the user that the installation process is starting
    Write-Host -Object "`nStarting installation."

    # Prepare the MSI installation arguments
    $MSIArguments = New-Object System.Collections.Generic.List[string]
    $MSIArguments.Add("/package") # Specify the package to install
    $MSIArguments.Add("`"$MSIInstaller`"") # Add the path to the MSI installer
    $MSIArguments.Add("/quiet") # Run the installer in quiet mode
    $MSIArguments.Add("/norestart") # Prevent automatic restarts after installation

    # Set the values for the MSI properties based on the script parameters
    if ($AddToPath) { $PathValue = 1 }else { $PathValue = 0 }
    if ($AddToExplorer) { $ExplorerValue = 1 }else { $ExplorerValue = 0 }
    if ($DisableTelemetry) { $TelemetryValue = 1 }else { $TelemetryValue = 0 }
    if ($RegisterToEventLog) { $EventLogValue = 1 }else { $EventLogValue = 0 }
    if ($EnableAndUseMicrosoftUpdate) { $MicrosoftUpdateValue = 1 }else { $MicrosoftUpdateValue = 0 }

    # Add the MSI properties to the arguments list
    $MSIArguments.Add("ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=$ExplorerValue")
    $MSIArguments.Add("ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=$ExplorerValue")
    $MSIArguments.Add("REGISTER_MANIFEST=$EventLogValue")
    $MSIArguments.Add("USE_MU=$MicrosoftUpdateValue")
    $MSIArguments.Add("ENABLE_MU=$MicrosoftUpdateValue")
    $MSIArguments.Add("ADD_PATH=$PathValue")
    $MSIArguments.Add("DISABLE_TELEMETRY=$TelemetryValue")

    # Start the MSI installation process
    $InstallationProcess = Start-Process -FilePath "$env:SYSTEMROOT\System32\msiexec.exe" -ArgumentList $MSIArguments -NoNewWindow -PassThru

    # Wait for the installation process to complete, with a timeout of 30 minutes
    if (!$InstallationProcess.WaitForExit(1800000)) {
        Write-Host -Object "[Warning] The installation exceeded 30 minutes and timed out. Terminating the process."
        $InstallationProcess | Stop-Process -Force -Confirm:$False
    }

    # Check the exit code of the installation process to determine success
    if ([int]$InstallationProcess.ExitCode -ne 0) {
        Write-Host -Object "[Warning] Exit Code '$($InstallationProcess.ExitCode)' does not indicate success."
    }

    # Clean up the installer file if it exists
    if (Test-Path -Path $MSIInstaller -ErrorAction SilentlyContinue) {
        try {
            Remove-Item -Path $MSIInstaller -Force -Confirm:$False -ErrorAction Stop
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Unable to clean up the installer at '$MSIInstaller'."
            $ExitCode = 1
        }
    }

    #region Verify If Installed

    # Verify that the latest version of PowerShell was successfully installed
    try {
        Write-Host -Object "`nVerifying that PowerShell $LatestRelease was successfully installed."
        $PowerShellInstallKey = Find-InstallKey -DisplayName "PowerShell 7" -ErrorAction Stop
        $PowerShellInstallKey = $PowerShellInstallKey | Where-Object { $_.DisplayName -notmatch 'preview' }
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to verify that PowerShell $LatestRelease is installed."
        exit 1
    }

    # Check the installed version against the expected version
    try {
        if ($PowerShellInstallKey -and [version]$PowerShellInstallKey.DisplayVersion -ge [version]$LatestRelease) {
            Write-Host -Object "PowerShell $LatestRelease was successfully installed."
        } else {
            Write-Host -Object "[Error] PowerShell $LatestRelease installation failed."
            exit 1
        }
    } catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to verify that PowerShell $LatestRelease was installed."
        exit 1
    }

    # Exit the script with the appropriate exit code
    exit $ExitCode
}
end {
    
    
    
}