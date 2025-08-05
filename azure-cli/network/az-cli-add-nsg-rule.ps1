<#
.SYNOPSIS
    Add a security rule to an Azure Network Security Group using Azure CLI.

.DESCRIPTION
    This script adds a security rule to an existing Azure Network Security Group using the Azure CLI.
    Security rules control inbound and outbound traffic for network interfaces and subnets.
    
    The script uses the Azure CLI command: az network nsg rule create

.PARAMETER NSGName
    The name of the existing Network Security Group.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group containing the NSG.

.PARAMETER RuleName
    The name of the security rule to create.

.PARAMETER Priority
    The priority of the rule (100-4096). Lower numbers have higher priority.

.PARAMETER Direction
    The direction of the rule.
    Valid values: 'Inbound', 'Outbound'

.PARAMETER Access
    Whether to allow or deny the traffic.
    Valid values: 'Allow', 'Deny'

.PARAMETER Protocol
    The network protocol.
    Valid values: 'Tcp', 'Udp', 'Icmp', 'Esp', 'Ah', '*'

.PARAMETER SourceAddressPrefix
    Source address prefix (e.g., '10.0.0.0/8', 'VirtualNetwork', 'Internet', '*').

.PARAMETER SourcePortRange
    Source port range (e.g., '80', '80-90', '*').

.PARAMETER DestinationAddressPrefix
    Destination address prefix (e.g., '10.0.0.0/8', 'VirtualNetwork', 'Internet', '*').

.PARAMETER DestinationPortRange
    Destination port range (e.g., '443', '80-90', '*').

.PARAMETER Description
    Description of the security rule.

.EXAMPLE
    .\az-cli-add-nsg-rule.ps1 -NSGName "web-nsg" -ResourceGroup "MyRG" -RuleName "AllowHTTP" -Priority 100 -Direction "Inbound" -Access "Allow" -Protocol "Tcp" -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange "80"
    
    Creates a rule to allow HTTP traffic from anywhere.

.EXAMPLE
    .\az-cli-add-nsg-rule.ps1 -NSGName "app-nsg" -ResourceGroup "MyRG" -RuleName "AllowSSH" -Priority 200 -Direction "Inbound" -Access "Allow" -Protocol "Tcp" -SourceAddressPrefix "10.0.0.0/16" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange "22" -Description "Allow SSH from VNet"
    
    Creates a rule to allow SSH from the virtual network with a description.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/nsg/rule

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the existing Network Security Group")]
    [ValidateNotNullOrEmpty()]
    [string]$NSGName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the security rule")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [string]$RuleName,

    [Parameter(Mandatory = $true, HelpMessage = "The priority of the rule (100-4096)")]
    [ValidateRange(100, 4096)]
    [int]$Priority,

    [Parameter(Mandatory = $true, HelpMessage = "The direction of the rule")]
    [ValidateSet('Inbound', 'Outbound')]
    [string]$Direction,

    [Parameter(Mandatory = $true, HelpMessage = "Whether to allow or deny the traffic")]
    [ValidateSet('Allow', 'Deny')]
    [string]$Access,

    [Parameter(Mandatory = $true, HelpMessage = "The network protocol")]
    [ValidateSet('Tcp', 'Udp', 'Icmp', 'Esp', 'Ah', '*')]
    [string]$Protocol,

    [Parameter(Mandatory = $true, HelpMessage = "Source address prefix")]
    [ValidateNotNullOrEmpty()]
    [string]$SourceAddressPrefix,

    [Parameter(Mandatory = $true, HelpMessage = "Source port range")]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePortRange,

    [Parameter(Mandatory = $true, HelpMessage = "Destination address prefix")]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationAddressPrefix,

    [Parameter(Mandatory = $true, HelpMessage = "Destination port range")]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationPortRange,

    [Parameter(HelpMessage = "Description of the security rule")]
    [string]$Description
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

    # Verify the NSG exists
    Write-Host "Verifying Network Security Group exists..." -ForegroundColor Yellow
    $nsgCheck = az network nsg show --name $NSGName --resource-group $ResourceGroup 2>$null
    if (-not $nsgCheck) {
        throw "Network Security Group '$NSGName' not found in resource group '$ResourceGroup'"
    }
    Write-Host "✓ Network Security Group '$NSGName' found" -ForegroundColor Green

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'nsg', 'rule', 'create',
        '--nsg-name', $NSGName,
        '--resource-group', $ResourceGroup,
        '--name', $RuleName,
        '--priority', $Priority,
        '--direction', $Direction,
        '--access', $Access,
        '--protocol', $Protocol,
        '--source-address-prefixes', $SourceAddressPrefix,
        '--source-port-ranges', $SourcePortRange,
        '--destination-address-prefixes', $DestinationAddressPrefix,
        '--destination-port-ranges', $DestinationPortRange
    )

    # Add optional parameters
    if ($Description) { 
        $azParams += '--description', $Description 
    }

    Write-Host "Creating NSG security rule..." -ForegroundColor Yellow
    Write-Host "NSG Name: $NSGName" -ForegroundColor Cyan
    Write-Host "Rule Name: $RuleName" -ForegroundColor Cyan
    Write-Host "Priority: $Priority" -ForegroundColor Cyan
    Write-Host "Direction: $Direction" -ForegroundColor Cyan
    Write-Host "Access: $Access" -ForegroundColor Cyan
    Write-Host "Protocol: $Protocol" -ForegroundColor Cyan
    Write-Host "Source: $SourceAddressPrefix : $SourcePortRange" -ForegroundColor Cyan
    Write-Host "Destination: $DestinationAddressPrefix : $DestinationPortRange" -ForegroundColor Cyan

    # Execute Azure CLI command
    $result = & az @azParams 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ NSG security rule created successfully!" -ForegroundColor Green
        
        # Parse and display rule information
        try {
            $ruleInfo = $result | ConvertFrom-Json
            Write-Host "Rule Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($ruleInfo.name)" -ForegroundColor White
            Write-Host "  Priority: $($ruleInfo.priority)" -ForegroundColor White
            Write-Host "  Direction: $($ruleInfo.direction)" -ForegroundColor White
            Write-Host "  Access: $($ruleInfo.access)" -ForegroundColor White
            Write-Host "  Protocol: $($ruleInfo.protocol)" -ForegroundColor White
            Write-Host "  Source: $($ruleInfo.sourceAddressPrefix):$($ruleInfo.sourcePortRange)" -ForegroundColor White
            Write-Host "  Destination: $($ruleInfo.destinationAddressPrefix):$($ruleInfo.destinationPortRange)" -ForegroundColor White
            
            if ($ruleInfo.description) {
                Write-Host "  Description: $($ruleInfo.description)" -ForegroundColor White
            }
        }
        catch {
            Write-Host "Rule created successfully, but could not parse detailed information." -ForegroundColor Yellow
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create NSG security rule" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
