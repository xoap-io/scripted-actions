<#
.SYNOPSIS
    Create an Azure Application Security Group using Azure CLI.

.DESCRIPTION
    This script creates an Azure Application Security Group using the Azure CLI with comprehensive validation and best practices.
    Application Security Groups enable micro-segmentation within virtual networks and simplify NSG rule management.
    Includes location validation, tagging, and automatic resource association capabilities.

    The script uses the Azure CLI command: az network asg create

.PARAMETER Name
    Name of the Application Security Group to create.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group where the ASG will be created.

.PARAMETER Location
    Azure region where the ASG will be created.

.PARAMETER Tags
    Tags to apply to the ASG in key=value format (space-separated pairs).

.PARAMETER Description
    Description of the ASG for documentation purposes.

.EXAMPLE
    .\az-cli-create-asg.ps1 -Name "web-servers" -ResourceGroup "rg-web" -Location "eastus" -Description "Web server application security group"

.EXAMPLE
    .\az-cli-create-asg.ps1 -Name "database-servers" -ResourceGroup "rg-db" -Location "westus2" -Tags "Environment=Production Tier=Database" -Description "Database servers ASG"

.EXAMPLE
    .\az-cli-create-asg.ps1 -Name "api-servers" -ResourceGroup "rg-api" -Location "northeurope" -Tags "Project=ApiGateway Owner=DevTeam"

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
    Version: 1.0.0
    Requires: Azure CLI version 2.0 or later

    Application Security Groups:
    - Enable micro-segmentation within VNets
    - Simplify NSG rule management
    - Group VMs by application function
    - Support complex network topologies

.LINK
    https://docs.microsoft.com/en-us/cli/azure/network/asg

.COMPONENT
    Azure CLI Network Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Application Security Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "Azure region for the ASG")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "Tags in key=value format")]
    [string]$Tags,

    [Parameter(Mandatory = $false, HelpMessage = "Description of the ASG")]
    [ValidateLength(0, 500)]
    [string]$Description
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to validate Azure CLI installation and authentication
function Test-AzureCLI {
    try {
        Write-Host "🔍 Validating Azure CLI installation..." -ForegroundColor Cyan
        $null = az --version
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI is not installed or not functioning correctly"
        }

        Write-Host "🔍 Checking Azure CLI authentication..." -ForegroundColor Cyan
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Not authenticated to Azure CLI. Please run 'az login' first"
        }

        Write-Host "✅ Azure CLI validation successful" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Azure CLI validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to validate resource group exists
function Test-ResourceGroupExists {
    param($ResourceGroup)

    try {
        Write-Host "🔍 Validating resource group '$ResourceGroup' exists..." -ForegroundColor Cyan
        $rg = az group show --name $ResourceGroup --query "name" --output tsv 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($rg)) {
            throw "Resource group '$ResourceGroup' not found"
        }
        Write-Host "✅ Resource group '$ResourceGroup' found" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Resource group validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to validate location
function Test-AzureLocation {
    param($Location)

    try {
        Write-Host "🔍 Validating Azure location '$Location'..." -ForegroundColor Cyan
        $validLocations = az account list-locations --query "[].name" --output tsv
        if ($validLocations -notcontains $Location) {
            throw "Invalid Azure location: $Location"
        }
        Write-Host "✅ Location '$Location' is valid" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Location validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to check if ASG already exists
function Test-ASGExists {
    param($ResourceGroup, $AsgName)

    try {
        Write-Host "🔍 Checking if ASG '$AsgName' already exists..." -ForegroundColor Cyan
        $asg = az network asg show --resource-group $ResourceGroup --name $AsgName --query "name" --output tsv 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($asg)) {
            throw "ASG '$AsgName' already exists in resource group '$ResourceGroup'"
        }
        Write-Host "✅ ASG name is available" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "ASG conflict check failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to parse and validate tags
function Get-ValidatedTags {
    param($TagString)

    if ([string]::IsNullOrEmpty($TagString)) {
        return @()
    }

    $tagPairs = $TagString -split '\s+'
    $azTags = @()

    foreach ($pair in $tagPairs) {
        if ($pair -match '^([^=]+)=(.+)$') {
            $key = $Matches[1]
            $value = $Matches[2]

            # Validate tag key and value
            if ($key.Length -gt 512 -or $value.Length -gt 256) {
                throw "Tag key must be ≤ 512 chars and value ≤ 256 chars: $pair"
            }

            $azTags += $pair
        }
        else {
            throw "Invalid tag format: $pair (use key=value format)"
        }
    }

    return $azTags
}

# Function to get VNets in the resource group for reference
function Get-VirtualNetworks {
    param($ResourceGroup)

    try {
        Write-Host "🔍 Getting Virtual Networks in resource group for reference..." -ForegroundColor Cyan
        $vnets = az network vnet list --resource-group $ResourceGroup --query "[].{name:name, addressSpace:addressSpace.addressPrefixes[0], subnets:length(subnets)}" --output json | ConvertFrom-Json

        if ($vnets.Count -gt 0) {
            Write-Host "📋 Found $($vnets.Count) VNet(s) in resource group:" -ForegroundColor Yellow
            foreach ($vnet in $vnets) {
                Write-Host "   - $($vnet.name) ($($vnet.addressSpace)) - $($vnet.subnets) subnet(s)" -ForegroundColor White
            }
        }
        else {
            Write-Host "ℹ️ No Virtual Networks found in resource group" -ForegroundColor Gray
        }

        return $vnets
    }
    catch {
        Write-Warning "Could not retrieve VNet information: $($_.Exception.Message)"
        return @()
    }
}

# Function to show ASG usage recommendations
function Show-ASGRecommendations {
    param($AsgName)

    Write-Host "`n💡 ASG Usage Recommendations:" -ForegroundColor Yellow
    Write-Host "   1. Associate VMs/NICs with this ASG using:" -ForegroundColor White
    Write-Host "      az network nic ip-config update --resource-group $ResourceGroup --nic-name <NIC_NAME> --name ipconfig1 --application-security-groups $AsgName" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   2. Use in NSG rules for micro-segmentation:" -ForegroundColor White
    Write-Host "      az network nsg rule create --source-asgs $AsgName --destination-asgs <TARGET_ASG>" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   3. Common ASG naming patterns:" -ForegroundColor White
    Write-Host "      - web-servers, app-servers, db-servers" -ForegroundColor Gray
    Write-Host "      - frontend-tier, backend-tier, data-tier" -ForegroundColor Gray
    Write-Host "      - prod-web, dev-api, test-db" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   4. Best practices:" -ForegroundColor White
    Write-Host "      - Create ASGs before deploying VMs" -ForegroundColor Gray
    Write-Host "      - Use descriptive names for easy identification" -ForegroundColor Gray
    Write-Host "      - Plan ASG strategy for entire application stack" -ForegroundColor Gray
    Write-Host "      - Document ASG usage and associations" -ForegroundColor Gray
    Write-Host ""
}

# Function to display ASG summary
function Show-ASGSummary {
    param($Parameters)

    Write-Host "`n📋 ASG Configuration Summary:" -ForegroundColor Yellow
    Write-Host "   ASG Name: $($Parameters.Name)" -ForegroundColor White
    Write-Host "   Resource Group: $($Parameters.ResourceGroup)" -ForegroundColor White
    Write-Host "   Location: $($Parameters.Location)" -ForegroundColor White

    if ($Parameters.Tags) {
        Write-Host "   Tags: $($Parameters.Tags)" -ForegroundColor White
    }

    if ($Parameters.Description) {
        Write-Host "   Description: $($Parameters.Description)" -ForegroundColor White
    }
    Write-Host ""
}

# Main execution
try {
    Write-Host "🚀 Starting Azure ASG Creation" -ForegroundColor Green
    Write-Host "==============================" -ForegroundColor Green

    # Validate Azure CLI
    if (-not (Test-AzureCLI)) {
        exit 1
    }

    # Validate resource group exists
    if (-not (Test-ResourceGroupExists -ResourceGroup $ResourceGroup)) {
        exit 1
    }

    # Validate location
    if (-not (Test-AzureLocation -Location $Location)) {
        exit 1
    }

    # Check if ASG already exists
    if (-not (Test-ASGExists -ResourceGroup $ResourceGroup -AsgName $Name)) {
        exit 1
    }

    # Get VNets for reference
    $vnets = Get-VirtualNetworks -ResourceGroup $ResourceGroup

    # Validate and process tags
    $validatedTags = @()
    if ($Tags) {
        $validatedTags = Get-ValidatedTags -TagString $Tags
    }

    # Display configuration summary
    $paramSummary = @{
        Name = $Name
        ResourceGroup = $ResourceGroup
        Location = $Location
        Tags = $Tags
        Description = $Description
    }
    Show-ASGSummary -Parameters $paramSummary

    # Build parameters array
    $azParams = @(
        'network', 'asg', 'create',
        '--resource-group', $ResourceGroup,
        '--name', $Name,
        '--location', $Location
    )

    # Add optional parameters
    if ($validatedTags.Count -gt 0) {
        $azParams += '--tags'
        $azParams += $validatedTags
    }

    # Create the ASG
    Write-Host "🔧 Creating Application Security Group '$Name'..." -ForegroundColor Cyan
    $null = az @azParams

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ ASG '$Name' created successfully!" -ForegroundColor Green

        # Add description if provided (separate command as create doesn't support description)
        if ($Description) {
            Write-Host "📝 Adding description..." -ForegroundColor Cyan
            try {
                # Note: ASGs don't have a direct description property, so we'll add it as a tag
                $descriptionTag = "Description=$Description"
                $null = az network asg update --resource-group $ResourceGroup --name $Name --add tags.$descriptionTag 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Description added as tag" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "Could not add description: $($_.Exception.Message)"
            }
        }

        # Display created ASG details
        Write-Host "`n📝 ASG Details:" -ForegroundColor Yellow
        $asgDetails = az network asg show --resource-group $ResourceGroup --name $Name --output table
        Write-Host $asgDetails -ForegroundColor White

        # Show usage recommendations
        Show-ASGRecommendations -AsgName $Name

        # Show related ASGs in the resource group
        Write-Host "📋 Other ASGs in Resource Group:" -ForegroundColor Yellow
        $otherAsgs = az network asg list --resource-group $ResourceGroup --query "[].name" --output tsv
        if ($otherAsgs) {
            $otherAsgs | Where-Object { $_ -ne $Name } | ForEach-Object {
                Write-Host "   - $_" -ForegroundColor White
            }
        }
        else {
            Write-Host "   (No other ASGs found)" -ForegroundColor Gray
        }
    }
    else {
        throw "Failed to create ASG. Exit code: $LASTEXITCODE"
    }
}
catch {
    Write-Error "❌ Failed to create ASG: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
