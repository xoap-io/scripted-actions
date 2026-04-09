<#
.SYNOPSIS
    Create an Azure Log Analytics workspace using the Azure CLI.

.DESCRIPTION
    This script creates an Azure Log Analytics workspace using the Azure CLI.
    Log Analytics workspaces are the central component of Azure Monitor, collecting
    and storing log data from Azure resources, VMs, and other sources.
    The script uses the following Azure CLI command:
    az monitor log-analytics workspace create --resource-group $ResourceGroupName --workspace-name $WorkspaceName

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group where the workspace will be created.

.PARAMETER WorkspaceName
    Defines the name of the Log Analytics workspace.

.PARAMETER Location
    Defines the Azure region where the workspace will be created.

.PARAMETER Sku
    Defines the pricing tier for the workspace.
    Valid values: PerGB2018, Free, Standalone. Default: PerGB2018.

.PARAMETER RetentionDays
    Defines the data retention period in days (30-730). Default: 90.

.EXAMPLE
    .\az-cli-create-log-analytics-workspace.ps1 -ResourceGroupName "rg-monitoring" -WorkspaceName "law-prod-01" -Location "eastus"

.EXAMPLE
    .\az-cli-create-log-analytics-workspace.ps1 -ResourceGroupName "rg-monitoring" -WorkspaceName "law-prod-01" -Location "eastus" -Sku "PerGB2018" -RetentionDays 180

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
    https://learn.microsoft.com/en-us/cli/azure/monitor/log-analytics/workspace

.COMPONENT
    Azure CLI Monitor
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group where the workspace will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Log Analytics workspace")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where the workspace will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "The pricing tier for the workspace: PerGB2018, Free, or Standalone")]
    [ValidateSet('PerGB2018', 'Free', 'Standalone')]
    [string]$Sku = 'PerGB2018',

    [Parameter(Mandatory = $false, HelpMessage = "Data retention period in days (30-730)")]
    [ValidateRange(30, 730)]
    [int]$RetentionDays = 90
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating Log Analytics workspace '$WorkspaceName' in resource group '$ResourceGroupName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Create the Log Analytics workspace
    Write-Host "🔧 Creating workspace '$WorkspaceName' with SKU '$Sku' and $RetentionDays days retention..." -ForegroundColor Cyan
    $workspaceJson = az monitor log-analytics workspace create `
        --resource-group $ResourceGroupName `
        --workspace-name $WorkspaceName `
        --location $Location `
        --sku $Sku `
        --retention-time $RetentionDays `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI log-analytics workspace create command failed with exit code $LASTEXITCODE"
    }

    $workspace = $workspaceJson | ConvertFrom-Json

    Write-Host "`n✅ Log Analytics workspace '$WorkspaceName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   WorkspaceName: $($workspace.name)" -ForegroundColor White
    Write-Host "   WorkspaceId:   $($workspace.id)" -ForegroundColor White
    Write-Host "   CustomerId:    $($workspace.customerId)" -ForegroundColor White
    Write-Host "   Location:      $($workspace.location)" -ForegroundColor White
    Write-Host "   Sku:           $($workspace.sku.name)" -ForegroundColor White
    Write-Host "   RetentionDays: $($workspace.retentionInDays)" -ForegroundColor White
    Write-Host "   ProvisioningState: $($workspace.provisioningState)" -ForegroundColor White

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - Connect VMs:       az vm extension set --workspace-id $($workspace.customerId)" -ForegroundColor White
    Write-Host "   - Create alerts:     Use az-cli-create-monitor-alert.ps1" -ForegroundColor White
    Write-Host "   - Configure diag:    Use az-cli-create-diagnostic-setting.ps1 with WorkspaceId $($workspace.id)" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
