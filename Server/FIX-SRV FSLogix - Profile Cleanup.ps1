# The purpose of this script is to clean up any FSLogix user profile remnants after a server crash

# Delete FSLogix session information from registry
Get-ChildItem "HKLM:\SOFTWARE\FSLogix\Profiles\Sessions" | Remove-Item -Recurse -Force

# Delete FSLogix user profiles from registry
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" | Where {($_.Property -Contains "FSL_OriginalProfileImagePath")} | Remove-Item $_.Name -Recurse -Force

# Delete local user profile folders
\\contoso.local\NETLOGON\DelProf2.exe /u /id:local_*
