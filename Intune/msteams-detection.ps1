$Results = Get-ChildItem "C:\Program Files\WindowsApps\" | Where-Object{ $_.Name -Like 'MSTeams*'}
if ($results.length -gt 0){Return 0} else {Return 1}