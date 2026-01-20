<#
.SYNOPSIS
    Create an Azure Network Security Group using Azure CLI.

.DESCRIPTION
    This script creates an Azure Network Security Group using the Azure CLI with comprehensive validation and security best practices.
    Supports location validation, tagging, and automatic default rule creation.
    Includes conflict checking and resource validation with detailed reporting.

    The script uses the Azure CLI command: az network nsg create

.PARAMETER Name
    Name of the Network Security Group to create.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group where the NSG will be created.

.PARAMETER Location
    Azure region where the NSG will be created.

.PARAMETER Tags
    Tags to apply to the NSG in key=value format (space-separated pairs).

.PARAMETER CreateDefaultRules
    Create default security rules for common scenarios (SSH, RDP, HTTP, HTTPS).

.PARAMETER DefaultRuleProfile
    Profile for default rules: Basic, Web, Database, or Custom.

.EXAMPLE
    .\az-cli-create-nsg-group.ps1 -Name "web-nsg" -ResourceGroup "rg-web" -Location "eastus" -Tags "Environment=Production Project=WebApp" -CreateDefaultRules -DefaultRuleProfile "Web"

.EXAMPLE
    .\az-cli-create-nsg-group.ps1 -Name "db-nsg" -ResourceGroup "rg-database" -Location "westus2" -DefaultRuleProfile "Database"

.EXAMPLE
    .\az-cli-create-nsg-group.ps1 -Name "custom-nsg" -ResourceGroup "rg-custom" -Location "northeurope"

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later

.LINK
    https://docs.microsoft.com/en-us/cli/azure/network/nsg

.COMPONENT
    Azure CLI Network Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Network Security Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "Azure region for the NSG")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "Tags in key=value format")]
    [string]$Tags,

    [Parameter(Mandatory = $false, HelpMessage = "Create default security rules")]
    [switch]$CreateDefaultRules,

    [Parameter(Mandatory = $false, HelpMessage = "Default rule profile")]
    [ValidateSet('Basic', 'Web', 'Database', 'Custom')]
    [string]$DefaultRuleProfile = 'Basic'
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

# Function to check if NSG already exists
function Test-NSGExists {
    param($ResourceGroup, $NsgName)

    try {
        Write-Host "🔍 Checking if NSG '$NsgName' already exists..." -ForegroundColor Cyan
        $nsg = az network nsg show --resource-group $ResourceGroup --name $NsgName --query "name" --output tsv 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($nsg)) {
            throw "NSG '$NsgName' already exists in resource group '$ResourceGroup'"
        }
        Write-Host "✅ NSG name is available" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "NSG conflict check failed: $($_.Exception.Message)"
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

# Function to get default rules based on profile
function Get-DefaultRules {
    param($RuleProfile)

    $rules = @()

    switch ($RuleProfile) {
        'Basic' {
            $rules = @(
                @{ Name = "AllowSSH"; Priority = 1000; Direction = "Inbound"; Access = "Allow"; Protocol = "Tcp"; SourcePort = "*"; DestinationPort = "22"; Source = "*"; Destination = "*"; Description = "Allow SSH inbound" },
                @{ Name = "AllowRDP"; Priority = 1010; Direction = "Inbound"; Access = "Allow"; Protocol = "Tcp"; SourcePort = "*"; DestinationPort = "3389"; Source = "*"; Destination = "*"; Description = "Allow RDP inbound" },
                @{ Name = "DenyAllInbound"; Priority = 4096; Direction = "Inbound"; Access = "Deny"; Protocol = "*"; SourcePort = "*"; DestinationPort = "*"; Source = "*"; Destination = "*"; Description = "Deny all other inbound traffic" }
            )
        }
        'Web' {
            $rules = @(
                @{ Name = "AllowHTTP"; Priority = 1000; Direction = "Inbound"; Access = "Allow"; Protocol = "Tcp"; SourcePort = "*"; DestinationPort = "80"; Source = "*"; Destination = "*"; Description = "Allow HTTP inbound" },
                @{ Name = "AllowHTTPS"; Priority = 1010; Direction = "Inbound"; Access = "Allow"; Protocol = "Tcp"; SourcePort = "*"; DestinationPort = "443"; Source = "*"; Destination = "*"; Description = "Allow HTTPS inbound" },
                @{ Name = "AllowSSH"; Priority = 1020; Direction = "Inbound"; Access = "Allow"; Protocol = "Tcp"; SourcePort = "*"; DestinationPort = "22"; Source = "10.0.0.0/8"; Destination = "*"; Description = "Allow SSH from private networks" },
                @{ Name = "DenyAllInbound"; Priority = 4096; Direction = "Inbound"; Access = "Deny"; Protocol = "*"; SourcePort = "*"; DestinationPort = "*"; Source = "*"; Destination = "*"; Description = "Deny all other inbound traffic" }
            )
        }
        'Database' {
            $rules = @(
                @{ Name = "AllowSQL"; Priority = 1000; Direction = "Inbound"; Access = "Allow"; Protocol = "Tcp"; SourcePort = "*"; DestinationPort = "1433"; Source = "10.0.0.0/8"; Destination = "*"; Description = "Allow SQL Server from private networks" },
                @{ Name = "AllowMySQL"; Priority = 1010; Direction = "Inbound"; Access = "Allow"; Protocol = "Tcp"; SourcePort = "*"; DestinationPort = "3306"; Source = "10.0.0.0/8"; Destination = "*"; Description = "Allow MySQL from private networks" },
                @{ Name = "AllowPostgreSQL"; Priority = 1020; Direction = "Inbound"; Access = "Allow"; Protocol = "Tcp"; SourcePort = "*"; DestinationPort = "5432"; Source = "10.0.0.0/8"; Destination = "*"; Description = "Allow PostgreSQL from private networks" },
                @{ Name = "AllowSSH"; Priority = 1030; Direction = "Inbound"; Access = "Allow"; Protocol = "Tcp"; SourcePort = "*"; DestinationPort = "22"; Source = "10.0.0.0/8"; Destination = "*"; Description = "Allow SSH from private networks" },
                @{ Name = "DenyAllInbound"; Priority = 4096; Direction = "Inbound"; Access = "Deny"; Protocol = "*"; SourcePort = "*"; DestinationPort = "*"; Source = "*"; Destination = "*"; Description = "Deny all other inbound traffic" }
            )
        }
        'Custom' {
            $rules = @(
                @{ Name = "DenyAllInbound"; Priority = 4096; Direction = "Inbound"; Access = "Deny"; Protocol = "*"; SourcePort = "*"; DestinationPort = "*"; Source = "*"; Destination = "*"; Description = "Deny all inbound traffic (customize as needed)" }
            )
        }
    }

    return $rules
}

# Function to create default rules
function New-DefaultRules {
    param($ResourceGroup, $NsgName, $Rules)

    Write-Host "🔧 Creating default security rules..." -ForegroundColor Cyan

    foreach ($rule in $Rules) {
        try {
            Write-Host "   Creating rule: $($rule.Name)" -ForegroundColor Gray

            $ruleParams = @(
                'network', 'nsg', 'rule', 'create',
                '--resource-group', $ResourceGroup,
                '--nsg-name', $NsgName,
                '--name', $rule.Name,
                '--priority', $rule.Priority.ToString(),
                '--direction', $rule.Direction,
                '--access', $rule.Access,
                '--protocol', $rule.Protocol,
                '--source-address-prefixes', $rule.Source,
                '--source-port-ranges', $rule.SourcePort,
                '--destination-address-prefixes', $rule.Destination,
                '--destination-port-ranges', $rule.DestinationPort,
                '--description', $rule.Description
            )

            $null = az @ruleParams
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✅ Rule '$($rule.Name)' created successfully" -ForegroundColor Green
            }
            else {
                Write-Warning "   ⚠️ Failed to create rule '$($rule.Name)'"
            }
        }
        catch {
            Write-Warning "   ⚠️ Error creating rule '$($rule.Name)': $($_.Exception.Message)"
        }
    }
}

# Function to display NSG summary
function Show-NSGSummary {
    param($Parameters)

    Write-Host "`n📋 NSG Configuration Summary:" -ForegroundColor Yellow
    Write-Host "   NSG Name: $($Parameters.Name)" -ForegroundColor White
    Write-Host "   Resource Group: $($Parameters.ResourceGroup)" -ForegroundColor White
    Write-Host "   Location: $($Parameters.Location)" -ForegroundColor White

    if ($Parameters.Tags) {
        Write-Host "   Tags: $($Parameters.Tags)" -ForegroundColor White
    }

    if ($Parameters.CreateDefaultRules) {
        Write-Host "   Default Rules: Yes ($($Parameters.DefaultRuleProfile) profile)" -ForegroundColor White
    }
    else {
        Write-Host "   Default Rules: No" -ForegroundColor White
    }
    Write-Host ""
}

# Main execution
try {
    Write-Host "🚀 Starting Azure NSG Creation" -ForegroundColor Green
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

    # Check if NSG already exists
    if (-not (Test-NSGExists -ResourceGroup $ResourceGroup -NsgName $Name)) {
        exit 1
    }

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
        CreateDefaultRules = $CreateDefaultRules
        DefaultRuleProfile = $DefaultRuleProfile
    }
    Show-NSGSummary -Parameters $paramSummary

    # Build parameters array
    $azParams = @(
        'network', 'nsg', 'create',
        '--resource-group', $ResourceGroup,
        '--name', $Name,
        '--location', $Location
    )

    # Add tags if provided
    if ($validatedTags.Count -gt 0) {
        $azParams += '--tags'
        $azParams += $validatedTags
    }

    # Create the NSG
    Write-Host "🔧 Creating Network Security Group '$Name'..." -ForegroundColor Cyan
    $null = az @azParams

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ NSG '$Name' created successfully!" -ForegroundColor Green

        # Create default rules if requested
        if ($CreateDefaultRules) {
            $defaultRules = Get-DefaultRules -RuleProfile $DefaultRuleProfile
            New-DefaultRules -ResourceGroup $ResourceGroup -NsgName $Name -Rules $defaultRules
        }

        # Display created NSG details
        Write-Host "`n📝 NSG Details:" -ForegroundColor Yellow
        $nsgDetails = az network nsg show --resource-group $ResourceGroup --name $Name --output table
        Write-Host $nsgDetails -ForegroundColor White

        # Show rules summary
        Write-Host "`n📋 Security Rules Summary:" -ForegroundColor Yellow
        $rulesDetails = az network nsg rule list --resource-group $ResourceGroup --nsg-name $Name --output table
        Write-Host $rulesDetails -ForegroundColor White
    }
    else {
        throw "Failed to create NSG. Exit code: $LASTEXITCODE"
    }
}
catch {
    Write-Error "❌ Failed to create NSG: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
