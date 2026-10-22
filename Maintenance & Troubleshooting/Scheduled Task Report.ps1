#Requires -Version 4.0

<#
.SYNOPSIS
    Retrieves a list of scheduled tasks and outputs the list into the activity feed. The results can also be saved to a custom field.
.DESCRIPTION
    Retrieves a list of scheduled tasks and outputs the list into the activity feed. The results can also be saved to a custom field.

.PARAMETER TaskName
    Specify the name or part of the name of the scheduled task(s) to filter by. This can be a comma-separated list of names. If not provided, all tasks will be included.
.PARAMETER IncludeMicrosoft
    Include scheduled tasks created by Microsoft in the report.
.PARAMETER IncludeDisabled
    Include scheduled tasks that are currently disabled in the report.
.PARAMETER MultilineCustomFieldName
    Specify the name of a multiline custom field to save the results to. This is optional; results will also be output to the activity feed.
.PARAMETER WYSIWYGCustomFieldName
    Specify the name of a WYSIWYG custom field to save the results to. This is optional; results will also be output to the activity feed.

.EXAMPLE
    (No Parameters)

    [Info] 9 scheduled task(s) found that match the criteria.

    TaskName    : CreateExplorerShellUnelevatedTask
    TaskPath    : \
    Author      : ExplorerShellUnelevated
    State       : Ready
    Description :

    TaskName    : MicrosoftEdgeUpdateTaskMachineCore
    TaskPath    : \
    Author      :
    State       : Ready
    Description : Keeps your Microsoft software up to date. If this task is disabled or stopp(...)

    (...)

.EXAMPLE
    -TaskName "firefox"

    [Info] 2 scheduled task(s) found that match the criteria.

    TaskName    : Firefox Background Update S-1-5-21-21640437-1735840450-3283185940-1104 E7CF176E110C211B
    TaskPath    : \Mozilla\
    Author      : Mozilla
    State       : Ready
    Description : The Background Update task checks for updates to Firefox when Firefox is no(...)

    TaskName    : Firefox Default Browser Agent E7CF176E110C211B
    TaskPath    : \Mozilla\
    Author      : Mozilla
    State       : Ready
    Description : The Default Browser Agent task checks when the default changes from Firefox(...)

.EXAMPLE
    -TaskName "License" -IncludeMicrosoft -IncludeDisabled -MultilineCustomFieldName "Scheduled Tasks Report" -WYSIWYGCustomFieldName "Scheduled Tasks Report WYSIWYG"

    [Info] 6 scheduled task(s) found that match the criteria.

    [Info] Publishing a list of scheduled tasks to the Multiline custom field 'Scheduled Tasks Report'.
    [Info] Successfully set 'Scheduled Tasks Report' custom field!

    [Info] Publishing a table of scheduled tasks to the WYSIWYG custom field 'Scheduled Tasks Report WYSIWYG'.
    [Info] Successfully set 'Scheduled Tasks Report WYSIWYG' custom field!

    TaskName    : EnableLicenseAcquisition
    TaskPath    : \Microsoft\Windows\Subscription\
    Author      : Microsoft Corporation
    State       : Ready
    Description : Enable subscription license acquisition

    TaskName    : StartOobeAppsScan_LicenseAccepted
    TaskPath    : \Microsoft\Windows\UpdateOrchestrator\
    Author      : Microsoft Corporation
    State       : Ready
    Description : This task performs a scheduled Windows Update scan.

    TaskName    : TempSignedLicenseExchange
    TaskPath    : \Microsoft\Windows\License Manager\
    Author      : Microsoft Corporation
    State       : Ready
    Description : Exchanges temporary preinstalled licenses for Windows Store licenses.

    TaskName    : License Validation
    TaskPath    : \Microsoft\Windows\Clip\
    Author      : Microsoft Corporation
    State       : Disabled
    Description : Windows Store legacy license migration task

    TaskName    : LicenseAcquisition
    TaskPath    : \Microsoft\Windows\Subscription\
    Author      : Microsoft Corporation
    State       : Disabled
    Description : Subscription license acquisition

    TaskName    : LicenseImdsIntegration
    TaskPath    : \Microsoft\Windows\Clip\
    Author      : $(@%SystemRoot%\system32\fclip.exe,-100)
    State       : Disabled
    Description : FClip

    (...)

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2012 R2
    Version: 2.0
    Release Notes: Added TaskName parameter. Added support for WYSIWYG custom fields. Updated output formatting.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string[]]$TaskName,
    [Parameter()]
    [Switch]$IncludeMicrosoft = [System.Convert]::ToBoolean($env:includeMicrosoftTasks),
    [Parameter()]
    [Switch]$IncludeDisabled = [System.Convert]::ToBoolean($env:includeDisabledTasks),
    [Parameter()]
    [String]$MultilineCustomFieldName,
    [Parameter()]
    [String]$WYSIWYGCustomFieldName
)

begin {
    # Import script variables
    if ($env:TaskName) { $TaskName = $env:TaskName }
    if ($env:MultilineCustomFieldName) { $MultilineCustomFieldName = $env:MultilineCustomFieldName }
    if ($env:WYSIWYGCustomFieldName) { $WYSIWYGCustomFieldName = $env:WYSIWYGCustomFieldName }

    # Check if the operating system build version is less than 9600 (Windows 10 or Windows Server 2012 R2 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 9600) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2012 R2 (9600)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Error if the TaskName parameter is provided but is empty or whitespace
    if ($TaskName -and [string]::IsNullOrWhiteSpace($TaskName)) {
        Write-Host -Object "[Error] The TaskName parameter cannot be empty or whitespace. Please provide a valid task name or keyword to filter on."
        exit 1
    }

    # Initialize the exit code variable
    $ExitCode = 0

    # Validate the multiline custom field name
    if ($MultilineCustomFieldName) {
        # Skip writing to the Multiline custom field if it is empty or whitespace
        if ([string]::IsNullOrWhiteSpace($MultilineCustomFieldName)) {
            Write-Host -Object "[Error] The value for 'Multiline Custom Field Name' only contains spaces. Please provide a valid Multiline custom field name or leave it blank."
            Write-Host -Object "[Error] Writing to the Multiline custom field will be skipped."
            $MultilineCustomFieldName = $null
            $ExitCode = 1
            Write-Host -Object ""
        }
        else {
            # Trim the Multiline Custom Field Name to remove leading and trailing whitespace
            $MultilineCustomFieldName = $MultilineCustomFieldName.Trim()

            # Skip writing to the Multiline custom field if it contains invalid characters
            if ($MultilineCustomFieldName -match "[^0-9A-Z]") {
                Write-Host -Object "[Error] The value for 'Multiline Custom Field Name' contains invalid character(s). Please provide a valid Multiline custom field name."
                Write-Host -Object "[Error] Writing to the Multiline custom field will be skipped."
                $MultilineCustomFieldName = $null
                $ExitCode = 1
                Write-Host -Object ""
            }
        }
    }

    # Validate the WYSIWYG custom field name
    if ($WYSIWYGCustomFieldName) {
        # Skip writing to the WYSIWYG custom field if it is empty or whitespace
        if ([string]::IsNullOrWhiteSpace($WYSIWYGCustomFieldName)) {
            Write-Host -Object "[Error] The value for 'WYSIWYG Custom Field Name' only contains spaces. Please provide a valid WYSIWYG custom field name or leave it blank."
            Write-Host -Object "[Error] Writing to the WYSIWYG custom field will be skipped."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            $WYSIWYGCustomFieldName = $null
            $ExitCode = 1
            Write-Host -Object ""
        }
        else {
            # Trim the WYSIWYG Custom Field Name to remove leading and trailing whitespace
            $WYSIWYGCustomFieldName = $WYSIWYGCustomFieldName.Trim()

            # Skip writing to the WYSIWYG custom field if it contains invalid characters
            if ($WYSIWYGCustomFieldName -match "[^0-9A-Z]") {
                Write-Host -Object "[Error] The value for 'WYSIWYG Custom Field Name' contains invalid character(s). Please provide a valid WYSIWYG custom field name."
                Write-Host -Object "[Error] Writing to the WYSIWYG custom field will be skipped."
                Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
                $WYSIWYGCustomFieldName = $null
                $ExitCode = 1
                Write-Host -Object ""
            }
        }
    }

    # Some Scheduled Tasks require Local Admin Privileges to view.
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

    if (!$IsElevated) {
        Write-Host -Object "[Error] Access Denied: The user '$env:Username' does not have Administrator privileges."
        exit 1
    }

    try {
        # By default, we'll exclude tasks made by Microsoft. They don't always put themselves down as an author.
        if (-not $IncludeMicrosoft) {
            $ScheduledTasks = Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.Author -notlike "Microsoft*" -and $_.TaskPath -notlike "\Microsoft*" }
        }
        else {
            $ScheduledTasks = Get-ScheduledTask -ErrorAction Stop
        }
    }
    catch {
        Write-Host -Object "[Error] Error while retrieving scheduled tasks."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # We should ignore disabled tasks unless told otherwise.
    if (-not $IncludeDisabled) {
        $ScheduledTasks = $ScheduledTasks | Where-Object { $_.State -notlike "Disabled" }
    }

    # If an argument for TaskName was provided, we'll filter the tasks based on it
    if ($TaskName) {
        # Split the TaskName by commas in case multiple were provided in one string
        $TaskName = $TaskName -split ","

        # Trim whitespace from each TaskName
        $TaskName = $TaskName | ForEach-Object { $_.Trim() }

        # Filter the scheduled tasks based on the provided TaskName(s)
        $ScheduledTasks = foreach ($Name in $TaskName) {
            $ScheduledTasks | Where-Object { $_.TaskName -match $Name }
        }

        # Filter out any duplicate tasks
        $ScheduledTasks = $ScheduledTasks | Select-Object -Unique
    }

    if ($ScheduledTasks) {
        # Format the ScheduledTasks list to include a shortened description if the description is too long.
        $ScheduledTasks = $ScheduledTasks | Select-Object -Property TaskName, TaskPath, Author, State, @{
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

        # Sort the scheduled tasks
        $ScheduledTasks = $ScheduledTasks | Sort-Object @{Expression = "State"; Descending = $true}, TaskName, Author

        Write-Host -Object "[Info] $(($ScheduledTasks | Measure-Object).Count) scheduled task(s) found that match the criteria.`n"

        # Set the multiline custom field if provided
        if ($MultilineCustomFieldName) {
            # Set the character limit for Multiline custom fields
            $multilineCharacterThreshold = 9500

            # Create a copy of the ScheduledTasks object to avoid modifying the original
            $multilineObject = $ScheduledTasks.PSObject.Copy()

            # Format the multiline object to a string
            $formattedMultilineString = ($multilineObject | Format-List | Out-String).Trim()

            # Measure the total character count of the formatted string
            $Characters = $formattedMultilineString | Measure-Object -Character | Select-Object -ExpandProperty Characters

            # Check if output would exceed Multiline custom field character limit and truncate if so
            if ($Characters -ge $multilineCharacterThreshold) {
                Write-Host -Object "[Warning] 10,000 character limit for Multiline fields has been reached! Trimming output until the character limit is satisfied..."

                do {
                    # Find the total number of objects in the multiline object
                    $objectCount = ($multilineObject | Measure-Object).Count

                    # Remove the last object by selecting the first ($objectCount - 1) objects
                    $multilineObject = $multilineObject | Select-Object -First ($objectCount - 1)

                    # Format the multiline object again
                    $formattedMultilineString = ($multilineObject | Format-List | Out-String).Trim()

                    # Add note to the top of the multiline field that the extensions have been truncated
                    $formattedMultilineString = $formattedMultilineString -replace "^(.*)", "`nThis info has been truncated to accommodate the 10,000 character limit.`n`n`$1"

                    # Check that we now comply with the character limit. If not restart the loop.
                    $Characters = $formattedMultilineString | Measure-Object -Character | Select-Object -ExpandProperty Characters
                } while ($Characters -ge $multilineCharacterThreshold)
            }

            try {
                Write-Host -Object "[Info] Publishing a list of scheduled tasks to the Multiline custom field '$MultilineCustomFieldName'."
                Set-NinjaProperty -Name $MultilineCustomFieldName -Value $formattedMultilineString -Type "Multiline" -ErrorAction Stop
                Write-Host -Object "[Info] Successfully set the '$MultilineCustomFieldName' custom field!`n"
            }
            catch {
                Write-Host -Object "[Error] Error setting the Multiline custom field '$MultilineCustomFieldName'."
                Write-Host -Object "[Error] $($_.Exception.Message)`n"
                $ExitCode = 1
            }
        }

        # Set the WYSIWYG custom field if provided
        if ($WYSIWYGCustomFieldName) {
            # Set the character limit for WYSIWYG fields
            $WYSIWYGCharacterThreshold = 44500

            # Convert the matching tasks into an HTML report.
            $htmlTable = $ScheduledTasks | ConvertTo-Html -Fragment

            # Format width and style of table columns
            $htmlTable = $htmlTable -replace "<th>TaskPath", "<th style='width:250px;'><b>TaskPath</b>"
            $htmlTable = $htmlTable -replace "<th>Author", "<th style='width:200px;'><b>Author</b>"
            $htmlTable = $htmlTable -replace "<th>State", "<th style='width:75px;'><b>State</b>"

            # Wrap table in a card layout
            $HtmlTable = "<div class='card flex-grow-1'>
                            <div class='card-title-box'>
                                <div class='card-title'><i class='fa-solid fa-gears'></i>&nbsp;&nbsp;Scheduled Tasks</div>
                            </div>
                            <div class='card-body' style='white-space: nowrap;'>
                                $HtmlTable
                            </div>
                        </div>"

            # Check that the output complies with the hard character limits.
            $Characters = $htmlTable | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters

            # If output exceeds the WYSIWYG character limit, truncate the output
            if ($Characters -ge $WYSIWYGCharacterThreshold) {
                Write-Host -Object "[Warning] 45,000 character limit for WYSIWYG fields has been reached! Trimming output until the character limit is satisfied..."

                # Add notice about truncation to the top of the table
                $htmlTable = $htmlTable -replace "<table>", "<p>This info has been truncated to accommodate the 45,000 character limit.</p><table>"

                # Regex expression to match rows in the HTML
                $rowRegex = '<tr>.*?</tr>'

                do {
                    # Create a collection of rows in the table
                    $rows = [regex]::Matches($htmlTable, $rowRegex)

                    # Get the value of the last row
                    $lastRowValue = $rows[$rows.Count - 1].Value

                    # Remove the last row from the table
                    $htmlTable = $htmlTable -replace [regex]::Escape($lastRowValue)

                    # Check that we now comply with the character limit. If not restart the loop.
                    $Characters = $htmlTable | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
                } while ($Characters -ge $WYSIWYGCharacterThreshold)
            }

            # Write the HTML table to the WYSIWYG custom field
            try {
                Write-Host -Object "[Info] Publishing a table of scheduled tasks to the WYSIWYG custom field '$WYSIWYGCustomFieldName'."
                Set-NinjaProperty -Name $WYSIWYGCustomFieldName -Value $htmlTable -Type "WYSIWYG" -ErrorAction Stop
                Write-Host -Object "[Info] Successfully set the '$WYSIWYGCustomFieldName' custom field!`n"
            }
            catch {
                Write-Host -Object "[Error] Error setting the WYSIWYG custom field '$WYSIWYGCustomFieldName'."
                Write-Host -Object "[Error] $($_.Exception.Message)`n"
                $ExitCode = 1
            }
        }

        # Check if output would exceed activity feed character limit and truncate if so
        if (($ScheduledTasks | Format-List | Out-String | Measure-Object -Character | Select-Object -Expand Characters) -ge 9500) {
            Write-Host -Object "[Warning] 10,000 character limit for the activity feed has been reached! Trimming output until the character limit is satisfied..."

            if (-not $WysiwygCustomFieldName) {
                Write-Host -Object "[Warning] Please publish this report to a WYSIWYG field for a full listing of scheduled tasks."
            }

            # Truncate the output by removing the last object until we are under the limit
            do {
                # Find the total number of objects in the ScheduledTasks object
                $objectCount = ($ScheduledTasks | Measure-Object).Count

                # Remove the last object by selecting the first ($objectCount - 1) objects
                $ScheduledTasks = $ScheduledTasks | Select-Object -First ($objectCount - 1)

                # Check that we now comply with the character limit. If not restart the do loop.
                $Characters = $ScheduledTasks | Format-List | Out-String | Measure-Object -Character | Select-Object -ExpandProperty Characters
            } while ($Characters -ge 9500)

            # Format the output and write it to the activity feed
            ($ScheduledTasks | Format-List | Out-String).TrimEnd() + "`n`n(...)" | Write-Host
        }
        else {
            # Format the output and write it to the activity feed
            ($ScheduledTasks | Format-List | Out-String).Trim() | Write-Host
        }
    }
    else {
        Write-Host -Object "[Info] No scheduled tasks found that match the criteria."
    }

    exit $ExitCode
}
end {
    
    
    
}