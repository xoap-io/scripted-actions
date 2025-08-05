<#
.SYNOPSIS
    Export Azure Resource Manager templates using Azure CLI.

.DESCRIPTION
    This script exports ARM templates from existing Azure resources using the Azure CLI.
    Supports exporting from Resource Groups, individual resources, and generating deployment templates.
    Includes parameter file generation, template optimization, and Infrastructure as Code workflows.
    
    The script uses the Azure CLI commands: az group export, az resource show

.PARAMETER ResourceGroup
    Resource Group to export ARM template from.

.PARAMETER Resources
    Array of specific resource IDs to export (exports all RG resources if not specified).

.PARAMETER OutputPath
    Directory path to save the exported template files.

.PARAMETER TemplateFileName
    Name for the exported template file (default: template.json).

.PARAMETER ParametersFileName
    Name for the generated parameters file (default: parameters.json).

.PARAMETER IncludeParameterFile
    Generate a separate parameters file with current values.

.PARAMETER IncludeComments
    Include descriptive comments in the exported template.

.PARAMETER SkipResourceNameParameterization
    Keep original resource names instead of parameterizing them.

.PARAMETER ExportScope
    Scope of the export operation.

.PARAMETER OptimizeTemplate
    Optimize the template by removing unnecessary properties.

.PARAMETER ValidateTemplate
    Validate the exported template syntax and deployability.

.PARAMETER FormatJson
    Format JSON output with proper indentation.

.PARAMETER CreateDeploymentScript
    Generate PowerShell deployment script alongside the template.

.EXAMPLE
    .\az-cli-export-template.ps1 -ResourceGroup "production-rg" -OutputPath ".\templates"
    
    Exports ARM template from Resource Group to templates directory.

.EXAMPLE
    .\az-cli-export-template.ps1 -ResourceGroup "web-rg" -IncludeParameterFile -IncludeComments -OutputPath ".\exports"
    
    Exports template with parameters file and comments.

.EXAMPLE
    .\az-cli-export-template.ps1 -Resources @("/subscriptions/.../resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1") -OutputPath ".\vm-template"
    
    Exports template for specific virtual machine only.

.EXAMPLE
    .\az-cli-export-template.ps1 -ResourceGroup "infra-rg" -OptimizeTemplate -ValidateTemplate -CreateDeploymentScript
    
    Exports optimized template with validation and deployment script.

.NOTES
    Author: Azure CLI Script
    Version: 1.0
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/group

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Resource Group to export ARM template from")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._\-\(\)]+$')]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Array of specific resource IDs to export")]
    [string[]]$Resources,

    [Parameter(HelpMessage = "Directory path to save exported template files")]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Container)) {
            New-Item -Path $_ -ItemType Directory -Force | Out-Null
        }
        return $true
    })]
    [string]$OutputPath = ".\exported-templates",

    [Parameter(HelpMessage = "Name for the exported template file")]
    [ValidatePattern('\.json$')]
    [string]$TemplateFileName = "template.json",

    [Parameter(HelpMessage = "Name for the generated parameters file")]
    [ValidatePattern('\.json$')]
    [string]$ParametersFileName = "parameters.json",

    [Parameter(HelpMessage = "Generate a separate parameters file with current values")]
    [switch]$IncludeParameterFile,

    [Parameter(HelpMessage = "Include descriptive comments in the exported template")]
    [switch]$IncludeComments,

    [Parameter(HelpMessage = "Keep original resource names instead of parameterizing them")]
    [switch]$SkipResourceNameParameterization,

    [Parameter(HelpMessage = "Scope of the export operation")]
    [ValidateSet("ResourceGroup", "Resource")]
    [string]$ExportScope = "ResourceGroup",

    [Parameter(HelpMessage = "Optimize template by removing unnecessary properties")]
    [switch]$OptimizeTemplate,

    [Parameter(HelpMessage = "Validate the exported template syntax and deployability")]
    [switch]$ValidateTemplate,

    [Parameter(HelpMessage = "Format JSON output with proper indentation")]
    [switch]$FormatJson,

    [Parameter(HelpMessage = "Generate PowerShell deployment script alongside the template")]
    [switch]$CreateDeploymentScript,

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

    Write-Host "📤 Azure ARM Template Export" -ForegroundColor Blue
    Write-Host "=============================" -ForegroundColor Blue
    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green

    # Switch subscription if specified
    if ($Subscription) {
        Write-Host "Switching to subscription: $Subscription" -ForegroundColor Yellow
        az account set --subscription $Subscription
        $azAccount = az account show | ConvertFrom-Json
    }

    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan
    Write-Host ""

    # Verify Resource Group exists
    Write-Host "Verifying Resource Group: $ResourceGroup" -ForegroundColor Yellow
    $rgCheck = az group show --name $ResourceGroup 2>$null
    if (-not $rgCheck) {
        throw "Resource Group '$ResourceGroup' not found in subscription '$($azAccount.name)'"
    }
    
    $rgInfo = $rgCheck | ConvertFrom-Json
    Write-Host "✓ Resource Group '$ResourceGroup' found" -ForegroundColor Green
    Write-Host "  Location: $($rgInfo.location)" -ForegroundColor White

    # Ensure output directory exists
    if (-not (Test-Path $OutputPath -PathType Container)) {
        Write-Host "Creating output directory: $OutputPath" -ForegroundColor Yellow
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $templateFilePath = Join-Path $OutputPath $TemplateFileName
    $parametersFilePath = Join-Path $OutputPath $ParametersFileName

    # Get resources to export
    Write-Host ""
    Write-Host "Analyzing resources to export..." -ForegroundColor Yellow
    
    if ($Resources -and $Resources.Count -gt 0) {
        $ExportScope = "Resource"
        Write-Host "Exporting specific resources: $($Resources.Count)" -ForegroundColor Blue
        foreach ($resourceId in $Resources) {
            $resourceName = $resourceId -split '/' | Select-Object -Last 1
            Write-Host "  • $resourceName" -ForegroundColor White
        }
    } else {
        $allResources = az resource list --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
        $resourceCount = if ($allResources) { $allResources.Count } else { 0 }
        Write-Host "Exporting all resources from Resource Group: $resourceCount" -ForegroundColor Blue
        
        if ($resourceCount -eq 0) {
            Write-Host "⚠ No resources found in Resource Group to export" -ForegroundColor Yellow
            Write-Host "Creating empty template..." -ForegroundColor Blue
        } else {
            # Display resource summary
            $resourceTypes = $allResources | Group-Object -Property type
            Write-Host "Resource types to export:" -ForegroundColor Blue
            foreach ($typeGroup in $resourceTypes) {
                Write-Host "  • $($typeGroup.Name): $($typeGroup.Count)" -ForegroundColor White
            }
        }
    }

    # Display export configuration
    Write-Host ""
    Write-Host "Export Configuration:" -ForegroundColor Cyan
    Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
    Write-Host "  Export Scope: $ExportScope" -ForegroundColor White
    Write-Host "  Output Path: $OutputPath" -ForegroundColor White
    Write-Host "  Template File: $TemplateFileName" -ForegroundColor White
    if ($IncludeParameterFile) {
        Write-Host "  Parameters File: $ParametersFileName" -ForegroundColor White
    }
    Write-Host "  Include Comments: $(if ($IncludeComments) { 'Yes' } else { 'No' })" -ForegroundColor White
    Write-Host "  Parameterize Names: $(if ($SkipResourceNameParameterization) { 'No' } else { 'Yes' })" -ForegroundColor White
    Write-Host "  Optimize Template: $(if ($OptimizeTemplate) { 'Yes' } else { 'No' })" -ForegroundColor White

    # Build Azure CLI export command
    Write-Host ""
    Write-Host "🚀 Exporting ARM template..." -ForegroundColor Blue

    if ($ExportScope -eq "ResourceGroup") {
        # Export entire Resource Group
        $azParams = @('group', 'export', '--name', $ResourceGroup)
        
        if ($SkipResourceNameParameterization) {
            $azParams += '--skip-resource-name-params'
        }
        
        if ($IncludeComments) {
            $azParams += '--include-comments'
        }
        
        if ($IncludeParameterFile) {
            $azParams += '--include-parameter-default-value'
        }
    } else {
        # Export specific resources - need to use different approach
        Write-Host "Exporting individual resources..." -ForegroundColor Yellow
        
        # Create a custom template for specific resources
        $template = @{
            '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
            contentVersion = "1.0.0.0"
            parameters = @{}
            variables = @{}
            resources = @()
            outputs = @{}
        }
        
        foreach ($resourceId in $Resources) {
            Write-Host "  Processing: $($resourceId -split '/' | Select-Object -Last 1)" -ForegroundColor Blue
            
            # Get resource details
            $resourceDetails = az resource show --ids $resourceId | ConvertFrom-Json
            
            if ($resourceDetails) {
                # Add resource to template (simplified version)
                $resourceTemplate = @{
                    type = $resourceDetails.type
                    apiVersion = "2021-01-01"  # Default API version
                    name = $resourceDetails.name
                    location = $resourceDetails.location
                    properties = $resourceDetails.properties
                }
                
                if ($resourceDetails.tags) {
                    $resourceTemplate.tags = $resourceDetails.tags
                }
                
                $template.resources += $resourceTemplate
            }
        }
        
        # Convert to JSON and save
        $templateJson = $template | ConvertTo-Json -Depth 10
        
        if ($FormatJson) {
            $templateJson | Out-File -FilePath $templateFilePath -Encoding UTF8
        } else {
            $templateJson -replace "`r`n", "" | Out-File -FilePath $templateFilePath -Encoding UTF8
        }
        
        Write-Host "✓ Custom template exported successfully" -ForegroundColor Green
    }

    # Execute standard Resource Group export if needed
    if ($ExportScope -eq "ResourceGroup") {
        $result = & az @azParams 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            # Save the exported template
            if ($FormatJson) {
                $result | ConvertFrom-Json | ConvertTo-Json -Depth 20 | Out-File -FilePath $templateFilePath -Encoding UTF8
            } else {
                $result | Out-File -FilePath $templateFilePath -Encoding UTF8
            }
            
            Write-Host "✓ Template exported successfully" -ForegroundColor Green
        } else {
            throw "Failed to export template: $($result -join "`n")"
        }
    }

    # Load the exported template for processing
    $exportedTemplate = Get-Content -Path $templateFilePath -Raw | ConvertFrom-Json

    # Optimize template if requested
    if ($OptimizeTemplate) {
        Write-Host ""
        Write-Host "🔧 Optimizing template..." -ForegroundColor Yellow
        
        # Remove common unnecessary properties
        foreach ($resource in $exportedTemplate.resources) {
            # Remove read-only properties
            if ($resource.properties) {
                $resource.properties.PSObject.Properties.Remove('provisioningState')
                $resource.properties.PSObject.Properties.Remove('resourceGuid')
                $resource.properties.PSObject.Properties.Remove('uniqueId')
            }
            
            # Remove system-generated names/IDs where appropriate
            if ($resource.type -eq "Microsoft.Network/networkSecurityGroups") {
                if ($resource.properties.defaultSecurityRules) {
                    $resource.properties.PSObject.Properties.Remove('defaultSecurityRules')
                }
            }
        }
        
        # Save optimized template
        $exportedTemplate | ConvertTo-Json -Depth 20 | Out-File -FilePath $templateFilePath -Encoding UTF8
        Write-Host "✓ Template optimized" -ForegroundColor Green
    }

    # Generate parameters file if requested
    if ($IncludeParameterFile) {
        Write-Host ""
        Write-Host "📄 Generating parameters file..." -ForegroundColor Yellow
        
        $parametersTemplate = @{
            '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
            contentVersion = "1.0.0.0"
            parameters = @{}
        }
        
        # Extract parameters from template
        if ($exportedTemplate.parameters) {
            foreach ($param in $exportedTemplate.parameters.PSObject.Properties) {
                $paramValue = @{
                    value = if ($param.Value.defaultValue) { $param.Value.defaultValue } else { "" }
                }
                $parametersTemplate.parameters[$param.Name] = $paramValue
            }
        }
        
        $parametersTemplate | ConvertTo-Json -Depth 10 | Out-File -FilePath $parametersFilePath -Encoding UTF8
        Write-Host "✓ Parameters file generated: $ParametersFileName" -ForegroundColor Green
    }

    # Validate template if requested
    if ($ValidateTemplate) {
        Write-Host ""
        Write-Host "🔍 Validating exported template..." -ForegroundColor Yellow
        
        try {
            $validateParams = @('deployment', 'group', 'validate', '--resource-group', $ResourceGroup, '--template-file', $templateFilePath)
            
            if ($IncludeParameterFile) {
                $validateParams += '--parameters', "@$parametersFilePath"
            }
            
            $validationResult = & az @validateParams 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ Template validation passed" -ForegroundColor Green
            } else {
                Write-Host "⚠ Template validation failed:" -ForegroundColor Yellow
                Write-Host ($validationResult -join "`n") -ForegroundColor Red
            }
        }
        catch {
            Write-Host "⚠ Template validation encountered errors: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # Create deployment script if requested
    if ($CreateDeploymentScript) {
        Write-Host ""
        Write-Host "📜 Creating deployment script..." -ForegroundColor Yellow
        
        $deploymentScriptPath = Join-Path $OutputPath "deploy.ps1"
        $deploymentScript = @"
<#
.SYNOPSIS
    Deploy exported ARM template to Azure

.DESCRIPTION
    This script deploys the exported ARM template using Azure CLI.
    Generated by az-cli-export-template.ps1

.PARAMETER ResourceGroupName
    Target Resource Group for deployment

.PARAMETER DeploymentName
    Name for the deployment (optional)
#>

param(
    [Parameter(Mandatory = `$true)]
    [string]`$ResourceGroupName,
    
    [string]`$DeploymentName = "deployment-`$(Get-Date -Format 'yyyyMMdd-HHmmss')"
)

# Deploy the template
Write-Host "Deploying ARM template..." -ForegroundColor Blue

`$templatePath = Join-Path `$PSScriptRoot "$TemplateFileName"
$(if ($IncludeParameterFile) { "`$parametersPath = Join-Path `$PSScriptRoot `"$ParametersFileName`"" })

`$deployParams = @(
    'deployment', 'group', 'create',
    '--resource-group', `$ResourceGroupName,
    '--template-file', `$templatePath,
    '--name', `$DeploymentName
)

$(if ($IncludeParameterFile) { "`$deployParams += '--parameters', `"@`$parametersPath`"" })

`$result = & az @deployParams

if (`$LASTEXITCODE -eq 0) {
    Write-Host "✓ Deployment completed successfully!" -ForegroundColor Green
    `$result | ConvertFrom-Json | ConvertTo-Json -Depth 5
} else {
    Write-Host "✗ Deployment failed" -ForegroundColor Red
    exit 1
}
"@
        
        $deploymentScript | Out-File -FilePath $deploymentScriptPath -Encoding UTF8
        Write-Host "✓ Deployment script created: deploy.ps1" -ForegroundColor Green
    }

    # Generate summary report
    Write-Host ""
    Write-Host "📊 Export Summary:" -ForegroundColor Cyan
    Write-Host "  Template file: $templateFilePath" -ForegroundColor White
    Write-Host "  Template size: $([math]::Round((Get-Item $templateFilePath).Length / 1KB, 2)) KB" -ForegroundColor White
    Write-Host "  Resources exported: $($exportedTemplate.resources.Count)" -ForegroundColor White
    Write-Host "  Parameters: $($exportedTemplate.parameters.PSObject.Properties.Count)" -ForegroundColor White
    Write-Host "  Variables: $($exportedTemplate.variables.PSObject.Properties.Count)" -ForegroundColor White
    
    if ($IncludeParameterFile) {
        Write-Host "  Parameters file: $parametersFilePath" -ForegroundColor White
    }
    
    if ($CreateDeploymentScript) {
        Write-Host "  Deployment script: deploy.ps1" -ForegroundColor White
    }

    # Display resource breakdown
    if ($exportedTemplate.resources.Count -gt 0) {
        Write-Host ""
        Write-Host "Resource Breakdown:" -ForegroundColor Blue
        $resourcesByType = $exportedTemplate.resources | Group-Object -Property type
        foreach ($group in $resourcesByType) {
            Write-Host "  • $($group.Name): $($group.Count)" -ForegroundColor White
        }
    }

    Write-Host ""
    Write-Host "🏁 ARM template export completed successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "• Review and customize the exported template" -ForegroundColor White
    Write-Host "• Update parameter default values as needed" -ForegroundColor White
    Write-Host "• Test deployment in a non-production environment" -ForegroundColor White
    if ($CreateDeploymentScript) {
        Write-Host "• Use deploy.ps1 script for easy deployment" -ForegroundColor White
    }
}
catch {
    Write-Host "✗ Failed to export ARM template" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
