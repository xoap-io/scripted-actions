<#
.SYNOPSIS
    Create an Azure SQL logical server using Azure CLI.

.DESCRIPTION
    This script creates an Azure SQL logical server in a specified resource group and
    location using the Azure CLI. It configures the admin login, password, TLS version,
    and public network access policy.
    The script uses the following Azure CLI command:
    az sql server create --name $ServerName --resource-group $ResourceGroupName --location $Location

.PARAMETER ServerName
    The globally unique name for the Azure SQL logical server. Must match the pattern
    '^[a-z][a-z0-9-]{0,61}[a-z0-9]$'.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group where the SQL server will be created.

.PARAMETER Location
    The Azure region where the SQL server will be created (e.g. eastus, westeurope).

.PARAMETER AdminLogin
    The administrator username for the SQL server.

.PARAMETER AdminPassword
    The administrator password for the SQL server.

.PARAMETER MinimalTlsVersion
    The minimum TLS version enforced by the server. Accepted values: '1.0', '1.1', '1.2'.
    Defaults to '1.2'.

.PARAMETER PublicNetworkAccess
    Whether public network access is enabled or disabled. Accepted values: 'Enabled',
    'Disabled'. Defaults to 'Disabled'.

.PARAMETER Tags
    Space-separated tags in 'key=value' format to apply to the SQL server resource.

.EXAMPLE
    .\az-cli-create-sql-server.ps1 -ServerName "sql-prod-eastus-01" -ResourceGroupName "rg-databases" -Location "eastus" -AdminLogin "sqladmin" -AdminPassword "P@ssw0rd1234!"

.EXAMPLE
    .\az-cli-create-sql-server.ps1 -ServerName "sql-prod-eastus-01" -ResourceGroupName "rg-databases" -Location "eastus" -AdminLogin "sqladmin" -AdminPassword "P@ssw0rd1234!" -MinimalTlsVersion "1.2" -PublicNetworkAccess "Disabled" -Tags "env=prod team=data"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/sql/server

.COMPONENT
    Azure CLI SQL Database
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The globally unique name for the Azure SQL logical server.")]
    [ValidatePattern('^[a-z][a-z0-9-]{0,61}[a-z0-9]$')]
    [string]$ServerName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group where the SQL server will be created.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where the SQL server will be created (e.g. eastus, westeurope).")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $true, HelpMessage = "The administrator username for the SQL server.")]
    [ValidateNotNullOrEmpty()]
    [string]$AdminLogin,

    [Parameter(Mandatory = $true, HelpMessage = "The administrator password for the SQL server.")]
    [ValidateNotNullOrEmpty()]
    [string]$AdminPassword,

    [Parameter(Mandatory = $false, HelpMessage = "The minimum TLS version enforced by the server. Accepted values: 1.0, 1.1, 1.2. Defaults to 1.2.")]
    [ValidateSet('1.0', '1.1', '1.2')]
    [string]$MinimalTlsVersion = '1.2',

    [Parameter(Mandatory = $false, HelpMessage = "Whether public network access is enabled or disabled. Defaults to 'Disabled'.")]
    [ValidateSet('Enabled', 'Disabled')]
    [string]$PublicNetworkAccess = 'Disabled',

    [Parameter(Mandatory = $false, HelpMessage = "Space-separated tags in 'key=value' format to apply to the SQL server resource.")]
    [ValidateNotNullOrEmpty()]
    [string]$Tags
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating Azure SQL logical server '$ServerName'..." -ForegroundColor Green

    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    Write-Host "🔍 Validating resource group '$ResourceGroupName'..." -ForegroundColor Cyan

    $rgExists = az group show --name $ResourceGroupName --query "name" --output tsv 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $rgExists) {
        throw "Resource group '$ResourceGroupName' not found. Please create it before running this script."
    }

    Write-Host "🔧 Running az sql server create..." -ForegroundColor Cyan

    $createArgs = @(
        'sql', 'server', 'create',
        '--name', $ServerName,
        '--resource-group', $ResourceGroupName,
        '--location', $Location,
        '--admin-user', $AdminLogin,
        '--admin-password', $AdminPassword,
        '--minimal-tls-version', $MinimalTlsVersion,
        '--enable-public-network', $(if ($PublicNetworkAccess -eq 'Enabled') { 'true' } else { 'false' }),
        '--output', 'json'
    )

    if ($Tags) {
        $createArgs += '--tags'
        $createArgs += $Tags
    }

    $serverJson = az @createArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI sql server create command failed with exit code $LASTEXITCODE"
    }

    $server = $serverJson | ConvertFrom-Json

    Write-Host "`n✅ Azure SQL logical server '$ServerName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Server Name:   $($server.name)" -ForegroundColor White
    Write-Host "   FQDN:          $($server.fullyQualifiedDomainName)" -ForegroundColor White
    Write-Host "   State:         $($server.state)" -ForegroundColor White
    Write-Host "   Admin Login:   $($server.administratorLogin)" -ForegroundColor White
    Write-Host "   TLS Version:   $($server.minimalTlsVersion)" -ForegroundColor White
    Write-Host "   Public Access: $PublicNetworkAccess" -ForegroundColor White

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - Create a database: az sql db create --server $ServerName --resource-group $ResourceGroupName --name <db-name>" -ForegroundColor White
    Write-Host "   - Configure firewall rules to allow connections to FQDN: $($server.fullyQualifiedDomainName)" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
