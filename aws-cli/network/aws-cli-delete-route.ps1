<#
.SYNOPSIS
    Deletes routes from AWS Route Tables using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script safely deletes routes from route tables with validation and impact analysis.
    Provides warnings for potentially disruptive deletions.

.PARAMETER RouteTableId
    The ID of the route table from which to delete the route.

.PARAMETER DestinationCidrBlock
    The IPv4 CIDR block of the route to delete.

.PARAMETER DestinationIpv6CidrBlock
    The IPv6 CIDR block of the route to delete.

.PARAMETER DryRun
    Perform a dry run to validate parameters without deleting the route.

.PARAMETER Force
    Skip confirmation prompts for potentially disruptive deletions.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-delete-route.ps1 -RouteTableId "rtb-12345678" -DestinationCidrBlock "10.1.0.0/16"

.EXAMPLE
    .\aws-cli-delete-route.ps1 -RouteTableId "rtb-12345678" -DestinationCidrBlock "0.0.0.0/0" -Force

.EXAMPLE
    .\aws-cli-delete-route.ps1 -RouteTableId "rtb-12345678" -DestinationIpv6CidrBlock "2001:db8::/32"

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
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

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

    Write-Output "🗑️  Deleting route from route table: $RouteTableId"
    if ($DryRun) { Write-Output "Mode: DRY RUN - No changes will be made" }

    # Validate destination
    if (-not $DestinationCidrBlock -and -not $DestinationIpv6CidrBlock) {
        throw "Either DestinationCidrBlock or DestinationIpv6CidrBlock must be specified."
    }

    if ($DestinationCidrBlock -and $DestinationIpv6CidrBlock) {
        throw "Only one destination (IPv4 or IPv6) can be specified per route deletion."
    }

    # Get route table details and verify route exists
    Write-Output "`n🔍 Verifying route table and target route..."
    $rtbResult = aws ec2 describe-route-tables --route-table-ids $RouteTableId @awsArgs --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Route table $RouteTableId not found or not accessible: $rtbResult"
    }

    $rtbData = $rtbResult | ConvertFrom-Json
    $routeTable = $rtbData.RouteTables[0]
    
    Write-Output "✅ Route table verified:"
    Write-Output "  VPC ID: $($routeTable.VpcId)"
    Write-Output "  Current routes: $($routeTable.Routes.Count)"

    # Find the target route
    $targetRoute = $null
    $destination = ""
    
    if ($DestinationCidrBlock) {
        $targetRoute = $routeTable.Routes | Where-Object { $_.DestinationCidrBlock -eq $DestinationCidrBlock }
        $destination = $DestinationCidrBlock
        Write-Output "  Target destination: $DestinationCidrBlock (IPv4)"
    }
    
    if ($DestinationIpv6CidrBlock) {
        $targetRoute = $routeTable.Routes | Where-Object { $_.DestinationIpv6CidrBlock -eq $DestinationIpv6CidrBlock }
        $destination = $DestinationIpv6CidrBlock
        Write-Output "  Target destination: $DestinationIpv6CidrBlock (IPv6)"
    }

    if (-not $targetRoute) {
        Write-Error "Route with destination $destination not found in route table $RouteTableId"
    }

    # Display route details
    Write-Output "`n📋 Route to be deleted:"
    Write-Output "  Destination: $($targetRoute.DestinationCidrBlock)$($targetRoute.DestinationIpv6CidrBlock)"
    Write-Output "  Target: $($targetRoute.GatewayId)$($targetRoute.NatGatewayId)$($targetRoute.NetworkInterfaceId)$($targetRoute.InstanceId)$($targetRoute.VpcPeeringConnectionId)$($targetRoute.TransitGatewayId)"
    Write-Output "  State: $($targetRoute.State)"
    Write-Output "  Origin: $($targetRoute.Origin)"

    # Check if this is a potentially disruptive deletion
    $isDisruptive = $false
    $warningMessages = @()

    # Check for default route (0.0.0.0/0 or ::/0)
    if ($destination -eq "0.0.0.0/0" -or $destination -eq "::/0") {
        $isDisruptive = $true
        $warningMessages += "⚠️  WARNING: Deleting default route - this will remove internet access!"
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

    # Check if deleting NAT Gateway route (might affect outbound connectivity)
    if ($targetRoute.NatGatewayId) {
        $isDisruptive = $true
        $warningMessages += "⚠️  WARNING: Deleting NAT Gateway route - may affect outbound connectivity for private subnets"
    }

    # Display warnings
    if ($warningMessages.Count -gt 0) {
        Write-Output "`n🚨 Impact Analysis:"
        foreach ($warning in $warningMessages) {
            Write-Output $warning
        }
    }

    # Check if this is a system route that can't be deleted
    if ($targetRoute.Origin -eq "CreateRouteTable") {
        Write-Error "Cannot delete local VPC route (Origin: CreateRouteTable). This route is automatically managed by AWS."
    }

    # Confirmation prompt for disruptive changes
    if ($isDisruptive -and -not $Force -and -not $DryRun) {
        Write-Output "`n❓ This deletion may be disruptive. Do you want to continue? (y/N)"
        $confirmation = Read-Host
        if ($confirmation -notmatch '^[Yy]') {
            Write-Output "❌ Route deletion cancelled by user."
            exit 0
        }
    }

    # Build delete route command
    $deleteArgs = @(
        'ec2', 'delete-route',
        '--route-table-id', $RouteTableId
    ) + $awsArgs

    # Add destination
    if ($DestinationCidrBlock) {
        $deleteArgs += @('--destination-cidr-block', $DestinationCidrBlock)
    }
    if ($DestinationIpv6CidrBlock) {
        $deleteArgs += @('--destination-ipv6-cidr-block', $DestinationIpv6CidrBlock)
    }

    # Delete the route
    if (-not $DryRun) {
        Write-Output "`n🗑️ Deleting route..."
        $result = aws @deleteArgs --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Output "✅ Route deleted successfully!"
            
            # Verify the route was deleted
            Write-Output "`n🔍 Verifying route deletion..."
            $verifyResult = aws ec2 describe-route-tables --route-table-ids $RouteTableId @awsArgs --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $verifyData = $verifyResult | ConvertFrom-Json
                $updatedRouteTable = $verifyData.RouteTables[0]
                
                Write-Output "✅ Route table updated:"
                Write-Output "  Total routes: $($updatedRouteTable.Routes.Count)"
                
                # Verify the route is gone
                $deletedRoute = $null
                if ($DestinationCidrBlock) {
                    $deletedRoute = $updatedRouteTable.Routes | Where-Object { $_.DestinationCidrBlock -eq $DestinationCidrBlock }
                }
                if ($DestinationIpv6CidrBlock) {
                    $deletedRoute = $updatedRouteTable.Routes | Where-Object { $_.DestinationIpv6CidrBlock -eq $DestinationIpv6CidrBlock }
                }

                if ($null -eq $deletedRoute) {
                    Write-Output "✅ Route successfully removed from route table"
                } else {
                    Write-Warning "⚠️  Route still appears in route table (may be propagating)"
                }
            }

            Write-Output "`n💡 Post-Deletion Tips:"
            Write-Output "• Monitor connectivity to ensure no unintended impacts"
            Write-Output "• Use 'aws ec2 describe-route-tables --route-table-ids $RouteTableId' to view remaining routes"
            Write-Output "• Create replacement routes if needed with 'aws ec2 create-route'"
            
            if ($isDisruptive) {
                Write-Output "• Test connectivity to affected resources"
                Write-Output "• Consider creating alternative routes if connectivity is lost"
            }

        } else {
            Write-Error "Failed to delete route: $result"
        }
    } else {
        Write-Output "`n✅ DRY RUN: Route deletion command validated successfully"
        Write-Output "Command that would be executed:"
        Write-Output "aws $($deleteArgs -join ' ')"
        
        if ($isDisruptive) {
            Write-Output "`n⚠️  DRY RUN: This deletion would be disruptive - review warnings above"
        }
    }

} catch {
    Write-Error "Failed to delete route: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
