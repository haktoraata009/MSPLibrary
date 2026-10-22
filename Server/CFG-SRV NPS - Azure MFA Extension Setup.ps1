$licenseRequirment="The NPS extension for Azure MFA is available to customers with licenses for Azure Multi-Factor Authentication which are included in Azure AD Premium, Enterprise Management Suite (EMS), or an MFA subscription. The consumption-based licenses for Azure MFA, such as Per User or Per Authentication licenses, are not compatible with the NPS Extension."

$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()

if(!(New-Object Security.Principal.WindowsPrincipal $currentUser).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)){
	Write-Error ("Please run the configuration script as administrator")
	exit
}

Install-Module -Name "Microsoft.Graph" -verbose -ErrorAction Stop

Write-Host "Connecting to Microsoft Azure.  Please sign on as a tenant administrator."
Connect-MgGraph -Scopes Application.ReadWrite.All -NoWelcome -Verbose -ErrorAction Stop

$appPrincipalId="981f26a1-7f43-403b-a875-f8b09b8cd720"
$user='NETWORK SERVICE'
$permission='Read'

function errorOut( $errorMsg){
	if($errorMsg.Count){
	  Write-Error ("Configuration Script exiting with error: " + $errorMsg.join)
	  exit
	}
}

function cleanUpAndErrorOut( $errorMsg, $thumbprint ){
    if($errorMsg.Count){
      Get-Item Cert:\LocalMachine\My\$thumbprint | Remove-Item
	  Write-Error ("Configuration Script exiting with error: " + $errorMsg.join)
	  Write-Host $licenseRequirment
	  exit
	}
}

Write-Host "Starting Azure MFA NPS Extension Configuration Script"

$tenantId=Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\AzureMfa\" -Name "TENANT_ID" -ErrorAction 'SilentlyContinue'

if(!$tenantId){
    $tenantId=Read-Host -Prompt 'Provide your Tenant ID For Self-Signed Certificate Creation'
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\AzureMfa\" -Name "TENANT_ID" -VALUE $tenantId
}else{
    $tenantId=$tenantId.TENANT_ID
    Write-Host (" Tenant ID currently registered with Azure MFA NPS Extension is: " + $tenantId )
    [string] $newTenantId=Read-Host -Prompt 'Enter new Tenant ID to change or press Enter to keep the current value'
    if(![string]::IsNullOrEmpty($newTenantId)){
        $tenantId=$newTenantId
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\AzureMfa\" -Name "TENANT_ID" -VALUE $tenantId
        Write-Host (" Updated Tenant ID registered with Azure MFA NPS Extension to: " + $tenantId )
    }
}

Import-Module -Name $env:ProgramFiles\WindowsPowerShell\Modules\AzureMfaClientCertProvider -ErrorVariable errorMsg -ErrorAction Stop

Write-Host ("Generating client certificate")
New-AzureMfaTenantCertificate -TenantId $tenantId -OutVariable certX509 -ErrorVariable errorMsg
errorOut $errorMsg

$subject=$certX509[0].Subject

Write-Host "Client Certificate successfully generated"

$binCert = $certx509[0].GetRawCertData()
$credValue = [System.Convert]::ToBase64String($binCert)

$servicePrincipalId = (Get-MgServicePrincipal -Filter "appid eq '981f26a1-7f43-403b-a875-f8b09b8cd720'").Id
$keyCredentials = (Get-MgServicePrincipal -Filter "appid eq '981f26a1-7f43-403b-a875-f8b09b8cd720'").KeyCredentials
$newKey = @(@{
	CustomKeyIdentifier = $null
	DisplayName = $subject
	EndDateTime = $null
	Key = $binCert
	KeyId = [guid]::NewGuid()
	StartDateTime = $null
	Type = "AsymmetricX509Cert"
	Usage = "Verify"
	AdditionalProperties = $null
})
$keyCredentials += $newKey
Update-MgServicePrincipal -ServicePrincipalId $servicePrincipalId -KeyCredentials $keyCredentials -Verbose -ErrorVariable errorMsg -OutVariable result
cleanUpAndErrorOut $errorMsg $certX509[0].Thumbprint

Write-Host ("Client Certificate associated with Service Principal: " + $appPrincipalId)


Write-Host ("Starting registry updates")

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\AzureMfa\" -Name "CLIENT_CERT_IDENTIFIER" -VALUE $subject
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\AzureMfa\" -Name "TENANT_ID" -VALUE $tenantId

Write-Host ("Completed registry updates")

Write-Host ("Client certificate : " + $subject + " successfully associated with Azure MFA NPS Extension for Tenant ID: " + $tenantId )


try
{
	# Get Location of the machine related keys
	$keyPath = $env:ProgramData + "\Microsoft\Crypto\RSA\MachineKeys\"; 
	$keyName = $certX509[0].PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName;
	$keyFullPath = $keyPath + $keyName;
	#Get the current access levels and update it
	$acl = (Get-Item $keyFullPath).GetAccessControl('Access') 
	$buildAcl = New-Object  System.Security.AccessControl.FileSystemAccessRule($user,$permission,"Allow") 
	$acl.SetAccessRule($buildAcl) #Add Access Rule

	Write-Host "Granting certificate private key access to $user"
	Set-Acl $keyFullPath $acl #Save Access Rules
	
	Write-Host "Successfully granted to $user"
}
catch
{
	Write-Host "Unable to grant certificate private key access to $user. Please grant access manually." 
	throw $_;
}

Write-Host ("Restarting Network Policy Server (ias) service")
Restart-Service -Force ias

Read-Host -Prompt 'Configuration complete.  Press Enter to continue...'