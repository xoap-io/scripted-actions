<#
.SYNOPSIS
    Replaces existing routes in AWS Route Tables using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script safely replaces existing routes in route tables with new targets.
    Provides validation and impact analysis for route changes.

.PARAMETER RouteTableId
    The ID of the route table containing the route to replace.

.PARAMETER DestinationCidrBlock
    The IPv4 CIDR block of the route to replace.

.PARAMETER DestinationIpv6CidrBlock
    The IPv6 CIDR block of the route to replace.

.PARAMETER GatewayId
    The new ID of an internet gateway or VPC gateway for the route.

.PARAMETER NatGatewayId
    The new ID of a NAT gateway for the route.

.PARAMETER NetworkInterfaceId
    The new ID of a network interface for the route.

.PARAMETER InstanceId
    The new ID of an EC2 instance for the route.

.PARAMETER VpcPeeringConnectionId
    The new ID of a VPC peering connection for the route.

.PARAMETER TransitGatewayId
    The new ID of a transit gateway for the route.

.PARAMETER LocalGatewayId
    The new ID of a local gateway for the route.

.PARAMETER CarrierGatewayId
    The new ID of a carrier gateway for the route.

.PARAMETER VpcEndpointId
    The new ID of a VPC endpoint for the route.

.PARAMETER DryRun
    Perform a dry run to validate parameters without replacing the route.

.PARAMETER Force
    Skip confirmation prompts for potentially disruptive replacements.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-replace-route.ps1 -RouteTableId "rtb-12345678" -DestinationCidrBlock "0.0.0.0/0" -GatewayId "igw-87654321"

.EXAMPLE
    .\aws-cli-replace-route.ps1 -RouteTableId "rtb-12345678" -DestinationCidrBlock "10.1.0.0/16" -NatGatewayId "nat-87654321"

.EXAMPLE
    .\aws-cli-replace-route.ps1 -RouteTableId "rtb-12345678" -DestinationCidrBlock "0.0.0.0/0" -NatGatewayId "nat-87654321" -Force

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/ec2/replace-route.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the route table containing the route to replace")]
    [ValidatePattern('^rtb-[a-zA-Z0-9]{8,}$')]
    [string]$RouteTableId,

    [Parameter(Mandatory = $false, HelpMessage = "The IPv4 CIDR block of the route to replace")]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$DestinationCidrBlock,

    [Parameter(Mandatory = $false, HelpMessage = "The IPv6 CIDR block of the route to replace")]
    [ValidatePattern('^([a-fA-F0-9:]+:+)+[a-fA-F0-9]+/\d{1,3}$')]
    [string]$DestinationIpv6CidrBlock,

    [Parameter(Mandatory = $false, HelpMessage = "The new ID of an internet gateway or VPC gateway for the route")]
    [ValidatePattern('^(igw|vgw)-[a-zA-Z0-9]{8,}$')]
    [string]$GatewayId,

    [Parameter(Mandatory = $false, HelpMessage = "The new ID of a NAT gateway for the route")]
    [ValidatePattern('^nat-[a-zA-Z0-9]{8,}$')]
    [string]$NatGatewayId,

    [Parameter(Mandatory = $false, HelpMessage = "The new ID of a network interface for the route")]
    [ValidatePattern('^eni-[a-zA-Z0-9]{8,}$')]
    [string]$NetworkInterfaceId,

    [Parameter(Mandatory = $false, HelpMessage = "The new ID of an EC2 instance for the route")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $false, HelpMessage = "The new ID of a VPC peering connection for the route")]
    [ValidatePattern('^pcx-[a-zA-Z0-9]{8,}$')]
    [string]$VpcPeeringConnectionId,

    [Parameter(Mandatory = $false, HelpMessage = "The new ID of a transit gateway for the route")]
    [ValidatePattern('^tgw-[a-zA-Z0-9]{8,}$')]
    [string]$TransitGatewayId,

    [Parameter(Mandatory = $false, HelpMessage = "The new ID of a local gateway for the route")]
    [ValidatePattern('^lgw-[a-zA-Z0-9]{8,}$')]
    [string]$LocalGatewayId,

    [Parameter(Mandatory = $false, HelpMessage = "The new ID of a carrier gateway for the route")]
    [ValidatePattern('^cagw-[a-zA-Z0-9]{8,}$')]
    [string]$CarrierGatewayId,

    [Parameter(Mandatory = $false, HelpMessage = "The new ID of a VPC endpoint for the route")]
    [ValidatePattern('^vpce-[a-zA-Z0-9]{8,}$')]
    [string]$VpcEndpointId,

    [Parameter(Mandatory = $false, HelpMessage = "Perform a dry run to validate parameters without replacing the route")]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts for potentially disruptive replacements")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
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

    Write-Output "🔄 Replacing route in route table: $RouteTableId"
    if ($DryRun) { Write-Output "Mode: DRY RUN - No changes will be made" }

    # Validate destination
    if (-not $DestinationCidrBlock -and -not $DestinationIpv6CidrBlock) {
        throw "Either DestinationCidrBlock or DestinationIpv6CidrBlock must be specified."
    }

    if ($DestinationCidrBlock -and $DestinationIpv6CidrBlock) {
        throw "Only one destination (IPv4 or IPv6) can be specified per route replacement."
    }

    # Count target parameters
    $targets = @($GatewayId, $NatGatewayId, $NetworkInterfaceId, $InstanceId, $VpcPeeringConnectionId, $TransitGatewayId, $LocalGatewayId, $CarrierGatewayId, $VpcEndpointId) | Where-Object { $_ }

    if ($targets.Count -eq 0) {
        throw "At least one new target (Gateway, NAT Gateway, Network Interface, Instance, etc.) must be specified."
    }

    if ($targets.Count -gt 1) {
        throw "Only one new target can be specified per route replacement."
    }

    # Get route table details and verify route exists
    Write-Output "`n🔍 Verifying route table and existing route..."
    $rtbResult = aws ec2 describe-route-tables --route-table-ids $RouteTableId @awsArgs --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Route table $RouteTableId not found or not accessible: $rtbResult"
    }

    $rtbData = $rtbResult | ConvertFrom-Json
    $routeTable = $rtbData.RouteTables[0]

    Write-Output "✅ Route table verified:"
    Write-Output "  VPC ID: $($routeTable.VpcId)"
    Write-Output "  Current routes: $($routeTable.Routes.Count)"

    # Find the existing route
    $existingRoute = $null
    $destination = ""

    if ($DestinationCidrBlock) {
        $existingRoute = $routeTable.Routes | Where-Object { $_.DestinationCidrBlock -eq $DestinationCidrBlock }
        $destination = $DestinationCidrBlock
        Write-Output "  Target destination: $DestinationCidrBlock (IPv4)"
    }

    if ($DestinationIpv6CidrBlock) {
        $existingRoute = $routeTable.Routes | Where-Object { $_.DestinationIpv6CidrBlock -eq $DestinationIpv6CidrBlock }
        $destination = $DestinationIpv6CidrBlock
        Write-Output "  Target destination: $DestinationIpv6CidrBlock (IPv6)"
    }

    if (-not $existingRoute) {
        Write-Error "Route with destination $destination not found in route table $RouteTableId. Use create-route to add new routes."
    }

    # Check if this is a system route that can't be replaced
    if ($existingRoute.Origin -eq "CreateRouteTable") {
        Write-Error "Cannot replace local VPC route (Origin: CreateRouteTable). This route is automatically managed by AWS."
    }

    # Display current route details
    Write-Output "`n📋 Current Route:"
    Write-Output "  Destination: $($existingRoute.DestinationCidrBlock)$($existingRoute.DestinationIpv6CidrBlock)"
    Write-Output "  Current target: $($existingRoute.GatewayId)$($existingRoute.NatGatewayId)$($existingRoute.NetworkInterfaceId)$($existingRoute.InstanceId)$($existingRoute.VpcPeeringConnectionId)$($existingRoute.TransitGatewayId)"
    Write-Output "  State: $($existingRoute.State)"
    Write-Output "  Origin: $($existingRoute.Origin)"

    # Determine new target for display
    $newTarget = ""
    if ($GatewayId) { $newTarget = "Internet/VPN Gateway ($GatewayId)" }
    if ($NatGatewayId) { $newTarget = "NAT Gateway ($NatGatewayId)" }
    if ($NetworkInterfaceId) { $newTarget = "Network Interface ($NetworkInterfaceId)" }
    if ($InstanceId) { $newTarget = "EC2 Instance ($InstanceId)" }
    if ($VpcPeeringConnectionId) { $newTarget = "VPC Peering Connection ($VpcPeeringConnectionId)" }
    if ($TransitGatewayId) { $newTarget = "Transit Gateway ($TransitGatewayId)" }
    if ($LocalGatewayId) { $newTarget = "Local Gateway ($LocalGatewayId)" }
    if ($CarrierGatewayId) { $newTarget = "Carrier Gateway ($CarrierGatewayId)" }
    if ($VpcEndpointId) { $newTarget = "VPC Endpoint ($VpcEndpointId)" }

    Write-Output "`n🔄 New Route Target:"
    Write-Output "  New target: $newTarget"

    # Check if this is a potentially disruptive replacement
    $isDisruptive = $false
    $warningMessages = @()

    # Check for default route (0.0.0.0/0 or ::/0)
    if ($destination -eq "0.0.0.0/0" -or $destination -eq "::/0") {
        $isDisruptive = $true
        $warningMessages += "⚠️  WARNING: Replacing default route - this may affect internet connectivity!"
    }

    # Check if route table has associations
    if ($routeTable.Associations -and $routeTable.Associations.Count -gt 0) {
        $subnetAssociations = $routeTable.Associations | Where-Object { $_.SubnetId }
        if ($subnetAssociations.Count -gt 0) {
            $isDisruptive = $true
            $warningMessages += "⚠️  WARNING: Route table is associated with $($subnetAssociations.Count) subnet(s)"
            $warningMessages += "   Affected subnets: $($subnetAssociations.SubnetId -join ', ')"
        }
    }

    # Check for specific target type changes that might be disruptive
    $oldTarget = "$($existingRoute.GatewayId)$($existingRoute.NatGatewayId)$($existingRoute.NetworkInterfaceId)$($existingRoute.InstanceId)$($existingRoute.VpcPeeringConnectionId)$($existingRoute.TransitGatewayId)"
    $newTargetId = "$($GatewayId)$($NatGatewayId)$($NetworkInterfaceId)$($InstanceId)$($VpcPeeringConnectionId)$($TransitGatewayId)$($LocalGatewayId)$($CarrierGatewayId)$($VpcEndpointId)"

    if ($oldTarget -ne $newTargetId) {
        $warningMessages += "⚠️  WARNING: Changing route target from $oldTarget to $newTargetId"

        # Specific warnings for certain changes
        if ($existingRoute.GatewayId -and ($NatGatewayId -or $NetworkInterfaceId -or $InstanceId)) {
            $warningMessages += "   Changing from Internet Gateway to NAT/Instance - this may affect inbound connectivity"
        }
        if ($existingRoute.NatGatewayId -and $GatewayId) {
            $warningMessages += "   Changing from NAT Gateway to Internet Gateway - this may expose private resources"
        }
    }

    # Display warnings
    if ($warningMessages.Count -gt 0) {
        Write-Output "`n🚨 Impact Analysis:"
        foreach ($warning in $warningMessages) {
            Write-Output $warning
        }
    }

    # Confirmation prompt for disruptive changes
    if ($isDisruptive -and -not $Force -and -not $DryRun) {
        Write-Output "`n❓ This replacement may be disruptive. Do you want to continue? (y/N)"
        $confirmation = Read-Host
        if ($confirmation -notmatch '^[Yy]') {
            Write-Output "❌ Route replacement cancelled by user."
            exit 0
        }
    }

    # Build replace route command
    $replaceArgs = @(
        'ec2', 'replace-route',
        '--route-table-id', $RouteTableId
    ) + $awsArgs

    # Add destination
    if ($DestinationCidrBlock) {
        $replaceArgs += @('--destination-cidr-block', $DestinationCidrBlock)
    }
    if ($DestinationIpv6CidrBlock) {
        $replaceArgs += @('--destination-ipv6-cidr-block', $DestinationIpv6CidrBlock)
    }

    # Add new target
    if ($GatewayId) {
        $replaceArgs += @('--gateway-id', $GatewayId)
    }
    if ($NatGatewayId) {
        $replaceArgs += @('--nat-gateway-id', $NatGatewayId)
    }
    if ($NetworkInterfaceId) {
        $replaceArgs += @('--network-interface-id', $NetworkInterfaceId)
    }
    if ($InstanceId) {
        $replaceArgs += @('--instance-id', $InstanceId)
    }
    if ($VpcPeeringConnectionId) {
        $replaceArgs += @('--vpc-peering-connection-id', $VpcPeeringConnectionId)
    }
    if ($TransitGatewayId) {
        $replaceArgs += @('--transit-gateway-id', $TransitGatewayId)
    }
    if ($LocalGatewayId) {
        $replaceArgs += @('--local-gateway-id', $LocalGatewayId)
    }
    if ($CarrierGatewayId) {
        $replaceArgs += @('--carrier-gateway-id', $CarrierGatewayId)
    }
    if ($VpcEndpointId) {
        $replaceArgs += @('--vpc-endpoint-id', $VpcEndpointId)
    }

    # Replace the route
    if (-not $DryRun) {
        Write-Output "`n🔄 Replacing route..."
        $result = aws @replaceArgs --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Output "✅ Route replaced successfully!"

            # Verify the route was replaced
            Write-Output "`n🔍 Verifying route replacement..."
            $verifyResult = aws ec2 describe-route-tables --route-table-ids $RouteTableId @awsArgs --output json 2>&1

            if ($LASTEXITCODE -eq 0) {
                $verifyData = $verifyResult | ConvertFrom-Json
                $updatedRouteTable = $verifyData.RouteTables[0]

                # Find and display the updated route
                $updatedRoute = $null
                if ($DestinationCidrBlock) {
                    $updatedRoute = $updatedRouteTable.Routes | Where-Object { $_.DestinationCidrBlock -eq $DestinationCidrBlock }
                }
                if ($DestinationIpv6CidrBlock) {
                    $updatedRoute = $updatedRouteTable.Routes | Where-Object { $_.DestinationIpv6CidrBlock -eq $DestinationIpv6CidrBlock }
                }

                if ($updatedRoute) {
                    Write-Output "`n📋 Updated Route Details:"
                    Write-Output "  Destination: $($updatedRoute.DestinationCidrBlock)$($updatedRoute.DestinationIpv6CidrBlock)"
                    Write-Output "  New target: $($updatedRoute.GatewayId)$($updatedRoute.NatGatewayId)$($updatedRoute.NetworkInterfaceId)$($updatedRoute.InstanceId)$($updatedRoute.VpcPeeringConnectionId)$($updatedRoute.TransitGatewayId)"
                    Write-Output "  State: $($updatedRoute.State)"
                    Write-Output "  Origin: $($updatedRoute.Origin)"
                }
            }

            Write-Output "`n💡 Post-Replacement Tips:"
            Write-Output "• Test connectivity to ensure the route change works as expected"
            Write-Output "• Monitor route state to ensure it becomes 'active'"
            Write-Output "• Use 'aws ec2 describe-route-tables --route-table-ids $RouteTableId' to view all routes"

            if ($isDisruptive) {
                Write-Output "• Verify that all affected resources maintain proper connectivity"
                Write-Output "• Consider rolling back if issues are discovered"
            }

        } else {
            Write-Error "Failed to replace route: $result"
        }
    } else {
        Write-Output "`n✅ DRY RUN: Route replacement command validated successfully"
        Write-Output "Command that would be executed:"
        Write-Output "aws $($replaceArgs -join ' ')"

        if ($isDisruptive) {
            Write-Output "`n⚠️  DRY RUN: This replacement would be disruptive - review warnings above"
        }
    }

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
