<#
.SYNOPSIS
    Create an Azure SQL Database on an existing logical server using Azure CLI.

.DESCRIPTION
    This script creates an Azure SQL Database on an existing Azure SQL logical server
    using the Azure CLI. It supports configuring the service objective (SKU), maximum
    database size, zone redundancy, and backup storage redundancy.
    The script uses the following Azure CLI command:
    az sql db create --server $ServerName --resource-group $ResourceGroupName --name $DatabaseName

.PARAMETER ServerName
    The name of the existing Azure SQL logical server on which to create the database.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group that contains the SQL server.

.PARAMETER DatabaseName
    The name of the Azure SQL Database to create.

.PARAMETER ServiceObjective
    The service objective (SKU) for the database. Examples: GP_Gen5_2, BC_Gen5_4, Basic,
    Standard, Premium. Defaults to 'GP_Gen5_2'.

.PARAMETER MaxSize
    The maximum size of the database. Examples: 32GB, 100GB, 1TB. Defaults to '32GB'.

.PARAMETER ZoneRedundant
    If specified, enables zone redundancy for the database.

.PARAMETER BackupStorageRedundancy
    The backup storage redundancy for the database. Accepted values: 'Local', 'Zone', 'Geo'.
    Defaults to 'Geo'.

.PARAMETER Tags
    Space-separated tags in 'key=value' format to apply to the database resource.

.EXAMPLE
    .\az-cli-create-sql-database.ps1 -ServerName "sql-prod-eastus-01" -ResourceGroupName "rg-databases" -DatabaseName "db-app-prod"

.EXAMPLE
    .\az-cli-create-sql-database.ps1 -ServerName "sql-prod-eastus-01" -ResourceGroupName "rg-databases" -DatabaseName "db-app-prod" -ServiceObjective "GP_Gen5_4" -MaxSize "64GB" -ZoneRedundant -BackupStorageRedundancy "Zone" -Tags "env=prod team=data"

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
    https://learn.microsoft.com/en-us/cli/azure/sql/db

.COMPONENT
    Azure CLI SQL Database
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the existing Azure SQL logical server.")]
    [ValidateNotNullOrEmpty()]
    [string]$ServerName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group that contains the SQL server.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure SQL Database to create.")]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false, HelpMessage = "The service objective (SKU) for the database. Examples: GP_Gen5_2, BC_Gen5_4, Basic, Standard, Premium. Defaults to 'GP_Gen5_2'.")]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceObjective = 'GP_Gen5_2',

    [Parameter(Mandatory = $false, HelpMessage = "The maximum size of the database. Examples: 32GB, 100GB, 1TB. Defaults to '32GB'.")]
    [ValidateNotNullOrEmpty()]
    [string]$MaxSize = '32GB',

    [Parameter(Mandatory = $false, HelpMessage = "Enable zone redundancy for the database.")]
    [switch]$ZoneRedundant,

    [Parameter(Mandatory = $false, HelpMessage = "The backup storage redundancy. Accepted values: Local, Zone, Geo. Defaults to 'Geo'.")]
    [ValidateSet('Local', 'Zone', 'Geo')]
    [string]$BackupStorageRedundancy = 'Geo',

    [Parameter(Mandatory = $false, HelpMessage = "Space-separated tags in 'key=value' format to apply to the database resource.")]
    [ValidateNotNullOrEmpty()]
    [string]$Tags
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating Azure SQL Database '$DatabaseName' on server '$ServerName'..." -ForegroundColor Green

    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    Write-Host "🔍 Validating SQL server '$ServerName' exists..." -ForegroundColor Cyan

    $serverExists = az sql server show --name $ServerName --resource-group $ResourceGroupName --query "name" --output tsv 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $serverExists) {
        throw "SQL server '$ServerName' not found in resource group '$ResourceGroupName'."
    }

    Write-Host "🔧 Running az sql db create..." -ForegroundColor Cyan

    $createArgs = @(
        'sql', 'db', 'create',
        '--server', $ServerName,
        '--resource-group', $ResourceGroupName,
        '--name', $DatabaseName,
        '--service-objective', $ServiceObjective,
        '--max-size', $MaxSize,
        '--backup-storage-redundancy', $BackupStorageRedundancy,
        '--output', 'json'
    )

    if ($ZoneRedundant) {
        $createArgs += '--zone-redundant'
        $createArgs += 'true'
    }

    if ($Tags) {
        $createArgs += '--tags'
        $createArgs += $Tags
    }

    $dbJson = az @createArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI sql db create command failed with exit code $LASTEXITCODE"
    }

    $db = $dbJson | ConvertFrom-Json

    Write-Host "`n✅ Azure SQL Database '$DatabaseName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Database Name:      $($db.name)" -ForegroundColor White
    Write-Host "   Server:             $($db.serverName)" -ForegroundColor White
    Write-Host "   Status:             $($db.status)" -ForegroundColor White
    Write-Host "   Service Objective:  $($db.currentServiceObjectiveName)" -ForegroundColor White
    Write-Host "   Max Size (bytes):   $($db.maxSizeBytes)" -ForegroundColor White
    Write-Host "   Zone Redundant:     $($db.zoneRedundant)" -ForegroundColor White
    Write-Host "   Backup Redundancy:  $BackupStorageRedundancy" -ForegroundColor White

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - Connect using: Server=$($ServerName).database.windows.net; Database=$DatabaseName" -ForegroundColor White
    Write-Host "   - Configure firewall rules on the server to allow client connections." -ForegroundColor White
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
