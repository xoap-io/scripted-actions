<#
.SYNOPSIS
    Allocates Elastic IP addresses using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script allocates Elastic IP addresses with support for VPC and EC2-Classic domains,
    custom IP pools, and comprehensive tagging options.

.PARAMETER Domain
    The domain for the Elastic IP address: vpc or standard (EC2-Classic).

.PARAMETER Address
    The IP address to allocate from Amazon's pool of Elastic IP addresses.

.PARAMETER PublicIpv4Pool
    The ID of the address pool from which to allocate the Elastic IP address.

.PARAMETER NetworkBorderGroup
    The set of Availability Zones, Local Zones, or Wavelength Zones from which AWS advertises IP addresses.

.PARAMETER CustomerOwnedIpv4Pool
    The ID of a customer-owned address pool for allocating Elastic IP addresses.

.PARAMETER Tags
    JSON string of tags to apply to the Elastic IP address.

.PARAMETER Count
    Number of Elastic IP addresses to allocate (default: 1, max: 10).

.PARAMETER DryRun
    Perform a dry run to validate parameters without allocating addresses.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-allocate-elastic-ip.ps1 -Domain "vpc"

.EXAMPLE
    .\aws-cli-allocate-elastic-ip.ps1 -Domain "vpc" -Count 3 -Tags '[{"Key":"Environment","Value":"Production"},{"Key":"Project","Value":"WebApp"}]'

.EXAMPLE
    .\aws-cli-allocate-elastic-ip.ps1 -Domain "vpc" -PublicIpv4Pool "ipv4pool-ec2-12345678"

.EXAMPLE
    .\aws-cli-allocate-elastic-ip.ps1 -Address "203.0.113.12" -Domain "vpc"

.NOTES
    Author: XOAP
    Date: 2025-08-06

    Requires: AWS CLI v2.16+

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('vpc', 'standard')]
    [string]$Domain = 'vpc',

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}$')]
    [string]$Address,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^ipv4pool-[a-zA-Z0-9-]+$')]
    [string]$PublicIpv4Pool,

    [Parameter(Mandatory = $false)]
    [string]$NetworkBorderGroup,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^ipv4pool-coip-[a-zA-Z0-9-]+$')]
    [string]$CustomerOwnedIpv4Pool,

    [Parameter(Mandatory = $false)]
    [string]$Tags,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$Count = 1,

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

    Write-Output "🌐 Allocating Elastic IP Address(es)"
    Write-Output "Domain: $Domain"
    Write-Output "Count: $Count"
    if ($DryRun) { Write-Output "Mode: DRY RUN - No addresses will be allocated" }

    # Validate parameters
    if ($Address -and $Count -gt 1) {
        throw "Cannot specify both Address and Count > 1. When requesting a specific address, only one can be allocated."
    }

    if ($CustomerOwnedIpv4Pool -and $Domain -ne 'vpc') {
        throw "Customer-owned IPv4 pools are only supported with VPC domain."
    }

    # Check current Elastic IP usage and limits
    Write-Output "`n🔍 Checking current Elastic IP usage..."

    $currentEipsResult = aws ec2 describe-addresses @awsArgs --output json 2>&1

    if ($LASTEXITCODE -eq 0) {
        $currentEipsData = $currentEipsResult | ConvertFrom-Json
        $currentCount = $currentEipsData.Addresses.Count

        Write-Output "Current Elastic IPs: $currentCount"

        # Check regional limits (default is 5 per region)
        if (($currentCount + $Count) -gt 5) {
            Write-Warning "⚠️  This allocation may exceed the default Elastic IP limit (5 per region)"
            Write-Output "Request a limit increase if needed: https://console.aws.amazon.com/support/home#/case/create?issueType=service-limit-increase"
        }
    }

    # Validate IP pool if specified
    if ($PublicIpv4Pool) {
        Write-Output "`n🔍 Validating IPv4 pool..."
        $poolResult = aws ec2 describe-public-ipv4-pools --pool-ids $PublicIpv4Pool @awsArgs --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            $poolData = $poolResult | ConvertFrom-Json
            $pool = $poolData.PublicIpv4Pools[0]

            Write-Output "✅ IPv4 Pool validated:"
            Write-Output "  Pool ID: $($pool.PoolId)"
            Write-Output "  Description: $($pool.Description)"
            Write-Output "  Available addresses: $($pool.TotalAvailableAddressCount)"

            if ($pool.TotalAvailableAddressCount -lt $Count) {
                Write-Warning "⚠️  Pool may not have enough available addresses"
            }
        } else {
            Write-Warning "Could not validate IPv4 pool: $poolResult"
        }
    }

    $allocatedAddresses = @()

    # Allocate Elastic IP addresses
    for ($i = 1; $i -le $Count; $i++) {
        Write-Output "`n🚀 Allocating Elastic IP $i of $Count..."

        # Build allocation command
        $allocateArgs = @(
            'ec2', 'allocate-address',
            '--domain', $Domain
        ) + $awsArgs

        if ($Address -and $i -eq 1) {
            $allocateArgs += @('--address', $Address)
            Write-Output "  Requesting specific address: $Address"
        }

        if ($PublicIpv4Pool) {
            $allocateArgs += @('--public-ipv4-pool', $PublicIpv4Pool)
        }

        if ($NetworkBorderGroup) {
            $allocateArgs += @('--network-border-group', $NetworkBorderGroup)
        }

        if ($CustomerOwnedIpv4Pool) {
            $allocateArgs += @('--customer-owned-ipv4-pool', $CustomerOwnedIpv4Pool)
        }

        if (-not $DryRun) {
            $allocateResult = aws @allocateArgs --output json 2>&1

            if ($LASTEXITCODE -eq 0) {
                $eipData = $allocateResult | ConvertFrom-Json

                Write-Output "✅ Elastic IP allocated successfully:"
                Write-Output "  Public IP: $($eipData.PublicIp)"
                Write-Output "  Allocation ID: $($eipData.AllocationId)"
                Write-Output "  Domain: $($eipData.Domain)"

                if ($eipData.PublicIpv4Pool) {
                    Write-Output "  IPv4 Pool: $($eipData.PublicIpv4Pool)"
                }
                if ($eipData.NetworkBorderGroup) {
                    Write-Output "  Network Border Group: $($eipData.NetworkBorderGroup)"
                }
                if ($eipData.CustomerOwnedIpv4Pool) {
                    Write-Output "  Customer Owned Pool: $($eipData.CustomerOwnedIpv4Pool)"
                    Write-Output "  Customer Owned IP: $($eipData.CustomerOwnedIp)"
                }

                $allocatedAddresses += @{
                    PublicIp = $eipData.PublicIp
                    AllocationId = $eipData.AllocationId
                    Domain = $eipData.Domain
                    Index = $i
                }

                # Apply tags if provided
                if ($Tags) {
                    Write-Output "`n🏷️  Applying tags to $($eipData.PublicIp)..."
                    try {
                        $tagsArray = $Tags | ConvertFrom-Json

                        # Add allocation index to tags if allocating multiple
                        if ($Count -gt 1) {
                            $tagsArray += @{Key = "AllocationIndex"; Value = $i.ToString()}
                        }

                        $tagsJson = $tagsArray | ConvertTo-Json -Depth 3 -Compress

                        $tagResult = aws ec2 create-tags --resources $eipData.AllocationId --tags $tagsJson @awsArgs 2>&1

                        if ($LASTEXITCODE -eq 0) {
                            Write-Output "✅ Tags applied successfully"
                        } else {
                            Write-Warning "Failed to apply tags: $tagResult"
                        }
                    } catch {
                        Write-Warning "Invalid JSON format for tags: $($_.Exception.Message)"
                    }
                }

            } else {
                Write-Warning "Failed to allocate Elastic IP $i : $allocateResult"

                # If we're allocating a specific address and it fails, stop
                if ($Address) {
                    Write-Error "Failed to allocate specific address $Address"
                }
            }
        } else {
            Write-Output "✅ DRY RUN: Would allocate Elastic IP with domain '$Domain'"
            if ($Address) {
                Write-Output "  Would request specific address: $Address"
            }
        }

        # Small delay between allocations to avoid rate limiting
        if ($i -lt $Count -and -not $DryRun) {
            Start-Sleep -Seconds 1
        }
    }

    # Summary
    if (-not $DryRun -and $allocatedAddresses.Count -gt 0) {
        Write-Output "`n📊 Allocation Summary:"
        Write-Output "Successfully allocated: $($allocatedAddresses.Count) of $Count requested"

        Write-Output "`n📋 Allocated Elastic IPs:"
        foreach ($addr in $allocatedAddresses) {
            Write-Output "  $($addr.Index). $($addr.PublicIp) (Allocation ID: $($addr.AllocationId))"
        }

        # Cost information
        Write-Output "`n💰 Cost Information:"
        Write-Output "• Elastic IPs are FREE when associated with running instances"
        Write-Output "• Elastic IPs cost $0.005 per hour when NOT associated with instances"
        Write-Output "• Additional Elastic IPs on the same instance cost $0.005 per hour"

        $monthlyCostUnassociated = $allocatedAddresses.Count * 0.005 * 24 * 30
        Write-Output "• Monthly cost if unassociated: ~$([math]::Round($monthlyCostUnassociated, 2))"

        Write-Output "`n💡 Next Steps:"
        Write-Output "• Associate Elastic IPs with EC2 instances to avoid charges"
        Write-Output "• Configure reverse DNS (PTR records) if needed"
        Write-Output "• Set up monitoring for Elastic IP usage"
        Write-Output "• Release unused Elastic IPs to avoid charges"

        Write-Output "`n📋 Useful Commands:"
        Write-Output "# Associate with EC2 instance:"
        foreach ($addr in $allocatedAddresses) {
            Write-Output "aws ec2 associate-address --allocation-id $($addr.AllocationId) --instance-id i-xxxxxxxx"
            break # Just show one example
        }
        Write-Output ""
        Write-Output "# Release Elastic IP:"
        foreach ($addr in $allocatedAddresses) {
            Write-Output "aws ec2 release-address --allocation-id $($addr.AllocationId)"
            break # Just show one example
        }

    } elseif ($DryRun) {
        Write-Output "`n✅ DRY RUN completed - All allocation parameters validated"
    }

    if ($allocatedAddresses.Count -ne $Count -and -not $DryRun) {
        Write-Warning "⚠️  Only $($allocatedAddresses.Count) of $Count requested Elastic IPs were allocated"
        exit 1
    }

    Write-Output "`n✅ Elastic IP allocation process completed."

} catch {
    Write-Error "Failed to allocate Elastic IP address: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
