# Install the required modules if not already installed
Install-Module -Name Microsoft.Graph -Force -AllowClobber

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.ReadWrite.All", "Sites.ReadWrite.All"

#CSV includes- 
#GroupName,GroupMailNickname,SiteURL,Template/
#Contoso Clients,ContosoClients,https://contoso.sharepoint.com/sites/ContosoClients,STS#3


# Path to the CSV file
$csvPath = "C:\Temp\site-template.csv"

# Import the CSV file
$groups = Import-Csv -Path $csvPath

foreach ($group in $groups) {
    # Create the group
    $newGroup = New-MgGroup -DisplayName $group.GroupName -MailNickname $group.GroupMailNickname -MailEnabled:$true -SecurityEnabled:$false -GroupTypes "Unified"

    # Create the SharePoint site and associate it with the group
    $site = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$($newGroup.Id)/sites" -Body @{
        displayName = $group.GroupName
        webUrl = $group.SiteUrl
        template = $group.SiteTemplate
    }

    # Output the group and site details
    Write-Output "Group created: $($newGroup.DisplayName)"
    Write-Output "SharePoint site created: $($site.displayName) - $($site.webUrl)"
}