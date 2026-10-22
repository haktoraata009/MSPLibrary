# Connect to Exchange Online
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline


# Define distribution groups
$Groups = @(
    @{ Name = "Contoso South"; Email = "ContosoSouth@contoso.com" }
    @{ Name = "Contoso South All Technical Staff"; Email = "ContosoSouthAllTechnicalStaff@contoso.com" }
    @{ Name = "Blenheim Staff"; Email = "Blenheim@contoso.com" }
    @{ Name = "Christchurch Staff"; Email = "Christchurch@contoso.com" }
    @{ Name = "Client Manager - South"; Email = "clientmanagerssouth@contoso.com" }
    @{ Name = "Cloud Pager - South"; Email = "cloudpager@contoso.com" }
    @{ Name = "Cloud Reporting - South"; Email = "cloudreporting@contoso.com" }
    @{ Name = "Cloud Team - South"; Email = "CloudTeamSouth@contoso.com" }
    @{ Name = "CloudiLO - South"; Email = "cloudilosouth@contoso.com" }
    @{ Name = "Cloud Accounts - South"; Email = "CloudAccountsSouth@contoso.com" }
    @{ Name = "Deliver the Business - South"; Email = "DeliverTheBusiness@contoso.com" }
    @{ Name = "Dispatch - South"; Email = "DispatchSouth@contoso.com" }
    @{ Name = "Dunedin Staff"; Email = "dunedin@contoso.com" }
    @{ Name = "FortinetSupport - South"; Email = "FortinetSupport@contoso.com" }
    @{ Name = "Generate the Business - South"; Email = "GenerateTheBusiness@contoso.com" }
    @{ Name = "Info - South"; Email = "InfoSouth@contoso.com" }
    @{ Name = "Managed Services - South"; Email = "ManagedServicesSouth@contoso.com" }
    @{ Name = "Nelson Staff"; Email = "Nelton@contoso.com" }
    @{ Name = "Payroll - South"; Email = "PayrollSouth@contoso.com" }
    @{ Name = "Queenstown Staff"; Email = "queenstown@contoso.com" }
    @{ Name = "Service Desk - South"; Email = "ServiceDeskSouth@contoso.com" }
    @{ Name = "Signoffs - South"; Email = "SignoffsSouth@contoso.com" }
    @{ Name = "System Architects - South"; Email = "SystemArchitectsSouth@contoso.com" }
    @{ Name = "Wasabi Management - South"; Email = "wasabimanagement@contoso.com" }
)

# Create distribution groups
foreach ($Group in $Groups) {
    Write-Host "Creating distribution group:" $Group.Name

    New-DistributionGroup `
        -Name $Group.Name `
        -DisplayName $Group.Name `
        -PrimarySmtpAddress $Group.Email `
        -Type Distribution `
        -RequireSenderAuthenticationEnabled $true
}

Write-Host "All distribution groups created"
