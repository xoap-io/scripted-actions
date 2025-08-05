<#
.SYNOPSIS
    Create an Azure Resource Group using Azure CLI.

.DESCRIPTION
    This script creates a new Azure Resource Group using the Azure CLI with comprehensive validation and error handling.
    Includes checks for existing resource groups, proper naming conventions, and detailed output.
    Supports managed resource groups and custom tagging for better resource organization.
    
    The script uses the Azure CLI command: az group create

.PARAMETER ResourceGroup
    The name of the Azure Resource Group to create.

.PARAMETER Location
    The Azure region where the Resource Group will be created.

.PARAMETER ManagedBy
    The resource ID of the resource that manages this Resource Group.

.PARAMETER Tags
    Tags to apply to the Resource Group as JSON string.

.PARAMETER Force
    Force creation even if a Resource Group with the same name exists in a different location.

.EXAMPLE
    .\az-cli-create-resource-group.ps1 -ResourceGroup "prod-rg" -Location "East US"
    
    Creates a basic Resource Group in East US.

.EXAMPLE
    .\az-cli-create-resource-group.ps1 -ResourceGroup "managed-rg" -Location "West US 2" -ManagedBy "/subscriptions/.../resourceGroups/mgmt-rg" -Tags '{"Environment":"Production","Owner":"TeamA"}'
    
    Creates a managed Resource Group with custom tags.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI
    Note: Resource Group names must be unique within a subscription.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/group

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[\w\-\.\(\)]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region for the Resource Group")]
    [ValidateSet(
        "East US", "East US 2", "West US", "West US 2", "West US 3", "Central US", "North Central US", "South Central US",
        "Canada Central", "Canada East", "Brazil South", "North Europe", "West Europe", "UK South", "UK West",
        "France Central", "Germany West Central", "Switzerland North", "Norway East", "Sweden Central",
        "Australia East", "Australia Southeast", "Southeast Asia", "East Asia", "Japan East", "Japan West",
        "Korea Central", "Central India", "South India", "West India", "UAE North", "South Africa North"
    )]
    [string]$Location,

    [Parameter(HelpMessage = "The resource ID that manages this Resource Group")]
    [ValidatePattern('^/subscriptions/[^/]+/resourceGroups/[^/]+')]
    [string]$ManagedBy,

    [Parameter(HelpMessage = "Tags as JSON string")]
    [string]$Tags,

    [Parameter(HelpMessage = "Force creation even if Resource Group exists")]
    [switch]$Force
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

    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green
    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan

    # Check if Resource Group already exists
    Write-Host "Checking if Resource Group already exists..." -ForegroundColor Yellow
    $existingRG = az group show --name $ResourceGroup 2>$null
    
    if ($existingRG) {
        $rgInfo = $existingRG | ConvertFrom-Json
        
        if ($rgInfo.location.Replace(' ', '').ToLower() -eq $Location.Replace(' ', '').ToLower()) {
            if ($Force) {
                Write-Host "ℹ Resource Group '$ResourceGroup' already exists in $Location" -ForegroundColor Blue
                Write-Host "Using existing Resource Group due to -Force parameter" -ForegroundColor Blue
                
                # Display existing RG details
                Write-Host "Existing Resource Group Details:" -ForegroundColor Cyan
                Write-Host "  Name: $($rgInfo.name)" -ForegroundColor White
                Write-Host "  Location: $($rgInfo.location)" -ForegroundColor White
                Write-Host "  Provisioning State: $($rgInfo.properties.provisioningState)" -ForegroundColor White
                if ($rgInfo.managedBy) {
                    Write-Host "  Managed By: $($rgInfo.managedBy)" -ForegroundColor White
                }
                if ($rgInfo.tags) {
                    Write-Host "  Tags: $($rgInfo.tags | ConvertTo-Json -Compress)" -ForegroundColor White
                }
                
                Write-Host "✓ Using existing Resource Group successfully!" -ForegroundColor Green
                exit 0
            } else {
                throw "Resource Group '$ResourceGroup' already exists in $Location. Use -Force to proceed with existing Resource Group."
            }
        } else {
            throw "Resource Group '$ResourceGroup' already exists in $($rgInfo.location) but you specified $Location. Resource Group names must be unique within a subscription."
        }
    }
    Write-Host "✓ Resource Group name is available" -ForegroundColor Green

    # Validate Resource Group name format
    if ($ResourceGroup -notmatch '^[\w\-\.\(\)]+$') {
        throw "Resource Group name '$ResourceGroup' contains invalid characters. Use only letters, numbers, periods, underscores, hyphens, and parentheses."
    }
    
    if ($ResourceGroup.Length -gt 90) {
        throw "Resource Group name '$ResourceGroup' is too long. Maximum length is 90 characters."
    }
    
    Write-Host "✓ Resource Group name format validated" -ForegroundColor Green

    # Build Azure CLI command parameters
    $azParams = @(
        'group', 'create',
        '--name', $ResourceGroup,
        '--location', $Location
    )

    # Add optional parameters
    if ($ManagedBy) {
        # Validate ManagedBy format
        if ($ManagedBy -notmatch '^/subscriptions/[^/]+/resourceGroups/[^/]+') {
            throw "ManagedBy must be a valid resource ID format: /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/{provider}/{resource-type}/{resource-name}"
        }
        $azParams += '--managed-by', $ManagedBy
    }

    if ($Tags) {
        try {
            # Validate JSON format
            $null = $Tags | ConvertFrom-Json
            $azParams += '--tags', $Tags
        }
        catch {
            throw "Tags parameter must be valid JSON format. Example: '{`"Environment`":`"Production`",`"Owner`":`"TeamA`"}'"
        }
    }

    # Display configuration summary
    Write-Host "Resource Group Configuration:" -ForegroundColor Cyan
    Write-Host "  Name: $ResourceGroup" -ForegroundColor White
    Write-Host "  Location: $Location" -ForegroundColor White
    if ($ManagedBy) {
        Write-Host "  Managed By: $ManagedBy" -ForegroundColor White
    }
    if ($Tags) {
        Write-Host "  Tags: $Tags" -ForegroundColor White
    }

    Write-Host "Creating Resource Group..." -ForegroundColor Yellow

    # Execute Azure CLI command
    $result = & az @azParams 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $rgResult = $result | ConvertFrom-Json
        
        Write-Host "✓ Resource Group created successfully!" -ForegroundColor Green
        Write-Host "Resource Group Details:" -ForegroundColor Cyan
        Write-Host "  Name: $($rgResult.name)" -ForegroundColor White
        Write-Host "  Resource ID: $($rgResult.id)" -ForegroundColor White
        Write-Host "  Location: $($rgResult.location)" -ForegroundColor White
        Write-Host "  Provisioning State: $($rgResult.properties.provisioningState)" -ForegroundColor White
        
        if ($rgResult.managedBy) {
            Write-Host "  Managed By: $($rgResult.managedBy)" -ForegroundColor White
        }
        
        if ($rgResult.tags) {
            Write-Host "  Tags:" -ForegroundColor White
            foreach ($tag in $rgResult.tags.PSObject.Properties) {
                Write-Host "    $($tag.Name): $($tag.Value)" -ForegroundColor White
            }
        }
        
        Write-Host "" -ForegroundColor White
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "• Deploy resources to this Resource Group" -ForegroundColor White
        Write-Host "• Set up additional tags for resource organization" -ForegroundColor White
        Write-Host "• Configure resource locks if needed for protection" -ForegroundColor White
        Write-Host "• Review and set up RBAC permissions" -ForegroundColor White
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create Resource Group" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
