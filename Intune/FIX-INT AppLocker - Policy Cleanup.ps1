# Cleans up AppLocker Policies in C:\windows\system32\applocker\
# This is great for unassigning AppLocker Policies via Intune because Intune doesn't remove the policy from the devices.

# Identify the date that the MDM policy was applied
$MDMTime = (Get-Item C:\windows\system32\applocker\MDM).LastWriteTime.Date

# Find all items in the AppLocker folder that match that date and delete them
Get-ChildItem C:\windows\system32\applocker\ | Where-Object{$_.LastWriteTime.Date -eq $MDMTime} | ForEach-Object {Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue}

gpupdate /force