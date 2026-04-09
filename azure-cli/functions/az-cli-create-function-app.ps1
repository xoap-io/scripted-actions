<#
.SYNOPSIS
    Create an Azure Function App using Azure CLI.

.DESCRIPTION
    This script creates an Azure Function App in a specified resource group using the
    Azure CLI. It requires an existing storage account and supports configuring the
    runtime, OS type, functions version, and optional hosting plan.
    The script uses the following Azure CLI command:
    az functionapp create --name $FunctionAppName --resource-group $ResourceGroupName --storage-account $StorageAccountName

.PARAMETER FunctionAppName
    The globally unique name for the Azure Function App.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group where the Function App will be created.

.PARAMETER StorageAccountName
    The name of the existing Azure Storage Account to use for the Function App.

.PARAMETER Runtime
    The language runtime stack for the Function App. Accepted values: dotnet,
    dotnet-isolated, node, python, java, powershell.

.PARAMETER RuntimeVersion
    The version of the runtime stack (e.g. '4.0' for dotnet, '20' for node,
    '3.11' for python). Leave unset to use the default for the selected runtime.

.PARAMETER FunctionsVersion
    The Azure Functions runtime version. Defaults to 4.

.PARAMETER OsType
    The operating system for the Function App host. Accepted values: 'Windows',
    'Linux'. Defaults to 'Linux'.

.PARAMETER PlanName
    The name of an existing App Service or Elastic Premium plan. If omitted,
    a Consumption (serverless) plan is used automatically.

.PARAMETER Location
    The Azure region for the Function App. If omitted, the resource group's
    location is used.

.PARAMETER Tags
    Space-separated tags in 'key=value' format to apply to the Function App resource.

.EXAMPLE
    .\az-cli-create-function-app.ps1 -FunctionAppName "func-myapp-prod" -ResourceGroupName "rg-functions" -StorageAccountName "stmyappprod" -Runtime "python"

.EXAMPLE
    .\az-cli-create-function-app.ps1 -FunctionAppName "func-myapp-prod" -ResourceGroupName "rg-functions" -StorageAccountName "stmyappprod" -Runtime "node" -RuntimeVersion "20" -OsType "Linux" -Location "eastus" -Tags "env=prod team=backend"

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
    https://learn.microsoft.com/en-us/cli/azure/functionapp

.COMPONENT
    Azure CLI Functions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The globally unique name for the Azure Function App.")]
    [ValidateNotNullOrEmpty()]
    [string]$FunctionAppName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group where the Function App will be created.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the existing Azure Storage Account to use for the Function App.")]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true, HelpMessage = "The language runtime stack (dotnet, dotnet-isolated, node, python, java, powershell).")]
    [ValidateSet('dotnet', 'dotnet-isolated', 'node', 'python', 'java', 'powershell')]
    [string]$Runtime,

    [Parameter(Mandatory = $false, HelpMessage = "The version of the runtime stack (e.g. '4.0', '20', '3.11').")]
    [ValidateNotNullOrEmpty()]
    [string]$RuntimeVersion,

    [Parameter(Mandatory = $false, HelpMessage = "The Azure Functions runtime version. Defaults to 4.")]
    [ValidateRange(4, 4)]
    [int]$FunctionsVersion = 4,

    [Parameter(Mandatory = $false, HelpMessage = "The operating system for the Function App host. Accepted values: Windows, Linux. Defaults to 'Linux'.")]
    [ValidateSet('Windows', 'Linux')]
    [string]$OsType = 'Linux',

    [Parameter(Mandatory = $false, HelpMessage = "The name of an existing App Service or Elastic Premium plan. If omitted, a Consumption plan is used.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanName,

    [Parameter(Mandatory = $false, HelpMessage = "The Azure region for the Function App. If omitted, the resource group location is used.")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "Space-separated tags in 'key=value' format to apply to the Function App resource.")]
    [ValidateNotNullOrEmpty()]
    [string]$Tags
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating Azure Function App '$FunctionAppName'..." -ForegroundColor Green

    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    Write-Host "🔍 Validating resource group '$ResourceGroupName'..." -ForegroundColor Cyan

    $rgExists = az group show --name $ResourceGroupName --query "name" --output tsv 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $rgExists) {
        throw "Resource group '$ResourceGroupName' not found. Please create it before running this script."
    }

    Write-Host "🔍 Validating storage account '$StorageAccountName'..." -ForegroundColor Cyan

    $saExists = az storage account show --name $StorageAccountName --resource-group $ResourceGroupName --query "name" --output tsv 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $saExists) {
        throw "Storage account '$StorageAccountName' not found in resource group '$ResourceGroupName'."
    }

    Write-Host "🔧 Running az functionapp create..." -ForegroundColor Cyan

    $createArgs = @(
        'functionapp', 'create',
        '--name', $FunctionAppName,
        '--resource-group', $ResourceGroupName,
        '--storage-account', $StorageAccountName,
        '--runtime', $Runtime,
        '--functions-version', $FunctionsVersion,
        '--os-type', $OsType,
        '--output', 'json'
    )

    if ($RuntimeVersion) {
        $createArgs += '--runtime-version'
        $createArgs += $RuntimeVersion
    }

    if ($PlanName) {
        $createArgs += '--plan'
        $createArgs += $PlanName
    }
    else {
        $createArgs += '--consumption-plan-location'
        $createArgs += $(if ($Location) { $Location } else {
            az group show --name $ResourceGroupName --query "location" --output tsv
        })
    }

    if ($Location -and $PlanName) {
        $createArgs += '--location'
        $createArgs += $Location
    }

    if ($Tags) {
        $createArgs += '--tags'
        $createArgs += $Tags
    }

    $appJson = az @createArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI functionapp create command failed with exit code $LASTEXITCODE"
    }

    $app = $appJson | ConvertFrom-Json

    Write-Host "`n✅ Azure Function App '$FunctionAppName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   App Name:         $($app.name)" -ForegroundColor White
    Write-Host "   Default Hostname: $($app.defaultHostName)" -ForegroundColor White
    Write-Host "   State:            $($app.state)" -ForegroundColor White
    Write-Host "   Runtime:          $Runtime" -ForegroundColor White
    Write-Host "   OS Type:          $OsType" -ForegroundColor White
    Write-Host "   Functions Version: $FunctionsVersion" -ForegroundColor White

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - Deploy code: func azure functionapp publish $FunctionAppName" -ForegroundColor White
    Write-Host "   - Open in portal: az functionapp browse --name $FunctionAppName --resource-group $ResourceGroupName" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
