<#
.SYNOPSIS
    Describes AWS VPC peering connections.

.DESCRIPTION
    This script retrieves detailed information about VPC peering connections in your AWS account.
    It supports filtering by various criteria and provides comprehensive connection details.
    Uses aws ec2 describe-vpc-peering-connections to perform the operation.

.PARAMETER VpcPeeringConnectionIds
    Comma-separated list of specific VPC peering connection IDs to describe. Must be in the format 'pcx-xxxxxxxxx'.

.PARAMETER RequesterVpcId
    Filter peering connections by the requester VPC ID.

.PARAMETER AccepterVpcId
    Filter peering connections by the accepter VPC ID.

.PARAMETER Status
    Filter by peering connection status.

.PARAMETER RequesterOwnerId
    Filter by the AWS account ID that owns the requester VPC.

.PARAMETER AccepterOwnerId
    Filter by the AWS account ID that owns the accepter VPC.

.PARAMETER Profile
    The AWS CLI profile to use for the operation.

.PARAMETER Region
    The AWS region to query for VPC peering connections.

.PARAMETER OutputFormat
    The output format for the results (json, table, text, yaml).

.PARAMETER Detailed
    Show detailed information including related route tables and security considerations.

.EXAMPLE
    .\aws-cli-describe-vpc-peering-connections.ps1

.EXAMPLE
    .\aws-cli-describe-vpc-peering-connections.ps1 -RequesterVpcId vpc-12345678

.EXAMPLE
    .\aws-cli-describe-vpc-peering-connections.ps1 -Status active

.EXAMPLE
    .\aws-cli-describe-vpc-peering-connections.ps1 -VpcPeeringConnectionIds pcx-12345678,pcx-87654321 -Detailed

.EXAMPLE
    .\aws-cli-describe-vpc-peering-connections.ps1 -RequesterOwnerId 123456789012 -AccepterOwnerId 210987654321

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-vpc-peering-connections.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Specific VPC peering connection IDs to describe")]
    [ValidatePattern('^pcx-[a-zA-Z0-9]+(,pcx-[a-zA-Z0-9]+)*$')]
    [string]$VpcPeeringConnectionIds,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by requester VPC ID")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]+$')]
    [string]$RequesterVpcId,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by accepter VPC ID")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]+$')]
    [string]$AccepterVpcId,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by peering connection status")]
    [ValidateSet('initiating-request', 'pending-acceptance', 'active', 'deleted', 'rejected', 'failed', 'expired', 'provisioning', 'deleting')]
    [string]$Status,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by requester owner ID")]
    [ValidatePattern('^\d{12}$')]
    [string]$RequesterOwnerId,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by accepter owner ID")]
    [ValidatePattern('^\d{12}$')]
    [string]$AccepterOwnerId,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('json', 'table', 'text', 'yaml')]
    [string]$OutputFormat = 'table',

    [Parameter(Mandatory = $false, HelpMessage = "Show detailed information including related routes")]
    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving VPC peering connection information..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @('ec2', 'describe-vpc-peering-connections')

    if ($VpcPeeringConnectionIds) {
        $connectionArray = $VpcPeeringConnectionIds -split ','
        $awsArgs += @('--vpc-peering-connection-ids')
        $awsArgs += $connectionArray
    }

    # Build filters array
    $filters = @()

    if ($RequesterVpcId) {
        $filters += "Name=requester-vpc-info.vpc-id,Values=$RequesterVpcId"
    }

    if ($AccepterVpcId) {
        $filters += "Name=accepter-vpc-info.vpc-id,Values=$AccepterVpcId"
    }

    if ($Status) {
        $filters += "Name=status-code,Values=$Status"
    }

    if ($RequesterOwnerId) {
        $filters += "Name=requester-vpc-info.owner-id,Values=$RequesterOwnerId"
    }

    if ($AccepterOwnerId) {
        $filters += "Name=accepter-vpc-info.owner-id,Values=$AccepterOwnerId"
    }

    if ($filters.Count -gt 0) {
        $awsArgs += @('--filters')
        $awsArgs += $filters
    }

    if ($Profile) {
        $awsArgs += @('--profile', $Profile)
    }

    if ($Region) {
        $awsArgs += @('--region', $Region)
    }

    # Execute the AWS CLI command
    $result = & aws @awsArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe VPC peering connections: $result"
    }

    $peeringInfo = $result | ConvertFrom-Json

    if ($OutputFormat -eq 'json') {
        # Output raw JSON
        $result
        return
    }

    if ($peeringInfo.VpcPeeringConnections.Count -eq 0) {
        Write-Host "No VPC peering connections found matching the specified criteria." -ForegroundColor Yellow
        return
    }

    # Display summary
    Write-Host "`nVPC Peering Connections Summary:" -ForegroundColor Cyan
    Write-Host "Total connections found: $($peeringInfo.VpcPeeringConnections.Count)" -ForegroundColor White

    # Group by status
    $byStatus = $peeringInfo.VpcPeeringConnections | Group-Object { $_.Status.Code }
    foreach ($group in $byStatus) {
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor White
    }

    # Display detailed information for each peering connection
    foreach ($connection in $peeringInfo.VpcPeeringConnections) {
        Write-Host "`n" + "="*70 -ForegroundColor Gray
        Write-Host "Peering Connection: $($connection.VpcPeeringConnectionId)" -ForegroundColor Cyan

        # Status information
        $statusColor = switch ($connection.Status.Code) {
            'active' { 'Green' }
            'pending-acceptance' { 'Yellow' }
            'failed' { 'Red' }
            'rejected' { 'Red' }
            'deleted' { 'Gray' }
            'expired' { 'Red' }
            default { 'White' }
        }

        Write-Host "  Status: $($connection.Status.Code)" -ForegroundColor $statusColor
        if ($connection.Status.Message) {
            Write-Host "  Message: $($connection.Status.Message)" -ForegroundColor White
        }

        # VPC information
        Write-Host "`n  Requester VPC:" -ForegroundColor Yellow
        Write-Host "    VPC ID: $($connection.RequesterVpcInfo.VpcId)" -ForegroundColor White
        Write-Host "    CIDR Block: $($connection.RequesterVpcInfo.CidrBlock)" -ForegroundColor White
        Write-Host "    Owner ID: $($connection.RequesterVpcInfo.OwnerId)" -ForegroundColor White
        Write-Host "    Region: $($connection.RequesterVpcInfo.Region)" -ForegroundColor White

        # Display additional CIDR blocks if present
        if ($connection.RequesterVpcInfo.CidrBlockSet -and $connection.RequesterVpcInfo.CidrBlockSet.Count -gt 1) {
            Write-Host "    Additional CIDRs:" -ForegroundColor White
            foreach ($cidr in $connection.RequesterVpcInfo.CidrBlockSet) {
                if ($cidr.CidrBlock -ne $connection.RequesterVpcInfo.CidrBlock) {
                    Write-Host "      - $($cidr.CidrBlock)" -ForegroundColor Gray
                }
            }
        }

        Write-Host "`n  Accepter VPC:" -ForegroundColor Yellow
        Write-Host "    VPC ID: $($connection.AccepterVpcInfo.VpcId)" -ForegroundColor White
        Write-Host "    CIDR Block: $($connection.AccepterVpcInfo.CidrBlock)" -ForegroundColor White
        Write-Host "    Owner ID: $($connection.AccepterVpcInfo.OwnerId)" -ForegroundColor White
        Write-Host "    Region: $($connection.AccepterVpcInfo.Region)" -ForegroundColor White

        # Display additional CIDR blocks if present
        if ($connection.AccepterVpcInfo.CidrBlockSet -and $connection.AccepterVpcInfo.CidrBlockSet.Count -gt 1) {
            Write-Host "    Additional CIDRs:" -ForegroundColor White
            foreach ($cidr in $connection.AccepterVpcInfo.CidrBlockSet) {
                if ($cidr.CidrBlock -ne $connection.AccepterVpcInfo.CidrBlock) {
                    Write-Host "      - $($cidr.CidrBlock)" -ForegroundColor Gray
                }
            }
        }

        # Connection type analysis
        $isInterRegion = $connection.RequesterVpcInfo.Region -ne $connection.AccepterVpcInfo.Region
        $isInterAccount = $connection.RequesterVpcInfo.OwnerId -ne $connection.AccepterVpcInfo.OwnerId

        Write-Host "`n  Connection Type:" -ForegroundColor Yellow
        if ($isInterAccount -and $isInterRegion) {
            Write-Host "    Cross-account, Cross-region" -ForegroundColor Cyan
        } elseif ($isInterAccount) {
            Write-Host "    Cross-account, Same region" -ForegroundColor Cyan
        } elseif ($isInterRegion) {
            Write-Host "    Same account, Cross-region" -ForegroundColor Cyan
        } else {
            Write-Host "    Same account, Same region" -ForegroundColor Cyan
        }

        # CIDR overlap check
        if ($connection.RequesterVpcInfo.CidrBlock -eq $connection.AccepterVpcInfo.CidrBlock) {
            Write-Host "    WARNING: Identical CIDR blocks detected!" -ForegroundColor Red
        }

        # Display tags if present
        if ($connection.Tags -and $connection.Tags.Count -gt 0) {
            Write-Host "`n  Tags:" -ForegroundColor Yellow
            foreach ($tag in $connection.Tags) {
                Write-Host "    $($tag.Key): $($tag.Value)" -ForegroundColor White
            }
        }

        # Show detailed information if requested
        if ($Detailed -and $connection.Status.Code -eq 'active') {
            Write-Host "`n  Route Table Analysis:" -ForegroundColor Yellow

            # Check for routes using this peering connection
            $routeArgs = @('ec2', 'describe-route-tables', '--filters', "Name=route.vpc-peering-connection-id,Values=$($connection.VpcPeeringConnectionId)")

            if ($Profile) {
                $routeArgs += @('--profile', $Profile)
            }

            if ($Region) {
                $routeArgs += @('--region', $Region)
            }

            $routeResult = & aws @routeArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                $routeInfo = $routeResult | ConvertFrom-Json

                if ($routeInfo.RouteTables.Count -gt 0) {
                    Write-Host "    Route tables using this peering connection:" -ForegroundColor White
                    foreach ($routeTable in $routeInfo.RouteTables) {
                        Write-Host "      - $($routeTable.RouteTableId) (VPC: $($routeTable.VpcId))" -ForegroundColor Gray

                        $peeringRoutes = $routeTable.Routes | Where-Object { $_.VpcPeeringConnectionId -eq $connection.VpcPeeringConnectionId }
                        foreach ($route in $peeringRoutes) {
                            Write-Host "        Route: $($route.DestinationCidrBlock) -> $($route.VpcPeeringConnectionId)" -ForegroundColor Gray
                        }
                    }
                } else {
                    Write-Host "    No route tables are currently using this peering connection" -ForegroundColor Yellow
                }
            }
        }
    }

    Write-Host "`n" + "="*70 -ForegroundColor Gray

    if (-not $Detailed) {
        Write-Host "`nTip: Use -Detailed switch for route table analysis and comprehensive information." -ForegroundColor Cyan
    }

    # Display summary of actions needed for pending connections
    $pendingConnections = $peeringInfo.VpcPeeringConnections | Where-Object { $_.Status.Code -eq 'pending-acceptance' }
    if ($pendingConnections.Count -gt 0) {
        Write-Host "`nPending Acceptance Required:" -ForegroundColor Yellow
        foreach ($pending in $pendingConnections) {
            Write-Host "  $($pending.VpcPeeringConnectionId) - Use: aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $($pending.VpcPeeringConnectionId)" -ForegroundColor Gray
        }
    }

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
