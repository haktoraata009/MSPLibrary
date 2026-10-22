#Get the on-prem AD Object ID (ImmutableID)
[system.convert]::ToBase64String(([guid](get-aduser -identity rh).objectguid).ToByteArray())

#Force linking the AAD Object to the on-prem AD object 
Set-AzureADUser -ObjectID user1@contoso.com -ImmutableID '<ImmutableID>'

#Change User O365 username
Set-MsolUserPrincipalName -UserPrincipalName user2@contoso.onmicrosoft.com -NewUserPrincipalName user2@contoso.com