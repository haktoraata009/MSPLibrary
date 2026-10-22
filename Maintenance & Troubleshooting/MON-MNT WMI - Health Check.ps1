#Requires -Version 5.1

<#
.SYNOPSIS
    Test the most common WMI classes for issues, optionally reporting to a multiline or WYSIWYG custom field.
.DESCRIPTION
    Test the most common WMI classes for issues, optionally reporting to a multiline or WYSIWYG custom field.

.EXAMPLE
    (No Parameters)
    ## EXAMPLE OUTPUT WITHOUT PARAMS ##

    [Info] Testing common WMI classes for consistency.

    [Info] All WMI queries completed successfully.

    Class                             Status
    -----                             ------
    Win32_Account                     Consistent
    Win32_AccountSID                  Consistent
    Win32_Battery                     Consistent
    Win32_BIOS                        Consistent
    Win32_ComputerSystem              Consistent
    Win32_CurrentTime                 Consistent
    Win32_DiskDrive                   Consistent
    Win32_Environment                 Consistent
    Win32_Fan                         Consistent
    Win32_Group                       Consistent
    Win32_GroupUser                   Consistent
    Win32_LoggedOnUser                Consistent
    Win32_LogicalDisk                 Consistent
    Win32_LogonSession                Consistent
    Win32_NetworkAdapter              Consistent
    Win32_NetworkAdapterConfiguration Consistent
    Win32_NetworkAdapterSetting       Consistent
    Win32_NetworkClient               Consistent
    Win32_NetworkConnection           Consistent
    Win32_NetworkLoginProfile         Consistent
    Win32_NetworkProtocol             Consistent
    Win32_OperatingSystem             Consistent
    Win32_Perf                        Consistent
    Win32_PhysicalMedia               Consistent
    Win32_PnPDevice                   Consistent
    Win32_Printer                     Consistent
    Win32_Process                     Consistent
    Win32_Processor                   Consistent
    Win32_Service                     Consistent
    Win32_Volume                      Consistent

.EXAMPLE
    -MultilineCustomFieldName "WMIHealthCheck" -WYSIWYGCustomFieldName "WMIHealthCheckWYSIWYG"

    [Info] Testing common WMI classes for consistency.

    [Alert] Errors occurred while querying the following WMI classes. This indicates an inconsistent WMI repository.

    Class      Status       Error
    -----      ------       -----
    Win32_Perf Inconsistent Invalid class

    ### Consistent WMI Classes: ###

    Class                             Status
    -----                             ------
    Win32_Account                     Consistent
    Win32_AccountSID                  Consistent
    Win32_Battery                     Consistent
    Win32_BIOS                        Consistent
    Win32_ComputerSystem              Consistent
    Win32_CurrentTime                 Consistent
    Win32_DiskDrive                   Consistent
    Win32_Environment                 Consistent
    Win32_Fan                         Consistent
    Win32_Group                       Consistent
    Win32_GroupUser                   Consistent
    Win32_LoggedOnUser                Consistent
    Win32_LogicalDisk                 Consistent
    Win32_LogonSession                Consistent
    Win32_NetworkAdapter              Consistent
    Win32_NetworkAdapterConfiguration Consistent
    Win32_NetworkAdapterSetting       Consistent
    Win32_NetworkClient               Consistent
    Win32_NetworkConnection           Consistent
    Win32_NetworkLoginProfile         Consistent
    Win32_NetworkProtocol             Consistent
    Win32_OperatingSystem             Consistent
    Win32_PhysicalMedia               Consistent
    Win32_PnPDevice                   Consistent
    Win32_Printer                     Consistent
    Win32_Process                     Consistent
    Win32_Processor                   Consistent
    Win32_Service                     Consistent
    Win32_Volume                      Consistent

    [Info] Writing results to multiline custom field 'WMIHealthCheck'.
    [Info] Successfully wrote results to multiline custom field 'WMIHealthCheck'.

    [Info] Writing results to WYSIWYG custom field 'WMIHealthCheckWYSIWYG'.
    [Info] Successfully wrote results to WYSIWYG custom field 'WMIHealthCheckWYSIWYG'.

.PARAMETER MultilineCustomFieldName
    Enter the name of a multiline custom field to report results to.
.PARAMETER WYSIWYGCustomFieldName
    Enter the name of a WYSIWYG custom field to report results to.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.0
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$MultilineCustomFieldName,
    [Parameter()]
    [string]$WYSIWYGCustomFieldName
)

begin {
    Write-Host ""
    # Check if the operating system build version is less than 10240 (Windows 10 or Windows Server 2016 minimum requirement)
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Import script variables
    if ($env:MultilineCustomFieldName) {$MultilineCustomFieldName = $env:MultilineCustomFieldName}
    if ($env:WYSIWYGCustomFieldName) {$WYSIWYGCustomFieldName = $env:WYSIWYGCustomFieldName}

    # Validate the Multiline custom field name if provided
    if ($MultilineCustomFieldName) {
        # Trim the field name to remove leading and trailing whitespace
        $MultilineCustomFieldName = $MultilineCustomFieldName.Trim()

        # Validate that the field is not just whitespace
        if ([string]::IsNullOrWhiteSpace($MultilineCustomFieldName)) {
            Write-Host "[Error] The 'Multiline Custom Field Name' parameter contains only spaces. Please provide a valid field name or leave it blank."
            exit 1
        }

        # Validate that the field name contains only alphanumeric characters
        if ($MultilineCustomFieldName -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'Multiline Custom Field Name' of '$MultilineCustomFieldName' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid Multiline custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Validate the WYSIWYG custom field name if provided
    if ($WYSIWYGCustomFieldName) {
        # Trim the field name to remove leading and trailing whitespace
        $WYSIWYGCustomFieldName = $WYSIWYGCustomFieldName.Trim()

        # Validate that the field is not just whitespace
        if ([string]::IsNullOrWhiteSpace($WYSIWYGCustomFieldName)) {
            Write-Host "[Error] The 'WYSIWYG Custom Field Name' parameter contains only spaces. Please provide a valid field name or leave it blank."
            exit 1
        }

        # Validate that the field name contains only alphanumeric characters
        if ($WYSIWYGCustomFieldName -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' of '$WYSIWYGCustomFieldName' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid WYSIWYG custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
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
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running this script in an elevated session."
        exit 1
    }

    # Error if not elevated and writing to custom fields
    if (!$IsElevated -and ($MultilineCustomFieldName -or $WYSIWYGCustomFieldName)) {
        Write-Host -Object "[Error] The user '$env:USERNAME' is not running this script in an elevated session. An elevated session is required when writing to custom fields."
        Write-Host -Object "[Error] Please run this script as System or in an elevated session, or remove the custom field parameters and run again."
        exit 1
    }

    # Retrieve details about the winmgmt service
    try {
        $Service = Get-Service -Name "winmgmt" -ErrorAction Stop
    }
    catch {
        Write-Host "[Error] Failed to retrieve the Windows Management Instrumentation service."
        Write-Host "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Error if the service is disabled
    if ($Service.StartType -eq "Disabled") {
        Write-Host "[Error] The Windows Management Instrumentation service (winmgmt) is disabled."
        Write-Host "[Error] Please enable and start the service, then run the script again."
        exit 1
    }

    # Error if the service is not running
    if ($Service.Status -ne "Running") {
        Write-Host "[Error] The Windows Management Instrumentation service (winmgmt) is not running, it is currently '$($Service.Status)'."
        Write-Host "[Error] Please start the service, then run the script again."
        exit 1
    }

    # List of classes that will be tested
    $ClassesToTest = @(
        "Win32_Account"
        "Win32_AccountSID"
        "Win32_Battery"
        "Win32_BIOS"
        "Win32_ComputerSystem"
        "Win32_CurrentTime"
        "Win32_DiskDrive"
        "Win32_Environment"
        "Win32_Fan"
        "Win32_Group"
        "Win32_GroupUser"
        "Win32_LoggedOnUser"
        "Win32_LogicalDisk"
        "Win32_LogonSession"
        "Win32_NetworkAdapter"
        "Win32_NetworkAdapterConfiguration"
        "Win32_NetworkAdapterSetting"
        "Win32_NetworkClient"
        "Win32_NetworkConnection"
        "Win32_NetworkLoginProfile"
        "Win32_NetworkProtocol"
        "Win32_OperatingSystem"
        "Win32_Perf"
        "Win32_PhysicalMedia"
        "Win32_PnPDevice"
        "Win32_Printer"
        "Win32_Process"
        "Win32_Processor"
        "Win32_Service"
        "Win32_Volume"
    )

    # Initialize a list to hold class results
    $ClassResultsObject = New-Object -TypeName System.Collections.Generic.List[object]

    Write-Host "[Info] Testing common WMI classes for consistency.`n"

    # Loop through each class and query it to test for errors
    foreach ($Class in $ClassesToTest) {
        try {
            # Query the WMI class with a timeout of 30 seconds
            Get-CimInstance -ClassName $Class -ErrorAction Stop -OperationTimeoutSec 30 | Out-Null

            # Add a result object to the class results list indicating success
            $ClassResultsObject.Add(
                [PSCustomObject]@{
                    Class  = $Class
                    Status = "Consistent"
                }
            )
        }
        catch {
            $ErrorMessage = $_.Exception.Message.Trim()

            # If an error occurs during querying, add a result object indicating failure
            $ClassResultsObject.Add(
                [PSCustomObject]@{
                    Class  = $Class
                    Status = "Inconsistent"
                    Error  = $ErrorMessage
                }
            )
        }
    }

    # Sort the class results object so that classes with issues appear first
    $ClassResultsObject = $ClassResultsObject | Sort-Object -Property @{Expression = {
            switch ($_.Status) {
                "Inconsistent" { 0 }
                "Consistent" { 1 }
                default { 2 }
            }
        }
    }, Class

    # Filter for failed queries
    $FailedQueries = $ClassResultsObject | Where-Object { $_.Status -ne "Consistent" }

    # If there are any failed queries, output them separately from the main results
    if ($FailedQueries) {
        Write-Host "[Alert] Errors occurred while querying the following WMI classes. This indicates an inconsistent WMI repository.`n"
        ($FailedQueries | Format-Table -AutoSize | Out-String).Trim() | Write-Host

        Write-Host "`n### Consistent WMI Classes: ###`n"
        ($ClassResultsObject | Where-Object { $_.Status -eq "Consistent" } | Select-Object Class, Status | Format-Table -AutoSize | Out-String).Trim() | Write-Host
    }
    elseif ($ClassResultsObject) {
        Write-Host "[Info] All WMI queries completed successfully.`n"

        ($ClassResultsObject | Where-Object { $_.Status -eq "Consistent" } | Select-Object Class, Status | Format-Table -AutoSize | Out-String).Trim() | Write-Host
    }

    # If a multiline field was specified, write results to it
    if ($MultilineCustomFieldName) {
        Write-Host ""

        # Initialize the multiline field content string builder
        $MultilineFieldBuilder = New-Object -TypeName System.Text.StringBuilder

        # Add a header based on if there were any failed queries
        if ($FailedQueries) {
            [void]$MultilineFieldBuilder.AppendLine("[Alert] WMI Repository: Inconsistent`n")
        }
        else {
            [void]$MultilineFieldBuilder.AppendLine("WMI Repository: Consistent`n")
        }

        # Build the multiline field content
        ($ClassResultsObject | Format-List | Out-String).Trim() | ForEach-Object { [void]$MultilineFieldBuilder.AppendLine($_) }

        # Get the final multiline field content from the string builder
        $MultilineFieldContent = $MultilineFieldBuilder.ToString()

        try {
            Write-Host "[Info] Writing results to multiline custom field '$MultilineCustomFieldName'."
            Set-NinjaProperty -Name $MultilineCustomFieldName -Value $MultilineFieldContent -ErrorAction Stop
            Write-Host "[Info] Successfully wrote results to multiline custom field '$MultilineCustomFieldName'."
        }
        catch {
            Write-Host "[Error] Failed to write results to multiline custom field '$MultilineCustomFieldName'."
            Write-Host "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    # Write results to WYSIWYG custom field if specified
    if ($WYSIWYGCustomFieldName) {
        Write-Host ""

        # If there were any failed queries, prepend an alert header and create a separate table for them
        if ($FailedQueries) {
            $WMIStatus = "<h3>[Alert] WMI Repository: Inconsistent</h3>"

            # Create the failed queries table
            $FailedQueriesTable = $FailedQueries | Select-Object Class, Status, Error | ConvertTo-Html -Fragment

            # Bold the headers and highlight the rows
            $FailedQueriesTable = $FailedQueriesTable -replace "<th>", "<th><strong>" -replace "</th>", "</strong></th>"
            $FailedQueriesTable = $FailedQueriesTable | ForEach-Object {
                if ($_ -match "Inconsistent") {
                    $_ -replace "<tr>", "<tr class='danger'>"
                }
                else {
                    $_
                }
            }

            # Create the consistent classes table
            $ClassTable = $ClassResultsObject | Where-Object {$_.Status -eq "Consistent"} | ConvertTo-Html -Fragment
        }
        else {
            $WMIStatus = "<h3>WMI Repository: Consistent</h3>"
            $ClassTable = $ClassResultsObject | ConvertTo-Html -Fragment
        }

        # Bold the headers of the class table
        $ClassTable = $ClassTable -replace "<th>", "<th><strong>" -replace "</th>", "</strong></th>"

        # Prepare the final WYSIWYG content
        # Start with the WMI Status header, then add the failed queries table if it exists, followed by the consistent classes table
        $WYSIWYGContent = "$WMIStatus
                        <div class='card flex-grow-1'>
                            $(
                                if ($FailedQueriesTable) {
                                    "<div class='card-title-box'>
                                        <div class='card-title'><i class='fa-solid fa-circle-exclamation'></i>&nbsp;&nbsp;Inconsistent WMI Classes</div>
                                    </div>
                                    <div class='card-body' style='white-space: nowrap; margin-bottom: 10px;'>
                                        $FailedQueriesTable
                                    </div>"
                                }
                            )
                            <div class='card-title-box'>
                                <div class='card-title'><i class='fa-solid fa-list'></i>&nbsp;&nbsp;Consistent WMI Classes</div>
                            </div>
                            <div class='card-body' style='white-space: nowrap;'>
                                $ClassTable
                            </div>
                        </div>"

        try {
            Write-Host "[Info] Writing results to WYSIWYG custom field '$WYSIWYGCustomFieldName'."
            Set-NinjaProperty -Name $WYSIWYGCustomFieldName -Value $WYSIWYGContent -ErrorAction Stop
            Write-Host "[Info] Successfully wrote results to WYSIWYG custom field '$WYSIWYGCustomFieldName'."
        }
        catch {
            Write-Host "[Error] Failed to write results to WYSIWYG custom field '$WYSIWYGCustomFieldName'."
            Write-Host "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    exit $ExitCode
}
end {
    
    
    
}