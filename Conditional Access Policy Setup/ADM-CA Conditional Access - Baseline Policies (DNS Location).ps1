<##################################################################################################
#
.SYNOPSIS
    This script contains a baseline for SMB orgs to create the following recommended Conditional Access policies:
    
    CA001: Block legacy authentication
    CA002: Block access from unsupported device platforms
    CA003: Require MFA for Azure management 
    CA004: Require MFA to register or join devices 
    CA101: Require MFA for admin users
    CA201: Require MFA for internal users
    CA202: Securing security info registration
    CA203: Require MAM or MDM for mobile device access (Office 365)
    CA204: Require managed devices for desktop client access (Office 365)
    CA205: Block access outside NZ & Aus
    CA301: Block guest access to unsupported apps
    CA302: Require MFA for guests & external users
  
    
.NOTES
    1. You may need to disable the 'Security defaults' first. See https://aka.ms/securitydefaults
    2. None of the policies created by this script will be enabled by default.
    3. Before enabling policies, you should notify end users about the expected impacts
    4. Be sure to populate the security group 'sgu-Exclude from CA' with at least one admin account for emergency access

.HOW-TO
    1. To install the Azure AD Preview PowerShell module use: Install-Module AzureADPreview -AllowClobber
    2. Run .\Install-ITPMBaselineCAPolicies.ps1

.DETAILS
    FileName:    Install-ITPMBaselineCAPolicies.ps1
    Author:      Alex Fields, ITProMentor.com
    Created:     February 2022
    Updated:     February 2022
    VERSION:     1.0

#>

###################################################################################################
## Import Modules
Import-Module AzureADPreview


###################################################################################################
## Define Group Names

#Exclude from all policies (emergency break glass account should be only member)
$ExcludeCAGroupName = "Conditional Access - Excluded Users" # See also: sgu-Exclude From CA
# Incase group does not exist, use the name without spaces for its 'mail' address required field
$ExcludeCAGroupMailName = $ExcludeCAGroupName.Replace(' ','')

#Group to allow bypassing of geo filtering for users traveling etc.
$RoamingGroupName = "Conditional Access - International Roaming Users" # See also: Conditional Acccess - Overseas Access Allowed
#Incase group does not exist, use the name without spaces for its 'mail' address required field
$RoamingGroupMailName = $RoamingGroupName.Replace(' ','')

## Define Policy Names
# 000 policies are for all users (global settings)
$CA001PolicyName = "CA001: Block legacy authentication"
$CA002PolicyName = "CA002: Block access from unsupported device platforms"
$CA003PolicyName = "CA003: Require MFA for Azure management"
$CA004PolicyName = "CA004: Require MFA to register or join devices"
# 100 polices are for admin users
$CA101PolicyName = "CA101: Require MFA for admin users"
# 200 policies are for normal users
$CA201PolicyName = "CA201: Require MFA or compliant device for internal users"
$CA202PolicyName = "CA202: Securing security info registration"
$CA203PolicyName = "CA203: Require MAM or MDM for mobile device access (Office 365)"
$CA204PolicyName = "CA204: Require managed devices for desktop client access (Office 365)"
$CA205PolicyName = "CA205: Block access outside NZ & Aus"
# 300 policies are for guest accounts
$CA301PolicyName = "CA301: Block guest access to unsupported apps"
$CA302PolicyName = "CA302: Require MFA for guests and external users"

###################################################################################################
## Define IP & geolocation names
$MSPIPDisplayName = "MSP Office"
$NZIPDisplayName = "Geo - New Zealand"
$AUIPDisplayName = "Geo - Australia"
$DateTime = Get-Date -Format "yyyy-MM-dd HHmm"

## Define IP ranges
#Read in current MSP Office IPs from DNS, then convert to CIDR format
$DNSRecordIPs = (([System.Net.Dns]::GetHostAddresses("office.example.com") | Select IPAddressToString -ExpandProperty IPAddressToString).ForEach({$_ + "/32"}))
#Convert to usable IPRange object
[System.Collections.Generic.List[Microsoft.Open.MSGraph.Model.IpRange]]$MSPIpRange = $DNSRecordIPs.Split(" ")


###################################################################################################
## Define Admin Roles

# Based on the recommended roles documented here:
# https://learn.microsoft.com/en-us/entra/identity/conditional-access/howto-conditional-access-policy-admin-mfa
# The IDs are documented here: 
# https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference

$AdminRoles = @(
'62e90394-69f5-4237-9190-012177145e10',` # Global Administrator
'9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3',` # Application Administrator
'c4e39bd9-1100-46d3-8c65-fb160da0071f',` # Authentication Administrator
'158c047a-c907-4556-b7ef-446551a6b5f7',` # Cloud Application Administrator
'f28a1f50-f6e7-4571-818b-6a12f2af6b6c',` # SharePoint Administrator
'29232cdf-9323-42fd-ade2-1d097af3e4de',` # Exchange Administrator
'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9',` # Conditional Access Administrator
'194ae4cb-b126-40b2-bd5b-6091b380977d',` # Security Administrator
'729827e3-9c14-49f7-bb1b-9608f156bbb8',` # Helpdesk Administrator
'966707d0-3269-4727-9be2-8c3a10f19b9d',` # Password Administrator
'b0f54661-2d74-4c50-afa3-1ec803f12efe',` # Billing Administrator
'fe930be7-5e62-47db-91af-98c3a49a38b1',` # User Administrator
'7be44c8a-adaf-4e2a-84d6-ab2649e08a13',` # Privileged Authentication Administrator
'e8611ab8-c189-46e8-94e1-60213ab1f814'   # Privileged Role Administrator
)


###################################################################################################
## Connect to AzureAD
Connect-AzureAD


###################################################################################################
## Check for the existence of the security groups, and create if it does not exist

$ExcludeCAGroup = Get-AzureADGroup -All $true | Where-Object DisplayName -eq $ExcludeCAGroupName
If ($ExcludeCAGroup -eq $null -or $ExcludeCAGroup -eq "") {
    New-AzureADGroup -DisplayName $ExcludeCAGroupName -SecurityEnabled $true -MailEnabled $false -MailNickName $ExcludeCAGroupMailName
    $ExcludeCAGroup = Get-AzureADGroup -All $true | Where-Object DisplayName -eq $ExcludeCAGroupName
} else {
    Write-Host "Exclude from CA group already exists"
}

$RoamingGroup = Get-AzureADGroup -All $true | Where-Object DisplayName -eq $RoamingGroupName
If ($RoamingGroup -eq $null -or $RoamingGroup -eq "") {
    New-AzureADGroup -DisplayName $RoamingGroupName -SecurityEnabled $true -MailEnabled $false -MailNickName $RoamingGroupMailName
    $RoamingGroup = Get-AzureADGroup -All $true | Where-Object DisplayName -eq $RoamingGroupName
} else {
    Write-Host "Roaming user CA group already exists"
}


###################################################################################################
## Read in all the existing policies grabbing the DisplayNames and IDs
$ExistingPolicies = Get-AzureADMSNamedLocationPolicy | Select DisplayName, ID

###################################################################################################
## Add "Named Location" entries to AzureAD

#Update existing MSP IP Location object or create if not already present in Tenant
If ($ExistingPolicies.DisplayName -Contains $MSPIPDisplayName) { Set-AzureADMSNamedLocationPolicy -PolicyID $(($ExistingPolicies | Where {$_.DisplayName -contains $MSPIPDisplayName}).ID) -OdataType "#microsoft.graph.ipNamedLocation" -DisplayName $MSPIPDisplayName -IsTrusted $True -IpRanges $MSPIpRange } Else { New-AzureADMSNamedLocationPolicy -OdataType "#microsoft.graph.ipNamedLocation" -DisplayName $MSPIPDisplayName -IsTrusted $True -IpRanges $MSPIpRange}

## Create New Zealand Location Object if it does not exist
If (!($ExistingPolicies.DisplayName -Contains $NZIPDisplayName)) { New-AzureADMSNamedLocationPolicy -OdataType "#microsoft.graph.countryNamedLocation" -CountriesAndRegions "NZ" -DisplayName $NZIPDisplayName }

## Create Australia Location Object if it does not exist
If (!($ExistingPolicies.DisplayName -Contains $AUIPDisplayName)) { New-AzureADMSNamedLocationPolicy -OdataType "#microsoft.graph.countryNamedLocation" -CountriesAndRegions "AU" -DisplayName $AUIPDisplayName }

# Get the ID's for the new locations to be excluded in policies later
$NZIPID = $(Get-AzureADMSNamedLocationPolicy | Where-Object {$_.DisplayName -eq "$NZIPDisplayName"}).ID
$AUIPID = $(Get-AzureADMSNamedLocationPolicy | Where-Object {$_.DisplayName -eq "$AUIPDisplayName"}).ID

###################################################################################################
# Policy Functions

Function Define-Conditions
{
  Param(
    #Apps to include, generally this will be all
    [Parameter(Mandatory=$false)]
    [array]$IncludeApplications,
    #Apps to exclude from the CA - not used by default
    [Parameter(Mandatory=$false)]
    [array]$ExcludeApplications,
    #User actions to include - used instead of apps
    [Parameter(Mandatory=$false)]
    $IncludeUserActions,
    #User actions to exclude - used instead of apps
    [Parameter(Mandatory=$false)]
    $ExcludeUserActions,
    #Users to include, this should just be "all"
    [Parameter(Mandatory=$false)]
    $IncludeUsers,
    #Users to exclude, should use the exclude groups instead
    [Parameter(Mandatory=$false)]
    $ExcludeUsers,
    #Roles to include, used for the admin roles policy
    [Parameter(Mandatory=$false)]
    $IncludeRoles,
    #Roles to exclude
    [Parameter(Mandatory=$false)]
    $ExcludeRoles,
    #Groups to include, usually would just use the "all" under users
    [Parameter(Mandatory=$false)]
    $IncludeGroups,
    #Groups to include, by default should just be the exclude group this script creates
    [Parameter(Mandatory=$false)]
    $ExcludeGroups,
    #Client apps - used to block the legacy auth etc.
    [Parameter(Mandatory=$false)]
    [array]$ClientAppTypes,
    #Locations to include in the policy - usually just all
    [Parameter(Mandatory=$false)]
    [array]$IncludeLocations,
    #Locations to exclude, usually just all trusted locations
    [Parameter(Mandatory=$false)]
    [array]$ExcludeLocations,
    #Platforms to include, used to limit policies to just mobiles etc.
    [Parameter(Mandatory=$false)]
    [array]$IncludePlatforms,
    #Platforms to exclude
    [Parameter(Mandatory=$false)]
    [array]$ExcludePlatforms
  )
  #Create the core conditions object
  $Global:Conditions = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessConditionSet
  
  #Define the application conditions
  $Conditions.Applications = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessApplicationCondition
  #Set the included applications if it exists
  If ($IncludeApplications) { $Conditions.Applications.IncludeApplications = $IncludeApplications }
  #Set the included applications if it exists
  If ($ExludeApplications) { $Conditions.Applications.ExcludeApplications = $ExcludeApplications }
  #Set the included user actions if it exists
  If ($IncludeUserActions) { $Conditions.Applications.IncludeUserActions = $IncludeUserActions }
  #Set the excluded user actions if it exists
  If ($ExcludeUserActions) { $Conditions.Applications.ExcludeUserActions = $ExcludeUserActions }
  
  #Define the user conditions
  $Conditions.Users = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessUserCondition
  #Set the included users or roles
  If ($IncludeUsers) { $Conditions.Users.IncludeUsers = $IncludeUsers }
  If ($IncludeRoles) { $Conditions.Users.IncludeRoles = $IncludeRoles }
  #Set the excluded users/groups if they exist
  If ($ExcludeGroups) { $Conditions.Users.ExcludeGroups = $ExcludeGroups }

  #Define the location conditions, skip if no include defined to leave it as not configured
  If ($IncludeLocations) { $Conditions.Locations = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessLocationCondition }
  #Set the included locations if they exist
  If ($IncludeLocations) { $Conditions.Locations.IncludeLocations = $IncludeLocations }
  #Set the excluded locations if they exist
  If ($ExcludeLocations) { $Conditions.Locations.ExcludeLocations = $ExcludeLocations }
  
  #Define the platform conditions, skip if no include defined to leave it as not configured
  If ($IncludePlatforms) { $Conditions.Platforms = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessPlatformCondition }
  #Set the included platforms if they exist
  If ($IncludePlatforms) { $Conditions.Platforms.IncludePlatforms = $IncludePlatforms }
  #Set the excluded platforms if they exist
  If ($ExcludePlatforms) { $Conditions.Platforms.ExcludePlatforms = $ExcludePlatforms }

  #Set the client app conditions
  If ($ClientAppTypes) { $Conditions.ClientAppTypes = $ClientAppTypes }

}

Function Define-Controls
{
  Param(
    [Parameter(Mandatory=$true)]
    [string]$Operator,
    [Parameter(Mandatory=$true)]
    [array]$BuiltInControls
  )
  #Create the core controls object
  $Global:Controls = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessGrantControls
  $Controls._Operator = $Operator
  $Controls.BuiltInControls = $BuiltInControls
}


###################################################################################################
# Create Policies

#Set the default exclusion to be the one group
$DefaultExclusion = $ExcludeCAGroup.ObjectId

########################################################
## CA001: Block legacy authentication
## This policy blocks legacy authentication for all users; check sign-in logs for legacy auth before enabling this policy.

Define-Conditions -IncludeApplications "All" -IncludeUsers "All" -ExcludeGroups @($DefaultExclusion) -ClientAppTypes @('ExchangeActiveSync', 'Other')
Define-Controls -Operator "OR" -BuiltInControls "Block"
  
#Check if there is a matching policy name already, if so find its ID
$PolicyID = $null
$PolicyID = (Get-AzureADMSConditionalAccessPolicy | Where-Object {$_.DisplayName -eq "$CA001PolicyName"}).ID

#If an ID was found, update the existing policy, otherwise just create a new policy 
If ($PolicyID.length -lt 36)
{ 
  New-AzureADMSConditionalAccessPolicy -DisplayName $CA001PolicyName -State "Disabled" -Conditions $Conditions -GrantControls $Controls
} Else {
  Set-AzureADMSConditionalAccessPolicy -PolicyID $PolicyID -Conditions $Conditions -GrantControls $Controls
}

########################################################
## CA002: Block access from unsupported device platforms
## This policy prevents access from unsupported devices platforms such as Linux and ChromeOS

Define-Conditions -IncludeApplications "All" -IncludeUsers "All" -ExcludeGroups @($DefaultExclusion) -IncludePlatforms "All" -ExcludePlatforms @('Android', 'IOS', 'Windows', 'macOS')
Define-Controls -Operator "OR" -BuiltInControls "Block"
  
#Check if there is a matching policy name already, if so find its ID
$PolicyID = (Get-AzureADMSConditionalAccessPolicy | Where-Object {$_.DisplayName -eq "$CA002PolicyName"}).ID
#If an ID was found, update the existing policy, otherwise just create a new policy 
If ($PolicyID.length -lt 36)
{ 
  New-AzureADMSConditionalAccessPolicy -DisplayName $CA002PolicyName -State "Disabled" -Conditions $Conditions -GrantControls $Controls
} Else {
  Set-AzureADMSConditionalAccessPolicy -PolicyID $PolicyID -Conditions $Conditions -GrantControls $Controls
}

########################################################
## CA003: Require MFA for Azure management
## This policy requires Multi-factor Authentication for Azure Management for all users

Define-Conditions -IncludeApplications "797f4846-ba00-4fd7-ba43-dac1f8f63013" -IncludeUsers "All" -ExcludeGroups @($DefaultExclusion)
Define-Controls -Operator "OR" -BuiltInControls "MFA"
  
#Check if there is a matching policy name already, if so find its ID
$PolicyID = $null
$PolicyID = (Get-AzureADMSConditionalAccessPolicy | Where-Object {$_.DisplayName -eq "$CA003PolicyName"}).ID
#If an ID was found, update the existing policy, otherwise just create a new policy 
If ($PolicyID.length -lt 36)
{ 
  New-AzureADMSConditionalAccessPolicy -DisplayName $CA003PolicyName -State "Disabled" -Conditions $Conditions -GrantControls $Controls
} Else {
  Set-AzureADMSConditionalAccessPolicy -PolicyID $PolicyID -Conditions $Conditions -GrantControls $Controls
}

########################################################
## CA004: Require MFA to register or join devices
## This policy requires Multi-factor Authentication when registering or joining a new device

Define-Conditions -IncludeUserActions "urn:user:registerdevice" -IncludeUsers "All" -ExcludeGroups @($DefaultExclusion)
Define-Controls -Operator "OR" -BuiltInControls "MFA"
  
#Check if there is a matching policy name already, if so find its ID
$PolicyID = $null
$PolicyID = (Get-AzureADMSConditionalAccessPolicy | Where-Object {$_.DisplayName -eq "$CA004PolicyName"}).ID
#If an ID was found, update the existing policy, otherwise just create a new policy 
If ($PolicyID.length -lt 36)
{ 
  New-AzureADMSConditionalAccessPolicy -DisplayName $CA004PolicyName -State "Disabled" -Conditions $Conditions -GrantControls $Controls
} Else {
  Set-AzureADMSConditionalAccessPolicy -PolicyID $PolicyID -Conditions $Conditions -GrantControls $Controls
}

########################################################
# ADMIN PERSONA POLICIES:
# These policies target admin roles specifically

########################################################
## CA101: Require MFA for admins
## This policy requires Multi-factor Authentication for Admin users

Define-Conditions -IncludeApplications "All" -IncludeRoles $AdminRoles -ExcludeGroups @($DefaultExclusion)
Define-Controls -Operator "OR" -BuiltInControls "MFA"
  
#Check if there is a matching policy name already, if so find its ID
$PolicyID = $null
$PolicyID = (Get-AzureADMSConditionalAccessPolicy | Where-Object {$_.DisplayName -eq "$CA101PolicyName"}).ID
#If an ID was found, update the existing policy, otherwise just create a new policy 
If ($PolicyID.length -lt 36)
{ 
  New-AzureADMSConditionalAccessPolicy -DisplayName $CA101PolicyName -State "Disabled" -Conditions $Conditions -GrantControls $Controls
} Else {
  Set-AzureADMSConditionalAccessPolicy -PolicyID $PolicyID -Conditions $Conditions -GrantControls $Controls
}

########################################################
# INTERNAL PERSONA POLICIES:
# These policies target internal users, and always exclude guests and external users

########################################################
## CA201: Require MFA or compliant device for internal users 
## This policy requires Multi-factor Authentication for all users 

Define-Conditions -IncludeApplications "All" -IncludeUsers "All" -ExcludeUsers "GuestsOrExternalUsers" -ExcludeGroups @($DefaultExclusion) -ClientAppTypes @('Browser', 'MobileAppsAndDesktopClients')
Define-Controls -Operator "OR" -BuiltInControls @('MFA', 'CompliantDevice')
  
#Check if there is a matching policy name already, if so find its ID
$PolicyID = $null
$PolicyID = (Get-AzureADMSConditionalAccessPolicy | Where-Object {$_.DisplayName -eq "$CA201PolicyName"}).ID
#If an ID was found, update the existing policy, otherwise just create a new policy 
If ($PolicyID.length -lt 36)
{ 
  New-AzureADMSConditionalAccessPolicy -DisplayName $CA201PolicyName -State "Disabled" -Conditions $Conditions -GrantControls $Controls
} Else {
  Set-AzureADMSConditionalAccessPolicy -PolicyID $PolicyID -Conditions $Conditions -GrantControls $Controls
}

########################################################
## CA202: Securing security info registration
## This policy requires Multi-factor Authentication (e.g. TAP) when registering security information @ https://aka.ms/mysecurityinfo

Define-Conditions -IncludeUserActions "urn:user:registersecurityinfo" -IncludeUsers "All" -ExcludeUsers "GuestsOrExternalUsers" -ExcludeGroups @($DefaultExclusion) -ExcludeRoles "62e90394-69f5-4237-9190-012177145e10" -IncludeLocations "All" -ExcludeLocations "AllTrusted"
Define-Controls -Operator "OR" -BuiltInControls @('MFA')
  
#Check if there is a matching policy name already, if so find its ID
$PolicyID = $null
$PolicyID = (Get-AzureADMSConditionalAccessPolicy | Where-Object {$_.DisplayName -eq "$CA202PolicyName"}).ID
#If an ID was found, update the existing policy, otherwise just create a new policy 
If ($PolicyID.length -lt 36)
{ 
  New-AzureADMSConditionalAccessPolicy -DisplayName $CA202PolicyName -State "Disabled" -Conditions $Conditions -GrantControls $Controls
} Else {
  Set-AzureADMSConditionalAccessPolicy -PolicyID $PolicyID -Conditions $Conditions -GrantControls $Controls
}

########################################################
## CA203: Require MAM or MDM for mobile device access (Office 365)
## This policy enforces either MAM or MDM for iOS and Android devices
## NOTES: 
##     1. End-user must either use approved Microsoft apps (e.g. Outlook, Edge) OR enroll their device using Company Portal (in order to use other apps)
##     2. You must also deploy App protection policies and Compliance policies in Microsoft Endpoint Manager to complete this setup
##     2. Android and iOS users must have the Authenticator app as well as the Company Portal app

Define-Conditions -IncludeApplications "Office365" -IncludeUsers "All" -ExcludeUsers "GuestsOrExternalUsers" -ExcludeGroups @($DefaultExclusion) -IncludePlatforms @('Android', 'IOS')
Define-Controls -Operator "OR" -BuiltInControls @('CompliantDevice', 'ApprovedApplication', 'CompliantApplication')
  
#Check if there is a matching policy name already, if so find its ID
$PolicyID = $null
$PolicyID = (Get-AzureADMSConditionalAccessPolicy | Where-Object {$_.DisplayName -eq "$CA203PolicyName"}).ID
#If an ID was found, update the existing policy, otherwise just create a new policy 
If ($PolicyID.length -lt 36)
{ 
  New-AzureADMSConditionalAccessPolicy -DisplayName $CA203PolicyName -State "Disabled" -Conditions $Conditions -GrantControls $Controls
} Else {
  Set-AzureADMSConditionalAccessPolicy -PolicyID $PolicyID -Conditions $Conditions -GrantControls $Controls
}

########################################################
## CA204: Require managed devices for desktop client access (Office 365)
## This policy enforces device compliance (or Hybrid Azure AD join) for these platforms: Windows, macOS
## NOTES: 
##    1. Azure AD joined or Hybrid Joined devices will be auto-enrolled if configured properly
##    2. Users with personal devices should use the Company Portal app to enroll
##    3. This policy blocks unmanaged device access from desktop client apps (e.g. Outlook, OneDrive, etc.)
##    4. Optionally, you may add 'Browser' to the ClientAppTypes condition if you also want to block web access on unmanaged devices

Define-Conditions -IncludeApplications "Office365" -IncludeUsers "All" -ExcludeUsers "GuestsOrExternalUsers" -ExcludeGroups @($DefaultExclusion) -IncludePlatforms @('Windows', 'macOS') -ClientAppTypes @('MobileAppsAndDesktopClients')
Define-Controls -Operator "OR" -BuiltInControls @('DomainJoinedDevice', 'CompliantDevice')
  
#Check if there is a matching policy name already, if so find its ID
$PolicyID = $null
$PolicyID = (Get-AzureADMSConditionalAccessPolicy | Where-Object {$_.DisplayName -eq "$CA204PolicyName"}).ID
#If an ID was found, update the existing policy, otherwise just create a new policy 
If ($PolicyID.length -lt 36)
{ 
  New-AzureADMSConditionalAccessPolicy -DisplayName $CA204PolicyName -State "Disabled" -Conditions $Conditions -GrantControls $Controls
} Else {
  Set-AzureADMSConditionalAccessPolicy -PolicyID $PolicyID -Conditions $Conditions -GrantControls $Controls
}

########################################################
## CA205: Block access outside NZ & Aus
## This policy blocks access to anything from overseas, unless in the roaming group

Define-Conditions -IncludeApplications "All" -IncludeUsers "All" -ExcludeUsers "GuestsOrExternalUsers" -ExcludeGroups @($RoamingGroup.ObjectId) -IncludeLocations "All" -ExcludeLocations @($NZIPID,$AUIPID)
Define-Controls -Operator "OR" -BuiltInControls "Block"
  
#Check if there is a matching policy name already, if so find its ID
$PolicyID = $null
$PolicyID = (Get-AzureADMSConditionalAccessPolicy | Where-Object {$_.DisplayName -eq "$CA205PolicyName"}).ID
#If an ID was found, update the existing policy, otherwise just create a new policy 
If ($PolicyID.length -lt 36)
{ 
  New-AzureADMSConditionalAccessPolicy -DisplayName $CA205PolicyName -State "Disabled" -Conditions $Conditions -GrantControls $Controls
} Else {
  Set-AzureADMSConditionalAccessPolicy -PolicyID $PolicyID -Conditions $Conditions -GrantControls $Controls
}

########################################################
# EXTERNAL/GUEST PERSONA POLICIES:
# Note: Some orgs prefer to separate personas for External (longer-term) and Guest (shorter-term) access

########################################################
## CA301: Block guest access to unsupported apps
## This policy blocks guest access to all cloud apps except Office 365 

Define-Conditions -IncludeApplications "All" -ExcludeApplications @("Office365") -IncludeUsers "GuestsOrExternalUsers" -ExcludeGroups @($DefaultExclusion)
Define-Controls -Operator "OR" -BuiltInControls "Block"
  
#Check if there is a matching policy name already, if so find its ID
$PolicyID = $null
$PolicyID = (Get-AzureADMSConditionalAccessPolicy | Where-Object {$_.DisplayName -eq "$CA301PolicyName"}).ID
#If an ID was found, update the existing policy, otherwise just create a new policy 
If ($PolicyID.length -lt 36)
{ 
  New-AzureADMSConditionalAccessPolicy -DisplayName $CA301PolicyName -State "Disabled" -Conditions $Conditions -GrantControls $Controls
} Else {
  Set-AzureADMSConditionalAccessPolicy -PolicyID $PolicyID -Conditions $Conditions -GrantControls $Controls
}

########################################################
## CA302: Require MFA for guests and external users
## This policy requires Multi-factor Authentication for guests 
## Note: You should also plan to enable trust for MFA claims coming from outside Azure AD tenants
## Find trust settings under External identities > Cross-tenant access settings > Default settings > Edit inbound defaults > Trust settings

Define-Conditions -IncludeApplications "All" -IncludeUsers "GuestsOrExternalUsers" -ExcludeGroups @($DefaultExclusion)
Define-Controls -Operator "OR" -BuiltInControls "MFA"
  
#Check if there is a matching policy name already, if so find its ID
$PolicyID = $null
$PolicyID = (Get-AzureADMSConditionalAccessPolicy | Where-Object {$_.DisplayName -eq "$CA302PolicyName"}).ID
#If an ID was found, update the existing policy, otherwise just create a new policy 
If ($PolicyID.length -lt 36)
{ 
  New-AzureADMSConditionalAccessPolicy -DisplayName $CA302PolicyName -State "Disabled" -Conditions $Conditions -GrantControls $Controls
} Else {
  Set-AzureADMSConditionalAccessPolicy -PolicyID $PolicyID -Conditions $Conditions -GrantControls $Controls
}

########################################################

Write-Host "Script completed" -ForegroundColor Cyan
