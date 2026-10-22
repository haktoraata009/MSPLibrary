Function UpdateRegistryProperty
{
  param(
    [Parameter(Mandatory=$true)]
    [string]
    # The path to the registry key where the value should be set.
    $Key,

    [Parameter(Mandatory=$true)]
    [string]
    # The name of the property being set.
    $PropertyName,
    
    [Parameter(Mandatory=$true)]
    [string]
    # The name of the property being set.
    $PropertyType,
    
    [Parameter(Mandatory=$true)]
    [string]
    # The data of the property being set.
    $PropertyData
  )
  
  # Check if the registry property exists
  If ((Get-Item -Path $Key).GetValue($PropertyName) -eq $null)
  {
    # Create registry property if does not exist
    New-ItemProperty -Path $Key -Name $PropertyName -PropertyType $PropertyType -Value $PropertyData
  }
  Else 
  {
    # Update registry propery if does exist
    Set-ItemProperty -Path $Key -Name $PropertyName -Type $PropertyType -Value $PropertyData
  }
}

UpdateRegistryProperty -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\NetLogon\Parameters' -PropertyName 'NegativeCachePeriod' -PropertyType 'DWord' -PropertyData '0'
UpdateRegistryProperty -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -PropertyName 'MaxNegativeCacheTtl' -PropertyType 'DWord' -PropertyData '0'
UpdateRegistryProperty -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters' -PropertyName 'AlwaysExpectDomainController' -PropertyType 'DWord' -PropertyData '1'
