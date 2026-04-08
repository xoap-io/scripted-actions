<#
.SYNOPSIS
    Deletes subnets in AWS using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script safely deletes subnets with comprehensive validation and impact analysis.
    Provides warnings for potentially disruptive deletions and resource cleanup guidance.

.PARAMETER SubnetId
    The ID of the subnet to delete.

.PARAMETER DryRun
    Perform a dry run to validate parameters without deleting the subnet.

.PARAMETER Force
    Skip confirmation prompts for potentially disruptive deletions.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-delete-subnet.ps1 -SubnetId "subnet-12345678"

.EXAMPLE
    .\aws-cli-delete-subnet.ps1 -SubnetId "subnet-12345678" -Force

.EXAMPLE
    .\aws-cli-delete-subnet.ps1 -SubnetId "subnet-12345678" -DryRun

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/delete-subnet.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the subnet to delete")]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId,

    [Parameter(Mandatory = $false, HelpMessage = "Perform a dry run to validate parameters without deleting the subnet")]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts for potentially disruptive deletions")]
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

    Write-Output "🗑️  Deleting subnet: $SubnetId"
    if ($DryRun) { Write-Output "Mode: DRY RUN - No changes will be made" }

    # Get subnet details
    Write-Output "`n🔍 Retrieving subnet information..."
    $subnetResult = aws ec2 describe-subnets --subnet-ids $SubnetId @awsArgs --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Subnet $SubnetId not found or not accessible: $subnetResult"
    }

    $subnetData = $subnetResult | ConvertFrom-Json

    if ($subnetData.Subnets.Count -eq 0) {
        Write-Error "Subnet $SubnetId not found"
    }

    $subnet = $subnetData.Subnets[0]

    # Display subnet details
    Write-Output "✅ Subnet found:"
    Write-Output "  Subnet ID: $($subnet.SubnetId)"
    Write-Output "  State: $($subnet.State)"
    Write-Output "  VPC ID: $($subnet.VpcId)"
    Write-Output "  CIDR Block: $($subnet.CidrBlock)"
    Write-Output "  Availability Zone: $($subnet.AvailabilityZone)"
    Write-Output "  Available IP addresses: $($subnet.AvailableIpAddressCount)"
    Write-Output "  Map Public IP on Launch: $($subnet.MapPublicIpOnLaunch)"

    if ($subnet.Tags -and $subnet.Tags.Count -gt 0) {
        $nameTag = $subnet.Tags | Where-Object { $_.Key -eq "Name" }
        if ($nameTag) {
            Write-Output "  Name: $($nameTag.Value)"
        }
    }

    # Check subnet state
    if ($subnet.State -ne "available") {
        Write-Warning "⚠️  Subnet is in '$($subnet.State)' state - deletion may not be possible"
    }

    # Check for EC2 instances in the subnet
    Write-Output "`n🔍 Checking for EC2 instances in subnet..."
    $instanceResult = aws ec2 describe-instances --filters "Name=subnet-id,Values=$SubnetId" "Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped" @awsArgs --output json 2>&1

    $instances = @()
    if ($LASTEXITCODE -eq 0) {
        $instanceData = $instanceResult | ConvertFrom-Json

        foreach ($reservation in $instanceData.Reservations) {
            foreach ($instance in $reservation.Instances) {
                $instances += [PSCustomObject]@{
                    InstanceId = $instance.InstanceId
                    State = $instance.State.Name
                    InstanceType = $instance.InstanceType
                    PublicIp = $instance.PublicIpAddress
                    PrivateIp = $instance.PrivateIpAddress
                }
            }
        }

        if ($instances.Count -gt 0) {
            Write-Output "🚨 Found $($instances.Count) EC2 instance(s) in this subnet:"
            foreach ($instance in $instances) {
                Write-Output "  - Instance: $($instance.InstanceId) (State: $($instance.State))"
                Write-Output "    Type: $($instance.InstanceType)"
                Write-Output "    Private IP: $($instance.PrivateIp)"
                if ($instance.PublicIp) {
                    Write-Output "    Public IP: $($instance.PublicIp)"
                }
            }
            Write-Error "❌ Cannot delete subnet - contains EC2 instances. Terminate instances first."
        } else {
            Write-Output "✅ No EC2 instances found in subnet"
        }
    }

    # Check for network interfaces
    Write-Output "`n🔍 Checking for network interfaces in subnet..."
    $eniResult = aws ec2 describe-network-interfaces --filters "Name=subnet-id,Values=$SubnetId" @awsArgs --output json 2>&1

    $networkInterfaces = @()
    if ($LASTEXITCODE -eq 0) {
        $eniData = $eniResult | ConvertFrom-Json

        foreach ($eni in $eniData.NetworkInterfaces) {
            # Skip the default network interface that's automatically created/deleted
            if ($eni.RequesterManaged -eq $false -or $eni.Status -ne "available") {
                $networkInterfaces += [PSCustomObject]@{
                    NetworkInterfaceId = $eni.NetworkInterfaceId
                    Status = $eni.Status
                    Description = $eni.Description
                    InterfaceType = $eni.InterfaceType
                    RequesterManaged = $eni.RequesterManaged
                    PrivateIpAddress = $eni.PrivateIpAddress
                }
            }
        }

        if ($networkInterfaces.Count -gt 0) {
            Write-Output "⚠️  Found $($networkInterfaces.Count) network interface(s) in this subnet:"
            foreach ($eni in $networkInterfaces) {
                Write-Output "  - Interface: $($eni.NetworkInterfaceId)"
                Write-Output "    Status: $($eni.Status)"
                Write-Output "    Type: $($eni.InterfaceType)"
                Write-Output "    Description: $($eni.Description)"
                Write-Output "    Requester Managed: $($eni.RequesterManaged)"

                if ($eni.RequesterManaged -eq $false -and $eni.Status -eq "available") {
                    Write-Output "    ⚠️  This interface may need manual deletion"
                }
            }

            # Check if any are blocking deletion
            $blockingEnis = $networkInterfaces | Where-Object { $_.RequesterManaged -eq $false -and $_.Status -eq "available" }
            if ($blockingEnis.Count -gt 0) {
                Write-Warning "⚠️  Found $($blockingEnis.Count) network interface(s) that may prevent subnet deletion"
                Write-Output "   These interfaces should be deleted before deleting the subnet"
            }
        } else {
            Write-Output "✅ No blocking network interfaces found in subnet"
        }
    }

    # Check for route table associations
    Write-Output "`n🔍 Checking route table associations..."
    $routeTableResult = aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$SubnetId" @awsArgs --output json 2>&1

    $routeTableAssociations = @()
    if ($LASTEXITCODE -eq 0) {
        $routeTableData = $routeTableResult | ConvertFrom-Json

        foreach ($routeTable in $routeTableData.RouteTables) {
            $subnetAssociations = $routeTable.Associations | Where-Object { $_.SubnetId -eq $SubnetId }
            foreach ($association in $subnetAssociations) {
                $routeTableAssociations += [PSCustomObject]@{
                    RouteTableId = $routeTable.RouteTableId
                    AssociationId = $association.RouteTableAssociationId
                    Main = $association.Main
                }
            }
        }

        if ($routeTableAssociations.Count -gt 0) {
            Write-Output "📋 Found $($routeTableAssociations.Count) route table association(s):"
            foreach ($association in $routeTableAssociations) {
                Write-Output "  - Route Table: $($association.RouteTableId)"
                Write-Output "    Association ID: $($association.AssociationId)"
                Write-Output "    Main: $($association.Main)"
            }
            Write-Output "   These associations will be automatically removed during subnet deletion"
        } else {
            Write-Output "✅ Subnet uses default (main) route table association only"
        }
    }

    # Check for VPC endpoints in the subnet
    Write-Output "`n🔍 Checking for VPC endpoints..."
    $vpcEndpointResult = aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$($subnet.VpcId)" @awsArgs --output json 2>&1

    $affectedEndpoints = @()
    if ($LASTEXITCODE -eq 0) {
        $vpcEndpointData = $vpcEndpointResult | ConvertFrom-Json

        foreach ($endpoint in $vpcEndpointData.VpcEndpoints) {
            if ($endpoint.SubnetIds -and $endpoint.SubnetIds -contains $SubnetId) {
                $affectedEndpoints += [PSCustomObject]@{
                    VpcEndpointId = $endpoint.VpcEndpointId
                    ServiceName = $endpoint.ServiceName
                    VpcEndpointType = $endpoint.VpcEndpointType
                    State = $endpoint.State
                }
            }
        }

        if ($affectedEndpoints.Count -gt 0) {
            Write-Output "⚠️  Found $($affectedEndpoints.Count) VPC endpoint(s) using this subnet:"
            foreach ($endpoint in $affectedEndpoints) {
                Write-Output "  - Endpoint: $($endpoint.VpcEndpointId)"
                Write-Output "    Service: $($endpoint.ServiceName)"
                Write-Output "    Type: $($endpoint.VpcEndpointType)"
                Write-Output "    State: $($endpoint.State)"
            }
            Write-Warning "⚠️  These VPC endpoints may be affected by subnet deletion"
        } else {
            Write-Output "✅ No VPC endpoints found using this subnet"
        }
    }

    # Check for load balancers
    Write-Output "`n🔍 Checking for load balancers in subnet..."
    $elbResult = aws elbv2 describe-load-balancers @awsArgs --output json 2>&1

    $affectedLoadBalancers = @()
    if ($LASTEXITCODE -eq 0) {
        $elbData = $elbResult | ConvertFrom-Json

        foreach ($lb in $elbData.LoadBalancers) {
            if ($lb.SubnetMappings) {
                $subnetMapping = $lb.SubnetMappings | Where-Object { $_.SubnetId -eq $SubnetId }
                if ($subnetMapping) {
                    $affectedLoadBalancers += [PSCustomObject]@{
                        LoadBalancerArn = $lb.LoadBalancerArn
                        LoadBalancerName = $lb.LoadBalancerName
                        Type = $lb.Type
                        State = $lb.State.Code
                    }
                }
            }
        }

        if ($affectedLoadBalancers.Count -gt 0) {
            Write-Output "🚨 Found $($affectedLoadBalancers.Count) load balancer(s) in this subnet:"
            foreach ($lb in $affectedLoadBalancers) {
                Write-Output "  - Load Balancer: $($lb.LoadBalancerName)"
                Write-Output "    Type: $($lb.Type)"
                Write-Output "    State: $($lb.State)"
            }
            Write-Error "❌ Cannot delete subnet - contains load balancers. Delete load balancers first."
        } else {
            Write-Output "✅ No load balancers found in subnet"
        }
    }

    # Impact assessment
    $hasBlockingResources = ($instances.Count -gt 0) -or ($affectedLoadBalancers.Count -gt 0) -or (($networkInterfaces | Where-Object { $_.RequesterManaged -eq $false -and $_.Status -eq "available" }).Count -gt 0)
    $hasWarningResources = ($affectedEndpoints.Count -gt 0)

    if ($hasBlockingResources) {
        Write-Error "❌ Cannot proceed with subnet deletion due to blocking resources listed above"
    }

    if ($hasWarningResources) {
        Write-Output "`n🚨 IMPACT ANALYSIS:"
        Write-Output "• VPC endpoints may lose connectivity or functionality"
        Write-Output "• Applications using these endpoints may experience service disruption"
    }

    # Display cleanup guidance
    Write-Output "`n💡 Pre-Deletion Checklist:"
    Write-Output "✅ No EC2 instances in subnet"
    Write-Output "✅ No load balancers in subnet"
    Write-Output "✅ No blocking network interfaces"
    if ($routeTableAssociations.Count -gt 0) {
        Write-Output "ℹ️  Route table associations will be automatically removed"
    }
    if ($affectedEndpoints.Count -gt 0) {
        Write-Output "⚠️  VPC endpoints will be updated to remove this subnet"
    }

    # Confirmation prompt
    if (-not $Force -and -not $DryRun) {
        Write-Output "`n❓ Are you sure you want to delete subnet $SubnetId? (y/N)"
        $confirmation = Read-Host
        if ($confirmation -notmatch '^[Yy]') {
            Write-Output "❌ Subnet deletion cancelled by user."
            exit 0
        }
    }

    # Delete the subnet
    if (-not $DryRun) {
        Write-Output "`n🗑️ Deleting subnet..."
        $deleteResult = aws ec2 delete-subnet --subnet-id $SubnetId @awsArgs --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Output "✅ Subnet deletion initiated successfully!"

            # Verify deletion
            Write-Output "`n🔍 Verifying subnet deletion..."
            Start-Sleep -Seconds 3

            $verifyResult = aws ec2 describe-subnets --subnet-ids $SubnetId @awsArgs --output json 2>&1

            if ($LASTEXITCODE -ne 0) {
                Write-Output "✅ Subnet successfully deleted (no longer found)"
            } else {
                $verifyData = $verifyResult | ConvertFrom-Json
                if ($verifyData.Subnets.Count -eq 0) {
                    Write-Output "✅ Subnet successfully deleted"
                } else {
                    Write-Warning "⚠️  Subnet still exists - deletion may be in progress"
                }
            }

            Write-Output "`n💡 Post-Deletion Notes:"
            Write-Output "• IP addresses from this subnet's CIDR block are now available for reuse"
            Write-Output "• Any VPC endpoints that used this subnet have been automatically updated"
            Write-Output "• Route table associations have been automatically removed"
            Write-Output "• Consider updating security groups that may have referenced this subnet"
            Write-Output "• Review any documentation or scripts that referenced this subnet ID"

            if ($affectedEndpoints.Count -gt 0) {
                Write-Output "• Verify VPC endpoint functionality for affected services"
            }

        } else {
            Write-Error "Failed to delete subnet: $deleteResult"
        }
    } else {
        Write-Output "`n✅ DRY RUN: Subnet deletion command validated successfully"
        Write-Output "Command that would be executed:"
        Write-Output "aws ec2 delete-subnet --subnet-id $SubnetId"

        if ($hasWarningResources) {
            Write-Output "`n⚠️  DRY RUN: This deletion would affect VPC endpoints - review impact above"
        }
    }

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
