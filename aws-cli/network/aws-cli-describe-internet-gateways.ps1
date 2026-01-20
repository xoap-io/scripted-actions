[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Specific Internet Gateway IDs to describe")]
    [ValidatePattern('^igw-[a-zA-Z0-9]+(,igw-[a-zA-Z0-9]+)*$', ErrorMessage = "InternetGatewayIds must be comma-separated valid Internet Gateway IDs (format: igw-xxxxxxxxx)")]
    [string]$InternetGatewayIds,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by VPC ID")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]+$', ErrorMessage = "VpcId must be a valid VPC ID (format: vpc-xxxxxxxxx)")]
    [string]$VpcId,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by attachment state")]
    [ValidateSet('available', 'attaching', 'attached', 'detaching', 'detached')]
    [string]$AttachmentState,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('json', 'table', 'text', 'yaml')]
    [string]$OutputFormat = 'table',

    [Parameter(Mandatory = $false, HelpMessage = "Show detailed route table analysis")]
    [switch]$ShowRoutes
)

<#
.SYNOPSIS
Describes AWS Internet Gateways.

.DESCRIPTION
This script retrieves detailed information about Internet Gateways in your AWS account. It supports filtering by various criteria and provides route table analysis.

.PARAMETER InternetGatewayIds
Comma-separated list of specific Internet Gateway IDs to describe. Must be in the format 'igw-xxxxxxxxx'.

.PARAMETER VpcId
Filter Internet Gateways by VPC ID to show only gateways attached to a specific VPC.

.PARAMETER AttachmentState
Filter by attachment state: available, attaching, attached, detaching, or detached.

.PARAMETER Profile
The AWS CLI profile to use for the operation.

.PARAMETER Region
The AWS region to query for Internet Gateways.

.PARAMETER OutputFormat
The output format for the results (json, table, text, yaml).

.PARAMETER ShowRoutes
Show detailed route table analysis including routes that use each Internet Gateway.

.EXAMPLE
.\aws-cli-describe-internet-gateways.ps1

Lists all Internet Gateways in the default region.

.EXAMPLE
.\aws-cli-describe-internet-gateways.ps1 -VpcId vpc-12345678

Lists Internet Gateways attached to a specific VPC.

.EXAMPLE
.\aws-cli-describe-internet-gateways.ps1 -AttachmentState attached

Lists all attached Internet Gateways.

.EXAMPLE
.\aws-cli-describe-internet-gateways.ps1 -InternetGatewayIds igw-12345678,igw-87654321 -ShowRoutes

Shows detailed information for specific Internet Gateways including route analysis.

.EXAMPLE
.\aws-cli-describe-internet-gateways.ps1 -AttachmentState detached

Lists unattached Internet Gateways that may be incurring unnecessary charges.

.NOTES
Author: Your Name
Date: 2024
Requires: AWS CLI v2.16+ and appropriate IAM permissions
#>

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving Internet Gateway information..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @('ec2', 'describe-internet-gateways')

    if ($InternetGatewayIds) {
        $igwArray = $InternetGatewayIds -split ','
        $awsArgs += @('--internet-gateway-ids')
        $awsArgs += $igwArray
    }

    # Build filters array
    $filters = @()

    if ($VpcId) {
        $filters += "Name=attachment.vpc-id,Values=$VpcId"
    }

    if ($AttachmentState) {
        $filters += "Name=attachment.state,Values=$AttachmentState"
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
        throw "Failed to describe Internet Gateways: $result"
    }

    $igwInfo = $result | ConvertFrom-Json

    if ($OutputFormat -eq 'json') {
        # Output raw JSON
        $result
        return
    }

    if ($igwInfo.InternetGateways.Count -eq 0) {
        Write-Host "No Internet Gateways found matching the specified criteria." -ForegroundColor Yellow
        return
    }

    # Display summary
    Write-Host "`nInternet Gateways Summary:" -ForegroundColor Cyan
    Write-Host "Total gateways found: $($igwInfo.InternetGateways.Count)" -ForegroundColor White

    # Categorize gateways
    $attached = $igwInfo.InternetGateways | Where-Object { $_.Attachments.Count -gt 0 -and $_.Attachments[0].State -eq 'attached' }
    $detached = $igwInfo.InternetGateways | Where-Object { $_.Attachments.Count -eq 0 -or $_.Attachments[0].State -ne 'attached' }

    Write-Host "  Attached: $($attached.Count)" -ForegroundColor Green
    Write-Host "  Detached: $($detached.Count)" -ForegroundColor Yellow

    if ($detached.Count -gt 0) {
        Write-Host "`nNOTE: Detached Internet Gateways don't incur charges but may indicate unused resources." -ForegroundColor Cyan
    }

    # Display detailed information for each gateway
    foreach ($gateway in $igwInfo.InternetGateways) {
        Write-Host "`n" + "="*60 -ForegroundColor Gray
        Write-Host "Internet Gateway: $($gateway.InternetGatewayId)" -ForegroundColor Cyan
        Write-Host "  Owner ID: $($gateway.OwnerId)" -ForegroundColor White

        # Attachment information
        if ($gateway.Attachments -and $gateway.Attachments.Count -gt 0) {
            Write-Host "  Attachments:" -ForegroundColor White
            foreach ($attachment in $gateway.Attachments) {
                $stateColor = switch ($attachment.State) {
                    'attached' { 'Green' }
                    'detached' { 'Gray' }
                    'attaching' { 'Yellow' }
                    'detaching' { 'Yellow' }
                    default { 'White' }
                }

                Write-Host "    VPC ID: $($attachment.VpcId)" -ForegroundColor White
                Write-Host "    State: $($attachment.State)" -ForegroundColor $stateColor
            }
        } else {
            Write-Host "  Status: Not attached to any VPC" -ForegroundColor Yellow
        }

        # Display tags if present
        if ($gateway.Tags -and $gateway.Tags.Count -gt 0) {
            Write-Host "  Tags:" -ForegroundColor White
            foreach ($tag in $gateway.Tags) {
                Write-Host "    $($tag.Key): $($tag.Value)" -ForegroundColor Gray
            }
        }

        # Show route analysis if requested and gateway is attached
        if ($ShowRoutes -and $gateway.Attachments -and $gateway.Attachments[0].State -eq 'attached') {
            Write-Host "`n  Route Table Analysis:" -ForegroundColor Yellow

            # Find route tables that use this Internet Gateway
            $routeArgs = @('ec2', 'describe-route-tables', '--filters', "Name=route.gateway-id,Values=$($gateway.InternetGatewayId)")

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
                    Write-Host "    Route tables using this gateway:" -ForegroundColor White
                    foreach ($routeTable in $routeInfo.RouteTables) {
                        Write-Host "      Route Table: $($routeTable.RouteTableId) (VPC: $($routeTable.VpcId))" -ForegroundColor Gray

                        # Find associations
                        if ($routeTable.Associations -and $routeTable.Associations.Count -gt 0) {
                            $mainAssoc = $routeTable.Associations | Where-Object { $_.Main -eq $true }
                            $subnetAssocs = $routeTable.Associations | Where-Object { $_.SubnetId }

                            if ($mainAssoc) {
                                Write-Host "        Type: Main route table" -ForegroundColor Gray
                            }
                            if ($subnetAssocs) {
                                Write-Host "        Associated subnets: $($subnetAssocs.Count)" -ForegroundColor Gray
                            }
                        }

                        # Show routes to this IGW
                        $igwRoutes = $routeTable.Routes | Where-Object { $_.GatewayId -eq $gateway.InternetGatewayId }
                        foreach ($route in $igwRoutes) {
                            $routeColor = if ($route.State -eq 'active') { 'Green' } else { 'Yellow' }
                            Write-Host "        Route: $($route.DestinationCidrBlock) -> $($route.GatewayId) ($($route.State))" -ForegroundColor $routeColor
                        }
                    }
                } else {
                    Write-Host "    No route tables are currently using this gateway" -ForegroundColor Yellow
                    Write-Host "    This gateway may not be providing internet access" -ForegroundColor Yellow
                }
            }
        }
    }

    Write-Host "`n" + "="*60 -ForegroundColor Gray

    # Display recommendations
    if ($detached.Count -gt 0) {
        Write-Host "`nDetached Internet Gateways:" -ForegroundColor Yellow
        foreach ($detachedGw in $detached) {
            Write-Host "  $($detachedGw.InternetGatewayId) - Consider deleting if no longer needed" -ForegroundColor Gray
        }
    }

    # Show common management commands
    Write-Host "`nManagement Commands:" -ForegroundColor Cyan
    Write-Host "Attach to VPC: aws ec2 attach-internet-gateway --internet-gateway-id <igw-id> --vpc-id <vpc-id>" -ForegroundColor Gray
    Write-Host "Detach from VPC: aws ec2 detach-internet-gateway --internet-gateway-id <igw-id> --vpc-id <vpc-id>" -ForegroundColor Gray
    Write-Host "Delete gateway: aws ec2 delete-internet-gateway --internet-gateway-id <igw-id>" -ForegroundColor Gray

    if (-not $ShowRoutes) {
        Write-Host "`nTip: Use -ShowRoutes switch for detailed route table analysis." -ForegroundColor Cyan
    }

    # Connectivity analysis
    $attachedGateways = $igwInfo.InternetGateways | Where-Object { $_.Attachments.Count -gt 0 -and $_.Attachments[0].State -eq 'attached' }
    if ($attachedGateways.Count -gt 0) {
        Write-Host "`nConnectivity Notes:" -ForegroundColor Cyan
        Write-Host "- Internet Gateways provide outbound internet access for public subnets" -ForegroundColor White
        Write-Host "- Ensure route tables have 0.0.0.0/0 routes pointing to the gateway" -ForegroundColor White
        Write-Host "- Security groups and NACLs must allow the required traffic" -ForegroundColor White
        Write-Host "- Instances need public IP addresses or Elastic IPs for inbound access" -ForegroundColor White
    }

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
