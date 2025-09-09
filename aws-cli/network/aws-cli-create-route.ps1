<#
.SYNOPSIS
    Creates routes in AWS Route Tables using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script creates routes in route tables with support for various destination types
    including internet gateways, NAT gateways, VPC peering connections, and network interfaces.

.PARAMETER RouteTableId
    The ID of the route table where the route will be created.

.PARAMETER DestinationCidrBlock
    The IPv4 CIDR block for the route destination.

.PARAMETER DestinationIpv6CidrBlock
    The IPv6 CIDR block for the route destination.

.PARAMETER GatewayId
    The ID of an internet gateway or VPC gateway for the route.

.PARAMETER NatGatewayId
    The ID of a NAT gateway for the route.

.PARAMETER NetworkInterfaceId
    The ID of a network interface for the route.

.PARAMETER InstanceId
    The ID of an EC2 instance for the route.

.PARAMETER VpcPeeringConnectionId
    The ID of a VPC peering connection for the route.

.PARAMETER TransitGatewayId
    The ID of a transit gateway for the route.

.PARAMETER LocalGatewayId
    The ID of a local gateway for the route.

.PARAMETER CarrierGatewayId
    The ID of a carrier gateway for the route.

.PARAMETER VpcEndpointId
    The ID of a VPC endpoint for the route.

.PARAMETER DryRun
    Perform a dry run to validate parameters without creating the route.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-create-route.ps1 -RouteTableId "rtb-12345678" -DestinationCidrBlock "0.0.0.0/0" -GatewayId "igw-12345678"

.EXAMPLE
    .\aws-cli-create-route.ps1 -RouteTableId "rtb-12345678" -DestinationCidrBlock "10.1.0.0/16" -VpcPeeringConnectionId "pcx-12345678"

.EXAMPLE
    .\aws-cli-create-route.ps1 -RouteTableId "rtb-12345678" -DestinationCidrBlock "0.0.0.0/0" -NatGatewayId "nat-12345678"

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
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^rtb-[a-zA-Z0-9]{8,}$')]
    [string]$RouteTableId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$DestinationCidrBlock,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^([a-fA-F0-9:]+:+)+[a-fA-F0-9]+/\d{1,3}$')]
    [string]$DestinationIpv6CidrBlock,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(igw|vgw)-[a-zA-Z0-9]{8,}$')]
    [string]$GatewayId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^nat-[a-zA-Z0-9]{8,}$')]
    [string]$NatGatewayId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^eni-[a-zA-Z0-9]{8,}$')]
    [string]$NetworkInterfaceId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^pcx-[a-zA-Z0-9]{8,}$')]
    [string]$VpcPeeringConnectionId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^tgw-[a-zA-Z0-9]{8,}$')]
    [string]$TransitGatewayId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^lgw-[a-zA-Z0-9]{8,}$')]
    [string]$LocalGatewayId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^cagw-[a-zA-Z0-9]{8,}$')]
    [string]$CarrierGatewayId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^vpce-[a-zA-Z0-9]{8,}$')]
    [string]$VpcEndpointId,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

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
    if ($DryRun) { $awsArgs += @('--dry-run') }

    Write-Output "🛣️  Creating route in route table: $RouteTableId"
    if ($DryRun) { Write-Output "Mode: DRY RUN - No changes will be made" }

    # Validate destination
    if (-not $DestinationCidrBlock -and -not $DestinationIpv6CidrBlock) {
        throw "Either DestinationCidrBlock or DestinationIpv6CidrBlock must be specified."
    }

    # Count target parameters
    $targets = @($GatewayId, $NatGatewayId, $NetworkInterfaceId, $InstanceId, $VpcPeeringConnectionId, $TransitGatewayId, $LocalGatewayId, $CarrierGatewayId, $VpcEndpointId) | Where-Object { $_ }
    
    if ($targets.Count -eq 0) {
        throw "At least one target (Gateway, NAT Gateway, Network Interface, Instance, etc.) must be specified."
    }
    
    if ($targets.Count -gt 1) {
        throw "Only one target can be specified per route."
    }

    # Build route creation command
    $routeArgs = @(
        'ec2', 'create-route',
        '--route-table-id', $RouteTableId
    ) + $awsArgs

    # Add destination
    if ($DestinationCidrBlock) {
        $routeArgs += @('--destination-cidr-block', $DestinationCidrBlock)
        Write-Output "Destination: $DestinationCidrBlock (IPv4)"
    }
    if ($DestinationIpv6CidrBlock) {
        $routeArgs += @('--destination-ipv6-cidr-block', $DestinationIpv6CidrBlock)
        Write-Output "Destination: $DestinationIpv6CidrBlock (IPv6)"
    }

    # Add target
    if ($GatewayId) {
        $routeArgs += @('--gateway-id', $GatewayId)
        Write-Output "Target: Internet/VPN Gateway ($GatewayId)"
    }
    if ($NatGatewayId) {
        $routeArgs += @('--nat-gateway-id', $NatGatewayId)
        Write-Output "Target: NAT Gateway ($NatGatewayId)"
    }
    if ($NetworkInterfaceId) {
        $routeArgs += @('--network-interface-id', $NetworkInterfaceId)
        Write-Output "Target: Network Interface ($NetworkInterfaceId)"
    }
    if ($InstanceId) {
        $routeArgs += @('--instance-id', $InstanceId)
        Write-Output "Target: EC2 Instance ($InstanceId)"
    }
    if ($VpcPeeringConnectionId) {
        $routeArgs += @('--vpc-peering-connection-id', $VpcPeeringConnectionId)
        Write-Output "Target: VPC Peering Connection ($VpcPeeringConnectionId)"
    }
    if ($TransitGatewayId) {
        $routeArgs += @('--transit-gateway-id', $TransitGatewayId)
        Write-Output "Target: Transit Gateway ($TransitGatewayId)"
    }
    if ($LocalGatewayId) {
        $routeArgs += @('--local-gateway-id', $LocalGatewayId)
        Write-Output "Target: Local Gateway ($LocalGatewayId)"
    }
    if ($CarrierGatewayId) {
        $routeArgs += @('--carrier-gateway-id', $CarrierGatewayId)
        Write-Output "Target: Carrier Gateway ($CarrierGatewayId)"
    }
    if ($VpcEndpointId) {
        $routeArgs += @('--vpc-endpoint-id', $VpcEndpointId)
        Write-Output "Target: VPC Endpoint ($VpcEndpointId)"
    }

    # Verify route table exists before creating route
    Write-Output "`n🔍 Verifying route table exists..."
    $rtbResult = aws ec2 describe-route-tables --route-table-ids $RouteTableId @awsArgs --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Route table $RouteTableId not found or not accessible: $rtbResult"
    }

    $rtbData = $rtbResult | ConvertFrom-Json
    $routeTable = $rtbData.RouteTables[0]
    
    Write-Output "✅ Route table verified:"
    Write-Output "  VPC ID: $($routeTable.VpcId)"
    Write-Output "  Current routes: $($routeTable.Routes.Count)"

    # Check for existing conflicting routes
    Write-Output "`n🔍 Checking for conflicting routes..."
    $conflictingRoute = $null
    
    if ($DestinationCidrBlock) {
        $conflictingRoute = $routeTable.Routes | Where-Object { $_.DestinationCidrBlock -eq $DestinationCidrBlock }
    }
    if ($DestinationIpv6CidrBlock) {
        $conflictingRoute = $routeTable.Routes | Where-Object { $_.DestinationIpv6CidrBlock -eq $DestinationIpv6CidrBlock }
    }

    if ($conflictingRoute) {
        Write-Warning "⚠️  Conflicting route found:"
        Write-Output "  Destination: $($conflictingRoute.DestinationCidrBlock)$($conflictingRoute.DestinationIpv6CidrBlock)"
        Write-Output "  Current target: $($conflictingRoute.GatewayId)$($conflictingRoute.NatGatewayId)$($conflictingRoute.NetworkInterfaceId)$($conflictingRoute.InstanceId)"
        Write-Output "  State: $($conflictingRoute.State)"
        
        if (-not $DryRun) {
            throw "A route with this destination already exists. Use replace-route to modify it."
        } else {
            Write-Output "⚠️  DRY RUN: Would fail due to conflicting route"
        }
    }

    # Create the route
    if (-not $DryRun) {
        Write-Output "`n🚀 Creating route..."
        $result = aws @routeArgs --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            $routeData = $result | ConvertFrom-Json
            Write-Output "✅ Route created successfully!"
            
            if ($routeData.Return) {
                Write-Output "Creation status: Success"
            }

            # Verify the route was created
            Write-Output "`n🔍 Verifying route creation..."
            $verifyResult = aws ec2 describe-route-tables --route-table-ids $RouteTableId @awsArgs --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $verifyData = $verifyResult | ConvertFrom-Json
                $updatedRouteTable = $verifyData.RouteTables[0]
                
                Write-Output "✅ Route table updated:"
                Write-Output "  Total routes: $($updatedRouteTable.Routes.Count)"
                
                # Find and display the new route
                $newRoute = $null
                if ($DestinationCidrBlock) {
                    $newRoute = $updatedRouteTable.Routes | Where-Object { $_.DestinationCidrBlock -eq $DestinationCidrBlock }
                }
                if ($DestinationIpv6CidrBlock) {
                    $newRoute = $updatedRouteTable.Routes | Where-Object { $_.DestinationIpv6CidrBlock -eq $DestinationIpv6CidrBlock }
                }

                if ($newRoute) {
                    Write-Output "`n📋 New Route Details:"
                    Write-Output "  Destination: $($newRoute.DestinationCidrBlock)$($newRoute.DestinationIpv6CidrBlock)"
                    Write-Output "  Target: $($newRoute.GatewayId)$($newRoute.NatGatewayId)$($newRoute.NetworkInterfaceId)$($newRoute.InstanceId)$($newRoute.VpcPeeringConnectionId)$($newRoute.TransitGatewayId)"
                    Write-Output "  State: $($newRoute.State)"
                    Write-Output "  Origin: $($newRoute.Origin)"
                }
            }

            Write-Output "`n💡 Route Management Tips:"
            Write-Output "• Use 'aws ec2 describe-route-tables --route-table-ids $RouteTableId' to view all routes"
            Write-Output "• Monitor route state to ensure it becomes 'active'"
            Write-Output "• Use 'aws ec2 replace-route' to modify existing routes"
            Write-Output "• Use 'aws ec2 delete-route' to remove routes when no longer needed"

        } else {
            Write-Error "Failed to create route: $result"
        }
    } else {
        Write-Output "`n✅ DRY RUN: Route creation command validated successfully"
        Write-Output "Command that would be executed:"
        Write-Output "aws $($routeArgs -join ' ')"
    }

} catch {
    Write-Error "Failed to create route: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
