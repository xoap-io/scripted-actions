<#
.SYNOPSIS
    Create an Azure Network Security Group using Azure CLI.

.DESCRIPTION
    This script creates an Azure Network Security Group (NSG) using the Azure CLI.
    NSGs contain security rules that allow or deny network traffic to resources connected to Azure Virtual Networks.

    The script uses the Azure CLI command: az network nsg create

.PARAMETER Name
    The name of the Network Security Group to create.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the NSG will be created.

.PARAMETER Location
    The Azure region where the NSG will be created.

.PARAMETER Tags
    Tags to apply to the NSG in the format 'key1=value1 key2=value2'.

.EXAMPLE
    .\az-cli-create-network-security-group.ps1 -Name "web-nsg" -ResourceGroup "MyRG" -Location "eastus"

    Creates a basic network security group.

.EXAMPLE
    .\az-cli-create-network-security-group.ps1 -Name "app-nsg" -ResourceGroup "MyRG" -Location "westus2" -Tags "environment=production tier=application"

    Creates a network security group with tags.

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
    https://learn.microsoft.com/en-us/cli/azure/network/nsg

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview

.COMPONENT
    Azure CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Network Security Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9\-\.\_]{0,78}[a-zA-Z0-9\_]$|^[a-zA-Z0-9]$', ErrorMessage = "NSG name must be 1-80 characters, start and end with alphanumeric or underscore, contain only letters, numbers, hyphens, periods, and underscores")]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where the NSG will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(HelpMessage = "Tags in the format 'key1=value1 key2=value2'")]
    [string]$Tags
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

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'nsg', 'create',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--location', $Location
    )

    # Add optional parameters
    if ($Tags) {
        $azParams += '--tags', $Tags
    }

    Write-Host "Creating Network Security Group..." -ForegroundColor Yellow
    Write-Host "NSG Name: $Name" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan
    Write-Host "Location: $Location" -ForegroundColor Cyan

    # Execute Azure CLI command
    $result = & az @azParams 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Network Security Group created successfully!" -ForegroundColor Green

        # Parse and display NSG information
        try {
            $nsgInfo = $result | ConvertFrom-Json
            Write-Host "NSG Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($nsgInfo.name)" -ForegroundColor White
            Write-Host "  Resource Group: $($nsgInfo.resourceGroup)" -ForegroundColor White
            Write-Host "  Location: $($nsgInfo.location)" -ForegroundColor White
            Write-Host "  Resource ID: $($nsgInfo.id)" -ForegroundColor White

            if ($nsgInfo.defaultSecurityRules -and $nsgInfo.defaultSecurityRules.Count -gt 0) {
                Write-Host "  Default Rules: $($nsgInfo.defaultSecurityRules.Count) rules created" -ForegroundColor White
            }

            if ($nsgInfo.tags -and $nsgInfo.tags.PSObject.Properties.Count -gt 0) {
                Write-Host "  Tags:" -ForegroundColor White
                $nsgInfo.tags.PSObject.Properties | ForEach-Object {
                    Write-Host "    $($_.Name): $($_.Value)" -ForegroundColor White
                }
            }
        }
        catch {
            Write-Host "NSG created successfully, but could not parse detailed information." -ForegroundColor Yellow
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
