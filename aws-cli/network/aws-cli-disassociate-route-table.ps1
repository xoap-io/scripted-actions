<#
.SYNOPSIS
    Disassociates an AWS Route Table from a Subnet using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script disassociates a route table from a subnet, allowing the subnet to use
    the main route table or be associated with a different route table.

.PARAMETER AssociationId
    The ID of the route table association to remove.

.PARAMETER RouteTableId
    The ID of the route table (used to find association if AssociationId not provided).

.PARAMETER SubnetId
    The ID of the subnet (used to find association if AssociationId not provided).

.PARAMETER DryRun
    Perform a dry run to validate parameters without making changes.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-disassociate-route-table.ps1 -AssociationId "rtbassoc-12345678"

.EXAMPLE
    .\aws-cli-disassociate-route-table.ps1 -RouteTableId "rtb-12345678" -SubnetId "subnet-12345678"

.EXAMPLE
    .\aws-cli-disassociate-route-table.ps1 -SubnetId "subnet-12345678" -Force

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
    [ValidatePattern('^rtbassoc-[a-zA-Z0-9]{8,}$')]
    [string]$AssociationId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^rtb-[a-zA-Z0-9]{8,}$')]
    [string]$RouteTableId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId,

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

    Write-Output "🔓 Disassociating Route Table from Subnet"
    if ($DryRun) { Write-Output "Mode: DRY RUN - No changes will be made" }

    # Validate input parameters
    if (-not $AssociationId -and (-not $RouteTableId -or -not $SubnetId)) {
        throw "Either AssociationId must be provided, or both RouteTableId and SubnetId must be provided."
    }

    # If AssociationId not provided, find it using RouteTableId and SubnetId
    if (-not $AssociationId) {
        Write-Output "🔍 Finding association ID for Route Table: $RouteTableId and Subnet: $SubnetId"
        
        $rtbResult = aws ec2 describe-route-tables --route-table-ids $RouteTableId @awsArgs --output json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Route table $RouteTableId not found or not accessible: $rtbResult"
        }

        $rtbData = $rtbResult | ConvertFrom-Json
        $routeTable = $rtbData.RouteTables[0]
        
        # Find the association for the specified subnet
        $association = $routeTable.Associations | Where-Object { $_.SubnetId -eq $SubnetId }
        
        if (-not $association) {
            Write-Error "No association found between route table $RouteTableId and subnet $SubnetId"
        }

        $AssociationId = $association.RouteTableAssociationId
        Write-Output "✅ Found association ID: $AssociationId"
    }

    # If only SubnetId provided, find any route table association
    if (-not $AssociationId -and $SubnetId -and -not $RouteTableId) {
        Write-Output "🔍 Finding route table association for Subnet: $SubnetId"
        
        $rtbResult = aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$SubnetId" @awsArgs --output json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to find route table associations for subnet $SubnetId : $rtbResult"
        }

        $rtbData = $rtbResult | ConvertFrom-Json
        
        if ($rtbData.RouteTables.Count -eq 0) {
            Write-Output "ℹ️  Subnet $SubnetId is not explicitly associated with any route table."
            Write-Output "It is using the main route table for its VPC."
            exit 0
        }

        $routeTable = $rtbData.RouteTables[0]
        $association = $routeTable.Associations | Where-Object { $_.SubnetId -eq $SubnetId }
        
        if (-not $association) {
            Write-Error "Association not found for subnet $SubnetId"
        }

        $AssociationId = $association.RouteTableAssociationId
        $RouteTableId = $routeTable.RouteTableId
        Write-Output "✅ Found association: $AssociationId (Route Table: $RouteTableId)"
    }

    # Get detailed information about the association
    Write-Output "`n🔍 Verifying association details..."
    
    if ($RouteTableId) {
        $rtbResult = aws ec2 describe-route-tables --route-table-ids $RouteTableId @awsArgs --output json 2>&1
    } else {
        # Find route table using association ID
        $rtbResult = aws ec2 describe-route-tables --filters "Name=association.route-table-association-id,Values=$AssociationId" @awsArgs --output json 2>&1
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get route table information: $rtbResult"
    }

    $rtbData = $rtbResult | ConvertFrom-Json
    
    if ($rtbData.RouteTables.Count -eq 0) {
        Write-Error "Route table not found for association $AssociationId"
    }

    $routeTable = $rtbData.RouteTables[0]
    $association = $routeTable.Associations | Where-Object { $_.RouteTableAssociationId -eq $AssociationId }
    
    if (-not $association) {
        Write-Error "Association $AssociationId not found in route table $($routeTable.RouteTableId)"
    }

    Write-Output "✅ Association verified:"
    Write-Output "  Association ID: $($association.RouteTableAssociationId)"
    Write-Output "  Route Table: $($routeTable.RouteTableId)"
    Write-Output "  Subnet: $($association.SubnetId)"
    Write-Output "  State: $($association.AssociationState.State)"

    # Verify this is not a main route table association
    if ($association.Main) {
        Write-Error "Cannot disassociate main route table. This is the default route table for the VPC."
    }

    # Get VPC information to show main route table
    $vpcId = $routeTable.VpcId
    Write-Output "  VPC: $vpcId"

    # Get main route table information
    $mainRtbResult = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpcId" "Name=association.main,Values=true" @awsArgs --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $mainRtbData = $mainRtbResult | ConvertFrom-Json
        if ($mainRtbData.RouteTables.Count -gt 0) {
            $mainRouteTable = $mainRtbData.RouteTables[0]
            Write-Output "  Main Route Table: $($mainRouteTable.RouteTableId)"
            Write-Output "  ⚠️  After disassociation, subnet will use the main route table"
        }
    }

    # Get subnet details
    if ($association.SubnetId) {
        $subnetResult = aws ec2 describe-subnets --subnet-ids $association.SubnetId @awsArgs --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $subnetData = $subnetResult | ConvertFrom-Json
            $subnet = $subnetData.Subnets[0]
            
            Write-Output "`n📋 Subnet Details:"
            Write-Output "  Subnet ID: $($subnet.SubnetId)"
            Write-Output "  CIDR Block: $($subnet.CidrBlock)"
            Write-Output "  Availability Zone: $($subnet.AvailabilityZone)"
            Write-Output "  Public IP Auto-assign: $($subnet.MapPublicIpOnLaunch)"
        }
    }

    # Warning about potential connectivity impact
    Write-Output "`n⚠️  Impact Analysis:"
    
    # Check for internet routes in current route table
    $hasIgwRoute = $routeTable.Routes | Where-Object { $_.GatewayId -like 'igw-*' -and $_.DestinationCidrBlock -eq '0.0.0.0/0' }
    $hasNatRoute = $routeTable.Routes | Where-Object { $_.NatGatewayId -and $_.DestinationCidrBlock -eq '0.0.0.0/0' }
    
    if ($hasIgwRoute) {
        Write-Output "  • Current route table provides INTERNET access via Internet Gateway"
    } elseif ($hasNatRoute) {
        Write-Output "  • Current route table provides INTERNET access via NAT Gateway"
    } else {
        Write-Output "  • Current route table does NOT provide internet access"
    }

    # Check main route table connectivity
    if ($mainRouteTable) {
        $mainHasIgwRoute = $mainRouteTable.Routes | Where-Object { $_.GatewayId -like 'igw-*' -and $_.DestinationCidrBlock -eq '0.0.0.0/0' }
        $mainHasNatRoute = $mainRouteTable.Routes | Where-Object { $_.NatGatewayId -and $_.DestinationCidrBlock -eq '0.0.0.0/0' }
        
        if ($mainHasIgwRoute) {
            Write-Output "  • Main route table provides INTERNET access via Internet Gateway"
        } elseif ($mainHasNatRoute) {
            Write-Output "  • Main route table provides INTERNET access via NAT Gateway"
        } else {
            Write-Output "  • Main route table does NOT provide internet access"
        }

        # Warn about connectivity changes
        if (($hasIgwRoute -or $hasNatRoute) -and -not ($mainHasIgwRoute -or $mainHasNatRoute)) {
            Write-Output "  🚨 WARNING: Subnet will LOSE internet connectivity after disassociation!"
        } elseif (-not ($hasIgwRoute -or $hasNatRoute) -and ($mainHasIgwRoute -or $mainHasNatRoute)) {
            Write-Output "  ✅ Subnet will GAIN internet connectivity after disassociation"
        }
    }

    # Confirmation prompt
    if (-not $Force -and -not $DryRun) {
        Write-Output "`n⚠️  You are about to disassociate:"
        Write-Output "Route Table: $($routeTable.RouteTableId)"
        Write-Output "From Subnet: $($association.SubnetId)"
        Write-Output "The subnet will then use the main route table: $($mainRouteTable.RouteTableId)"
        
        $confirmation = Read-Host "`nAre you sure you want to continue? (y/N)"
        
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-Output "❌ Operation cancelled by user."
            exit 0
        }
    }

    # Disassociate the route table
    if (-not $DryRun) {
        Write-Output "`n🔓 Disassociating route table..."
        $disassociateResult = aws ec2 disassociate-route-table --association-id $AssociationId @awsArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Output "✅ Route table disassociated successfully!"
            Write-Output "Association ID $AssociationId has been removed."
            
            # Verify the disassociation
            Write-Output "`n🔍 Verifying disassociation..."
            Start-Sleep -Seconds 2
            
            $verifyResult = aws ec2 describe-route-tables --route-table-ids $routeTable.RouteTableId @awsArgs --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $verifyData = $verifyResult | ConvertFrom-Json
                $updatedRouteTable = $verifyData.RouteTables[0]
                
                $remainingAssociation = $updatedRouteTable.Associations | Where-Object { $_.RouteTableAssociationId -eq $AssociationId }
                
                if (-not $remainingAssociation) {
                    Write-Output "✅ Disassociation verified - association no longer exists"
                } else {
                    Write-Warning "⚠️  Association still exists - may take a moment to update"
                }
                
                Write-Output "Remaining associations for route table: $($updatedRouteTable.Associations.Count)"
            }

            Write-Output "`n💡 Next Steps:"
            Write-Output "• The subnet now uses the main route table: $($mainRouteTable.RouteTableId)"
            Write-Output "• Verify connectivity for resources in the subnet"
            Write-Output "• Consider associating with a different route table if needed"
            Write-Output "• Update any automation that relies on the previous association"

            Write-Output "`n📋 Useful Commands:"
            Write-Output "# Associate with a different route table:"
            Write-Output "aws ec2 associate-route-table --route-table-id rtb-xxxxxxxx --subnet-id $($association.SubnetId)"
            Write-Output ""
            Write-Output "# Check current route table for subnet:"
            Write-Output "aws ec2 describe-route-tables --filters 'Name=association.subnet-id,Values=$($association.SubnetId)'"

        } else {
            Write-Error "Failed to disassociate route table: $disassociateResult"
        }
    } else {
        Write-Output "`n✅ DRY RUN: Route table disassociation command validated successfully"
        Write-Output "Command that would be executed:"
        Write-Output "aws ec2 disassociate-route-table --association-id $AssociationId"
    }

} catch {
    Write-Error "Failed to disassociate route table: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
