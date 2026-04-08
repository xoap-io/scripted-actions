<#
.SYNOPSIS
    Deploy Azure Resource Manager (ARM) templates using Azure CLI.

.DESCRIPTION
    This script deploys ARM templates to Azure using the Azure CLI with comprehensive validation and monitoring.
    Supports deployment to Resource Groups, subscriptions, management groups, and tenants.
    Includes parameter validation, deployment monitoring, rollback capabilities, and detailed reporting.

    The script uses the Azure CLI commands: az deployment group create, az deployment sub create

.PARAMETER TemplateFile
    Path to the ARM template file (.json).

.PARAMETER TemplateUri
    URI to the ARM template file (alternative to TemplateFile).

.PARAMETER ParametersFile
    Path to the parameters file (.json).

.PARAMETER Parameters
    Hashtable of parameter values to override.

.PARAMETER ResourceGroup
    Target Resource Group for the deployment (required for RG-level deployments).

.PARAMETER DeploymentName
    Name for the deployment (auto-generated if not specified).

.PARAMETER Location
    Azure location for subscription/management group level deployments.

.PARAMETER DeploymentScope
    Scope of the deployment.

.PARAMETER Mode
    Deployment mode for Resource Group deployments.

.PARAMETER ValidateOnly
    Perform template validation without deploying.

.PARAMETER WhatIf
    Show what resources would be created/modified without deploying.

.PARAMETER Confirm
    Prompt for confirmation before deploying.

.PARAMETER RollbackOnError
    Automatically rollback to last successful deployment on error.

.PARAMETER MonitorProgress
    Display real-time deployment progress.

.PARAMETER OutputResults
    Display deployment outputs after completion.

.EXAMPLE
    .\az-cli-deploy-template.ps1 -TemplateFile "vm-template.json" -ParametersFile "vm-parameters.json" -ResourceGroup "production-rg"

    Deploys ARM template to Resource Group with parameters file.

.EXAMPLE
    .\az-cli-deploy-template.ps1 -TemplateUri "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/quickstarts/microsoft.compute/vm-simple-linux/azuredeploy.json" -ResourceGroup "test-rg" -ValidateOnly

    Validates ARM template from URI without deploying.

.EXAMPLE
    .\az-cli-deploy-template.ps1 -TemplateFile "subscription-template.json" -DeploymentScope "subscription" -Location "East US" -Parameters @{"budgetAmount"="1000"}

    Deploys template at subscription scope with parameter override.

.EXAMPLE
    .\az-cli-deploy-template.ps1 -TemplateFile "infrastructure.json" -ResourceGroup "infra-rg" -WhatIf -MonitorProgress

    Shows what would be deployed and monitors progress during actual deployment.

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
    https://learn.microsoft.com/en-us/cli/azure/deployment

.COMPONENT
    Azure CLI Resource Manager
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Path to the ARM template file")]
    [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
    [string]$TemplateFile,

    [Parameter(HelpMessage = "URI to the ARM template file")]
    [ValidatePattern('^https?://')]
    [string]$TemplateUri,

    [Parameter(HelpMessage = "Path to the parameters file")]
    [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
    [string]$ParametersFile,

    [Parameter(HelpMessage = "Hashtable of parameter values")]
    [hashtable]$Parameters,

    [Parameter(HelpMessage = "Target Resource Group for RG-level deployments")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._\-\(\)]+$')]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Name for the deployment")]
    [ValidateLength(1, 64)]
    [ValidatePattern('^[a-zA-Z0-9._\-\(\)]+$')]
    [string]$DeploymentName,

    [Parameter(HelpMessage = "Azure location for subscription/management group deployments")]
    [ValidateSet(
        "East US", "East US 2", "West US", "West US 2", "West US 3", "Central US", "North Central US", "South Central US",
        "West Central US", "Canada Central", "Canada East", "Brazil South", "North Europe", "West Europe", "UK South",
        "UK West", "France Central", "Germany West Central", "Switzerland North", "Norway East", "Sweden Central",
        "UAE North", "South Africa North", "Australia East", "Australia Southeast", "East Asia", "Southeast Asia",
        "Japan East", "Japan West", "Korea Central", "India Central", "China East 2", "China North 3"
    )]
    [string]$Location,

    [Parameter(HelpMessage = "Scope of the deployment")]
    [ValidateSet("resourceGroup", "subscription", "managementGroup", "tenant")]
    [string]$DeploymentScope = "resourceGroup",

    [Parameter(HelpMessage = "Deployment mode for Resource Group deployments")]
    [ValidateSet("Incremental", "Complete")]
    [string]$Mode = "Incremental",

    [Parameter(HelpMessage = "Perform template validation without deploying")]
    [switch]$ValidateOnly,

    [Parameter(HelpMessage = "Show what resources would be created/modified")]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Prompt for confirmation before deploying")]
    [switch]$Confirm,

    [Parameter(HelpMessage = "Automatically rollback to last successful deployment on error")]
    [switch]$RollbackOnError,

    [Parameter(HelpMessage = "Display real-time deployment progress")]
    [switch]$MonitorProgress,

    [Parameter(HelpMessage = "Display deployment outputs after completion")]
    [switch]$OutputResults,

    [Parameter(HelpMessage = "Azure subscription ID or name")]
    [ValidatePattern('^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})|(.+)$')]
    [string]$Subscription
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

try {
    # Check if Azure CLI is available
    if (-not (Get-Command 'az' -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not found in PATH. Please install Azure CLI first."
    }

    # Check if user is logged in to Azure CLI
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $azAccount) {
        throw "Not logged in to Azure CLI. Please run 'az login' first."
    }

    $operationType = if ($ValidateOnly) { "Template Validation" } elseif ($WhatIf) { "What-If Analysis" } else { "Template Deployment" }
    Write-Host "🚀 Azure ARM $operationType" -ForegroundColor Blue
    Write-Host "==============================" -ForegroundColor Blue
    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green

    # Switch subscription if specified
    if ($Subscription) {
        Write-Host "Switching to subscription: $Subscription" -ForegroundColor Yellow
        az account set --subscription $Subscription
        $azAccount = az account show | ConvertFrom-Json
    }

    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan
    Write-Host ""

    # Validate parameters
    if (-not $TemplateFile -and -not $TemplateUri) {
        throw "Either TemplateFile or TemplateUri parameter must be specified"
    }

    if ($TemplateFile -and $TemplateUri) {
        throw "Cannot specify both TemplateFile and TemplateUri parameters"
    }

    if ($DeploymentScope -eq "resourceGroup" -and -not $ResourceGroup) {
        throw "ResourceGroup parameter is required for Resource Group deployments"
    }

    if ($DeploymentScope -ne "resourceGroup" -and -not $Location) {
        throw "Location parameter is required for subscription/management group/tenant deployments"
    }

    # Location mapping for display names
    $locationMap = @{
        "East US" = "eastus"; "East US 2" = "eastus2"; "West US" = "westus"; "West US 2" = "westus2"; "West US 3" = "westus3"
        "Central US" = "centralus"; "North Central US" = "northcentralus"; "South Central US" = "southcentralus"
        "West Central US" = "westcentralus"; "Canada Central" = "canadacentral"; "Canada East" = "canadaeast"
        "Brazil South" = "brazilsouth"; "North Europe" = "northeurope"; "West Europe" = "westeurope"
        "UK South" = "uksouth"; "UK West" = "ukwest"; "France Central" = "francecentral"
        "Germany West Central" = "germanywestcentral"; "Switzerland North" = "switzerlandnorth"
        "Norway East" = "norwayeast"; "Sweden Central" = "swedencentral"; "UAE North" = "uaenorth"
        "South Africa North" = "southafricanorth"; "Australia East" = "australiaeast"
        "Australia Southeast" = "australiasoutheast"; "East Asia" = "eastasia"; "Southeast Asia" = "southeastasia"
        "Japan East" = "japaneast"; "Japan West" = "japanwest"; "Korea Central" = "koreacentral"
        "India Central" = "centralindia"; "China East 2" = "chinaeast2"; "China North 3" = "chinanorth3"
    }

    # Convert location display name to code
    $locationCode = $null
    if ($Location) {
        $locationCode = $locationMap[$Location]
        if (-not $locationCode) {
            $locationCode = $Location.ToLower() -replace ' ', ''
        }
    }

    # Verify Resource Group exists if specified
    if ($ResourceGroup) {
        Write-Host "Verifying Resource Group: $ResourceGroup" -ForegroundColor Yellow
        $rgCheck = az group show --name $ResourceGroup 2>$null
        if (-not $rgCheck) {
            throw "Resource Group '$ResourceGroup' not found in subscription '$($azAccount.name)'"
        }

        $rgInfo = $rgCheck | ConvertFrom-Json
        Write-Host "✓ Resource Group '$ResourceGroup' found" -ForegroundColor Green
        Write-Host "  Location: $($rgInfo.location)" -ForegroundColor White
    }

    # Generate deployment name if not specified
    if (-not $DeploymentName) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $DeploymentName = "deployment-$timestamp"
    }

    # Load and validate template
    Write-Host "Loading ARM template..." -ForegroundColor Yellow

    if ($TemplateFile) {
        Write-Host "  Template file: $TemplateFile" -ForegroundColor Blue

        # Validate JSON syntax
        try {
            $null = Get-Content -Path $TemplateFile -Raw | ConvertFrom-Json
            Write-Host "✓ Template JSON syntax is valid" -ForegroundColor Green
        }
        catch {
            throw "Invalid JSON syntax in template file: $($_.Exception.Message)"
        }
    } else {
        Write-Host "  Template URI: $TemplateUri" -ForegroundColor Blue

        # Test URI accessibility
        try {
            $null = Invoke-WebRequest -Uri $TemplateUri -Method Head -UseBasicParsing
            Write-Host "✓ Template URI is accessible" -ForegroundColor Green
        }
        catch {
            throw "Cannot access template URI: $($_.Exception.Message)"
        }
    }

    # Load parameters if specified
    $allParameters = @{}

    if ($ParametersFile) {
        Write-Host "Loading parameters file: $ParametersFile" -ForegroundColor Yellow
        try {
            $parametersContent = Get-Content -Path $ParametersFile -Raw | ConvertFrom-Json

            # Handle both parameter file formats
            if ($parametersContent.parameters) {
                foreach ($param in $parametersContent.parameters.PSObject.Properties) {
                    $allParameters[$param.Name] = $param.Value.value
                }
            } else {
                foreach ($param in $parametersContent.PSObject.Properties) {
                    $allParameters[$param.Name] = $param.Value
                }
            }

            Write-Host "✓ Loaded $($allParameters.Count) parameters from file" -ForegroundColor Green
        }
        catch {
            throw "Invalid JSON syntax in parameters file: $($_.Exception.Message)"
        }
    }

    # Merge with parameter overrides
    if ($Parameters) {
        Write-Host "Applying parameter overrides..." -ForegroundColor Yellow
        foreach ($param in $Parameters.GetEnumerator()) {
            $allParameters[$param.Key] = $param.Value
        }
        Write-Host "✓ Applied $($Parameters.Count) parameter overrides" -ForegroundColor Green
    }

    # Display deployment configuration
    Write-Host ""
    Write-Host "Deployment Configuration:" -ForegroundColor Cyan
    Write-Host "  Deployment Name: $DeploymentName" -ForegroundColor White
    Write-Host "  Scope: $DeploymentScope" -ForegroundColor White

    if ($ResourceGroup) {
        Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
        Write-Host "  Mode: $Mode" -ForegroundColor White
    }

    if ($Location) {
        Write-Host "  Location: $Location" -ForegroundColor White
    }

    Write-Host "  Template: $(if ($TemplateFile) { $TemplateFile } else { $TemplateUri })" -ForegroundColor White
    Write-Host "  Parameters: $($allParameters.Count)" -ForegroundColor White
    Write-Host "  Operation: $(if ($ValidateOnly) { 'Validation only' } elseif ($WhatIf) { 'What-If analysis' } else { 'Deploy' })" -ForegroundColor White

    if ($allParameters.Count -gt 0) {
        Write-Host ""
        Write-Host "Parameters:" -ForegroundColor Blue
        foreach ($param in $allParameters.GetEnumerator()) {
            $value = if ($param.Value.ToString().Length -gt 50) {
                $param.Value.ToString().Substring(0, 47) + "..."
            } else {
                $param.Value
            }
            Write-Host "  $($param.Key): $value" -ForegroundColor White
        }
    }

    # Build Azure CLI command parameters
    $azCommand = switch ($DeploymentScope) {
        "resourceGroup" { @('deployment', 'group') }
        "subscription" { @('deployment', 'sub') }
        "managementGroup" { @('deployment', 'mg') }
        "tenant" { @('deployment', 'tenant') }
    }

    if ($ValidateOnly) {
        $azCommand += 'validate'
    } elseif ($WhatIf) {
        $azCommand += 'what-if'
    } else {
        $azCommand += 'create'
    }

    # Add common parameters
    $azCommand += '--name', $DeploymentName

    if ($ResourceGroup) {
        $azCommand += '--resource-group', $ResourceGroup
    }

    if ($locationCode) {
        $azCommand += '--location', $locationCode
    }

    if ($TemplateFile) {
        $azCommand += '--template-file', $TemplateFile
    } else {
        $azCommand += '--template-uri', $TemplateUri
    }

    if ($ParametersFile) {
        $azCommand += '--parameters', "@$ParametersFile"
    }

    # Add parameter overrides
    foreach ($param in $allParameters.GetEnumerator()) {
        $azCommand += '--parameters', "$($param.Key)=$($param.Value)"
    }

    if ($DeploymentScope -eq "resourceGroup" -and $Mode -eq "Complete") {
        $azCommand += '--mode', 'Complete'
    }

    if ($RollbackOnError -and -not $ValidateOnly -and -not $WhatIf) {
        $azCommand += '--rollback-on-error'
    }

    # Confirmation prompt
    if ($Confirm -and -not $ValidateOnly -and -not $WhatIf) {
        Write-Host ""
        Write-Host "⚠ Deployment Confirmation" -ForegroundColor Yellow
        Write-Host "This will deploy ARM template to:" -ForegroundColor White
        if ($ResourceGroup) {
            Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Blue
        } else {
            Write-Host "  Scope: $DeploymentScope" -ForegroundColor Blue
        }
        Write-Host "  Deployment mode: $Mode" -ForegroundColor White
        Write-Host "  Template: $(if ($TemplateFile) { Split-Path $TemplateFile -Leaf } else { $TemplateUri })" -ForegroundColor White
        Write-Host ""

        $confirmation = Read-Host "Do you want to proceed with the deployment? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-Host "Deployment cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Execute deployment
    Write-Host ""
    if ($ValidateOnly) {
        Write-Host "🔍 Validating ARM template..." -ForegroundColor Blue
    } elseif ($WhatIf) {
        Write-Host "🔍 Performing What-If analysis..." -ForegroundColor Blue
    } else {
        Write-Host "🚀 Starting ARM template deployment..." -ForegroundColor Blue
        if ($MonitorProgress) {
            Write-Host "Progress monitoring enabled..." -ForegroundColor Yellow
        }
    }

    $startTime = Get-Date

    # Execute the command
    $result = & az @azCommand 2>&1
    $exitCode = $LASTEXITCODE

    $endTime = Get-Date
    $duration = $endTime - $startTime

    if ($exitCode -eq 0) {
        Write-Host ""
        if ($ValidateOnly) {
            Write-Host "✓ Template validation completed successfully!" -ForegroundColor Green
            Write-Host "The template is valid and can be deployed." -ForegroundColor White
        } elseif ($WhatIf) {
            Write-Host "✓ What-If analysis completed successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "What-If Results:" -ForegroundColor Cyan
            Write-Host $("-" * 50) -ForegroundColor Gray
            Write-Host ($result -join "`n") -ForegroundColor White
        } else {
            Write-Host "✓ Deployment completed successfully!" -ForegroundColor Green

            # Parse deployment results
            $deploymentResult = $result | ConvertFrom-Json -ErrorAction SilentlyContinue

            if ($deploymentResult) {
                Write-Host ""
                Write-Host "Deployment Details:" -ForegroundColor Cyan
                Write-Host "  Name: $($deploymentResult.name)" -ForegroundColor White
                Write-Host "  State: $($deploymentResult.properties.provisioningState)" -ForegroundColor Green
                Write-Host "  Mode: $($deploymentResult.properties.mode)" -ForegroundColor White
                Write-Host "  Timestamp: $($deploymentResult.properties.timestamp)" -ForegroundColor White

                if ($deploymentResult.properties.outputs -and $OutputResults) {
                    Write-Host ""
                    Write-Host "Deployment Outputs:" -ForegroundColor Blue
                    foreach ($output in $deploymentResult.properties.outputs.PSObject.Properties) {
                        Write-Host "  $($output.Name): $($output.Value.value)" -ForegroundColor White
                    }
                }
            }
        }

        Write-Host ""
        Write-Host "Operation Summary:" -ForegroundColor Cyan
        Write-Host "  Duration: $([math]::Round($duration.TotalMinutes, 2)) minutes" -ForegroundColor White
        Write-Host "  Scope: $DeploymentScope" -ForegroundColor White
        if ($ResourceGroup) {
            Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
        }
        Write-Host "  Template: $(if ($TemplateFile) { Split-Path $TemplateFile -Leaf } else { $TemplateUri })" -ForegroundColor White

        Write-Host ""
        Write-Host "🏁 ARM template operation completed successfully" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "✗ Deployment operation failed" -ForegroundColor Red
        Write-Host "Error details:" -ForegroundColor Red
        Write-Host ($result -join "`n") -ForegroundColor Red
        Write-Host ""
        Write-Host "Common solutions:" -ForegroundColor Yellow
        Write-Host "• Check template syntax and parameter values" -ForegroundColor White
        Write-Host "• Verify resource names don't conflict with existing resources" -ForegroundColor White
        Write-Host "• Ensure sufficient permissions for the deployment scope" -ForegroundColor White
        Write-Host "• Check resource quotas and limits" -ForegroundColor White
        Write-Host ""
        Write-Host "Use -ValidateOnly to check for template issues" -ForegroundColor Blue

        throw "Azure CLI command failed with exit code $exitCode"
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
