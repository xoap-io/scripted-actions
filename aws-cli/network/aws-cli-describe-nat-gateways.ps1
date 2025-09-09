<#
.SYNOPSIS
    Describes NAT Gateways in AWS using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script retrieves detailed information about NAT Gateways including their state,
    associated Elastic IPs, network interfaces, and related route tables.

.PARAMETER NatGatewayId
    The ID(s) of specific NAT Gateway(s) to describe. Can be a single ID or array of IDs.

.PARAMETER VpcId
    Filter NAT Gateways by VPC ID.

.PARAMETER SubnetId
    Filter NAT Gateways by Subnet ID.

.PARAMETER State
    Filter NAT Gateways by state (pending, failed, available, deleting, deleted).

.PARAMETER ConnectivityType
    Filter NAT Gateways by connectivity type (public, private).

.PARAMETER ShowRoutes
    Include information about route tables that reference these NAT Gateways.

.PARAMETER ShowCosts
    Include estimated cost information for running NAT Gateways.

.PARAMETER OutputFormat
    Output format: table, json, or detailed (default: table).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-describe-nat-gateways.ps1

.EXAMPLE
    .\aws-cli-describe-nat-gateways.ps1 -NatGatewayId "nat-12345678"

.EXAMPLE
    .\aws-cli-describe-nat-gateways.ps1 -VpcId "vpc-12345678" -ShowRoutes

.EXAMPLE
    .\aws-cli-describe-nat-gateways.ps1 -State "available" -ShowCosts

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
    [ValidatePattern('^nat-[a-zA-Z0-9]{8,}$')]
    [string[]]$NatGatewayId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId,

    [Parameter(Mandatory = $false)]
    [ValidateSet("pending", "failed", "available", "deleting", "deleted")]
    [string]$State,

    [Parameter(Mandatory = $false)]
    [ValidateSet("public", "private")]
    [string]$ConnectivityType,

    [Parameter(Mandatory = $false)]
    [switch]$ShowRoutes,

    [Parameter(Mandatory = $false)]
    [switch]$ShowCosts,

    [Parameter(Mandatory = $false)]
    [ValidateSet("table", "json", "detailed")]
    [string]$OutputFormat = "table",

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

try {
    # Build base AWS CLI arguments
    $awsArgs = @()
    if ($Region) { $awsArgs += @('--region', $Region) }
    if ($Profile) { $awsArgs += @('--profile', $Profile) }

    Write-Output "🔍 Describing NAT Gateways..."
    if ($Region) { Write-Output "Region: $Region" }

    # Build describe command
    $describeArgs = @('ec2', 'describe-nat-gateways') + $awsArgs + @('--output', 'json')

    # Add filters
    $filters = @()
    
    if ($VpcId) {
        $filters += "Name=vpc-id,Values=$VpcId"
    }
    
    if ($SubnetId) {
        $filters += "Name=subnet-id,Values=$SubnetId"
    }
    
    if ($State) {
        $filters += "Name=state,Values=$State"
    }
    
    if ($ConnectivityType) {
        $filters += "Name=connectivity-type,Values=$ConnectivityType"
    }

    if ($filters.Count -gt 0) {
        $describeArgs += @('--filters')
        $describeArgs += $filters
    }

    # Add specific NAT Gateway IDs if provided
    if ($NatGatewayId -and $NatGatewayId.Count -gt 0) {
        $describeArgs += @('--nat-gateway-ids')
        $describeArgs += $NatGatewayId
    }

    # Execute describe command
    $result = aws @describeArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to describe NAT Gateways: $result"
    }

    $data = $result | ConvertFrom-Json
    $natGateways = $data.NatGateways

    if ($natGateways.Count -eq 0) {
        Write-Output "📭 No NAT Gateways found matching the specified criteria."
        exit 0
    }

    Write-Output "✅ Found $($natGateways.Count) NAT Gateway(s)"

    # Get route table information if requested
    $routeTablesData = $null
    if ($ShowRoutes) {
        Write-Output "`n🔍 Retrieving route table information..."
        $routeResult = aws ec2 describe-route-tables @awsArgs --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $routeTablesData = ($routeResult | ConvertFrom-Json).RouteTables
        } else {
            Write-Warning "Could not retrieve route table information: $routeResult"
        }
    }

    # Output results based on format
    switch ($OutputFormat) {
        "json" {
            Write-Output "`n📄 JSON Output:"
            $natGateways | ConvertTo-Json -Depth 10
        }
        
        "table" {
            Write-Output "`n📊 NAT Gateway Summary:"
            Write-Output ("{0,-20} {1,-12} {2,-15} {3,-15} {4,-20} {5,-15}" -f "NAT Gateway ID", "State", "Type", "VPC ID", "Subnet ID", "Public IP")
            Write-Output ("{0,-20} {1,-12} {2,-15} {3,-15} {4,-20} {5,-15}" -f ("-" * 20), ("-" * 12), ("-" * 15), ("-" * 15), ("-" * 20), ("-" * 15))
            
            foreach ($nat in $natGateways) {
                $publicIp = ""
                if ($nat.NatGatewayAddresses -and $nat.NatGatewayAddresses.Count -gt 0) {
                    $publicIp = ($nat.NatGatewayAddresses | Where-Object { $_.PublicIp } | Select-Object -First 1).PublicIp
                    if (-not $publicIp) { $publicIp = "N/A" }
                } else {
                    $publicIp = "N/A"
                }
                
                Write-Output ("{0,-20} {1,-12} {2,-15} {3,-15} {4,-20} {5,-15}" -f $nat.NatGatewayId, $nat.State, $nat.ConnectivityType, $nat.VpcId, $nat.SubnetId, $publicIp)
            }
        }
        
        "detailed" {
            foreach ($nat in $natGateways) {
                Write-Output "`n" + ("=" * 80)
                Write-Output "🌐 NAT Gateway: $($nat.NatGatewayId)"
                Write-Output ("=" * 80)
                
                Write-Output "📋 Basic Information:"
                Write-Output "  State: $($nat.State)"
                Write-Output "  Connectivity Type: $($nat.ConnectivityType)"
                Write-Output "  VPC ID: $($nat.VpcId)"
                Write-Output "  Subnet ID: $($nat.SubnetId)"
                Write-Output "  Created: $($nat.CreateTime)"
                
                if ($nat.DeleteTime) {
                    Write-Output "  Deleted: $($nat.DeleteTime)"
                }
                
                if ($nat.FailureCode) {
                    Write-Output "  Failure Code: $($nat.FailureCode)"
                    Write-Output "  Failure Message: $($nat.FailureMessage)"
                }

                # Network Interface Information
                if ($nat.NatGatewayAddresses -and $nat.NatGatewayAddresses.Count -gt 0) {
                    Write-Output "`n🔌 Network Interfaces:"
                    foreach ($address in $nat.NatGatewayAddresses) {
                        Write-Output "  Interface: $($address.NetworkInterfaceId)"
                        if ($address.AllocationId) {
                            Write-Output "    Elastic IP: $($address.PublicIp)"
                            Write-Output "    Allocation ID: $($address.AllocationId)"
                        }
                        if ($address.PrivateIp) {
                            Write-Output "    Private IP: $($address.PrivateIp)"
                        }
                        if ($address.Status) {
                            Write-Output "    Status: $($address.Status)"
                        }
                    }
                }

                # Tags
                if ($nat.Tags -and $nat.Tags.Count -gt 0) {
                    Write-Output "`n🏷️  Tags:"
                    foreach ($tag in $nat.Tags) {
                        Write-Output "  $($tag.Key): $($tag.Value)"
                    }
                }

                # Route information
                if ($ShowRoutes -and $routeTablesData) {
                    $referencingRoutes = @()
                    foreach ($routeTable in $routeTablesData) {
                        $natRoutes = $routeTable.Routes | Where-Object { $_.NatGatewayId -eq $nat.NatGatewayId }
                        if ($natRoutes) {
                            foreach ($route in $natRoutes) {
                                $referencingRoutes += [PSCustomObject]@{
                                    RouteTableId = $routeTable.RouteTableId
                                    VpcId = $routeTable.VpcId
                                    Destination = "$($route.DestinationCidrBlock)$($route.DestinationIpv6CidrBlock)"
                                    State = $route.State
                                    Associations = $routeTable.Associations.Count
                                    SubnetAssociations = ($routeTable.Associations | Where-Object { $_.SubnetId }).SubnetId -join ", "
                                }
                            }
                        }
                    }

                    if ($referencingRoutes.Count -gt 0) {
                        Write-Output "`n🛣️  Referenced by Routes:"
                        foreach ($route in $referencingRoutes) {
                            Write-Output "  Route Table: $($route.RouteTableId)"
                            Write-Output "    Destination: $($route.Destination)"
                            Write-Output "    State: $($route.State)"
                            if ($route.SubnetAssociations) {
                                Write-Output "    Associated Subnets: $($route.SubnetAssociations)"
                            }
                        }
                    } else {
                        Write-Output "`n🛣️  Referenced by Routes: None"
                    }
                }

                # Cost information
                if ($ShowCosts -and $nat.State -eq "available") {
                    $hourlyCost = switch ($nat.ConnectivityType) {
                        "public" { 0.045 }  # Approximate hourly cost
                        "private" { 0.045 }
                        default { 0.045 }
                    }
                    
                    Write-Output "`n💰 Cost Information:"
                    Write-Output "  Estimated hourly cost: ~`$$hourlyCost USD"
                    Write-Output "  Estimated daily cost: ~`$$([math]::Round($hourlyCost * 24, 2)) USD"
                    Write-Output "  Estimated monthly cost: ~`$$([math]::Round($hourlyCost * 24 * 30, 2)) USD"
                    Write-Output "  Note: Plus data processing charges (~`$0.045/GB processed)"
                }
            }
        }
    }

    # Summary statistics
    if ($OutputFormat -ne "json") {
        Write-Output "`n📊 Summary Statistics:"
        
        $stateGroups = $natGateways | Group-Object -Property State
        foreach ($group in $stateGroups) {
            Write-Output "  $($group.Name): $($group.Count)"
        }
        
        $typeGroups = $natGateways | Group-Object -Property ConnectivityType
        foreach ($group in $typeGroups) {
            Write-Output "  $($group.Name) NAT Gateways: $($group.Count)"
        }
        
        $vpcGroups = $natGateways | Group-Object -Property VpcId
        Write-Output "  Unique VPCs: $($vpcGroups.Count)"
        
        # Cost summary
        if ($ShowCosts) {
            $availableNats = ($natGateways | Where-Object { $_.State -eq "available" }).Count
            if ($availableNats -gt 0) {
                $totalHourlyCost = $availableNats * 0.045
                Write-Output "`n💰 Total Estimated Costs:"
                Write-Output "  Total hourly cost: ~`$$totalHourlyCost USD"
                Write-Output "  Total daily cost: ~`$$([math]::Round($totalHourlyCost * 24, 2)) USD"
                Write-Output "  Total monthly cost: ~`$$([math]::Round($totalHourlyCost * 24 * 30, 2)) USD"
                Write-Output "  (Plus data processing charges for active NAT Gateways)"
            }
        }
    }

    Write-Output "`n💡 Management Tips:"
    Write-Output "• Use 'aws ec2 create-nat-gateway' to create new NAT Gateways"
    Write-Output "• Use 'aws ec2 delete-nat-gateway' to delete unused NAT Gateways"
    Write-Output "• Monitor data processing charges in CloudWatch"
    Write-Output "• Consider NAT instances for lower-cost alternatives in dev environments"
    Write-Output "• Use VPC endpoints to reduce NAT Gateway data processing for AWS services"

} catch {
    Write-Error "Failed to describe NAT Gateways: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
