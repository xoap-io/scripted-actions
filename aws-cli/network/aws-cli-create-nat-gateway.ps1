<#
.SYNOPSIS
    Creates an AWS NAT Gateway using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script creates a NAT Gateway in a specified subnet with comprehensive
    validation and configuration options. Supports both public and private NAT Gateways.

.PARAMETER SubnetId
    The ID of the subnet where the NAT Gateway will be created.

.PARAMETER AllocationId
    The allocation ID of the Elastic IP address for the NAT Gateway (required for public NAT Gateways).

.PARAMETER ConnectivityType
    The connectivity type for the NAT Gateway: public or private.

.PARAMETER PrivateIpAddress
    The private IP address to assign to the NAT Gateway (optional, for private NAT Gateways).

.PARAMETER SecondaryAllocationIds
    Comma-separated list of secondary Elastic IP allocation IDs.

.PARAMETER SecondaryPrivateIpAddresses
    Comma-separated list of secondary private IP addresses.

.PARAMETER Tags
    JSON string of tags to apply to the NAT Gateway.

.PARAMETER DryRun
    Perform a dry run to validate parameters without creating the NAT Gateway.

.PARAMETER WaitForAvailable
    Wait for the NAT Gateway to become available before returning.

.PARAMETER MaxWaitTime
    Maximum time to wait for NAT Gateway to become available in seconds (default: 300).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-create-nat-gateway.ps1 -SubnetId "subnet-12345678" -AllocationId "eipalloc-12345678"

.EXAMPLE
    .\aws-cli-create-nat-gateway.ps1 -SubnetId "subnet-12345678" -ConnectivityType "private"

.EXAMPLE
    .\aws-cli-create-nat-gateway.ps1 -SubnetId "subnet-12345678" -AllocationId "eipalloc-12345678" -WaitForAvailable -Tags '[{"Key":"Name","Value":"MyNATGateway"},{"Key":"Environment","Value":"Production"}]'

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
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^eipalloc-[a-zA-Z0-9]{8,}$')]
    [string]$AllocationId,

    [Parameter(Mandatory = $false)]
    [ValidateSet('public', 'private')]
    [string]$ConnectivityType = 'public',

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}$')]
    [string]$PrivateIpAddress,

    [Parameter(Mandatory = $false)]
    [string]$SecondaryAllocationIds,

    [Parameter(Mandatory = $false)]
    [string]$SecondaryPrivateIpAddresses,

    [Parameter(Mandatory = $false)]
    [string]$Tags,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$WaitForAvailable,

    [Parameter(Mandatory = $false)]
    [ValidateRange(60, 1800)]
    [int]$MaxWaitTime = 300,

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

    Write-Output "🌉 Creating NAT Gateway"
    Write-Output "Subnet: $SubnetId"
    Write-Output "Connectivity Type: $ConnectivityType"
    if ($DryRun) { Write-Output "Mode: DRY RUN - No changes will be made" }

    # Validate parameters based on connectivity type
    if ($ConnectivityType -eq 'public' -and -not $AllocationId) {
        throw "AllocationId (Elastic IP) is required for public NAT Gateways."
    }

    if ($ConnectivityType -eq 'private' -and $AllocationId) {
        Write-Warning "⚠️  AllocationId is not used for private NAT Gateways and will be ignored."
    }

    # Verify subnet exists and get details
    Write-Output "`n🔍 Verifying subnet..."
    $subnetResult = aws ec2 describe-subnets --subnet-ids $SubnetId @awsArgs --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Subnet $SubnetId not found or not accessible: $subnetResult"
    }

    $subnetData = $subnetResult | ConvertFrom-Json
    $subnet = $subnetData.Subnets[0]

    Write-Output "✅ Subnet verified:"
    Write-Output "  VPC ID: $($subnet.VpcId)"
    Write-Output "  Availability Zone: $($subnet.AvailabilityZone)"
    Write-Output "  CIDR Block: $($subnet.CidrBlock)"
    Write-Output "  State: $($subnet.State)"
    Write-Output "  Public: $($subnet.MapPublicIpOnLaunch)"

    # For public NAT Gateways, verify the subnet is in a public subnet (has route to IGW)
    if ($ConnectivityType -eq 'public') {
        Write-Output "`n🔍 Verifying subnet is public (has route to Internet Gateway)..."

        # Get route tables associated with this subnet
        $routeTablesResult = aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$SubnetId" @awsArgs --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            $routeTablesData = $routeTablesResult | ConvertFrom-Json

            if ($routeTablesData.RouteTables.Count -eq 0) {
                # Check main route table for the VPC
                $mainRtbResult = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$($subnet.VpcId)" "Name=association.main,Values=true" @awsArgs --output json 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $mainRtbData = $mainRtbResult | ConvertFrom-Json
                    $routeTablesData.RouteTables = $mainRtbData.RouteTables
                }
            }

            $hasIgwRoute = $false
            foreach ($routeTable in $routeTablesData.RouteTables) {
                $igwRoute = $routeTable.Routes | Where-Object { $_.GatewayId -like 'igw-*' -and $_.DestinationCidrBlock -eq '0.0.0.0/0' }
                if ($igwRoute) {
                    $hasIgwRoute = $true
                    Write-Output "✅ Found Internet Gateway route in route table: $($routeTable.RouteTableId)"
                    break
                }
            }

            if (-not $hasIgwRoute) {
                Write-Warning "⚠️  Subnet does not appear to have a route to an Internet Gateway"
                Write-Output "For a public NAT Gateway, the subnet should have a route to an Internet Gateway"
            }
        }
    }

    # Verify Elastic IP if provided
    if ($AllocationId) {
        Write-Output "`n🔍 Verifying Elastic IP..."
        $eipResult = aws ec2 describe-addresses --allocation-ids $AllocationId @awsArgs --output json 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Elastic IP allocation $AllocationId not found or not accessible: $eipResult"
        }

        $eipData = $eipResult | ConvertFrom-Json
        $elasticIp = $eipData.Addresses[0]

        Write-Output "✅ Elastic IP verified:"
        Write-Output "  Public IP: $($elasticIp.PublicIp)"
        Write-Output "  Domain: $($elasticIp.Domain)"

        if ($elasticIp.AssociationId) {
            Write-Warning "⚠️  Elastic IP is currently associated with: $($elasticIp.InstanceId)$($elasticIp.NetworkInterfaceId)"
            throw "Elastic IP is already in use. Use an unassociated Elastic IP for NAT Gateway."
        }
    }

    # Check for existing NAT Gateways in the subnet
    Write-Output "`n🔍 Checking for existing NAT Gateways in subnet..."
    $existingNatResult = aws ec2 describe-nat-gateways --filter "Name=subnet-id,Values=$SubnetId" "Name=state,Values=pending,available" @awsArgs --output json 2>&1

    if ($LASTEXITCODE -eq 0) {
        $existingNatData = $existingNatResult | ConvertFrom-Json

        if ($existingNatData.NatGateways.Count -gt 0) {
            Write-Warning "⚠️  Found $($existingNatData.NatGateways.Count) existing NAT Gateway(s) in this subnet:"
            foreach ($existingNat in $existingNatData.NatGateways) {
                Write-Output "  • $($existingNat.NatGatewayId) (State: $($existingNat.State), Type: $($existingNat.ConnectivityType))"
            }

            if (-not $DryRun) {
                $confirmation = Read-Host "Continue with creating another NAT Gateway in this subnet? (y/N)"
                if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                    Write-Output "❌ Operation cancelled by user."
                    exit 0
                }
            }
        }
    }

    # Build NAT Gateway creation command
    $natArgs = @(
        'ec2', 'create-nat-gateway',
        '--subnet-id', $SubnetId,
        '--connectivity-type', $ConnectivityType
    ) + $awsArgs

    if ($AllocationId -and $ConnectivityType -eq 'public') {
        $natArgs += @('--allocation-id', $AllocationId)
        Write-Output "Elastic IP: $AllocationId"
    }

    if ($PrivateIpAddress) {
        $natArgs += @('--private-ip-address', $PrivateIpAddress)
        Write-Output "Private IP: $PrivateIpAddress"
    }

    # Handle secondary IPs and allocations
    if ($SecondaryAllocationIds) {
        $secondaryAllocs = $SecondaryAllocationIds -split ',' | ForEach-Object { $_.Trim() }
        $natArgs += @('--secondary-allocation-ids')
        $natArgs += $secondaryAllocs
        Write-Output "Secondary EIPs: $($secondaryAllocs -join ', ')"
    }

    if ($SecondaryPrivateIpAddresses) {
        $secondaryIps = $SecondaryPrivateIpAddresses -split ',' | ForEach-Object { $_.Trim() }
        $natArgs += @('--secondary-private-ip-addresses')
        $natArgs += $secondaryIps
        Write-Output "Secondary Private IPs: $($secondaryIps -join ', ')"
    }

    # Create the NAT Gateway
    if (-not $DryRun) {
        Write-Output "`n🚀 Creating NAT Gateway..."
        $createResult = aws @natArgs --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            $natData = $createResult | ConvertFrom-Json
            $natGateway = $natData.NatGateway

            Write-Output "✅ NAT Gateway creation initiated!"
            Write-Output "  NAT Gateway ID: $($natGateway.NatGatewayId)"
            Write-Output "  State: $($natGateway.State)"
            Write-Output "  Connectivity Type: $($natGateway.ConnectivityType)"
            Write-Output "  Subnet ID: $($natGateway.SubnetId)"
            Write-Output "  VPC ID: $($natGateway.VpcId)"

            if ($natGateway.NatGatewayAddresses) {
                Write-Output "  IP Addresses:"
                foreach ($address in $natGateway.NatGatewayAddresses) {
                    if ($address.PublicIp) {
                        Write-Output "    • Public: $($address.PublicIp) (EIP: $($address.AllocationId))"
                    }
                    if ($address.PrivateIp) {
                        Write-Output "    • Private: $($address.PrivateIp)"
                    }
                }
            }

            # Apply tags if provided
            if ($Tags) {
                Write-Output "`n🏷️  Applying tags..."
                try {
                    $tagsArray = $Tags | ConvertFrom-Json
                    $tagsJson = $tagsArray | ConvertTo-Json -Depth 3 -Compress

                    $tagResult = aws ec2 create-tags --resources $natGateway.NatGatewayId --tags $tagsJson @awsArgs 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        Write-Output "✅ Tags applied successfully"
                    } else {
                        Write-Warning "Failed to apply tags: $tagResult"
                    }
                } catch {
                    Write-Warning "Invalid JSON format for tags: $($_.Exception.Message)"
                }
            }

            # Wait for NAT Gateway to become available if requested
            if ($WaitForAvailable) {
                Write-Output "`n⏳ Waiting for NAT Gateway to become available..."
                $waitTime = 0
                $checkInterval = 15

                do {
                    Start-Sleep -Seconds $checkInterval
                    $waitTime += $checkInterval

                    $statusResult = aws ec2 describe-nat-gateways --nat-gateway-ids $natGateway.NatGatewayId @awsArgs --query 'NatGateways[0].State' --output text 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $currentState = $statusResult.Trim()
                        Write-Output "[$([math]::Round($waitTime/60, 1)) min] NAT Gateway state: $currentState"

                        if ($currentState -eq 'available') {
                            Write-Output "✅ NAT Gateway is now available!"
                            break
                        } elseif ($currentState -eq 'failed') {
                            Write-Error "❌ NAT Gateway creation failed"
                            break
                        }
                    }

                } while ($waitTime -lt $MaxWaitTime)

                if ($waitTime -ge $MaxWaitTime) {
                    Write-Warning "⏰ NAT Gateway monitoring timed out after $($MaxWaitTime/60) minutes"
                    Write-Output "Check NAT Gateway status manually: aws ec2 describe-nat-gateways --nat-gateway-ids $($natGateway.NatGatewayId)"
                }
            }

            Write-Output "`n💡 Next Steps:"
            Write-Output "• Update route tables for private subnets to route traffic (0.0.0.0/0) to this NAT Gateway"
            Write-Output "• Monitor NAT Gateway state until it becomes 'available'"
            Write-Output "• Consider setting up CloudWatch monitoring for the NAT Gateway"

            Write-Output "`n📋 Useful Commands:"
            Write-Output "# Check NAT Gateway status:"
            Write-Output "aws ec2 describe-nat-gateways --nat-gateway-ids $($natGateway.NatGatewayId)"
            Write-Output ""
            Write-Output "# Add route to private subnet route table:"
            Write-Output "aws ec2 create-route --route-table-id rtb-xxxxxxxx --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $($natGateway.NatGatewayId)"

        } else {
            Write-Error "Failed to create NAT Gateway: $createResult"
        }
    } else {
        Write-Output "`n✅ DRY RUN: NAT Gateway creation command validated successfully"
        Write-Output "Command that would be executed:"
        Write-Output "aws $($natArgs -join ' ')"
    }

} catch {
    Write-Error "Failed to create NAT Gateway: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
