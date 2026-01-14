<#
.SYNOPSIS
    Describes AWS Subnets using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script provides comprehensive information about subnets including
    CIDR blocks, availability zones, route tables, and network configurations.

.PARAMETER SubnetId
    The ID of a specific subnet to describe.

.PARAMETER SubnetIds
    Comma-separated list of subnet IDs to describe.

.PARAMETER VpcId
    Filter subnets by VPC ID.

.PARAMETER AvailabilityZone
    Filter subnets by availability zone.

.PARAMETER State
    Filter subnets by state (available, pending).

.PARAMETER FilterByTag
    Filter subnets by tag (format: Key=Value).

.PARAMETER ShowRouteTable
    Show associated route table information for each subnet.

.PARAMETER ShowNetworkAcl
    Show associated Network ACL information for each subnet.

.PARAMETER ShowAvailableIps
    Calculate and show available IP addresses in each subnet.

.PARAMETER OutputFormat
    Output format: table, json, or detailed.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-describe-subnets.ps1

.EXAMPLE
    .\aws-cli-describe-subnets.ps1 -SubnetId "subnet-12345678" -ShowRouteTable -ShowNetworkAcl

.EXAMPLE
    .\aws-cli-describe-subnets.ps1 -VpcId "vpc-12345678" -OutputFormat "table"

.EXAMPLE
    .\aws-cli-describe-subnets.ps1 -AvailabilityZone "us-east-1a" -ShowAvailableIps

.EXAMPLE
    .\aws-cli-describe-subnets.ps1 -FilterByTag "Environment=Production"

.NOTES
    Author: XOAP
    Date: 2025-08-06
    Version: 1.0
    Requires: AWS CLI v2.16+

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId,

    [Parameter(Mandatory = $false)]
    [string]$SubnetIds,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId,

    [Parameter(Mandatory = $false)]
    [string]$AvailabilityZone,

    [Parameter(Mandatory = $false)]
    [ValidateSet('available', 'pending')]
    [string]$State,

    [Parameter(Mandatory = $false)]
    [string]$FilterByTag,

    [Parameter(Mandatory = $false)]
    [switch]$ShowRouteTable,

    [Parameter(Mandatory = $false)]
    [switch]$ShowNetworkAcl,

    [Parameter(Mandatory = $false)]
    [switch]$ShowAvailableIps,

    [Parameter(Mandatory = $false)]
    [ValidateSet('table', 'json', 'detailed')]
    [string]$OutputFormat = 'detailed',

    [Parameter(Mandatory = $false)]
    [string]$Region,

    [Parameter(Mandatory = $false)]
    [string]$Profile
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

# Function to calculate available IPs in a subnet
function Get-AvailableIpCount {
    param([string]$CidrBlock, [int]$AvailableIpAddressCount)

    # Extract network bits from CIDR
    $networkBits = [int]($CidrBlock -split '/')[1]
    $hostBits = 32 - $networkBits
    $totalIps = [math]::Pow(2, $hostBits)

    # AWS reserves 5 IPs per subnet
    $awsReservedIps = 5
    $maxAvailable = $totalIps - $awsReservedIps

    return @{
        TotalIps = $totalIps
        MaxAvailable = $maxAvailable
        CurrentAvailable = $AvailableIpAddressCount
        UsedIps = $maxAvailable - $AvailableIpAddressCount
        UtilizationPercent = [math]::Round((($maxAvailable - $AvailableIpAddressCount) / $maxAvailable) * 100, 1)
    }
}

try {
    # Build base AWS CLI arguments
    $awsArgs = @()
    if ($Region) { $awsArgs += @('--region', $Region) }
    if ($Profile) { $awsArgs += @('--profile', $Profile) }

    Write-Output "🏠 Describing AWS Subnets"
    if ($Region) { Write-Output "Region: $Region" }

    # Build describe command
    $describeArgs = @('ec2', 'describe-subnets') + $awsArgs

    # Add filters
    $filters = @()

    if ($VpcId) {
        $filters += "Name=vpc-id,Values=$VpcId"
        Write-Output "Filter: VPC ID = $VpcId"
    }

    if ($AvailabilityZone) {
        $filters += "Name=availability-zone,Values=$AvailabilityZone"
        Write-Output "Filter: Availability Zone = $AvailabilityZone"
    }

    if ($State) {
        $filters += "Name=state,Values=$State"
        Write-Output "Filter: State = $State"
    }

    if ($FilterByTag) {
        if ($FilterByTag -match '^(.+)=(.+)$') {
            $tagKey = $matches[1]
            $tagValue = $matches[2]
            $filters += "Name=tag:$tagKey,Values=$tagValue"
            Write-Output "Filter: Tag $tagKey = $tagValue"
        } else {
            throw "FilterByTag must be in format 'Key=Value'"
        }
    }

    if ($filters.Count -gt 0) {
        $describeArgs += @('--filters')
        $describeArgs += $filters
    }

    # Add specific subnet IDs
    $targetSubnetIds = @()
    if ($SubnetId) {
        $targetSubnetIds += $SubnetId
    }
    if ($SubnetIds) {
        $targetSubnetIds += $SubnetIds -split ',' | ForEach-Object { $_.Trim() }
    }

    if ($targetSubnetIds.Count -gt 0) {
        $describeArgs += @('--subnet-ids')
        $describeArgs += $targetSubnetIds
        Write-Output "Specific Subnets: $($targetSubnetIds -join ', ')"
    }

    # Execute the describe command
    $describeResult = aws @describeArgs --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to describe subnets: $describeResult"
    }

    $subnetsData = $describeResult | ConvertFrom-Json

    if ($subnetsData.Subnets.Count -eq 0) {
        Write-Output "No subnets found matching the specified criteria."
        exit 0
    }

    Write-Output "`n📊 Found $($subnetsData.Subnets.Count) Subnet(s)"

    # Display results based on output format
    switch ($OutputFormat) {
        'json' {
            Write-Output "`n📄 Subnets (JSON):"
            $subnetsData.Subnets | ConvertTo-Json -Depth 5
        }

        'table' {
            Write-Output "`n📊 Subnets Summary:"
            Write-Output "=" * 140
            Write-Output "Subnet ID`t`tVPC ID`t`t`tAZ`t`tCIDR Block`t`tAvailable IPs`tPublic`tName"
            Write-Output "-" * 140

            foreach ($subnet in $subnetsData.Subnets) {
                $name = "N/A"
                if ($subnet.Tags) {
                    $nameTag = $subnet.Tags | Where-Object { $_.Key -eq 'Name' } | Select-Object -First 1
                    if ($nameTag) { $name = $nameTag.Value }
                }

                Write-Output "$($subnet.SubnetId)`t$($subnet.VpcId)`t$($subnet.AvailabilityZone)`t$($subnet.CidrBlock.PadRight(15))`t$($subnet.AvailableIpAddressCount.ToString().PadLeft(5))`t`t$($subnet.MapPublicIpOnLaunch)`t$name"
            }
        }

        'detailed' {
            foreach ($subnet in $subnetsData.Subnets) {
                Write-Output "`n" + "=" * 80
                Write-Output "Subnet: $($subnet.SubnetId)"
                Write-Output "=" * 80

                # Basic information
                Write-Output "VPC ID: $($subnet.VpcId)"
                Write-Output "Availability Zone: $($subnet.AvailabilityZone)"
                Write-Output "Availability Zone ID: $($subnet.AvailabilityZoneId)"
                Write-Output "CIDR Block: $($subnet.CidrBlock)"
                Write-Output "State: $($subnet.State)"
                Write-Output "Owner ID: $($subnet.OwnerId)"

                # IPv6 information
                if ($subnet.Ipv6CidrBlockAssociationSet -and $subnet.Ipv6CidrBlockAssociationSet.Count -gt 0) {
                    Write-Output "`n🔗 IPv6 CIDR Blocks:"
                    foreach ($ipv6Block in $subnet.Ipv6CidrBlockAssociationSet) {
                        Write-Output "  • $($ipv6Block.Ipv6CidrBlock) (State: $($ipv6Block.Ipv6CidrBlockState.State))"
                    }
                }

                # Public IP configuration
                Write-Output "`n🌐 Public IP Configuration:"
                Write-Output "  Auto-assign Public IP: $($subnet.MapPublicIpOnLaunch)"
                Write-Output "  Auto-assign IPv6: $($subnet.AssignIpv6AddressOnCreation)"

                # IP Address utilization
                if ($ShowAvailableIps -or $OutputFormat -eq 'detailed') {
                    Write-Output "`n📊 IP Address Utilization:"
                    $ipStats = Get-AvailableIpCount -CidrBlock $subnet.CidrBlock -AvailableIpAddressCount $subnet.AvailableIpAddressCount

                    Write-Output "  Total IPs in CIDR: $($ipStats.TotalIps)"
                    Write-Output "  AWS Reserved IPs: 5"
                    Write-Output "  Max Available IPs: $($ipStats.MaxAvailable)"
                    Write-Output "  Currently Available: $($ipStats.CurrentAvailable)"
                    Write-Output "  Currently Used: $($ipStats.UsedIps)"
                    Write-Output "  Utilization: $($ipStats.UtilizationPercent)%"

                    if ($ipStats.UtilizationPercent -gt 80) {
                        Write-Output "  ⚠️  High utilization warning!"
                    }
                }

                # Tags
                if ($subnet.Tags -and $subnet.Tags.Count -gt 0) {
                    Write-Output "`n🏷️  Tags:"
                    foreach ($tag in $subnet.Tags) {
                        Write-Output "  • $($tag.Key): $($tag.Value)"
                    }
                }

                # Route Table information
                if ($ShowRouteTable -or $OutputFormat -eq 'detailed') {
                    Write-Output "`n🛣️  Route Table Information:"

                    # Get associated route table
                    $rtbResult = aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$($subnet.SubnetId)" @awsArgs --output json 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $rtbData = $rtbResult | ConvertFrom-Json

                        if ($rtbData.RouteTables.Count -gt 0) {
                            $routeTable = $rtbData.RouteTables[0]
                            Write-Output "  Associated Route Table: $($routeTable.RouteTableId)"

                            # Check for internet connectivity
                            $igwRoute = $routeTable.Routes | Where-Object { $_.GatewayId -like 'igw-*' -and $_.DestinationCidrBlock -eq '0.0.0.0/0' }
                            $natRoute = $routeTable.Routes | Where-Object { $_.NatGatewayId -and $_.DestinationCidrBlock -eq '0.0.0.0/0' }

                            if ($igwRoute) {
                                Write-Output "  ✅ Public Subnet (Internet Gateway route)"
                            } elseif ($natRoute) {
                                Write-Output "  🔒 Private Subnet with NAT (NAT Gateway route)"
                            } else {
                                Write-Output "  🔒 Private Subnet (no internet route)"
                            }
                        } else {
                            # Check main route table
                            $mainRtbResult = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$($subnet.VpcId)" "Name=association.main,Values=true" @awsArgs --output json 2>&1

                            if ($LASTEXITCODE -eq 0) {
                                $mainRtbData = $mainRtbResult | ConvertFrom-Json
                                if ($mainRtbData.RouteTables.Count -gt 0) {
                                    Write-Output "  Using Main Route Table: $($mainRtbData.RouteTables[0].RouteTableId)"
                                }
                            }
                        }
                    }
                }

                # Network ACL information
                if ($ShowNetworkAcl -or $OutputFormat -eq 'detailed') {
                    Write-Output "`n🛡️  Network ACL Information:"

                    $naclResult = aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=$($subnet.SubnetId)" @awsArgs --output json 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $naclData = $naclResult | ConvertFrom-Json

                        if ($naclData.NetworkAcls.Count -gt 0) {
                            $networkAcl = $naclData.NetworkAcls[0]
                            Write-Output "  Network ACL: $($networkAcl.NetworkAclId)"
                            Write-Output "  Default ACL: $($networkAcl.IsDefault)"
                            Write-Output "  Entries: $($networkAcl.Entries.Count)"
                        }
                    }
                }

                # Subnet analysis
                Write-Output "`n🔍 Subnet Analysis:"

                # Determine subnet type
                if ($subnet.MapPublicIpOnLaunch) {
                    Write-Output "  📍 Public subnet (auto-assigns public IPs)"
                } else {
                    Write-Output "  📍 Private subnet (no auto-assigned public IPs)"
                }

                # Availability zone insights
                Write-Output "  📍 Located in Availability Zone: $($subnet.AvailabilityZone)"

                # CIDR analysis
                $networkBits = [int]($subnet.CidrBlock -split '/')[1]
                if ($networkBits -ge 28) {
                    Write-Output "  ⚠️  Small subnet (/$networkBits) - consider larger CIDR for scalability"
                } elseif ($networkBits -le 20) {
                    Write-Output "  ✅ Large subnet (/$networkBits) - good for scalability"
                }
            }
        }
    }

    # Summary statistics
    if ($OutputFormat -eq 'detailed') {
        Write-Output "`n📈 Summary Statistics:"

        $totalIps = ($subnetsData.Subnets | ForEach-Object {
            $networkBits = [int]($_.CidrBlock -split '/')[1]
            [math]::Pow(2, 32 - $networkBits) - 5
        } | Measure-Object -Sum).Sum

        $availableIps = ($subnetsData.Subnets | ForEach-Object { $_.AvailableIpAddressCount } | Measure-Object -Sum).Sum
        $usedIps = $totalIps - $availableIps
        $utilizationPercent = if ($totalIps -gt 0) { [math]::Round(($usedIps / $totalIps) * 100, 1) } else { 0 }

        Write-Output "  • Total Subnets: $($subnetsData.Subnets.Count)"
        Write-Output "  • Total Available IPs: $totalIps"
        Write-Output "  • Currently Available: $availableIps"
        Write-Output "  • Currently Used: $usedIps"
        Write-Output "  • Overall Utilization: $utilizationPercent%"

        # Availability Zone distribution
        $azGroups = $subnetsData.Subnets | Group-Object AvailabilityZone
        Write-Output "`n📊 Distribution by Availability Zone:"
        foreach ($group in $azGroups) {
            Write-Output "  • $($group.Name): $($group.Count) subnet(s)"
        }

        # VPC distribution
        $vpcGroups = $subnetsData.Subnets | Group-Object VpcId
        Write-Output "`n📊 Distribution by VPC:"
        foreach ($group in $vpcGroups) {
            Write-Output "  • $($group.Name): $($group.Count) subnet(s)"
        }

        # Public vs Private
        $publicSubnets = ($subnetsData.Subnets | Where-Object { $_.MapPublicIpOnLaunch }).Count
        $privateSubnets = $subnetsData.Subnets.Count - $publicSubnets
        Write-Output "`n📊 Public vs Private:"
        Write-Output "  • Public Subnets: $publicSubnets"
        Write-Output "  • Private Subnets: $privateSubnets"
    }

    Write-Output "`n💡 Useful Commands:"
    Write-Output "# Modify subnet to auto-assign public IPs:"
    Write-Output "aws ec2 modify-subnet-attribute --subnet-id subnet-xxxxxxxx --map-public-ip-on-launch"
    Write-Output ""
    Write-Output "# Associate subnet with route table:"
    Write-Output "aws ec2 associate-route-table --route-table-id rtb-xxxxxxxx --subnet-id subnet-xxxxxxxx"

    Write-Output "`n✅ Subnet description completed."

} catch {
    Write-Error "Failed to describe subnets: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
