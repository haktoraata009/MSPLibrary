 <#
.SYNOPSIS
Convert regular UPD VHDX files to the content format and folder structure for FSLogix
.NOTES
Script assumes SAM_SID folder structure as this is easier to use when browsing for profiles in a folder. FSLogix default format is SID_SAM
Script assumes VHDX file extension. FSLogix default is VHD
Options to configure this are documented here: https://docs.microsoft.com/en-us/fslogix/configure-profile-container-tutorial
.REQUIREMENTS
AD Module
#>

#####################################################
################ Specify paths here #################
#####################################################


# Source path containg UVHD-SID.VHDX UPD files
$updroot = "\\FILESERVER\UserProfileDisks$\ConvertFSLogix"
##$updroot = "E:\User Profile Disks"


# Root path for FSLogix data
$fslogixroot = "\\FILESERVER\Profile Containers$"
##$fslogixroot = "F:\Profile Containers"

# Value in second to pause when mounting and dismounting the VHDX. Helps make sure the process has completed
$delay = 5


#####################################################
########## No need to edit below this line ##########
#####################################################

# Stop if the AD module cannot be loaded
If (!(Get-module ActiveDirectory)) {
Import-Module ActiveDirectory -ErrorAction Stop
}

# Outputs the current HHmmss value when called. Used to prefix log and console entries
Function ThisHHmmss() {
(Get-Date).ToString("HH:mm:ss")
}

# Index the VHDX files
$files = Get-ChildItem -Path $updroot -File -Filter UVHD-S*.vhdx | Sort Name

# Convert VHDX filename AD account information and add to the array $results
ForEach ($file in $files) {
    # Obtain the SID in the filename by removing the UVHD- prefix
    $sid = ($file.Basename).Substring(5)
    If 
    (
        # Only proceed with this file if there is an AD user with this SID
        (Get-ADUser -Filter { SID -eq $sid }) -ne $null
    ) {
        # Obtain Name and SAM values from the user SID
        $userinfo = Get-ADUser -Filter { SID -eq $sid } | Select Name, SamAccountName, UserPrincipalName, SID
        $name = ($userinfo.Name).ToString()
        $sam = ($userinfo.SamAccountName).ToString()
        Write-Host (ThisHHmmss) "Processing account: $name ($sam)" -ForegroundColor Green

        # Source UPD VHDX
        $sourcevhdx = $file.FullName
        # Unique user SAM_SID user folder name to store FSLogix VHDX
        $sam_sid = "$sam"+"_"+"$sid"
        # Full folder path to store VHDX
        $fslogixuserpath = "$fslogixroot" + "\" + "$sam_sid"

        # Mount the source VHDX and obtain the drive mapping
        Write-Host (ThisHHmmss) "Mounting VHDX: $sourcevhdx" -ForegroundColor Green
        Mount-DiskImage -ImagePath $sourcevhdx
        # Small delay to ensure VHDX has been mounted
        Write-Host (ThisHHmmss) "$delay Second delay after mounting $sourcevhdx" -ForegroundColor Green
        Start-Sleep -Seconds $delay
        # Get drive letter
        $mountletter = (Get-DiskImage -ImagePath $sourcevhdx | Get-Disk | Get-Partition).DriveLetter
        $mountpath = ($mountletter + ':\')

        
        #region internalVHDX
        #####################################################
        ##### These changes occur within the VHDX itself ####
        #####################################################
        
        ## Create a folder called Profile in the root of the mounted VHDX
        # Define path in the profile disk
        $ProfileDir = 'Profile'
        $vhdxprofiledir = Join-Path -Path $mountpath -ChildPath $ProfileDir
        # Create path in the profile disk
        If (!(Test-Path $vhdxprofiledir)) {
            Write-Output "Create Folder: $vhdxprofiledir"
            New-Item $vhdxprofiledir -ItemType Directory | Out-Null
        } 

        ## Move the user content into the new Profile folder
        # Defining the files and folders that should not be moved
        $Excludes = @("Profile", "Uvhd-Binding", "`$RECYCLE.BIN", "System Volume Information")

        # Copy profile disk content to the new profile folder
        $Content = Get-ChildItem $mountpath -Force
        ForEach ($C in $Content) {
            If ($Excludes -notcontains $C.Name) {
                Write-Output ('Move: ' + $C.FullName)
                Try { Move-Item $C.FullName -Destination $vhdxprofiledir -Force -ErrorAction Stop } 
                Catch { Write-Warning "Error: $_" }
            }

        }
       
        ## Create the .reg file containing the FSLogix information for the profile

        # Defining the registry file
        $regtext = "Windows Registry Editor Version 5.00
            [HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID]
            `"ProfileImagePath`"=`"C:\\Users\\$SAM`"
            `"Flags`"=dword:00000000
            `"State`"=dword:00000000
            `"ProfileLoadTimeLow`"=dword:00000000
            `"ProfileLoadTimeHigh`"=dword:00000000
            `"RefCount`"=dword:00000000
            `"RunLogonScriptSync`"=dword:00000001
            "

        # Create the folder and registry file
        Write-Output "Create Reg: $vhdxprofiledir\AppData\Local\FSLogix\ProfileData.reg"
        If (!(Test-Path "$vhdxprofiledir\AppData\Local\FSLogix")) {
            New-Item -Path "$vhdxprofiledir\AppData\Local\FSLogix" -ItemType directory | Out-Null
        }
        If (!(Test-Path "$vhdxprofiledir\AppData\Local\FSLogix\ProfileData.reg")) {
            $regtext | Out-File "$vhdxprofiledir\AppData\Local\FSLogix\ProfileData.reg" -Encoding ascii
        }

        #####################################################
        ########### End of internal VHDX changes ############
        #####################################################
        #endregion internalVHDX

        # Dismount source VHDX
        Dismount-DiskImage -ImagePath $sourcevhdx
        # Small delay after dismounting the VHDX file to ensure it and the drive letter are free
        Write-Host (ThisHHmmss) "$delay Second delay after dismounting $sourcevhdx" -ForegroundColor Green
        Start-Sleep -Seconds $delay

        ### Moving and renaming the VHDX happens here ###

        # Create the new SAM_SID user folder in the FSLogix root path
        Write-Host (ThisHHmmss) "Creating new folder $fslogixuserpath" -ForegroundColor Green
        New-Item -Path $fslogixroot -Name $sam_sid -ItemType Directory | Out-Null

        # Move the source UPD VHDX to the fsLogix path
        Write-Host (ThisHHmmss) "Moving original VHDX to new FSLogix location" -ForegroundColor Green
        Move-Item -Path $sourcevhdx -Destination $fslogixuserpath

        # Rename the VHDX file from the UPD format to the fsLogix format
        $updvhdx = "$fslogixuserpath" + "\" + "$file"
        $fslogixvhdx = "Profile_" + "$sam" + ".vhdx"
        Rename-Item $updvhdx -NewName $fslogixvhdx

        # This is the full filepath of the new VHDX file
        $newUVHD = "$fslogixuserpath" + "\" + "$fslogixvhdx"

        # Update NTFS permission to give the user RW access
        & icacls $fslogixuserpath /setowner "$env:userdomain\$sam" /T /C | Out-Null
        & icacls $fslogixuserpath /grant $env:userdomain\$sam`:`(OI`)`(CI`)F /T | Out-Null
        & icacls $newUVHD /grant $env:userdomain\$sam`:`(OI`)`(CI`)F /T /inheritance:E | Out-Null

        Write-Host (ThisHHmmss) "Finished processing account $Name" -ForegroundColor Green

        # Clear user variables to be safe
        Clear-Variable file, sid, userinfo, name, sam, sourcevhdx, sam_sid, fslogixuserpath, mountletter, mountpath, vhdxprofiledir, Content, regtext, updvhdx, fslogixvhdx, newUVHD
        Write-Host "#######################################################"
    }

} 
