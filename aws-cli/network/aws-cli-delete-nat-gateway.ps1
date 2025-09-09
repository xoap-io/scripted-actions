<#
.SYNOPSIS
    Deletes NAT Gateways in AWS using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script safely deletes NAT Gateways with validation and impact analysis.
    Provides warnings for potentially disruptive deletions and route cleanup guidance.

.PARAMETER NatGatewayId
    The ID of the NAT Gateway to delete.

.PARAMETER DryRun
    Perform a dry run to validate parameters without deleting the NAT Gateway.

.PARAMETER Force
    Skip confirmation prompts for potentially disruptive deletions.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-delete-nat-gateway.ps1 -NatGatewayId "nat-12345678"

.EXAMPLE
    .\aws-cli-delete-nat-gateway.ps1 -NatGatewayId "nat-12345678" -Force

.EXAMPLE
    .\aws-cli-delete-nat-gateway.ps1 -NatGatewayId "nat-12345678" -DryRun

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
    [ValidatePattern('^nat-[a-zA-Z0-9]{8,}$')]
    [string]$NatGatewayId,

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

    Write-Output "🗑️  Deleting NAT Gateway: $NatGatewayId"
    if ($DryRun) { Write-Output "Mode: DRY RUN - No changes will be made" }

    # Get NAT Gateway details
    Write-Output "`n🔍 Retrieving NAT Gateway information..."
    $natResult = aws ec2 describe-nat-gateways --nat-gateway-ids $NatGatewayId @awsArgs --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "NAT Gateway $NatGatewayId not found or not accessible: $natResult"
    }

    $natData = $natResult | ConvertFrom-Json
    
    if ($natData.NatGateways.Count -eq 0) {
        Write-Error "NAT Gateway $NatGatewayId not found"
    }

    $natGateway = $natData.NatGateways[0]
    
    # Display NAT Gateway details
    Write-Output "✅ NAT Gateway found:"
    Write-Output "  NAT Gateway ID: $($natGateway.NatGatewayId)"
    Write-Output "  State: $($natGateway.State)"
    Write-Output "  Type: $($natGateway.ConnectivityType)"
    Write-Output "  VPC ID: $($natGateway.VpcId)"
    Write-Output "  Subnet ID: $($natGateway.SubnetId)"
    Write-Output "  Created: $($natGateway.CreateTime)"

    # Display Elastic IP information for public NAT Gateways
    if ($natGateway.NatGatewayAddresses -and $natGateway.NatGatewayAddresses.Count -gt 0) {
        Write-Output "  Network Interfaces:"
        foreach ($address in $natGateway.NatGatewayAddresses) {
            Write-Output "    - Network Interface: $($address.NetworkInterfaceId)"
            if ($address.AllocationId) {
                Write-Output "      Elastic IP: $($address.PublicIp) (Allocation: $($address.AllocationId))"
            }
            if ($address.PrivateIp) {
                Write-Output "      Private IP: $($address.PrivateIp)"
            }
        }
    }

    # Check current state
    if ($natGateway.State -eq "deleted" -or $natGateway.State -eq "deleting") {
        Write-Warning "⚠️  NAT Gateway is already in '$($natGateway.State)' state"
        if ($natGateway.State -eq "deleted") {
            Write-Output "✅ NAT Gateway is already deleted"
            exit 0
        } else {
            Write-Output "🔄 NAT Gateway deletion is already in progress"
            exit 0
        }
    }

    if ($natGateway.State -ne "available") {
        Write-Warning "⚠️  NAT Gateway is in '$($natGateway.State)' state - deletion may not be possible"
    }

    # Check for routes that reference this NAT Gateway
    Write-Output "`n🔍 Checking for routes that reference this NAT Gateway..."
    $routeResult = aws ec2 describe-route-tables @awsArgs --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $routeData = $routeResult | ConvertFrom-Json
        $referencingRoutes = @()
        
        foreach ($routeTable in $routeData.RouteTables) {
            $natRoutes = $routeTable.Routes | Where-Object { $_.NatGatewayId -eq $NatGatewayId }
            if ($natRoutes) {
                foreach ($route in $natRoutes) {
                    $referencingRoutes += [PSCustomObject]@{
                        RouteTableId = $routeTable.RouteTableId
                        VpcId = $routeTable.VpcId
                        Destination = "$($route.DestinationCidrBlock)$($route.DestinationIpv6CidrBlock)"
                        State = $route.State
                        Associations = $routeTable.Associations.Count
                    }
                }
            }
        }

        if ($referencingRoutes.Count -gt 0) {
            Write-Output "⚠️  Found $($referencingRoutes.Count) route(s) referencing this NAT Gateway:"
            foreach ($route in $referencingRoutes) {
                Write-Output "  - Route Table: $($route.RouteTableId) (VPC: $($route.VpcId))"
                Write-Output "    Destination: $($route.Destination), State: $($route.State)"
                Write-Output "    Associations: $($route.Associations)"
            }
            Write-Output ""
            Write-Output "🚨 WARNING: Deleting this NAT Gateway will make these routes invalid!"
            Write-Output "   This may cause connectivity issues for private subnets that rely on this NAT Gateway."
        } else {
            Write-Output "✅ No routes found referencing this NAT Gateway"
        }
    }

    # Check for associated subnets (indirectly through route tables)
    if ($referencingRoutes.Count -gt 0) {
        $associatedSubnets = @()
        foreach ($route in $referencingRoutes) {
            $rtbDetail = aws ec2 describe-route-tables --route-table-ids $route.RouteTableId @awsArgs --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $rtbDetailData = $rtbDetail | ConvertFrom-Json
                $routeTableDetail = $rtbDetailData.RouteTables[0]
                $subnetAssociations = $routeTableDetail.Associations | Where-Object { $_.SubnetId }
                if ($subnetAssociations) {
                    $associatedSubnets += $subnetAssociations.SubnetId
                }
            }
        }

        if ($associatedSubnets.Count -gt 0) {
            Write-Output "🚨 IMPACT ANALYSIS: Potentially affected subnets:"
            $uniqueSubnets = $associatedSubnets | Sort-Object -Unique
            foreach ($subnetId in $uniqueSubnets) {
                Write-Output "  - Subnet: $subnetId"
            }
            Write-Output "   These subnets may lose outbound internet connectivity!"
        }
    }

    # Estimate hourly cost savings
    $hourlyCost = switch ($natGateway.ConnectivityType) {
        "public" { 0.045 }  # Approximate hourly cost for public NAT Gateway
        "private" { 0.045 } # Approximate hourly cost for private NAT Gateway
        default { 0.045 }
    }
    
    Write-Output "`n💰 Cost Impact:"
    Write-Output "  Estimated hourly cost savings: ~`$$hourlyCost USD"
    Write-Output "  Estimated daily cost savings: ~`$$([math]::Round($hourlyCost * 24, 2)) USD"
    Write-Output "  Estimated monthly cost savings: ~`$$([math]::Round($hourlyCost * 24 * 30, 2)) USD"

    # Confirmation prompt for potentially disruptive deletions
    $isDisruptive = $referencingRoutes.Count -gt 0
    
    if ($isDisruptive -and -not $Force -and -not $DryRun) {
        Write-Output "`n❓ This deletion will affect network connectivity. Do you want to continue? (y/N)"
        $confirmation = Read-Host
        if ($confirmation -notmatch '^[Yy]') {
            Write-Output "❌ NAT Gateway deletion cancelled by user."
            exit 0
        }
    }

    # Delete the NAT Gateway
    if (-not $DryRun) {
        Write-Output "`n🗑️ Deleting NAT Gateway..."
        $deleteResult = aws ec2 delete-nat-gateway --nat-gateway-id $NatGatewayId @awsArgs --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            $deleteData = $deleteResult | ConvertFrom-Json
            Write-Output "✅ NAT Gateway deletion initiated successfully!"
            Write-Output "  NAT Gateway ID: $($deleteData.NatGatewayId)"
            
            # Monitor deletion progress
            Write-Output "`n🔄 Monitoring deletion progress..."
            $maxAttempts = 20
            $attempt = 0
            
            do {
                Start-Sleep -Seconds 15
                $attempt++
                
                $statusResult = aws ec2 describe-nat-gateways --nat-gateway-ids $NatGatewayId @awsArgs --output json 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $statusData = $statusResult | ConvertFrom-Json
                    if ($statusData.NatGateways.Count -gt 0) {
                        $currentState = $statusData.NatGateways[0].State
                        Write-Output "  Status check $attempt/$maxAttempts - State: $currentState"
                        
                        if ($currentState -eq "deleted") {
                            Write-Output "✅ NAT Gateway successfully deleted!"
                            break
                        }
                        
                        if ($currentState -eq "failed") {
                            Write-Warning "⚠️  NAT Gateway deletion failed"
                            break
                        }
                    }
                } else {
                    # If describe fails, NAT Gateway might be deleted
                    Write-Output "✅ NAT Gateway appears to be deleted (no longer found)"
                    break
                }
                
            } while ($attempt -lt $maxAttempts)
            
            if ($attempt -eq $maxAttempts) {
                Write-Warning "⚠️  Deletion monitoring timeout reached. Check NAT Gateway status manually."
            }

            Write-Output "`n💡 Post-Deletion Tasks:"
            Write-Output "• Elastic IP addresses are automatically released for public NAT Gateways"
            Write-Output "• Clean up any routes that referenced this NAT Gateway:"
            
            if ($referencingRoutes.Count -gt 0) {
                foreach ($route in $referencingRoutes) {
                    Write-Output "  aws ec2 delete-route --route-table-id $($route.RouteTableId) --destination-cidr-block $($route.Destination)"
                }
            }
            
            Write-Output "• Verify connectivity for affected subnets"
            Write-Output "• Consider creating alternative NAT Gateway or NAT instances if needed"
            Write-Output "• Monitor for any applications that may have lost internet connectivity"

        } else {
            Write-Error "Failed to delete NAT Gateway: $deleteResult"
        }
    } else {
        Write-Output "`n✅ DRY RUN: NAT Gateway deletion command validated successfully"
        Write-Output "Command that would be executed:"
        Write-Output "aws ec2 delete-nat-gateway --nat-gateway-id $NatGatewayId"
        
        if ($isDisruptive) {
            Write-Output "`n⚠️  DRY RUN: This deletion would affect network connectivity - review impact above"
        }
        
        Write-Output "`n📋 DRY RUN: Cleanup commands that would be needed:"
        if ($referencingRoutes.Count -gt 0) {
            foreach ($route in $referencingRoutes) {
                Write-Output "aws ec2 delete-route --route-table-id $($route.RouteTableId) --destination-cidr-block $($route.Destination)"
            }
        }
    }

} catch {
    Write-Error "Failed to delete NAT Gateway: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
