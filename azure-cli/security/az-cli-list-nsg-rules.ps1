<#
.SYNOPSIS
    List and analyze Azure Network Security Group rules using Azure CLI.

.DESCRIPTION
    This script lists and analyzes Azure Network Security Group rules using the Azure CLI with comprehensive filtering and reporting capabilities.
    Supports filtering by NSG, resource group, rule properties, and security analysis.
    Includes rule conflict detection, security gap analysis, and export capabilities.

    The script uses the Azure CLI command: az network nsg rule list

.PARAMETER ResourceGroup
    Name of the Azure Resource Group (optional, lists all if not specified).

.PARAMETER NsgName
    Name of the specific Network Security Group (optional, lists all if not specified).

.PARAMETER RuleName
    Name of a specific rule to display (optional).

.PARAMETER Direction
    Filter rules by direction (Inbound/Outbound).

.PARAMETER Access
    Filter rules by access type (Allow/Deny).

.PARAMETER Protocol
    Filter rules by protocol.

.PARAMETER Priority
    Filter rules by priority range (e.g., "100-1000").

.PARAMETER SourceAddress
    Filter rules containing specific source address or CIDR.

.PARAMETER DestinationPort
    Filter rules by destination port.

.PARAMETER ShowConflicts
    Analyze and show potential rule conflicts.

.PARAMETER ShowGaps
    Analyze and show potential security gaps.

.PARAMETER OutputFormat
    Output format: Table, JSON, CSV, or Summary.

.PARAMETER ExportPath
    Export results to file (CSV or JSON based on OutputFormat).

.PARAMETER IncludeDefaultRules
    Include Azure default security rules in the output.

.EXAMPLE
    .\az-cli-list-nsg-rules.ps1 -ResourceGroup "rg-web" -NsgName "web-nsg" -OutputFormat "Table"

.EXAMPLE
    .\az-cli-list-nsg-rules.ps1 -Direction "Inbound" -Access "Allow" -ShowConflicts -OutputFormat "Summary"

.EXAMPLE
    .\az-cli-list-nsg-rules.ps1 -ResourceGroup "rg-prod" -DestinationPort "80,443" -ExportPath "web-rules.csv"

.EXAMPLE
    .\az-cli-list-nsg-rules.ps1 -ShowGaps -ShowConflicts -OutputFormat "JSON" -ExportPath "security-analysis.json"

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later

.LINK
    https://docs.microsoft.com/en-us/cli/azure/network/nsg/rule

.COMPONENT
    Azure CLI Network Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the Network Security Group")]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$NsgName,

    [Parameter(Mandatory = $false, HelpMessage = "Name of a specific rule")]
    [ValidateLength(1, 80)]
    [string]$RuleName,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by traffic direction")]
    [ValidateSet('Inbound', 'Outbound')]
    [string]$Direction,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by access type")]
    [ValidateSet('Allow', 'Deny')]
    [string]$Access,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by protocol")]
    [ValidateSet('*', 'Ah', 'Esp', 'Icmp', 'Tcp', 'Udp')]
    [string]$Protocol,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by priority range (e.g., 100-1000)")]
    [ValidatePattern('^\d+-\d+$')]
    [string]$Priority,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by source address")]
    [string]$SourceAddress,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by destination port (comma-separated)")]
    [string]$DestinationPort,

    [Parameter(Mandatory = $false, HelpMessage = "Analyze rule conflicts")]
    [switch]$ShowConflicts,

    [Parameter(Mandatory = $false, HelpMessage = "Analyze security gaps")]
    [switch]$ShowGaps,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('Table', 'JSON', 'CSV', 'Summary')]
    [string]$OutputFormat = 'Table',

    [Parameter(Mandatory = $false, HelpMessage = "Export to file path")]
    [string]$ExportPath,

    [Parameter(Mandatory = $false, HelpMessage = "Include Azure default rules")]
    [switch]$IncludeDefaultRules
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

# Function to get all NSGs or validate specific NSG
function Get-NetworkSecurityGroups {
    param($ResourceGroup, $NsgName)

    try {
        $nsgs = @()

        if ($NsgName -and $ResourceGroup) {
            # Specific NSG
            Write-Host "🔍 Validating NSG '$NsgName' in resource group '$ResourceGroup'..." -ForegroundColor Cyan
            $nsg = az network nsg show --resource-group $ResourceGroup --name $NsgName --query "{name:name, resourceGroup:resourceGroup, location:location}" --output json | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0) {
                $nsgs += $nsg
                Write-Host "✅ NSG '$NsgName' found" -ForegroundColor Green
            }
            else {
                throw "NSG '$NsgName' not found in resource group '$ResourceGroup'"
            }
        }
        elseif ($ResourceGroup) {
            # All NSGs in resource group
            Write-Host "🔍 Getting NSGs in resource group '$ResourceGroup'..." -ForegroundColor Cyan
            $nsgs = az network nsg list --resource-group $ResourceGroup --query "[].{name:name, resourceGroup:resourceGroup, location:location}" --output json | ConvertFrom-Json
            Write-Host "✅ Found $($nsgs.Count) NSG(s) in resource group" -ForegroundColor Green
        }
        else {
            # All NSGs in subscription
            Write-Host "🔍 Getting all NSGs in subscription..." -ForegroundColor Cyan
            $nsgs = az network nsg list --query "[].{name:name, resourceGroup:resourceGroup, location:location}" --output json | ConvertFrom-Json
            Write-Host "✅ Found $($nsgs.Count) NSG(s) in subscription" -ForegroundColor Green
        }

        return $nsgs
    }
    catch {
        Write-Error "Failed to get NSGs: $($_.Exception.Message)"
        return @()
    }
}

# Function to get rules for an NSG
function Get-NSGRules {
    param($ResourceGroup, $NsgName, $IncludeDefaults)

    try {
        $query = "[].{name:name, priority:priority, direction:direction, access:access, protocol:protocol, sourceAddressPrefix:sourceAddressPrefix, sourcePortRange:sourcePortRange, destinationAddressPrefix:destinationAddressPrefix, destinationPortRange:destinationPortRange, description:description, source:sourceAddressPrefixes[0], destination:destinationAddressPrefixes[0]}"

        $rules = az network nsg rule list --resource-group $ResourceGroup --nsg-name $NsgName --query $query --output json | ConvertFrom-Json

        if (-not $IncludeDefaults) {
            # Filter out default Azure rules
            $rules = $rules | Where-Object { $_.name -notmatch '^(AllowVnetInBound|AllowAzureLoadBalancerInBound|DenyAllInBound|AllowVnetOutBound|AllowInternetOutBound|DenyAllOutBound)$' }
        }

        # Add NSG context to each rule
        foreach ($rule in $rules) {
            $rule | Add-Member -NotePropertyName 'nsgName' -NotePropertyValue $NsgName
            $rule | Add-Member -NotePropertyName 'resourceGroup' -NotePropertyValue $ResourceGroup
        }

        return $rules
    }
    catch {
        Write-Warning "Failed to get rules for NSG '$NsgName': $($_.Exception.Message)"
        return @()
    }
}

# Function to filter rules based on criteria
function Get-FilteredRules {
    param($Rules, $Filters)

    $filteredRules = $Rules

    if ($Filters.RuleName) {
        $filteredRules = $filteredRules | Where-Object { $_.name -like "*$($Filters.RuleName)*" }
    }

    if ($Filters.Direction) {
        $filteredRules = $filteredRules | Where-Object { $_.direction -eq $Filters.Direction }
    }

    if ($Filters.Access) {
        $filteredRules = $filteredRules | Where-Object { $_.access -eq $Filters.Access }
    }

    if ($Filters.Protocol) {
        $filteredRules = $filteredRules | Where-Object { $_.protocol -eq $Filters.Protocol }
    }

    if ($Filters.Priority) {
        $range = $Filters.Priority -split '-'
        $minPriority = [int]$range[0]
        $maxPriority = [int]$range[1]
        $filteredRules = $filteredRules | Where-Object { $_.priority -ge $minPriority -and $_.priority -le $maxPriority }
    }

    if ($Filters.SourceAddress) {
        $filteredRules = $filteredRules | Where-Object {
            ($_.sourceAddressPrefix -like "*$($Filters.SourceAddress)*") -or
            ($_.source -like "*$($Filters.SourceAddress)*")
        }
    }

    if ($Filters.DestinationPort) {
        $ports = $Filters.DestinationPort -split ','
        $filteredRules = $filteredRules | Where-Object {
            $rule = $_
            $ports | ForEach-Object {
                ($rule.destinationPortRange -like "*$_*") -or ($rule.destinationPortRange -eq "*")
            }
        }
    }

    return $filteredRules
}

# Function to analyze rule conflicts
function Find-RuleConflicts {
    param($Rules)

    Write-Host "🔍 Analyzing rule conflicts..." -ForegroundColor Cyan
    $conflicts = @()

    for ($i = 0; $i -lt $Rules.Count; $i++) {
        for ($j = $i + 1; $j -lt $Rules.Count; $j++) {
            $rule1 = $Rules[$i]
            $rule2 = $Rules[$j]

            # Check for same NSG and direction
            if ($rule1.nsgName -eq $rule2.nsgName -and $rule1.direction -eq $rule2.direction) {
                # Check for overlapping criteria with different actions
                if ($rule1.access -ne $rule2.access) {
                    $conflict = @{
                        Type = "Access Conflict"
                        Rule1 = "$($rule1.nsgName)/$($rule1.name) (Priority: $($rule1.priority), Access: $($rule1.access))"
                        Rule2 = "$($rule2.nsgName)/$($rule2.name) (Priority: $($rule2.priority), Access: $($rule2.access))"
                        Description = "Rules with overlapping criteria but different access types"
                    }
                    $conflicts += $conflict
                }

                # Check for duplicate priorities
                if ($rule1.priority -eq $rule2.priority) {
                    $conflict = @{
                        Type = "Priority Conflict"
                        Rule1 = "$($rule1.nsgName)/$($rule1.name)"
                        Rule2 = "$($rule2.nsgName)/$($rule2.name)"
                        Description = "Rules with identical priority ($($rule1.priority))"
                    }
                    $conflicts += $conflict
                }
            }
        }
    }

    return $conflicts
}

# Function to analyze security gaps
function Find-SecurityGaps {
    param($Rules)

    Write-Host "🔍 Analyzing security gaps..." -ForegroundColor Cyan
    $gaps = @()

    # Check for common security issues
    $inboundRules = $Rules | Where-Object { $_.direction -eq "Inbound" }
    $null = $Rules | Where-Object { $_.direction -eq "Outbound" }

    # Check for overly permissive rules
    $permissiveRules = $Rules | Where-Object {
        ($_.sourceAddressPrefix -eq "*" -or $_.source -eq "*") -and
        ($_.destinationPortRange -eq "*") -and
        $_.access -eq "Allow"
    }

    if ($permissiveRules.Count -gt 0) {
        $gaps += @{
            Type = "Overly Permissive Rules"
            Count = $permissiveRules.Count
            Description = "Rules allowing all traffic from any source to any destination"
            Rules = $permissiveRules.name -join ", "
        }
    }

    # Check for missing deny-all rules
    $denyAllInbound = $inboundRules | Where-Object { $_.access -eq "Deny" -and $_.priority -ge 4000 }
    if ($denyAllInbound.Count -eq 0) {
        $gaps += @{
            Type = "Missing Deny-All Inbound"
            Count = 1
            Description = "No high-priority deny-all inbound rule found"
            Rules = "Consider adding a deny-all rule with priority 4000+"
        }
    }

    # Check for common vulnerable ports
    $vulnerablePorts = @("22", "3389", "1433", "3306", "5432")
    foreach ($port in $vulnerablePorts) {
        $exposedRules = $inboundRules | Where-Object {
            $_.destinationPortRange -eq $port -and
            ($_.sourceAddressPrefix -eq "*" -or $_.source -eq "*") -and
            $_.access -eq "Allow"
        }

        if ($exposedRules.Count -gt 0) {
            $portName = switch ($port) {
                "22" { "SSH" }
                "3389" { "RDP" }
                "1433" { "SQL Server" }
                "3306" { "MySQL" }
                "5432" { "PostgreSQL" }
            }

            $gaps += @{
                Type = "Exposed $portName Port"
                Count = $exposedRules.Count
                Description = "Port $port ($portName) exposed to the internet"
                Rules = $exposedRules.name -join ", "
            }
        }
    }

    return $gaps
}

# Function to format output
function Format-Output {
    param($Rules, $Conflicts, $Gaps, $Format)

    switch ($Format) {
        'Table' {
            if ($Rules.Count -gt 0) {
                Write-Host "`n📋 NSG Rules:" -ForegroundColor Yellow
                $Rules | Select-Object nsgName, name, priority, direction, access, protocol, sourceAddressPrefix, destinationPortRange, description | Format-Table -AutoSize
            }
        }
        'JSON' {
            $output = @{
                Rules = $Rules
                Conflicts = $Conflicts
                SecurityGaps = $Gaps
                Summary = @{
                    TotalRules = $Rules.Count
                    ConflictCount = $Conflicts.Count
                    SecurityGapCount = $Gaps.Count
                }
            }
            return $output | ConvertTo-Json -Depth 10
        }
        'CSV' {
            return $Rules | ConvertTo-Csv -NoTypeInformation
        }
        'Summary' {
            Write-Host "`n📊 NSG Rules Summary:" -ForegroundColor Yellow
            Write-Host "   Total Rules: $($Rules.Count)" -ForegroundColor White
            Write-Host "   Inbound Rules: $(($Rules | Where-Object { $_.direction -eq 'Inbound' }).Count)" -ForegroundColor White
            Write-Host "   Outbound Rules: $(($Rules | Where-Object { $_.direction -eq 'Outbound' }).Count)" -ForegroundColor White
            Write-Host "   Allow Rules: $(($Rules | Where-Object { $_.access -eq 'Allow' }).Count)" -ForegroundColor White
            Write-Host "   Deny Rules: $(($Rules | Where-Object { $_.access -eq 'Deny' }).Count)" -ForegroundColor White
            Write-Host "   Conflicts Found: $($Conflicts.Count)" -ForegroundColor White
            Write-Host "   Security Gaps: $($Gaps.Count)" -ForegroundColor White
        }
    }
}

# Function to show conflicts
function Show-Conflicts {
    param($Conflicts)

    if ($Conflicts.Count -gt 0) {
        Write-Host "`n⚠️ Rule Conflicts Found:" -ForegroundColor Red
        foreach ($conflict in $Conflicts) {
            Write-Host "   Type: $($conflict.Type)" -ForegroundColor Yellow
            Write-Host "   Rule 1: $($conflict.Rule1)" -ForegroundColor White
            Write-Host "   Rule 2: $($conflict.Rule2)" -ForegroundColor White
            Write-Host "   Description: $($conflict.Description)" -ForegroundColor Gray
            Write-Host ""
        }
    }
    else {
        Write-Host "`n✅ No rule conflicts detected" -ForegroundColor Green
    }
}

# Function to show security gaps
function Show-SecurityGaps {
    param($Gaps)

    if ($Gaps.Count -gt 0) {
        Write-Host "`n🔍 Security Gaps Found:" -ForegroundColor Yellow
        foreach ($gap in $Gaps) {
            Write-Host "   Type: $($gap.Type)" -ForegroundColor Red
            Write-Host "   Count: $($gap.Count)" -ForegroundColor White
            Write-Host "   Description: $($gap.Description)" -ForegroundColor Gray
            Write-Host "   Rules: $($gap.Rules)" -ForegroundColor White
            Write-Host ""
        }
    }
    else {
        Write-Host "`n✅ No security gaps detected" -ForegroundColor Green
    }
}

# Main execution
try {
    Write-Host "🚀 Starting NSG Rules Analysis" -ForegroundColor Green
    Write-Host "==============================" -ForegroundColor Green

    # Validate Azure CLI
    if (-not (Test-AzureCLI)) {
        exit 1
    }

    # Get NSGs
    $nsgs = Get-NetworkSecurityGroups -ResourceGroup $ResourceGroup -NsgName $NsgName
    if ($nsgs.Count -eq 0) {
        Write-Warning "No NSGs found matching the criteria"
        exit 0
    }

    # Collect all rules
    $allRules = @()
    foreach ($nsg in $nsgs) {
        Write-Host "📋 Processing NSG: $($nsg.name)" -ForegroundColor Cyan
        $rules = Get-NSGRules -ResourceGroup $nsg.resourceGroup -NsgName $nsg.name -IncludeDefaults $IncludeDefaultRules
        $allRules += $rules
    }

    # Apply filters
    $filters = @{
        RuleName = $RuleName
        Direction = $Direction
        Access = $Access
        Protocol = $Protocol
        Priority = $Priority
        SourceAddress = $SourceAddress
        DestinationPort = $DestinationPort
    }

    $filteredRules = Get-FilteredRules -Rules $allRules -Filters $filters

    # Analyze conflicts and gaps if requested
    $conflicts = @()
    $gaps = @()

    if ($ShowConflicts) {
        $conflicts = Find-RuleConflicts -Rules $filteredRules
    }

    if ($ShowGaps) {
        $gaps = Find-SecurityGaps -Rules $filteredRules
    }

    # Format and display output
    if ($OutputFormat -eq 'JSON' -or $ExportPath) {
        $output = Format-Output -Rules $filteredRules -Conflicts $conflicts -Gaps $gaps -Format $OutputFormat

        if ($ExportPath) {
            $output | Out-File -FilePath $ExportPath -Encoding UTF8
            Write-Host "✅ Results exported to: $ExportPath" -ForegroundColor Green
        }
        else {
            Write-Output $output
        }
    }
    else {
        Format-Output -Rules $filteredRules -Conflicts $conflicts -Gaps $gaps -Format $OutputFormat
    }

    # Show analysis results
    if ($ShowConflicts) {
        Show-Conflicts -Conflicts $conflicts
    }

    if ($ShowGaps) {
        Show-SecurityGaps -Gaps $gaps
    }
}
catch {
    Write-Error "❌ Failed to analyze NSG rules: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
