<#
.SYNOPSIS
    Describes AWS VPC endpoints.

.DESCRIPTION
    This script retrieves detailed information about VPC endpoints in your AWS account.
    It supports filtering by various criteria and provides comprehensive endpoint details.
    Uses aws ec2 describe-vpc-endpoints to perform the operation.

.PARAMETER VpcEndpointIds
    Comma-separated list of specific VPC endpoint IDs to describe. Must be in the format 'vpce-xxxxxxxxx'.

.PARAMETER VpcId
    Filter endpoints by VPC ID.

.PARAMETER ServiceName
    Filter endpoints by AWS service name (e.g., com.amazonaws.us-east-1.s3).

.PARAMETER VpcEndpointType
    Filter by endpoint type: Interface, Gateway, or GatewayLoadBalancer.

.PARAMETER State
    Filter by endpoint state.

.PARAMETER Profile
    The AWS CLI profile to use for the operation.

.PARAMETER Region
    The AWS region to query for VPC endpoints.

.PARAMETER OutputFormat
    The output format for the results (json, table, text, yaml).

.PARAMETER Detailed
    Show detailed information including DNS entries and policy documents.

.EXAMPLE
    .\aws-cli-describe-vpc-endpoints.ps1

.EXAMPLE
    .\aws-cli-describe-vpc-endpoints.ps1 -VpcId vpc-12345678

.EXAMPLE
    .\aws-cli-describe-vpc-endpoints.ps1 -ServiceName "com.amazonaws.us-east-1.s3"

.EXAMPLE
    .\aws-cli-describe-vpc-endpoints.ps1 -VpcEndpointType Interface -State Available

.EXAMPLE
    .\aws-cli-describe-vpc-endpoints.ps1 -VpcEndpointIds vpce-12345678,vpce-87654321 -Detailed

.EXAMPLE
    .\aws-cli-describe-vpc-endpoints.ps1 -Profile myprofile -Region us-west-2 -OutputFormat json

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-vpc-endpoints.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Specific VPC endpoint IDs to describe")]
    [ValidatePattern('^vpce-[a-zA-Z0-9]+(,vpce-[a-zA-Z0-9]+)*$')]
    [string]$VpcEndpointIds,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by VPC ID")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]+$')]
    [string]$VpcId,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by service name")]
    [string]$ServiceName,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by VPC endpoint type")]
    [ValidateSet('Interface', 'Gateway', 'GatewayLoadBalancer')]
    [string]$VpcEndpointType,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by VPC endpoint state")]
    [ValidateSet('PendingAcceptance', 'Pending', 'Available', 'Deleting', 'Deleted', 'Rejected', 'Failed', 'Expired')]
    [string]$State,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('json', 'table', 'text', 'yaml')]
    [string]$OutputFormat = 'table',

    [Parameter(Mandatory = $false, HelpMessage = "Show detailed information including DNS entries and policy documents")]
    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving VPC endpoint information..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @('ec2', 'describe-vpc-endpoints')

    if ($VpcEndpointIds) {
        $endpointArray = $VpcEndpointIds -split ','
        $awsArgs += @('--vpc-endpoint-ids')
        $awsArgs += $endpointArray
    }

    # Build filters array
    $filters = @()

    if ($VpcId) {
        $filters += "Name=vpc-id,Values=$VpcId"
    }

    if ($ServiceName) {
        $filters += "Name=service-name,Values=$ServiceName"
    }

    if ($VpcEndpointType) {
        $filters += "Name=vpc-endpoint-type,Values=$VpcEndpointType"
    }

    if ($State) {
        $filters += "Name=state,Values=$State"
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
        throw "Failed to describe VPC endpoints: $result"
    }

    $endpointInfo = $result | ConvertFrom-Json

    if ($OutputFormat -eq 'json') {
        # Output raw JSON
        $result
        return
    }

    if ($endpointInfo.VpcEndpoints.Count -eq 0) {
        Write-Host "No VPC endpoints found matching the specified criteria." -ForegroundColor Yellow
        return
    }

    # Display summary
    Write-Host "`nVPC Endpoints Summary:" -ForegroundColor Cyan
    Write-Host "Total endpoints found: $($endpointInfo.VpcEndpoints.Count)" -ForegroundColor White

    # Group by type
    $byType = $endpointInfo.VpcEndpoints | Group-Object VpcEndpointType
    foreach ($group in $byType) {
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor White
    }

    # Display detailed information for each endpoint
    foreach ($endpoint in $endpointInfo.VpcEndpoints) {
        Write-Host "`n" + "="*60 -ForegroundColor Gray
        Write-Host "VPC Endpoint: $($endpoint.VpcEndpointId)" -ForegroundColor Cyan
        Write-Host "  VPC ID: $($endpoint.VpcId)" -ForegroundColor White
        Write-Host "  Service Name: $($endpoint.ServiceName)" -ForegroundColor White
        Write-Host "  Type: $($endpoint.VpcEndpointType)" -ForegroundColor White
        Write-Host "  State: $($endpoint.State)" -ForegroundColor White
        Write-Host "  Creation Time: $($endpoint.CreationTimestamp)" -ForegroundColor White

        if ($endpoint.PolicyDocument) {
            Write-Host "  Policy Document: Present" -ForegroundColor White
        }

        if ($endpoint.RouteTableIds -and $endpoint.RouteTableIds.Count -gt 0) {
            Write-Host "  Route Tables: $($endpoint.RouteTableIds -join ', ')" -ForegroundColor White
        }

        if ($endpoint.SubnetIds -and $endpoint.SubnetIds.Count -gt 0) {
            Write-Host "  Subnets: $($endpoint.SubnetIds -join ', ')" -ForegroundColor White
        }

        if ($endpoint.Groups -and $endpoint.Groups.Count -gt 0) {
            Write-Host "  Security Groups:" -ForegroundColor White
            foreach ($group in $endpoint.Groups) {
                Write-Host "    - $($group.GroupId) ($($group.GroupName))" -ForegroundColor Gray
            }
        }

        if ($endpoint.NetworkInterfaceIds -and $endpoint.NetworkInterfaceIds.Count -gt 0) {
            Write-Host "  Network Interfaces: $($endpoint.NetworkInterfaceIds -join ', ')" -ForegroundColor White
        }

        if ($null -ne $endpoint.PrivateDnsEnabled) {
            Write-Host "  Private DNS Enabled: $($endpoint.PrivateDnsEnabled)" -ForegroundColor White
        }

        # Show detailed information if requested
        if ($Detailed) {
            if ($endpoint.DnsEntries -and $endpoint.DnsEntries.Count -gt 0) {
                Write-Host "  DNS Entries:" -ForegroundColor White
                foreach ($dns in $endpoint.DnsEntries) {
                    Write-Host "    - $($dns.DnsName) (Hosted Zone: $($dns.HostedZoneId))" -ForegroundColor Gray
                }
            }

            if ($endpoint.PolicyDocument) {
                Write-Host "  Policy Document:" -ForegroundColor White
                $policy = $endpoint.PolicyDocument | ConvertFrom-Json | ConvertTo-Json -Depth 10
                Write-Host $policy -ForegroundColor Gray
            }

            if ($endpoint.Tags -and $endpoint.Tags.Count -gt 0) {
                Write-Host "  Tags:" -ForegroundColor White
                foreach ($tag in $endpoint.Tags) {
                    Write-Host "    - $($tag.Key): $($tag.Value)" -ForegroundColor Gray
                }
            }
        }
    }

    Write-Host "`n" + "="*60 -ForegroundColor Gray
    Write-Host "`nTip: Use -Detailed switch for more comprehensive information including DNS entries and policies." -ForegroundColor Cyan

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
