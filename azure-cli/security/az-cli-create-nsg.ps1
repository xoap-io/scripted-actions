<#
.SYNOPSIS
    Create an Azure Network Security Group (NSG) rule using Azure CLI.

.DESCRIPTION
    This script creates an Azure Network Security Group rule using the Azure CLI with comprehensive validation and security best practices.
    Supports all NSG rule parameters including source/destination prefixes, ports, protocols, and Application Security Groups.
    Includes priority validation, rule conflict detection, and security compliance checks.

    The script uses the Azure CLI command: az network nsg rule create

.PARAMETER Name
    Name of the Network Security Group rule.

.PARAMETER NsgName
    Name of the existing Network Security Group.

.PARAMETER Priority
    Priority of the rule (100-4096). Lower numbers have higher priority.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group containing the NSG.

.PARAMETER Access
    Whether to allow or deny traffic matching this rule.

.PARAMETER Description
    Description of the NSG rule for documentation purposes.

.PARAMETER DestinationAddressPrefixes
    Destination address prefixes or CIDR ranges (space-separated for multiple).

.PARAMETER DestinationPortRanges
    Destination port ranges (space-separated for multiple, e.g., "80 443" or "8000-8999").

.PARAMETER DestinationAsgs
    Destination Application Security Group names (space-separated for multiple).

.PARAMETER Direction
    Direction of traffic for the rule.

.PARAMETER NoWait
    Execute command in background without waiting for completion.

.PARAMETER Protocol
    Network protocol for the rule.

.PARAMETER SourceAddressPrefixes
    Source address prefixes or CIDR ranges (space-separated for multiple).

.PARAMETER SourcePortRanges
    Source port ranges (space-separated for multiple, e.g., "80 443" or "1000-2000").

.PARAMETER SourceAsgs
    Source Application Security Group names (space-separated for multiple).

.EXAMPLE
    .\az-cli-create-nsg.ps1 -Name "AllowHTTP" -NsgName "web-nsg" -Priority 100 -ResourceGroup "rg-web" -Access "Allow" -Protocol "Tcp" -Direction "Inbound" -SourceAddressPrefixes "*" -DestinationAddressPrefixes "10.0.1.0/24" -DestinationPortRanges "80" -Description "Allow HTTP traffic to web servers"

.EXAMPLE
    .\az-cli-create-nsg.ps1 -Name "DenyAllOutbound" -NsgName "secure-nsg" -Priority 4000 -ResourceGroup "rg-security" -Access "Deny" -Protocol "*" -Direction "Outbound" -SourceAddressPrefixes "*" -DestinationAddressPrefixes "*" -DestinationPortRanges "*" -Description "Default deny all outbound traffic"

.EXAMPLE
    .\az-cli-create-nsg.ps1 -Name "AllowSSHFromJumpbox" -NsgName "app-nsg" -Priority 200 -ResourceGroup "rg-app" -Access "Allow" -Protocol "Tcp" -Direction "Inbound" -SourceAddressPrefixes "10.0.0.10/32" -DestinationAddressPrefixes "10.0.2.0/24" -DestinationPortRanges "22" -Description "Allow SSH from jumpbox to app servers"

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
    Version: 2.0.0
    Requires: Azure CLI version 2.0 or later

    Priority ranges:
    - 100-999: High priority rules (critical services)
    - 1000-2999: Medium priority rules (standard services)
    - 3000-3999: Low priority rules (less critical)
    - 4000-4096: Cleanup rules (deny all, etc.)

.LINK
    https://docs.microsoft.com/en-us/cli/azure/network/nsg/rule

.COMPONENT
    Azure CLI Network Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Network Security Group rule")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the existing Network Security Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$NsgName,

    [Parameter(Mandatory = $true, HelpMessage = "Priority of the rule (100-4096, lower numbers have higher priority)")]
    [ValidateRange(100, 4096)]
    [int]$Priority,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Whether to allow or deny traffic")]
    [ValidateSet('Allow', 'Deny')]
    [string]$Access = 'Allow',

    [Parameter(Mandatory = $false, HelpMessage = "Description of the NSG rule")]
    [ValidateLength(0, 140)]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "Destination address prefixes or CIDR ranges")]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationAddressPrefixes,

    [Parameter(Mandatory = $false, HelpMessage = "Destination port ranges")]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationPortRanges,

    [Parameter(Mandatory = $false, HelpMessage = "Destination Application Security Group names")]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationAsgs,

    [Parameter(Mandatory = $false, HelpMessage = "Direction of traffic")]
    [ValidateSet('Inbound', 'Outbound')]
    [string]$Direction = 'Inbound',

    [Parameter(Mandatory = $false, HelpMessage = "Execute in background without waiting")]
    [switch]$NoWait,

    [Parameter(Mandatory = $false, HelpMessage = "Network protocol")]
    [ValidateSet('*', 'Ah', 'Esp', 'Icmp', 'Tcp', 'Udp')]
    [string]$Protocol = '*',

    [Parameter(Mandatory = $false, HelpMessage = "Source address prefixes or CIDR ranges")]
    [ValidateNotNullOrEmpty()]
    [string]$SourceAddressPrefixes,

    [Parameter(Mandatory = $false, HelpMessage = "Source Application Security Group names")]
    [ValidateNotNullOrEmpty()]
    [string]$SourceAsgs,

    [Parameter(Mandatory = $false, HelpMessage = "Source port ranges")]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePortRanges = '*'
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

# Function to validate NSG exists
function Test-NSGExists {
    param($ResourceGroup, $NsgName)

    try {
        Write-Host "🔍 Validating NSG '$NsgName' exists in resource group '$ResourceGroup'..." -ForegroundColor Cyan
        $nsg = az network nsg show --resource-group $ResourceGroup --name $NsgName --query "name" --output tsv 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($nsg)) {
            throw "NSG '$NsgName' not found in resource group '$ResourceGroup'"
        }
        Write-Host "✅ NSG '$NsgName' found" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "NSG validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to check for existing rule with same name or priority
function Test-NSGRuleConflict {
    param($ResourceGroup, $NsgName, $RuleName, $Priority)

    try {
        Write-Host "🔍 Checking for existing rules with name '$RuleName' or priority '$Priority'..." -ForegroundColor Cyan

        # Check for existing rule with same name
        $existingRuleByName = az network nsg rule show --resource-group $ResourceGroup --nsg-name $NsgName --name $RuleName --query "name" --output tsv 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($existingRuleByName)) {
            throw "A rule with name '$RuleName' already exists in NSG '$NsgName'"
        }

        # Check for existing rule with same priority
        $existingRuleByPriority = az network nsg rule list --resource-group $ResourceGroup --nsg-name $NsgName --query "[?priority=='$Priority'].name" --output tsv 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($existingRuleByPriority)) {
            throw "A rule with priority '$Priority' already exists in NSG '$NsgName': $existingRuleByPriority"
        }

        Write-Host "✅ No conflicts found" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Rule conflict check failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to validate port ranges
function Test-PortRanges {
    param([string]$PortRanges)

    if ([string]::IsNullOrEmpty($PortRanges) -or $PortRanges -eq '*') {
        return $true
    }

    $ports = $PortRanges -split '\s+'
    foreach ($port in $ports) {
        if ($port -match '^\d+$') {
            # Single port
            $portNum = [int]$port
            if ($portNum -lt 1 -or $portNum -gt 65535) {
                throw "Invalid port number: $port (must be 1-65535)"
            }
        }
        elseif ($port -match '^\d+-\d+$') {
            # Port range
            $range = $port -split '-'
            $startPort = [int]$range[0]
            $endPort = [int]$range[1]

            if ($startPort -lt 1 -or $startPort -gt 65535 -or $endPort -lt 1 -or $endPort -gt 65535) {
                throw "Invalid port range: $port (ports must be 1-65535)"
            }
            if ($startPort -gt $endPort) {
                throw "Invalid port range: $port (start port must be less than or equal to end port)"
            }
        }
        else {
            throw "Invalid port format: $port (use single ports or ranges like '80' or '8000-8999')"
        }
    }
    return $true
}

# Function to validate CIDR notation
function Test-CIDRNotation {
    param([string]$AddressPrefixes)

    if ([string]::IsNullOrEmpty($AddressPrefixes) -or $AddressPrefixes -eq '*') {
        return $true
    }

    $prefixes = $AddressPrefixes -split '\s+'
    foreach ($prefix in $prefixes) {
        if ($prefix -eq '*') {
            continue
        }

        if ($prefix -notmatch '^(\d{1,3}\.){3}\d{1,3}(\/\d{1,2})?$') {
            throw "Invalid CIDR notation: $prefix (use format like '10.0.0.0/24' or '192.168.1.1/32')"
        }

        # Validate IP address parts
        $ipPart = ($prefix -split '\/')[0]
        $octets = $ipPart -split '\.'
        foreach ($octet in $octets) {
            if ([int]$octet -gt 255) {
                throw "Invalid IP address in CIDR: $prefix (octets must be 0-255)"
            }
        }

        # Validate subnet mask
        if ($prefix -contains '/') {
            $mask = ($prefix -split '\/')[1]
            if ([int]$mask -gt 32) {
                throw "Invalid subnet mask in CIDR: $prefix (mask must be 0-32)"
            }
        }
    }
    return $true
}

# Function to display rule summary
function Show-RuleSummary {
    param($Parameters)

    Write-Host "`n📋 NSG Rule Configuration Summary:" -ForegroundColor Yellow
    Write-Host "   Rule Name: $($Parameters.Name)" -ForegroundColor White
    Write-Host "   NSG Name: $($Parameters.NsgName)" -ForegroundColor White
    Write-Host "   Priority: $($Parameters.Priority)" -ForegroundColor White
    Write-Host "   Direction: $($Parameters.Direction)" -ForegroundColor White
    Write-Host "   Access: $($Parameters.Access)" -ForegroundColor White
    Write-Host "   Protocol: $($Parameters.Protocol)" -ForegroundColor White

    if ($Parameters.SourceAddressPrefixes) {
        Write-Host "   Source IPs: $($Parameters.SourceAddressPrefixes)" -ForegroundColor White
    }
    if ($Parameters.SourcePortRanges) {
        Write-Host "   Source Ports: $($Parameters.SourcePortRanges)" -ForegroundColor White
    }
    if ($Parameters.DestinationAddressPrefixes) {
        Write-Host "   Destination IPs: $($Parameters.DestinationAddressPrefixes)" -ForegroundColor White
    }
    if ($Parameters.DestinationPortRanges) {
        Write-Host "   Destination Ports: $($Parameters.DestinationPortRanges)" -ForegroundColor White
    }
    if ($Parameters.Description) {
        Write-Host "   Description: $($Parameters.Description)" -ForegroundColor White
    }
    Write-Host ""
}

# Main execution
try {
    Write-Host "🚀 Starting Azure NSG Rule Creation" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green

    # Validate Azure CLI
    if (-not (Test-AzureCLI)) {
        exit 1
    }

    # Validate NSG exists
    if (-not (Test-NSGExists -ResourceGroup $ResourceGroup -NsgName $NsgName)) {
        exit 1
    }

    # Check for conflicts
    if (-not (Test-NSGRuleConflict -ResourceGroup $ResourceGroup -NsgName $NsgName -RuleName $Name -Priority $Priority)) {
        exit 1
    }

    # Validate port ranges if provided
    if ($SourcePortRanges) {
        $null = Test-PortRanges -PortRanges $SourcePortRanges
    }
    if ($DestinationPortRanges) {
        $null = Test-PortRanges -PortRanges $DestinationPortRanges
    }

    # Validate CIDR notation if provided
    if ($SourceAddressPrefixes) {
        $null = Test-CIDRNotation -AddressPrefixes $SourceAddressPrefixes
    }
    if ($DestinationAddressPrefixes) {
        $null = Test-CIDRNotation -AddressPrefixes $DestinationAddressPrefixes
    }

    # Build parameters array
    $azParams = @(
        'network', 'nsg', 'rule', 'create',
        '--resource-group', $ResourceGroup,
        '--nsg-name', $NsgName,
        '--name', $Name,
        '--priority', $Priority.ToString(),
        '--access', $Access,
        '--direction', $Direction,
        '--protocol', $Protocol
    )

    # Add optional parameters
    if ($Description) { $azParams += '--description', $Description }
    if ($SourceAddressPrefixes) { $azParams += '--source-address-prefixes', $SourceAddressPrefixes }
    if ($SourcePortRanges) { $azParams += '--source-port-ranges', $SourcePortRanges }
    if ($DestinationAddressPrefixes) { $azParams += '--destination-address-prefixes', $DestinationAddressPrefixes }
    if ($DestinationPortRanges) { $azParams += '--destination-port-ranges', $DestinationPortRanges }
    if ($SourceAsgs) { $azParams += '--source-asgs', $SourceAsgs }
    if ($DestinationAsgs) { $azParams += '--destination-asgs', $DestinationAsgs }
    if ($NoWait) { $azParams += '--no-wait' }

    # Display configuration summary
    $paramSummary = @{
        Name = $Name
        NsgName = $NsgName
        Priority = $Priority
        Direction = $Direction
        Access = $Access
        Protocol = $Protocol
        SourceAddressPrefixes = $SourceAddressPrefixes
        SourcePortRanges = $SourcePortRanges
        DestinationAddressPrefixes = $DestinationAddressPrefixes
        DestinationPortRanges = $DestinationPortRanges
        Description = $Description
    }
    Show-RuleSummary -Parameters $paramSummary

    # Create the NSG rule
    Write-Host "🔧 Creating NSG rule '$Name'..." -ForegroundColor Cyan
    $null = az @azParams

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ NSG rule '$Name' created successfully!" -ForegroundColor Green

        if (-not $NoWait) {
            # Display created rule details
            Write-Host "`n📝 Rule Details:" -ForegroundColor Yellow
            $ruleDetails = az network nsg rule show --resource-group $ResourceGroup --nsg-name $NsgName --name $Name --output table
            Write-Host $ruleDetails -ForegroundColor White
        }
    }
    else {
        throw "Failed to create NSG rule. Exit code: $LASTEXITCODE"
    }
}
catch {
    Write-Error "❌ Failed to create NSG rule: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
